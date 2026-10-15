import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/banner/controllers/banner_controller.dart';
import 'package:sixam_mart/features/brands/controllers/brands_controller.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:sixam_mart/features/home/controllers/advertisement_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/home/screens/home_screen.dart';
import 'package:sixam_mart/features/item/controllers/campaign_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/language/controllers/language_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/reels/controllers/reels_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';

/// CUSTOM: instant module switching.
///
/// The home-screen controllers are shared by every module, so 6amMart throws the old module's data away on
/// each switch and reloads it. This keeps an in-memory snapshot of each visited module's home data
/// (+ scroll offset): leaving a module saves it, coming back restores it before the screen changes, then
/// [refreshIfStale] refreshes quietly in the background without clearing anything.
///
/// Snapshots belong to one zone + language + user; when any of those change they are all dropped
/// (checked on every save/restore, so address/language/login flows need no hooks).
class ModuleStateCache {
  ModuleStateCache._();

  /// A restored module is refreshed in the background only if its data is older than this.
  static const Duration _freshFor = Duration(seconds: 60);

  static final Map<int, _ModuleSnapshot> _snapshots = {};
  static final Map<int, DateTime> _refreshedAt = {};
  static String? _contextKey;

  /// The home page's scroll controller (registered by MainScreen) — used to keep each module's scroll position.
  static ScrollController? scrollController;

  /// Module types whose home screen is built from the controllers snapshotted here.
  static bool isCacheable(String? moduleType) => [
    AppConstants.grocery, AppConstants.food, AppConstants.pharmacy, AppConstants.ecommerce,
  ].contains(moduleType);

  /// Saves the current home data as [moduleId]'s snapshot. Call while that module is still the active one.
  static void save(int moduleId) {
    _checkContext();
    // Left before its first load finished: the controllers may still hold the previous module's data — don't keep it.
    if(Get.find<CategoryController>().categoryList == null) {
      _snapshots.remove(moduleId);
      return;
    }
    final ScrollController? sc = scrollController;
    _snapshots[moduleId] = _ModuleSnapshot(
      state: _capture(),
      scrollOffset: (sc != null && sc.hasClients) ? sc.offset : 0,
    );
  }

  /// Puts [moduleId]'s snapshot back into the controllers. Returns false if there is none (first visit,
  /// or dropped because zone/language/user changed) — the caller then loads the module the normal way.
  static bool restore(int moduleId) {
    _checkContext();
    final _ModuleSnapshot? snapshot = _snapshots[moduleId];
    if(snapshot == null) return false;
    _apply(snapshot.state);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ScrollController? sc = scrollController;
      if(sc != null && sc.hasClients) {
        sc.jumpTo(snapshot.scrollOffset.clamp(0.0, sc.position.maxScrollExtent));
      }
    });
    return true;
  }

  /// Marks [moduleId] as just loaded from the server (a full load, or a background refresh).
  static void markRefreshed(int moduleId) => _refreshedAt[moduleId] = DateTime.now();

  /// After a restore: reloads the module in the background unless it was refreshed in the last [_freshFor].
  /// Uses 6amMart's own HomeScreen.loadData, which clears every list synchronously before its first await;
  /// re-applying the state right after the call undoes that clear in the same frame, so the screen never
  /// shows a shimmer and each list is swapped in place when its fresh data arrives.
  static void refreshIfStale(int moduleId) {
    final DateTime? last = _refreshedAt[moduleId];
    final bool incomplete = Get.find<CategoryController>().categoryList == null || Get.find<BannerController>().bannerImageList == null
        || (AppConstants.lazyHomeSections && Get.find<StoreController>().storeModel == null); // CUSTOM: left before the lazy tier 2 ran -> load it now
    if(!incomplete && last != null && DateTime.now().difference(last) < _freshFor) return;

    final Map<String, Map<String, dynamic>> state = _capture();
    HomeScreen.loadData(true, fromModule: true, silent: true);
    _apply(state);
    markRefreshed(moduleId);
  }

  static void clear() {
    _snapshots.clear();
    _refreshedAt.clear();
  }

  static void _checkContext() {
    final String key = currentContextKey();
    if(_contextKey != key) {
      clear();
      _contextKey = key;
    }
  }

  /// Zone + language + user/guest — data cached for one of these must not be shown for another (also used by OfferController).
  static String currentContextKey() {
    final String zone = AddressHelper.getUserAddressFromSharedPref()?.zoneIds?.join(',') ?? '';
    final String language = Get.find<LocalizationController>().locale.languageCode;
    final String user = AuthHelper.isLoggedIn()
        ? 'u${Get.find<AuthController>().getUserToken().hashCode}'
        : (AuthHelper.isGuestLoggedIn() ? 'g${AuthHelper.getGuestId()}' : '-');
    return '$zone|$language|$user';
  }

  static Map<String, Map<String, dynamic>> _capture() => {
    'category': Get.find<CategoryController>().exportModuleState(),
    'banner': Get.find<BannerController>().exportModuleState(),
    'item': Get.find<ItemController>().exportModuleState(),
    'campaign': Get.find<CampaignController>().exportModuleState(),
    'flashSale': Get.find<FlashSaleController>().exportModuleState(),
    'store': Get.find<StoreController>().exportModuleState(),
    'brands': Get.find<BrandsController>().exportModuleState(),
    'advertisement': Get.find<AdvertisementController>().exportModuleState(),
    'reels': Get.find<ReelsController>().exportModuleState(),
    'order': Get.find<OrderController>().exportModuleState(),
    'home': Get.find<HomeController>().exportModuleState(),
  };

  static void _apply(Map<String, Map<String, dynamic>> state) {
    Get.find<CategoryController>().importModuleState(state['category']!);
    Get.find<BannerController>().importModuleState(state['banner']!);
    Get.find<ItemController>().importModuleState(state['item']!);
    Get.find<CampaignController>().importModuleState(state['campaign']!);
    Get.find<FlashSaleController>().importModuleState(state['flashSale']!);
    Get.find<StoreController>().importModuleState(state['store']!);
    Get.find<BrandsController>().importModuleState(state['brands']!);
    Get.find<AdvertisementController>().importModuleState(state['advertisement']!);
    Get.find<ReelsController>().importModuleState(state['reels']!);
    Get.find<OrderController>().importModuleState(state['order']!);
    Get.find<HomeController>().importModuleState(state['home']!);
  }
}

class _ModuleSnapshot {
  final Map<String, Map<String, dynamic>> state;
  final double scrollOffset;
  const _ModuleSnapshot({required this.state, required this.scrollOffset});
}
