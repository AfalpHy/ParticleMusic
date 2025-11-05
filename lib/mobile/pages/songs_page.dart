import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/song_list_page.dart';

class SongsPage extends StatefulWidget {
  const SongsPage({super.key});

  @override
  State<StatefulWidget> createState() => SongsPageState();
}

class SongsPageState extends State<SongsPage> {
  @override
  Widget build(BuildContext _) {
    return SongListPage(
      key: ValueKey(librarySongs),
      songList: librarySongs,
      moreSheet: (context) => moreSheet(context),
    );
  }

  Widget moreSheet(BuildContext context) {
    return mySheet(
      Column(
        children: [
          ListTile(title: Text('Songs', style: TextStyle(fontSize: 15))),
          Divider(color: Colors.grey.shade300, thickness: 0.5, height: 1),

          ListTile(
            leading: const ImageIcon(selectImage, color: Colors.black),
            title: Text(
              'Select',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SelectableSongListPage(songList: librarySongs),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.refresh_rounded),
            title: Text(
              'Reload',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () async {
              if (await showConfirmDialog(context, 'Reload Action')) {
                await libraryLoader.reload();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }
}
