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
    final bool? includeNullFields,
  })  : assignFieldTypes = assignFieldTypes ?? true,
        includeNullFields = includeNullFields ?? true;

  /// If the field names should be converted using [StringUtils.toCamelCase].
  final bool? convertClassNames;

  /// If the field names should be converted using [StringUtils.toCamelCase].
  final bool? convertFieldNames;

  /// If the unknown field types should be resolved from default values using
  /// [FieldType.fromObject].
  final bool assignFieldTypes;

  /// If the fields with null values should be added in `toMap`.
  final bool includeNullFields;

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
          final Object? deserialize = fieldEntry.value['deserialize'];
          final Object? equality = fieldEntry.value['equality'];
          final Object? toString = fieldEntry.value['to_string'];
          final Object? checkType = fieldEntry.value['check_type'];
          final Object? checkTypeDefault =
              fieldEntry.value['check_type_default'];
          final Object? castIterable = fieldEntry.value['cast_iterable'];
          fields.add(
            FieldModel<Object?>(
              fieldEntry.key,
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
              serialize: serialize is bool
                  ? serialize
                      ? includeNullFields
                          ? FieldSerialization.all
                          : FieldSerialization.nonNull
                      : FieldSerialization.none
                  : serialize is String
                      ? FieldSerialization.values.firstWhereOrNull(
                          (final FieldSerialization $serialize) =>
                              $serialize.name == serialize.trim(),
                        )
                      : !includeNullFields
                          ? FieldSerialization.nonNull
                          : null,
              deserialize: deserialize is bool ? deserialize : null,
              equality: equality is bool
                  ? (equality ? FieldEquality.ordered : FieldEquality.none)
                  : equality is String
                      ? FieldEquality.values.firstWhereOrNull(
                          (final FieldEquality $equality) =>
                              $equality.name == equality.trim(),
                        )
                      : null,
              toString: toString is bool ? toString : null,
              convert: convertFieldNames,
              convertClasses: convertClassNames,
              checkType: checkType is bool ? checkType : null,
              checkTypeDefault: checkTypeDefault ??
                  (!fieldEntry.value.containsKey('check_type_default')
                      ? Object
                      : null),
              castIterable: castIterable is bool ? castIterable : null,
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
    super.includeNullFields,
    final Iterable<String>? imports,
  }) : imports = imports ??
            const <String>[
              'package:json_converters_lite/json_converters_lite.dart'
            ];

  /// The iterable with imports to be used in [generateHeader].
  final Iterable<String> imports;

  bool get _isDirectoryExport {
    final FileSystemEntityType exportType =
        FileSystemEntity.typeSync(exportPath);
    return exportType == FileSystemEntityType.directory ||
        exportType == FileSystemEntityType.notFound &&
            extension(exportPath).isEmpty;
  }

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
      if (_isDirectoryExport) {
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
    final String output = buffer.toString();
    try {
      return formatter.format(output, uri: exportPath);
    } on Exception catch (_) {
      return output;
    }
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
      )
      ..writeDoc('')
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

    if (_isDirectoryExport) {
      /// Handle model relationships with relative imports.
      final Map<String, int> relativeImports = <String, int>{};
      for (final ClassModel<T> model in models) {
        if (model.reference.isEmpty) {
          continue;
        }
        final List<String> nameParts =
            model.reference.split('.').reversed.skip(1).toList(growable: false);
        for (final FieldModel<T> field in model.fields) {
          if ((field.reference.isEmpty) ||
              (field.type != FieldType.$object &&
                  field.type != FieldType.$$object)) {
            continue;
          }
          final List<String> parts = field.reference
              .split('.')
              .reversed
              .skip(1)
              .toList(growable: false);
          if (parts.isEmpty ||
              const IterableEquality<String>().equals(nameParts, parts)) {
            continue;
          }

          int index,
              dotCount = 0; // ignore: avoid_multiple_declarations_per_line
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
            '${parts.first}.dart'
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
            ..writeDoc('The `$value` property of this [$enumName].', indent: 2)
            ..write(field.convert ? value.toCamelCase() : value.normalize())
            ..writeln(index < referenceValues.length - 1 ? ',' : ';');
        }
        buffer
          ..writeln()
          ..writeDoc('The name of the enum value.', indent: 2)
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
      ..writeDoc(doc, indent: 2)
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
              final String $default = _renderDefault(model.name, field);
              if (field.required || !field.nullable && $default.isEmpty) {
                return 'required this.${field.name}';
              } else if ($default.isNotEmpty) {
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
      buffer
        ..writeDoc(
          field.doc == null
              ? 'The `${field.key}` property of this [${model.name}].'
              : field.doc!,
          indent: 2,
        )
        ..writeln('final ${field.renderType(model.name)} ${field.name};');
    }

    /// `copyWith`
    if (model.fields.any((final FieldModel<T> field) => field.copy)) {
      buffer
        ..writeDoc('Return the copy of this model.', indent: 2)
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
        ..writeDoc(
          'Return the copy of this model with nullable fields.',
          indent: 2,
        )
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

    buffer

      /// `toMap`
      ..writeDoc(
        'Convert this model to map with string keys.',
        indent: 2,
      )
      ..writeFunction(
        'Map<String, Object?> toMap',
        const Iterable<String>.empty(),
        bodyConstructor: '<String, Object?>{',
        bodyFields: <String>[
          for (final FieldModel<T> field in model.fields)
            if (field.serialize != FieldSerialization.none)
              (final FieldModel<T> field) {
                final String $field = "'${field.key}': "
                    '${renderSerialization(model.name, field)}';
                return field.serialize == FieldSerialization.nonNull &&
                        field.nullable
                    ? 'if (${field.name} != null) ${$field}'
                    : $field;
              }(field)
        ],
      )

      /// `fromMap`
      ..writeDoc('Convert the map with string keys to this model.', indent: 2)
      ..writeFunction(
        'factory ${model.name}.fromMap',
        <String>['final Map<String, Object?> map'],
        bodyConstructor: model.name,
        bodyFields: <String>[
          for (final FieldModel<T> field in model.fields)
            if (field.deserialize || field.required)
              '${field.name}: ${renderDeserialization(model.name, field)}'
        ],
      );

    if (model.toJson) {
      buffer

        /// `toJson`
        ..writeDoc('Convert this model to a json string.', indent: 2)
        ..writeFunction(
          'String toJson',
          const Iterable<String>.empty(),
          bodyConstructor: 'json.encode',
          bodyFields: <String>['toMap()'],
        )

        /// `fromJson`
        ..writeDoc('Convert the json string to this model.', indent: 2)
        ..writeFunction(
          'factory ${model.name}.fromJson',
          <String>['final String source'],
          bodyConstructor: '${model.name}.fromMap',
          bodyFields: <String>['json.decode(source)! as Map<String, Object?>'],
        );
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

    /// `equality`
    if (model.fields.any(
      (final FieldModel<T> field) => field.equality != FieldEquality.none,
    )) {
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
              if (field.equality != FieldEquality.none)
                if (field.type.name.startsWith(r'$$'))
                  (final FieldModel<T> field) {
                    final String equality =
                        field.equality == FieldEquality.ordered
                            ? 'IterableEquality'
                            : 'UnorderedIterableEquality';
                    return 'const $equality'
                        '<${field.renderType(model.name, iterable: false)}>()'
                        '.equals(other.${field.name}, ${field.name},)';
                  }(field)
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
              if (field.equality != FieldEquality.none) '${field.name}.hashCode'
          ],
          separator: ' ^ ',
        );
    }

    /// `toString`
    buffer
      ..writeln()
      ..writeln('@override')
      ..writeFunction(
        'String toString',
        <String>[],
        bodyConstructor:
            "'${model.name.startsWith(r'$') ? r'\' : ''}${model.name}(",
        bodyFields: <String>[
          for (final FieldModel<T> field in model.fields)
            if (field.$toString) '${field.name}: \$${field.name}'
        ],
      )
      ..writeln('}');
  }

  /// The default value of this [field] in a form of [String].
  String _renderDefault<T extends Object?>(
    final String className,
    final FieldModel<T> field, [
    final Object? $value = Object,
  ]) {
    final Object? value = $value == Object ? field.$default : $value;
    if (value == null) {
      return '';
    }
    final String Function(Object? value) convert;
    switch (field.type) {
      case FieldType.$boolean:
        return value is bool ? value.toString() : '';
      case FieldType.$integer:
        return value is int ? value.toString() : '';
      case FieldType.$float:
        return value is double ? value.toString() : '';
      case FieldType.$string:
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

      case FieldType.$$boolean:
        convert =
            (final Object? value) => value is bool ? value.toString() : '';
        break;
      case FieldType.$$integer:
        convert = (final Object? value) => value is int ? value.toString() : '';
        break;
      case FieldType.$$float:
        convert =
            (final Object? value) => value is double ? value.toString() : '';
        break;
      case FieldType.$$string:
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
    final Iterable<String> values;
    return iterable.isEmpty ||
            (values = iterable.map(convert).where((final _) => _.isNotEmpty))
                .isEmpty
        ? 'const Iterable<${$type}>.empty()'
        : 'const <${$type}>[${values.join(',')}]';
  }

  String _renderModel<T extends Object?>(
    final String className,
    final FieldModel<T> field,
    final Object? value, {
    final bool renderConst = true,
  }) {
    if (value is! Map<String, Object?>) {
      return '';
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
    return '';
  }

  String _renderEnum<T extends Object?>(
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
    return '';
  }

  /// The converter of this field in a form of [String].
  String renderConverter<T extends Object?>(
    final String className,
    final FieldModel<T> field,
  ) {
    switch (field.type) {
      case FieldType.$object:
        final String reference = field.reference.split('[').first.normalize();
        if (models.every(
          (final ClassModel<Object?> model) => model.key != reference,
        )) {
          return '';
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
      case FieldType.$boolean:
      case FieldType.$integer:
      case FieldType.$float:
      case FieldType.$string:
        return '';

      case FieldType.$$object:
        final String reference = field.reference.split('[').first.normalize();
        if (models.every(
          (final ClassModel<Object?> model) => model.key != reference,
        )) {
          return '';
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

      case FieldType.$$boolean:
      case FieldType.$$integer:
      case FieldType.$$float:
      case FieldType.$$string:
        return '';
    }
  }

  /// The serialization of this field in a form of [String].
  String renderSerialization<T extends Object?>(
    final String className,
    final FieldModel<T> field,
  ) {
    final String converter = renderConverter(className, field);
    switch (field.type) {
      case FieldType.$object:
      case FieldType.$enum:
      case FieldType.$boolean:
      case FieldType.$integer:
      case FieldType.$float:
      case FieldType.$string:
      case FieldType.$datetime:
      case FieldType.$timedelta:
        return converter.isEmpty
            ? field.name
            : '$converter.toJson(${field.name})';

      case FieldType.$$object:
      case FieldType.$$enum:
      case FieldType.$$boolean:
      case FieldType.$$integer:
      case FieldType.$$float:
      case FieldType.$$string:
      case FieldType.$$datetime:
      case FieldType.$$timedelta:
        final String q = field.nullable ? '?' : '';
        return converter.isEmpty
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
    final String converter = renderConverter(className, field);
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
      case FieldType.$boolean:
      case FieldType.$integer:
      case FieldType.$float:
      case FieldType.$string:
        $type ??= field.renderType(className, iterable: false, nullable: false);
        String single = "$map['${field.key}']${field.nullable ? '' : '!'}";
        if ($type != Object().runtimeType.toString()) {
          if (field.nullable && field.checkType) {
            final Object? $default = field.checkTypeDefault ??
                (field.required ? field.$default : null);
            String $$default = _renderDefault(className, field, $default);
            if ($$default.isEmpty) {
              $$default = null.toString();
            }
            single = '$single is ${$type} ? '
                '$single! as ${$type} : ${$$default}';
          } else {
            single += ' as ${$type}${field.nullable ? '?' : ''}';
          }
        }
        return converter.isEmpty ? single : '$converter.fromJson($single)';

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
      case FieldType.$$boolean:
      case FieldType.$$integer:
      case FieldType.$$float:
      case FieldType.$$string:
        $type ??= field.renderType(className, iterable: false, nullable: false);
        String iterable = "$map['${field.key}']${field.nullable ? '' : '!'}";
        if (field.nullable && field.checkType) {
          final Object? $default = field.checkTypeDefault ??
              (field.required ? field.$default : null);
          String $$default = _renderDefault(className, field, $default);
          if ($$default.isEmpty) {
            $$default = null.toString();
          }
          iterable = '$iterable is Iterable<Object?> ? '
              '$iterable! as Iterable<Object?> : ${$$default}';
        } else {
          iterable += ' as Iterable<Object?>${field.nullable ? '?' : ''}';
        }
        if ($type != Object().runtimeType.toString()) {
          iterable = '($iterable)${field.nullable ? '?' : ''}.'
              '${field.castIterable ? 'cast' : 'whereType'}<${$type}>()';
        }
        if (field.nullable && emptyRequiredIterables) {
          iterable += ' ?? const Iterable<${$type}>.empty()';
        }
        return converter.isEmpty ? iterable : '$converter.fromJson($iterable,)';
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
  $boolean,

  /// The field type for a single [int].
  $integer,

  /// The field type for a single [double].
  $float,

  /// The field type for a single [String].
  $string,

  /// The field type for a single [DateTime].
  $datetime,

  /// The field type for a single [Duration].
  $timedelta,

  /// The field type for a list of [Object].
  $$object,

  /// The field type for a list of [Enum].
  $$enum,

  /// The field type for a list of [bool].
  $$boolean,

  /// The field type for a list of [int].
  $$integer,

  /// The field type for a list of [double].
  $$float,

  /// The field type for a list of [String].
  $$string,

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
      return $$boolean;
    } else if (object is Iterable<int>) {
      return $$integer;
    } else if (object is Iterable<double>) {
      return $$float;
    } else if (object is Iterable<String>) {
      return $$string;
    } else if (object is Iterable<DateTime>) {
      return $$datetime;
    } else if (object is Iterable<Duration>) {
      return $$timedelta;
    } else if (object is Iterable<Enum>) {
      return $$enum;
    } else if (object is Iterable<Object?>) {
      return $$object;
    } else if (object is bool) {
      return $boolean;
    } else if (object is int) {
      return $integer;
    } else if (object is double) {
      return $float;
    } else if (object is String) {
      return $string;
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
      case $boolean:
        return bool;
      case $integer:
        return int;
      case $float:
        return double;
      case $string:
        return String;
      case $datetime:
        return DateTime;
      case $timedelta:
        return Duration;
      case $$object:
        return Iterable<Object>;
      case $$enum:
        return Iterable<Enum>;
      case $$boolean:
        return Iterable<bool>;
      case $$integer:
        return Iterable<int>;
      case $$float:
        return Iterable<double>;
      case $$string:
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

/// The type of the [FieldModel.serialize].
enum FieldSerialization {
  /// Field should not be serialized.
  none,

  /// Field should be serialized if non-null only.
  nonNull,

  /// Field should be serialized anyway.
  all;

  /// The `snake_case` name of this enum.
  String get name {
    switch (this) {
      case FieldSerialization.none:
        return 'none';
      case FieldSerialization.nonNull:
        return 'non_null';
      case FieldSerialization.all:
        return 'all';
    }
  }
}

/// The type of the [FieldModel.equality].
enum FieldEquality {
  /// Equality should not be added.
  none,

  /// Equality should be added as [IterableEquality] for iterable fields and
  /// [==] for reqular ones.
  ordered,

  /// Equality should be added as [UnorderedIterableEquality] for iterable
  /// fields and [==] for reqular ones.
  unordered;
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
    final FieldSerialization? serialize,
    final bool? deserialize,
    final bool? compare,
    final FieldEquality? equality,
    final bool? toString,
    final bool? convert,
    final bool? convertClasses,
    final bool? checkType,
    this.checkTypeDefault,
    final bool? castIterable,
  })  : assert(key != '', 'Key can not be empty'),
        dartName = dartName ?? '',
        reference = reference ?? '',
        required = required ?? ($default == null && !(nullable ?? false)),
        nullable = nullable ?? false,
        copy = copy ?? true,
        serialize = serialize ?? FieldSerialization.all,
        deserialize = deserialize ?? true,
        compare = compare ?? false,
        equality = equality ?? FieldEquality.ordered,
        $toString = toString ?? true,
        convert = convert ?? true,
        convertClasses = convertClasses ?? true,
        checkType = checkType ?? true,
        castIterable = castIterable ?? false;

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

  /// The type of the [FieldSerialization] that should apply to this field.
  final FieldSerialization serialize;

  /// If this field can be deserialized.
  final bool deserialize;

  /// If this field should participate in object comparison.
  final bool compare;

  /// The type of the [FieldEquality] that should apply to this field.
  final FieldEquality equality;

  /// If this field should be added in object [toString] method.
  final bool $toString;

  /// If this field name should be converted using [StringUtils.toCamelCase].
  final bool convert;

  /// If other data types relatable to this field should be converted using
  /// [StringUtils.toCamelCase].
  final bool convertClasses;

  /// If value type should be checked on [deserialize] and replaced for
  /// [checkTypeDefault] if needed.
  final bool checkType;

  /// The default value of this field to set if [checkType] resolves to false.
  final Object? checkTypeDefault;

  /// If iterable value type should be processed on [deserialize] using
  /// [Iterable.cast] instead of [Iterable.whereType].
  final bool castIterable;

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
          other.deserialize == deserialize &&
          other.compare == compare &&
          other.equality == equality &&
          other.$toString == $toString &&
          other.convert == convert &&
          other.convertClasses == convertClasses &&
          other.checkType == checkType &&
          other.checkTypeDefault == checkTypeDefault &&
          other.castIterable == castIterable;

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
      deserialize.hashCode ^
      compare.hashCode ^
      equality.hashCode ^
      $toString.hashCode ^
      convert.hashCode ^
      convertClasses.hashCode ^
      checkType.hashCode ^
      checkTypeDefault.hashCode ^
      castIterable.hashCode;
}

String _renderBasic(final Object? value) {
  if (value is bool || value is num) {
    return value.toString();
  } else if (value is String) {
    return _renderString(value);
  } else if (value is Map<Object?, Object?>) {
    return 'const <Object?, Object?>${json.encode(value)}';
  } else if (value is Iterable<Object?>) {
    return 'const <Object?>${json.encode(value)}';
  } else {
    return '';
  }
}

String _renderString(final Object? value) {
  if (value is! String) {
    return '';
  } else if (value.contains('"') && value.contains("'")) {
    return "'${value.replaceAll("'", r"\'")}'";
  } else if (value.contains("'")) {
    return '"$value"';
  } else {
    return "'$value'";
  }
}

String _renderDateTime(
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
    return '';
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

String _renderDuration(
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
      return '';
    }
    duration = Duration(
      seconds: seconds,
      milliseconds: milliseconds,
      microseconds: microseconds,
    );
  } else {
    return '';
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
