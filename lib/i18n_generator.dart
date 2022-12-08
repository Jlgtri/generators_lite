import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';

import 'src/base_generator.dart';
import 'src/utils/map_utils.dart';
import 'src/utils/string_buffer_utils.dart';
import 'src/utils/string_utils.dart';

/// Build runner static entry point for [I18NGenerator].
I18NGenerator i18nGeneratorBuilder(final BuilderOptions options) =>
    I18NCommand().get(options.config);

/// The command used to run the [I18NGenerator].
class I18NCommand extends GeneratorCommand<I18NGenerator> {
  /// The command used to run the [I18NGenerator].
  I18NCommand() : super('./i18n.g.dart') {
    argParser
      ..addOption(
        'encoding',
        help: 'The encoding used for reading the `.json` and `.yaml` files. '
            'Defaults to `utf-8`.',
      )
      ..addOption(
        'base-name',
        abbr: 'n',
        help: 'The base name of the generated class. Defaults to `I18N`.',
      )
      ..addFlag(
        'convert',
        abbr: 'c',
        help: 'If the i18n names should be converted to camel case. Disabling '
            'this option will prevent any changes to be made to the i18n '
            'names. Be certain to pass valid Dart names or the generation will '
            'be likely to fail. Defaults to `true`.',
        defaultsTo: null,
      )
      ..addFlag(
        'only-language-code',
        help: 'Ensure that locales should only use their language codes. '
            'Defaults to `true`.',
        defaultsTo: null,
      )
      ..addOption(
        'base-class-name',
        abbr: 'b',
        help: 'The base name of the base I18N class. Defaults to ``.',
      )
      ..addOption(
        'enum-class-name',
        abbr: 'u',
        help: 'The name of the I18N enum class. Defaults to `I18NLocale`.',
      )
      ..addFlag(
        'use-flutter',
        help: 'If the generated results are intended to be used with Flutter. '
            "Thus, whether Localizations class and it's Localizations Delegate "
            'should be generated. Defaults to `true`.',
        defaultsTo: null,
      )
      ..addOption(
        'localizations-class-name',
        help: 'The name of the I18N Localizations class implementation. '
            'Only used if `use-flutter` is true. '
            'Defaults to `I18NLocalizations`.',
      )
      ..addOption(
        'delegate-class-name',
        help: 'The name of the Localizations Delegate class implementation. '
            'Only used if `use-flutter` is true. Defaults to `I18NDelegate`.',
      )
      ..addOption(
        'delegate-fallback-locale',
        help: 'The locale that will be used as a fallback in Localizations '
            'Delegate. Should be the exact match of one of the generated '
            'locales. Only used if `use_flutter` is true. '
            'Defaults to the first locale generated.',
      )
      ..addMultiOption(
        'imports',
        abbr: 'f',
        help: 'The imports to be used in generated file. '
            'Defaults to import `package:meta/meta.dart`.',
        defaultsTo: <String>[null.toString()],
      );
  }

  @override
  String get name => 'i18n';

  @override
  String get description =>
      'Primarily used for utilizing autocompletion of the files with '
      'translations, but can also be used for any type of dart code conversion '
      'from strings.';

  @override
  I18NGenerator get([final Map<String, Object?>? options]) {
    final Object? importPath =
        options?['import_path'] ?? argResults?['import-path'] as Object?;
    final Object? exportPath =
        options?['export_path'] ?? argResults?['export-path'] as Object?;
    final Object? exportEncoding = options?['export_encoding'] ??
        argResults?['export-encoding'] as Object?;
    final Object? encoding =
        options?['encoding'] ?? argResults?['encoding'] as Object?;
    final Object? baseName =
        options?['base_name'] ?? argResults?['base-name'] as Object?;
    final Object? convert =
        options?['convert'] ?? argResults?['convert'] as Object?;
    final Object? onlyLanguageCode = options?['only_language_code'] ??
        argResults?['only-language-code'] as Object?;
    final Object? baseClassName = options?['base_class_name'] ??
        argResults?['base-class-name'] as Object?;
    final Object? enumClassName = options?['enum_class_name'] ??
        argResults?['enum-class-name'] as Object?;
    final Object? useFlutter =
        options?['use_flutter'] ?? argResults?['use-flutter'] as Object?;
    final Object? localizationsClassName =
        options?['localizations_class_name'] ??
            argResults?['localizations-class-name'] as Object?;
    final Object? delegateClassName = options?['delegate_class_name'] ??
        argResults?['delegate-class-name'] as Object?;
    final Object? delegateFallbackLocale =
        options?['delegate_fallback_locale'] ??
            argResults?['delegate-fallback-locale'] as Object?;
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
      return DartI18NGenerator(
        importPath: importPath,
        exportPath: exportPath,
        exportEncoding: exportEncoding is String
            ? Encoding.getByName(exportEncoding)
            : null,
        encoding: encoding is String ? Encoding.getByName(encoding) : null,
        baseName: baseName is String && baseName.isNotEmpty
            ? baseName.normalize()
            : null,
        convert: convert is bool ? convert : null,
        onlyLanguageCode: onlyLanguageCode is bool ? onlyLanguageCode : null,
        baseClassName: baseClassName is String && baseClassName.isNotEmpty
            ? baseClassName.normalize()
            : null,
        enumClassName: enumClassName is String && enumClassName.isNotEmpty
            ? enumClassName.normalize()
            : null,
        useFlutter: useFlutter is bool ? useFlutter : null,
        localizationsClassName: localizationsClassName is String &&
                localizationsClassName.isNotEmpty
            ? localizationsClassName
            : null,
        delegateClassName:
            delegateClassName is String && delegateClassName.isNotEmpty
                ? delegateClassName
                : null,
        delegateFallbackLocale: delegateFallbackLocale is String &&
                delegateFallbackLocale.isNotEmpty
            ? delegateFallbackLocale
            : null,
        imports: imports == null ||
                imports.length == 1 && imports.single == null.toString()
            ? null
            : imports,
      );
    }
  }
}

