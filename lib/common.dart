import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:path/path.dart';
import 'package:smooth_corner/smooth_corner.dart';

const Color mainColor = Color.fromARGB(255, 120, 230, 230);
late double appWidth;

const AssetImage addImage = AssetImage('assets/images/add.png');
const AssetImage albumImage = AssetImage('assets/images/album.png');
const AssetImage artistImage = AssetImage('assets/images/artist.png');
const AssetImage closeImage = AssetImage('assets/images/close.png');
const AssetImage deleteImage = AssetImage('assets/images/delete.png');
const AssetImage loopImage = AssetImage('assets/images/loop.png');
const AssetImage maximizeImage = AssetImage('assets/images/maximize.png');
const AssetImage minimizeImage = AssetImage('assets/images/minimize.png');
const AssetImage musicNoteImage = AssetImage('assets/images/music_note.png');
const AssetImage nextButtonImage = AssetImage('assets/images/next_button.png');
const AssetImage pauseCircleImage = AssetImage(
  'assets/images/pause_circle.png',
);
const AssetImage playCircleFillImage = AssetImage(
  'assets/images/play_circle_fill.png',
);
const AssetImage playCircleImage = AssetImage('assets/images/play_circle.png');
const AssetImage playlistAddImage = AssetImage(
  'assets/images/playlist_add.png',
);
const AssetImage playlistsImage = AssetImage('assets/images/playlists.png');
const AssetImage playnextCircleImage = AssetImage(
  'assets/images/playnext_circle.png',
);
const AssetImage previousButtonImage = AssetImage(
  'assets/images/previous_button.png',
);
const AssetImage reorderImage = AssetImage('assets/images/reorder.png');
const AssetImage repeatImage = AssetImage('assets/images/repeat.png');
const AssetImage selectImage = AssetImage('assets/images/select.png');
const AssetImage shuffleImage = AssetImage('assets/images/shuffle.png');
const AssetImage songsImage = AssetImage('assets/images/songs.png');

class MyAutoSizeText extends AutoSizeText {
  final String content;

  final TextStyle textStyle;
  MyAutoSizeText(
    this.content, {
    super.key,
    super.maxLines,
    required this.textStyle,
  }) : super(
         content,
         style: textStyle,
         minFontSize: textStyle.fontSize ?? 12,
         maxFontSize: textStyle.fontSize ?? double.infinity,
         overflowReplacement: Marquee(
           text: content,
           style: textStyle,
           scrollAxis: Axis.horizontal,
           blankSpace: 20,
           velocity: 30,
           pauseAfterRound: const Duration(seconds: 1),
           accelerationDuration: const Duration(milliseconds: 500),
           accelerationCurve: Curves.linear,
           decelerationDuration: const Duration(milliseconds: 500),
           decelerationCurve: Curves.linear,
         ),
       );
}

Widget mySheet(
  Widget child, {
  double height = 500,
  Color color = Colors.white,
}) {
  return SmoothClipRRect(
    smoothness: 1,
    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
    child: Container(height: height, color: color, child: child),
  );
}

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
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: SmoothRectangleBorder(
          smoothness: 1,
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: Colors.white,
        title: Text(action),
        content: const Text(
          'Are you sure you want to continue?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, false),
                style: ElevatedButton.styleFrom(
                  elevation: 1,
                  backgroundColor: Colors.grey.shade50,
                  shadowColor: Colors.black54,
                  foregroundColor: Colors.black,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  elevation: 1,
                  backgroundColor: Colors.grey.shade50,
                  shadowColor: Colors.black54,
                  foregroundColor: Colors.red,
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Confirm'),
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
  return song.title ?? basename(song.file.path);
}

String getArtist(AudioMetadata? song) {
  if (song == null) {
    return '';
  }
  return song.artist ?? 'Unknown Artist';
}

String getAlbum(AudioMetadata? song) {
  if (song == null) {
    return '';
  }
  return song.album ?? 'Unknown Album';
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

List<AudioMetadata> filterSongs(List<AudioMetadata> songList, String value) {
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

String twoPadDuration(Duration duration) {
  return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}
