import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/features/banner/controllers/banner_controller.dart';
import 'package:sixam_mart/features/brands/controllers/brands_controller.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:sixam_mart/features/home/controllers/advertisement_controller.dart';
import 'package:sixam_mart/features/item/controllers/campaign_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/reels/controllers/reels_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';

enum HomeSectionState { ok, retrying, failed }

/// CUSTOM: per-section failure policy on the module homes (docs/plan-home-section-failures.md).
///
/// `ApiClient` reports the result of every home-section request here. A section whose request fails while it has no
/// data yet (its list is still null) is retried once after [AppConstants.homeSectionRetryDelay]; if that fails too it
/// becomes [HomeSectionState.failed] and the module screen shows a retry box instead of an endless shimmer. A section
/// that already shows data (saved copy or an earlier load) is never marked failed. One summary message per home load
/// replaces the per-request error popups; when categories and banners both fail the page shows one screen message.
class HomeSectionStatusController extends GetxController implements GetxService {
  /// Test seams: defaults read the real controllers / show the real snackbar.
  final bool Function(String section)? hasDataOverride;
  final void Function(String section)? reloadOverride;
  final void Function()? summaryOverride;
  final Duration retryDelay;
  HomeSectionStatusController({this.hasDataOverride, this.reloadOverride, this.summaryOverride, this.retryDelay = AppConstants.homeSectionRetryDelay});

  final Map<String, HomeSectionState> _states = {};
  final Set<String> _retryInFlight = {};
  bool _summaryShown = false;

  /// Request path -> section key. A path is only a home section when it matches exactly (query ignored).
  static const Map<String, String> _sectionByPath = {
    '/api/v1/categories': 'categories',
    '/api/v1/banners': 'banners',
    '/api/v1/flash-sales': 'flash_sale',
    '/api/v1/advertisement/list': 'advertisements',
    '/api/v1/stores/recommended': 'recommended_stores',
    '/api/v1/campaigns/item': 'item_campaigns',
    '/api/v1/items/discounted': 'discounted_items',
    '/api/v1/items/popular': 'popular_items',
    '/api/v1/stores/top-offer-near-me': 'top_offer_stores',
    '/api/v1/stores/latest': 'latest_stores',
    '/api/v1/stores/quick-delivery': 'quick_delivery',
    '/api/v1/customer/visit-again': 'visit_again',
    '/api/v1/brand': 'brands',
    '/api/v1/customer/reels/list': 'reels',
    '/api/v1/items/basic': 'basic_medicine',
    '/api/v1/common-condition': 'common_conditions',
    '/api/v1/stores/verified': 'verified_stores',
    '/api/v1/stores/get-stores/all': 'all_stores',
  };

  /// The section a request belongs to, or null. Only while the user is on the main (home) route and only for the
  /// first page — "see all" screens and later pages keep 6amMart's normal error handling.
  static String? sectionForUri(String uri) {
    if (!AppConstants.homeSectionFailurePolicy || !_onHomeRoute) return null;
    final Uri parsed = Uri.parse(uri);
    final String? section = _sectionByPath[parsed.path];
    if (section == null) return null;
    if (parsed.queryParameters['featured'] == '1') return null; // the Home tab's featured stores, not a module section
    final String? offset = parsed.queryParameters['offset'];
    if (offset != null && offset != '1') return null;
    return section;
  }

  static bool get _onHomeRoute {
    final String route = Get.currentRoute;
    return route == RouteHelper.initial || route.startsWith('${RouteHelper.initial}?') || route.startsWith(RouteHelper.main);
  }

  bool isFailed(String key) => _states[key] == HomeSectionState.failed;

  /// No connection at all: neither categories nor banners could be loaded.
  bool get pageFailed => isFailed('categories') && isFailed('banners');

  /// Called at the start of every home load (module open, refresh, module switch).
  void reset() {
    if (_states.isEmpty && !_summaryShown) return;
    _states.clear();
    _retryInFlight.clear();
    _summaryShown = false;
    update();
  }