/// The architecture of the
/// {@template i18n}
/// [I18N](https://en.wikipedia.org/wiki/Internationalization_and_localization)
/// {@endtemplate}
/// generator.
@immutable
abstract class I18NGenerator extends BaseGenerator {
  /// The architecture of the
  /// {@macro i18n}
  /// generator.
  I18NGenerator({
    required super.importPath,
    required super.exportPath,
    super.exportEncoding,
    super.encoding,
    super.formatter,
    super.jsonReviver,
    super.yamlRecover,
    final String? baseName,
    final bool? convert,
    final bool? onlyLanguageCode,
  })  : baseName = baseName ?? 'I18N',
        convert = convert ?? true,
        onlyLanguageCode = onlyLanguageCode ?? false;

  /// The name of the
  /// {@macro i18n}
  /// class.
  final String baseName;

  /// If the
  /// {@macro i18n}
  /// names should be converted using [StringUtils.toCamelCase].
  final bool convert;

  /// If only the language code of the generated
  /// {@macro i18n}
  /// locales should be used.
  final bool onlyLanguageCode;

  /// The map with
  /// {@macro i18n}
  /// locales as keys and translations as values.
  final Map<String, Map<String, Object?>> i18nMap =
      <String, Map<String, Object?>>{};

  /// The name of the
  /// {@macro i18n}
  /// enum value.
  String enumName(final String name) => name.replaceAll('_', '');

  /// The name of the
  /// {@macro i18n}
  /// instance.
  String constName(final String name) {
    final String constName = (enumName(name) + baseName).capitalize();
    final String $constName = constName.decapitalize();
    return $constName == constName ? '\$${$constName}' : $constName;
  }

  /// The name of the
  /// {@macro i18n}
  /// class nested with [keys].
  String className(
    final String name, [
    final Iterable<String> keys = const Iterable<String>.empty(),
  ]) {
    final List<String> nameParts = name.split('_');
    return <String>[
      if (nameParts.isNotEmpty) nameParts.first.normalize().capitalize(),
      if (nameParts.length > 1) ...<String>[
        ...nameParts.sublist(1, nameParts.length - 1),
        nameParts.last.toUpperCase()
      ],
      baseName,
      ...keys.map(
        (final String key) =>
            (convert ? key.toCamelCase() : key.normalize()).capitalize(),
      )
    ].join();
  }

  @override
  Map<String, List<String>> get buildExtensions => <String, List<String>>{
        r'$package$': <String>[exportPath],
      };

