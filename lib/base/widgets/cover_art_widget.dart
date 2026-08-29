import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/services/picture_load_scheduler.dart';
import 'package:sylvakru/base/services/picture_service.dart';

class CoverArtWidget extends StatelessWidget {
  final double? size;
  final double borderRadius;
  final MyPicture? picture;
  final String? picturePath;
  final double elevation;
  final Color? color;
  const CoverArtWidget({
    super.key,
    this.size,
    this.borderRadius = 0,
    this.picture,
    this.picturePath,
    this.elevation = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      color: color ?? Colors.transparent,
      shape: SmoothRectangleBorder(
        smoothness: 1,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: .antiAlias,
      child: content(context),
    );
  }

  Widget content(BuildContext context) {
    if (picturePath != null) {
      return imageWidget(picturePath!);
    }
    if (picture == null) {
      return musicNote();
    }

    if (picture!.isLoaded) {
      return imageWidget(picture!.path);
    }
    return _FuturePicture(
      picture: picture!,
      size: size,
      imageWidget: imageWidget,
      musicNote: musicNote,
    );
  }

  Widget imageWidget(String path) {
    final ImageProvider imageProvider = size != null && size! <= 256
        ? ResizeImage(FileImage(File(path)), width: (size! * 4).toInt())
        : FileImage(File(path));

    return Image(
      image: imageProvider,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return musicNote();
      },
    );
  }

  Widget musicNote() {
    return ImageIcon(musicNoteImage, size: size);
  }
}

class _FuturePicture extends StatefulWidget {
  final MyPicture picture;
  final double? size;
  final Widget Function(String) imageWidget;
  final Widget Function() musicNote;

  const _FuturePicture({
    required this.picture,
    required this.size,
    required this.imageWidget,
    required this.musicNote,
  });
  @override
  State<StatefulWidget> createState() => _FuturePictureState();
}

class _FuturePictureState extends State<_FuturePicture> {
  @override
  void dispose() {
    pictureLoadScheduler.cancel(widget.picture.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: loadPictureSafe(widget.picture),
      builder: (context, asyncSnapshot) {
        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(width: widget.size, height: widget.size);
        }

        if (asyncSnapshot.hasError) {
          return widget.musicNote();
        }
        return widget.imageWidget(widget.picture.path);
      },
    );
  }
}
