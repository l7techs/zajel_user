import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';

/// CUSTOM: category image on a soft rounded tile, shown whole (BoxFit.contain).
/// Replaces 6amMart's circle crop, which cut off our transparent category images.
/// While the image downloads (or if it fails) the tile stays empty and the image fades in —
/// CustomImage's wide placeholder picture looked squashed inside a square tile.
class CategoryImageTile extends StatelessWidget {
  final String image;
  final double size;
  const CategoryImageTile({super.key, required this.image, required this.size});

  @override
  Widget build(BuildContext context) {
    final int cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      height: size, width: size,
      padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: image.isEmpty ? null : CachedNetworkImage(
        imageUrl: kIsWeb ? '${AppConstants.baseUrl}/image-proxy?url=$image' : image, // same as CustomImage
        fit: BoxFit.contain,
        memCacheWidth: cacheSize, memCacheHeight: cacheSize,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) => const SizedBox.shrink(),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
      ),
    );
  }
}
