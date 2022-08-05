import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'src/base_generator.dart';
import 'src/utils/map_utils.dart';
import 'src/utils/string_buffer_utils.dart';
import 'src/utils/string_utils.dart';

/// Build runner static entry point for [ModelsGenerator].
ModelsGenerator modelsGeneratorBuilder(final BuilderOptions options) =>
    ModelsCommand().get(options.config);

/// The command used to run the [ModelsGenerator].
class ModelsCommand extends GeneratorCommand<ModelsGenerator> {
  /// The command used to run the [ModelsGenerator].
  ModelsCommand() : super('./models.g.dart') {
    argParser
      ..addOption(
        'encoding',
        help: 'The encoding used for reading the `.json` and `.yaml` files. '
            'Defaults to `utf-8`.',
      )
      ..addFlag(
        'convert-class-names',
        help: 'If the class names should be converted to camel case. Disabling '
            'this option will prevent any changes to be made to the class '
            'names. Be certain to pass valid Dart names or the generation will '
            'be likely to fail. Defaults to `true`.',
        defaultsTo: null,
      )
      ..addFlag(
        'convert-field-names',
        help: 'If the field names should be converted to camel case. Disabling '
            'this option will prevent any changes to be made to the field '
            'names. Be certain to pass valid Dart names or the generation will '
            'be likely to fail. Defaults to `true`.',
        defaultsTo: null,
      )
      ..addFlag(
        'assign-field-types',
        help: 'If the unknown field types should be resolved from default '
            'values. Defaults to `true`.',
        defaultsTo: null,
      )
      ..addFlag(
        'include-null-fields',
        help: 'If the fields with null values should be added in `toMap`. '
            'Defaults to `true`.',
        defaultsTo: null,
      )
      ..addFlag(
        'empty-required-iterables',
        help: 'If the required iterable fields with null values should be '
            'replaced with empty iterable in `fromMap`. Defaults to `true`.',
        defaultsTo: null,
      )
      ..addMultiOption(
        'imports',
        abbr: 'f',
        help: 'The imports to be used in generated files. '
            'By default, imports '
            '`package:json_converters_lite/json_converters_lite.dart`.',
        defaultsTo: <String>[null.toString()],
      );
  }

  @override
  String get name => 'models';

  @override
  String get description => 'Migrates file structure into Dart classes.';

  @override
  ModelsGenerator get([final Map<String, Object?>? options]) {
    final Object? importPath =
        options?['import_path'] ?? argResults?['import-path'] as Object?;
    final Object? exportPath =
        options?['export_path'] ?? argResults?['export-path'] as Object?;
    final Object? exportEncoding = options?['export_encoding'] ??
        argResults?['export-encoding'] as Object?;
    final Object? encoding =
        options?['encoding'] ?? argResults?['encoding'] as Object?;
    final Object? convertClassNames = options?['convert_class_names'] ??
        argResults?['convert-class-names'] as Object?;
    final Object? convertFieldNames = options?['convert_field_names'] ??
        argResults?['convert-field-names'] as Object?;
    final Object? assignFieldTypes = options?['assign_field_types'] ??
        argResults?['assign-field-types'] as Object?;
    final Object? includeNullFields = options?['include_null_fields'] ??
        argResults?['include-null-fields'] as Object?;
    final Object? emptyRequiredIterables =
        options?['empty_required_iterables'] ??
            argResults?['empty-required-iterables'] as Object?;
    final Object? $imports =
        options?['imports'] ?? argResults?['imports'] as Object?;
    final Iterable<String>? imports = $imports is String
        ? <String>[$imports]
        : $imports is Iterable<Object?>
            ? $imports.cast<String>()
            : null;
    if (importPath is! String || importPath.isEmpty) {
      throw const FormatException('The import path is not provided.');
    } else if (exportPath is! String || exportPath.isEmpty) {
      throw const FormatException('The export path is not provided.');
    } else {
      return DartModelsGenerator(
        importPath: importPath,
        exportPath: exportPath,
        exportEncoding: exportEncoding is String
            ? Encoding.getByName(exportEncoding)
            : null,
        encoding: encoding is String && encoding.isNotEmpty
            ? Encoding.getByName(encoding)
            : null,
        convertClassNames: convertClassNames is bool ? convertClassNames : null,
        convertFieldNames: convertFieldNames is bool ? convertFieldNames : null,
        assignFieldTypes: assignFieldTypes is bool ? assignFieldTypes : null,
        includeNullFields: includeNullFields is bool ? includeNullFields : null,
        emptyRequiredIterables:
            emptyRequiredIterables is bool ? emptyRequiredIterables : null,
        imports: imports == null ||
                imports.length == 1 && imports.single == null.toString()
            ? null
            : imports,
      );
    }
  }
}

/// The architecture of the data class generator.
@immutable
abstract class ModelsGenerator extends BaseGenerator {
  /// The architecture of the data class generator.
  ModelsGenerator({
    required super.importPath,
    required super.exportPath,
    super.exportEncoding,
    super.encoding,
    super.formatter,
    super.jsonReviver,
    super.yamlRecover,
    this.convertClassNames,
    this.convertFieldNames,
    final bool? assignFieldTypes,
  }) : assignFieldTypes = assignFieldTypes ?? true;

  /// If the field names should be converted using [StringUtils.toCamelCase].
  final bool? convertClassNames;

  /// If the field names should be converted using [StringUtils.toCamelCase].
  final bool? convertFieldNames;

  /// If the unknown field types should be resolved from default values using
  /// [FieldType.fromObject].
  final bool assignFieldTypes;

  /// The map with data class names as keys and instances as values.
  final List<ClassModel<Object?>> models = <ClassModel<Object?>>[];

  @override
  Map<String, List<String>> get buildExtensions => <String, List<String>>{
        r'$package$': <String>[exportPath],
      };

