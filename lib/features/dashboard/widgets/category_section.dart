
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/features/category/domain/models/category_model.dart';
import 'package:sixam_mart/features/category/widgets/category_image_tile.dart'; // CUSTOM: was custom_image.dart (category image tile)
import 'package:sixam_mart/features/dashboard/widgets/category_widget.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

// CUSTOM-START: category tile size (6amMart: 64) and row cell width (6amMart: 76) — change the size here only
const double _categoryTileSize = 76;
const double _categoryCellWidth = _categoryTileSize + 12;
// CUSTOM-END

// Height of a category cell: the image tile + gap + the two-line label,
// scaled by the device text scale so larger font/accessibility settings don't
// clip the label. Floored at tile + 46 (6amMart: 110 for a 64px circle).
double _categoryCellHeight(BuildContext context) {
  final double textScale = MediaQuery.textScalerOf(context).scale(1.0);
  final double labelHeight = Dimensions.fontSizeSmall * 1.3 * 2 * textScale;
  // CUSTOM: was 64 and a fixed 110 floor; the floor keeps 6amMart's 46px for gap + label (the 1.3 line-height guess is too small)
  return (_categoryTileSize + Dimensions.paddingSizeExtraSmall + labelHeight + 2).clamp(_categoryTileSize + 46, double.infinity).toDouble();
}

class CategorySection extends StatelessWidget {
  final bool asList;
  const CategorySection({super.key, required this.asList});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CategoryController>(builder: (controller) {
      final List<CategoryModel>? list = controller.categoryList;
      if(list == null) {
        return _CategoryShimmer(asList: asList);
      }
      if(list.isEmpty) {
        return const SizedBox.shrink();
      }
      return CategoryGridWidget(
        categories: list, asList: asList,
        onCategoryTap: _navigateToCategory,
      );
    });
  }

  void _navigateToCategory(CategoryModel category) {
    Get.toNamed(RouteHelper.getCategoryItemRoute(
      category.id, category.name ?? '',
      slug: category.slug ?? '',
    ));
  }
}

class CategoryGridWidget extends StatelessWidget {
  final List<CategoryModel> categories;
  final bool asList;
  final void Function(CategoryModel category)? onCategoryTap;
  const CategoryGridWidget({super.key, required this.categories, required this.asList, this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    final bool hasMoreCategories = categories.length > (asList ? 6 : 8);
    return asList ? SizedBox(
      height: _categoryCellHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: Dimensions.paddingSizeDefault, end: Dimensions.paddingSizeExtraSmall), // CUSTOM: RTL — was left/right
        itemBuilder: (context, index) {
          if(hasMoreCategories && index == 6) {
            return _ViewAllCategoryButton(
              onTap:()=>  seeMoreCategoryAction(categories, onCategoryTap: onCategoryTap),
            );
          }

          final CategoryModel category = categories[index];
          return InkWell(
            onTap: onCategoryTap != null ? () => onCategoryTap!(category) : null,
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            child: SizedBox(
              width: _categoryCellWidth, // CUSTOM: was 76
              child: Column(
                children: [
                  CategoryImageTile(image: category.imageFullUrl ?? '', size: _categoryTileSize), // CUSTOM: soft tile instead of circle crop
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text(
                    category.name ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: Dimensions.paddingSizeSmall),
        itemCount: hasMoreCategories ? 6+1 : categories.length,
      ),
    ) : Column(
        children : [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
            itemBuilder: (context, index) {
              if(hasMoreCategories && index == 8) {
                return _ViewAllCategoryButton(
                  onTap: () {
                   seeMoreCategoryAction(categories, onCategoryTap: onCategoryTap);
                  },
                );
              }

              final CategoryModel category = categories[index];
              return InkWell(
                onTap: onCategoryTap != null ? () => onCategoryTap!(category) : null,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                child: Column(
                  children: [
                    CategoryImageTile(image: category.imageFullUrl ?? '', size: _categoryTileSize), // CUSTOM: soft tile instead of circle crop
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    Text(
                      category.name ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall),
                    ),
                  ],
                ),
              );
            },
            itemCount: hasMoreCategories ? 8 : categories.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: Dimensions.paddingSizeExtraSmall,
              crossAxisSpacing: Dimensions.paddingSizeExtraSmall,
              mainAxisExtent: _categoryCellHeight(context),
            ),
          ),
          if(hasMoreCategories) Padding(
            padding: const EdgeInsets.only(top: Dimensions.paddingSizeSmall),
            child: GestureDetector(
              onTap:() => seeMoreCategoryAction(categories, onCategoryTap: onCategoryTap),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("see_more".tr, style: robotoSemiBold.copyWith(color: Colors.blueAccent, fontSize: Dimensions.fontSizeLarge)),
                  const SizedBox(width: Dimensions.paddingSizeExtraSmall,),
                  Icon(Icons.keyboard_arrow_down_outlined, size: Dimensions.fontSizeExtraLarge),
                ],
              ),
            ),
          )
        ]
    );
  }
}

