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

/// Build runner static entry point for [AssetsGenerator].
AssetsGenerator assetsGeneratorBuilder(final BuilderOptions options) =>
    AssetsCommand().get(options.config);

/// The command used to run the [AssetsGenerator].
class AssetsCommand extends GeneratorCommand<AssetsGenerator> {
  /// The command used to run the [AssetsGenerator].
  AssetsCommand() : super('./assets.g.dart') {
    argParser
      ..addOption(
        'base-name',
        abbr: 'n',
        help: 'The name of the generated class. Defaults to `Assets`.',
      )
      ..addFlag(
        'convert',
        abbr: 'c',
        help: 'If the file names should be converted to camel case. Disabling '
            'this option will prevent any changes to be made to the file '
            'names. Be certain to pass valid Dart names or the generation will '
            'be likely to fail. Defaults to `true`.',
        defaultsTo: null,
      );
  }

  @override
  String get name => 'assets';

  @override
  String get description => 'Migrates file structure into Dart classes.';

  @override
  AssetsGenerator get([final Map<String, Object?>? options]) {
    final Object? importPath =
        options?['import_path'] ?? argResults?['import-path'] as Object?;
    final Object? exportPath =
        options?['export_path'] ?? argResults?['export-path'] as Object?;
    final Object? exportEncoding = options?['export_encoding'] ??
        argResults?['export-encoding'] as Object?;
    final Object? baseName =
        options?['base_name'] ?? argResults?['base-name'] as Object?;
    final Object? convert =
        options?['convert'] ?? argResults?['convert'] as Object?;
    if (importPath is! String || importPath.isEmpty) {
      throw const FormatException('The import path is not provided.');
    } else if (exportPath is! String || exportPath.isEmpty) {
      throw const FormatException('The export path is not provided.');
    } else {
      return DartAssetsGenerator(
        importPath: importPath,
        exportPath: exportPath,
        exportEncoding: exportEncoding is String
            ? Encoding.getByName(exportEncoding)
            : null,
        baseName: baseName is String && baseName.isNotEmpty ? baseName : null,
        convert: convert is bool ? convert : null,
      );
    }
  }
}

/// The architecture of the
/// {@template assets}
/// [Assets](https://docs.flutter.dev/development/ui/assets-and-images)
/// {@endtemplate}
/// generator.
@immutable
abstract class AssetsGenerator extends BaseGenerator {
  /// The architecture of the
  /// {@macro assets}
  /// generator.
  AssetsGenerator({
    required super.importPath,
    required super.exportPath,
    super.exportEncoding,
    super.formatter,
    final String? baseName,
    final bool? convert,
  })  : baseName = baseName ?? 'Assets',
        convert = convert ?? true,
        super(loadFiles: false);

  /// The name of the base
  /// {@macro assets}
  /// class.
  final String baseName;

  /// If the
  /// {@macro assets}
  /// names should be converted using [StringUtils.toCamelCase].
  final bool convert;

  /// The
  /// {@macro assets}
  /// path graph.
  final Map<String, Object?> assetsMap = <String, Object?>{};

  /// Return the class name from the base [name] and [keys].
  String className(
    final String name, [
    final Iterable<String> keys = const Iterable<String>.empty(),
  ]) {
    final List<String> $keys = <String>[...keys, name];
    if (!convert && $keys.length == 1) {
      $keys.insert(0, $keys.removeAt(0).normalize());
    }
    return $keys
        .map(
          (final String key) =>
              (convert ? key.toCamelCase() : key).capitalize(),
        )
        .join();
  }

  @override
  Map<String, List<String>> get buildExtensions => <String, List<String>>{
        r'$package$': <String>[exportPath],
      };

  @override
  @mustCallSuper
  FutureOr<void> build([final BuildStep? buildStep]) async {
    await super.build(buildStep);
    assetsMap.clear();
    assetsMap[''] = importPath;

    Iterable<String> baseSegments = split(canonicalize(importPath));
    final List<String> sameSegments = fileMap.keys.sameSegments.toList();
    if (!const IterableEquality<String>().equals(
      baseSegments,
      sameSegments.length > baseSegments.length
          ? sameSegments.sublist(0, baseSegments.length)
          : sameSegments,
    )) {
      baseSegments = const <String>[];
    }
    for (final String inputPath in fileMap.keys) {
      Map<String, Object?> nestedAssetsMap = assetsMap;
      final List<String> segments =
          split(inputPath).sublist(baseSegments.length);
      for (int index = 0; index < segments.length; index++) {
        final String segment = segments.elementAt(index);
        if (index == segments.length - 1) {
          nestedAssetsMap[segment] =
              posix.join(importPath, posix.joinAll(segments));
        } else {
          nestedAssetsMap.putIfAbsent(segment, () => <String, Object?>{});
          nestedAssetsMap = nestedAssetsMap[segment]! as Map<String, Object?>;
          if (!nestedAssetsMap.containsKey('')) {
            nestedAssetsMap[''] = posix.joinAll(<String>[
              importPath,
              ...segments.sublist(0, segments.length - index - 1)
            ]);
          }
        }
      }
    }
  }
}

