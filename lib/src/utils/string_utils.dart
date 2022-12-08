/// Source: https://github.com/hexrcs/quartet_dart/tree/master/lib/src/case
extension StringUtils on String {
  static final RegExp _dartNamePattern =
      RegExp(r'(?!^\d)[$0-9a-zA-Z]+|^_+[$0-9a-zA-Z]+');

  /// Sets the prefix with `$` for this string if it starts with digit.
  ///
  /// Example:
  /// ```dart
  /// "123443".normalize() // will return "$123443"
  /// ```
  String normalize() =>
      isNotEmpty && !startsWith(_dartNamePattern) ? '\$$this' : this;

  /// Converts all characters of this string to camel case.
  ///
  /// Example:
  /// ```dart
  /// "dart lang".toCamelCase() // will return "dartLang"
  /// ```
  String toCamelCase({final bool normalize = true}) {
    final List<String> splitted = <String>[
      for (final Match m
          in _dartNamePattern.allMatches(normalize ? this.normalize() : this))
        m.group(0)!.toLowerCase(),
    ];
    return splitted.isEmpty
        ? ''
        : splitted.first.toLowerCase() +
            splitted.sublist(1).map((final String x) => x.capitalize()).join();
  }

  /// Converts the first character of this string to upper case.
  ///
  /// If [lowerRest] is set to true, the rest of the string will be converted
  /// to lower case.
  ///
  /// Example:
  /// ```dart
  /// "dartLang".capitalize(lowerRest: true) // will return "Dartlang"
  /// "dartLang".capitalize() // will return "DartLang"
  /// ```
  String capitalize({final bool lowerRest = false}) {
    if (isEmpty) {
      return '';
    } else if (lowerRest) {
      return this[0].toUpperCase() + substring(1).toLowerCase();
    } else {
      return this[0].toUpperCase() + substring(1);
    }
  }

  /// Converts the first character of this string to lower case.
  ///
  /// Example:
  /// ```dart
  /// "DartLang".decapitalize() // will return "dartLang"
  /// ```
  String decapitalize() => isEmpty ? '' : this[0].toLowerCase() + substring(1);
}
