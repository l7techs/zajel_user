import 'package:flutter/material.dart';
import 'package:sixam_mart/features/home/widgets/home_section_sliver.dart'; // CUSTOM: failure policy
import 'package:get/get.dart';
import 'package:sixam_mart/features/banner/controllers/banner_controller.dart';
import 'package:sixam_mart/features/brands/controllers/brands_controller.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/features/flash_sale/controllers/flash_sale_controller.dart';
import 'package:sixam_mart/features/home/controllers/advertisement_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/reels/controllers/reels_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/dashboard/widgets/category_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/explore_restaurant_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/banner_slider.dart';
import 'package:sixam_mart/features/dashboard/widgets/featured_restaurant.dart';
import 'package:sixam_mart/features/dashboard/widgets/items_you_will_love_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/just_for_you_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/last_orders_section_widget.dart';
import 'package:sixam_mart/features/dashboard/widgets/last_visited_store_section.dart';
import 'package:sixam_mart/common/widgets/title_widget.dart';
import 'package:sixam_mart/features/dashboard/widgets/top_picks_near_you_widget.dart';
import 'package:sixam_mart/features/dashboard/widgets/trending_dishes_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/search_header_widget.dart';
import 'package:sixam_mart/features/dashboard/widgets/sliver_gap.dart';
import 'package:sixam_mart/features/brands/widgets/brand_section_widget.dart';
import 'package:sixam_mart/features/dashboard/modules/shop/widgets/shop_flash_sale_header_widget.dart';
import 'package:sixam_mart/features/dashboard/modules/shop/widgets/shop_upto_offer.dart';
import 'package:sixam_mart/features/reels/widgets/reels_section_widget.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/features/home/widgets/views/promotional_banner_view.dart';
import 'package:sliver_tools/sliver_tools.dart';

class ShopModuleScreen extends StatefulWidget {
  final Key searchHeaderKey;
  final Key exploreRestaurantKey;
  final ScrollController scrollController;
  final bool isSearchPinned;
  const ShopModuleScreen({super.key, required this.searchHeaderKey, required this.exploreRestaurantKey, required this.scrollController, this.isSearchPinned = false});

  @override
  State<ShopModuleScreen> createState() => _ShopModuleScreenState();
}

