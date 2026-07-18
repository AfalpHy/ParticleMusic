import 'dart:io';

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/app.dart' as app;
import 'package:sylvakru/base/data/database.dart';
import 'package:sylvakru/base/extensions/metadata_extension.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';

void main() {
  late Directory appSupportDirectory;

  setUpAll(() async {
    appSupportDirectory = await Directory.systemTemp.createTemp(
      'metadata_database_test',
    );
    app.appSupportDir = appSupportDirectory;
  });

  tearDownAll(() async {
    await appSupportDirectory.delete(recursive: true);
  });

  test('ReplayGain 四项元数据可完整写入并读回', () async {
    final database = MetadataDB(NativeDatabase.memory());
    addTearDown(database.close);
    final metadata = MyAudioMetadata(
      AudioMetadata(
        title: 'ReplayGain test',
        replayGainTrackGainDb: -7.25,
        replayGainTrackPeak: 0.987654321,
        replayGainAlbumGainDb: -5.75,
        replayGainAlbumPeak: 1.012345678,
      ),
      id: 'replaygain-values',
    );

    await database.into(database.metadataItems).insert(metadata.toCompanion());
    final restored = (await database.select(database.metadataItems).getSingle())
        .toMetadata();

    expect(restored.replayGainTrackGainDb, -7.25);
    expect(restored.replayGainTrackPeak, 0.987654321);
    expect(restored.replayGainAlbumGainDb, -5.75);
    expect(restored.replayGainAlbumPeak, 1.012345678);
  });

  test('ReplayGain 空值可完整写入并读回', () async {
    final database = MetadataDB(NativeDatabase.memory());
    addTearDown(database.close);
    final metadata = MyAudioMetadata(
      AudioMetadata(title: 'ReplayGain null test'),
      id: 'replaygain-null',
    );

    await database.into(database.metadataItems).insert(metadata.toCompanion());
    final restored = (await database.select(database.metadataItems).getSingle())
        .toMetadata();

    expect(restored.replayGainTrackGainDb, isNull);
    expect(restored.replayGainTrackPeak, isNull);
    expect(restored.replayGainAlbumGainDb, isNull);
    expect(restored.replayGainAlbumPeak, isNull);
  });
}