  /// Result of one request for [section] (from `ApiClient.getData`).
  void report(String section, bool success) {
    if (success) {
      _retryInFlight.remove(section);
      if (_states.remove(section) != null) update();
      return;
    }
    if ((hasDataOverride ?? _hasData)(section)) return; // keep saved data — a failed refresh changes nothing on screen

    final HomeSectionState? state = _states[section];
    if (state == HomeSectionState.failed) return;
    if (state == HomeSectionState.retrying) {
      if (!_retryInFlight.contains(section)) return; // another caller sharing the same failed request
      _retryInFlight.remove(section);
      _states[section] = HomeSectionState.failed;
      update();
      _showSummaryOnce();
      return;
    }
    _states[section] = HomeSectionState.retrying;
    update();
    Future.delayed(retryDelay, () {
      if (_states[section] != HomeSectionState.retrying) return;
      _retryInFlight.add(section);
      (reloadOverride ?? _reload)(section);
    });
  }

  /// Retry button of a failed section.
  void retry(String section) {
    _states[section] = HomeSectionState.retrying;
    _retryInFlight.add(section);
    update();
    (reloadOverride ?? _reload)(section);
  }

  void _showSummaryOnce() {
    if (_summaryShown || pageFailed) return;
    _summaryShown = true;
    if (summaryOverride != null) {
      summaryOverride!();
    } else {
      showCustomSnackBar('some_sections_failed'.tr);
    }
  }

  bool _hasData(String section) {
    switch (section) {
      case 'categories': return Get.find<CategoryController>().categoryList != null;
      case 'banners': return Get.find<BannerController>().bannerImageList != null;
      case 'flash_sale': return Get.find<FlashSaleController>().flashSaleModel != null;
      case 'advertisements': return Get.find<AdvertisementController>().advertisementList != null;
      case 'recommended_stores': return Get.find<StoreController>().recommendedStoreList != null;
      case 'item_campaigns': return Get.find<CampaignController>().itemCampaignList != null;
      case 'discounted_items': return Get.find<ItemController>().discountedItemList != null;
      case 'popular_items': return Get.find<ItemController>().popularItemList != null;
      case 'top_offer_stores': return Get.find<StoreController>().topOfferStoreList != null;
      case 'latest_stores': return Get.find<StoreController>().latestStoreList != null;
      case 'quick_delivery': return Get.find<StoreController>().quickDeliveryStoreList != null;
      case 'visit_again': return Get.find<StoreController>().visitAgainStoreList != null;
      case 'brands': return Get.find<BrandsController>().brandList != null;
      case 'reels': return Get.find<ReelsController>().reelsList != null;
      case 'basic_medicine': return Get.find<ItemController>().basicMedicineModel != null;
      case 'common_conditions': return Get.find<ItemController>().commonConditions != null;
      case 'verified_stores': return Get.find<StoreController>().verifiedStoreList != null;
      case 'all_stores': return Get.find<StoreController>().storeModel != null;
    }
    return false;
  }

  void _reload(String section) {
    switch (section) {
      case 'categories': Get.find<CategoryController>().getCategoryList(true);
      case 'banners': Get.find<BannerController>().getBannerList(true);
      case 'flash_sale': Get.find<FlashSaleController>().getFlashSale(true, true);
      case 'advertisements': Get.find<AdvertisementController>().getAdvertisementList();
      case 'recommended_stores': Get.find<StoreController>().getRecommendedStoreList();
      case 'item_campaigns': Get.find<CampaignController>().getItemCampaignList(true);
      case 'discounted_items': Get.find<ItemController>().getDiscountedItemList(offset: '1', notify: true);
      case 'popular_items': Get.find<ItemController>().getPopularItemList(offset: '1', notify: true);
      case 'top_offer_stores': Get.find<StoreController>().getTopOfferStoreList(true, true);
      case 'latest_stores': Get.find<StoreController>().getLatestStoreList(true, 'all', true);
      case 'quick_delivery': Get.find<StoreController>().getQuickDeliveryStoreList(reload: true);
      case 'visit_again': Get.find<StoreController>().getVisitAgainStoreList();
      case 'brands': Get.find<BrandsController>().getBrandList();
      case 'reels': Get.find<ReelsController>().getReelsList(offset: 1);
      case 'basic_medicine': Get.find<ItemController>().getBasicMedicine(true, true);
      case 'common_conditions': Get.find<ItemController>().getCommonConditions(true);
      case 'verified_stores': Get.find<StoreController>().getVerifiedStoreList(reload: true);
      case 'all_stores': Get.find<StoreController>().getStoreList(1, true);
    }
  }
}