  @override
  @mustCallSuper
  FutureOr<void> build([final BuildStep? buildStep]) async {
    await super.build(buildStep);
    i18nMap.clear();
    final int localDirSegmentsCount =
        split(join(Directory.current.path, importPath)).length;

    // final Map<String, int> withoutUnderscore = <String, int>{};
    // for (final String inputPath in fileMap.keys) {
    //   final String dirName = dirname(inputPath);
    //   withoutUnderscore.putIfAbsent(dirName, () => 0);
    //   if (!basenameWithoutExtension(inputPath).contains('_')) {
    //     withoutUnderscore[dirName] = withoutUnderscore[dirName]! + 1;
    //   }
    // }

    final Map<String, Iterable<String>> langKeys = <String, Iterable<String>>{};
    for (final String inputPath in fileMap.keys) {
      String fileExtension = extension(inputPath);
      if (fileExtension.isEmpty && basename(inputPath).startsWith('.')) {
        fileExtension = basename(inputPath);
      }

      String langKey = basenameWithoutExtension(inputPath);
      if (langKey == fileExtension) {
        langKey = '';
      } else if (langKey.contains('_')) {
        langKey = langKey.split('_').last.trim();
      }
      // else if (withoutUnderscore[dirname(inputPath)]! <= 1) {
      //   langKey = '';
      // }

      final List<String> langParts = langKey
          .replaceAll('-', '_')
          .split('_')
          .where((final String _) => _.isNotEmpty)
          .toList();
      if (langParts.isNotEmpty) {
        if (onlyLanguageCode) {
          langKey = langParts.first;
        } else {
          final String lastKey = langParts.removeLast().toUpperCase();
          langKey = <String>[...langParts, lastKey].join('_');
        }
      } else {
        langKey = '';
      }
      langKeys[langKey] = <String>[...?langKeys[langKey], inputPath];
    }

    for (final String langKey in langKeys.keys) {
      final Map<String, Object?> langValues = <String, Object?>{
        for (final String inputPath in langKeys[langKey]!)
          inputPath: fileMap[inputPath]
      };

      final Object? value;
      if (langValues.length > 1) {
        final Map<String, Iterable<String>> directoryInputs =
            <String, Iterable<String>>{};
        for (final String inputPath in langValues.keys) {
          List<String> nestedKeys = split(inputPath);
          nestedKeys = nestedKeys.sublist(
            localDirSegmentsCount,
            nestedKeys.length - 1,
          );
          final String path = joinAll(nestedKeys);
          directoryInputs[path] = <String>[
            ...?directoryInputs[path],
            inputPath
          ];
        }

        value = <String, Object?>{};
        for (final String directoryPath in directoryInputs.keys) {
          final Iterable<String> inputs = directoryInputs[directoryPath]!;
          if (inputs.length > 1) {
            for (final String directory in inputs) {
              List<String> nestedKeys = split(directory);
              nestedKeys = nestedKeys.sublist(localDirSegmentsCount);
              String inputKey =
                  (nestedKeys.removeLast().split('.')..removeLast()).join('.');
              inputKey = inputKey.contains('_')
                  ? (inputKey.split('_')..removeLast())
                      .map((final String _) => _.trim())
                      .join('_')
                  : inputKey;
              (value as Map<String, Object?>).nest(
                <String>[...nestedKeys, inputKey],
                langValues[directory],
              );
            }
          } else {
            List<String> nestedKeys = split(inputs.single);
            nestedKeys = nestedKeys.sublist(
              localDirSegmentsCount,
              nestedKeys.length - 1,
            );
            (value as Map<String, Object?>)
                .nest(nestedKeys, langValues[inputs.single]);
          }
        }
      } else {
        List<String> nestedKeys = split(langValues.keys.single);
        nestedKeys = nestedKeys.sublist(
          localDirSegmentsCount,
          nestedKeys.length - 1,
        );
        if (nestedKeys.isEmpty) {
          value = langValues.values.single;
        } else {
          value = <String, Object?>{}
            ..nest(nestedKeys, langValues.values.single);
        }
      }

      i18nMap[langKey] = <String, Object?>{
        ...?i18nMap[langKey],
        ...value.toMap<String>()
      };
    }

    if (i18nMap.isEmpty) {
      throw const FormatException('No languages or abstract base provided.');
    } else if (i18nMap.keys.contains('') && i18nMap['']!.isNotEmpty) {
      for (final String langKey in i18nMap.keys) {
        i18nMap[langKey]!.check(i18nMap['']!, parent: langKey);
      }
    } else {
      for (final String langKey in i18nMap.keys) {
        for (final String $langKey in i18nMap.keys) {
          if (langKey != $langKey) {
            i18nMap[langKey]!.check(
              i18nMap[$langKey]!,
              parent: langKey,
              otherParent: $langKey.isEmpty ? null : $langKey,
            );
          }
        }
      }
      i18nMap[''] = i18nMap.values.first.onlyKeys();
    }
  }
}

