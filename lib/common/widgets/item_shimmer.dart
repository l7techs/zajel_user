import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:flutter/material.dart';

// CUSTOM: shimmer mirrors ItemWidget (card shadow/radius, 90px image, cart button at the end) and is direction-aware (RTL)
class ItemShimmer extends StatelessWidget {
  final bool isEnabled;
  final bool isStore;
  final bool hasDivider;
  const ItemShimmer({super.key, required this.isEnabled, required this.hasDivider, this.isStore = false});

  @override
  Widget build(BuildContext context) {
    bool desktop = ResponsiveHelper.isDesktop(context);
    final Color shade = Theme.of(context).shadowColor;

    return Container(
      margin: desktop ? null : const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      padding: desktop
          ? const EdgeInsets.all(Dimensions.paddingSizeSmall)
          : const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall, vertical: Dimensions.paddingSizeExtraSmall),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        color: Theme.of(context).cardColor,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1)],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: desktop ? 0 : Dimensions.paddingSizeExtraSmall),
        child: Row(children: [

          Container(
            height: desktop ? 120 : 90, width: desktop ? 120 : 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              color: shade,
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [

              Container(
                height: desktop ? 16 : 12, width: double.maxFinite,
                margin: const EdgeInsetsDirectional.only(end: Dimensions.paddingSizeExtraLarge),
                color: shade,
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              Container(
                height: desktop ? 12 : 9, width: double.maxFinite,
                margin: const EdgeInsetsDirectional.only(end: Dimensions.paddingSizeExtraLarge * 2),
                color: shade,
              ),
              const SizedBox(height: Dimensions.paddingSizeSmall),

              isStore ? Row(
                children: List.generate(5, (index) {
                  return Icon(Icons.star, color: shade, size: 14);
                }),
              ) : Row(children: [
                Container(height: desktop ? 18 : 14, width: 40, color: shade),
                const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                Container(height: desktop ? 14 : 10, width: 25, color: shade),
              ]),

            ]),
          ),

          Column(mainAxisAlignment: isStore ? MainAxisAlignment.center : MainAxisAlignment.end, children: [
            Container(
              height: 30, width: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, color: shade),
            ),
          ]),

        ]),
      ),
    );
  }
}
