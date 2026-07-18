import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

void main() {
  test('恢复索引只在播放队列有效时返回', () {
    expect(restoredPlaybackIndex(-1, 3), isNull);
    expect(restoredPlaybackIndex(2, 0), isNull);
    expect(restoredPlaybackIndex(8, 3), 0);
    expect(restoredPlaybackIndex(2, 3), 2);
  });

  test('中断状态为零或倒退时保留最后可信独占位置', () {
    expect(
      trustedUsbExclusivePosition(
        current: const Duration(minutes: 2),
        reported: Duration.zero,
        stateActive: false,
      ),
      const Duration(minutes: 2),
    );
    expect(
      trustedUsbExclusivePosition(
        current: const Duration(minutes: 2),
        reported: const Duration(seconds: 110),
        stateActive: false,
      ),
      const Duration(minutes: 2),
    );
  });

  test('活动会话允许用户向前或向后 seek', () {
    expect(
      trustedUsbExclusivePosition(
        current: const Duration(minutes: 2),
        reported: const Duration(seconds: 30),
        stateActive: true,
      ),
      const Duration(seconds: 30),
    );
  });

  test('只有意外失活且没有进行中的交接才启动共享回退', () {
    expect(
      shouldStartUsbOutputHandoff(
        wasActive: true,
        intentionalStop: false,
        handoffInProgress: false,
        completed: false,
      ),
      isTrue,
    );
    expect(
      shouldStartUsbOutputHandoff(
        wasActive: true,
        intentionalStop: true,
        handoffInProgress: false,
        completed: false,
      ),
      isFalse,
    );
    expect(
      shouldStartUsbOutputHandoff(
        wasActive: true,
        intentionalStop: false,
        handoffInProgress: true,
        completed: false,
      ),
      isFalse,
    );
    expect(
      shouldStartUsbOutputHandoff(
        wasActive: true,
        intentionalStop: false,
        handoffInProgress: false,
        completed: true,
      ),
      isFalse,
    );
  });
}
