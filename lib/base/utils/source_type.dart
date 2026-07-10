import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

String getSourceTypeName(AppLocalizations l10n, SourceType sourceType) {
  switch (sourceType) {
    case .local:
      return l10n.local;
    case .webdav:
      return 'WebDAV';
    case .subsonic:
      return 'Subsonic';
    case .navidrome:
      return 'Navidrome';
    default:
      return 'Emby';
  }
}

int getSourceTypeBitMask(SourceType sourceType) {
  switch (sourceType) {
    case .local:
      return 1;
    case .webdav:
      return 2;
    case .subsonic:
      return 4;
    case .navidrome:
      return 8;
    default:
      return 16;
  }
}

AssetImage getSourceTypeImage(SourceType sourceType) {
  switch (sourceType) {
    case .local:
      return localImage;
    case .webdav:
      return webdavImage;
    case .subsonic:
      return subsonicImage;
    case .navidrome:
      return navidromeImage;
    default:
      return embyImage;
  }
}