  @override
  @mustCallSuper
  FutureOr<void> build([final BuildStep? buildStep]) async {
    await super.build(buildStep);
    models.clear();

    /// Generate models from dictionaries.
    for (final MapEntry<String, Map<String, Object?>> entry in fileMap.values
        .toMap<String>()
        .cast<String, Map<String, Object?>>()
        .entries) {
      final List<FieldModel<Object?>> fields = <FieldModel<Object?>>[];

      /// Convert dictionary fields.
      for (final MapEntry<String, Map<String, Object?>> fieldEntry
          in entry.value.cast<String, Map<String, Object?>>().entries) {
        if (fieldEntry.key.isNotEmpty) {
          final Object? type = fieldEntry.value['type'];
          final Object? name = fieldEntry.value['name'];
          final Object? doc = fieldEntry.value['doc'];
          final Object? $default = fieldEntry.value['default'];
          final Object? compare = fieldEntry.value['compare'];
          final Object? nullable = fieldEntry.value['nullable'];
          final Object? required = fieldEntry.value['required'];
          final Object? copy = fieldEntry.value['copy'];
          final Object? serialize = fieldEntry.value['serialize'];
          fields.add(
            FieldModel<Object?>(
              fieldEntry.key.normalize(),
              type is String
                  ? FieldType.fromString(type)
                  : assignFieldTypes && $default != null
                      ? FieldType.fromObject($default)
                      : FieldType.$object,
              dartName:
                  name is String && name.isNotEmpty ? name.normalize() : null,
              reference: type is String ? type : null,
              doc: doc is String ? doc : null,
              $default: $default,
              compare: compare is bool ? compare : null,
              nullable: nullable is bool ? nullable : null,
              required: required is bool ? required : null,
              copy: copy is bool ? copy : null,
              serialize: serialize is bool ? serialize : null,
              convert: convertFieldNames,
              convertClasses: convertClassNames,
            ),
          );
        }
      }

      final Map<String, Object?> modelRef =
          (entry.value[''] as Map<String, Object?>?) ??
              const <String, Object?>{};
      final Object? name = modelRef['name'];
      final Object? doc = modelRef['doc'];
      final Object? toJson = modelRef['to_json'];
      models.add(
        ClassModel<Object?>(
          entry.key.split('.').last.normalize(),
          reference: entry.key,
          fields: fields,
          dartName: name is String && name.isNotEmpty ? name : null,
          doc: doc is String && doc.isNotEmpty ? doc : null,
          toJson: toJson is bool ? toJson : null,
          convert: convertClassNames,
        ),
      );
    }
  }
}

/// The data class generator for dart.
@immutable
class DartModelsGenerator extends ModelsGenerator {
  /// The data class generator for dart.
  DartModelsGenerator({
    required super.importPath,
    required super.exportPath,
    super.exportEncoding,
    super.encoding,
    super.formatter,
    super.jsonReviver,
    super.yamlRecover,
    super.convertClassNames,
    super.convertFieldNames,
    super.assignFieldTypes,
    final bool? includeNullFields,
    final bool? emptyRequiredIterables,
    final Iterable<String>? imports,
  })  : includeNullFields = includeNullFields ?? true,
        emptyRequiredIterables = emptyRequiredIterables ?? true,
        imports = imports ??
            const <String>[
              'package:json_converters_lite/json_converters_lite.dart'
            ];

  /// If the fields with null values should be added in `toMap`.
  final bool includeNullFields;

  /// If the required iterable fields with null values should be replaced with
  /// empty [Iterable] in `fromMap`.
  final bool emptyRequiredIterables;

  /// The iterable with imports to be used in [generateHeader].
  final Iterable<String> imports;

  @override
  @mustCallSuper
  FutureOr<void> build([final BuildStep? buildStep]) async {
    await super.build(buildStep);
    if (buildStep != null) {
      await buildStep.writeAsString(
        buildStep.allowedOutputs.single,
        buildStep.trackStage('Generate $exportPath.', () => generate(models)),
        encoding: exportEncoding,
      );
    } else {
      final FileSystemEntityType exportType =
          FileSystemEntity.typeSync(exportPath);
      if (exportType == FileSystemEntityType.directory ||
          exportType == FileSystemEntityType.notFound &&
              extension(exportPath).isEmpty) {
        final Map<Uri, Iterable<ClassModel<Object?>>> files =
            <Uri, Iterable<ClassModel<Object?>>>{};
        for (final ClassModel<Object?> model in models) {
          final List<String> parts =
              (model.reference.isEmpty ? model.name : model.reference)
                  .split('.');
          final String filename =
              parts.length > 2 ? parts.elementAt(parts.length - 2) : parts.last;
          final Uri uri = Uri(
            pathSegments: <String>[
              exportPath,
              if (parts.length > 2) ...parts.sublist(0, parts.length - 2),
              '$filename.g.dart'
            ],
          );
          files[uri] = <ClassModel<Object?>>[...?files[uri], model];
        }
        for (final Uri uri in files.keys) {
          final File file = File.fromUri(uri);
          await file.parent.create(recursive: true);
          await file.writeAsString(
            generate(files[uri]!),
            encoding: exportEncoding,
            mode: FileMode.writeOnly,
            flush: true,
          );
        }
      } else {
        final File file = File(exportPath);
        await file.parent.create(recursive: true);
        await file.writeAsString(
          generate(models),
          encoding: exportEncoding,
          mode: FileMode.writeOnly,
          flush: true,
        );
      }
    }
  }

  /// Generate a single file with data classes from [models].
  String generate<T extends Object?>(final Iterable<ClassModel<T>> models) {
    final StringBuffer buffer = StringBuffer();
    generateHeader<T>(buffer, models);
    generateEnum<T>(buffer, models);
    for (final ClassModel<T> model in models) {
      generateConverter<T>(buffer, model);
    }
    for (final ClassModel<T> model in models) {
      generateModel<T>(buffer, model);
    }
    return formatter.format(buffer.toString(), uri: exportPath);
  }

