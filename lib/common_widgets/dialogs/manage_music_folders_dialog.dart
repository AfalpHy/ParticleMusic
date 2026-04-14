import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/bookmark_service.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/common_widgets/webdav_dir_picker.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/loader.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class ManageMusicFoldersDialog extends StatefulWidget {
  const ManageMusicFoldersDialog({super.key});

  @override
  State<StatefulWidget> createState() => _ManageMusicFoldersDialogState();
}

class _ManageMusicFoldersDialogState extends State<ManageMusicFoldersDialog> {
  late List<String> currentFolderList;
  final updateNotifier = ValueNotifier(0);
  late ValueNotifier<bool> tmpRecursiveScanNotifier;

  @override
  void initState() {
    super.initState();

    currentFolderList = library.folderList.map((e) => e.path).toList();
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
            width: 560,
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
          child: ValueListenableBuilder(
            valueListenable: updateColorNotifier,
            builder: (context, value, child) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: options(context)),

                  SliverToBoxAdapter(child: SizedBox(height: 10)),

                  SliverToBoxAdapter(
                    child: Divider(
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
              );
            },
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
          child: ValueListenableBuilder(
            valueListenable: updateColorNotifier,
            builder: (context, value, child) {
              return Row(
                children: [
                  SizedBox(
                    width: 220,
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
                              if (await showConfirmDialog(
                                context,
                                l10n.confirm,
                              )) {
                                bool needReload =
                                    tmpRecursiveScanNotifier.value !=
                                    recursiveScanNotifier.value;
                                recursiveScanNotifier.value =
                                    tmpRecursiveScanNotifier.value;

                                settingManager.saveSetting();
                                if (await library.updateFolders(
                                      currentFolderList,
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
                  VerticalDivider(
                    thickness: 0.5,
                    width: 1,
                    color: dividerColor,
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
              );
            },
          ),
        );
      },
    );
  }

  Widget confirmButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ElevatedButton(
      onPressed: () async {
        if (await showConfirmDialog(context, l10n.confirm)) {
          bool needReload =
              tmpRecursiveScanNotifier.value != recursiveScanNotifier.value;
          recursiveScanNotifier.value = tmpRecursiveScanNotifier.value;

          settingManager.saveSetting();
          if (await library.updateFolders(currentFolderList) || needReload) {
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
      child: Text(l10n.confirm),
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

              if (currentFolderList.contains(result)) {
                if (context.mounted) {
                  showCenterMessage(
                    context,
                    'The folder already exists',
                    duration: 2000,
                  );
                }
                return;
              }

              currentFolderList.add(result);
              updateNotifier.value++;
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
                if (!currentFolderList.contains(folder)) {
                  currentFolderList.add(folder);
                }
              }

              updateNotifier.value++;
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
                  width: 320,
                  child: WebdavDirPicker(),
                ),
              );
              if (result == null) {
                return;
              }
              if (currentFolderList.contains(result)) {
                if (context.mounted) {
                  showCenterMessage(
                    context,
                    'The folder already exists',
                    duration: 2000,
                  );
                }
                return;
              }
              currentFolderList.add(result);
              updateNotifier.value++;
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
                  width: 320,
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
                if (currentFolderList.contains(folder)) {
                  continue;
                }
                currentFolderList.add(folder);
              }
              updateNotifier.value++;
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
              title: Text(currentFolderList[index]),
              trailing: IconButton(
                onPressed: () {
                  currentFolderList.removeAt(index);
                  updateNotifier.value++;
                },
                icon: Icon(Icons.clear_rounded),
              ),
            );
          }, childCount: currentFolderList.length),
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
              title: Text(currentFolderList[index]),
              trailing: IconButton(
                onPressed: () {
                  currentFolderList.removeAt(index);
                  updateNotifier.value++;
                },
                icon: Icon(Icons.clear_rounded),
              ),
            );
          },
          itemCount: currentFolderList.length,
        );
      },
    );
  }
}
