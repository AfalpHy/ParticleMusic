import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/bookmark_service.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_divider.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/common_widgets/webdav_dir_picker.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/loader.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class ManageMusicFolders extends StatefulWidget {
  const ManageMusicFolders({super.key});

  @override
  State<StatefulWidget> createState() => _ManageMusicFoldersState();
}

class _ManageMusicFoldersState extends State<ManageMusicFolders> {
  late List<String> currentFolderIdList;
  final updateNotifier = ValueNotifier(0);
  late ValueNotifier<bool> tmpRecursiveScanNotifier;

  @override
  void initState() {
    super.initState();

    currentFolderIdList = library.folderList.map((e) => e.id).toList();
    tmpRecursiveScanNotifier = ValueNotifier(recursiveScanNotifier.value);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final appWidth = MediaQuery.widthOf(context);
        final appHeight = MediaQuery.heightOf(context);

        if (isMobile && orientation == Orientation.portrait) {
          return SizedBox(
            height: appHeight * 0.7,
            width: max(300, appWidth * 0.5),
            child: _portraitView(context),
          );
        } else {
          return SizedBox(
            height: 320,
            width: 600,
            child: _landscapeView(context),
          );
        }
      },
    );
  }

  Widget _portraitView(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: updateNotifier,
      builder: (context, value, child) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: options(context)),

              SliverToBoxAdapter(child: SizedBox(height: 10)),

              SliverToBoxAdapter(
                child: MyDivider(
                  thickness: 0.5,
                  height: 1,
                  color: dividerColor,
                ),
              ),

              SliverToBoxAdapter(child: SizedBox(height: 10)),

              folderListSliver(),

              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    const Spacer(),

                    Align(
                      alignment: Alignment.centerRight,
                      child: confirmButton(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _landscapeView(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder(
      valueListenable: updateNotifier,
      builder: (context, value, child) {
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 230,
                child: Column(
                  children: [
                    Spacer(),
                    options(context),
                    Material(
                      color: Colors.transparent,
                      shape: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: .all(.circular(10)),
                      ),
                      clipBehavior: .antiAlias,
                      child: ListTile(
                        contentPadding: .fromLTRB(15, 0, 0, 0),
                        dense: true,
                        title: Text(l10n.confirm),
                        onTap: () async {
                          if (await showConfirmDialog(context, l10n.confirm)) {
                            bool needReload =
                                tmpRecursiveScanNotifier.value !=
                                recursiveScanNotifier.value;
                            recursiveScanNotifier.value =
                                tmpRecursiveScanNotifier.value;

                            settingManager.saveSetting();
                            if (await library.updateFolders(
                                  currentFolderIdList,
                                ) ||
                                needReload) {
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                              await Loader.reload();
                            } else {
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          }
                        },
                      ),
                    ),
                    Spacer(),
                  ],
                ),
              ),
              SizedBox(width: 10),
              MyDivider(
                thickness: 0.5,
                width: 1,
                color: dividerColor,
                vertical: true,
              ),

              Expanded(
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Expanded(child: folderList()),

                    SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget confirmButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder(
      valueListenable: buttonColor.valueNotifier,
      builder: (context, value, child) {
        return ElevatedButton(
          onPressed: () async {
            if (await showConfirmDialog(context, l10n.confirm)) {
              bool needReload =
                  tmpRecursiveScanNotifier.value != recursiveScanNotifier.value;
              recursiveScanNotifier.value = tmpRecursiveScanNotifier.value;

              settingManager.saveSetting();
              if (await library.updateFolders(currentFolderIdList) ||
                  needReload) {
                if (context.mounted) {
                  Navigator.pop(context);
                }
                await Loader.reload();
              } else {
                if (context.mounted) {
                  showCenterMessage(
                    context,
                    'Nothing is changed',
                    duration: 2000,
                  );
                  Navigator.pop(context);
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: value),
          child: Text(l10n.confirm),
        );
      },
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
            title: Text(l10n.recursiveScan),
            contentPadding: .fromLTRB(15, 0, 0, 0),
            dense: true,
            trailing: ValueListenableBuilder(
              valueListenable: tmpRecursiveScanNotifier,
              builder: (context, value, child) {
                return SizedBox(
                  width: 50,
                  child: MySwitch(
                    value: value,
                    onToggle: (v) {
                      tmpRecursiveScanNotifier.value = v;
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
            contentPadding: .fromLTRB(15, 0, 0, 0),
            dense: true,
            onTap: () {
              _addFolder(context);
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
            contentPadding: .fromLTRB(15, 0, 0, 0),
            dense: true,
            onTap: () {
              _addFolders(context);
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
            contentPadding: .fromLTRB(15, 0, 0, 0),
            dense: true,
            onTap: () {
              _addWebdavFolder(context);
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
            contentPadding: .fromLTRB(15, 0, 0, 0),
            dense: true,
            onTap: () {
              _addWebdavFolders(context);
            },
            title: Text(l10n.addWebDAVRecursiveFolder),
          ),
        ),
      ],
    );
  }

  Widget folderListSliver() {
    return ValueListenableBuilder(
      valueListenable: updateNotifier,
      builder: (context, value, child) {
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return ListTile(
              dense: true,
              contentPadding: .fromLTRB(15, 0, 0, 0),
              title: Text(currentFolderIdList[index]),
              trailing: IconButton(
                onPressed: () {
                  currentFolderIdList.removeAt(index);
                  updateNotifier.value++;
                },
                icon: Icon(Icons.clear_rounded),
              ),
            );
          }, childCount: currentFolderIdList.length),
        );
      },
    );
  }

  Widget folderList() {
    return ValueListenableBuilder(
      valueListenable: updateNotifier,
      builder: (context, value, child) {
        return ListView.builder(
          itemBuilder: (context, index) {
            return ListTile(
              dense: true,
              contentPadding: .fromLTRB(20, 0, 0, 0),
              title: Text(currentFolderIdList[index]),
              trailing: IconButton(
                onPressed: () {
                  currentFolderIdList.removeAt(index);
                  updateNotifier.value++;
                },
                icon: Icon(Icons.clear_rounded),
              ),
            );
          },
          itemCount: currentFolderIdList.length,
        );
      },
    );
  }

  Future<bool> _checkAndConfigureIOSPath(
    BuildContext context,
    String path,
  ) async {
    bool isOnMyiPhone = isFileProviderStorePath(path);
    if (!isOnMyiPhone && !path.contains(appDocs.path)) {
      if (context.mounted) {
        showCenterMessage(
          context,
          'This folder is not supported yet.',
          duration: 2000,
        );
      }
      return false;
    }

    if (isOnMyiPhone && !await BookmarkService.active(path)) {
      if (context.mounted) {
        showCenterMessage(context, 'Get permission failed', duration: 2000);
      }
      return false;
    }
    if (isOnMyiPhone) {
      library.setIOSFileProviderStorageIfNeed(path);
    }
    return true;
  }

  void _addFolder(BuildContext context) async {
    String? result = await FilePicker.getDirectoryPath();
    if (result == null || !context.mounted) {
      return;
    }

    String id = result;
    if (Platform.isIOS) {
      if (!await _checkAndConfigureIOSPath(context, result)) {
        return;
      }
      id = convertIOSPath(result);
    }

    if (currentFolderIdList.contains(id)) {
      if (context.mounted) {
        showCenterMessage(context, 'The folder already exists', duration: 2000);
      }
      return;
    }

    currentFolderIdList.add(id);
    updateNotifier.value++;
  }

  void _addFolders(BuildContext context) async {
    String? result = await FilePicker.getDirectoryPath();
    if (result == null || !context.mounted) {
      return;
    }
    if (Platform.isIOS && await _checkAndConfigureIOSPath(context, result)) {
      return;
    }

    Directory root = Directory(result);

    List<String> pathList = root
        .listSync(recursive: true)
        .whereType<Directory>()
        .map((d) => d.path)
        .toList();

    pathList.insert(0, result);

    for (String path in pathList) {
      String id = path;
      if (Platform.isIOS) {
        id = convertIOSPath(path);
      }
      if (!currentFolderIdList.contains(id)) {
        currentFolderIdList.add(id);
      }
    }

    updateNotifier.value++;
  }

  Future<bool> _isWebdavValid(BuildContext context) async {
    if (webdavClient == null) {
      showCenterMessage(
        context,
        'There is no connected WebDAV',
        duration: 2000,
      );
      return false;
    }
    try {
      await webdavClient!.ping();
    } catch (e) {
      if (!context.mounted) {
        return false;
      }
      showCenterMessage(context, 'Can not connect to WebDAV', duration: 2000);
      return false;
    }
    return true;
  }

  void _addWebdavFolder(BuildContext context) async {
    if (!await _isWebdavValid(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final id = await showAnimationDialog(
      context: context,
      child: SizedBox(height: 350, width: 300, child: WebdavDirPicker()),
    );
    if (id == null) {
      return;
    }
    if (currentFolderIdList.contains(id)) {
      if (context.mounted) {
        showCenterMessage(context, 'The folder already exists', duration: 2000);
      }
      return;
    }
    currentFolderIdList.add(id);
    updateNotifier.value++;
  }

  void _addWebdavFolders(BuildContext context) async {
    if (!await _isWebdavValid(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    String? root = await showAnimationDialog(
      context: context,
      child: SizedBox(height: 350, width: 300, child: WebdavDirPicker()),
    );
    if (root == null) {
      return;
    }
    List<String> idList = [root];
    final subDirectories = await getWebdavSubDirectoriesFrom(root.substring(7));
    for (final dir in subDirectories) {
      idList.add('WebDAV:$dir');
    }

    for (final id in idList) {
      if (currentFolderIdList.contains(id)) {
        continue;
      }
      currentFolderIdList.add(id);
    }
    updateNotifier.value++;
  }
}
