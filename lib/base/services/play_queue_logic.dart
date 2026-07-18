import 'package:sylvakru/base/my_audio_metadata.dart';

/// The result of moving a song within/into the play queue: where the
/// currently-playing item ends up afterward, and whether [song] wasn't
/// already queued (which callers use to decide whether it also needs to be
/// remembered in the pre-shuffle queue).
class QueueInsertResult {
  final int currentIndex;
  final bool wasNewlyInserted;

  const QueueInsertResult(this.currentIndex, this.wasNewlyInserted);
}

/// Index bookkeeping for play-queue reordering, split out of
/// [MyAudioHandler] so it can be unit tested without a live Player/platform
/// channel - it only touches the queue list and the current index, no I/O.
class PlayQueueLogic {
  /// Moves [song] to play right after [currentIndex] (or inserts it there
  /// if it isn't queued yet). Mutates [playQueue] in place. Returns null if
  /// [song] is already the currently-playing item - nothing to do.
  static QueueInsertResult? insert2Next(
    List<MyAudioMetadata> playQueue,
    int currentIndex,
    MyAudioMetadata song,
  ) {
    final songIndex = playQueue.indexOf(song);
    if (songIndex != -1) {
      if (songIndex == currentIndex) {
        return null;
      }
      playQueue.removeAt(songIndex);
      if (songIndex < currentIndex) {
        playQueue.insert(currentIndex, song);
        return QueueInsertResult(currentIndex - 1, false);
      } else {
        playQueue.insert(currentIndex + 1, song);
        return QueueInsertResult(currentIndex, false);
      }
    } else {
      playQueue.insert(currentIndex + 1, song);
      return QueueInsertResult(currentIndex, true);
    }
  }

  /// Moves [song] to the end of the queue (or appends it if it isn't
  /// queued yet). Mutates [playQueue] in place. Returns null if [song] is
  /// already the currently-playing item - nothing to do.
  static QueueInsertResult? add2Last(
    List<MyAudioMetadata> playQueue,
    int currentIndex,
    MyAudioMetadata song,
  ) {
    final songIndex = playQueue.indexOf(song);
    if (songIndex != -1) {
      if (songIndex == currentIndex) {
        return null;
      }
      final newIndex = songIndex < currentIndex
          ? currentIndex - 1
          : currentIndex;
      playQueue.removeAt(songIndex);
      playQueue.add(song);
      return QueueInsertResult(newIndex, false);
    } else {
      playQueue.add(song);
      return QueueInsertResult(currentIndex, true);
    }
  }
}
