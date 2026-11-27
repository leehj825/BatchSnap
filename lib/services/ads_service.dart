import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob IDs. Debug builds always use Google's official test ad units, so
/// developers never click or load real ads (an AdMob policy violation).
class AdIds {
  // App ID is configured in AndroidManifest.xml (patched by the CI workflow):
  // ca-app-pub-4400173019354346~5995575350
  static const _banner = 'ca-app-pub-4400173019354346/1602189722';
  static const _rewarded = 'ca-app-pub-4400173019354346/5566978751';

  static const _testBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static String get banner => kDebugMode ? _testBanner : _banner;
  static String get rewarded => kDebugMode ? _testRewarded : _rewarded;
}

class AdsService {
  AdsService._();

  /// True once consent was gathered and the SDK is initialized.
  static final ready = ValueNotifier<bool>(false);

  /// Gathers consent (UMP, required in the EEA/UK) and then initializes the SDK.
  /// Never throws; ads simply stay disabled on failure.
  static Future<void> init() async {
    try {
      final done = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((_) {
            if (!done.isCompleted) done.complete();
          });
        },
        (_) {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
        ready.value = true;
      }
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  /// Loads and shows a rewarded ad. Resolves to true only if the user earned
  /// the reward; false if the ad failed to load/show or was dismissed early.
  static Future<bool> showRewarded() async {
    if (!ready.value) return false;
    final result = Completer<bool>();
    var earned = false;

    await RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!result.isCompleted) result.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              if (!result.isCompleted) result.complete(false);
            },
          );
          ad.show(onUserEarnedReward: (_, __) => earned = true);
        },
        onAdFailedToLoad: (_) {
          if (!result.isCompleted) result.complete(false);
        },
      ),
    );
    return result.future;
  }
}
