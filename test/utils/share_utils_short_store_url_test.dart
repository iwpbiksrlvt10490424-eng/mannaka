// TDD テスト: ShareUtils.shortStoreUrl の分岐網羅
//
// 分岐:
//  1. hotpepperUrl が埋まっている（trim 後に残る）→ hotpepperUrl をそのまま返す
//  2. hotpepperUrl が null → Google Maps 検索 URL にフォールバック
//  3. hotpepperUrl が 空文字 → Google Maps 検索 URL にフォールバック
//  4. hotpepperUrl が 空白のみ（" "）→ Google Maps 検索 URL にフォールバック
//     （Red: 現状は trim していないので空白URLがそのまま返る → バグ）
//  5. station が空でも name だけで Google Maps URL を組める
//  6. station が埋まっていれば name + station を URL エンコードして連結

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/utils/share_utils.dart';

void main() {
  group('ShareUtils.shortStoreUrl — 店舗リンクの短縮・フォールバック', () {
    test('hotpepperUrl が埋まっているとき そのまま返す', () {
      final url = ShareUtils.shortStoreUrl(
        'https://www.hotpepper.jp/strJ001234567/',
        'ラーメン二郎',
        '新宿',
      );
      expect(url, 'https://www.hotpepper.jp/strJ001234567/',
          reason: 'hotpepperUrl があれば最短の公式ページを返すべき');
    });

    test('hotpepperUrl が null のとき Google Maps 検索 URL にフォールバックする', () {
      final url = ShareUtils.shortStoreUrl(null, 'サイゼリヤ', '渋谷');
      expect(url, startsWith('https://maps.google.com/?q='),
          reason: 'null のとき Google 検索にフォールバックするべき');
      expect(url, contains('%E3%82%B5'),
          reason: '日本語名がエンコードされて入るべき');
    });

    test('hotpepperUrl が 空文字 のとき Google Maps にフォールバックする', () {
      final url = ShareUtils.shortStoreUrl('', 'スタバ', '池袋');
      expect(url, startsWith('https://maps.google.com/?q='),
          reason: '空文字は hotpepperUrl として使えないので Google に落とすべき');
    });

    test('hotpepperUrl が 空白のみ のとき Google Maps にフォールバックする', () {
      // これが Red 側：trim していないと "   " がそのまま URL として返る
      final url = ShareUtils.shortStoreUrl('   ', 'ドトール', '新橋');
      expect(url, startsWith('https://maps.google.com/?q='),
          reason: '空白のみは意味を持たない URL。LINE 本文に空白 URL を送るべきではない');
    });

    test('station が空文字のとき name のみで Google Maps URL を組む', () {
      final url = ShareUtils.shortStoreUrl(null, 'タリーズ', '');
      expect(url, startsWith('https://maps.google.com/?q='));
      // 区切り文字（+ スペース）が URL に混入しないこと
      expect(url, isNot(contains('+%')),
          reason: '空 station を連結すると区切りスペースだけが残るのを防ぐべき');
    });

    test('station が埋まっていれば name + station を連結してエンコード', () {
      final url = ShareUtils.shortStoreUrl(null, 'モスバーガー', '秋葉原');
      // "モスバーガー 秋葉原" の "スペース" が "+" または %20 でエンコードされる
      final hasSeparator = url.contains('+') || url.contains('%20');
      expect(hasSeparator, isTrue,
          reason: 'name と station の間は URL エンコードされた区切りが必要');
    });

    test('Hotpepper の URL が http:// でも触らずそのまま返す（過剰防衛しない）', () {
      // 設計判断: Hotpepper 側の URL 仕様変更耐性を優先。http→https 書き換えはしない。
      // QA レビューで議論したとおり、実害より互換性リスクが上回る。
      final url = ShareUtils.shortStoreUrl(
        'http://www.hotpepper.jp/strJ000111222/',
        'ガスト',
        '目黒',
      );
      expect(url, 'http://www.hotpepper.jp/strJ000111222/',
          reason: '過剰なスキーム書き換えはしない方針');
    });
  });
}
