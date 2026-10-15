import 'package:flutter_test/flutter_test.dart';
import 'package:sixam_mart/features/home/controllers/home_section_status_controller.dart';

void main() {
  late List<String> reloads;
  late int summaries;
  late Set<String> withData;

  HomeSectionStatusController make() => HomeSectionStatusController(
    hasDataOverride: (s) => withData.contains(s),
    reloadOverride: reloads.add,
    summaryOverride: () => summaries++,
    retryDelay: const Duration(milliseconds: 10),
  );

  setUp(() { reloads = []; summaries = 0; withData = {}; });

  test('a failure triggers one automatic retry, a second failure marks the section failed', () async {
    final c = make();
    c.report('popular_items', false);
    expect(c.isFailed('popular_items'), isFalse);
    await Future.delayed(const Duration(milliseconds: 30));
    expect(reloads, ['popular_items']);
    c.report('popular_items', false);
    expect(c.isFailed('popular_items'), isTrue);
    expect(summaries, 1);
  });

  test('duplicate failure reports of the same request do not skip the automatic retry', () async {
    final c = make();
    c.report('banners', false);
    c.report('banners', false); // second caller sharing the same failed request
    expect(c.isFailed('banners'), isFalse);
    await Future.delayed(const Duration(milliseconds: 30));
    expect(reloads, ['banners']);
  });

  test('success after the automatic retry clears the section', () async {
    final c = make();
    c.report('latest_stores', false);
    await Future.delayed(const Duration(milliseconds: 30));
    c.report('latest_stores', true);
    expect(c.isFailed('latest_stores'), isFalse);
    expect(summaries, 0);
  });

  test('a section that already shows data is never marked failed', () async {
    withData.add('categories');
    final c = make();
    c.report('categories', false);
    await Future.delayed(const Duration(milliseconds: 30));
    expect(reloads, isEmpty);
    expect(c.isFailed('categories'), isFalse);
  });

  test('retry button reloads and a further failure keeps it failed; success clears it', () async {
    final c = make();
    c.report('brands', false);
    await Future.delayed(const Duration(milliseconds: 30));
    c.report('brands', false);
    expect(c.isFailed('brands'), isTrue);
    c.retry('brands');
    expect(reloads.last, 'brands');
    expect(c.isFailed('brands'), isFalse);
    c.report('brands', true);
    expect(c.isFailed('brands'), isFalse);
  });

  test('categories and banners both failed = page failed, and no summary message then', () async {
    final c = make();
    for (final s in ['categories', 'banners']) {
      c.report(s, false);
    }
    await Future.delayed(const Duration(milliseconds: 30));
    c.report('categories', false);
    expect(summaries, 1);
    c.report('banners', false);
    expect(c.pageFailed, isTrue);
    expect(summaries, 1);
  });

  test('reset clears failures for a new home load', () async {
    final c = make();
    c.report('reels', false);
    await Future.delayed(const Duration(milliseconds: 30));
    c.report('reels', false);
    c.reset();
    expect(c.isFailed('reels'), isFalse);
  });
}
