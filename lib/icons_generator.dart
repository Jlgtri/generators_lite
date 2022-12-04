import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

import 'src/base_generator.dart';
import 'src/utils/map_utils.dart';
import 'src/utils/string_buffer_utils.dart';
import 'src/utils/string_utils.dart';

/// Build runner static entry point for [IconsGenerator].
IconsGenerator iconsGeneratorBuilder(final BuilderOptions options) =>
    IconsCommand().get(options.config);

/// The command used to run the [IconsGenerator].
class IconsCommand extends GeneratorCommand<IconsGenerator> {
  /// The command used to run the [IconsGenerator].
  IconsCommand() : super('./icons.g.dart') {
    argParser
      ..addOption(
        'encoding',
        help: 'The encoding used for reading the `.json` and `.yaml` files. '
            'Defaults to `utf-8`.',
      )
      ..addOption(
        'font-export-path',
        abbr: 'f',
        help: 'The path to export generated font to. '
            'Defaults to `icons.ttf` in the current working directory.',
        defaultsTo: './icons.ttf',
      )
      ..addOption(
        'base-name',
        abbr: 'b',
        help: 'The name of the generated class. Defaults to `Icons`.',
      )
      ..addOption(
        'font-family',
        abbr: 'a',
        help: 'The name of the font specified in pubspec.yaml. '
            'Defaults to `Icons`.',
      )
      ..addOption(
        'base-code-point',
        abbr: 'o',
        help: 'The starting code point for referencing icons. '
            'Defaults to `0xf101`.',
      )
      ..addOption(
        'height',
        abbr: 't',
        help: 'The height of the heighest icon.',
      )
      ..addOption(
        'descent',
        abbr: 'd',
        help: 'The descent is usefull to fix the font baseline. '
            'Defaults to `0`.',
      )
      ..addFlag(
        'normalize',
        abbr: 'n',
        help: 'If the icons should be normalized by scaling them to the height '
            'of the highest icon. Defaults to `false`.',
        defaultsTo: null,
      )
      ..addOption(
        'package',
        abbr: 'p',
        help:
            'A path to the js package to run npm install or yarn install with. '
            'Defaults to package with `fantasticon: ^1.2.3`.',
      )
      ..addFlag(
        'convert',
        abbr: 'c',
        help: 'If the icon names should be converted to camel case. Disabling '
            'this option will prevent any changes to be made to the icon '
            'names. Be certain to pass valid Dart names or the generation will '
            'be likely to fail. Defaults to `true`',
        defaultsTo: null,
      )
      ..addFlag(
        'yarn',
        abbr: 'y',
        help: 'If the package should be installed with yarn instead of npm. '
            'Defaults to `false`.',
        defaultsTo: null,
      )
      ..addFlag(
        'force',
        abbr: 'r',
        help: 'If the package should be installed forcefully. Otherwise, if '
            'fantasticon executable is present, installation is ommited. '
            'Defaults to `false`.',
        defaultsTo: null,
      );
  }

  @override
  String get name => 'icons';

  @override
  String get description =>
      'Used for real-time generation of a webfont from `.svg` files. '
      'Also utilizes autocompletion of the nested icons like an assets '
      'generator.';

