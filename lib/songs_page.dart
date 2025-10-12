import 'dart:async';

import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/song_list_scaffold.dart';

class SongsScaffold extends StatefulWidget {
  final Future<void> Function() reload;

  const SongsScaffold({super.key, required this.reload});

  @override
  State<StatefulWidget> createState() => SongsScaffoldState();
}

class SongsScaffoldState extends State<SongsScaffold> {
  @override
  Widget build(BuildContext _) {
    return SongListScaffold(
      songList: librarySongs,
      moreSheet: (context) => moreSheet(context),
    );
  }

  Widget moreSheet(BuildContext context) {
    return mySheet(
      Column(
        children: [
          ListTile(title: Text('Library', style: TextStyle(fontSize: 15))),
          Divider(color: Colors.grey.shade300, thickness: 0.5, height: 1),

          ListTile(
            leading: Icon(Icons.reorder_rounded),
            title: Text(
              'Select',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      SelectableSongListScaffold(songList: librarySongs),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.refresh_rounded),
            title: Text(
              'Reload Library',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            onTap: () async {
              if (await showConfirmDialog(context, 'Reload Action')) {
                await widget.reload();
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
