import 'package:material_ui/material_ui.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/iap_service.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/settings_layer.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

final trialRemainingMinNotifier = ValueNotifier(-1);

class PremiumLayer extends StatefulWidget {
  const PremiumLayer({super.key});

  @override
  State<StatefulWidget> createState() => _PremiumLayerState();
}

class _PremiumLayerState extends State<PremiumLayer> {
  final IAPService _iapService = IAPService();
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _iapService.initialize();
    _iapService.onMessage = (msg, {duration}) {
      showCenterMessage(context, msg, duration: duration ?? 3000);
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iapService.l10n = AppLocalizations.of(context);
    });
  }

  @override
  void dispose() {
    _iapService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isTooNarrow(context)) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: customAppBarLeading(context, label: 'settings'),
          backgroundColor: Colors.transparent,
          systemOverlayStyle: mainPageThemeNotifier.value == .dark
              ? .light
              : .dark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
        ),
        body: premiumContent(context),
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: settingsVisibleNotifier,
      builder: (context, visible, child) {
        return Opacity(
          opacity: visible ? 0 : 1,
          child: Column(
            children: [
              TitleBar(backToRoot: () => layersManager.popDetail('settings')),
              Expanded(child: premiumContent(context)),
            ],
          ),
        );
      },
    );
  }

  Widget premiumContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: ValueListenableBuilder(
          valueListenable: buttonColor.valueNotifier,
          builder: (context, value, child) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                ImageIcon(premiumImage, size: 72),

                const SizedBox(height: 8),

                Text(
                  l10n.premiumFeatures,
                  textAlign: TextAlign.center,
                  style: .new(fontSize: 24, fontWeight: .bold),
                ),

                const SizedBox(height: 8),

                Text(l10n.premiumDescription, textAlign: TextAlign.center),

                const SizedBox(height: 16),

                ListenableBuilder(
                  listenable: Listenable.merge([
                    isPremiumNotifier,
                    trialRemainingMinNotifier,
                  ]),
                  builder: (context, _) {
                    bool canPurchase =
                        !isPremiumNotifier.value ||
                        trialRemainingMinNotifier.value >= 0;
                    return Column(
                      children: [
                        Card(
                          color: buttonColor.value,
                          shadowColor: mainPageThemeNotifier.value == .vivid
                              ? Colors.black.withAlpha(10)
                              : mainPageThemeNotifier.value == .dark
                              ? Colors.white
                              : null,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: SmoothRectangleBorder(
                            smoothness: 1,
                            borderRadius: .circular(10),
                          ),
                          clipBehavior: .antiAlias,
                          child: InkWell(
                            onTap: () async {
                              if (!canPurchase || isProcessing) {
                                return;
                              }
                              isProcessing = true;
                              if (await _iapService.checkAvailability()) {
                                await _iapService.buyProduct();
                              }
                              await Future.delayed(Duration(milliseconds: 50));
                              isProcessing = false;
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: .center,
                                children: [
                                  if (!canPurchase) ...[
                                    const Icon(Icons.check_circle, size: 20),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    !canPurchase
                                        ? l10n.alreadyPremium
                                        : l10n.unlockPremium,
                                    style: .new(
                                      fontSize: 15,
                                      fontWeight: .bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (canPurchase) ...[
                          const SizedBox(height: 8),

                          Card(
                            color: buttonColor.value,
                            shadowColor: mainPageThemeNotifier.value == .vivid
                                ? Colors.black.withAlpha(10)
                                : mainPageThemeNotifier.value == .dark
                                ? Colors.white
                                : null,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: .circular(10),
                            ),
                            clipBehavior: .antiAlias,
                            child: InkWell(
                              onTap: () async {
                                if (isProcessing) {
                                  return;
                                }
                                isProcessing = true;
                                if (await _iapService.checkAvailability()) {
                                  await _iapService.restorePurchases();
                                }
                                await Future.delayed(
                                  Duration(milliseconds: 50),
                                );
                                isProcessing = false;
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Center(
                                  child: Text(
                                    l10n.restorePurchase,
                                    style: .new(
                                      fontSize: 15,
                                      fontWeight: .bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                Text(
                  l10n.whatPremiumContains,
                  style: .new(fontWeight: .bold, fontSize: 16),
                ),

                const SizedBox(height: 12),

                FeatureCard(
                  icon: ImageIcon(themeImage, size: 30),
                  title: l10n.theme,
                  description: l10n.themeDescription,
                ),

                FeatureCard(
                  icon: ImageIcon(bigPictureModeImage, size: 30),
                  title: l10n.bigPictureMode,
                  description: l10n.bigPictureModeDescription,
                ),

                FeatureCard(
                  icon: ImageIcon(fontImage, size: 30),
                  title: l10n.fonts,
                  description: l10n.fontDescription,
                ),

                FeatureCard(
                  icon: ImageIcon(equalizerImage, size: 30),
                  title: l10n.equalizer,
                  description: l10n.equalizerDescription,
                ),

                FeatureCard(
                  icon: ImageIcon(futurePremiumImage, size: 30),
                  title: l10n.futurePremium,
                  description: l10n.futurePremiumDescription,
                ),
                const SizedBox(height: 90),
              ],
            );
          },
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final descriptionStyle = const TextStyle(height: 1.4);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: buttonColor.value,
      shadowColor: mainPageThemeNotifier.value == .vivid
          ? Colors.black.withAlpha(10)
          : mainPageThemeNotifier.value == .dark
          ? Colors.white
          : null,
      margin: const EdgeInsets.only(bottom: 12),
      shape: SmoothRectangleBorder(smoothness: 1, borderRadius: .circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: .new(fontWeight: .bold, fontSize: 16)),

                  const SizedBox(height: 4),

                  Text(description, style: descriptionStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