  @override
  IconsGenerator get([final Map<String, Object?>? options]) {
    final Object? importPath =
        options?['import_path'] ?? argResults?['import-path'] as Object?;
    final Object? exportPath =
        options?['export_path'] ?? argResults?['export-path'] as Object?;
    final Object? fontExportPath = options?['font_export_path'] ??
        argResults?['font-export-path'] as Object?;
    final Object? exportEncoding = options?['export_encoding'] ??
        argResults?['export-encoding'] as Object?;
    final Object? encoding =
        options?['encoding'] ?? argResults?['encoding'] as Object?;
    final Object? baseName =
        options?['base_name'] ?? argResults?['base-name'] as Object?;
    final Object? fontFamily =
        options?['font_family'] ?? argResults?['font-family'] as Object?;
    final Object? baseCodePoint = options?['base_code_point'] ??
        argResults?['base-code-point'] as Object?;
    final Object? height =
        options?['height'] ?? argResults?['height'] as Object?;
    final Object? descent =
        options?['descent'] ?? argResults?['descent'] as Object?;
    final Object? normalize =
        options?['normalize'] ?? argResults?['normalize'] as Object?;
    Object? package = options?['package'] ?? argResults?['package'] as Object?;
    final Object? convert =
        options?['convert'] ?? argResults?['convert'] as Object?;
    final Object? yarn = options?['yarn'] ?? argResults?['yarn'] as Object?;
    final Object? force = options?['force'] ?? argResults?['force'] as Object?;

    if (importPath is! String || importPath.isEmpty) {
      throw const FormatException('The import path is not provided.');
    } else if (exportPath is! String || exportPath.isEmpty) {
      throw const FormatException('The export path is not provided.');
    } else if (fontExportPath is! String || fontExportPath.isEmpty) {
      throw const FormatException('The font export path is not provided.');
    } else {
      if (package is String) {
        final String packageExtension = extension(package);
        if (<String>{'.json', '.yaml'}.contains(packageExtension)) {
          final File packageFile = File(package);
          if (packageFile.existsSync()) {
            package = packageFile.readAsStringSync(
              encoding: encoding is String && encoding.isNotEmpty
                  ? Encoding.getByName(encoding) ?? utf8
                  : utf8,
            );
            package = packageExtension == '.json'
                ? json.decode(package)
                : loadYaml(package);
          }
        }
      }
      return DartIconsGenerator(
        importPath: importPath,
        exportPath: exportPath,
        fontExportPath: fontExportPath,
        exportEncoding: exportEncoding is String
            ? Encoding.getByName(exportEncoding)
            : null,
        encoding: encoding is String && encoding.isNotEmpty
            ? Encoding.getByName(encoding)
            : null,
        baseName: baseName is String && baseName.isNotEmpty
            ? baseName.normalize()
            : null,
        fontFamily: fontFamily is String && fontFamily.isNotEmpty
            ? fontFamily.normalize()
            : null,
        baseCodePoint: baseCodePoint is int ? baseCodePoint : null,
        height: height is int ? height : null,
        descent: descent is int ? descent : null,
        normalize: normalize is bool ? normalize : null,
        package: package is Map<Object?, Object?> && package.isNotEmpty
            ? package.cast<String, Object?>().normalize()
            : package is MapMixin<Object?, Object?> && package.isNotEmpty
                ? package.cast<String, Object?>().normalize()
                : null,
        convert: convert is bool ? convert : null,
        yarn: yarn is bool ? yarn : null,
        force: force is bool ? force : null,
      );
    }
  }
}

/// The architecture of the
/// {@template icons}
/// [IconFont](https://en.wikipedia.org/wiki/TrueType)
/// {@endtemplate}
/// generator.
@immutable
abstract class IconsGenerator extends BaseGenerator {
  /// The architecture of the
  /// {@template icons}
  /// [IconFont](https://en.wikipedia.org/wiki/TrueType)
  /// {@endtemplate}
  /// generator.
  IconsGenerator({
    required super.importPath,
    required super.exportPath,
    required this.fontExportPath,
    super.exportEncoding,
    super.encoding,
    super.formatter,
    super.jsonReviver,
    super.yamlRecover,
    final String? baseName,
    final String? fontFamily,
    final int? baseCodePoint,
    this.height,
    this.descent,
    this.normalize,
    final Map<String, Object?>? package,
    final bool? convert,
    final bool? yarn,
    final bool? force,
  })  : baseName = baseName ?? 'Icons',
        fontFamily = fontFamily ?? 'Icons',
        baseCodePoint = baseCodePoint ?? 0xf101,
        package = package ??
            const <String, Object?>{
              'private': true,
              'devDependencies': <String, Object?>{'fantasticon': '^1.2.3'},
            },
        convert = convert ?? true,
        yarn = yarn ?? false,
        force = force ?? false;

  /// The name of the base assets class.
  final String baseName;

  /// The path to export generated font to.
  final String fontExportPath;

  /// The name of the font specified in pubspec.yaml.
  final String fontFamily;

  /// The starting code point for referencing
  /// {@macro icons}
  /// icons.
  final int baseCodePoint;

  /// The height of the heighest icon.
  final int? height;

  /// The descent is usefull to fix the font baseline.
  final int? descent;

  /// If the icons should be normalized by scaling them to the height of the
  /// highest icon.
  final bool? normalize;

  /// The js package to run `npm install` or `yarn install` with.
  final Map<String, Object?> package;

  /// If the
  /// {@macro icons}
  /// names should be converted using [StringUtils.toCamelCase].
  final bool convert;

  /// If the [package] should be installed with `yarn` instead of `npm`.
  final bool yarn;

  /// If the [package] should be installed forcefully. Otherwise, if
  /// `fantasticon` executable is present, installation is ommited.
  final bool force;

  @override
  Map<String, List<String>> get buildExtensions => <String, List<String>>{
        r'$package$': <String>[
          exportPath,
          fontExportPath,
          '${withoutExtension(fontExportPath)}.json',
          join('.dart_tool', 'package.json'),
        ],
      };

  /// The
  /// {@macro icons}
  /// path graph.
  final Map<String, Object?> iconsMap = <String, Object?>{};

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

