/// The implementation of a [Comparable] to sort Dart imports.
int sortImports(final String a, final String b) {
  int value;
  final bool dartA = a.startsWith('dart:');
  final bool dartB = b.startsWith('dart:');
  if ((value = (dartA ? 0 : 1).compareTo(dartB ? 0 : 1)) != 0) {
  } else {
    final bool packageA = a.startsWith('package:');
    final bool packageB = b.startsWith('package:');
    if ((value = (packageA ? 0 : 1).compareTo(packageB ? 0 : 1)) != 0) {
    } else {
      num dotCountA = 0;
      num dotCountB = 0;
      while (a.startsWith('.', dotCountA.toInt())) {
        dotCountA++;
      }
      while (b.startsWith('.', dotCountB.toInt())) {
        dotCountB++;
      }
      dotCountA = dotCountA == 0 ? double.infinity : dotCountA;
      dotCountB = dotCountB == 0 ? double.infinity : dotCountB;
      if ((value = dotCountA.compareTo(dotCountB)) != 0) {
      } else if ((value = a.compareTo(b)) != 0) {}
    }
  }
  return value;
}
