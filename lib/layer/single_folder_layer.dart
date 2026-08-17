import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/widgets/song_list.dart';

class SingleFolderLayer extends StatelessWidget {
  final Folder folder;

  const SingleFolderLayer({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return SongList(
      folder: folder,
      isRoot: false,
      sourceType: folder.isWebdav ? .webdav : .local,
    );
  }
}
