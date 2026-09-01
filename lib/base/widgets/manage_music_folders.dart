import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/bookmark_service.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/base/widgets/tv_dir_picker.dart';
import 'package:sylvakru/base/widgets/webdav_dir_picker.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:smooth_corner/smooth_corner.dart';

final ValueNotifier<bool> recursiveScanNotifier = ValueNotifier(false);

class ManageMusicFolders extends StatefulWidget {
  final bool inSetting;
  const ManageMusicFolders({super.key, this.inSetting = true});

  @override
  State<StatefulWidget> createState() => _ManageMusicFoldersState();
}

class _ManageMusicFoldersState extends State<ManageMusicFolders> {
  late List<String> currentFolderIdList;

  final updateNotifier = ValueNotifier(0);
  late ValueNotifier<bool> tmpRecursiveScanNotifier;

  void updateFolders() async {
    await library.updateFolders(currentFolderIdList);
  }

  @override
  void initState() {
    super.initState();

    currentFolderIdList = library.folderList.map((e) => e.id).toList();
    tmpRecursiveScanNotifier = ValueNotifier(recursiveScanNotifier.value);

    if (!widget.inSetting) {
      updateNotifier.addListener(updateFolders);
      tmpRecursiveScanNotifier.addListener(() {
        recursiveScanNotifier.value = tmpRecursiveScanNotifier.value;
        setting.save();
      });
    }
  }

  @override
  void dispose() {
    updateNotifier.dispose();
    tmpRecursiveScanNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.inSetting) {
      return _notInSettingView(context);
    }

    final appWidth = MediaQuery.widthOf(context);
    final appHeight = MediaQuery.heightOf(context);

    if (isTooNarrow(context)) {
      return SizedBox(
        height: appHeight * 0.7,
        width: max(300, appWidth * 0.5),
        child: _portraitView(context),
      );
    }
    return SizedBox(height: 320, width: 600, child: _landscapeView(context));
  }

  Widget _notInSettingView(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: updateNotifier,
      builder: (context, value, child) {
        int count = currentFolderIdList.length;
        return Column(
          children: [
            options(context),

            if (count > 0) ...[
              SizedBox(height: 10),

              MyDivider(thickness: 0.5, height: 1, color: dividerColor),

              SizedBox(height: 10),
            ],

            for (int index = 0; index < count; index++)
              ListTile(
                contentPadding: .fromLTRB(20, 0, 0, 0),
                title: Text(currentFolderIdList[index]),
                trailing: IconButton(
                  onPressed: () {
                    currentFolderIdList.removeAt(index);
                    updateNotifier.value++;
                  },
                  icon: ImageIcon(deleteImage),
                  iconSize: 20,
                ),
              ),
          ],
        );
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

              if (widget.inSetting)
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
                        onTap: () {
                          confirmAction(context);
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

  void confirmAction(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    if (await showConfirmDialog(context, l10n.confirm)) {
      if (Loader.busy) {
        if (context.mounted) {
          showCenterMessage(l10n.syncingTryLater);
        }
        return;
      }

      bool needSync = await library.updateFolders(currentFolderIdList);

      if (tmpRecursiveScanNotifier.value != recursiveScanNotifier.value) {
        recursiveScanNotifier.value = tmpRecursiveScanNotifier.value;
        setting.save();
        needSync = true;
      }

      if (context.mounted) {
        Navigator.pop(context);
      }
      if (needSync) {
        await Loader.sync();
      }
    }
  }

  Widget confirmButton(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder(
      valueListenable: buttonColor.valueNotifier,
      builder: (context, value, child) {
        return ElevatedButton(
          onPressed: () {
            confirmAction(context);
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
            dense: widget.inSetting,
            trailing: SizedBox(
              width: 70,
              child: MySwitch(valueNotifier: tmpRecursiveScanNotifier),
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
            dense: widget.inSetting,
            onTap: () {
              sourceType == .local
                  ? _addFolder(context)
                  : _addWebdavFolder(context);
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
            dense: widget.inSetting,
            onTap: () {
              sourceType == .local
                  ? _addFolders(context)
                  : _addWebdavFolders(context);
            },
            title: Text(l10n.addRecursiveFolder),
          ),
        ),
      ],
    );
  }

  Widget folderListSliver() {
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
            icon: ImageIcon(deleteImage),
            iconSize: 20,
          ),
        );
      }, childCount: currentFolderIdList.length),
    );
  }

  Widget folderList() {
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
            icon: ImageIcon(deleteImage),
            iconSize: 20,
          ),
        );
      },
      itemCount: currentFolderIdList.length,
    );
  }

  Future<bool> _checkAndConfigureIOSPath(
    BuildContext context,
    String path,
  ) async {
    final l10n = AppLocalizations.of(context);
    bool isOnMyiPhone = isFileProviderStorePath(path);

    if (!isOnMyiPhone && !path.contains(appDocsDir.path)) {
      if (context.mounted) {
        showCenterMessage(l10n.folderNotSupportedYet);
      }
      return false;
    }

    if (isOnMyiPhone && !await BookmarkService.active(path)) {
      if (context.mounted) {
        showCenterMessage(l10n.getPermissionFailed);
      }
      return false;
    }
    if (isOnMyiPhone) {
      setIOSFileProviderStorageIfNeed(path);
    }
    return true;
  }

  void _addFolder(BuildContext context) async {
    String? result;

    if (isTV) {
      result = await showAnimationDialog(
        context: context,
        child: SizedBox(
          height: MediaQuery.heightOf(context) * 0.8,
          width: 300,
          child: TvDirPicker(),
        ),
      );
    } else {
      result = await FilePicker.getDirectoryPath();
    }

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
        showCenterMessage(AppLocalizations.of(context).folderExist);
      }
      return;
    }
    currentFolderIdList.add(id);
    updateNotifier.value++;
  }

  void _addFolders(BuildContext context) async {
    String? result;
    if (isTV) {
      result = await showAnimationDialog(
        context: context,
        child: SizedBox(
          height: MediaQuery.heightOf(context) * 0.8,
          width: 300,
          child: TvDirPicker(),
        ),
      );
    } else {
      result = await FilePicker.getDirectoryPath();
    }

    if (result == null || !context.mounted) {
      return;
    }
    if (Platform.isIOS && !await _checkAndConfigureIOSPath(context, result)) {
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
      showCenterMessage('Please connect to WebDAV first');
      return false;
    }
    try {
      await webdavClient!.ping();
    } catch (e) {
      if (!context.mounted) {
        return false;
      }
      showCenterMessage('Can not connect to WebDAV');
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
        showCenterMessage(AppLocalizations.of(context).folderExist);
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
    final subDirectories = await webdavClient!.listSubDirectories(root);
    idList.addAll(subDirectories);

    for (final id in idList) {
      if (currentFolderIdList.contains(id)) {
        continue;
      }
      currentFolderIdList.add(id);
    }
    updateNotifier.value++;
  }
}
