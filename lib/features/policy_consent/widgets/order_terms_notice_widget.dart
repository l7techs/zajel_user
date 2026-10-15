import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

/// CUSTOM: notice above the place-order button (checklist 1.21) — placing the order means
/// accepting the terms; the backend logs the policy version with every order.
class OrderTermsNoticeWidget extends StatelessWidget {
  final bool isParcel;
  const OrderTermsNoticeWidget({super.key, this.isParcel = false});

  @override
  Widget build(BuildContext context) {
    final bool showRefund = !isParcel && Get.find<SplashController>().configModel?.refundPolicyStatus == 1;
    final bool showCancellation = Get.find<SplashController>().configModel?.cancellationPolicyStatus == 1;
    final TextStyle textStyle = robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor);
    final TextStyle linkStyle = robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor);

    final List<MapEntry<String, String>> links = [
      MapEntry('privacy_policy'.tr, RouteHelper.privacyPolicy),
      MapEntry('terms_conditions'.tr, RouteHelper.termsAndCondition),
      if (showCancellation) MapEntry('cancellation_policy'.tr, RouteHelper.cancellationPolicy),
      if (showRefund) MapEntry('refund_policy'.tr, RouteHelper.refundPolicy),
    ];

    final List<InlineSpan> spans = [TextSpan(text: '${'by_placing_this_order_you_agree_to'.tr} ', style: textStyle)];
    for (int i = 0; i < links.length; i++) {
      if (i > 0) {
        spans.add(TextSpan(text: i == links.length - 1 ? ' ${'and'.tr} ' : '${'comma_separator'.tr} ', style: textStyle));
      }
      spans.add(TextSpan(
        text: links[i].key, style: linkStyle,
        recognizer: TapGestureRecognizer()..onTap = () => Get.toNamed(links[i].value),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
      child: Text.rich(TextSpan(children: spans), textAlign: TextAlign.center),
    );
  }
}
