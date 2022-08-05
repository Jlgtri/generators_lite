import 'dart:collection';

/// The utility to convert  for working with map.
extension ObjectToMap on Object? {
  /// Create a map from this object. Flatten iterables and normalize maps.
  Map<T, Object?> toMap<T extends Object?>() => <T, Object?>{
        if (this is Map<Object?, Object?>)
          ...(this! as Map<Object?, Object?>).cast<T, Object?>().normalize()
        else if (this is MapMixin<Object?, Object?>)
          ...(this! as MapMixin<Object?, Object?>)
              .cast<T, Object?>()
              .normalize()
        else if (this is Iterable<Object?>)
          for (final Object? object in this! as Iterable<Object?>)
            ...object.toMap<T>()
      };
}

/// The utilities for working with map.
extension MapUtils<T extends Object?> on Map<T, Object?> {
  /// Return this map with all values converted to map.
  Map<T, Object?> normalize() => <T, Object?>{
        for (final MapEntry<T, Object?> entry in entries)
          entry.key: entry.value is MapMixin<Object?, Object?>
              ? <T, Object?>{
                  ...(entry.value! as MapMixin<Object?, Object?>)
                      .cast<T, Object?>()
                }.normalize()
              : entry.value is Map<Object?, Object?>
                  ? (entry.value! as Map<Object?, Object?>)
                      .cast<T, Object?>()
                      .normalize()
                  : entry.value
      };

  /// Return this map with all values set to null.
  Map<T, Object?> onlyKeys() => <T, Object?>{
        for (final MapEntry<T, Object?> entry in entries)
          entry.key: entry.value is Map<T, Object?>
              ? (entry.value! as Map<T, Object?>).onlyKeys()
              : null
      };

  /// Nest the [value] in this map within [keys].
  ///
  /// If [keys] is empty, returns [value].
  void nest(final Iterable<T> keys, final Object? value) {
    if (keys.isEmpty) {
      return;
    } else if (keys.length == 1) {
      this[keys.single] = value;
    } else {
      final List<T> $keys = keys.toList();
      final T lastKey = $keys.removeLast();
      Map<T, Object?> nested = this;
      for (final T key in $keys) {
        nested = nested[key] = <T, Object?>{};
      }
      nested[lastKey] = value;
    }
  }

  /// Nest the nested value in this map within [keys].
  ///
  /// If [keys] is empty, returns null.
  Object? getNested(final Iterable<T> keys) {
    Object? nested = this;
    for (final T key in keys) {
      if (nested is! Map<T, Object?>) {
        return null;
      }
      nested = nested[key];
    }
    return nested;
  }
}
