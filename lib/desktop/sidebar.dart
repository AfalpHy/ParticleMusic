import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/pages/main_page.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<String> sidebarHighlighLabel = ValueNotifier('');
Color sidebarColor = Color.fromARGB(255, 240, 240, 240);
Color customSidebarColor = Color.fromARGB(255, 240, 240, 240);
Color vividSidebarColor = sidebarColor.withAlpha(120);

class Sidebar extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();
  Sidebar({super.key});

  Widget sidebarItem({
    required String label,
    required Widget leading,
    required String content,
    Widget? trailing,
    EdgeInsetsGeometry? contentPadding,
    void Function()? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: SmoothClipRRect(
        smoothness: 1,
        borderRadius: BorderRadius.circular(10),
        child: ValueListenableBuilder(
          valueListenable: sidebarHighlighLabel,
          builder: (context, highlightLabel, child) {
            return ValueListenableBuilder(
              valueListenable: updateBackgroundNotifier,
              builder: (_, _, _) {
                final highlightColor = enableCustomColorNotifier.value
                    ? selectedItemColor
                    : backgroundColor.withAlpha(75);
                return Material(
                  color: highlightLabel == label
                      ? highlightColor
                      : Colors.transparent,
                  child: child,
                );
              },
            );
          },
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: ListTile(
              leading: leading,
              title: Text(
                content,
                style: TextStyle(fontSize: 15, overflow: TextOverflow.ellipsis),
              ),
              contentPadding: contentPadding,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -3.5),
              trailing: trailing,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: sidebarColor,
      child: SizedBox(
        width: 220,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) => windowManager.startDragging(),
              onDoubleTap: () async => await windowManager.isMaximized()
                  ? windowManager.unmaximize()
                  : windowManager.maximize(),
              child: SizedBox(
                height: 75,
                child: Center(
                  child: Text(
                    'Particle Music',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Scrollbar(
                thickness: 5,
                controller: _scrollController,
                child: CustomScrollView(
                  primary: false,
                  controller: _scrollController,
                  scrollBehavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  slivers: [
                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'artists',
                        leading: ImageIcon(
                          artistImage,
                          size: 30,
                          color: iconColor,
                        ),
                        content: l10n.artists,

                        onTap: () {
                          panelManager.pushPanel('artists');
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'albums',

                        leading: ImageIcon(
                          albumImage,
                          size: 30,
                          color: iconColor,
                        ),
                        content: l10n.albums,

                        onTap: () {
                          panelManager.pushPanel('albums');
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'songs',

                        leading: ImageIcon(
                          songsImage,
                          size: 30,
                          color: iconColor,
                        ),
                        content: l10n.songs,

                        onTap: () {
                          panelManager.pushPanel('songs');
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'folders',

                        leading: ImageIcon(
                          folderImage,
                          size: 30,
                          color: iconColor,
                        ),
                        content: l10n.folders,

                        onTap: () {
                          panelManager.pushPanel('folders');
                        },
                      ),
                    ),

                    SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: ValueListenableBuilder(
                          valueListenable: updateBackgroundNotifier,
                          builder: (_, _, _) {
                            return Divider(
                              thickness: 0.5,
                              height: 1,
                              color: enableCustomColorNotifier.value
                                  ? dividerColor
                                  : backgroundColor,
                            );
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10)),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        label: 'playlists',
                        leading: ImageIcon(
                          playlistsImage,
                          size: 30,
                          color: iconColor,
                        ),
                        content: l10n.playlists,
                        contentPadding: EdgeInsets.fromLTRB(16, 0, 8, 0),

                        trailing: IconButton(
                          onPressed: () {
                            showCreatePlaylistDialog(context);
                          },
                          icon: ImageIcon(addImage, size: 20),
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),

                        onTap: () {
                          panelManager.pushPanel('playlists');
                        },
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10)),

                    // keep Favorite at top
                    SliverToBoxAdapter(child: playlistItem(context, 0)),

                    ValueListenableBuilder(
                      valueListenable: playlistsManager.changeNotifier,
                      builder: (context, _, _) {
                        return SliverReorderableList(
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = playlistsManager.playlists.removeAt(
                              oldIndex + 1,
                            );
                            playlistsManager.playlists.insert(
                              newIndex + 1,
                              item,
                            );
                            playlistsManager.update();
                          },
                          itemCount: playlistsManager.length() - 1,
                          itemBuilder: (_, index) {
                            return ReorderableDragStartListener(
                              index: index,
                              key: ValueKey(index),
                              child: playlistItem(context, index + 1),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget playlistItem(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: playlistsManager.changeNotifier,
      builder: (context, value, child) {
        final playlist = playlistsManager.getPlaylistByIndex(index);
        return ContextMenuWidget(
          child: sidebarItem(
            label: '_${playlist.name}',
            leading: ValueListenableBuilder(
              valueListenable: playlist.changeNotifier,
              builder: (_, _, _) {
                return playlist.songs.isNotEmpty
                    ? ValueListenableBuilder(
                        valueListenable: songIsUpdated[playlist.songs.first]!,
                        builder: (_, _, _) {
                          return CoverArtWidget(
                            size: 30,
                            borderRadius: 3,
                            source: getCoverArt(playlist.songs.first),
                          );
                        },
                      )
                    : CoverArtWidget(size: 30, borderRadius: 3, source: null);
              },
            ),
            content: index == 0 ? l10n.favorite : playlist.name,

            onTap: () {
              panelManager.pushPanel('_${playlist.name}');
            },
          ),
          menuProvider: (_) {
            return Menu(
              children: [
                MenuAction(
                  title: index == 0 ? l10n.favorite : playlist.name,
                  callback: () {},
                ),

                if (playlist.name != 'Favorite') MenuSeparator(),
                if (playlist.name != 'Favorite')
                  MenuAction(
                    title: l10n.delete,
                    image: MenuImage.icon(Icons.delete),
                    callback: () async {
                      if (await showConfirmDialog(context, l10n.delete)) {
                        panelManager.removePlaylistPanel(playlist);
                        playlistsManager.deletePlaylistByIndex(index);
                      }
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
