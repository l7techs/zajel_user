import 'package:http/http.dart' as http;

/// CUSTOM: fewer duplicate requests.
///
/// 6amMart screens call the same GET endpoints many times (e.g. `customer/info` 12x in one 45 s start-up).
/// [RequestCoalescer] sits between `ApiClient` and the network:
///  * **in-flight coalescing** — while a GET for a key is still running, later callers wait for that same
///    network request instead of sending another one;
///  * **short TTL cache** — for an allow-list of session-like endpoints ([RequestCachePolicy]) a successful
///    200 response is reused for a few seconds;
///  * **writes clear everything** — [invalidate] is called on every POST/PUT/DELETE, so a GET issued after a
///    write can never be answered with data fetched before it.
///
/// Only the raw [http.Response] is shared; each caller decodes its own copy, so callers that mutate
/// decoded lists/maps never affect each other. Errors/timeouts are never cached.
class RequestCoalescer {
  final DateTime Function() _now;
  RequestCoalescer({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Map<String, Future<http.Response>> _inFlight = {};
  final Map<String, _CachedResponse> _cache = {};
  int _generation = 0;

  final Map<String, RequestStats> _stats = {};
  Map<String, RequestStats> get stats => _stats;

  /// Returns the response for [key]; [send] performs the real network call when needed.
  Future<http.Response> get(String key, Future<http.Response> Function() send, {Duration? cacheFor, String statsName = ''}) {
    final RequestStats stat = _stats.putIfAbsent(statsName.isEmpty ? key : statsName, () => RequestStats());

    if (cacheFor != null) {
      final _CachedResponse? cached = _cache[key];
      if (cached != null) {
        if (_now().isBefore(cached.expiresAt)) {
          stat.fromCache++;
          return Future<http.Response>.value(cached.response);
        }
        _cache.remove(key);
      }
    }

    final Future<http.Response>? running = _inFlight[key];
    if (running != null) {
      stat.coalesced++;
      return running;
    }

    stat.sent++;
    final int generation = _generation;
    late final Future<http.Response> future;
    future = send().then((http.Response response) {
      if (cacheFor != null && response.statusCode == 200 && generation == _generation) {
        _cache[key] = _CachedResponse(response, _now().add(cacheFor));
      }
      return response;
    }).whenComplete(() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    });
    _inFlight[key] = future;
    return future;
  }

  /// Call on every write (POST/PUT/DELETE/multipart) and on logout/login.
  void invalidate() {
    _generation++;
    _inFlight.clear();
    _cache.clear();
  }

  String statsSummary() {
    final List<String> lines = [];
    _stats.forEach((String name, RequestStats s) {
      lines.add('$name sent=${s.sent} coalesced=${s.coalesced} cached=${s.fromCache}${s.retried > 0 ? ' retried=${s.retried}' : ''}');
    });
    lines.sort();
    return lines.join('\n');
  }

  void resetStats() => _stats.clear();
}

class RequestStats {
  int sent = 0;
  int coalesced = 0;
  int fromCache = 0;
  int retried = 0;
}

class _CachedResponse {
  final http.Response response;
  final DateTime expiresAt;
  _CachedResponse(this.response, this.expiresAt);
}

/// Which GET endpoints may be answered from a short-lived cache. Everything not listed here is only
/// coalesced while in flight. Never list: cart, wish-list, notifications, anything with an order id,
/// anything under checkout.
class RequestCachePolicy {
  RequestCachePolicy._();

  static const Duration zone = Duration(seconds: 60);
  static const Duration profile = Duration(seconds: 15);
  static const Duration orders = Duration(seconds: 10);
  static const Duration content = Duration(seconds: 60);
  static const Duration lists = Duration(seconds: 30);

  /// [uri] is the path + query as passed to `ApiClient.getData` (e.g. `/api/v1/customer/info`).
  static Duration? ttlFor(String uri) {
    final Uri parsed = Uri.parse(uri);
    final String path = parsed.path;
    switch (path) {
      case '/api/v1/config/get-zone-id':
        return zone;
      case '/api/v1/customer/info':
        return profile;
      case '/api/v1/customer/order/last':
      case '/api/v1/customer/order/all-running-orders':
        return orders;
      case '/api/v1/customer/order/payment-failed':
        // Only the "any failed payment?" check; a lookup for a given order id is never cached.
        return parsed.queryParameters.containsKey('order_id') ? null : orders;
      case '/api/v1/module':
      case '/api/v1/smart-banners':
      case '/api/v1/app-popup':
      case '/api/v1/customer/policy-consent':
        return content;
      case '/api/v1/coupon/list':
        return lists;
      case '/api/v1/stores/get-stores/all':
        return parsed.queryParameters['featured'] == '1' ? lists : null;
    }
    return null;
  }

  /// Writes to these endpoints do not change any cached data, so they must not clear the cache.
  static bool isHarmlessWrite(String uri) => Uri.parse(uri).path == '/api/v1/customer/cm-firebase-token';
}
