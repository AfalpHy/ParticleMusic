part of '../../layer/folders_layer.dart';

extension FoldersPage on FoldersLayer {
  Widget pageView(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context),
        backgroundColor: Colors.transparent,
        systemOverlayStyle: mainPageThemeNotifier.value == .dark
            ? .light
            : .dark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.folders),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: library.folderList.length,
        itemBuilder: (_, index) {
          final folder = library.folderList[index];
          return ListTile(
            leading: ValueListenableBuilder(
              valueListenable: folder.changeNotifier,
              builder: (context, value, child) {
                final coverSong = getFirstSong(folder.songList);
                return ListenableBuilder(
                  listenable: Listenable.merge([coverSong?.updateNotifier]),
                  builder: (_, _) {
                    return Hero(
                      tag: (coverSong?.picture.id ?? '') + folder.id,
                      transitionOnUserGestures: true,
                      child: CoverArtWidget(
                        size: 50,
                        borderRadius: 5,
                        picture: coverSong?.picture,
                      ),
                    );
                  },
                );
              },
            ),
            title: Text(folder.id),
            onTap: () {
              layersManager.pushDetail('folders', folder);
            },
          );
        },
      ),
    );
  }
}
