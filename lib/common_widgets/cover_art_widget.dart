import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class CoverArtWidget extends StatelessWidget {
  final double? size;
  final double borderRadius;
  final MyAudioMetadata? song;
  final Uint8List? pictureBytes;
  const CoverArtWidget({
    super.key,
    this.size,
    this.borderRadius = 0,
    this.song,
    this.pictureBytes,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? tmpPictureBytes = pictureBytes;
    tmpPictureBytes ??= getPictureBytes(song);
    if (tmpPictureBytes == null) {
      if (song == null || song!.noPicture) {
        return musicNote();
      }
      return FutureBuilder(
        future: loadPictureBytes(song),
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(width: size, height: size);
          }

          if (asyncSnapshot.hasError || asyncSnapshot.data == null) {
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
      );
    }

    return SmoothClipRRect(
      smoothness: 1,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.memory(
        tmpPictureBytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return musicNote();
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
