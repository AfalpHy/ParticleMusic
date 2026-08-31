import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/picture_load_scheduler.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/utils/path.dart';

class MyPicture {
  String id;
  bool isLoaded = false;
  bool isExist = false;
  String path = '';
  Color? color;
  Color? lowerLuminance;

  MyPicture(this.id, {String? md5Hash}) {
    if (id.isEmpty) {
      isExist = false;
      isLoaded = true;
      color = Colors.grey;
      return;
    }
    md5Hash ??= md5.convert(utf8.encode(id)).toString();
    path = '${getPicturesPath(sourceType)}/$md5Hash';
    if (File(path).existsSync()) {
      isLoaded = true;
      isExist = true;
    } else {
      isExist = false;
    }
  }

  void reset() {
    isLoaded = false;
    isExist = false;
    color = null;
    lowerLuminance = null;
  }
}

Future<void> loadPictureSafe(MyPicture picture) async {
  if (picture.isLoaded) {
    return;
  }
  return pictureLoadScheduler.load(picture.id, () => _loadPicture(picture));
}

Future<void> _loadPicture(MyPicture picture) async {
  try {
    Uint8List? bytes;

    switch (sourceType) {
      case .local:
        bytes = await readPictureAsync(picture.id);
        break;
      case .webdav:
        final tmpPath = await convertToRealPathIfNeed(picture.id);
        if (tmpPath == null) {
          bytes = await readPictureAsync(
            picture.id,
            headers: webdavClient?.headers,
          );
        } else {
          bytes = await readPictureAsync(tmpPath);
        }
        break;
      default:
        bytes = await streamClient?.getPictureBytes(picture.id);
        break;
    }

    if (bytes != null) {
      File pictureFile = File(picture.path);
      if (!await pictureFile.exists()) {
        await pictureFile.create(recursive: true);
      }
      await pictureFile.writeAsBytes(bytes, flush: true);
      picture.isExist = true;
    }
  } catch (e) {
    logger.output(e.toString());
  }
  picture.isLoaded = true;
}

Future<Color> computeColor(MyPicture? picture) async {
  if (picture?.color != null) {
    return picture!.color!;
  }
  Uint8List? bytes;
  if (picture != null) {
    await loadPictureSafe(picture);
  }

  if (picture?.isExist == true) {
    File pictureFile = File(picture!.path);
    if (await pictureFile.exists()) {
      bytes = await pictureFile.readAsBytes();
    }
  }

  if (bytes == null) {
    picture?.color = Colors.grey;
    return Colors.grey;
  }

  final color = await _calculateAverageColor(bytes);
  picture!.color = color;

  double r = color.r;
  double g = color.g;
  double b = color.b;
  final luminance = 0.299 * r + 0.587 * g + 0.114 * b;

  const maxLuminance = 200 / 255.0;

  if (luminance > maxLuminance) {
    final factor = maxLuminance / luminance;

    picture.lowerLuminance = Color.from(
      alpha: color.a,
      red: r * factor,
      green: g * factor,
      blue: b * factor,
    );
  }

  return color;
}

Future<Color> _calculateAverageColor(Uint8List bytes) async {
  final state = WidgetsBinding.instance.lifecycleState;

  if (Platform.isIOS && state != AppLifecycleState.resumed) {
    return _calculateWithImagePackage(bytes);
  }

  ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 20,
      targetHeight: 20,
    );
  } catch (e) {
    logger.output(e.toString());
    return Colors.grey;
  }

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
