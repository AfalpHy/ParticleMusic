String formatDuration(Duration duration, {bool ms = true}) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  if (ms) {
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  return "${twoDigits((duration.inMinutes / 60).toInt())}:${twoDigits(duration.inMinutes.remainder(60))}";
}

int compareVersion(String a, String b) {
  final aParts = a.split('.').map(int.parse).toList();
  final bParts = b.split('.').map(int.parse).toList();

  final length = aParts.length > bParts.length ? aParts.length : bParts.length;

  for (int i = 0; i < length; i++) {
    final aVal = i < aParts.length ? aParts[i] : 0;
    final bVal = i < bParts.length ? bParts[i] : 0;

    if (aVal != bVal) {
      return aVal.compareTo(bVal);
    }
  }
  return 0;
}
