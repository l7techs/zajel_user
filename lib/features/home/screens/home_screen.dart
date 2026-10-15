import 'package:get/get.dart';
import 'package:sixam_mart/features/address/controllers/address_controller.dart';
import 'package:sixam_mart/features/banner/controllers/banner_controller.dart';
import 'package:sixam_mart/features/brands/controllers/brands_controller.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/features/coupon/controllers/coupon_controller.dart';
import 'package:sixam_mart/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:sixam_mart/features/home/controllers/advertisement_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_section_status_controller.dart'; // CUSTOM: failure policy
import 'package:sixam_mart/features/item/controllers/campaign_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/parcel/controllers/parcel_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/reels/controllers/reels_controller.dart';
import 'package:sixam_mart/features/rental_module/home/controllers/taxi_home_controller.dart';
import 'package:sixam_mart/features/rental_module/rental_cart_screen/controllers/taxi_cart_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';
class HomeScreen {
  // CUSTOM: silent = background refresh after an instant module switch (ModuleStateCache) — keeps the paginated all-stores list
  // CUSTOM-START: loadData is triggered from ~15 places (splash prefetch, MainScreen, module/address/language change, cart, ModuleStateCache…).
  // A second call with the same arguments while the first is still running gets the same future instead of starting another wave of requests.
  static final Map<String, Future<void>> _loadsInFlight = {};

  static Future<void> loadData(bool reload, {bool fromModule = false, bool silent = false}) {
    final String key = '$reload|$fromModule|$silent|${Get.find<SplashController>().module?.id}';
    final Future<void>? running = _loadsInFlight[key];
    if(AppConstants.requestDedupe && running != null) {
      return running;
    }
    final Future<void> future = _loadData(reload, fromModule: fromModule, silent: silent);
    _loadsInFlight[key] = future;
    future.whenComplete(() => _loadsInFlight.remove(key)).ignore();
    return future;
  }
  // CUSTOM-END

  static Future<void> _loadData(bool reload, {bool fromModule = false, bool silent = false}) async {
    print('===== Home Screen Load Data =====');
    if(Get.isRegistered<HomeSectionStatusController>()) Get.find<HomeSectionStatusController>().reset(); // CUSTOM: failure policy
    Get.find<LocationController>().syncZoneData();
    Get.find<FlashSaleController>().setEmptyFlashSale(fromModule: fromModule);

    if(Get.find<SplashController>().module != null
        && Get.find<SplashController>().module!.moduleType.toString() != AppConstants.ride
        && !Get.find<SplashController>().configModel!.moduleConfig!.module!.isParcel!
        && !Get.find<SplashController>().configModel!.moduleConfig!.module!.isTaxi!) {

      // CUSTOM-START: lazy home sections (docs/plan-lazy-home-sections.md). Tier 1 = what the module home shows first; tier 2 =
      // the rest, requested on the first scroll or [AppConstants.homeTier2Delay] after tier 1 has arrived, whichever is first.
      // On the phone the lists only the web home uses are not requested at all. Web, or lazyHomeSections = false: everything at once.
      final String moduleType = Get.find<SplashController>().module!.moduleType.toString();
      final bool lazy = AppConstants.lazyHomeSections && !GetPlatform.isWeb;
      final bool repeatOrder = AuthHelper.isLoggedIn() && Get.find<SplashController>().configModel!.repeatOrderOption == 1;
      final List<Future<void>> tier1 = [];

      tier1.add(Get.find<CategoryController>().getCategoryList(reload));
      tier1.add(Get.find<BannerController>().getBannerList(reload));
      if(moduleType == AppConstants.grocery || moduleType == AppConstants.ecommerce) {
        tier1.add(Get.find<FlashSaleController>().getFlashSale(reload, false));
      }
      if(moduleType == AppConstants.grocery) {
        tier1.add(Get.find<ItemController>().getDiscountedItemList(offset: '1', firstTimeCategoryLoad: true)); // "today's deals"
      }
      if(moduleType == AppConstants.food) {
        tier1.add(Get.find<AdvertisementController>().getAdvertisementList());
        tier1.add(Get.find<StoreController>().getRecommendedStoreList());
      }
      if(moduleType == AppConstants.pharmacy) {
        tier1.add(Get.find<ItemController>().getCommonConditions(false));
        if(repeatOrder) {
          tier1.add(Get.find<StoreController>().getVisitAgainStoreList(fromModule: fromModule));
        }
      }

      final int visit = ++_homeVisit;
      _tier2ModuleId = Get.find<SplashController>().module!.id;
      _tier2Started = false;
      _tier2 = () => _loadBelowTheFold(reload: reload, fromModule: fromModule, silent: silent, moduleType: moduleType,
        repeatOrder: repeatOrder, everything: !lazy);
      // Silent = background refresh of a restored module (ModuleStateCache re-applies its snapshot right after this call to
      // undo the list clears, so tier 2 must start now, inside the same call) — no lazy split there.
      if(!lazy || _refreshing || silent) {
        requestBelowTheFold();
      } else {
        Future.any([Future.wait(tier1), Future.delayed(const Duration(seconds: 8))])
            .then((_) => Future.delayed(AppConstants.homeTier2Delay))
            .then((_) { if(visit == _homeVisit) requestBelowTheFold(); });
      }
      // CUSTOM-END
    }
    if(AuthHelper.isLoggedIn()) {
      await Get.find<ProfileController>().getUserInfo();
      Get.find<NotificationController>().getNotificationList(reload);
      if(Get.find<SplashController>().configModel!.repeatOrderOption == 1) {
        Get.find<OrderController>().getLastOrders(reload: reload, isHome: true);
        // Also refresh the module-scoped list (LastOrdersSectionWidget reads this
        // when a module screen passes moduleType) — module screens only fetch it
        // once in initState, so without this it stays stale after placing an
        // order and simply popping back instead of switching modules.
        Get.find<OrderController>().getLastOrders(reload: reload, isHome: false);
      }
      if(!Get.find<SplashController>().configModel!.moduleConfig!.module!.isRide!) {
        Get.find<CouponController>().getCouponList();
      }
    }
    Get.find<SplashController>().getModules();
    if(Get.find<SplashController>().module == null && Get.find<SplashController>().configModel!.module == null) {
      Get.find<BannerController>().getFeaturedBanner();
      Get.find<StoreController>().getFeaturedStoreList();
      if(AuthHelper.isLoggedIn()) {
        Get.find<AddressController>().getAddressList();
      }
    }
    if(Get.find<SplashController>().module != null && Get.find<SplashController>().configModel!.moduleConfig!.module!.isParcel!) {
      Get.find<ParcelController>().getParcelCategoryList();
    }
    // CUSTOM: the pharmacy-only loads moved into the tiers above (common conditions = tier 1; basic medicine, featured + verified stores = tier 2)
  }

