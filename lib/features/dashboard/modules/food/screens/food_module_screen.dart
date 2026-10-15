import 'package:flutter/material.dart';
import 'package:sixam_mart/features/home/widgets/home_section_sliver.dart'; // CUSTOM: failure policy
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/title_widget.dart';
import 'package:sixam_mart/features/banner/controllers/banner_controller.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/features/dashboard/modules/shop/widgets/shop_upto_offer.dart';
import 'package:sixam_mart/features/dashboard/widgets/banner_slider.dart';
import 'package:sixam_mart/features/dashboard/widgets/category_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/explore_restaurant_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/featured_restaurant.dart';
import 'package:sixam_mart/features/dashboard/widgets/items_you_will_love_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/just_for_you_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/last_orders_section_widget.dart';
import 'package:sixam_mart/features/dashboard/widgets/last_visited_store_section.dart';
import 'package:sixam_mart/features/dashboard/widgets/search_header_widget.dart';
import 'package:sixam_mart/features/dashboard/widgets/sliver_gap.dart';
import 'package:sixam_mart/features/dashboard/widgets/top_picks_near_you_widget.dart';
import 'package:sixam_mart/features/dashboard/widgets/trending_dishes_section.dart';
import 'package:sixam_mart/features/home/controllers/advertisement_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/item/controllers/item_controller.dart';
import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/reels/controllers/reels_controller.dart';
import 'package:sixam_mart/features/reels/widgets/reels_section_widget.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/features/home/widgets/views/promotional_banner_view.dart';
import 'package:sliver_tools/sliver_tools.dart';

class FoodModuleScreen extends StatefulWidget {
  final Key searchHeaderKey;
  final Key exploreRestaurantKey;
  final ScrollController scrollController;
  final bool isSearchPinned;
  const FoodModuleScreen({super.key, required this.searchHeaderKey, required this.exploreRestaurantKey, required this.scrollController, this.isSearchPinned = false});

  @override
  State<FoodModuleScreen> createState() => _FoodModuleScreenState();
}

class _FoodModuleScreenState extends State<FoodModuleScreen> {

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

      // Find Your Food section — title + category collapse together when empty
      GetBuilder<CategoryController>(builder: (controller) {
        final visible = controller.categoryList == null || controller.categoryList!.isNotEmpty;
        return _conditionalSection(failureKey: 'categories', visible: visible, slivers: [ // CUSTOM: failure policy
          sliverGepY(value: Dimensions.paddingSizeExtraSmall),
          sliverPadX(child: TitleWidget(title: 'find_your_food'.tr)),
          sliverGepY(value: Dimensions.paddingSizeDefault),
          const SliverToBoxAdapter(child: CategorySection(asList: true)),
          sliverGepY(value: Dimensions.paddingSizeLarge),
        ]);
      }),

      // banner
      GetBuilder<BannerController>(builder: (controller) {
        final visible = controller.bannerImageList == null || controller.bannerImageList!.isNotEmpty;
        return _conditionalSection(failureKey: 'banners', visible: visible, slivers: [ // CUSTOM: failure policy
          const SliverToBoxAdapter(child: BannerSliderWidget()),
          sliverGepY(value: Dimensions.paddingSizeDefault),
        ]);
      }),

      // top offer promo card — has no loading shimmer, so show only when a valid offer exists
      GetBuilder<HomeController>(builder: (controller) {
        final topOffer = controller.topOffer;
        final visible = topOffer != null && topOffer.discount != null && topOffer.discount! > 0;
        return _conditionalSection(visible: visible, slivers: [
          sliverPadX(child: const ShopUpToOffer(variant: TopOfferVariant.food)),
          sliverGepY(value: Dimensions.paddingSizeDefault),
        ]);
      }),

      // Section: featured stores list
      GetBuilder<AdvertisementController>(builder: (controller) {
        final visible = controller.advertisementList == null || controller.advertisementList!.isNotEmpty;
        return _conditionalSection(failureKey: 'advertisements', visible: visible, slivers: [ // CUSTOM: failure policy
          sliverPadX(child: const FeaturedRestaurant()),
          sliverGepY(value: Dimensions.paddingSizeDefault),
        ]);
      }),

      // reels
      GetBuilder<ReelsController>(builder: (controller) {
        final visible = (controller.reelsList == null && controller.isLoading)
            || (controller.reelsList != null && controller.reelsList!.isNotEmpty);
        return _conditionalSection(failureKey: 'reels', visible: visible, slivers: [ // CUSTOM: failure policy
          const SliverToBoxAdapter(child: ReelsSectionWidget()),
          sliverGepY(value: Dimensions.paddingSizeDefault),
        ]);
      }),

      // Section: Recommended For You
      GetBuilder<StoreController>(builder: (controller) {
        final visible = controller.recommendedStoreList == null || controller.recommendedStoreList!.isNotEmpty;
        return _conditionalSection(failureKey: 'recommended_stores', visible: visible, slivers: [ // CUSTOM: failure policy
          SliverToBoxAdapter(
            child: TopPicksNearYouWidget(title: "recommended_for_you".tr, isRecommended: true,),
          ),
        ]);
      }),

