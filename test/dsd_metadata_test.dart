import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/dsd_metadata.dart';

// 手工构造 KB 级 DSF/DFF 头部验证解析（不使用版权音频）
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dsd_metadata_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<String> writeFile(String name, List<int> bytes) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('DSF 头部解析出速率/时长，尾部 ID3v2.3 文本帧生效', () async {
    final builder = BytesBuilder();
    const sampleRate = 2822400;
    const channels = 2;
    const sampleCount = 2822400 * 2; // 每通道 2 秒
    final audioBytes = Uint8List(64); // 音频体不参与解析，给个占位
    final id3 = _buildId3v23(
      {
        'TIT2': 'DSD 测试曲',
        'TPE1': '测试艺人',
        'TALB': '测试专辑',
        'TRCK': '3/12',
        'TYER': '2020',
      },
      userTextFrames: {
        'replaygain_track_gain': ' -7.25 dB ',
        'REPLAYGAIN_TRACK_PEAK': '0.9876',
        'ReplayGain_Album_Gain': '+1.50 DB',
        'REPLAYGAIN_ALBUM_PEAK': '1.2345',
      },
    );
    final metadataOffset = 28 + 52 + 12 + audioBytes.length;

    builder.add('DSD '.codeUnits);
    builder.add(_longLe(28));
    builder.add(_longLe(metadataOffset + id3.length));
    builder.add(_longLe(metadataOffset));
    builder.add('fmt '.codeUnits);
    builder.add(_longLe(52));
    builder.add(_intLe(1)); // formatVersion
    builder.add(_intLe(0)); // formatId
    builder.add(_intLe(2)); // channelType
    builder.add(_intLe(channels));
    builder.add(_intLe(sampleRate));
    builder.add(_intLe(1)); // bitsPerSample
    builder.add(_longLe(sampleCount));
    builder.add(_intLe(4096)); // blockSizePerChannel
    builder.add(_intLe(0)); // reserved
    builder.add('data'.codeUnits);
    builder.add(_longLe(12 + audioBytes.length));
    builder.add(audioBytes);
    builder.add(id3);

    final path = await writeFile('sample.dsf', builder.toBytes());
    final metadata = await readDsdMetadata(path);

    expect(metadata, isNotNull);
    expect(metadata!.format, 'dsf');
    expect(metadata.samplerate, sampleRate);
    expect(metadata.duration, const Duration(seconds: 2));
    expect(metadata.title, 'DSD 测试曲');
    expect(metadata.artist, '测试艺人');
    expect(metadata.album, '测试专辑');
    expect(metadata.track, 3);
    expect(metadata.year, 2020);
    expect(metadata.replayGainTrackGainDb, -7.25);
    expect(metadata.replayGainTrackPeak, 0.9876);
    expect(metadata.replayGainAlbumGainDb, 1.5);
    expect(metadata.replayGainAlbumPeak, 1.2345);
  });

  test('DSF ID3v2.3 TXXX 忽略非有限增益和非正峰值', () async {
    final id3 = _buildId3v23(
      const {},
      userTextFrames: {
        'REPLAYGAIN_TRACK_GAIN': 'NaN dB',
        'REPLAYGAIN_TRACK_PEAK': '0',
        'REPLAYGAIN_ALBUM_GAIN': 'Infinity dB',
        'REPLAYGAIN_ALBUM_PEAK': '-0.25',
      },
    );
    final path = await writeFile('invalid_gain.dsf', _buildDsf(id3));

    final metadata = await readDsdMetadata(path);

    expect(metadata, isNotNull);
    expect(metadata!.replayGainTrackGainDb, isNull);
    expect(metadata.replayGainTrackPeak, isNull);
    expect(metadata.replayGainAlbumGainDb, isNull);
    expect(metadata.replayGainAlbumPeak, isNull);
  });

  test('DSF ID3v2.3 TXXX 按帧编码拆分 description 和 value', () async {
    final id3 = _buildId3v23(
      const {},
      encodedUserTextFrames: {
        'REPLAYGAIN_TRACK_GAIN': (0, '-4.0 dB'),
        'REPLAYGAIN_TRACK_PEAK': (1, '0.8'),
        'REPLAYGAIN_ALBUM_GAIN': (2, '-5.0 dB'),
        'REPLAYGAIN_ALBUM_PEAK': (3, '1.05'),
      },
    );
    final path = await writeFile('encoded_gain.dsf', _buildDsf(id3));

    final metadata = await readDsdMetadata(path);

    expect(metadata, isNotNull);
    expect(metadata!.replayGainTrackGainDb, -4.0);
    expect(metadata.replayGainTrackPeak, 0.8);
    expect(metadata.replayGainAlbumGainDb, -5.0);
    expect(metadata.replayGainAlbumPeak, 1.05);
  });

  test('DSF ID3v2.4 TXXX 按 syncsafe 帧大小解析 ReplayGain', () async {
    final id3 = _buildId3v23(
      const {},
      majorVersion: 4,
      userTextFrames: {
        'REPLAYGAIN_TRACK_GAIN': '-8.5 dB',
        'REPLAYGAIN_TRACK_PEAK': '0.75',
      },
    );
    final path = await writeFile('id3v24_gain.dsf', _buildDsf(id3));

    final metadata = await readDsdMetadata(path);

    expect(metadata, isNotNull);
    expect(metadata!.replayGainTrackGainDb, -8.5);
    expect(metadata.replayGainTrackPeak, 0.75);
  });

  test('DSF ID3 不读取超出标签声明边界的 TXXX 帧', () async {
    final id3 = _buildId3v23(
      const {},
      declaredSizeAdjustment: -5,
      userTextFrames: {'REPLAYGAIN_TRACK_GAIN': '-9.0 dB'},
    );
    final path = await writeFile('truncated_id3_boundary.dsf', _buildDsf(id3));

    final metadata = await readDsdMetadata(path);

    expect(metadata, isNotNull);
    expect(metadata!.replayGainTrackGainDb, isNull);
  });

  test('DFF 头部解析出速率/声道/时长', () async {
    const sampleRate = 5644800;
    const channels = 2;
    // 每通道 1 秒 = 705600 字节
    final audio = Uint8List(sampleRate ~/ 8 * channels);

    final prop = BytesBuilder();
    prop.add('SND '.codeUnits);
    prop.add('FS  '.codeUnits);
    prop.add(_longBe(4));
    prop.add(_intBe(sampleRate));
    prop.add('CHNL'.codeUnits);
    prop.add(_longBe(2 + channels * 4));
    prop.add(_shortBe(channels));
    prop.add('SLFTSRGT'.codeUnits);
    final propBytes = prop.toBytes();

    final body = BytesBuilder();
    body.add('DSD '.codeUnits);
    body.add('FVER'.codeUnits);
    body.add(_longBe(4));
    body.add(_intBe(0x01050000));
    body.add('PROP'.codeUnits);
    body.add(_longBe(propBytes.length));
    body.add(propBytes);
    body.add('DSD '.codeUnits);
    body.add(_longBe(audio.length));
    body.add(audio);
    final bodyBytes = body.toBytes();

    final builder = BytesBuilder();
    builder.add('FRM8'.codeUnits);
    builder.add(_longBe(bodyBytes.length));
    builder.add(bodyBytes);

    final path = await writeFile('sample.dff', builder.toBytes());
    final metadata = await readDsdMetadata(path);

    expect(metadata, isNotNull);
    expect(metadata!.format, 'dff');
    expect(metadata.samplerate, sampleRate);
    expect(metadata.duration, const Duration(seconds: 1));
  });

  test('非 DSD 文件返回 null', () async {
    final path = await writeFile('not_dsd.dsf', 'RIFF0000WAVE'.codeUnits);
    expect(await readDsdMetadata(path), isNull);
  });

  test('DFF 只有头部字节时按远程总长换算时长', () async {
    const sampleRate = 2822400;
    const channels = 2;
    // 每通道 2 秒的数据大小，但本地只落头部 + 少量数据
    final dataBytes = sampleRate ~/ 8 * 2 * channels;

    final prop = BytesBuilder();
    prop.add('SND '.codeUnits);
    prop.add('FS  '.codeUnits);
    prop.add(_longBe(4));
    prop.add(_intBe(sampleRate));
    prop.add('CHNL'.codeUnits);
    prop.add(_longBe(2 + channels * 4));
    prop.add(_shortBe(channels));
    prop.add('SLFTSRGT'.codeUnits);
    final propBytes = prop.toBytes();

    final body = BytesBuilder();
    body.add('DSD '.codeUnits);
    body.add('FVER'.codeUnits);
    body.add(_longBe(4));
    body.add(_intBe(0x01050000));
    body.add('PROP'.codeUnits);
    body.add(_longBe(propBytes.length));
    body.add(propBytes);
    body.add('DSD '.codeUnits);
    body.add(_longBe(dataBytes));
    body.add(Uint8List(16)); // 数据只落了 16 字节

    final builder = BytesBuilder();
    builder.add('FRM8'.codeUnits);
    builder.add(_longBe(body.length + dataBytes - 16));
    builder.add(body.toBytes());

    final headOnly = builder.toBytes();
    final path = await writeFile('head_only.dff', headOnly);
    final totalLength = headOnly.length + dataBytes - 16;

    final metadata = await readDsdMetadata(
      path,
      remoteTotalLength: totalLength,
    );
    expect(metadata, isNotNull);
    expect(metadata!.samplerate, sampleRate);
    expect(metadata.duration, const Duration(seconds: 2));
  });
}

