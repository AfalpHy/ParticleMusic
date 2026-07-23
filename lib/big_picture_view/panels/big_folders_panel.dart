import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/services/metadata_service.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_folder_panel.dart';

class BigFoldersPanel extends StatefulWidget {
  const BigFoldersPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigFoldersPanelState();
}

class _BigFoldersPanelState extends State<BigFoldersPanel> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 75),
      itemCount:
          library.localFolderList.length + library.webdavFolderList.length,
      itemBuilder: (_, index) {
        late Folder folder;
        if (index < library.localFolderList.length) {
          folder = library.localFolderList[index];
        } else {
          folder =
              library.webdavFolderList[index - library.localFolderList.length];
        }
        return ValueListenableBuilder(
          valueListenable: folder.changeNotifier,
          builder: (context, value, child) {
            final coverSong = getFirstSong(folder.songList);
            return SizedBox(
              height: 150,
              child: InkWell(
                customBorder: SmoothRectangleBorder(
                  smoothness: 1,
                  borderRadius: BorderRadius.circular(15),
                ),
                mouseCursor: SystemMouseCursors.click,
                child: Row(
                  children: [
                    SizedBox(width: 20),
                    ListenableBuilder(
                      listenable: Listenable.merge([coverSong?.updateNotifier]),
                      builder: (_, _) {
                        return Hero(
                          tag: 'big${coverSong?.id}${folder.id}',
                          child: CoverArtWidget(
                            size: 100,
                            borderRadius: 10,
                            song: coverSong,
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        folder.id,
                        style: TextStyle(overflow: .ellipsis),
                      ),
                    ),
                  ],
                ),
                onTap: () async {
                  final baseColor = await computeCoverArtColor(
                    getFirstSong(folder.songList),
                  );
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).push(
                    ZoomPageRoute(
                      builder: (context) {
                        return BigSingleFolderPanel(
                          folder: folder,
                          baseColor: baseColor,
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