/// The
/// {@macro assets}
/// generator for dart.
@immutable
class DartAssetsGenerator extends AssetsGenerator {
  /// The
  /// {@macro assets}
  /// generator for dart.
  DartAssetsGenerator({
    required super.importPath,
    required super.exportPath,
    super.exportEncoding,
    super.formatter,
    super.baseName,
    super.convert,
  });

  @override
  @mustCallSuper
  FutureOr<void> build([final BuildStep? buildStep]) async {
    await super.build(buildStep);
    if (assetsMap.isEmpty) {
    } else if (buildStep != null) {
      await buildStep.writeAsString(
        buildStep.allowedOutputs.single,
        buildStep.trackStage(
          'Generate $exportPath.',
          () => generate(assetsMap),
        ),
        encoding: exportEncoding,
      );
    } else {
      final File file = File(exportPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        generate(assetsMap),
        encoding: exportEncoding,
        mode: FileMode.writeOnly,
        flush: true,
      );
    }
  }

  /// Generate a single
  /// {@macro assets}
  /// file from [assetsMap].
  String generate(final Map<String, Object?> assetsMap) {
    final StringBuffer buffer = StringBuffer();
    generateHeader(buffer, assetsMap);
    generateModel(buffer, assetsMap, baseName);
    final String output = buffer.toString();
    try {
      return formatter.format(output, uri: exportPath);
    } on Exception catch (_) {
      return output;
    }
  }

  /// Generate a header for the
  /// {@macro assets}
  /// file.
  void generateHeader(
    final StringBuffer buffer,
    final Map<String, Object?> assetsMap,
  ) {
    buffer
      ..writeDoc(
        (<String>['missing_whitespace_between_adjacent_strings']..sort())
            .join(' '),
        prefix: '// ignore_for_file: ',
        separator: ', ',
      )
      ..writeDoc('')
      ..writeDoc(
        'This file is used for `${assetsMap['']! as String}` folder file '
        'structure generation.',
      )
      ..writeDoc('')
      ..writeDoc('Modify this file at your own risk!')
      ..writeDoc('')
      ..writeDoc('See: https://pub.dev/packages/generators_lite#assets-generator')
      ..writeDoc('')
      ..writeImports(<String>['package:meta/meta.dart']);
  }

  /// Generate a
  /// {@template model}
  /// model nested from [keys].
  /// {@endtemplate}
  void generateModel(
    final StringBuffer buffer,
    final Map<String, Object?> assetsMap,
    final String name, {
    final Iterable<String> keys = const Iterable<String>.empty(),
  }) {
    final String cls = className(name, keys);
    if (keys.isEmpty) {
      String className = cls.decapitalize();
      className = className == cls ? '\$$className' : className;
      final Iterable<String> dirParts = posix.split(assetsMap['']! as String);
      buffer
        ..writeDoc(
          'This is a generated file structure of the '
          '`${dirParts.join('`/`')}` folder.',
        )
        ..writeDoc('')
        ..writeDoc(
          'See: https://pub.dev/packages/generators_lite#icon-fonts-generator',
        )
        ..writeln('const $cls $className = $cls._();')
        ..writeln();
    }
    final Map<String, Object?> map = keys.skip(1).isEmpty && name == baseName
        ? assetsMap
        : assetsMap.getNested(<String>[...keys.skip(1), name])!
            as Map<String, Object?>;
    final String parentName = keys.isNotEmpty
        ? className(keys.last, keys.toList()..removeLast())
        : '';
    final Iterable<String> dirParts = posix.split(map['']! as String);
    buffer
      ..writeDoc(
        'The file structure of the `${dirParts.join('`/`')}` folder.',
      )
      ..writeln('@sealed')
      ..writeln('@immutable')
      ..writeln('class $cls {')

      /// `Constructor`
      ..writeFunction(
        'const ${className(name, keys)}._',
        <String>[if (parentName.isNotEmpty) 'final $parentName _'],
      );

    /// `Fields`
    generateFields(buffer, assetsMap, name, keys: keys);

    buffer

      /// `== operator`
      ..writeln()
      ..writeln('@override')
      ..writeFunction(
        'bool operator ==',
        <String>['final Object? other'],
        bodyFields: <String>[
          'identical(this, other) || other is ${className(name, keys)}',
          ...<String>[
            for (final MapEntry<String, Object?> entry in map.entries)
              if (entry.key.isNotEmpty) basenameWithoutExtension(entry.key),
          ]
              .map((final _) => convert ? _.toCamelCase() : _.normalize())
              .map((final String key) => 'other.$key == $key')
        ],
        separator: ' && ',
      )

      /// `hashCode`
      ..writeln()
      ..writeln('@override')
      ..writeFunction(
        'int get hashCode',
        <String>[],
        bodyFields: <String>[
          for (final MapEntry<String, Object?> entry in map.entries)
            if (entry.key.isNotEmpty) basenameWithoutExtension(entry.key)
        ]
            .map((final _) => convert ? _.toCamelCase() : _.normalize())
            .map((final String key) => '$key.hashCode'),
        separator: ' ^ ',
      )
      ..writeln('}');
    for (final MapEntry<String, Object?> entry in map.entries) {
      if (entry.key.isNotEmpty && entry.value is Map<String, Object?>) {
        generateModel(
          buffer,
          assetsMap,
          entry.key,
          keys: <String>[...keys, name],
        );
      }
    }
  }