Uint8List _buildId3v23(
  Map<String, String> textFrames, {
  int majorVersion = 3,
  int declaredSizeAdjustment = 0,
  Map<String, String> userTextFrames = const {},
  Map<String, (int, String)> encodedUserTextFrames = const {},
}) {
  final frames = BytesBuilder();
  List<int> frameSize(int value) =>
      majorVersion >= 4 ? _syncsafe(value) : _intBe(value);
  textFrames.forEach((id, value) {
    // UTF-8 编码（encoding byte = 3）
    final encoded = <int>[3, ...utf8.encode(value)];
    frames.add(id.codeUnits);
    frames.add(frameSize(encoded.length));
    frames.add([0, 0]); // flags
    frames.add(encoded);
  });
  userTextFrames.forEach((description, value) {
    final encoded = _encodeTxxx(description, value, 3);
    frames.add('TXXX'.codeUnits);
    frames.add(frameSize(encoded.length));
    frames.add([0, 0]);
    frames.add(encoded);
  });
  encodedUserTextFrames.forEach((description, entry) {
    final encoded = _encodeTxxx(description, entry.$2, entry.$1);
    frames.add('TXXX'.codeUnits);
    frames.add(frameSize(encoded.length));
    frames.add([0, 0]);
    frames.add(encoded);
  });
  final frameBytes = frames.toBytes();

  final builder = BytesBuilder();
  builder.add('ID3'.codeUnits);
  builder.add([majorVersion, 0, 0]);
  builder.add(_syncsafe(frameBytes.length + declaredSizeAdjustment));
  builder.add(frameBytes);
  return builder.toBytes();
}

