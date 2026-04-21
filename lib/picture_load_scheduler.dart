import 'dart:async';
import 'dart:typed_data';

PictureLoadScheduler pictureLoadScheduler = PictureLoadScheduler();

class PictureLoadScheduler {
  final int maxConcurrent;

  int _running = 0;
  final _queue = <_Task>[];

  final Map<String, Future<Uint8List?>> _inFlight = {};

  PictureLoadScheduler({this.maxConcurrent = 5});

  Future<Uint8List?> load(String key, Future<Uint8List?> Function() loader) {
    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!;
    }

    final completer = Completer<Uint8List?>();

    final task = _Task(() async {
      try {
        final result = await loader();

        completer.complete(result);
      } catch (_, _) {
        completer.complete(null);
      } finally {
        _inFlight.remove(key);
        _running--;
        _schedule();
      }
    });

    _inFlight[key] = completer.future;
    _queue.add(task);

    _schedule();

    return completer.future;
  }

  void _schedule() {
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _running++;
      task.run();
    }
  }
}

class _Task {
  final Future<void> Function() run;
  _Task(this.run);
}