  /// Generate
  /// {@macro icons}
  /// from [fileMap].
  @override
  @mustCallSuper
  FutureOr<void> build([final BuildStep? buildStep]) async {
    FutureOr<T> runAction<T extends Object?>(
      final String label,
      final FutureOr<T> Function() action,
    ) =>
        buildStep != null
            ? buildStep.trackStage(label, action, isExternal: true)
            : action();

    ProcessResult result;
    // ProcessResult result = await runAction(
    //   'Check Node.JS version.',
    //   () => Process.run('node', <String>['--version'], runInShell: true),
    // );
    // if (result.exitCode != 0) {
    //   throw Exception('Please install Node.JS v10+');
    // }

    await super.build(buildStep);

    final String fantasticonExecutable = join(
      Directory.current.path,
      '.dart_tool',
      'node_modules',
      '.bin',
      'fantasticon${Platform.isWindows ? '.cmd' : ''}',
    );
    if (force || !File(fantasticonExecutable).existsSync()) {
      final File packageFile =
          File(join(Directory.current.path, '.dart_tool', 'package.json'));
      if (!packageFile.existsSync()) {
        await packageFile.writeAsString(json.encode(package));
      }

      result = await runAction(
        'Run ${yarn ? 'yarn' : 'npm'} install.',
        () => Process.run(
          yarn ? 'yarn' : 'npm',
          <String>['install', '--no-fund'],
          workingDirectory: join(Directory.current.path, '.dart_tool'),
          runInShell: true,
        ),
      );
      if (result.exitCode != 0) {
        final Object? stderr = result.stderr;
        throw Exception(
          stderr is String && stderr.isNotEmpty ? stderr : result.stdout,
        );
      }
    }

    result = await runAction(
      'Run fantasticon.',
      () => Process.run(
        fantasticonExecutable,
        <String>[
          canonicalize(joinAll(split(importPath))),
          if (height != null) ...<String>['--font-height', height!.toString()],
          if (descent != null) ...<String>['--descent', descent!.toString()],
          if (normalize != null) ...<String>[
            '--normalize',
            normalize!.toString()
          ],
          '--name',
          basenameWithoutExtension(fontExportPath),
          '--output',
          canonicalize(joinAll(split(dirname(fontExportPath)))),
          ...<String>['--asset-types', 'json'],
          ...<String>['--font-types', extension(fontExportPath).substring(1)]
        ],
        workingDirectory: Directory.current.path,
        runInShell: true,
      ),
    );
    if (result.exitCode != 0) {
      final Object? stderr = result.stderr;
      throw Exception(
        stderr is String && stderr.isNotEmpty ? stderr : result.stdout,
      );
    }

    iconsMap.clear();
    iconsMap[''] = importPath;
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
    int globalIndex = 0;
    for (final String inputPath in fileMap.keys.sorted(
      (final String $1, final String $2) =>
          basenameWithoutExtension($2).startsWith(basenameWithoutExtension($1))
              ? 1
              : $1.compareTo($2),
    )) {
      Map<String, Object?> nestedIconsMap = iconsMap;
      final List<String> segments =
          split(inputPath).sublist(baseSegments.length);
      for (int index = 0; index < segments.length; index++) {
        final String segment = segments.elementAt(index);
        if (index == segments.length - 1) {
          final String fullPath =
              posix.join(importPath, posix.joinAll(segments));
          nestedIconsMap[fullPath] = baseCodePoint + globalIndex++;
        } else {
          nestedIconsMap.putIfAbsent(segment, () => <String, Object?>{});
          nestedIconsMap = nestedIconsMap[segment]! as Map<String, Object?>;
          if (!nestedIconsMap.containsKey('')) {
            nestedIconsMap[''] = posix.join(
              importPath,
              posix.joinAll(segments.sublist(0, segments.length - index - 1)),
            );
          }
        }
      }
    }
  }
}

/// The
/// {@macro icons}
/// generator for dart.
@immutable
class DartIconsGenerator extends IconsGenerator {
  /// The
  /// {@macro icons}
  /// generator for dart.
  DartIconsGenerator({
    required super.importPath,
    required super.exportPath,
    required super.fontExportPath,
    super.exportEncoding,
    super.encoding,
    super.formatter,
    super.jsonReviver,
    super.yamlRecover,
    super.baseName,
    super.fontFamily,
    super.height,
    super.descent,
    super.normalize,
    super.package,
    super.baseCodePoint,
    super.convert,
    super.yarn,
    super.force,
  });

  @override
  @mustCallSuper
  FutureOr<void> build([final BuildStep? buildStep]) async {
    await super.build(buildStep);
    if (buildStep != null) {
      await buildStep.writeAsString(
        buildStep.allowedOutputs.first,
        buildStep.trackStage('Generate $exportPath.', () => generate(iconsMap)),
        encoding: exportEncoding,
      );
    } else {
      final File file = File(exportPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        generate(iconsMap),
        encoding: exportEncoding,
        mode: FileMode.writeOnly,
        flush: true,
      );
    }
  }

