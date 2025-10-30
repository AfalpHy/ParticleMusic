import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/cover_art_widget.dart';
import 'package:particle_music/desktop/plane_manager.dart';
import 'package:particle_music/playlists.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<int> sidebarHighlightIndex = ValueNotifier<int>(2);

class Sidebar extends StatelessWidget {
  final ScrollController _scrollController = ScrollController();
  Sidebar({super.key});

  Widget sidebarItem({
    required int index,
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
          valueListenable: sidebarHighlightIndex,
          builder: (context, value, child) {
            return Material(
              color: value == index
                  ? Colors.white
                  : Color.fromARGB(255, 240, 245, 250),
              child: InkWell(
                onTap: onTap,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: ListTile(
                  leading: leading,
                  title: Text(
                    content,
                    style: TextStyle(
                      fontSize: 15,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  contentPadding: contentPadding,
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -4,
                  ),
                  trailing: trailing,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.fromARGB(255, 240, 245, 250),
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
                        index: 0,
                        leading: const ImageIcon(
                          artistImage,
                          size: 30,
                          color: mainColor,
                        ),
                        content: 'Artists',

                        onTap: () {
                          planeManager.pushPlane(1);
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        index: 1,

                        leading: const ImageIcon(
                          albumImage,
                          size: 30,
                          color: mainColor,
                        ),
                        content: 'Albums',

                        onTap: () {
                          planeManager.pushPlane(2);
                        },
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        index: 2,

                        leading: const ImageIcon(
                          songsImage,
                          size: 30,
                          color: mainColor,
                        ),
                        content: 'Songs',

                        onTap: () {
                          planeManager.pushPlane(0);
                        },
                      ),
                    ),

                    SliverToBoxAdapter(child: SizedBox(height: 10)),
                    SliverToBoxAdapter(
                      child: Divider(
                        thickness: 0.5,
                        height: 1,
                        color: Colors.grey.shade300,
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10)),

                    SliverToBoxAdapter(
                      child: sidebarItem(
                        index: 3,
                        leading: const ImageIcon(
                          playlistsImage,
                          size: 30,
                          color: mainColor,
                        ),
                        content: 'Playlists',
                        contentPadding: EdgeInsets.fromLTRB(16, 0, 8, 0),

                        trailing: IconButton(
                          onPressed: () {
                            showCreatePlaylistDialog(context);
                          },
                          icon: ImageIcon(addImage, size: 20),
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),

                        onTap: () {},
                      ),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 10)),

                    ValueListenableBuilder(
                      valueListenable: playlistsManager.changeNotifier,
                      builder: (context, _, _) {
                        return SliverList.builder(
                          itemCount: playlistsManager.length(),
                          itemBuilder: (_, index) {
                            final playlist = playlistsManager
                                .getPlaylistByIndex(index);
                            return ContextMenuWidget(
                              child: sidebarItem(
                                index: 4 + index,
                                leading: ValueListenableBuilder(
                                  valueListenable: playlist.changeNotifier,
                                  builder: (_, _, _) {
                                    return CoverArtWidget(
                                      size: 30,
                                      borderRadius: 3,
                                      source: playlist.songs.isNotEmpty
                                          ? getCoverArt(playlist.songs.first)
                                          : null,
                                    );
                                  },
                                ),
                                content: playlist.name,

                                onTap: () {
                                  planeManager.pushPlane(index + 5);
                                },
                              ),
                              menuProvider: (_) {
                                return Menu(
                                  children: [
                                    MenuAction(
                                      title: playlist.name,
                                      callback: () {},
                                    ),
                                    if (playlist.name != 'Favorite')
                                      MenuAction(
                                        title: 'Delete',
                                        image: MenuImage.icon(Icons.delete),
                                        callback: () async {
                                          if (await showConfirmDialog(
                                            context,
                                            'Delete Action',
                                          )) {
                                            planeManager.removePlaylistPlane(
                                              playlist,
                                            );
                                            playlistsManager.deletePlaylist(
                                              index,
                                            );
                                          }
                                        },
                                      ),
                                  ],
                                );
                              },
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
}
