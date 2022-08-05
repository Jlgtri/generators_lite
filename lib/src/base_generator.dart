import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

/// The base [Command] for all generators.
abstract class GeneratorCommand<Generator extends BaseGenerator>
    extends Command<void> {
  /// The base [Command] for all generators.
  GeneratorCommand(final String defaultExportPath) {
    argParser
      ..addOption(
        'import-path',
        abbr: 'i',
        help: 'The path to the files to generate from. '
            'Defaults to all files in the current working directory.',
        defaultsTo: '.',
      )
      ..addOption(
        'export-path',
        abbr: 'e',
        help: 'The path to export generated result to. '
            'Defaults to `$defaultExportPath` in the current working '
            'directory.',
        defaultsTo: defaultExportPath,
      )
      ..addOption(
        'export-encoding',
        help: 'The encoding used for writing the `.dart` files. '
            'Defaults to `utf-8`.',
      );
  }

  @override
  final ArgParser argParser = ArgParser(
    usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : 80,
  );

  /// Return the generator for this instance.
  Generator get([final Map<String, Object?>? options]);

  @override
  FutureOr<void> run() => get().build();
}

/// The base architecture for all generators on top of [Builder].
@immutable
abstract class BaseGenerator implements Builder {
  /// The base architecture for all generators on top of [Builder].
  BaseGenerator({
    required this.importPath,
    required this.exportPath,
    final Encoding? exportEncoding,
    final Encoding? encoding,
    final DartFormatter? formatter,
    this.jsonReviver,
    final bool? yamlRecover,
    final bool? loadFiles,
  })  : loadFiles = loadFiles ?? true,
        exportEncoding = exportEncoding ?? utf8,
        encoding = encoding ?? utf8,
        yamlRecover = yamlRecover ?? false,
        formatter =
            formatter ?? DartFormatter(lineEnding: '\r\n', fixes: StyleFix.all);

  /// The path to import data from.
  final String importPath;

  /// The path to export data to.
  final String exportPath;

  /// The encoding used for writing the `.dart` files.
  final Encoding exportEncoding;

  /// The encoding used for reading the `.json` and `.yaml` files.
  final Encoding encoding;

  /// The [formatter] used to format generated files.
  final DartFormatter formatter;

  /// The reviver for loading of [.json] files.
  final Object? Function(Object?, Object?)? jsonReviver;

  /// If yaml parser should attempt to recover from parse errors and return
  /// invalid or synthetic nodes.
  final bool yamlRecover;

  /// If file contents should be loaded during [build] into [fileMap].
  final bool loadFiles;

  /// The map of files that was loaded from [importPath].
  final Map<String, Object?> fileMap = <String, Object?>{};

  /// Generate [fileMap] from files under [importPath].
  ///
  /// Loads [.json] and [.yaml] files and skips others.
  @override
  @mustCallSuper
  FutureOr<void> build([final BuildStep? buildStep]) async {
    fileMap.clear();
    await buildStep
        ?.findAssets(Glob(posix.normalize(importPath), recursive: true))
        .drain<void>();
    for (final File file in <FileSystemEntity>[
      if (FileSystemEntity.isFileSync(importPath))
        File(importPath)
      else if (FileSystemEntity.isDirectorySync(importPath))
        ...Directory(importPath).listSync(recursive: true)
    ].whereType<File>()) {
      Future<String> fileContent() => buildStep == null
          ? file.readAsString(encoding: encoding)
          : buildStep.trackStage(
              'Loading ${file.path}',
              () => buildStep.readAsString(
                AssetId(buildStep.inputId.package, file.path),
                encoding: encoding,
              ),
            );

      String fileExtension = '';
      if (loadFiles) {
        fileExtension = extension(file.path);
        if (fileExtension.isEmpty && basename(file.path).startsWith('.')) {
          fileExtension = basename(file.path);
        }
      }
      final Object? content;
      switch (fileExtension) {
        case '.json':
          content = json.decode(await fileContent(), reviver: jsonReviver);
          break;
        case '.yaml':
          content = loadYaml(
            await fileContent(),
            sourceUrl: file.uri,
            recover: yamlRecover,
          );
          break;
        default:
          content = null;
      }
      fileMap[canonicalize(file.path)] = content;
    }
  }
}
