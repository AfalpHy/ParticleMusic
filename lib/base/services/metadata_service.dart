import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/subsonic_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/picture_load_scheduler.dart';
import 'package:sylvakru/base/utils/path.dart';

Future<void> loadPictureSafe(MyAudioMetadata? song) async {
  if (song == null || song.pictureLoaded) {
    return;
  }
  return pictureLoadScheduler.load(song.id, () => _loadPicture(song));
}

Future<void> _loadPicture(MyAudioMetadata song) async {
  try {
    Uint8List? bytes;

    switch (song.sourceType) {
      case .local:
        bytes = await readPictureAsync(song.path!);
        break;
      case .webdav:
        final tmpPath = await convertToRealPathIfNeed(song.path!);
        if (tmpPath == null) {
          bytes = await readPictureAsync(
            song.path!,
            headers: webdavClient?.headers,
          );
        } else {
          bytes = await readPictureAsync(tmpPath);
        }
        break;
      case .subsonic:
        bytes = await subsonicClient!.getPictureBytes(song.id);
        break;
      case .navidrome:
        bytes = await navidromeClient!.getPictureBytes(song.id);
        break;
      default:
        bytes = await embyClient!.getPictureBytes(song.id);
        break;
    }

    if (bytes != null) {
      File pictureFile = File(song.picturePath);
      if (!await pictureFile.exists()) {
        await pictureFile.create(recursive: true);
      }
      await pictureFile.writeAsBytes(bytes);
      song.pictureExist = true;
    }
  } catch (e) {
    logger.output(e.toString());
  }
  song.pictureLoaded = true;
}

Future<Color> computeCoverArtColor(MyAudioMetadata? song) async {
  if (song?.coverArtColor != null) {
    return song!.coverArtColor!;
  }
  Uint8List? bytes;
  await loadPictureSafe(song);

  if (song?.pictureExist == true) {
    File pictureFile = File(song!.picturePath);
    if (await pictureFile.exists()) {
      bytes = await pictureFile.readAsBytes();
    }
  }

  if (bytes == null) {
    song?.coverArtColor = Colors.grey;
    return Colors.grey;
  }

  final color = await calculateAverageColor(bytes);
  song!.coverArtColor = color;

  double r = color.r;
  double g = color.g;
  double b = color.b;
  final luminance = 0.299 * r + 0.587 * g + 0.114 * b;

  const maxLuminance = 200 / 255.0;

  if (luminance > maxLuminance) {
    final factor = maxLuminance / luminance;

    song.lowerLuminance = Color.from(
      alpha: color.a,
      red: r * factor,
      green: g * factor,
      blue: b * factor,
    );
  }

  return color;
}

Future<Color> calculateAverageColor(Uint8List bytes) async {
  final state = WidgetsBinding.instance.lifecycleState;

  if (Platform.isIOS && state != AppLifecycleState.resumed) {
    return _calculateWithImagePackage(bytes);
  }

  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 20,
    targetHeight: 20,
  );

  final frameInfo = await codec.getNextFrame();
  final image = frameInfo.image;

  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

  image.dispose();

  if (byteData == null) {
    return Colors.grey;
  }

  final buffer = byteData.buffer.asUint8List();

  double r = 0;
  double g = 0;
  double b = 0;
  int count = 0;

  for (int i = 0; i < buffer.length; i += 4) {
    final red = buffer[i];
    final green = buffer[i + 1];
    final blue = buffer[i + 2];
    final alpha = buffer[i + 3];

    if (alpha == 0) {
      r += 128;
      g += 128;
      b += 128;
    } else {
      r += red;
      g += green;
      b += blue;
    }

    count++;
  }

  if (count == 0) {
    return Colors.grey;
  }
  return Color.fromARGB(
    255,
    (r / count).round(),
    (g / count).round(),
    (b / count).round(),
  );
}

Color _calculateWithImagePackage(Uint8List bytes) {
  final image = img.decodeImage(bytes);

  if (image == null) {
    return Colors.grey;
  }

  final thumb = img.copyResize(
    image,
    width: 20,
    height: 20,
    interpolation: img.Interpolation.average,
  );

  double r = 0;
  double g = 0;
  double b = 0;
  int count = 0;

  for (final pixel in thumb) {
    if (pixel.a == 0) {
      r += 128;
      g += 128;
      b += 128;
    } else {
      r += pixel.r;
      g += pixel.g;
      b += pixel.b;
    }

    count++;
  }

  if (count == 0) {
    return Colors.grey;
  }

  return Color.fromARGB(
    255,
    (r / count).round(),
    (g / count).round(),
    (b / count).round(),
  );
}