      // Section: just for you (self-collapses when there are no campaigns)
      const HomeSectionSliver(sectionKey: 'item_campaigns', visible: true, slivers: [SliverToBoxAdapter(child: JustForYouSection())]), // CUSTOM: failure policy
      sliverGepY(value: Dimensions.paddingSizeDefault),

      // Section: quick Delivery
      GetBuilder<StoreController>(builder: (controller) {
        final visible = controller.latestStoreList == null || controller.latestStoreList!.isNotEmpty;
        return _conditionalSection(failureKey: 'latest_stores', visible: visible, slivers: [ // CUSTOM: failure policy
          SliverToBoxAdapter(
            child: TopPicksNearYouWidget(isQuick: true, height: 85, title: "quick_delivery".tr, subTitle: 'get_fastest_order_from_your_nearby_restaurant'.tr,),
          ),
          // sliverGepY(value: Dimensions.paddingSizeDefault),
        ]);
      }),

      // Section: last orders (self-collapses; no trailing gap)
      const SliverToBoxAdapter(child: LastOrdersSectionWidget(moduleType: AppConstants.food, showTitleFirst : true)),

      // Section: last visited store (self-collapses when there is nothing to show)
      const HomeSectionSliver(sectionKey: 'visit_again', visible: true, slivers: [SliverToBoxAdapter(child: LastVisitedStoreSection())]), // CUSTOM: failure policy
      sliverGepY(value: Dimensions.paddingSizeDefault),

      // Section: top picks carousel — divider + gap collapse with it
      GetBuilder<StoreController>(builder: (controller) {
        final visible = controller.topOfferStoreList == null || controller.topOfferStoreList!.isNotEmpty;
        return _conditionalSection(failureKey: 'top_offer_stores', visible: visible, slivers: [ // CUSTOM: failure policy
          SliverToBoxAdapter(
            child: TopPicksNearYouWidget(title: "top_picks_near_you".tr, isNearYou: true),
          ),
          SliverToBoxAdapter(child: Container(
            height: 5, width: double.infinity, color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
          )),
          sliverGepY(value: Dimensions.paddingSizeDefault),
        ]);
      }),

      // Section: Recommended For You (self-collapses; no trailing gap)
      SliverToBoxAdapter(
        child: TopPicksNearYouWidget(title: "recommended_for_you".tr, isRecommended: true),
      ),

      // Section: trending dishes
      GetBuilder<ItemController>(builder: (controller) {
        final visible = controller.discountedItemList == null || controller.discountedItemList!.isNotEmpty;
        return _conditionalSection(failureKey: 'discounted_items', visible: visible, slivers: [ // CUSTOM: failure policy
          SliverToBoxAdapter(child: TrendingDishesSectionWidget(title: "trending_dishes".tr)),
          sliverGepY(value: Dimensions.paddingSizeDefault),
        ]);
      }),

      // Section: items you will love
      GetBuilder<ItemController>(builder: (controller) {
        final visible = controller.popularItemList == null || controller.popularItemList!.isNotEmpty;
        return _conditionalSection(failureKey: 'popular_items', visible: visible, slivers: [ // CUSTOM: failure policy
          SliverToBoxAdapter(child: ItemsYouWillLoveSectionWidget(title: 'items_you_will_love'.tr,)),
          sliverGepY(value: Dimensions.paddingSizeSmall),
        ]);
      }),

      // Section: promotional banner
      const PromotionalBannerSliver(),
      sliverGepY(value: Dimensions.paddingSizeDefault),

      SliverToBoxAdapter(child: Container(
        height: 5, width: double.infinity, color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
      )),
      sliverGepY(value: Dimensions.paddingSizeDefault),

      // Section: explore restaurants
      HomeSectionSliver(sectionKey: 'all_stores', visible: true, slivers: [ExploreRestaurantSection(exploreRestaurantKey: widget.exploreRestaurantKey, scrollController: widget.scrollController,)]), // CUSTOM: failure policy

    ]
    );
  }
}

// Renders a section together with its trailing spacing (gap / divider), or
// nothing at all — dropping the gap — when the section has loaded but is empty.
// Always returns exactly one sliver so it stays valid inside the parent MultiSliver.
// CUSTOM: failureKey -> HomeSectionSliver (retry box when the section's request failed, docs/plan-home-section-failures.md)
Widget _conditionalSection({required bool visible, required List<Widget> slivers, String? failureKey}) {
  if (failureKey != null) {
    return HomeSectionSliver(sectionKey: failureKey, visible: visible, slivers: slivers);
  }
  return visible
      ? MultiSliver(children: slivers)
      : const SliverToBoxAdapter(child: SizedBox.shrink());
}
