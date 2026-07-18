import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/play_queue_logic.dart';

MyAudioMetadata song(String id) {
  return MyAudioMetadata(AudioMetadata(title: id), id: id);
}

void main() {
  // MyAudioMetadata's constructor reads from appSupportDir to check for a
  // cached cover art file; it only needs to exist, not actually contain
  // anything relevant to these tests.
  setUpAll(() {
    appSupportDir = Directory.systemTemp.createTempSync('sylvakru_test');
  });

  group('PlayQueueLogic.insert2Next', () {
    test('does nothing when the song is already playing', () {
      final queue = [song('a'), song('b')];
      final result = PlayQueueLogic.insert2Next(queue, 0, queue[0]);

      expect(result, isNull);
      expect(queue.map((e) => e.id), ['a', 'b']);
    });

    test('inserts a brand-new song right after currentIndex', () {
      final queue = [song('a'), song('b')];
      final newSong = song('c');
      final result = PlayQueueLogic.insert2Next(queue, 0, newSong);

      expect(result!.currentIndex, 0);
      expect(result.wasNewlyInserted, isTrue);
      expect(queue.map((e) => e.id), ['a', 'c', 'b']);
    });

    test(
      'moves a song from later in the queue to right after currentIndex',
      () {
        final queue = [song('a'), song('b'), song('c')];
        // 'c' is already queued after the current song ('a').
        final result = PlayQueueLogic.insert2Next(queue, 0, queue[2]);

        expect(result!.currentIndex, 0);
        expect(result.wasNewlyInserted, isFalse);
        expect(queue.map((e) => e.id), ['a', 'c', 'b']);
      },
    );

    test(
      'moving a song from earlier in the queue shifts currentIndex back by one',
      () {
        final queue = [song('a'), song('b'), song('c'), song('d')];
        // 'a' is queued before the current song ('c' at index 2).
        final result = PlayQueueLogic.insert2Next(queue, 2, queue[0]);

        expect(result!.currentIndex, 1);
        expect(result.wasNewlyInserted, isFalse);
        expect(queue.map((e) => e.id), ['b', 'c', 'a', 'd']);
      },
    );
  });

  group('PlayQueueLogic.add2Last', () {
    test('does nothing when the song is already playing', () {
      final queue = [song('a'), song('b')];
      final result = PlayQueueLogic.add2Last(queue, 0, queue[0]);

      expect(result, isNull);
      expect(queue.map((e) => e.id), ['a', 'b']);
    });

    test('appends a brand-new song to the end', () {
      final queue = [song('a'), song('b')];
      final newSong = song('c');
      final result = PlayQueueLogic.add2Last(queue, 0, newSong);

      expect(result!.currentIndex, 0);
      expect(result.wasNewlyInserted, isTrue);
      expect(queue.map((e) => e.id), ['a', 'b', 'c']);
    });

    test(
      'moving a song from before currentIndex to the end shifts currentIndex back',
      () {
        final queue = [song('a'), song('b'), song('c')];
        // 'a' is queued before the current song ('c' at index 2).
        final result = PlayQueueLogic.add2Last(queue, 2, queue[0]);

        expect(result!.currentIndex, 1);
        expect(result.wasNewlyInserted, isFalse);
        expect(queue.map((e) => e.id), ['b', 'c', 'a']);
      },
    );

    test(
      'moving a song from after currentIndex to the end leaves currentIndex unchanged',
      () {
        final queue = [song('a'), song('b'), song('c')];
        // 'c' is queued after the current song ('a' at index 0).
        final result = PlayQueueLogic.add2Last(queue, 0, queue[2]);

        expect(result!.currentIndex, 0);
        expect(result.wasNewlyInserted, isFalse);
        expect(queue.map((e) => e.id), ['a', 'b', 'c']);
      },
    );
  });
}