class _ShopModuleScreenState extends State<ShopModuleScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      Get.find<OrderController>().getLastOrders(isHome: false);
      Get.find<HomeController>().getTopOffer(notify: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiSliver(children: [
      // Section: search and quick filters
      SliverToBoxAdapter(
        child: Visibility(
          visible: !widget.isSearchPinned,
          maintainSize: true, maintainState: true, maintainAnimation: true,
          child: SearchAndQuickFilterWidget(key: widget.searchHeaderKey, isPinned: false),
        ),
      ),

      // banner — leading gap collapses with it
      GetBuilder<BannerController>(builder: (controller) {
        final visible = controller.bannerImageList == null || controller.bannerImageList!.isNotEmpty;
        return _conditionalSection(failureKey: 'banners', visible: visible, slivers: [ // CUSTOM: failure policy
          sliverGepY(value: Dimensions.paddingSizeDefault),
          const SliverToBoxAdapter(child: BannerSliderWidget()),
        ]);
      }),

      // category (title + grid) — whole block collapses when empty
      GetBuilder<CategoryController>(builder: (controller) {
        final visible = controller.categoryList == null || controller.categoryList!.isNotEmpty;
        return _conditionalSection(failureKey: 'categories', visible: visible, slivers: [ // CUSTOM: failure policy
          sliverGepY(value: Dimensions.paddingSizeDefault),
          sliverPadX(child: TitleWidget(title: 'find_your_flavor'.tr)),
          sliverGepY(value: Dimensions.paddingSizeExtraLarge),
          const SliverToBoxAdapter(child: CategorySection(asList: true)),
        ]);
      }),

      // top offer promo card — has no loading shimmer, so show only when a valid offer exists
      GetBuilder<HomeController>(builder: (controller) {
        final topOffer = controller.topOffer;
        final visible = topOffer != null && topOffer.discount != null && topOffer.discount! > 0;
        return _conditionalSection(visible: visible, slivers: [
          sliverGepY(value: Dimensions.paddingSizeDefault),
          sliverPadX(child: const ShopUpToOffer(variant: TopOfferVariant.shop)),
        ]);
      }),

      // Section: flash sale
      GetBuilder<FlashSaleController>(builder: (controller) {
        // CUSTOM: hidden while loading (was "== null ||") — its loading state flashed a grid of blue lightning bolts
        // (flash_sell_bg.png) on every module switch, then vanished when there was no active sale
        final visible = controller.flashSaleModel?.activeProducts?.isNotEmpty ?? false;
        return _conditionalSection(failureKey: 'flash_sale', visible: visible, slivers: [ // CUSTOM: failure policy
          sliverGepY(value: Dimensions.paddingSizeLarge),
          const SliverToBoxAdapter(child: ShopFlashSaleHeaderWidget()),
        ]);
      }),

      // reels
      GetBuilder<ReelsController>(builder: (controller) {
        final visible = (controller.reelsList == null && controller.isLoading)
            || (controller.reelsList != null && controller.reelsList!.isNotEmpty);
        return _conditionalSection(failureKey: 'reels', visible: visible, slivers: [ // CUSTOM: failure policy
          const SliverToBoxAdapter(child: ReelsSectionWidget()),
        ]);
      }),

      // Section: just for you (self-collapses when there are no campaigns)
      sliverGepY(value: Dimensions.paddingSizeDefault),
      const HomeSectionSliver(sectionKey: 'item_campaigns', visible: true, slivers: [SliverToBoxAdapter(child: JustForYouSection())]), // CUSTOM: failure policy

      // Section: last orders — section + leading gap collapse when there are no last orders
      GetBuilder<OrderController>(builder: (controller) {
        final visible = controller.lastOrders?.isNotEmpty ?? false;
        return _conditionalSection(visible: visible, slivers: [
          sliverGepY(value: Dimensions.paddingSizeDefault),
          const SliverToBoxAdapter(child: LastOrdersSectionWidget(moduleType: AppConstants.grocery)),
        ]);
      }),

      // Section: last visited store (self-collapses when there is nothing to show)
      sliverGepY(value: Dimensions.paddingSizeDefault),
      const HomeSectionSliver(sectionKey: 'visit_again', visible: true, slivers: [SliverToBoxAdapter(child: LastVisitedStoreSection())]), // CUSTOM: failure policy

      // top brands
      GetBuilder<BrandsController>(builder: (controller) {
        final visible = controller.brandList == null || controller.brandList!.isNotEmpty;
        return _conditionalSection(failureKey: 'brands', visible: visible, slivers: [ // CUSTOM: failure policy
          sliverGepY(value: Dimensions.paddingSizeSmall),
          SliverToBoxAdapter(child: BrandSectionWidget(title: "top_brands".tr, showLabel: true, showItemCount: true)),
          sliverGepY(value: Dimensions.paddingSizeLarge),
        ]);
      }),

      // Section: featured stores list
      GetBuilder<AdvertisementController>(builder: (controller) {
        final visible = controller.advertisementList == null || controller.advertisementList!.isNotEmpty;
        return _conditionalSection(failureKey: 'advertisements', visible: visible, slivers: [ // CUSTOM: failure policy
          sliverGepY(value: Dimensions.paddingSizeExtraSmall),
        ]);
      }),

      sliverPadX(child: const FeaturedRestaurant(isShop: true)),
      // SliverToBoxAdapter(child: Container(
      //   height: 5, width: double.infinity, color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
      // )),

      // Section: Recommended For You
      GetBuilder<StoreController>(builder: (controller) {
        final visible = controller.recommendedStoreList == null || controller.recommendedStoreList!.isNotEmpty;
        return _conditionalSection(failureKey: 'recommended_stores', visible: visible, slivers: [ // CUSTOM: failure policy
          sliverGepY(value: Dimensions.paddingSizeLarge),
          SliverToBoxAdapter(
            child: TopPicksNearYouWidget(title: "recommended_for_you".tr, isRecommended: true,),
          ),
        ]);
      }),

      // Section: trending dishes
      GetBuilder<ItemController>(builder: (controller) {
        final visible = controller.discountedItemList == null || controller.discountedItemList!.isNotEmpty;
        return _conditionalSection(failureKey: 'discounted_items', visible: visible, slivers: [ // CUSTOM: failure policy
          SliverToBoxAdapter(child: TrendingDishesSectionWidget(title: "trending_item".tr)),
        ]);
      }),

      // Section: items you will love
      GetBuilder<ItemController>(builder: (controller) {
        final visible = controller.popularItemList == null || controller.popularItemList!.isNotEmpty;
        return _conditionalSection(failureKey: 'popular_items', visible: visible, slivers: [ // CUSTOM: failure policy
          sliverGepY(value: Dimensions.paddingSizeDefault),
          SliverToBoxAdapter(child: ItemsYouWillLoveSectionWidget(title: 'items_you_will_love'.tr,)),
        ]);
      }),

      const PromotionalBannerSliver(),
      sliverGepY(value: Dimensions.paddingSizeDefault),

      SliverToBoxAdapter(child: Container(
        height: 5, width: double.infinity, color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
      )),
      sliverGepY(value: Dimensions.paddingSizeDefault),

      HomeSectionSliver(sectionKey: 'all_stores', visible: true, slivers: [ExploreRestaurantSection(title: 'explore_shop'.tr, exploreRestaurantKey: widget.exploreRestaurantKey, scrollController: widget.scrollController)]), // CUSTOM: failure policy

    ]
    );
  }
}

// Renders a section together with its leading/trailing spacing, or nothing at
// all — dropping the gap — when the section has loaded but is empty. Always
// returns exactly one sliver so it stays valid inside the parent MultiSliver.
// CUSTOM: failureKey -> HomeSectionSliver (retry box when the section's request failed, docs/plan-home-section-failures.md)
Widget _conditionalSection({required bool visible, required List<Widget> slivers, String? failureKey}) {
  if (failureKey != null) {
    return HomeSectionSliver(sectionKey: failureKey, visible: visible, slivers: slivers);
  }
  return visible
      ? MultiSliver(children: slivers)
      : const SliverToBoxAdapter(child: SizedBox.shrink());
}
