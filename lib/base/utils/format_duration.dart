String formatDuration(Duration duration, {bool ms = true}) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  if (ms) {
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  return "${twoDigits((duration.inMinutes / 60).toInt())}:${twoDigits((duration.inMinutes.remainder(60)).toInt())}";
}