/// The
/// {@macro i18n}
/// generator for dart.
@immutable
class DartI18NGenerator extends I18NGenerator {
  /// The
  /// {@macro i18n}
  /// generator for dart.
  DartI18NGenerator({
    required super.importPath,
    required super.exportPath,
    super.exportEncoding,
    super.encoding,
    super.formatter,
    super.jsonReviver,
    super.yamlRecover,
    super.baseName,
    super.convert,
    super.onlyLanguageCode,
    this.baseClassName,
    final String? enumClassName,
    final bool? useFlutter,
    final String? localizationsClassName,
    final String? delegateClassName,
    this.delegateFallbackLocale,
    final Iterable<String>? imports,
  })  : enumClassName = enumClassName ?? 'I18NLocale',
        useFlutter = useFlutter ?? true,
        localizationsClassName = localizationsClassName ?? 'I18NLocalizations',
        delegateClassName = delegateClassName ?? 'I18NDelegate',
        imports = imports ?? const <String>[];

  /// The base name of the base
  /// {@macro i18n}
  /// class.
  final String? baseClassName;

  /// The name of the
  /// {@macro i18n}
  /// enum class.
  final String enumClassName;

  /// If the generator should create Flutter's
  /// {@macro i18n}
  /// localization delegate.
  final bool useFlutter;

  /// The name of the
  /// {@macro i18n}
  /// Localizations class implementation.
  ///
  /// Only used if [useFlutter] is true.
  final String localizationsClassName;

  /// The name of the
  /// {@macro i18n}
  /// Localizations Delegate class implementation.
  ///
  /// Only used if [useFlutter] is true.
  final String delegateClassName;

  /// The locale that will be used as a fallback in the
  /// {@macro i18n}
  /// Localizations Delegate. Should be the exact match of one of the generated
  /// locales.
  ///
  /// Only used if [useFlutter] is true.
  final String? delegateFallbackLocale;

  /// The iterable with imports to be used in [generateHeader].
  final Iterable<String> imports;

  @override
  @mustCallSuper
  FutureOr<void> build([final BuildStep? buildStep]) async {
    await super.build(buildStep);
    if (buildStep != null) {
      await buildStep.writeAsString(
        buildStep.allowedOutputs.single,
        buildStep.trackStage('Generate $exportPath.', () => generate(i18nMap)),
        encoding: exportEncoding,
      );
    } else {
      final File file = File(exportPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        generate(i18nMap),
        encoding: exportEncoding,
        mode: FileMode.writeOnly,
        flush: true,
      );
    }
  }

  /// Generate a single
  /// {@macro i18n}
  /// file from [i18nMap].
  String generate(final Map<String, Map<String, Object?>> i18nMap) {
    final StringBuffer buffer = StringBuffer();
    generateHeader(buffer, i18nMap);
    if (i18nMap.keys.any((final String key) => key.isNotEmpty)) {
      if (useFlutter) {
        generateLocalizations(buffer);
        generateLocalizationsDelegate(buffer);
      }
      generateEnum(buffer, i18nMap);
    }
    for (final String lang in i18nMap.keys.toList(growable: false)..sort()) {
      generateModel(buffer, i18nMap, lang);
    }
    final String output = buffer.toString();
    try {
      return formatter.format(output, uri: exportPath);
    } on Exception catch (_) {
      return output;
    }
  }

  /// Generate a header for the
  /// {@macro i18n}
  /// file.
  void generateHeader(
    final StringBuffer buffer,
    final Map<String, Map<String, Object?>> i18nMap,
  ) {
    buffer
      ..writeDoc(
        (<String>[
          'file_names',
          'unnecessary_string_interpolations',
          'unused_field'
        ]..sort())
            .join(' '),
        prefix: '// ignore_for_file: ',
        separator: ', ',
      )
      ..writeDoc('')
      ..writeDoc('This file is used for `I18N` package generation.')
      ..writeDoc('')
      ..writeDoc('Modify this file at your own risk!')
      ..writeDoc('')
      ..writeDoc('See: https://pub.dev/packages/generators#i18n-generator')
      ..writeDoc('')
      ..writeImports(<String>[
        ...imports,
        if (useFlutter &&
            i18nMap.keys.any((final String key) => key.isNotEmpty)) ...<String>[
          'package:flutter/foundation.dart',
          'package:flutter/material.dart'
        ],
        'package:meta/meta.dart'
      ]);
  }

