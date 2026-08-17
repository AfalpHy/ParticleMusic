import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/big_picture_view/panels/big_artists_albums_base_panel.dart';

class BigArtistsPanel extends BigArtistsAlbumsBasePanel {
  const BigArtistsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigArtistsPanelState();
}

class _BigArtistsPanelState extends BigArtistsAlbumsBasePanelState {
  @override
  bool get isArtist => true;

  @override
  List<ArtistAlbumBase> get list => artistAlbumManager.artistList;

  @override
  ValueNotifier<bool> get randomizeNotifier =>
      artistAlbumManager.artistsRandomizeNotifier;

  @override
  ValueNotifier<bool> get isAscendingNotifier =>
      artistAlbumManager.artistsIsAscendingNotifier;
}