  /// Generate a header for the data classes file.
  void generateHeader<T extends Object?>(
    final StringBuffer buffer,
    final Iterable<ClassModel<T>> models,
  ) {
    buffer
      ..writeDoc(
        (<String>['sort_constructors_first']..sort()).join(' '),
        prefix: '// ignore_for_file: ',
        separator: ', ',
        indent: 0,
      )
      ..writeln()
      ..writeDoc('This file is used for `Data Class` generation.')
      ..writeDoc('')
      ..writeDoc('Modify this file at your own risk!')
      ..writeDoc('')
      ..writeDoc(
        'See: https://pub.dev/packages/generators#data-class-generator',
      )
      ..writeDoc('')
      ..writeImports(<String>[
        ...imports,
        'package:meta/meta.dart',
        if (models.any((final ClassModel<T> model) => model.toJson))
          'dart:convert',
        if (models.any(
          (final ClassModel<T> model) => model.fields.any(
            (final FieldModel<T> field) => field.type.name.startsWith(r'$$'),
          ),
        ))
          'package:collection/collection.dart',
      ]);

    final Map<String, int> relativeImports = <String, int>{};
    for (final ClassModel<T> model in models) {
      if (model.reference.isEmpty) {
        continue;
      }
      final List<String> nameParts = model.reference
          .split('.')
          .reversed
          .toList(growable: false)
          .sublist(1);
      for (final FieldModel<T> field in model.fields) {
        if ((field.reference.isEmpty) ||
            (field.type != FieldType.$object &&
                field.type != FieldType.$$object)) {
          continue;
        }
        final List<String> parts = field.reference
            .split('.')
            .reversed
            .toList(growable: false)
            .sublist(1);
        if (const IterableEquality<String>().equals(nameParts, parts)) {
          continue;
        }

        int index, dotCount = 0; // ignore: avoid_multiple_declarations_per_line
        for (index = 1; index < parts.length; index++) {
          if (index < nameParts.length &&
              parts.elementAt(index) == nameParts.elementAt(index)) {
            dotCount++;
          } else {
            dotCount += nameParts.length - index + 1;
            break;
          }
        }

        final String path = <String>[
          if (dotCount > 0) '.' * dotCount,
          ...parts.sublist(index).reversed,
          '${parts.elementAt(0)}.dart'
        ].join('/');
        relativeImports["import '$path';"] = dotCount;
      }
    }
    relativeImports.keys.toList(growable: false)
      ..sort(
        (final String key1, final String key2) {
          final num value1 = relativeImports[key1]!;
          final num value2 = relativeImports[key2]!;
          final int value = (value1 <= 1 ? double.infinity : value1)
              .compareTo(value2 <= 1 ? double.infinity : value2);
          return value != 0 ? value : key1.compareTo(key2);
        },
      )
      ..forEach(buffer.writeln);
  }

  /// Generate enums for the data classes file.
  void generateEnum<T extends Object?>(
    final StringBuffer buffer,
    final Iterable<ClassModel<T>> models,
  ) {
    final Set<String> processedEnumNames = <String>{};
    for (final ClassModel<T> model in models) {
      for (final FieldModel<T> field in model.fields) {
        if (field.reference.isEmpty ||
            (field.type != FieldType.$enum && field.type != FieldType.$$enum)) {
          continue;
        }

        final String enumName =
            field.renderType(model.name, iterable: false, nullable: false);
        if (processedEnumNames.contains(enumName)) {
          continue;
        }
        processedEnumNames.add(enumName);

        String reference = field.reference.split('[').last.normalize();
        if (reference.endsWith(']')) {
          reference = reference.substring(0, reference.length - 1);
        }
        buffer
          ..writeDoc('The enum for the [${model.name}.${field.key}].')
          ..writeln('enum $enumName { ');
        final Iterable<String> referenceValues = reference.split(',');
        for (int index = 0; index < referenceValues.length; index++) {
          final String value = referenceValues.elementAt(index).trim();
          buffer
            ..writeDoc('The `$value` property of this [$enumName].')
            ..write(field.convert ? value.toCamelCase() : value.normalize())
            ..writeln(index < referenceValues.length - 1 ? ',' : ';');
        }
        buffer
          ..writeln()
          ..writeDoc('The name of the enum value.')
          ..writeln('String get name {')
          ..writeln('switch (this) {');
        for (final String value in reference.split(',')) {
          final String $value = field.convert
              ? value.trim().toCamelCase()
              : value.trim().normalize();
          buffer
            ..writeln('case $enumName.${$value}:')
            ..writeln("return '${value.trim()}';");
        }
        buffer
          ..writeln('}')
          ..writeln('}')
          ..writeln('}');
      }
    }
  }

  /// Generate converter for the data classes file.
  void generateConverter<T extends Object?>(
    final StringBuffer buffer,
    final ClassModel<T> model,
  ) {
    String converter = model.name.endsWith('Model')
        ? model.name.substring(0, model.name.length - 5)
        : model.name;
    converter += 'Converter';
    String converterName = converter.decapitalize();
    converterName =
        converterName == converter ? '\$$converterName' : converterName;

    final String optionalConverter = 'Optional$converter';
    buffer
      ..writeDoc('The optional converter of the [${model.name}].')
      ..writeln(
        'const $optionalConverter ${optionalConverter.decapitalize()} = '
        '$optionalConverter._();',
      )
      ..writeln()
      ..writeDoc('The optional converter of the [${model.name}].')
      ..writeln('@sealed')
      ..writeln('@immutable')
      ..writeln(
        'class $optionalConverter implements '
        'JsonConverter<${model.name}?, Map<String, Object?>?> {',
      )
      ..writeln('const $optionalConverter._();')
      ..writeln()
      ..writeln('@override')
      ..writeFunction(
        '${model.name}? fromJson',
        <String>['final Map<String, Object?>? value'],
        bodyConstructor: 'value == null ? null : ${model.name}.fromMap',
        bodyFields: <String>['value'],
      )
      ..writeln()
      ..writeln('@override')
      ..writeFunction(
        'Map<String, Object?>? toJson',
        <String>['final ${model.name}? value'],
        bodyConstructor: 'value?.toMap',
      )
      ..writeln('}')
      ..writeln()
      ..writeDoc('The converter of the [${model.name}].')
      ..writeln(
        'const $converter $converterName = $converter._();',
      )
      ..writeln()
      ..writeDoc('The converter of the [${model.name}].')
      ..writeln('@sealed')
      ..writeln('@immutable')
      ..writeln(
        'class $converter implements '
        'JsonConverter<${model.name}, Map<String, Object?>> {',
      )
      ..writeln('const $converter._();')
      ..writeln()
      ..writeln('@override')
      ..writeFunction(
        '${model.name} fromJson',
        <String>['final Map<String, Object?> value'],
        bodyConstructor: '${model.name}.fromMap',
        bodyFields: <String>['value'],
      )
      ..writeln()
      ..writeln('@override')
      ..writeFunction(
        'Map<String, Object?> toJson',
        <String>['final ${model.name} value'],
        bodyConstructor: 'value.toMap',
      )
      ..writeln('}');
  }

