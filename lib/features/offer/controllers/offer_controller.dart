import 'package:get/get.dart';
import 'package:sixam_mart/features/offer/domain/models/new_item_model.dart';
import 'package:sixam_mart/features/offer/domain/services/offer_service_interface.dart';
import 'package:sixam_mart/features/service_module/service_home/domain/models/service_model.dart';
import 'package:sixam_mart/features/store/domain/models/store_model.dart';
import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/helper/module_state_cache.dart'; // CUSTOM: instant offer tabs

class OfferController extends GetxController implements GetxService {
  final OfferServiceInterface offerServiceInterface;
  OfferController({required this.offerServiceInterface});

  static const String typeAll = 'all';
  static const String typeItem = 'item';
  static const String typeStore = 'store';
  static const int pageLimit = 10;

  NewItemListResponse? _itemList;
  NewItemListResponse? get itemList => _itemList;

  ServiceModel? _serviceItemList;
  ServiceModel? get serviceItemList => _serviceItemList;

  StoreModel? _storeList;
  StoreModel? get storeList => _storeList;

  List<Store>? _exclusiveDeals;
  List<Store>? get exclusiveDeals => _exclusiveDeals;

  String _selectedType = typeAll;
  String get selectedType => _selectedType;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int? _selectedModuleId;
  int? get selectedModuleId => _selectedModuleId;

  String? _selectedModuleType;
  String? get selectedModuleType => _selectedModuleType;

  bool get isServiceModule => _selectedModuleType == AppConstants.service;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _itemOffset = 1;
  int get itemOffset => _itemOffset;

  int _storeOffset = 1;
  int get storeOffset => _storeOffset;

  int _serviceItemOffset = 1;
  int get serviceItemOffset => _serviceItemOffset;

  // CUSTOM-START: instant offer tabs. 6amMart cleared both lists and re-downloaded on every tab tap, although the
  // All / Items / Stores tabs show the same item & store lists (same requests). Now:
  //  - type tabs reuse the module's lists and fetch only a list that is still missing;
  //  - each module's lists are kept in memory (_moduleCache): leaving a module stashes them, coming back restores them;
  //  - a kept list is refreshed quietly (no clearing, no shimmer) only if older than [_freshFor] and still on page 1
  //    (a list paginated further is left alone so the user's place isn't lost);
  //  - search results aren't kept; clearing the search restores the module's lists;
  //  - responses for a module/search the user already left are dropped (they used to land in the wrong tab);
  //  - everything is dropped when zone / language / user changes (ModuleStateCache.currentContextKey()).
  // The `reload` parameter is kept for callers but no longer forces a clear.
  static const Duration _freshFor = Duration(seconds: 60);
  final Map<String, _OfferModuleCache> _moduleCache = {};
  String? _cacheContextKey;
  int _loadGen = 0;
  DateTime? _itemsAt;
  DateTime? _storesAt;
  DateTime? _servicesAt;
  DateTime? _dealsAt;

  Future<void> loadOffers({
    String? type,
    String? search,
    int? moduleId,
    String? moduleType,
    bool clearModule = false,
    bool reload = false,
    bool notify = true,
  }) async {
    final String nextType = type ?? _selectedType;
    final String nextSearch = search ?? _searchQuery;
    final int? nextModuleId = clearModule ? null : (moduleId ?? _selectedModuleId);
    final String? nextModuleType = clearModule ? null : (moduleType ?? _selectedModuleType);
    final bool searchChanged = nextSearch != _searchQuery;
    final bool moduleChanged = nextModuleId != _selectedModuleId || nextModuleType != _selectedModuleType;

    _checkCacheContext();
    if (moduleChanged || searchChanged) _stashCurrent();
    _selectedType = nextType;
    _searchQuery = nextSearch;
    _selectedModuleId = nextModuleId;
    _selectedModuleType = nextModuleType;
    if ((moduleChanged || searchChanged) && !_restoreCurrent()) _clearCurrent();

    // Exclusive deals apply only to non-service modules.
    if (isServiceModule) _exclusiveDeals = null;
    final bool fetchItems = _shouldFetchItems && _needsFetch(_itemList, _itemsAt, _itemOffset);
    final bool fetchServices = _shouldFetchServiceItems && _needsFetch(_serviceItemList, _servicesAt, _serviceItemOffset);
    final bool fetchStores = _shouldFetchStores && _needsFetch(_storeList, _storesAt, _storeOffset);
    final bool fetchDeals = !isServiceModule && _needsFetch(_exclusiveDeals, _dealsAt, 1);

    // The shimmer (isLoading) only when a list this tab shows doesn't exist yet; refreshes are silent.
    final int gen = ++_loadGen;
    _isLoading = (fetchItems && _itemList == null) || (fetchServices && _serviceItemList == null) || (fetchStores && _storeList == null);
    if (notify) update();
    if (!fetchItems && !fetchServices && !fetchStores && !fetchDeals) return;

    await Future.wait<void>(<Future<void>>[
      if (fetchItems) _fetchItems(offset: 1, replace: true),
      if (fetchServices) _fetchServiceItems(offset: 1, replace: true),
      if (fetchStores) _fetchStores(offset: 1, replace: true),
      if (fetchDeals) _fetchExclusiveDeals(),
    ]);

    if (gen == _loadGen) _isLoading = false;
    update();
  }

