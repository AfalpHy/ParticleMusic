import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class CoverArtWidget extends StatelessWidget {
  final double? size;
  final double borderRadius;
  final AudioMetadata? song;
  final Picture? picture;
  const CoverArtWidget({
    super.key,
    this.size,
    this.borderRadius = 0,
    this.song,
    this.picture,
  });

  @override
  Widget build(BuildContext context) {
    Picture? tmpPicture = picture;
    tmpPicture ??= getCoverArt(song);
    return SmoothClipRRect(
      smoothness: 1,
      borderRadius: BorderRadius.circular(borderRadius),
      child: tmpPicture != null
          ? Image.memory(
              tmpPicture.bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return musicNote();
              },
            )
          : FutureBuilder(
              future: getPictureBytes(song),
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
