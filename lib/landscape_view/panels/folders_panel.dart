import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/cover_art_widget.dart';
import 'package:particle_music/landscape_view/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class FoldersPanel extends StatelessWidget {
  const FoldersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleBar(),
        Expanded(child: contentWidget(context)),
      ],
    );
  }

  Widget contentWidget(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: ListTile(
              leading: ValueListenableBuilder(
                valueListenable: updateColorNotifier,
                builder: (_, _, _) {
                  return ImageIcon(folderImage, size: 50, color: iconColor);
                },
              ),
              title: Text(
                l10n.folders,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                l10n.folderCount(library.folderList.length),
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ValueListenableBuilder(
            valueListenable: updateColorNotifier,
            builder: (context, value, child) {
              return Divider(
                thickness: 0.5,
                height: 0.5,
                indent: 30,
                endIndent: 30,
                color: dividerColor,
              );
            },
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 15)),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 40),

          sliver: SliverList.builder(
            itemCount: library.folderList.length,
            itemBuilder: (context, index) {
              final folder = library.folderList[index];
              return ValueListenableBuilder(
                valueListenable: folder.updateNotifier,
                builder: (context, value, child) {
                  final displaySong = getFirstSong(folder.songList);
                  return SizedBox(
                    height: 64,
                    child: InkWell(
                      customBorder: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      mouseCursor: SystemMouseCursors.click,
                      child: Row(
                        children: [
                          SizedBox(width: 20),
                          displaySong == null
                              ? CoverArtWidget(
                                  size: 50,
                                  borderRadius: 5,
                                  song: null,
                                )
                              : ValueListenableBuilder(
                                  valueListenable: displaySong.updateNotifier,
                                  builder: (_, _, _) {
                                    return CoverArtWidget(
                                      size: 50,
                                      borderRadius: 5,
                                      song: displaySong,
                                    );
                                  },
                                ),
                          SizedBox(width: 10),

                          Text(
                            folder.getDisplayName(),
                            style: TextStyle(overflow: .ellipsis),
                          ),
                        ],
                      ),
                      onTap: () {
                        layersManager.pushLayer(
                          'folders',
                          content: folder.path,
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
