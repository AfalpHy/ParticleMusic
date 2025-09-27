import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';

class ArtWidget extends StatelessWidget {
  final double size;
  final double borderRadius;
  final Picture? source;

  const ArtWidget({
    super.key,
    required this.size,
    this.borderRadius = 0,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    if (source == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          color: Colors.grey,
          child: Icon(Icons.music_note, size: size),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.memory(
        source!.bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey,
            child: Icon(Icons.music_note, size: size),
          );
        },
      ),
    );
  }
}
