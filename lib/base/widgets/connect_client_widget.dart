import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/config.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/stream_client.dart';
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
    } else if (widget.sourceType == .navidrome) {
      baseUrlTmp.text = config.navidromeBaseUrl ?? '';
      usernameTmp.text = config.navidromeUsername ?? '';
      passwordTmp.text = config.navidromePassword ?? '';
    } else {
      baseUrlTmp.text = config.embyBaseUrl ?? '';
      usernameTmp.text = config.embyUsername ?? '';
      passwordTmp.text = config.embyPassword ?? '';
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
      child: Padding(
        padding: .fromLTRB(20, 15, 20, 15),
        child: Column(
          mainAxisAlignment: .center,
          mainAxisSize: .min,
          children: [
            SizedBox(
              child: Text(
                getSourceTypeDisplayName(l10n, widget.sourceType),
                style: .new(fontWeight: .bold, fontSize: 18),
              ),
            ),

            SizedBox(height: 10),
            isTV
                ? fakeTextField('Url', baseUrlTmp)
                : CustomTextField('Url', baseUrlTmp, compact: false),

            SizedBox(height: 10),
            isTV
                ? fakeTextField(l10n.username, usernameTmp)
                : CustomTextField(l10n.username, usernameTmp, compact: false),

            SizedBox(height: 10),
            isTV
                ? fakeTextField(l10n.password, passwordTmp)
                : CustomTextField(
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

  Widget fakeTextField(String title, TextEditingController textController) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('$title:', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        InkWell(
          onTap: () async {
            textController.text = await getInputTextDialog(
              context,
              title,
              needConfirm: false,
            );
            setState(() {});
          },
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: textColor.value),
            ),
            child: Text(textController.text, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
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
                if (!await showConfirmDialog(context, l10n.delete)) {
                  return;
                }
                if (widget.sourceType == .webdav) {
                  await library.updateFolders([]);
                  webdavClient = null;
                } else if (widget.sourceType == .navidrome) {
                  config.navidromeBaseUrl = null;
                  config.navidromeUsername = null;
                  config.navidromePassword = null;
                  if (sourceType == widget.sourceType) {
                    streamClient = null;
                  }
                } else {
                  config.embyBaseUrl = null;
                  config.embyUsername = null;
                  config.embyPassword = null;
                  if (sourceType == widget.sourceType) {
                    streamClient = null;
                  }
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }

                await config.save();
                if (widget.sourceType == sourceType) {
                  await Loader.sync();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: firstLaunch ? null : value,
              ),
              child: Text(l10n.delete),
            ),

            SizedBox(width: 20),

            ElevatedButton(
              onPressed: () async {
                try {
                  if (widget.sourceType == .webdav) {
                    final tmp = webdavClient;
                    webdavClient = WebDavClient(
                      baseUrl: baseUrlTmp.text,
                      username: usernameTmp.text,
                      password: passwordTmp.text,
                    );
                    if (!await webdavClient!.ping()) {
                      showCenterMessage('Can not connect to WebDav');
                      webdavClient = tmp;
                      return;
                    }
                  } else if (widget.sourceType == .navidrome) {
                    final tmp = streamClient;
                    final navidromeClient = NavidromeClient(
                      baseUrl: baseUrlTmp.text,
                      username: usernameTmp.text,
                      password: passwordTmp.text,
                    );
                    if (!await navidromeClient.ping()) {
                      showCenterMessage('Can not connect to Navidrome');
                      streamClient = tmp;
                      return;
                    }
                    if (widget.sourceType == sourceType) {
                      streamClient = navidromeClient;
                    }
                    config.navidromeBaseUrl = baseUrlTmp.text;
                    config.navidromeUsername = usernameTmp.text;
                    config.navidromePassword = passwordTmp.text;
                  } else {
                    final tmp = streamClient;
                    final embyClient = EmbyClient(
                      baseUrl: baseUrlTmp.text,
                      username: usernameTmp.text,
                      password: passwordTmp.text,
                    );

                    if (!await embyClient.ping()) {
                      showCenterMessage('Can not connect to Emby');
                      streamClient = tmp;
                      return;
                    }
                    if (widget.sourceType == sourceType) {
                      streamClient = embyClient;
                    }
                    config.embyBaseUrl = baseUrlTmp.text;
                    config.embyUsername = usernameTmp.text;
                    config.embyPassword = passwordTmp.text;
                  }
                } catch (e) {
                  if (context.mounted) {
                    showCenterMessage(e.toString(), duration: 5000);
                  }
                  logger.output(e.toString());
                  return;
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  showCenterMessage('Save successfully');
                }
                await config.save();
                if (widget.sourceType != .webdav &&
                    widget.sourceType == sourceType) {
                  await Loader.sync();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: firstLaunch ? null : value,
              ),
              child: Text(l10n.save),
            ),
            Spacer(),
          ],
        );
      },
    );
  }
}