  bool _needsFetch(Object? data, DateTime? fetchedAt, int offset) {
    if (data == null) return true;
    if (offset > 1) return false;
    return fetchedAt == null || DateTime.now().difference(fetchedAt) > _freshFor;
  }

  // True while the response for this module + search is still the one on screen.
  bool _isCurrent(int? moduleId, String search) => moduleId == _selectedModuleId && search == _searchQuery;

  String get _cacheKey => '${_selectedModuleId ?? 'all'}';

  void _checkCacheContext() {
    final String key = ModuleStateCache.currentContextKey();
    if (_cacheContextKey != null && _cacheContextKey != key) {
      _moduleCache.clear();
      _clearCurrent();
    }
    _cacheContextKey = key;
  }

  void _stashCurrent() {
    if (_searchQuery.isNotEmpty) return;
    if (_itemList == null && _storeList == null && _serviceItemList == null && _exclusiveDeals == null) return;
    _moduleCache[_cacheKey] = _OfferModuleCache(
      itemList: _itemList, serviceItemList: _serviceItemList, storeList: _storeList, exclusiveDeals: _exclusiveDeals,
      itemOffset: _itemOffset, storeOffset: _storeOffset, serviceItemOffset: _serviceItemOffset,
      itemsAt: _itemsAt, storesAt: _storesAt, servicesAt: _servicesAt, dealsAt: _dealsAt,
    );
  }

  bool _restoreCurrent() {
    if (_searchQuery.isNotEmpty) return false;
    final _OfferModuleCache? cached = _moduleCache[_cacheKey];
    if (cached == null) return false;
    _itemList = cached.itemList;
    _serviceItemList = cached.serviceItemList;
    _storeList = cached.storeList;
    _exclusiveDeals = cached.exclusiveDeals;
    _itemOffset = cached.itemOffset;
    _storeOffset = cached.storeOffset;
    _serviceItemOffset = cached.serviceItemOffset;
    _itemsAt = cached.itemsAt;
    _storesAt = cached.storesAt;
    _servicesAt = cached.servicesAt;
    _dealsAt = cached.dealsAt;
    return true;
  }

  void _clearCurrent() {
    _itemList = null;
    _storeList = null;
    _serviceItemList = null;
    _exclusiveDeals = null;
    _itemOffset = 1;
    _storeOffset = 1;
    _serviceItemOffset = 1;
    _itemsAt = null;
    _storesAt = null;
    _servicesAt = null;
    _dealsAt = null;
  }

  Future<void> _fetchExclusiveDeals() async {
    final int? moduleId = _selectedModuleId;
    final String search = _searchQuery;
    final List<Store>? deals = await offerServiceInterface.getExclusiveDeals(moduleId: moduleId);
    if (!_isCurrent(moduleId, search)) return;
    _exclusiveDeals = deals;
    _dealsAt = DateTime.now();
  }

  Future<void> _fetchItems({required int offset, bool replace = false}) async {
    final int? moduleId = _selectedModuleId;
    final String search = _searchQuery;
    final NewItemListResponse? response = await offerServiceInterface.getOfferItems(
      offset: offset, limit: pageLimit, search: search, moduleId: moduleId,
    );
    if (response == null || !_isCurrent(moduleId, search)) return;
    if (replace || _itemList == null) {
      _itemList = response;
      _itemsAt = DateTime.now();
    } else {
      _itemList!.items ??= <NewItem>[];
      if (response.items != null) _itemList!.items!.addAll(response.items!);
      _itemList!.totalSize = response.totalSize;
      _itemList!.limit = response.limit;
      _itemList!.offset = response.offset;
    }
    _itemOffset = offset;
  }

