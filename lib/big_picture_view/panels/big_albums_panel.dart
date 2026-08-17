import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/artist_album.dart';
import 'package:sylvakru/big_picture_view/panels/big_artists_albums_base_panel.dart';

class BigAlbumsPanel extends BigArtistsAlbumsBasePanel {
  const BigAlbumsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigAlbumsPanelState();
}

class _BigAlbumsPanelState extends BigArtistsAlbumsBasePanelState {
  @override
  bool get isArtist => false;

  @override
  List<ArtistAlbumBase> get list => artistAlbumManager.albumList;

  @override
  ValueNotifier<bool> get randomizeNotifier =>
      artistAlbumManager.albumsRandomizeNotifier;

  @override
  ValueNotifier<bool> get isAscendingNotifier =>
      artistAlbumManager.albumsIsAscendingNotifier;
}
