import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/config.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/premium_layer.dart';

class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  Function(String, {int? duration})? onMessage;

  bool foundAnyRestored = false;

  List<ProductDetails> products = [];

  late AppLocalizations l10n;

  void initialize() {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () => _subscription.cancel(),
      onError: (error) => logger.output('Purchase stream error: $error'),
    );
  }

  void dispose() {
    _subscription.cancel();
  }

  Future<bool> checkAvailability() async {
    final available = await _iap.isAvailable();
    if (!available) {
      onMessage?.call(l10n.iapNotAvailable);
    }
    return available;
  }

  Future<void> buyProduct() async {
    onMessage?.call(l10n.connectingToAppStore);
    if (products.isEmpty) {
      final ProductDetailsResponse response = await _iap.queryProductDetails({
        'com.afalphy.sylvakru.premium.lifetime',
      });
      if (response.error != null) {
        logger.output(response.error.toString());
      } else {
        products = response.productDetails;
      }
      if (products.isEmpty) {
        onMessage?.call(l10n.productNotAvailable);
        return;
      }
    }

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: products[0],
      );

      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onMessage?.call(l10n.iapNotAvailable);
      logger.output('buy product failed $e');
    }
  }

  Future<void> restorePurchases() async {
    foundAnyRestored = false;
    onMessage?.call(l10n.checkingPurchase);
    await _iap.restorePurchases();
    await Future.delayed(const Duration(seconds: 3));
    if (!foundAnyRestored) {
      onMessage?.call(l10n.purchaseNotFound);
    }
  }

  void _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _showPendingUI();
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _handleError(purchaseDetails.error);
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        if (purchaseDetails.status == PurchaseStatus.restored) {
          foundAnyRestored = true;
        }
        _grantAppFeatures(purchaseDetails.productID);
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void _grantAppFeatures(String productId) async {
    await config.savePremium();
    isPremiumNotifier.value = true;
    trialRemainingMinNotifier.value = -1;
  }

  void _showPendingUI() => onMessage?.call(l10n.pendingPurchase);

  void _handleError(IAPError? error) =>
      logger.output('Purchase error: ${error?.message}');
}