  // CUSTOM-START: lazy home sections — tier 2 (see loadData)
  static int _homeVisit = 0;
  static int? _tier2ModuleId;
  static bool _tier2Started = true;
  static void Function()? _tier2;
  static bool _refreshing = false;

  /// Pull-to-refresh: load both tiers at once.
  static Future<void> refreshAll() async {
    _refreshing = true;
    try {
      await loadData(true, fromModule: true);
    } finally {
      _refreshing = false;
    }
  }

  /// Starts tier 2 of the current module home once (first scroll, the timer, or refresh). No-op if already started
  /// or if the user is now on another module than the one tier 1 was loaded for.
  static void requestBelowTheFold() {
    if(_tier2Started || _tier2 == null || Get.find<SplashController>().module?.id != _tier2ModuleId) {
      return;
    }
    _tier2Started = true;
    _tier2!();
  }

  static void _loadBelowTheFold({required bool reload, required bool fromModule, required bool silent, required String moduleType,
    required bool repeatOrder, required bool everything}) {
    final ItemController itemController = Get.find<ItemController>();
    final StoreController storeController = Get.find<StoreController>();
    if(repeatOrder && moduleType != AppConstants.pharmacy) {
      storeController.getVisitAgainStoreList(fromModule: fromModule);
    }
    if(moduleType != AppConstants.food) {
      Get.find<AdvertisementController>().getAdvertisementList();
      storeController.getRecommendedStoreList();
    }
    if(moduleType == AppConstants.grocery || moduleType == AppConstants.ecommerce) {
      Get.find<BrandsController>().getBrandList();
    }
    Get.find<CampaignController>().getItemCampaignList(reload);
    if(moduleType != AppConstants.grocery) {
      itemController.getDiscountedItemList(offset: '1', firstTimeCategoryLoad: true);
    }
    itemController.getPopularItemList(offset: '1', firstTimeCategoryLoad: true);
    storeController.getTopOfferStoreList(reload, false);
    storeController.getLatestStoreList(reload, 'all', false);
    if(moduleType == AppConstants.food || moduleType == AppConstants.grocery || moduleType == AppConstants.pharmacy) {
      storeController.getQuickDeliveryStoreList(reload: reload);
    }
    if(moduleType == AppConstants.pharmacy) {
      itemController.getBasicMedicine(reload, false);
      storeController.getFeaturedStoreList();
      storeController.getVerifiedStoreList(reload: reload, notify: false);
    }
    Get.find<ReelsController>().getReelsList(offset: 1);
    if(!silent || storeController.storeModel == null) { // keep scrolled-in store pages on a silent refresh
      storeController.getStoreList(1, reload);
    }
    if(everything) {
      // Only the web home (and old, unused 6amMart widgets) show these — the phone module homes don't.
      Get.find<BannerController>().getPromotionalBannerList(reload);
      Get.find<CampaignController>().getBasicCampaignList(reload);
      storeController.getPopularStoreList(reload, 'all', false);
      itemController.getReviewedItemList(offset: '1', firstTimeCategoryLoad: true);
      itemController.getRecommendedItemList(reload, 'all', false);
      if(moduleType == AppConstants.ecommerce) {
        itemController.getFeaturedCategoriesItemList(false, false);
      }
    }
  }
  // CUSTOM-END

  static Future<void> loadTaxiApis() async {
    await Get.find<TaxiHomeController>().getTaxiBannerList(true);
    await Get.find<TaxiHomeController>().getTopRatedCarList(1, true);
    if (AuthHelper.isLoggedIn()) {
      await Get.find<AddressController>().getAddressList();
      await Get.find<TaxiHomeController>().getTaxiCouponList(true);
      await Get.find<TaxiCartController>().getCarCartList();
    }
  }
}