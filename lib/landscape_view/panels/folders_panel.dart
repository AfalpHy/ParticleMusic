part of '../../layer/folders_layer.dart';

extension FoldersPanel on FoldersLayer {
  Widget panelView(BuildContext context) {
    return Column(
      children: [
        TitleBar(),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: library.folderListChangeNotifier,
            builder: (context, value, child) {
              return contentWidget(context);
            },
          ),
        ),
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
            child: Focus(
              child: ListTile(
                leading: ValueListenableBuilder(
                  valueListenable: iconColor.valueNotifier,
                  builder: (_, value, _) {
                    return ImageIcon(folderImage, size: 50, color: value);
                  },
                ),
                title: Text(
                  l10n.folders,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  l10n.folderCount(
                    library.localFolderList.length +
                        library.webdavFolderList.length,
                  ),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: MyDivider(
            thickness: 0.5,
            height: 0.5,
            indent: 30,
            endIndent: 30,
            color: dividerColor,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 15)),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 40),

          sliver: SliverList.builder(
            itemCount:
                library.localFolderList.length +
                library.webdavFolderList.length,
            itemBuilder: (_, index) {
              late Folder folder;
              if (index < library.localFolderList.length) {
                folder = library.localFolderList[index];
              } else {
                folder = library
                    .webdavFolderList[index - library.localFolderList.length];
              }
              return ValueListenableBuilder(
                valueListenable: folder.changeNotifier,
                builder: (context, value, child) {
                  final coverSong = getFirstSong(folder.songList);
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
                          ListenableBuilder(
                            listenable: Listenable.merge([
                              coverSong?.updateNotifier,
                            ]),
                            builder: (_, _) {
                              return Hero(
                                tag:
                                    (coverSong?.id ??
                                        (folder.isWebdav
                                            ? 'webdav'
                                            : 'local')) +
                                    folder.id,
                                child: CoverArtWidget(
                                  size: 50,
                                  borderRadius: 5,
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
                      onTap: () {
                        layersManager.pushDetail('folders', folder);
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
