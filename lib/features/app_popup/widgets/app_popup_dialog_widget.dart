import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_image.dart';
import 'package:sixam_mart/features/app_popup/controllers/app_popup_controller.dart';
import 'package:sixam_mart/features/app_popup/domain/models/app_popup_model.dart';
import 'package:sixam_mart/util/dimensions.dart';

/// The popup image (animated GIF / WebP play as-is) with a close button above its top-end corner.
class AppPopupDialogWidget extends StatelessWidget {
  final AppPopupModel popup;
  final String imageUrl;
  final double aspectRatio;
  const AppPopupDialogWidget({super.key, required this.popup, required this.imageUrl, required this.aspectRatio});

  static const double _maxWidth = 420;

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.sizeOf(context);
    // ~85% of the width (420 max on tablets / web) and ~70% of the height; the image keeps its own shape.
    double maxWidth = min(screenSize.width * 0.85, _maxWidth);
    double maxHeight = screenSize.height * 0.7;
    double width = min(maxWidth, maxHeight * aspectRatio);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: width,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Semantics(
              button: true,
              label: 'close'.tr,
              child: InkWell(
                // Navigator.pop, not Get.back: Get.back closes an open snackbar instead of the dialog.
                onTap: () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle),
                  child: Icon(Icons.close, size: 20, color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            GestureDetector(
              onTap: popup.hasLink ? () {
                Navigator.of(context).pop();
                Get.find<AppPopupController>().onPopupTap(popup);
              } : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: CustomImage(image: imageUrl, fit: BoxFit.cover),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
