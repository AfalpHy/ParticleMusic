import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';

class SelectableSongListTile extends StatelessWidget {
  final int index;
  final List<MyAudioMetadata> source;
  final ValueNotifier<bool> isSelected;
  final ValueNotifier<int> selectedNumNotifier;
  final bool reorderable;
  final bool isRanking;

  const SelectableSongListTile({
    super.key,
    required this.index,
    required this.source,
    required this.isSelected,
    required this.selectedNumNotifier,
    this.reorderable = false,
    this.isRanking = false,
  });

  @override
  Widget build(BuildContext context) {
    final song = source[index];

    return Row(
      children: [
        ValueListenableBuilder(
          valueListenable: isSelected,
          builder: (context, value, child) {
            return Checkbox(
              value: value,
              activeColor: iconColor.value,
              onChanged: (value) {
                isSelected.value = value!;
                selectedNumNotifier.value += value ? 1 : -1;
              },
              shape: const CircleBorder(),
              side: BorderSide(color: iconColor.value.withAlpha(128)),
            );
          },
        ),
        Expanded(
          child: GestureDetector(
            child: ListTile(
              contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
              leading: CoverArtWidget(
                size: 40,
                borderRadius: 4,
                picture: song.picture,
              ),
              title: ValueListenableBuilder(
                valueListenable: currentSongNotifier,
                builder: (_, currentSong, _) {
                  return Text(
                    getTitle(song),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: song == currentSong
                          ? highlightTextColor.value
                          : textColor.value,
                      fontWeight: song == currentSong ? FontWeight.bold : null,
                    ),
                  );
                },
              ),

              subtitle: Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: song.isFavoriteNotifier,
                    builder: (_, value, _) {
                      return value
                          ? SizedBox(
                              width: 20,
                              child: Icon(
                                Icons.star_rounded,
                                color: Colors.red,
                                size: 15,
                              ),
                            )
                          : SizedBox();
                    },
                  ),
                  Expanded(
                    child: Text(
                      "${getArtist(song)} - ${getAlbum(song)}",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            ),
            onTap: () {
              isSelected.value = !isSelected.value;
              selectedNumNotifier.value += isSelected.value ? 1 : -1;
            },
          ),
        ),

        if (isRanking)
          SizedBox(
            width: 60,
            child: Row(
              children: [
                Spacer(),
                ImageIcon(playOutlinedImage, size: 15, color: iconColor.value),
                Text(song.playCount.toString()),
              ],
            ),
          ),

        reorderable
            ? SizedBox(
                width: 60,
                height: 50,
                child: ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    // must set color to make area valid
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        SizedBox(width: 10),
                        ImageIcon(reorderImage, color: iconColor.value),
                      ],
                    ),
                  ),
                ),
              )
            : SizedBox(width: 20),
      ],
    );
  }
}
