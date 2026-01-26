import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/utils.dart';

class SelectableSongListTile extends StatelessWidget {
  final int index;
  final List<AudioMetadata> source;
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
    final isFavorite = songIsFavorite[song]!;
    return Row(
      children: [
        ValueListenableBuilder(
          valueListenable: isSelected,
          builder: (context, value, child) {
            return Checkbox(
              value: value,
              activeColor: iconColor,
              onChanged: (value) {
                isSelected.value = value!;
                selectedNumNotifier.value += value ? 1 : -1;
              },
              shape: const CircleBorder(),
              side: BorderSide(color: Colors.grey),
            );
          },
        ),
        Expanded(
          child: GestureDetector(
            child: ListTile(
              contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
              leading: CoverArtWidget(size: 40, borderRadius: 4, song: song),
              title: ValueListenableBuilder(
                valueListenable: currentSongNotifier,
                builder: (_, currentSong, _) {
                  return Text(
                    getTitle(song),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: song == currentSong ? textColor : null,
                      fontWeight: song == currentSong ? FontWeight.bold : null,
                    ),
                  );
                },
              ),

              subtitle: Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: isFavorite,
                    builder: (_, value, _) {
                      return value
                          ? SizedBox(
                              width: 20,
                              child: Icon(
                                Icons.favorite,
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
                Icon(Icons.play_arrow_outlined, size: 15),
                Text(historyManager.rankingItemList[index].times.toString()),
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
                        const ImageIcon(reorderImage),
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