  /// Generate Flutter's
  /// {@macro i18n}
  /// Localizations class.
  void generateLocalizations(final StringBuffer buffer) {
    buffer
      ..writeDoc('The [$baseName] Localizations for the current [locale].')
      ..writeln('class $localizationsClassName {')
      ..writeDoc(
        'The [$baseName] Localizations for the current [locale].',
        indent: 2,
      )
      ..writeln('const $localizationsClassName(this.locale);')
      ..writeln()
      ..writeDoc(
        'The current [$baseName] locale of the [Localizations] widget.',
        indent: 2,
      )
      ..writeln('final $enumClassName locale;')
      ..writeln()
      ..writeDoc(
        'Return the [$baseName] for the current locale of the '
        '[Localizations] widget.',
        indent: 2,
      )
      ..writeln('static $baseName of(final BuildContext context) {')
      ..writeln(
        'final $localizationsClassName? i18n = '
        'Localizations.of<$localizationsClassName>(context, '
        '$localizationsClassName);',
      )
      ..writeln('assert(')
      ..writeln('() {')
      ..writeln('if (i18n == null) {')
      ..writeln('throw FlutterError.fromParts(<DiagnosticsNode>[')
      ..writeln('ErrorSummary(')
      ..writeDoc(
        'No $localizationsClassName found.',
        prefix: "'",
        suffix: "'",
        indent: 14,
      )
      ..writeln(',),')
      ..writeln('ErrorDescription(')
      ..writeDoc(
        '\${context.widget.runtimeType} widget require $localizationsClassName '
        'to be provided by a Localizations widget ancestor.',
        prefix: "'",
        suffix: "'",
        indent: 14,
      )
      ..writeln(',),')
      ..writeln('ErrorDescription(')
      ..writeDoc(
        'The widgets library uses Localizations to generate messages, labels, '
        'and abbreviations.',
        prefix: "'",
        suffix: "'",
        indent: 14,
      )
      ..writeln(',),')
      ..writeln('ErrorHint(')
      ..writeDoc(
        'To introduce the $localizationsClassName, add a Localization widget '
        'with the $delegateClassName.',
        prefix: "'",
        suffix: "'",
        indent: 14,
      )
      ..writeln(',),')
      ..writeln('...context.describeMissingAncestor(')
      ..writeln('expectedAncestorType: $localizationsClassName,')
      ..writeln('),')
      ..writeln(']);')
      ..writeln('}')
      ..writeln('return true;')
      ..writeln('}(),')
      ..writeln("'',")
      ..writeln(');')
      ..writeln('return i18n!.locale();')
      ..writeln('}')
      ..writeln()
      ..writeDoc(
        'A [$delegateClassName] that creates an instance of this class.',
        indent: 2,
      )
      ..writeln(
        'static const LocalizationsDelegate<$localizationsClassName> delegate '
        '= $delegateClassName._();',
      )
      ..writeln('}');
  }

  /// Generate Flutter's
  /// {@macro i18n}
  /// Localizations Delegate class.
  void generateLocalizationsDelegate(final StringBuffer buffer) {
    buffer
      ..writeDoc(
        'The [$baseName] Localizations Delegate that creates an instance '
        'of [$localizationsClassName].',
      )
      ..writeln(
        'class $delegateClassName extends '
        'LocalizationsDelegate<$localizationsClassName> {',
      )
      ..writeln('const $delegateClassName._();')
      ..writeln()
      ..writeln('@override')
      ..writeln('bool isSupported(final Locale locale) => true;')
      ..writeln()
      ..writeln('@override')
      ..writeln('bool shouldReload(final $delegateClassName old) => false;')
      ..writeln()
      ..writeln('@override')
      ..writeln('Future<$localizationsClassName> load(final Locale locale) =>')
      ..writeln('SynchronousFuture<$localizationsClassName>(')
      ..writeln('$localizationsClassName(')
      ..writeln('$enumClassName.values.firstWhere(')
      ..writeln('(final $enumClassName \$locale) => \$locale.locale == locale,')
      ..write('orElse: () => $enumClassName.')
      ..writeln(
        (delegateFallbackLocale?.isNotEmpty ?? false) &&
                i18nMap.containsKey(delegateFallbackLocale)
            ? enumName(delegateFallbackLocale!)
            : 'values.first',
      )
      ..writeln(',),')
      ..writeln('),')
      ..writeln(');')
      ..writeln('}');
  }

