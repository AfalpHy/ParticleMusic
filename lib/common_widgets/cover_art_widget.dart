import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class CoverArtWidget extends StatefulWidget {
  final double? size;
  final double borderRadius;
  final AudioMetadata? song;

  const CoverArtWidget({
    super.key,
    this.size,
    this.borderRadius = 0,
    required this.song,
  });

  @override
  State<StatefulWidget> createState() => _CoverArtWidgetState();
}

class _CoverArtWidgetState extends State<CoverArtWidget> {
  late bool hasData;

  late double? size;
  late double borderRadius;
  late AudioMetadata? song;

  @override
  void initState() {
    super.initState();
    size = widget.size;
    borderRadius = widget.borderRadius;
    song = widget.song;
    hasData = song != null && song!.pictures.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return SmoothClipRRect(
      smoothness: 1,
      borderRadius: BorderRadius.circular(borderRadius),
      child: hasData
          ? Image.memory(
              getCoverArt(song)!.bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return musicNote();
              },
            )
          : FutureBuilder(
              future: _loadPictureBytes(song),
              builder: (context, asyncSnapshot) {
                if (asyncSnapshot.connectionState == ConnectionState.waiting ||
                    asyncSnapshot.hasError ||
                    asyncSnapshot.data == null) {
                  return musicNote();
                }
                return Image.memory(
                  asyncSnapshot.data!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return musicNote();
                  },
                );
              },
            ),
    );
  }

  Widget musicNote() {
    return Container(
      color: Colors.grey,
      child: ImageIcon(musicNoteImage, size: size),
    );
  }
}

Future<Uint8List?> _loadPictureBytes(AudioMetadata? song) async {
  if (song == null) {
    return null;
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
