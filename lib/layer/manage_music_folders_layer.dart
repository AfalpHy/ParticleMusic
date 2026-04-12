import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/bookmark_service.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/common_widgets/webdav_dir_picker.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/landscape_view/title_bar.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/loader.dart';
import 'package:particle_music/portrait_view/custom_appbar_leading.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

List<String>? _currentFolderList;
final _updateNotifier = ValueNotifier(0);
ValueNotifier<bool>? _tmpRecursiveScanNotifier;
int _cnt = 0;

class ManageMusicFoldersLayer extends StatefulWidget {
  const ManageMusicFoldersLayer({super.key});

  @override
  State<StatefulWidget> createState() => _ManageMusicFoldersLayerState();
}

class _ManageMusicFoldersLayerState extends State<ManageMusicFoldersLayer> {
  @override
  void initState() {
    super.initState();
    _cnt++;
    _currentFolderList ??= library.folderList.map((e) => e.path).toList();
    _tmpRecursiveScanNotifier ??= ValueNotifier(recursiveScanNotifier.value);
  }

  @override
  void dispose() {
    _cnt--;
    if (_cnt == 0) {
      _currentFolderList = null;
      _tmpRecursiveScanNotifier = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return page(context);
        } else {
          return panel(context);
        }
      },
    );
  }

  Widget page(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.manageMusicFolder),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: _updateNotifier,
        builder: (context, value, child) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ValueListenableBuilder(
              valueListenable: updateColorNotifier,
              builder: (context, value, child) {
                return Column(
                  children: [
                    Material(
                      color: selectedItemColor,
                      shape: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: .all(.circular(10)),
                      ),
                      clipBehavior: .antiAlias,
                      child: options(context),
                    ),
                    ListTile(title: Text("${l10n.addedFolders}:"), dense: true),
                    Expanded(
                      child: Material(
                        color: selectedItemColor,
                        shape: SmoothRectangleBorder(
                          smoothness: 1,
                          borderRadius: .all(.circular(10)),
                        ),
                        clipBehavior: .antiAlias,
                        child: folderListWidget(),
                      ),
                    ),
                    SizedBox(height: 100),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget panel(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(),

        Expanded(
          child: Column(
            children: [
              Text(
                l10n.manageMusicFolder,
                style: .new(
                  fontWeight: .bold,
                  fontSize: 20,
                  color: highlightTextColor,
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 250,
                        child: ListView(children: [options(context)]),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 0.5,
                        color: dividerColor,
                      ),
                      Expanded(child: folderListWidget()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget options(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: .all(.circular(10)),
          ),
          clipBehavior: .antiAlias,
          child: ListTile(
            dense: true,
            title: Text(l10n.recursiveScan),
            trailing: ValueListenableBuilder(
              valueListenable: _tmpRecursiveScanNotifier!,
              builder: (context, value, child) {
                return SizedBox(
                  width: 50,
                  child: MySwitch(
                    value: value,
                    onToggle: (v) {
                      _tmpRecursiveScanNotifier!.value = v;
                    },
                  ),
                );
              },
            ),
          ),
        ),

        Material(
          color: Colors.transparent,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: .all(.circular(10)),
          ),
          clipBehavior: .antiAlias,
          child: ListTile(
            dense: true,

            onTap: () async {
              String? result = await FilePicker.platform.getDirectoryPath();
              if (result == null) {
                return;
              }

              if (Platform.isIOS) {
                if (!result.contains('File Provider Storage/') &&
                    !result.contains(appDocs.path)) {
                  if (context.mounted) {
                    showCenterMessage(
                      context,
                      'Do not support this folder',
                      duration: 2000,
                    );
                  }
                  return;
                }

                if (isFileProviderStorePath(result) &&
                    !await BookmarkService.active(result)) {
                  if (context.mounted) {
                    showCenterMessage(
                      context,
                      'Get permission failed',
                      duration: 2000,
                    );
                  }
                  return;
                }
                library.setIOSFileProviderStorageIfNeed(result);
                result = convertIOSPath(result);
              }

              if (_currentFolderList!.contains(result)) {
                if (context.mounted) {
                  showCenterMessage(
                    context,
                    'The folder already exists',
                    duration: 2000,
                  );
                }
                return;
              }

              _currentFolderList!.add(result);
              _updateNotifier.value++;
            },
            title: Text(l10n.addFolder),
          ),
        ),

        Material(
          color: Colors.transparent,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: .all(.circular(10)),
          ),
          clipBehavior: .antiAlias,
          child: ListTile(
            dense: true,

            onTap: () async {
              String? result = await FilePicker.platform.getDirectoryPath();
              if (result == null) {
                return;
              }
              if (Platform.isIOS) {
                if (!result.contains('File Provider Storage/') &&
                    !result.contains(appDocs.path)) {
                  if (context.mounted) {
                    showCenterMessage(
                      context,
                      'Do not support this folder',
                      duration: 2000,
                    );
                  }
                  return;
                }
                if (isFileProviderStorePath(result) &&
                    !await BookmarkService.active(result)) {
                  if (context.mounted) {
                    showCenterMessage(
                      context,
                      'Get permission failed',
                      duration: 2000,
                    );
                  }
                  return;
                }
                library.setIOSFileProviderStorageIfNeed(result);
              }

              Directory root = Directory(result);

              List<String> folderList = root
                  .listSync(recursive: true)
                  .whereType<Directory>()
                  .map((d) => d.path)
                  .toList();

              folderList.insert(0, result);

              for (String folder in folderList) {
                if (Platform.isIOS) {
                  folder = convertIOSPath(folder);
                }
                if (!_currentFolderList!.contains(folder)) {
                  _currentFolderList!.add(folder);
                }
              }

              _updateNotifier.value++;
            },
            title: Text(l10n.addRecursiveFolder),
          ),
        ),

        Material(
          color: Colors.transparent,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: .all(.circular(10)),
          ),
          clipBehavior: .antiAlias,
          child: ListTile(
            dense: true,

            onTap: () async {
              if (webdavClient == null) {
                showCenterMessage(
                  context,
                  'There is no connected WebDAV.',
                  duration: 2000,
                );
                return;
              }
              try {
                await webdavClient!.ping();
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
                showCenterMessage(
                  context,
                  'Can not connect to WebDAV.',
                  duration: 2000,
                );
                return;
              }
              if (!context.mounted) {
                return;
              }
              final result = await showAnimationDialog(
                context: context,

                child: SizedBox(
                  height: 350,
                  width: 300,
                  child: WebdavDirPicker(),
                ),
              );
              if (result == null) {
                return;
              }
              if (_currentFolderList!.contains(result)) {
                if (context.mounted) {
                  showCenterMessage(
                    context,
                    'The folder already exists',
                    duration: 2000,
                  );
                }
                return;
              }
              _currentFolderList!.add(result);
              _updateNotifier.value++;
            },
            title: Text(l10n.addWebDAVFolder),
          ),
        ),

        Material(
          color: Colors.transparent,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: .all(.circular(10)),
          ),
          clipBehavior: .antiAlias,
          child: ListTile(
            dense: true,

            onTap: () async {
              if (webdavClient == null) {
                showCenterMessage(
                  context,
                  'There is no connected WebDAV.',
                  duration: 2000,
                );
                return;
              }
              try {
                await webdavClient!.ping();
              } catch (e) {
                if (!context.mounted) {
                  return;
                }
                showCenterMessage(
                  context,
                  'Can not connect to WebDAV.',
                  duration: 2000,
                );
                return;
              }
              if (!context.mounted) {
                return;
              }
              String? result = await showAnimationDialog(
                context: context,

                child: SizedBox(
                  height: 350,
                  width: 300,
                  child: WebdavDirPicker(),
                ),
              );
              if (result == null) {
                return;
              }
              List<String> folderList = [result];
              final subDirectories = await getWebdavSubDirectoriesFrom(
                result.substring(7),
              );
              for (final dir in subDirectories) {
                folderList.add('WebDAV:$dir');
              }

              for (final folder in folderList) {
                if (_currentFolderList!.contains(folder)) {
                  continue;
                }
                _currentFolderList!.add(folder);
              }
              _updateNotifier.value++;
            },
            title: Text(l10n.addWebDAVRecursiveFolder),
          ),
        ),

        Material(
          color: Colors.transparent,
          shape: SmoothRectangleBorder(
            smoothness: 1,
            borderRadius: .all(.circular(10)),
          ),
          clipBehavior: .antiAlias,
          child: ListTile(
            dense: true,
            title: Text(l10n.confirm),

            onTap: () async {
              if (await showConfirmDialog(context, l10n.confirm)) {
                bool needReload =
                    _tmpRecursiveScanNotifier!.value !=
                    recursiveScanNotifier.value;
                recursiveScanNotifier.value = _tmpRecursiveScanNotifier!.value;

                settingManager.saveSetting();
                if (await library.updateFolders(_currentFolderList!) ||
                    needReload) {
                  await Loader.reload();
                } else {
                  layersManager.popLayer();
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget folderListWidget() {
    return ValueListenableBuilder(
      valueListenable: _updateNotifier,
      builder: (context, value, child) {
        return ListView.builder(
          itemCount: _currentFolderList!.length,
          itemBuilder: (context, index) {
            return ListTile(
              dense: true,
              title: Text(_currentFolderList![index]),
              trailing: IconButton(
                onPressed: () {
                  _currentFolderList!.removeAt(index);
                  _updateNotifier.value++;
                },
                icon: Icon(Icons.clear_rounded),
              ),
            );
          },
        );
      },
    );
  }
}
