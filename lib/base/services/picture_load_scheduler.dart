import 'dart:async';

PictureLoadScheduler pictureLoadScheduler = PictureLoadScheduler();

class PictureLoadScheduler {
  final int maxConcurrent = 6;

  int _running = 0;
  final _queue = <_Task>[];

  final Map<String, Future<void>> _inFlight = {};

  Future<void> load(String key, Future<void> Function() loader) {
    if (_inFlight.containsKey(key)) {
      return _inFlight[key]!;
    }

    final completer = Completer<void>();

    final task = _Task(key, () async {
      try {
        await loader();
        completer.complete();
      } catch (_) {
        completer.complete();
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

  // TODO
  void release(String key) {}
}

class _Task {
  final String key;
  final Future<void> Function() run;
  _Task(this.key, this.run);
}
