import 'package:material_ui/material_ui.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/data/folder.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/my_navigator.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

part '../landscape_view/panels/folders_panel.dart';
part '../portrait_view/pages/folders_page.dart';

final GlobalKey<NavigatorState> foldersKey = GlobalKey();
final foldersVisibleNotifier = ValueNotifier(true);

class FoldersLayer extends StatelessWidget {
  const FoldersLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: foldersKey,
      visibleNotifier: foldersVisibleNotifier,
      pageViewBuilder: () => pageView(context),
      panelViewBuilder: () => panelView(context),
    );
  }
}
