import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:lpinyin/lpinyin.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:path/path.dart';
import 'package:smooth_corner/smooth_corner.dart';

void showCenterMessage(
  BuildContext context,
  String message, {
  int duration = 500,
}) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Center(
      child: Material(
        color: Colors.black,
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            message,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(Duration(milliseconds: duration), () {
    overlayEntry.remove();
  });
}

Future<bool> showConfirmDialog(BuildContext context, String action) async {
  final l10n = AppLocalizations.of(context);

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: commonColor,
        title: Text(action),
        content: Text(l10n.continueMsg, style: TextStyle(fontSize: 14)),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  backgroundColor: buttonColor,
                  shadowColor: Colors.black54,
                  foregroundColor: Colors.black,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  elevation: 2,
                  backgroundColor: buttonColor,
                  shadowColor: Colors.black54,
                  foregroundColor: Colors.red,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result!;
}

String getTitle(AudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.title == null || song.title == '') {
    return basename(song.file.path);
  }
  return song.title!;
}

String getArtist(AudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.artist == null || song.artist == '') {
    return 'Unknown Artist';
  }
  return song.artist!;
}

String getAlbum(AudioMetadata? song) {
  if (song == null) {
    return '';
  }
  if (song.album == null || song.album == '') {
    return 'Unknown Album';
  }
  return song.album!;
}

Duration getDuration(AudioMetadata? song) {
  if (song == null) {
    return Duration.zero;
  }
  return song.duration ?? Duration.zero;
}

Picture? getCoverArt(AudioMetadata? song) {
  if (song == null) {
    return null;
  }
  return song.pictures.isNotEmpty ? song.pictures.first : null;
}

List<AudioMetadata> filterSongList(List<AudioMetadata> songList, String value) {
  return songList.where((song) {
    final songTitle = getTitle(song);
    final songArtist = getArtist(song);
    final songAlbum = getAlbum(song);

    return value.isEmpty ||
        songTitle.toLowerCase().contains(value.toLowerCase()) ||
        songArtist.toLowerCase().contains(value.toLowerCase()) ||
        songAlbum.toLowerCase().contains(value.toLowerCase());
  }).toList();
}

void sortSongList(int sortType, List<AudioMetadata> songList) {
  switch (sortType) {
    case 1: // Title Ascending
      songList.sort((a, b) {
        return compareMixed(getTitle(a), getTitle(b));
      });
      break;
    case 2: // Title Descending
      songList.sort((a, b) {
        return compareMixed(getTitle(b), getTitle(a));
      });
      break;
    case 3: // Artist Ascending
      songList.sort((a, b) {
        return compareMixed(getArtist(a), getArtist(b));
      });
      break;
    case 4: // Artist Descending
      songList.sort((a, b) {
        return compareMixed(getArtist(b), getArtist(a));
      });
      break;
    case 5: // Album Ascending
      songList.sort((a, b) {
        return compareMixed(getAlbum(a), getAlbum(b));
      });
      break;
    case 6: // Album Descending
      songList.sort((a, b) {
        return compareMixed(getAlbum(b), getAlbum(a));
      });
      break;
    case 7: // Duration Ascending
      songList.sort((a, b) {
        return a.duration!.compareTo(b.duration!);
      });
      break;
    case 8: // Duration Descending
      songList.sort((a, b) {
        return b.duration!.compareTo(a.duration!);
      });
      break;
    default:
      break;
  }
}

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return "$minutes:$seconds";
}

bool isEnglish(String s) {
  final c = s[0];
  return RegExp(r'^[A-Za-z]').hasMatch(c);
}

int compareMixed(String a, String b) {
  final aIsEng = isEnglish(a);
  final bIsEng = isEnglish(b);

  if (aIsEng && !bIsEng) return -1;
  if (!aIsEng && bIsEng) return 1;

  if (aIsEng && bIsEng) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  final pa = PinyinHelper.getPinyinE(a);
  final pb = PinyinHelper.getPinyinE(b);
  return pa.compareTo(pb);
}

void tryVibrate() {
  if (vibrationOnNoitifier.value) {
    HapticFeedback.heavyImpact();
  }
}

void sortArtists() {
  artistMapEntryList.sort((a, b) {
    if (artistsIsAscendingNotifier.value) {
      return compareMixed(a.key, b.key);
    } else {
      return compareMixed(b.key, a.key);
    }
  });
}

void sortAlbums() {
  albumMapEntryList.sort((a, b) {
    if (albumsIsAscendingNotifier.value) {
      return compareMixed(a.key, b.key);
    } else {
      return compareMixed(b.key, a.key);
    }
  });
}

Future<Uint8List?> getPictureBytes(AudioMetadata? song) async {
  if (song == null) {
    return null;
  }

  if (song.pictures.isNotEmpty) {
    return song.pictures.first.bytes;
  }
  final path = clipFilePathIfNeed(song.file.path);
  final pictureFile = File(filePath2PicturePath[path]!);
  if (await pictureFile.exists()) {
    final result = await pictureFile.readAsBytes();
    song.pictures.add(Picture(result, '', PictureType.coverFront));
    return result;
  } else {
    return null;
  }
}

Future<Color> computeCoverArtColor(AudioMetadata? song) async {
  final bytes = await getPictureBytes(song);
  if (bytes == null) {
    return Colors.grey;
  }

  final decoded = image.decodeImage(bytes);
  if (decoded == null) return Colors.grey;

  // simple average of top pixels
  double r = 0, g = 0, b = 0, count = 0;
  for (int y = 0; y < decoded.height; y += 5) {
    for (int x = 0; x < decoded.width; x += 5) {
      final pixel = decoded.getPixel(x, y);

      r += pixel.r.toDouble();
      g += pixel.g.toDouble();
      b += pixel.b.toDouble();
      count++;
    }
  }
  r /= count;
  g /= count;
  b /= count;
  int luminance = image.getLuminanceRgb(r, g, b).toInt();
  int maxLuminace = 200;
  if (luminance > maxLuminace) {
    r -= luminance - maxLuminace;
    g -= luminance - maxLuminace;
    b -= luminance - maxLuminace;
  }
  return Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
}

AudioMetadata? getFirstSong(List<AudioMetadata> songList) {
  if (songList.isEmpty) {
    return null;
  }
  return songList.first;
}

// every installation on iOS may result in a different app documents path
// due to app container isolation, therefore, keep only relative paths
String clipFilePathIfNeed(String path) {
  if (Platform.isIOS) {
    int prefixLength = appDocs.path.length;
    return path.substring(prefixLength);
  }
  return path;
}

String revertFilePathIfNeed(String path) {
  if (Platform.isIOS) {
    return appDocs.path + path;
  }
  return path;
}

String convertDirectoryPathIfNeed(String path) {
  if (Platform.isIOS) {
    int prefixLength = appDocs.path.length;
    return path.substring(prefixLength);
  }
  return path;
}

String revertDirectoryPathIfNeed(String path) {
  if (Platform.isIOS) {
    return "${appDocs.parent.path}/${path.replaceFirst('Particle Music', 'Documents')}";
  }
  return path;
}