  /// Generate models for the data classes file.
  void generateModel<T extends Object?>(
    final StringBuffer buffer,
    final ClassModel<T> model,
  ) {
    final String comparable =
        model.fields.any((final FieldModel<T> field) => field.compare)
            ? ' implements Comparable<${model.name}>'
            : '';
    final String doc =
        model.doc == null ? 'The model of a ${model.name}.' : model.doc!;
    buffer
      ..writeDoc(doc)
      ..writeln('@sealed')
      ..writeln('@immutable')
      ..writeln('class ${model.name}$comparable {')

      /// `constructor`
      ..writeDoc(doc, indent: 4)
      ..writeFunction(
        useBrackets: true,
        'const ${model.name}',
        <String>[
          for (final FieldModel<T> field in model.fields)
            (final FieldModel<T> field) {
              final String? $default = _renderDefault(model.name, field);
              if (field.required || !field.nullable && $default == null) {
                return 'required this.${field.name}';
              } else if ($default != null) {
                return 'this.${field.name} = ${$default}';
              } else {
                return 'this.${field.name}';
              }
            }(field)
        ]..sort(
            (final String a, final String b) =>
                (b.startsWith('required') ? 1 : -1)
                    .compareTo(a.startsWith('required') ? 1 : -1),
          ),
      )
      ..writeln();

    /// `fields`
    for (final FieldModel<T> field in model.fields) {
      final String key =
          field.convert ? field.key.toCamelCase() : field.key.normalize();
      buffer
        ..writeDoc(
          field.doc == null
              ? 'The `${field.key}` property of this [${model.name}].'
              : field.doc!,
        )
        ..writeln('final ${field.renderType(model.name)} $key;');
    }

    /// `copyWith`
    if (model.fields.any((final FieldModel<T> field) => field.copy)) {
      buffer
        ..writeDoc('Return the copy of this model.')
        ..writeFunction(
          useBrackets: true,
          '${model.name} copyWith',
          <String>[
            for (final FieldModel<T> field in model.fields)
              if (field.copy)
                'final ${field.renderType(model.name, nullable: true)} '
                    '${field.name}'
          ],
          bodyConstructor: model.name,
          bodyFields: <String>[
            for (final FieldModel<T> field in model.fields)
              if (field.copy)
                '${field.name}: ${field.name} ?? this.${field.name}'
              else if (field.required)
                '${field.name}: ${field.name}'
          ],
        );
    }

    /// `copyWithNull`
    if (model.fields
        .any((final FieldModel<T> field) => field.nullable && field.copy)) {
      buffer
        ..writeDoc('Return the copy of this model with nullable fields.')
        ..writeFunction(
          useBrackets: true,
          '${model.name} copyWithNull',
          <String>[
            for (final FieldModel<T> field in model.fields)
              if (field.nullable && field.copy)
                'final bool ${field.name} = false'
          ],
          bodyConstructor: model.name,
          bodyFields: <String>[
            for (final FieldModel<T> field in model.fields)
              if (field.nullable && field.copy)
                '${field.name}: ${field.name} ? null : this.${field.name}'
              else
                '${field.name}: ${field.name}'
          ],
        );
    }

    if (model.fields.any((final FieldModel<T> field) => field.serialize)) {
      buffer

        /// `toMap`
        ..writeDoc('Convert this model to map with string keys.')
        ..writeFunction(
          'Map<String, Object?> toMap',
          const Iterable<String>.empty(),
          bodyConstructor: '<String, Object?>{',
          bodyFields: <String>[
            for (final FieldModel<T> field in model.fields)
              if (field.serialize)
                (final FieldModel<T> field) {
                  final String $field = "'${field.key}': "
                      '${renderSerialization(model.name, field)}';
                  return !includeNullFields && field.nullable
                      ? 'if (${field.name} != null) ${$field}'
                      : $field;
                }(field)
          ],
        )

        /// `fromMap`
        ..writeDoc('Convert the map with string keys to this model.')
        ..writeFunction(
          'factory ${model.name}.fromMap',
          <String>['final Map<String, Object?> map'],
          bodyConstructor: model.name,
          bodyFields: <String>[
            for (final FieldModel<T> field in model.fields)
              if (field.serialize)
                (final FieldModel<T> field) {
                  final String deserialized = renderDeserialization(
                    model.name,
                    field,
                    emptyRequiredIterables: emptyRequiredIterables,
                  );
                  return '${field.name}: $deserialized';
                }(field)
          ],
        );

      if (model.toJson) {
        buffer

          /// `toJson`
          ..writeDoc('Convert this model to a json string.')
          ..writeFunction(
            'String toJson',
            const Iterable<String>.empty(),
            bodyConstructor: 'json.encode',
            bodyFields: <String>['toMap()'],
          )

          /// `fromJson`
          ..writeDoc('Convert the json string to this model.')
          ..writeFunction(
            'factory ${model.name}.fromJson',
            <String>['final String source'],
            bodyConstructor: '${model.name}.fromMap',
            bodyFields: <String>[
              'json.decode(source)! as Map<String, Object?>'
            ],
          );
      }
    }

    /// `compareTo`
    final List<String> compareFields = <String>[
      for (final FieldModel<T> field in model.fields)
        if (field.compare)
          if (field.nullable)
            '${field.name} != null && other.${field.name} != null ? '
                '${field.name}!.compareTo(other.${field.name}!) : 0'
          else
            '${field.name}.compareTo(other.${field.name})'
    ];
    if (compareFields.isEmpty) {
    } else if (compareFields.length == 1) {
      buffer
        ..writeln()
        ..writeln('@override')
        ..writeFunction(
          'int compareTo',
          <String>['final ${model.name} other'],
          bodyFields: compareFields,
          separator: '',
        );
    } else {
      buffer
        ..writeln()
        ..writeln('@override')
        ..writeln('int compareTo(final ${model.name} other) {')
        ..writeln('int value;');
      for (int index = 0; index < compareFields.length; index++) {
        if (index > 0) {
          buffer.write(' else ');
        }
        buffer.writeln(
          'if ((value = ${compareFields.elementAt(index)}) != 0) {}',
        );
      }
      buffer
        ..writeln('return value;')
        ..writeln('}');
    }

    buffer
      ..writeln()

      /// `==` operator
      ..writeln('@override')
      ..writeFunction(
        'bool operator ==',
        <String>['final Object? other'],
        bodyFields: <String>[
          'identical(this, other) ||other is ${model.name}',
          for (final FieldModel<T> field in model.fields)
            if (field.type.name.startsWith(r'$$'))
              // ignore: missing_whitespace_between_adjacent_strings
              'const UnorderedIterableEquality'
                  '<${field.renderType(model.name, iterable: false)}>()'
                  '.equals(other.${field.name}, ${field.name})'
            else
              'other.${field.name} == ${field.name}'
        ],
        separator: ' && ',
      )
      ..writeln()

      /// `hashCode`
      ..writeln('@override')
      ..writeFunction(
        'int get hashCode',
        <String>[],
        bodyFields: <String>[
          for (final FieldModel<T> field in model.fields)
            '${field.name}.hashCode'
        ],
        separator: ' ^ ',
      )
      ..writeln()

      /// `toString`
      ..writeln('@override')
      ..writeFunction(
        'String toString',
        <String>[],
        bodyConstructor:
            "'${model.name.startsWith(r'$') ? r'\' : ''}${model.name}",
        bodyFields: <String>[
          for (final FieldModel<T> field in model.fields)
            '${field.name}: \$${field.name}'
        ],
      )
      ..writeln('}');
  }

