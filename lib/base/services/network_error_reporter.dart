import 'package:flutter/foundation.dart';

/// Server clients (webdav/subsonic/navidrome/emby) run deep in the data
/// layer with no BuildContext of their own, so failures can't call
/// showCenterMessage() directly. They report through here instead;
/// [ViewEntry] is the single place that listens and surfaces
/// [lastNetworkErrorMessage] to the user.
final networkErrorNotifier = ValueNotifier(0);
String? lastNetworkErrorMessage;

DateTime? _lastReportTime;

/// Debounced globally across all sources: a sync loop hitting a downed
/// server for hundreds of songs should surface one toast, not hundreds.
void reportNetworkError(String sourceLabel, String message) {
  final now = DateTime.now();
  if (_lastReportTime != null &&
      now.difference(_lastReportTime!) < const Duration(seconds: 5)) {
    return;
  }
  _lastReportTime = now;
  lastNetworkErrorMessage = '$sourceLabel: $message';
  networkErrorNotifier.value++;
}