  /// Generate a single
  /// {@macro icons}
  /// file from [iconsMap].
  String generate(final Map<String, Object?> iconsMap) {
    final StringBuffer buffer = StringBuffer();
    generateHeader(buffer, iconsMap);
    generateModel(buffer, iconsMap, baseName);
    final String output = buffer.toString();
    try {
      return formatter.format(output, uri: exportPath);
    } on Exception catch (_) {
      return output;
    }
  }

  /// Generate a header for the
  /// {@macro icons}
  /// file.
  void generateHeader(
    final StringBuffer buffer,
    final Map<String, Object?> iconsMap,
  ) {
    buffer
      ..writeDoc('This file is used for `Icon Font` structure generation.')
      ..writeDoc('')
      ..writeDoc('Modify this file at your own risk!')
      ..writeDoc('')
      ..writeDoc(
        'See: https://pub.dev/packages/generators#icon-fonts-generator',
      )
      ..writeDoc('')
      ..writeImports(<String>[
        'package:flutter/widgets.dart',
        'package:meta/meta.dart',
      ]);
  }

  /// Generate a
  /// {@template model}
  /// model nested from [keys].
  /// {@endtemplate}
  void generateModel(
    final StringBuffer buffer,
    final Map<String, Object?> iconsMap,
    final String name, {
    final Iterable<String> keys = const Iterable<String>.empty(),
  }) {
    final String cls = className(name, keys);
    if (keys.isEmpty) {
      String className = cls.decapitalize();
      className = className == cls ? '\$$className' : className;
      buffer
        ..writeDoc('This is a generated structure of an Icon Font.')
        ..writeDoc('')
        ..writeDoc(
          'See: https://pub.dev/packages/generators#icon-fonts-generator',
        )
        ..writeln('const $cls $className = $cls._();')
        ..writeln();
    }

    final Map<String, Object?> map = keys.skip(1).isEmpty && name == baseName
        ? iconsMap
        : iconsMap.getNested(<String>[name, ...keys.skip(1)])!
            as Map<String, Object?>;
    final String parentName = keys.isNotEmpty
        ? className(keys.last, keys.toList()..removeLast())
        : '';
    buffer
      ..writeDoc('The file structure of the `${map['']! as String}` folder.')
      ..writeln('@sealed')
      ..writeln('@immutable')
      ..writeln('class $cls {')

      /// `Constructor`
      ..writeFunction(
        'const ${className(name, keys)}._',
        <String>[if (parentName.isNotEmpty) 'final $parentName _'],
      );

    /// `Fields`
    for (final MapEntry<String, Object?> entry in map.entries) {
      final Object? value = entry.value;
      if (value is Map<String, Object?>) {
        final String key =
            convert ? entry.key.toCamelCase() : entry.key.normalize();
        final String cls = className(entry.key, <String>[...keys, name]);
        final Map<String, Object?> nestedMap =
            map[entry.key]! as Map<String, Object?>;
        final String nestedMapPath = nestedMap['']! as String;
        buffer
          ..writeDoc(
            'The `${posix.basename(nestedMapPath)}` folder in '
            '`${posix.dirname(nestedMapPath)}`.',
            indent: 2,
          )
          ..writeln('$cls get $key => $cls._(this);');
      } else if (value is int) {
        String iconName = posix.basenameWithoutExtension(entry.key);
        iconName = convert ? iconName.toCamelCase() : iconName.normalize();
        final String codePoint = value.toRadixString(16);
        buffer
          ..writeDoc(
            'The [IconData] of the `${posix.basename(entry.key)}` in '
            '`${posix.dirname(entry.key)}`.',
            indent: 2,
          )
          ..writeln('IconData get $iconName => '
              "const IconData(0x$codePoint, fontFamily: '$fontFamily');");
      }
    }
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
              if (entry.key.isNotEmpty)
                posix.basenameWithoutExtension(entry.key)
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
            if (entry.key.isNotEmpty) posix.basenameWithoutExtension(entry.key)
        ]
            .map((final _) => convert ? _.toCamelCase() : _.normalize())
            .map((final String key) => '$key.hashCode'),
        separator: ' ^ ',
      )
      ..writeln('}');

    /// `Nested Groups`
    for (final MapEntry<String, Object?> entry in map.entries) {
      if (entry.key.isNotEmpty && entry.value is Map<String, Object?>) {
        generateModel(
          buffer,
          iconsMap,
          entry.key,
          keys: <String>[...keys, name],
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
