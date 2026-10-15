import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/home/controllers/home_section_status_controller.dart';
import 'package:sixam_mart/features/home/screens/home_screen.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/styles.dart';
import 'package:sliver_tools/sliver_tools.dart';

/// CUSTOM: one module-home section with its failure policy (docs/plan-home-section-failures.md).
/// Shows [slivers] while the section is loading or loaded, a retry box when its request failed (after one automatic
/// retry), and nothing when the section is empty ([visible] false) or the whole page failed (see [HomePageFailedSliver]).
/// Always returns exactly one sliver, so it stays valid inside the module screen's MultiSliver.
class HomeSectionSliver extends StatelessWidget {
  final String sectionKey;
  final bool visible;
  final List<Widget> slivers;
  const HomeSectionSliver({super.key, required this.sectionKey, required this.visible, required this.slivers});

  @override
  Widget build(BuildContext context) {
    if (!AppConstants.homeSectionFailurePolicy) {
      return visible ? MultiSliver(children: slivers) : const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return GetBuilder<HomeSectionStatusController>(builder: (status) {
      if (status.pageFailed) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      if (status.isFailed(sectionKey)) {
        return SliverToBoxAdapter(child: _SectionRetryCard(onRetry: () => status.retry(sectionKey)));
      }
      return visible ? MultiSliver(children: slivers) : const SliverToBoxAdapter(child: SizedBox.shrink());
    });
  }
}

/// CUSTOM: one message for the whole module home when nothing could be loaded (categories and banners both failed).
class HomePageFailedSliver extends StatelessWidget {
  const HomePageFailedSliver({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConstants.homeSectionFailurePolicy) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return GetBuilder<HomeSectionStatusController>(builder: (status) {
      if (!status.pageFailed) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeLarge, vertical: Dimensions.paddingSizeExtraOverLarge),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: Theme.of(context).disabledColor),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Text('page_load_failed'.tr, textAlign: TextAlign.center, style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeLarge)),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          ElevatedButton.icon(
            onPressed: () => HomeScreen.refreshAll(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text('retry'.tr),
          ),
        ]),
      ));
    });
  }
}

class _SectionRetryCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _SectionRetryCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeSmall),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Dimensions.paddingSizeDefault, vertical: Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            color: Theme.of(context).disabledColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          ),
          child: Row(children: [
            Icon(Icons.cloud_off_rounded, color: Theme.of(context).disabledColor),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(child: Text('section_load_failed'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault))),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Icon(Icons.refresh_rounded, color: Theme.of(context).primaryColor, size: 20),
            const SizedBox(width: Dimensions.paddingSizeExtraSmall),
            Text('tap_to_retry'.tr, style: robotoMedium.copyWith(color: Theme.of(context).primaryColor, fontSize: Dimensions.fontSizeSmall)),
          ]),
        ),
      ),
    );
  }
}