  /// The default value of this [field] in a form of [String].
  String? _renderDefault<T extends Object?>(
    final String className,
    final FieldModel<T> field, [
    final Object? $value = Object,
  ]) {
    final Object? value = $value == Object ? field.$default : $value;
    if (value == null) {
      return null;
    }
    final String? Function(Object? value) convert;
    switch (field.type) {
      case FieldType.$bool:
        return value is bool ? value.toString() : null;
      case FieldType.$int:
        return value is int ? value.toString() : null;
      case FieldType.$float:
        return value is double ? value.toString() : null;
      case FieldType.$str:
        return _renderString(value);
      case FieldType.$datetime:
        return _renderDateTime(value);
      case FieldType.$timedelta:
        return _renderDuration(value);
      case FieldType.$enum:
        return _renderEnum(className, field, value);
      case FieldType.$object:
        final String modelKey = field.reference.split('[').first.normalize();
        if (models
            .any((final ClassModel<Object?> model) => model.key == modelKey)) {
          return _renderModel(className, field, value);
        } else if (value is! Iterable<Object?>) {
          return _renderBasic(value);
        }
        convert = _renderBasic;
        break;

      case FieldType.$$bool:
        convert =
            (final Object? value) => value is bool ? value.toString() : null;
        break;
      case FieldType.$$int:
        convert =
            (final Object? value) => value is int ? value.toString() : null;
        break;
      case FieldType.$$float:
        convert =
            (final Object? value) => value is double ? value.toString() : null;
        break;
      case FieldType.$$str:
        convert = _renderString;
        break;
      case FieldType.$$datetime:
        convert =
            (final Object? value) => _renderDateTime(value, renderConst: false);
        break;
      case FieldType.$$timedelta:
        convert =
            (final Object? value) => _renderDuration(value, renderConst: false);
        break;
      case FieldType.$$enum:
        convert = (final Object? value) => _renderEnum(className, field, value);
        break;

      case FieldType.$$object:
        final String modelKey = field.reference.split('[').first.normalize();
        if (models
            .any((final ClassModel<Object?> model) => model.key == modelKey)) {
          convert = (final Object? value) =>
              _renderModel(className, field, value, renderConst: false);
        } else {
          convert = _renderBasic;
        }
        break;
    }

    final String $type =
        field.renderType(className, iterable: false, nullable: false);
    final Iterable<Object?> iterable =
        value is Iterable<Object?> ? value : const Iterable<Object?>.empty();
    if (iterable.isEmpty) {
      return 'const Iterable<${$type}>.empty()';
    }
    final Iterable<String> values = iterable.map(convert).whereNotNull();
    if (values.isEmpty) {
      return 'const Iterable<${$type}>.empty()';
    }
    return 'const <${$type}>[${values.join(',')}]';
  }

  String? _renderModel<T extends Object?>(
    final String className,
    final FieldModel<T> field,
    final Object? value, {
    final bool renderConst = true,
  }) {
    if (value is! Map<String, Object?>) {
      return null;
    }
    final ClassModel<Object?>? fieldClass = models.firstWhereOrNull(
      (final ClassModel<Object?> model) =>
          model.key == field.reference.split('[').first.normalize(),
    );
    if (fieldClass != null) {
      final List<String> values = <String>[];
      for (final String key in value.keys) {
        final FieldModel<Object?>? classField =
            fieldClass.fields.firstWhereOrNull(
          (final FieldModel<Object?> field) => field.key == key,
        );
        if (classField != null) {
          values.add(
            '${classField.name}: '
            '${_renderDefault(fieldClass.name, classField, value[key])}',
          );
        }
      }
      String returnValue = '${renderConst ? 'const ' : ''}'
          '${fieldClass.name}(${values.join(', ')}';
      if (returnValue.length >
          80 - (renderConst ? '    this.${field.name} = ),'.length : 6)) {
        returnValue += ',';
      }
      return '$returnValue)';
    }
    return null;
  }

  String? _renderEnum<T extends Object?>(
    final String className,
    final FieldModel<T> field,
    final Object? value,
  ) {
    if (value is String) {
      String reference = field.reference.split('[').last.normalize();
      if (reference.endsWith(']')) {
        reference = reference.substring(0, reference.length - 1);
      }
      if (reference
          .split(',')
          .map((final String _) => _.trim())
          .contains(value)) {
        final String enumName =
            field.renderType(className, iterable: false, nullable: false);
        return '$enumName.'
            '${field.convert ? value.toCamelCase() : value.normalize()}';
      }
    }
    return null;
  }