  /// Generate an
  /// {@macro i18n}
  /// enum for the file.
  void generateEnum(
    final StringBuffer buffer,
    final Map<String, Map<String, Object?>> i18nMap,
  ) {
    buffer
      ..writeDoc('The generated [$baseName] enumeration.')
      ..writeln('enum $enumClassName {');
    final Iterable<String> $keys =
        i18nMap.keys.where((final String key) => key.isNotEmpty);
    for (int index = 0; index < $keys.length; index++) {
      final String name = enumName($keys.elementAt(index));
      buffer
        ..writeDoc('The implementation of the [$name] locale.', indent: 2)
        ..write(name)
        ..writeln(index < $keys.length - 1 ? ',' : ';');
    }
    buffer
      ..writeln()
      ..writeDoc('Return the localization for this locale.')
      ..writeln('$baseName call() {')
      ..writeln('switch (this) {');
    for (final String key in i18nMap.keys) {
      if (key.isNotEmpty) {
        buffer
          ..writeln('case $enumClassName.${enumName(key)}:')
          ..writeln('return ${constName(key)};');
      }
    }
    buffer
      ..writeln('}')
      ..writeln('}')
      ..writeDoc('Return the name of this locale.', indent: 2)
      ..writeln('String get name {')
      ..writeln('switch (this) {');
    for (final String key in i18nMap.keys) {
      if (key.isNotEmpty) {
        buffer
          ..writeln('case $enumClassName.${enumName(key)}:')
          ..writeln("return '$key';");
      }
    }
    buffer
      ..writeln('}')
      ..writeln('}');
    if (useFlutter) {
      buffer
        ..writeDoc('Return the Flutter [Locale] of this locale.', indent: 2)
        ..writeln('Locale get locale {')
        ..writeln('switch (this) {');
      for (final String key in i18nMap.keys) {
        if (key.isNotEmpty) {
          final List<String> keyParts = key.split('_');
          buffer
            ..writeln('case $enumClassName.${enumName(key)}:')
            ..write('return const ')
            ..writeln(
              keyParts.length >= 3
                  ? "Locale.fromSubtags(languageCode: '${keyParts.first}', "
                      "scriptCode: '${keyParts[1]}', "
                      "countryCode: '${keyParts[2]}',);"
                  : keyParts.length == 2
                      ? "Locale('${keyParts.first}', '${keyParts.last}');"
                      : "Locale('${keyParts.single}');",
            );
        }
      }
      buffer
        ..writeln('}')
        ..writeln('}');
    }
    buffer.writeln('}');
  }

  /// Generate a
  /// {@template model}
  /// model nested from [keys].
  /// {@endtemplate}
  void generateModel(
    final StringBuffer buffer,
    final Map<String, Map<String, Object?>> i18nMap,
    final String name, {
    final Iterable<String> keys = const Iterable<String>.empty(),
  }) {
    final Map<String, Object?>? abstract = keys.isNotEmpty
        ? i18nMap['']!.getNested(keys) as Map<String, Object?>?
        : i18nMap['']!;
    final Map<String, Object?> map =
        i18nMap.getNested(<String>[name, ...keys])! as Map<String, Object?>;
    if (name.isNotEmpty && keys.isEmpty) {
      final String $name = className(name, keys);
      buffer
        ..writeDoc('The instance of [${$name}] locale.')
        ..writeln('const ${$name} ${constName(name)} = ${$name}._();')
        ..writeln();
    }

    final String groupName = keys.isEmpty ? 'root' : '`${keys.join('`/`')}`';
    buffer.writeDoc(
      name.isEmpty
          ? 'The architecture of the $groupName group.'
          : 'The [$enumClassName.${enumName(name)}] $groupName group.',
    );
    if (name.isNotEmpty) {
      buffer.writeln('@sealed');
    }
    buffer
      ..writeln('@immutable')
      ..write(name.isEmpty ? 'abstract ' : '')
      ..write('class ${className(name, keys)}');

    /// `Nested Type Argument`
    if (name.isEmpty && keys.isNotEmpty) {
      String $className = '';
      for (int index = keys.length; index > 0; index--) {
        final Iterable<String> $keys =
            keys.toList().sublist(0, keys.length - index);
        $className = $className.isEmpty
            ? className(name, $keys)
            : '${className(name, $keys)}<${$className}>';
      }
      buffer.write('<T extends ${$className}>');
    }

    if (name.isNotEmpty) {
      buffer.write(' extends ${className('', keys)}');
      if (keys.isNotEmpty) {
        final Iterable<String> $keys = keys.toList()..removeLast();
        buffer.write('<${className(name, $keys)}>');
      }
    } else if (baseClassName != null) {
      buffer.write(' extends $baseClassName<$enumClassName>');
    }
    buffer
      ..writeln(' {')

      /// `constructor`
      ..writeFunction(
        'const ${className(name, keys)}._',
        <String>[
          if (name.isEmpty) ...<String>[
            if (keys.isNotEmpty) r'this.$'
          ] else if (keys.isNotEmpty)
            'super._'
        ],
        superConstructor: name.isNotEmpty ? 'super._' : '',
      )
      ..writeln();

    /// `Fields`
    generateFields(buffer, i18nMap, name, keys: keys);

    final String typeArg = name.isEmpty && keys.isNotEmpty ? '<T>' : '';
    buffer

      /// `== operator`
      ..writeln()
      ..writeln('@override')
      ..writeFunction(
        'bool operator ==',
        <String>['final Object? other'],
        bodyFields: <String>[
          'identical(this, other) || other is ${className(name, keys)}$typeArg',
          ...<String>[
            for (final MapEntry<String, Object?> entry in map.entries)
              if (entry.key.isNotEmpty)
                entry.value is Map<String, Object?>
                    ? entry.key
                    : entry.key.removeFunctionType()
          ]
              .map((final String key) => key.split('(').first)
              .map(
                (final String key) =>
                    convert ? key.toCamelCase() : key.normalize(),
              )
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
            if (entry.key.isNotEmpty)
              entry.value is Map<String, Object?>
                  ? entry.key
                  : entry.key.removeFunctionType()
        ]
            .map((final String key) => key.split('(').first)
            .map(
              (final String key) =>
                  convert ? key.toCamelCase() : key.normalize(),
            )
            .map((final String key) => '$key.hashCode'),
        separator: ' ^ ',
      )
      ..writeln('}');

    /// `Nested Groups`
    for (final MapEntry<String, Object?> entry in <MapEntry<String, Object?>>[
      ...map.entries,
      if (name.isNotEmpty && abstract != null)
        ...abstract.entries.where(
          (final MapEntry<String, Object?> entry) =>
              !map.containsKey(entry.key),
        )
    ]) {
      if (entry.key.isNotEmpty && entry.value is Map<String, Object?>) {
        generateModel(
          buffer,
          i18nMap,
          name,
          keys: <String>[...keys, entry.key],
        );
      }
    }
  }

