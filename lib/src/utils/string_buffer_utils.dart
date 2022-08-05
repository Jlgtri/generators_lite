import 'dart:convert';

import 'sort_imports.dart';

/// The extension with useful methods for [StringBuffer].
extension StringBufferUtils on StringBuffer {
  static final RegExp _whiteSpacePattern = RegExp(r'\s+', caseSensitive: false);

  /// Write package [imports] Dart-style.
  ///
  /// Sort imports and correct indentation.
  void writeImports(final Iterable<String> imports) {
    bool wasDart = imports.any((final String _) => _.startsWith('dart:'));
    bool wasPackage = imports.any((final String _) => _.startsWith('package:'));
    for (final String import in imports.toList()..sort(sortImports)) {
      if (wasDart && !import.startsWith('dart:')) {
        writeln();
        wasDart = false;
      } else if (wasPackage && !import.startsWith('package:')) {
        writeln();
        wasPackage = false;
      }
      writeln("import '$import';");
    }
  }

  /// Generate a whole function block named [constructor] with [fields] as
  /// values.
  void writeFunction(
    final String constructor,
    final Iterable<String> fields, {
    final String bodyConstructor = '',
    final Iterable<String> bodyFields = const Iterable<String>.empty(),
    final String superConstructor = '',
    final Iterable<String> superFields = const Iterable<String>.empty(),
    final bool useBrackets = false,
    final String separator = ', ',
  }) {
    String $constructor = constructor.trim();
    if ($constructor.endsWith('(')) {
      $constructor = $constructor.substring(0, $constructor.length - 1);
    }
    assert($constructor.isNotEmpty, 'Constuctor should not be empty.');
    String $body = bodyConstructor.trim();
    write($constructor);
    if (!$constructor.contains(' get ')) {
      write('(');
    }
    if (fields.isNotEmpty) {
      if (useBrackets) {
        write('{');
      }
      final String oneLine = fields.join(', ');
      if ($constructor.length +
              oneLine.length +
              (useBrackets ? 4 : 2) +
              ($body.isNotEmpty || bodyFields.isNotEmpty ? 3 : 0) <=
          80 - 2) {
        write(oneLine);
      } else {
        fields.map((final String field) => '$field,').forEach(write);
      }
      if (useBrackets) {
        write('}');
      }
    }
    if (!$constructor.contains(' get ')) {
      write(')');
      if (superConstructor.isNotEmpty) {
        write(' : $superConstructor(');
        if (superFields.isNotEmpty) {
          final String oneLine = superFields.join(', ');
          if (oneLine.length <= 80 - '      : $superConstructor();'.length) {
            write(oneLine);
          } else {
            superFields.map((final String field) => '$field,').forEach(write);
          }
        }
        write(')');
      }
    }

    if ($body.isNotEmpty || bodyFields.isNotEmpty) {
      write(' => ');
    }
    String quote = '';
    for (final String quote_ in <String>["'''", '"""', "'", '"']) {
      if ($body.startsWith(quote_)) {
        quote = quote_;
        break;
      }
    }
    if (($body.isNotEmpty && quote.isEmpty) &&
        !($body.endsWith('[') || $body.endsWith('{') || $body.endsWith('('))) {
      $body += '(';
    }
    final String end = $body.endsWith('[')
        ? ']'
        : $body.endsWith('{')
            ? '}'
            : $body.endsWith('(')
                ? ')'
                : '';

    if (bodyFields.isNotEmpty) {
      final String oneLine = bodyFields.join(separator);
      if ($body.length + oneLine.length + '$end;'.length <= 80 - 2 * 3) {
        write($body + oneLine);
      } else if (quote.isNotEmpty) {
        final StringBuffer line = StringBuffer($body);
        for (final String field in bodyFields) {
          if (line.toString() != $body) {
            line.write(separator);
          }
          if (line.length + field.length + separator.length + quote.length >
              80 - 2 * 3) {
            line.write(quote);
            write(line.toString());
            line
              ..clear()
              ..write(quote);
          }
          line.write(field);
        }
        write(line.toString());
      } else if (separator.trim() == ',') {
        write($body);
        bodyFields
            .map((final String field) => '$field$separator')
            .forEach(write);
      } else {
        write($body + bodyFields.join(separator));
      }
    } else {
      write($body);
    }
    writeln('$end$quote;');
  }

  /// Writes the [value] as documentation using Dart style.
  ///
  /// Automatically adds needed line breaks, but preserves existing ones.
  ///
  /// - **[prefix]** is set for each line in the [value], splitted by `\n`.
  /// - **[separator]** joins the words on a single line.
  /// - **[indent]** is the amount of spaces to be set before the line.
  /// - **[lineLength]** is used to calculate line breaks for each line.
  ///   - If the line in the [value] doesn't conform to the *[lineLength]*
  ///   bounds, it splits the line by `\s+` separator, and the continues on the
  ///   new line.
  ///   - If the splited value is too long to be set on one line, it is splitted
  ///   by characters to be in bounds with *[lineLength]*.
  void writeDoc(
    final String value, {
    final String prefix = '/// ',
    final String separator = ' ',
    final int indent = 2,
    final int lineLength = 80,
  }) {
    final int $lineLength = lineLength - prefix.length - indent;
    for (String line
        in const LineSplitter().convert(value.isEmpty ? '\n' : value)) {
      final String $prefix = prefix.trim();
      if ($prefix.isNotEmpty) {
        while ((line = line.trimLeft()).startsWith($prefix)) {
          line = line.replaceFirst($prefix, '');
        }
      }

      final List<String> currentWords = <String>[if (line.isEmpty) line];
      void writeWords() {
        if (currentWords.isNotEmpty) {
          final String line =
              ' ' * indent + prefix + currentWords.join(separator);
          writeln(line.trimRight());
          currentWords.clear();
        }
      }

      for (final String word in line.split(_whiteSpacePattern)) {
        final int currentLength = currentWords.fold<int>(
          currentWords.isNotEmpty ? currentWords.length * separator.length : 0,
          (final int length, final String word) => length + word.length,
        );
        if (currentLength + word.length < $lineLength) {
          currentWords.add(word);
        } else if (word.length >= $lineLength * 2 - currentLength) {
          int index = $lineLength - currentLength;
          currentWords.add(word.substring(0, index));
          writeWords();
          while (index + $lineLength < word.length) {
            write(' ' * indent + prefix);
            writeln(word.substring(index, index += $lineLength));
          }
          final String wordLeft = word.substring(index);
          if (wordLeft.isNotEmpty) {
            currentWords.add(wordLeft);
          }
        } else {
          writeWords();
          currentWords.add(word);
        }
      }
      writeWords();
    }
  }
}