  /// The converter of this field in a form of [String].
  String? renderConverter<T extends Object?>(
    final String className,
    final FieldModel<T> field,
  ) {
    switch (field.type) {
      case FieldType.$object:
        final String reference = field.reference.split('[').first.normalize();
        if (models.every(
          (final ClassModel<Object?> model) => model.key != reference,
        )) {
          return null;
        }
        final String $type =
            field.renderType(className, iterable: false, nullable: false);
        String converter =
            field.nullable ? 'optional${$type}' : $type.decapitalize();
        if (converter.endsWith('Model')) {
          converter = converter.substring(0, converter.length - 5);
        }
        return '${converter}Converter';

      case FieldType.$enum:
        final String $type =
            field.renderType(className, iterable: false, nullable: false);
        return field.nullable
            ? 'const OptionalEnumConverter<${$type}>(${$type}.values,)'
            : 'const EnumConverter<${$type}>(${$type}.values,)';

      case FieldType.$datetime:
        return field.nullable
            ? 'optionalDateTimeConverter'
            : 'dateTimeConverter';
      case FieldType.$timedelta:
        return field.nullable
            ? 'optionalDurationConverter'
            : 'durationConverter';
      case FieldType.$bool:
      case FieldType.$int:
      case FieldType.$float:
      case FieldType.$str:
        return null;

      case FieldType.$$object:
        final String reference = field.reference.split('[').first.normalize();
        if (models.every(
          (final ClassModel<Object?> model) => model.key != reference,
        )) {
          return null;
        }
        String $type =
            field.renderType(className, iterable: false, nullable: false);
        if ($type.endsWith('?')) {
          $type = $type.substring(0, $type.length - 1);
        }
        String converter =
            field.nullable ? 'optional${$type}' : $type.decapitalize();
        if (converter.endsWith('Model')) {
          converter = converter.substring(0, converter.length - 5);
        }
        converter += 'Converter';
        return field.nullable
            ? 'const OptionalIterableConverter<${$type}, '
                'Map<String, Object?>>($converter,)'
            : 'const IterableConverter<${$type}, '
                'Map<String, Object?>>($converter,)';

      case FieldType.$$enum:
        final String $type =
            field.renderType(className, iterable: false, nullable: false);
        final String converter = field.nullable
            ? 'OptionalEnumConverter<${$type}>(${$type}.values,)'
            : 'EnumConverter<${$type}>(${$type}.values,)';
        return field.nullable
            ? 'const OptionalIterableConverter<${$type}, String>($converter,)'
            : 'const IterableConverter<${$type}, String>($converter,)';

      case FieldType.$$datetime:
        return field.nullable
            ? 'const OptionalIterableConverter<DateTime, '
                'String>(dateTimeConverter)'
            : 'const IterableConverter<DateTime, String>(dateTimeConverter)';

      case FieldType.$$timedelta:
        return field.nullable
            ? 'const OptionalIterableConverter<Duration, '
                'num>(durationConverter)'
            : 'const IterableConverter<Duration, num>(durationConverter)';

      case FieldType.$$bool:
      case FieldType.$$int:
      case FieldType.$$float:
      case FieldType.$$str:
        return null;
    }
  }

  /// The serialization of this field in a form of [String].
  String renderSerialization<T extends Object?>(
    final String className,
    final FieldModel<T> field,
  ) {
    final String? converter = renderConverter(className, field);
    switch (field.type) {
      case FieldType.$object:
      case FieldType.$enum:
      case FieldType.$bool:
      case FieldType.$int:
      case FieldType.$float:
      case FieldType.$str:
      case FieldType.$datetime:
      case FieldType.$timedelta:
        return converter == null
            ? field.name
            : '$converter.toJson(${field.name})';

      case FieldType.$$object:
      case FieldType.$$enum:
      case FieldType.$$bool:
      case FieldType.$$int:
      case FieldType.$$float:
      case FieldType.$$str:
      case FieldType.$$datetime:
      case FieldType.$$timedelta:
        final String q = field.nullable ? '?' : '';
        return converter == null
            ? '${field.name}$q.toList(growable: false)'
            : '$converter.toJson(${field.name})$q.toList(growable: false)';
    }
  }

  /// The deserialization of this field in a form of [String].
  String renderDeserialization<T extends Object?>(
    final String className,
    final FieldModel<T> field, {
    final String map = 'map',
    final bool emptyRequiredIterables = true,
  }) {
    String? $type;
    final String? converter = renderConverter(className, field);
    switch (field.type) {
      case FieldType.$object:
        final String reference = field.reference.split('[').first.normalize();
        if (models
            .any((final ClassModel<Object?> model) => model.key == reference)) {
          $type = 'Map<String, Object?>';
        }
        continue single;

      case FieldType.$enum:
        $type = 'String';
        continue single;

      case FieldType.$datetime:
        $type = 'String';
        continue single;

      case FieldType.$timedelta:
        $type = 'num';
        continue single;

      single:
      case FieldType.$bool:
      case FieldType.$int:
      case FieldType.$float:
      case FieldType.$str:
        $type ??= field.renderType(className, iterable: false, nullable: false);
        final String single = field.nullable
            ? "$map['${field.key}'] ${$type != 'Object' ? 'as ${$type}?' : ''}"
            : "$map['${field.key}']! as ${$type}";
        return converter == null ? single : '$converter.fromJson($single)';

      case FieldType.$$object:
        final String reference = field.reference.split('[').first.normalize();
        if (models
            .any((final ClassModel<Object?> model) => model.key == reference)) {
          $type = 'Map<String, Object?>';
        }
        continue iterable;

      case FieldType.$$enum:
        $type = 'String';
        continue iterable;

      case FieldType.$$datetime:
        $type = 'String';
        continue iterable;

      case FieldType.$$timedelta:
        $type = 'num';
        continue iterable;

      iterable:
      case FieldType.$$bool:
      case FieldType.$$int:
      case FieldType.$$float:
      case FieldType.$$str:
        $type ??= field.renderType(className, iterable: false, nullable: false);
        final String iterable = field.nullable
            ? "($map['${field.key}'] as "
                'Iterable<Object?>?)?.whereType<${$type}>()'
            : emptyRequiredIterables
                ? "($map['${field.key}'] as Iterable<Object?>? ?? "
                    'const Iterable<Object?>.empty()).cast<${$type}>()'
                : "($map['${field.key}']! as "
                    'Iterable<Object?>).cast<${$type}>()';
        return converter == null ? iterable : '$converter.fromJson($iterable,)';
    }
  }
}

/// The possible type of the field in the model.
///
/// * Single prefix means field is non iterable.
/// * Double prefix means field is iterable.
enum FieldType {
  /// The field type for a single [Object].
  $object,

  /// The field type for a single [Enum].
  $enum,

  /// The field type for a single [bool].
  $bool,

  /// The field type for a single [int].
  $int,

  /// The field type for a single [double].
  $float,

  /// The field type for a single [String].
  $str,

  /// The field type for a single [DateTime].
  $datetime,

  /// The field type for a single [Duration].
  $timedelta,

  /// The field type for a list of [Object].
  $$object,

  /// The field type for a list of [Enum].
  $$enum,

  /// The field type for a list of [bool].
  $$bool,

  /// The field type for a list of [int].
  $$int,

  /// The field type for a list of [double].
  $$float,

  /// The field type for a list of [String].
  $$str,

