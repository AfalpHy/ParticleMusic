import 'package:auto_size_text/auto_size_text.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/playlist.dart';
import 'package:sylvakru/base/widgets/my_navigator.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

part '../landscape_view/panels/playlists_panel.dart';
part '../portrait_view/pages/playlists_page.dart';

final GlobalKey<NavigatorState> playlistsKey = GlobalKey();
final playlistsVisibleNotifier = ValueNotifier(true);

class PlaylistsLayer extends StatefulWidget {
  const PlaylistsLayer({super.key});

  @override
  State<StatefulWidget> createState() => _PlaylistsLayerState();
}

class _PlaylistsLayerState extends State<PlaylistsLayer> {
  final playlistsNotifier = ValueNotifier(playlistManager.playlists);
  final textController = TextEditingController();

  void filterPlaylists() {
    playlistsNotifier.value = playlistManager.playlists.where((playlist) {
      return playlist.name.toLowerCase().contains(
        textController.text.toLowerCase(),
      );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    playlistManager.updateNotifier.addListener(filterPlaylists);
    textController.addListener(filterPlaylists);
  }

  @override
  void dispose() {
    playlistManager.updateNotifier.removeListener(filterPlaylists);
    textController.removeListener(filterPlaylists);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: playlistsKey,
      visibleNotifier: playlistsVisibleNotifier,
      pageViewBuilder: () => pageView(context),
      panelViewBuilder: () => panelView(context),
    );
  }
}
