import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

String getSourceTypeDisplayName(AppLocalizations l10n, SourceType sourceType) {
  switch (sourceType) {
    case .local:
      return l10n.local;
    case .webdav:
      return 'WebDAV';
    case .navidrome:
      return 'Navidrome';
    default:
      return 'Emby';
  }
}

AssetImage getSourceTypeImage(SourceType sourceType) {
  switch (sourceType) {
    case .local:
      return localImage;
    case .webdav:
      return webdavImage;
    case .navidrome:
      return navidromeImage;
    default:
      return embyImage;
  }
}