// CUSTOM-START: category shimmer — same padding/gaps as CategoryGridWidget (nothing shifts when the list arrives),
// one shimmer wave over the whole section (6amMart: one per cell), two name bars like a real 2-line name.
class _CategoryShimmer extends StatelessWidget {
  final bool asList;
  const _CategoryShimmer({required this.asList});

  @override
  Widget build(BuildContext context) {
    final Widget section = asList ? SizedBox(
      height: _categoryCellHeight(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(start: Dimensions.paddingSizeDefault, end: Dimensions.paddingSizeExtraSmall), // CUSTOM: RTL — was left/right
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 7,
        separatorBuilder: (context, index) => const SizedBox(width: Dimensions.paddingSizeSmall),
        itemBuilder: (context, index) => const SizedBox(width: _categoryCellWidth, child: _ShimmerCell()),
      ),
    ) : GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
      itemCount: 8,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: Dimensions.paddingSizeExtraSmall,
        crossAxisSpacing: Dimensions.paddingSizeExtraSmall,
        mainAxisExtent: _categoryCellHeight(context),
      ),
      itemBuilder: (context, index) => const _ShimmerCell(),
    );

    return Shimmer(duration: const Duration(seconds: 2), child: section);
  }
}

class _ShimmerCell extends StatelessWidget {
  const _ShimmerCell();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).disabledColor.withValues(alpha: 0.15);
    return Column(children: [
      Container(
        height: _categoryTileSize, width: _categoryTileSize,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Dimensions.radiusDefault)),
      ),
      const SizedBox(height: Dimensions.paddingSizeExtraSmall + 3),
      _ShimmerBar(width: _categoryTileSize * 0.8, color: color),
      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
      _ShimmerBar(width: _categoryTileSize * 0.5, color: color),
    ]);
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  final Color color;
  const _ShimmerBar({required this.width, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8, width: width,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
    );
  }
}
// CUSTOM-END

class _ViewAllCategoryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewAllCategoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _categoryCellWidth, // CUSTOM: was 76
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: _categoryTileSize, // CUSTOM: was 64
              width: _categoryTileSize, // CUSTOM: was 64
              child: Center(
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.blue, size: 22),
                ),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Text(
              'view_all'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Dimensions.fontSizeSmall),
            ),
          ],
        ),
      ),
    );
  }
}


void seeMoreCategoryAction(List<CategoryModel> categories, {void Function(CategoryModel category)? onCategoryTap}) {
  Get.bottomSheet(
    categories.length >= 16
      ? _CategoryDraggableBottomSheet(categories: categories, onCategoryTap: onCategoryTap)
      : _CategoryStaticBottomSheet(categories: categories, onCategoryTap: onCategoryTap),
    isScrollControlled: true,
    useRootNavigator: true,
    ignoreSafeArea: false,
    backgroundColor: Colors.transparent,
  );
}

class _CategoryStaticBottomSheet extends StatelessWidget {
  final List<CategoryModel> categories;
  final void Function(CategoryModel category)? onCategoryTap;
  const _CategoryStaticBottomSheet({required this.categories, this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(Dimensions.radiusDefault), topRight: Radius.circular(Dimensions.radiusDefault),),
      ),
      child: FoodModuleCategoryScreen(
        categories: categories,
        showAsFullPage: false,
        onCategoryTap: onCategoryTap,
      ),
    );
  }
}

class _CategoryDraggableBottomSheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final void Function(CategoryModel category)? onCategoryTap;
  const _CategoryDraggableBottomSheet({required this.categories, this.onCategoryTap});

  @override
  State<_CategoryDraggableBottomSheet> createState() => _CategoryDraggableBottomSheetState();
}

class _CategoryDraggableBottomSheetState extends State<_CategoryDraggableBottomSheet> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final ValueNotifier<bool> _isAtMaxExtent = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_listenSheetExtent);
  }

  void _listenSheetExtent() {
    if(!_sheetController.isAttached) {
      return;
    }

    final bool isAtMaxExtent = _sheetController.size >= 1 - 0.01;
    if(isAtMaxExtent != _isAtMaxExtent.value) {
      _isAtMaxExtent.value = isAtMaxExtent;
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_listenSheetExtent);
    _sheetController.dispose();
    _isAtMaxExtent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 1,
      snap: false,
      builder: (context, scrollController) => ValueListenableBuilder<bool>(
        valueListenable: _isAtMaxExtent,
        builder: (context, isAtMaxExtent, _) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isAtMaxExtent ? 0 : Dimensions.radiusDefault),
              topRight: Radius.circular(isAtMaxExtent ? 0 : Dimensions.radiusDefault),
            ),
          ),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(top: isAtMaxExtent ? MediaQuery.of(context).padding.top : 0),
            child: FoodModuleCategoryScreen(
              categories: widget.categories,
              showAsFullPage: true,
              scrollController: scrollController,
              isAtMaxExtent: isAtMaxExtent,
              onCategoryTap: widget.onCategoryTap,
            ),
          ),
        ),
      ),
    );
  }
}
