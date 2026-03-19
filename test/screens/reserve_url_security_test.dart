// TDD Red フェーズ
// S1: _ReserveButton が http:// を許容している問題のテスト
//
// Engineer への実装依頼:
//   restaurant_detail_screen.dart に以下のトップレベル関数を追加する。
//
//   bool isReservationUrlAllowed(String url) { ... }
//
//   条件: https:// スキームのみ許可。http://, javascript:, data: 等は拒否。
//   その後 _ReserveButton._reserve() の uri.scheme チェックをこの関数に置き換える。

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/screens/restaurant_detail_screen.dart';

void main() {
  group('isReservationUrlAllowed()', () {
    test('http:// URLのとき 予約リンクが開かれない', () {
      // 現行コードは (uri.scheme == 'http' || uri.scheme == 'https') を許容しており
      // 中間者攻撃のリスクがある。https:// のみを許可する関数が必要。
      expect(
        isReservationUrlAllowed('http://r.gnavi.co.jp/abc/'),
        isFalse,
        reason: 'http:// は通信が平文になるため拒否しなければなりません。',
      );
    });

    test('https:// URLのとき 予約リンクが開かれる', () {
      expect(
        isReservationUrlAllowed('https://r.gnavi.co.jp/abc/'),
        isTrue,
        reason: 'https:// は安全な通信のため許可する必要があります。',
      );
    });

    test('空文字のとき 予約リンクが開かれない', () {
      expect(
        isReservationUrlAllowed(''),
        isFalse,
      );
    });

    test('javascript: スキームのとき 予約リンクが開かれない', () {
      expect(
        isReservationUrlAllowed('javascript:alert(1)'),
        isFalse,
        reason: '不正なスキームはXSSリスクがあるため拒否しなければなりません。',
      );
    });

    test('不正な文字列のとき 予約リンクが開かれない', () {
      expect(
        isReservationUrlAllowed('not-a-url'),
        isFalse,
      );
    });
  });
}
