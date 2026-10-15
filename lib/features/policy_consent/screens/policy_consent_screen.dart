import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/features/policy_consent/controllers/policy_consent_controller.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';

/// CUSTOM: blocking consent screen (checklist 1.5) — shown to a logged-in customer
/// who has not accepted the current privacy policy / terms version. Back is disabled:
/// the only ways out are accepting or declining (which logs out).
class PolicyConsentScreen extends StatelessWidget {
  final bool isUpdate;
  const PolicyConsentScreen({super.key, required this.isUpdate});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: GetBuilder<PolicyConsentController>(builder: (policyConsentController) {
                  return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                    Icon(Icons.privacy_tip_outlined, size: 64, color: Theme.of(context).primaryColor),
                    const SizedBox(height: Dimensions.paddingSizeLarge),

                    Text(
                      'policy_consent_title'.tr, textAlign: TextAlign.center,
                      style: robotoBold.copyWith(fontSize: Dimensions.fontSizeExtraLarge),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),

                    Text(
                      (isUpdate ? 'policy_consent_updated_message' : 'policy_consent_message').tr, textAlign: TextAlign.center,
                      style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                    _PolicyLinkTile(title: 'privacy_policy'.tr, route: RouteHelper.privacyPolicy),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    _PolicyLinkTile(title: 'terms_conditions'.tr, route: RouteHelper.termsAndCondition),
                    const SizedBox(height: Dimensions.paddingSizeExtremeLarge),

                    CustomButton(
                      buttonText: 'i_accept'.tr, isLoading: policyConsentController.isLoading,
                      onPressed: () => policyConsentController.accept(isUpdate: isUpdate),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),

                    TextButton(
                      onPressed: policyConsentController.isLoading ? null : () => policyConsentController.decline(),
                      child: Text('decline_and_log_out'.tr, style: robotoMedium.copyWith(color: Theme.of(context).colorScheme.error)),
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicyLinkTile extends StatelessWidget {
  final String title;
  final String route;
  const _PolicyLinkTile({required this.title, required this.route});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(route),
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(color: Theme.of(context).disabledColor.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.description_outlined, color: Theme.of(context).primaryColor),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(child: Text(title, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeDefault))),
          // chevron_right mirrors itself in right-to-left (Arabic) layouts.
          Icon(Icons.chevron_right, color: Theme.of(context).hintColor),
        ]),
      ),
    );
  }
}