  /// Generate the fields for the
  /// {@macro model}
  void generateFields(
    final StringBuffer buffer,
    final Map<String, Object?> assetsMap,
    final String name, {
    final Iterable<String> keys = const Iterable<String>.empty(),
  }) {
    final Map<String, List<String>> uniqueKeys = <String, List<String>>{};
    final Map<String, Object?> map = keys.skip(1).isEmpty && name == baseName
        ? assetsMap
        : assetsMap.getNested(<String>[...keys.skip(1), name])!
            as Map<String, Object?>;
    for (final MapEntry<String, Object?> entry in map.entries) {
      if (entry.key.isNotEmpty && entry.value is String) {
        String key = basenameWithoutExtension(entry.key);
        key = convert ? key.toCamelCase() : key.normalize();
        final String $extension = extension(entry.key);
        while ((uniqueKeys[key] ?? const <String>[]).contains($extension)) {
          key = '\$$key';
        }
        uniqueKeys[key] = <String>[...?uniqueKeys[key], $extension];
      }
    }
    final Map<String, int> uniqueKeysLength = <String, int>{
      for (final MapEntry<String, List<String>> entry in uniqueKeys.entries)
        entry.key: entry.value.length
    };

    for (final MapEntry<String, Object?> entry in map.entries) {
      final Object? value = entry.value;
      if (entry.key.isEmpty) {
      } else if (value is Map<String, Object?>) {
        final String key =
            convert ? entry.key.toCamelCase() : entry.key.normalize();
        final String cls = className(entry.key, <String>[...keys, name]);
        final Map<String, Object?> nestedMap =
            map[entry.key]! as Map<String, Object?>;
        final String nestedMapPath = nestedMap['']! as String;
        final Iterable<String> dirParts =
            posix.split(posix.dirname(nestedMapPath));
        buffer
          ..writeDoc(
            'The path to the `${posix.basename(nestedMapPath)}` folder '
            'in `${dirParts.join('`/`')}`.',
          )
          ..writeln('$cls get $key => $cls._(this);');
      } else if (value is String) {
        String key = basenameWithoutExtension(entry.key);
        key = convert ? key.toCamelCase() : key.normalize();
        final String $extension = extension(entry.key);
        while (!uniqueKeys[key]!.contains($extension)) {
          key = '\$$key';
        }
        uniqueKeys[key]!.remove($extension);
        if (uniqueKeysLength[key]! > 1) {
          key = basename(entry.key);
          key =
              convert ? key.toCamelCase() : key.replaceAll('.', '').normalize();
        }
        final Iterable<String> dirParts = posix.split(posix.dirname(value));
        buffer
          ..writeDoc(
            'The path to the `${posix.basename(value)}` in '
            '`${dirParts.join('`/`')}`.',
          )
          ..writeFunction(
            'String get $key',
            <String>[],
            bodyConstructor: value.contains(r'$') ? "r'" : "'",
            bodyFields: posix.split(value),
            separator: posix.separator,
          );
      }
    }
  }
}

extension on Iterable<String> {
  Iterable<String> get sameSegments {
    List<String>? sameSegments;
    for (final String inputPath in this) {
      if (sameSegments == null) {
        sameSegments = split(inputPath);
        continue;
      } else if (sameSegments.isEmpty) {
        break;
      }
      final List<String> inputSegments = split(inputPath);
      for (int index = 0; index < inputSegments.length; index++) {
        if (index >= sameSegments!.length ||
            inputSegments[index] != sameSegments[index]) {
          sameSegments = inputSegments.sublist(0, index);
          break;
        }
      }
    }
    return sameSegments ?? <String>[];
  }
}