  /// The field type for a list of [DateTime].
  $$datetime,

  /// The field type for a list of [Duration].
  $$timedelta;

  /// Return a [FieldType] from a [string].
  factory FieldType.fromString(String string) {
    string = string.trim().toLowerCase();
    if (string.startsWith('enum') || string.startsWith('flag')) {
      final Iterable<String> enums = string.split('[').last.split(',');
      if (enums.isEmpty || enums.length == 1 && enums.single == string) {
        throw FormatException(
          'The enum "$string" should have it\'s values specified.',
        );
      }
      return string.startsWith('enum') ? $enum : $$enum;
    }
    if (string.startsWith('date')) {
      string = string.replaceAll('datetime', 'date');
      string = string.replaceAll('date', 'datetime');
    }
    if (string.endsWith(']')) {
      string = string.split('[').first;
      if (string == 'date') {}
      if (!string.startsWith(r'$')) {
        string = '\$\$$string';
      }
    } else if (!string.startsWith(r'$')) {
      string = '\$$string';
    }
    return values.firstWhere(
      (final FieldType value) => value.name == string,
      orElse: () => string.startsWith(r'$$') ? $$object : $object,
    );
  }

  /// Return a [FieldType] from an [object].
  factory FieldType.fromObject(final Object? object) {
    if (object is Iterable<bool>) {
      return $$bool;
    } else if (object is Iterable<int>) {
      return $$int;
    } else if (object is Iterable<double>) {
      return $$float;
    } else if (object is Iterable<String>) {
      return $$str;
    } else if (object is Iterable<DateTime>) {
      return $$datetime;
    } else if (object is Iterable<Duration>) {
      return $$timedelta;
    } else if (object is Iterable<Enum>) {
      return $$enum;
    } else if (object is Iterable<Object?>) {
      return $$object;
    } else if (object is bool) {
      return $bool;
    } else if (object is int) {
      return $int;
    } else if (object is double) {
      return $float;
    } else if (object is String) {
      return $str;
    } else if (object is DateTime) {
      return $datetime;
    } else if (object is Duration) {
      return $timedelta;
    } else {
      return $object;
    }
  }

  /// Return an object [Type] from a [FieldType].
  Type get object {
    switch (this) {
      case $object:
        return Object;
      case $enum:
        return Enum;
      case $bool:
        return bool;
      case $int:
        return int;
      case $float:
        return double;
      case $str:
        return String;
      case $datetime:
        return DateTime;
      case $timedelta:
        return Duration;
      case $$object:
        return Iterable<Object>;
      case $$enum:
        return Iterable<Enum>;
      case $$bool:
        return Iterable<bool>;
      case $$int:
        return Iterable<int>;
      case $$float:
        return Iterable<double>;
      case $$str:
        return Iterable<String>;
      case $$datetime:
        return Iterable<DateTime>;
      case $$timedelta:
        return Iterable<Duration>;
    }
  }
}

/// The model to contain a model.
@sealed
@immutable
class ClassModel<T extends Object?> {
  /// The model to contain a model.
  const ClassModel(
    this.key, {
    required this.fields,
    final String? dartName,
    this.doc,
    final String? reference,
    final bool? toJson,
    final bool? convert,
  })  : assert(key != '', 'Key can not be empty'),
        dartName = dartName ?? '',
        reference = reference ?? '',
        toJson = toJson ?? true,
        convert = convert ?? true;

  /// The key of this field in the class.
  final String key;

  /// The name of this class.
  final String dartName;

  /// The documentation of this class.
  final String? doc;

  /// The reference to the name of this class.
  final String reference;

  /// If the `toJson` and `fromJson` serialization methods should also be
  /// generated.
  final bool toJson;

  /// If the class [name] should be converted using [StringUtils.toCamelCase].
  final bool convert;

  /// The fields of this class.
  final Iterable<FieldModel<T>> fields;

  /// The valid dart name of this field.
  String get name => dartName.isEmpty
      ? (convert ? key.toCamelCase().capitalize() : key.normalize())
      : dartName;

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is ClassModel<T> &&
          other.name == name &&
          other.doc == doc &&
          other.reference == reference &&
          other.toJson == toJson &&
          other.convert == convert &&
          IterableEquality<FieldModel<T>>().equals(other.fields, fields);

  @override
  int get hashCode =>
      name.hashCode ^
      doc.hashCode ^
      reference.hashCode ^
      toJson.hashCode ^
      convert.hashCode ^
      fields.hashCode;
}

/// The model to contain the options of each field of the [ClassModel].
@sealed
@immutable
class FieldModel<T extends Object?> {
  /// The model to contain the options of each field of the [ClassModel].
  const FieldModel(
    this.key,
    this.type, {
    final String? dartName,
    final String? reference,
    this.$default,
    this.doc,
    final bool? required,
    final bool? nullable,
    final bool? copy,
    final bool? serialize,
    final bool? compare,
    final bool? convert,
    final bool? convertClasses,
  })  : assert(key != '', 'Key can not be empty'),
        dartName = dartName ?? '',
        reference = reference ?? '',
        required = required ?? ($default == null && (!(nullable ?? false))),
        nullable = nullable ?? false,
        copy = copy ?? true,
        serialize = serialize ?? true,
        compare = compare ?? false,
        convert = convert ?? true,
        convertClasses = convertClasses ?? true;

  /// The key of this field in the class.
  final String key;

  /// The optional dart name of the [key].
  final String dartName;

  /// The type of this field.
  final FieldType type;

  /// The reference to the field type.
  final String reference;

  /// The default value of this field.
  final T? $default;

  /// The documentation for this field.
  final String? doc;

  /// If this field is required.
  final bool required;

  /// If this field is nullable.
  final bool nullable;

  /// If this field can be copied.
  final bool copy;

  /// If this field can be serialized.
  final bool serialize;

  /// If this field should participate in object comparison.
  final bool compare;

  /// If this field name should be converted using [StringUtils.toCamelCase].
  final bool convert;

  /// If other data types relatable to this field should be converted using
  /// [StringUtils.toCamelCase].
  final bool convertClasses;

  /// The valid dart name of this field.
  String get name => dartName.isEmpty
      ? (convert ? key.toCamelCase() : key.normalize())
      : dartName;

