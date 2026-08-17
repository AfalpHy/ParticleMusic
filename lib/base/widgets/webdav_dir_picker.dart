import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:path/path.dart';

class WebdavDirPicker extends StatefulWidget {
  const WebdavDirPicker({super.key});

  @override
  State<StatefulWidget> createState() => _WebdavDirPickerState();
}

class _WebdavDirPickerState extends State<WebdavDirPicker> {
  String root = '/';
  String currentPath = '/';
  List<String> directories = [];
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    loadDirectories(currentPath);
  }

  Future<List<String>> listDirectories(String path) async {
    try {
      await webdavClient!.ping();
    } catch (e) {
      return [];
    }

    final files = await webdavClient!.list(path);
    // Keep only directories
    final directories = files
        .where((f) => f.isDirectory)
        .map((f) => f.path.substring(webdavClient!.initialPath.length))
        .toList();
    return directories;
  }

  void loadDirectories(String path) async {
    setState(() {
      isLoading = true;
    });
    final dirs = await listDirectories(path);
    setState(() {
      isLoading = false;
      currentPath = path;
      directories = dirs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (currentPath == root) {
                    return;
                  }
                  loadDirectories(dirname(currentPath));
                },
                icon: Icon(Icons.arrow_back_ios_rounded),
              ),
              Transform.translate(
                offset: Offset(0, isMobile ? 0 : -1.5),
                child: Text(
                  basename(currentPath),
                  style: .new(fontWeight: .bold, fontSize: 18),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(color: iconColor.value),
                  )
                : ListView.builder(
                    itemCount: directories.length,
                    itemBuilder: (context, index) {
                      final dir = directories[index];
                      return ListTile(
                        title: Text(basename(dir)),
                        leading: Icon(Icons.folder),
                        dense: true,
                        onTap: () {
                          loadDirectories(dir); // navigate into subdirectory
                        },
                      );
                    },
                  ),
          ),
          SizedBox(height: 10),

          Row(
            mainAxisAlignment: .end,
            children: [
              ValueListenableBuilder(
                valueListenable: buttonColor.valueNotifier,
                builder: (context, value, child) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, currentPath);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: value),
                    child: Text(AppLocalizations.of(context).confirm),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 5),
        ],
      ),
    );
  }
}
