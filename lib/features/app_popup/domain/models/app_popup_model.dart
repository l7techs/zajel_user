import 'package:sixam_mart/features/item/domain/models/item_model.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';

/// The app-open promotional popup set in the admin panel (Marketing → App Popup).
class AppPopupModel {
  int? id;
  String? imageFullUrl;
  String? imageArFullUrl;
  /// none | store | item
  String? linkType;
  Store? store;
  Item? item;
  /// once | daily | always
  String? frequency;

  AppPopupModel({
    this.id, this.imageFullUrl, this.imageArFullUrl, this.linkType, this.store,
    this.item, this.frequency,
  });

  AppPopupModel.fromJson(Map<String, dynamic> json) {
    id = json['id'] is String ? int.tryParse(json['id']) : json['id'];
    imageFullUrl = json['image_full_url'];
    imageArFullUrl = json['image_ar_full_url'];
    linkType = json['link_type'] ?? 'none';
    store = json['store'] != null ? Store.fromJson(json['store']) : null;
    item = json['item'] != null ? Item.fromJson(json['item']) : null;
    frequency = json['frequency'] ?? 'once';
  }

  /// The Arabic image for Arabic-language users when one was uploaded, otherwise the main image.
  String? imageFor(String languageCode) {
    if (languageCode == 'ar' && imageArFullUrl != null && imageArFullUrl!.isNotEmpty) {
      return imageArFullUrl;
    }
    return imageFullUrl;
  }

  bool get hasLink => (linkType == 'store' && store != null) || (linkType == 'item' && item != null);
}