  /// Generate the fields for the
  /// {@macro model}
  void generateFields(
    final StringBuffer buffer,
    final Map<String, Map<String, Object?>> i18nMap,
    final String name, {
    final Iterable<String> keys = const Iterable<String>.empty(),
  }) {
    if (name.isEmpty && keys.isNotEmpty) {
      buffer
        ..writeln()
        ..writeDoc('The parent of this group.', indent: 2)
        ..writeln(r'final T $;');
    }

    final Object? abstract = i18nMap['']!.getNested(keys);
    final Map<String, Object?> map =
        i18nMap.getNested(<String>[name, ...keys])! as Map<String, Object?>;
    for (final MapEntry<String, Object?> entry in <MapEntry<String, Object?>>[
      ...map.entries,
      if (abstract is Map<String, Object?>)
        ...abstract.entries.where(
          (final MapEntry<String, Object?> entry) =>
              !map.containsKey(entry.key) &&
              entry.value is Map<String, Object?>,
        )
    ]) {
      if (name.isEmpty) {
        final String plainKey = entry.key.removeFunctionType().split('(').first;
        final String groupName =
            keys.isEmpty ? 'root' : '`${keys.join('`/`')}`';
        final String fieldType =
            entry.value is Map<String, Object?> ? 'group' : 'key';
        buffer
          ..writeln()
          ..writeDoc(
            'The `$plainKey` $fieldType in the $groupName group.',
            indent: 2,
          );
      } else if (name.isNotEmpty && entry.value == null) {
        continue;
      } else if (name.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('@override');
      }

      String? getFunctionType(final Object? value) =>
          value != null && (value is! String || !value.contains('\n'))
              ? value.runtimeType.toString()
              : null;

      final String $className;
      String $$className = '';
      if (entry.value is Map<String, Object?>) {
        if (name.isEmpty) {
          final List<String> $keys = <String>[...keys, name];
          for (int index = $keys.length; index > 0; index--) {
            final Iterable<String> $$keys =
                $keys.sublist(0, $keys.length - index);
            $$className = $$className.isEmpty
                ? className(name, $$keys)
                : '${className(name, $$keys)}<${$$className}>';
          }
        }
        $$className = $className =
            className(name, <String>[...keys, entry.key]) +
                ($$className.isNotEmpty ? '<${$$className}>' : '');
      } else if (name.isNotEmpty) {
        $className = entry.key.getFunctionType() ??
            getFunctionType(entry.value) ??
            'Object?';
      } else {
        final Set<String> values = i18nMap.values
            .map((final Map<String, Object?> map) {
              final Object? nestedMap;
              try {
                nestedMap = map.getNested(keys);
              } on FormatException catch (_) {
                return null;
              }
              if (nestedMap is! Map<String, Object?> || nestedMap.isEmpty) {
                return null;
              }
              final String key = entry.key.removeFunctionType();
              final String? nestedKey =
                  (nestedMap.keys.cast<String?>()).firstWhere(
                (final String? nestedKey) =>
                    nestedKey!.removeFunctionType() == key,
                orElse: () => null,
              );
              return nestedKey?.getFunctionType() ??
                  getFunctionType(nestedMap[nestedKey]);
            })
            .whereType<String>()
            .toSet();
        final Set<String> $values = values
            .map(
              (final String value) => value.endsWith('?')
                  ? value.substring(0, value.length - 1)
                  : value,
            )
            .toSet();

        $className = values.any((final String value) => value.endsWith('?'))
            ? ($values.length == 1 ? '${$values.single}?' : 'Object?')
            : ($values.length == 1 ? $values.single : 'Object');
      }
      buffer.write('${$className} ');

      String functionDeclaration = entry.value is Map<String, Object?>
          ? entry.key
          : entry.key.removeFunctionType();
      if (!functionDeclaration.contains('(')) {
        functionDeclaration = convert
            ? functionDeclaration.toCamelCase()
            : functionDeclaration.normalize();
        buffer.write('get $functionDeclaration');
      } else {
        final List<String> parts = functionDeclaration.split('(');
        buffer.write(
          '${convert ? parts.first.toCamelCase() : parts.first.normalize()}'
          '(${parts.last}${!parts.last.endsWith(')') ? '?' : ''}',
        );
      }

      void writeBody(final String value, [final String end = '']) {
        buffer.write(' => ');
        if (end.isNotEmpty) {
          buffer.writeDoc(
            value,
            indent: 6,
            prefix: entry.value is! Map<String, Object?> &&
                    entry.key.getFunctionType() == null &&
                    !entry.key.contains('(') &&
                    value.contains(r'$')
                ? 'r$end'
                : end,
            suffix: end,
          );
        } else {
          buffer.write(value);
        }
        buffer.writeln(';');
      }

      final Object? value = entry.value;
      if (value != null) {
        if (value is Map<String, Object?>) {
          if (name.isEmpty) {
            buffer.writeln(';');
            continue;
          }
          writeBody('${$$className}._(this)');
        } else if (value is String) {
          if (value.contains('\n')) {
            buffer
              ..writeln('{')
              ..writeln(value)
              ..writeln('}');
          } else if (value.contains('"') && value.contains("'")) {
            writeBody(value.replaceAll("'", r"\'"), "'");
          } else if (value.contains("'")) {
            writeBody(value, '"');
          } else {
            writeBody(value, "'");
          }
        } else {
          writeBody(value.toString());
        }
      } else {
        buffer.writeln(';');
      }
    }
  }
}

