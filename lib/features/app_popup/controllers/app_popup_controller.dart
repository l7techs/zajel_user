import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/models/module_model.dart';
import 'package:sixam_mart/features/app_popup/domain/models/app_popup_model.dart';
import 'package:sixam_mart/features/app_popup/domain/services/app_popup_service_interface.dart';
import 'package:sixam_mart/features/app_popup/widgets/app_popup_dialog_widget.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/language/controllers/language_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/store/screens/store_screen.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/date_converter.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';

/// Shows the admin's app-open popup once per app launch (from the dashboard opened by the splash screen).
class AppPopupController extends GetxController implements GetxService {
  final AppPopupServiceInterface appPopupServiceInterface;
  AppPopupController({required this.appPopupServiceInterface});

  bool _checkedThisLaunch = false;

  static const Duration _minDelay = Duration(seconds: 2);
  // The guest login suggestion opens 3 s after the dashboard; let it go first.
  static const Duration _minDelayWithLoginSuggestion = Duration(milliseconds: 3600);
  static const Duration _giveUpAfter = Duration(seconds: 20);
  static const Duration _imageTimeout = Duration(seconds: 8);

  /// [isScreenFree] is true while the dashboard is the top route (no dialog, sheet or page above it).
  Future<void> showPopupIfNeeded({required bool Function() isScreenFree}) async {
    if (_checkedThisLaunch) {
      return;
    }
    _checkedThisLaunch = true;
    final DateTime startedAt = DateTime.now();

    AppPopupModel? popup = await appPopupServiceInterface.getPopup();
    String today = DateConverter.dateToDate(DateTime.now());
    if (popup == null || !appPopupServiceInterface.shouldShow(popup, today)) {
      return;
    }

    String? imageUrl = popup.imageFor(Get.find<LocalizationController>().locale.languageCode);
    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }
    // Never show a half-loaded popup: skip this launch if the image doesn't load in time.
    double? aspectRatio = await _loadImage(imageUrl);
    if (aspectRatio == null || !await _waitForFreeScreen(startedAt, isScreenFree)) {
      return;
    }

    appPopupServiceInterface.markShown(popup.id!, today);
    appPopupServiceInterface.sendView(popup.id!);
    Get.dialog(
      AppPopupDialogWidget(popup: popup, imageUrl: imageUrl, aspectRatio: aspectRatio),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
    );
  }

  /// Downloads the image into the cache and returns its width / height.
  Future<double?> _loadImage(String imageUrl) async {
    final Completer<double?> completer = Completer<double?>();
    final ImageStream stream = CachedNetworkImageProvider(_cacheUrl(imageUrl)).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      if (!completer.isCompleted && info.image.height > 0) {
        completer.complete(info.image.width / info.image.height);
      }
      stream.removeListener(listener);
    }, onError: (Object error, StackTrace? stackTrace) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    return completer.future.timeout(_imageTimeout, onTimeout: () {
      stream.removeListener(listener);
      return null;
    });
  }

  /// Same URL CustomImage loads (web goes through the backend's image proxy).
  String _cacheUrl(String imageUrl) => kIsWeb ? '${AppConstants.baseUrl}/image-proxy?url=$imageUrl' : imageUrl;

  Future<bool> _waitForFreeScreen(DateTime startedAt, bool Function() isScreenFree) async {
    bool loginSuggestionPending = !AuthHelper.isLoggedIn() && Get.find<SplashController>().showLoginSuggestion()
        && (GetPlatform.isAndroid || GetPlatform.isIOS);
    Duration minDelay = loginSuggestionPending ? _minDelayWithLoginSuggestion : _minDelay;
    int freeChecks = 0;
    while (DateTime.now().difference(startedAt) < _giveUpAfter) {
      bool free = DateTime.now().difference(startedAt) >= minDelay && isScreenFree();
      freeChecks = free ? freeChecks + 1 : 0;
      // Free on two checks in a row, so a sheet that is just opening isn't covered.
      if (freeChecks >= 2) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  /// Called after the dialog has closed itself.
  Future<void> onPopupTap(AppPopupModel popup) async {
    if (!popup.hasLink) {
      return;
    }
    appPopupServiceInterface.sendTap(popup.id!);

    int? moduleId = popup.store?.moduleId ?? popup.item?.moduleId;
    if (!await _switchToModule(moduleId)) {
      return;
    }
    if (popup.store != null) {
      Get.toNamed(
        RouteHelper.getStoreRoute(id: popup.store!.id, page: 'banner', slug: popup.store!.slug ?? ''),
        arguments: StoreScreen(store: popup.store, fromModule: false),
      );
    } else if (popup.item != null && Get.context != null) {
      Get.find<ItemController>().navigateToItemPage(popup.item, Get.context!);
    }
  }

  /// Opens the target's business module first (as picking it on the home screen would), so the store / item
  /// and the home behind it belong to the same module. False when that module isn't available here.
  Future<bool> _switchToModule(int? moduleId) async {
    SplashController splashController = Get.find<SplashController>();
    if (moduleId == null || splashController.module?.id == moduleId) {
      return true;
    }
    if (splashController.configModel?.module != null) {
      // Single-module setup: there is nothing to switch to.
      return splashController.configModel!.module!.id == moduleId;
    }
    if (splashController.moduleList == null) {
      await splashController.getModules();
    }
    List<ModuleModel> modules = splashController.moduleList ?? [];
    int index = modules.indexWhere((module) => module.id == moduleId);
    if (index == -1) {
      return false;
    }
    splashController.switchModule(index, true);
    return true;
  }
}
