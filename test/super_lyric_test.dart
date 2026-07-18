import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/services/super_lyric.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.afalphy.sylvakru/super_lyric');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('重置后会重新发布当前歌词行', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final superLyric = SuperLyric();
    superLyric.updateLines([
      LyricLine(Duration.zero, 'current line', const []),
    ]);

    await superLyric.publishAt(Duration.zero);
    superLyric.reset();
    await superLyric.publishAt(Duration.zero);

    expect(calls.map((call) => call.method), ['sendLyric', 'sendLyric']);
  });
}