  /// The type of this field in a form of [String].
  String renderType(
    final String className, {
    final bool iterable = true,
    final bool? nullable,
  }) {
    String $type;
    if (reference.isNotEmpty &&
        (type == FieldType.$object || type == FieldType.$$object)) {
      $type = reference.split('.').last;
      if ($type.endsWith('[]')) {
        $type = $type.substring(0, $type.length - 2);
      }
      $type = convertClasses ? $type.toCamelCase() : $type.normalize();
      $type = type == FieldType.$$object ? 'Iterable<${$type}>' : $type;
    } else if (reference.isNotEmpty &&
        (type == FieldType.$enum || type == FieldType.$$enum)) {
      $type = convertClasses ? className.toCamelCase() : className.normalize();
      $type = $type.endsWith('Model')
          ? $type.substring(0, $type.length - 5)
          : $type;

      $type += (convert ? name.toCamelCase() : name.normalize()).capitalize();
      $type = type == FieldType.$$enum ? 'Iterable<${$type}>' : $type;
    } else {
      $type = type.object.toString();
    }

    if (!(nullable ?? this.nullable) && $type.endsWith('?')) {
      $type = $type.substring(0, $type.length - 1);
    }
    if (!iterable && $type.startsWith('Iterable<') && $type.endsWith('>')) {
      $type = $type.substring(9, $type.length - 1);
    }
    if ((nullable ?? this.nullable) && !$type.endsWith('?')) {
      $type = '${$type}?';
    }
    return $type;
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is FieldModel<T> &&
          other.key == key &&
          other.dartName == dartName &&
          other.type == type &&
          other.reference == reference &&
          other.$default == $default &&
          other.doc == doc &&
          other.required == required &&
          other.nullable == nullable &&
          other.copy == copy &&
          other.serialize == serialize &&
          other.compare == compare &&
          other.convert == convert;

  @override
  int get hashCode =>
      key.hashCode ^
      dartName.hashCode ^
      type.hashCode ^
      reference.hashCode ^
      $default.hashCode ^
      doc.hashCode ^
      required.hashCode ^
      nullable.hashCode ^
      copy.hashCode ^
      serialize.hashCode ^
      compare.hashCode ^
      convert.hashCode;
}

String? _renderBasic(final Object? value) {
  if (value is bool || value is num) {
    return value.toString();
  } else if (value is String) {
    return _renderString(value);
  } else if (value is Map<String, Object?>) {
    return json.encode(value);
  } else {
    return null;
  }
}

String? _renderString(final Object? value) {
  if (value is! String) {
    return null;
  } else if (value.contains('"') && value.contains("'")) {
    return "'${value.replaceAll("'", r"\'")}'";
  } else if (value.contains("'")) {
    return '"$value"';
  } else {
    return "'$value'";
  }
}

String? _renderDateTime(
  final Object? value, {
  final bool renderConst = true,
}) {
  final DateTime dateTime;
  if (value is DateTime) {
    dateTime = value;
  } else if (value is String) {
    num? seconds = num.tryParse(value);
    if (seconds == null) {
      dateTime = DateTime.parse(value);
    } else {
      final String fraction = seconds.toStringAsFixed(6).split('.').last;
      seconds = seconds.truncate();
      if (fraction.length <= 3) {
        final int millis =
            int.parse(seconds.toStringAsFixed(0) + fraction.padRight(3));
        dateTime = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      } else {
        final int micros =
            int.parse(seconds.toStringAsFixed(0) + fraction.padRight(6));
        dateTime = DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
      }
    }
  } else {
    return null;
  }

  final Iterable<int> values = <int>[
    dateTime.year,
    if (dateTime.month != 0 ||
        dateTime.day != 0 ||
        dateTime.hour != 0 ||
        dateTime.minute != 0 ||
        dateTime.second != 0 ||
        dateTime.millisecond != 0 ||
        dateTime.microsecond != 0)
      dateTime.month,
    if (dateTime.day != 0 ||
        dateTime.hour != 0 ||
        dateTime.minute != 0 ||
        dateTime.second != 0 ||
        dateTime.millisecond != 0 ||
        dateTime.microsecond != 0)
      dateTime.day,
    if (dateTime.hour != 0 ||
        dateTime.minute != 0 ||
        dateTime.second != 0 ||
        dateTime.millisecond != 0 ||
        dateTime.microsecond != 0)
      dateTime.hour,
    if (dateTime.minute != 0 ||
        dateTime.second != 0 ||
        dateTime.millisecond != 0 ||
        dateTime.microsecond != 0)
      dateTime.minute,
    if (dateTime.second != 0 ||
        dateTime.millisecond != 0 ||
        dateTime.microsecond != 0)
      dateTime.second,
    if (dateTime.millisecond != 0 || dateTime.microsecond != 0)
      dateTime.millisecond,
    if (dateTime.microsecond != 0) dateTime.microsecond
  ];
  return '${renderConst ? 'const ' : ''}DateTime(${values.join(', ')})';
}

String? _renderDuration(
  final Object? value, {
  final bool renderConst = true,
}) {
  final Duration duration;
  if (value is Duration) {
    duration = value;
  } else if (value is num) {
    final int seconds;
    final int milliseconds;
    final int microseconds;
    if (value is int) {
      seconds = value;
      milliseconds = microseconds = 0;
    } else if (value is double) {
      final Iterable<String> parts = value.toStringAsFixed(6).split('.');
      seconds = int.parse(parts.first);
      milliseconds = int.parse(parts.last.substring(0, 3));
      microseconds = int.parse(parts.last.substring(3));
    } else {
      return null;
    }
    duration = Duration(
      seconds: seconds,
      milliseconds: milliseconds,
      microseconds: microseconds,
    );
  } else {
    return null;
  }

  final String micros = duration.inMicroseconds.toString();
  final int seconds =
      micros.length > 6 ? int.parse(micros.substring(0, micros.length - 6)) : 0;
  final int milliseconds = micros.length > 3
      ? ((final String micros) => int.parse(
            micros.substring(micros.length - 6, micros.length - 3),
          ))(micros.padLeft(7))
      : 0;
  final int microseconds = int.parse(
    micros.padLeft(4).substring(micros.padLeft(4).length - 3),
  );
  final Iterable<String> values = <String>[
    if (seconds != 0) 'seconds: $seconds',
    if (milliseconds != 0) 'milliseconds: $milliseconds',
    if (microseconds != 0) 'microseconds: $microseconds'
  ];
  return values.isEmpty
      ? 'Duration.zero'
      : '${renderConst ? 'const ' : ''}Duration(${values.join(', ')})';
}
