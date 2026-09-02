import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/zoom_page_route.dart';
import 'package:sylvakru/big_picture_view/panels/big_collection_list_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_single_playlist_panel.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

class BigPlaylistsPanel extends BigCollectionListPanel {
  const BigPlaylistsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigPlaylistsPanelState();
}

class _BigPlaylistsPanelState extends BigCollectionListPanelState {
  @override
  void updateCurrentList() {
    preparing = false;
    final value = textController.text;
    final list = playlistManager.playlists
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();

    pictureList = list.map((e) => e.getCoverSong()?.picture).toList();
    textList = list.map((e) => e.name).toList();
    onTapList = list
        .map(
          (e) => () async {
            final baseColor = await computeColor(e.getCoverSong()?.picture);
            if (!mounted) {
              return;
            }
            Navigator.of(context).push(
              ZoomPageRoute(
                builder: (context) {
                  return BigSinglePlaylistPanel(
                    playlist: e,
                    baseColor: baseColor,
                  );
                },
              ),
            );
          },
        )
        .toList();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      updateCurrentList();
    });
    playlistManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    playlistManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (textList.isNotEmpty) {
      textList[0] = AppLocalizations.of(context).favorites;
    }
    return super.build(context);
  }
}
