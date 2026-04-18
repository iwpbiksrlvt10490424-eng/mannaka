// TDD Red テスト: ShareUtils.appStoreUrl が public API としてアクセス可能であること
//
// 現状 _appStoreUrl は private のため、このテストはコンパイルエラーで Red になる。
// _appStoreUrl → appStoreUrl に変更すればコンパイルが通り Green になる。

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/utils/share_utils.dart';

void main() {
  group('ShareUtils.appStoreUrl — public API テスト', () {
    test('appStoreUrl が正しい App Store URL を返すとき', () {
      // _appStoreUrl が private のままだとコンパイルエラーで Red
      final url = ShareUtils.appStoreUrl;
      expect(url, contains('apps.apple.com/jp/app/aimachi'),
          reason: 'appStoreUrl は App Store の Aimachi ページ URL であるべき');
    });

    test('appStoreUrl が https で始まるとき', () {
      final url = ShareUtils.appStoreUrl;
      expect(url, startsWith('https://'),
          reason: 'appStoreUrl は https:// で始まるべき');
    });

    test('appStoreUrl にアプリID id6761008332 が含まれるとき', () {
      final url = ShareUtils.appStoreUrl;
      expect(url, contains('id6761008332'),
          reason: 'appStoreUrl にアプリID が含まれるべき');
    });
  });
}