  Future<void> _fetchServiceItems({required int offset, bool replace = false}) async {
    final int? moduleId = _selectedModuleId;
    final String search = _searchQuery;
    final ServiceModel? response = await offerServiceInterface.getServiceOfferItems(
      offset: offset, limit: pageLimit, search: search, moduleId: moduleId,
    );
    if (response == null || !_isCurrent(moduleId, search)) return;
    if (replace || _serviceItemList == null) {
      _serviceItemList = response;
      _servicesAt = DateTime.now();
    } else {
      _serviceItemList!.services ??= <Service>[];
      if (response.services != null) _serviceItemList!.services!.addAll(response.services!);
      _serviceItemList!.totalSize = response.totalSize;
      _serviceItemList!.limit = response.limit;
      _serviceItemList!.offset = response.offset;
    }
    _serviceItemOffset = offset;
  }

  Future<void> _fetchStores({required int offset, bool replace = false}) async {
    final int? moduleId = _selectedModuleId;
    final String search = _searchQuery;
    final StoreModel? response = await offerServiceInterface.getOfferStores(
      offset: offset, limit: pageLimit, search: search, moduleId: moduleId,
    );
    if (response == null || !_isCurrent(moduleId, search)) return;
    if (replace || _storeList == null) {
      _storeList = response;
      _storesAt = DateTime.now();
    } else {
      _storeList!.stores ??= <Store>[];
      if (response.stores != null) _storeList!.stores!.addAll(response.stores!);
      _storeList!.totalSize = response.totalSize;
      _storeList!.limit = response.limit;
      _storeList!.offset = response.offset;
    }
    _storeOffset = offset;
  }
  // CUSTOM-END

  void setSelectedType(String type) {
    if (_selectedType == type) return;
    loadOffers(type: type, reload: true);
  }

  void setSearchQuery(String query) {
    final String trimmed = query.trim();
    if (_searchQuery == trimmed) return;
    loadOffers(search: trimmed, reload: true);
  }

  void setModuleFilter(int? moduleId, {String? moduleType}) {
    if (_selectedModuleId == moduleId && _selectedModuleType == moduleType) return;
    loadOffers(moduleId: moduleId, moduleType: moduleType, clearModule: moduleId == null, reload: true);
  }

  // Items are fetched only for non-service modules.
  bool get _shouldFetchItems => !isServiceModule && (_selectedType == typeAll || _selectedType == typeItem);
  // Service items are fetched only for the service module.
  bool get _shouldFetchServiceItems => isServiceModule && (_selectedType == typeAll || _selectedType == typeItem);
  bool get _shouldFetchStores => _selectedType == typeAll || _selectedType == typeStore;

  int get totalResultCount {
    if (isServiceModule) {
      final int serviceTotal = _serviceItemList?.totalSize ?? 0;
      final int storeTotal = _storeList?.totalSize ?? 0;
      if (_selectedType == typeItem) return serviceTotal;
      if (_selectedType == typeStore) return storeTotal;
      return serviceTotal + storeTotal;
    }
    final int itemTotal = _itemList?.totalSize ?? 0;
    final int storeTotal = _storeList?.totalSize ?? 0;
    if (_selectedType == typeItem) return itemTotal;
    if (_selectedType == typeStore) return storeTotal;
    return itemTotal + storeTotal;
  }

  // Pagination is driven by PaginatedListView for the active vertical list.
  Future<void> paginateItems(int? offset) async {
    if (offset == null) return;
    await _fetchItems(offset: offset);
    update();
  }

  Future<void> paginateStores(int? offset) async {
    if (offset == null) return;
    await _fetchStores(offset: offset);
    update();
  }

  Future<void> paginateServiceItems(int? offset) async {
    if (offset == null) return;
    await _fetchServiceItems(offset: offset);
    update();
  }
}

// CUSTOM: one module's offer lists, kept by OfferController for instant tab switching.
class _OfferModuleCache {
  final NewItemListResponse? itemList;
  final ServiceModel? serviceItemList;
  final StoreModel? storeList;
  final List<Store>? exclusiveDeals;
  final int itemOffset;
  final int storeOffset;
  final int serviceItemOffset;
  final DateTime? itemsAt;
  final DateTime? storesAt;
  final DateTime? servicesAt;
  final DateTime? dealsAt;

  const _OfferModuleCache({
    this.itemList, this.serviceItemList, this.storeList, this.exclusiveDeals, required this.itemOffset,
    required this.storeOffset, required this.serviceItemOffset, this.itemsAt, this.storesAt, this.servicesAt,
    this.dealsAt,
  });
}
