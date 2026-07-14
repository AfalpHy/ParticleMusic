import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/audio_handler.dart';

void main() {
  test('恢复索引只在播放队列有效时返回', () {
    expect(restoredPlaybackIndex(-1, 3), isNull);
    expect(restoredPlaybackIndex(2, 0), isNull);
    expect(restoredPlaybackIndex(8, 3), 0);
    expect(restoredPlaybackIndex(2, 3), 2);
  });
}
