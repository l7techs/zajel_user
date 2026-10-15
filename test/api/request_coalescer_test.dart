import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sixam_mart/api/request_coalescer.dart';

http.Response _ok(String body) => http.Response(body, 200);

void main() {
  test('concurrent identical GETs share one network call', () async {
    final RequestCoalescer c = RequestCoalescer();
    int calls = 0;
    final Completer<http.Response> gate = Completer<http.Response>();
    Future<http.Response> send() { calls++; return gate.future; }

    final List<Future<http.Response>> waiters = [c.get('k', send), c.get('k', send), c.get('k', send)];
    gate.complete(_ok('a'));
    final List<http.Response> results = await Future.wait(waiters);

    expect(calls, 1);
    expect(results.map((http.Response r) => r.body), ['a', 'a', 'a']);
    expect(c.stats['k']!.sent, 1);
    expect(c.stats['k']!.coalesced, 2);
  });

  test('different keys (other headers/module/zone) are separate requests', () async {
    final RequestCoalescer c = RequestCoalescer();
    int calls = 0;
    Future<http.Response> send() async { calls++; return _ok('x'); }
    await Future.wait([c.get('k1', send), c.get('k2', send)]);
    expect(calls, 2);
  });

  test('without cacheFor a finished request is not reused', () async {
    final RequestCoalescer c = RequestCoalescer();
    int calls = 0;
    Future<http.Response> send() async { calls++; return _ok('x'); }
    await c.get('k', send);
    await c.get('k', send);
    expect(calls, 2);
  });

  test('cacheFor reuses a 200 response until it expires', () async {
    DateTime now = DateTime(2026, 10, 15, 12);
    final RequestCoalescer c = RequestCoalescer(now: () => now);
    int calls = 0;
    Future<http.Response> send() async { calls++; return _ok('v$calls'); }

    expect((await c.get('k', send, cacheFor: const Duration(seconds: 10))).body, 'v1');
    now = now.add(const Duration(seconds: 5));
    expect((await c.get('k', send, cacheFor: const Duration(seconds: 10))).body, 'v1');
    expect(c.stats['k']!.fromCache, 1);
    now = now.add(const Duration(seconds: 6));
    expect((await c.get('k', send, cacheFor: const Duration(seconds: 10))).body, 'v2');
    expect(calls, 2);
  });

  test('non-200 responses are never cached', () async {
    final RequestCoalescer c = RequestCoalescer();
    int calls = 0;
    Future<http.Response> send() async { calls++; return http.Response('err', 500); }
    await c.get('k', send, cacheFor: const Duration(seconds: 10));
    await c.get('k', send, cacheFor: const Duration(seconds: 10));
    expect(calls, 2);
  });

  test('errors reach every waiter and are not kept', () async {
    final RequestCoalescer c = RequestCoalescer();
    int calls = 0;
    final Completer<http.Response> gate = Completer<http.Response>();
    Future<http.Response> failing() { calls++; return gate.future; }

    final Future<http.Response> a = c.get('k', failing);
    final Future<http.Response> b = c.get('k', failing);
    final Future<void> expectA = expectLater(a, throwsA(isA<TimeoutException>()));
    final Future<void> expectB = expectLater(b, throwsA(isA<TimeoutException>()));
    gate.completeError(TimeoutException('slow'));
    await Future.wait([expectA, expectB]);
    expect(calls, 1);

    // next call goes to the network again
    final http.Response next = await c.get('k', () async { calls++; return _ok('fresh'); });
    expect(next.body, 'fresh');
    expect(calls, 2);
  });

  test('a write (invalidate) stops later GETs joining an older in-flight GET', () async {
    final RequestCoalescer c = RequestCoalescer();
    final Completer<http.Response> oldGate = Completer<http.Response>();
    int calls = 0;

    final Future<http.Response> before = c.get('cart', () { calls++; return oldGate.future; });
    c.invalidate(); // e.g. add-to-cart POST
    final Future<http.Response> after = c.get('cart', () async { calls++; return _ok('new cart'); });

    expect((await after).body, 'new cart');
    expect(calls, 2);
    oldGate.complete(_ok('old cart'));
    expect((await before).body, 'old cart');
  });

  test('a response that started before a write is not cached afterwards', () async {
    final RequestCoalescer c = RequestCoalescer();
    final Completer<http.Response> gate = Completer<http.Response>();
    int calls = 0;

    final Future<http.Response> started = c.get('info', () { calls++; return gate.future; }, cacheFor: const Duration(seconds: 15));
    c.invalidate();
    gate.complete(_ok('stale'));
    await started;

    final http.Response again = await c.get('info', () async { calls++; return _ok('fresh'); }, cacheFor: const Duration(seconds: 15));
    expect(again.body, 'fresh');
    expect(calls, 2);
  });

  test('invalidate clears the TTL cache', () async {
    final RequestCoalescer c = RequestCoalescer();
    int calls = 0;
    Future<http.Response> send() async { calls++; return _ok('v$calls'); }
    await c.get('k', send, cacheFor: const Duration(seconds: 60));
    c.invalidate();
    expect((await c.get('k', send, cacheFor: const Duration(seconds: 60))).body, 'v2');
  });

  group('RequestCachePolicy', () {
    test('allow-listed session endpoints have a TTL', () {
      expect(RequestCachePolicy.ttlFor('/api/v1/customer/info'), RequestCachePolicy.profile);
      expect(RequestCachePolicy.ttlFor('/api/v1/config/get-zone-id?lat=1&lng=2'), RequestCachePolicy.zone);
      expect(RequestCachePolicy.ttlFor('/api/v1/customer/order/last'), RequestCachePolicy.orders);
      expect(RequestCachePolicy.ttlFor('/api/v1/stores/get-stores/all?featured=1&offset=1&limit=50'), RequestCachePolicy.lists);
    });

    test('cart, wish-list, notifications, normal store lists and order lookups are never cached', () {
      expect(RequestCachePolicy.ttlFor('/api/v1/customer/cart/get-all'), isNull);
      expect(RequestCachePolicy.ttlFor('/api/v1/customer/wish-list'), isNull);
      expect(RequestCachePolicy.ttlFor('/api/v1/customer/notifications'), isNull);
      expect(RequestCachePolicy.ttlFor('/api/v1/stores/get-stores/all?store_type=all&offset=1&limit=12'), isNull);
      expect(RequestCachePolicy.ttlFor('/api/v1/customer/order/payment-failed?order_id=100001'), isNull);
      expect(RequestCachePolicy.ttlFor('/api/v1/customer/order/details?order_id=1'), isNull);
    });

    test('only the firebase-token POST is a harmless write', () {
      expect(RequestCachePolicy.isHarmlessWrite('/api/v1/customer/cm-firebase-token'), isTrue);
      expect(RequestCachePolicy.isHarmlessWrite('/api/v1/customer/cart/add'), isFalse);
    });
  });
}