extension on String {
  String? getFunctionType() {
    String functionDeclaration = this;
    if (functionDeclaration.contains('(')) {
      functionDeclaration = functionDeclaration.split('(').first.trim();
    }
    if (functionDeclaration.contains('>')) {
      final List<String> functionTypeParts = functionDeclaration.split('>');
      return functionTypeParts
          .sublist(0, functionTypeParts.length - 1)
          .join('>');
    } else if (functionDeclaration.contains(' ')) {
      return functionDeclaration.split(' ').first;
    }
    return null;
  }

  String removeFunctionType() {
    final String? functionType = getFunctionType();
    return functionType != null ? substring(functionType.length).trim() : this;
  }
}

extension<T extends Object?> on Map<String, T> {
  /// Check if [other] doesn't have keys in this.
  ///
  /// Raises [FormatException] on mismatch.
  void check(
    final Map<String, T> other, {
    final String? parent,
    final String? otherParent,
  }) {
    final Map<String, T> otherMap = <String, T>{
      for (final MapEntry<String, T> entry in other.entries)
        entry.key.removeFunctionType(): entry.value
    };
    for (final MapEntry<String, T> entry in entries) {
      final String key = entry.key.removeFunctionType();
      final String parentKey = parent == null ? key : '$parent.$key';
      if (!otherMap.containsKey(key)) {
        throw FormatException(
          'Key "$parentKey" not present in "${otherParent ?? 'other'}".',
        );
      }
      final T? value1 = entry.value;
      final T? value2 = otherMap[key];
      if (value1 is Map<String, T> && value2 is Map<String, T>) {
        value1.check(
          value2,
          parent: parentKey,
          otherParent: otherParent == null ? key : '$otherParent.$key',
        );
      }
    }
  }

  // Object? getNested(final Iterable<String> keys) {
  //   Object? value = this;
  //   for (int index = 0; index < keys.length; index++) {
  //     if (value is Map<String, Object?> &&
  //         value.containsKey(keys.elementAt(index))) {
  //       value = value[keys.elementAt(index)];
  //     } else {
  //       final Iterable<String> fetchedKeys =
  //           keys.toList(growable: false).sublist(0, index);
  //       throw FormatException(
  //         'The nested key "${fetchedKeys.join('.')}" could not be fetched.',
  //       );
  //     }
  //   }
  //   return value;
  // }
}
