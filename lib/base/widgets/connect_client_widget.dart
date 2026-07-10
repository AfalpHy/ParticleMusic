import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/config.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/subsonic_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/utils/source_type.dart';
import 'package:sylvakru/base/widgets/custom_text_field.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

class ConnectClientWidget extends StatefulWidget {
  final SourceType sourceType;

  const ConnectClientWidget({super.key, required this.sourceType});
  @override
  State<StatefulWidget> createState() => _ConnectClientWidgetState();
}

class _ConnectClientWidgetState extends State<ConnectClientWidget> {
  final baseUrlTmp = TextEditingController();
  final usernameTmp = TextEditingController();
  final passwordTmp = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.sourceType == .webdav) {
      baseUrlTmp.text = webdavClient?.baseUrl ?? '';
      usernameTmp.text = webdavClient?.username ?? '';
      passwordTmp.text = webdavClient?.password ?? '';
    } else if (widget.sourceType == .subsonic) {
      baseUrlTmp.text = subsonicClient?.baseUrl ?? '';
      usernameTmp.text = subsonicClient?.username ?? '';
      passwordTmp.text = subsonicClient?.password ?? '';
    } else if (widget.sourceType == .navidrome) {
      baseUrlTmp.text = navidromeClient?.baseUrl ?? '';
      usernameTmp.text = navidromeClient?.username ?? '';
      passwordTmp.text = navidromeClient?.password ?? '';
    } else {
      baseUrlTmp.text = embyClient?.baseUrl ?? '';
      usernameTmp.text = embyClient?.username ?? '';
      passwordTmp.text = embyClient?.password ?? '';
    }
  }

  @override
  void dispose() {
    baseUrlTmp.dispose();
    usernameTmp.dispose();
    passwordTmp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: 300,
      height: isMobile ? 345 : 320,
      child: Padding(
        padding: .fromLTRB(20, 15, 20, 15),
        child: Column(
          mainAxisAlignment: .center,
          children: [
            SizedBox(
              child: Text(
                getSourceTypeName(l10n, widget.sourceType),
                style: .new(fontWeight: .bold, fontSize: 18),
              ),
            ),

            SizedBox(height: 10),
            CustomTextField('Url', baseUrlTmp, compact: false),

            SizedBox(height: 10),
            CustomTextField(l10n.username, usernameTmp, compact: false),

            SizedBox(height: 10),
            CustomTextField(
              l10n.password,
              passwordTmp,
              needObscure: true,
              compact: false,
            ),

            SizedBox(height: isMobile ? 10 : 25),

            buttons(),
          ],
        ),
      ),
    );
  }

  Widget buttons() {
    return ValueListenableBuilder(
      valueListenable: buttonColor.valueNotifier,
      builder: (context, value, child) {
        final l10n = AppLocalizations.of(context);

        return Row(
          children: [
            Spacer(),
            ElevatedButton(
              onPressed: () async {
                if (Loader.syncing) {
                  showCenterMessage(context, l10n.syncingTryLater);
                  return;
                }

                if (!await showConfirmDialog(context, l10n.clear)) {
                  return;
                }
                if (widget.sourceType == .webdav) {
                  await library.updateFolders([], false);
                  webdavClient = null;
                } else if (widget.sourceType == .subsonic) {
                  subsonicClient = null;
                } else if (widget.sourceType == .navidrome) {
                  navidromeClient = null;
                } else {
                  embyClient = null;
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
                await config.save();
                await Loader.sync(getSourceTypeBitMask(widget.sourceType));
              },
              style: ElevatedButton.styleFrom(backgroundColor: value),
              child: Text(l10n.clear),
            ),

            SizedBox(width: 20),

            ElevatedButton(
              onPressed: () async {
                if (Loader.syncing) {
                  showCenterMessage(context, l10n.syncingTryLater);
                  return;
                }

                if (widget.sourceType == .webdav) {
                  final tmp = webdavClient;
                  webdavClient = WebDavClient(
                    baseUrl: baseUrlTmp.text,
                    username: usernameTmp.text,
                    password: passwordTmp.text,
                  );
                  if (!await webdavClient!.ping()) {
                    if (context.mounted) {
                      showCenterMessage(context, 'Can not connect to WebDAV');
                    }
                    webdavClient = tmp;
                    return;
                  }
                } else if (widget.sourceType == .subsonic) {
                  final tmp = subsonicClient;
                  subsonicClient = SubsonicClient(
                    baseUrl: baseUrlTmp.text,
                    username: usernameTmp.text,
                    password: passwordTmp.text,
                  );
                  if (!await subsonicClient!.ping()) {
                    if (context.mounted) {
                      showCenterMessage(context, 'Can not connect to Subsonic');
                    }
                    subsonicClient = tmp;
                    return;
                  }
                } else if (widget.sourceType == .navidrome) {
                  final tmp = navidromeClient;
                  navidromeClient = NavidromeClient(
                    baseUrl: baseUrlTmp.text,
                    username: usernameTmp.text,
                    password: passwordTmp.text,
                  );
                  if (!await navidromeClient!.ping()) {
                    if (context.mounted) {
                      showCenterMessage(
                        context,
                        'Can not connect to Navidrome',
                      );
                    }
                    navidromeClient = tmp;
                    return;
                  }
                } else {
                  final tmp = embyClient;
                  embyClient = EmbyClient(
                    baseUrl: baseUrlTmp.text,
                    username: usernameTmp.text,
                    password: passwordTmp.text,
                  );

                  if (!await embyClient!.login()) {
                    if (context.mounted) {
                      showCenterMessage(context, 'Can not connect to Emby');
                    }
                    embyClient = tmp;
                    return;
                  }
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  showCenterMessage(context, 'Connected successfully');
                }
                await config.save();
                if (widget.sourceType != .webdav) {
                  await Loader.sync(getSourceTypeBitMask(widget.sourceType));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: value),
              child: Text(l10n.confirm),
            ),
            Spacer(),
          ],
        );
      },
    );
  }
}