List<int> _encodeTxxx(String description, String value, int encoding) {
  if (encoding == 0 || encoding == 3) {
    final encode = encoding == 3
        ? utf8.encode
        : (String text) => text.codeUnits;
    return [encoding, ...encode(description), 0, ...encode(value)];
  }
  List<int> utf16(String text, Endian endian) => [
    for (final unit in text.codeUnits)
      if (endian == Endian.little) ...[
        unit & 0xff,
        unit >> 8,
      ] else ...[
        unit >> 8,
        unit & 0xff,
      ],
  ];
  final endian = encoding == 2 ? Endian.big : Endian.little;
  return [
    encoding,
    if (encoding == 1) ...[0xff, 0xfe],
    ...utf16(description, endian),
    0,
    0,
    ...utf16(value, endian),
  ];
}

Uint8List _buildDsf(Uint8List id3) {
  const sampleRate = 2822400;
  const channels = 2;
  const sampleCount = sampleRate;
  final audioBytes = Uint8List(16);
  final metadataOffset = 28 + 52 + 12 + audioBytes.length;
  final builder = BytesBuilder();
  builder.add('DSD '.codeUnits);
  builder.add(_longLe(28));
  builder.add(_longLe(metadataOffset + id3.length));
  builder.add(_longLe(metadataOffset));
  builder.add('fmt '.codeUnits);
  builder.add(_longLe(52));
  builder.add(_intLe(1));
  builder.add(_intLe(0));
  builder.add(_intLe(2));
  builder.add(_intLe(channels));
  builder.add(_intLe(sampleRate));
  builder.add(_intLe(1));
  builder.add(_longLe(sampleCount));
  builder.add(_intLe(4096));
  builder.add(_intLe(0));
  builder.add('data'.codeUnits);
  builder.add(_longLe(12 + audioBytes.length));
  builder.add(audioBytes);
  builder.add(id3);
  return builder.toBytes();
}

List<int> _syncsafe(int value) => [
  (value >> 21) & 0x7f,
  (value >> 14) & 0x7f,
  (value >> 7) & 0x7f,
  value & 0x7f,
];

List<int> _intLe(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

List<int> _longLe(int value) => [
  for (var index = 0; index < 8; index++) (value >> (index * 8)) & 0xff,
];

List<int> _intBe(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

List<int> _shortBe(int value) => [(value >> 8) & 0xff, value & 0xff];

List<int> _longBe(int value) => [
  for (var index = 7; index >= 0; index--) (value >> (index * 8)) & 0xff,
];
