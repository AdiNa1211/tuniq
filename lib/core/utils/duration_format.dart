/// Formats as m:ss, or h:mm:ss for an hour or more.
String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$seconds'
      : '$minutes:$seconds';
}

/// Album length: "42 min" or "1 hr 5 min".
String formatTotalDuration(Duration d) {
  final hours = d.inHours;
  return hours > 0 ? '$hours hr ${d.inMinutes.remainder(60)} min' : '${d.inMinutes} min';
}
