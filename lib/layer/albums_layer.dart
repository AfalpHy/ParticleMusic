import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/widgets/my_navigator.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
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
import 'package:sylvakru/portrait_view/my_search_field.dart';

part '../landscape_view/panels/albums_panel.dart';
part '../portrait_view/pages/albums_page.dart';

final GlobalKey<NavigatorState> albumsKey = GlobalKey();
final albumsVisibleNotifier = ValueNotifier(true);

class AlbumsLayer extends StatefulWidget {
  const AlbumsLayer({super.key});

  @override
  State<StatefulWidget> createState() => _AlbumsLayerState();
}

class _AlbumsLayerState extends State<AlbumsLayer> {
  late final ValueNotifier<List<Album>> currentAlbumListNotifier;

  final textController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  late ValueNotifier<bool> randomizeNotifier;
  late ValueNotifier<bool> isAscendingNotifier;
  late ValueNotifier<bool> useLargePictureNotifier;

  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  void updateCurrentList() {
    final value = textController.text;
    currentAlbumListNotifier.value = artistAlbumManager.albumList
        .where((e) => (e.name.toLowerCase().contains(value.toLowerCase())))
        .toList();
    if (randomizeNotifier.value) {
      currentAlbumListNotifier.value.shuffle();
    }
  }

  @override
  void initState() {
    super.initState();
    currentAlbumListNotifier = ValueNotifier(artistAlbumManager.albumList);

    randomizeNotifier = artistAlbumManager.getIsRandomizeNotifier(false);

    isAscendingNotifier = artistAlbumManager.getIsAscendingNotifier(false);

    useLargePictureNotifier = artistAlbumManager.getUseLargePictureNotifier(
      false,
    );

    updateCurrentList();
    textController.addListener(updateCurrentList);
    artistAlbumManager.updateNotifier.addListener(updateCurrentList);
  }

  @override
  void dispose() {
    textController.dispose();
    artistAlbumManager.updateNotifier.removeListener(updateCurrentList);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: albumsKey,
      visibleNotifier: albumsVisibleNotifier,
      pageViewBuilder: () => pageView(context),
      panelViewBuilder: () => panelView(context),
    );
  }
}
