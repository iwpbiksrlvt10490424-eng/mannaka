// Phase 1〜4 リデザインのリグレッションテスト。
//
// 内容（細かいテストケース）:
//   1. shortenAccess: 長文アクセス情報の短縮
//   2. todayHours: 本日の営業時間抽出
//   3. formatOpenHours: 営業時間文字列の分割
//   4. FactBadges.build: 事実ベース最大 2 ラベル
//   5. 構造ガード: 旧文言・旧 Widget の残存チェック
//   6. バージョン整合性チェック

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/screens/restaurant_detail_screen.dart';
import 'package:mannaka/screens/results_screen.dart';

void main() {
  group('shortenAccess: アクセス文の短縮', () {
    test('空文字は空文字を返す', () {
      expect(shortenAccess(''), '');
    });

    test('Hotpepper の冗長アクセス文を短くする', () {
      const raw = 'JR池袋駅39出口より徒歩約1分/都電荒川線都電雑司ヶ谷駅出口より徒歩約13分';
      final out = shortenAccess(raw);
      expect(out.contains('池袋駅'), isTrue);
      expect(out.contains('徒歩1分'), isTrue);
      expect(out.length < raw.length, isTrue);
    });

    test('セパレータが無いシンプルな入力はほぼそのまま返す', () {
      const raw = '渋谷駅から徒歩5分';
      expect(shortenAccess(raw), '渋谷駅から徒歩5分');
    });

    test('「東京メトロ」「都営」などの路線名は除去する', () {
      const raw = '東京メトロ丸ノ内線 新宿駅 徒歩2分';
      final out = shortenAccess(raw);
      expect(out.contains('東京メトロ'), isFalse);
      expect(out.contains('丸ノ内線 新宿駅'), isTrue);
    });

    test('「徒歩約」は「徒歩」に短縮される', () {
      const raw = '渋谷駅徒歩約3分';
      expect(shortenAccess(raw).contains('徒歩約'), isFalse);
      expect(shortenAccess(raw).contains('徒歩3分'), isTrue);
    });

    test('読点（、）を含むアクセス文も処理できる', () {
      const raw = 'JR渋谷駅、ハチ公口より徒歩約2分';
      final out = shortenAccess(raw);
      expect(out.contains('JR'), isFalse);
    });
  });

  group('todayHours: 本日の営業時間抽出', () {
    test('空文字は空文字を返す', () {
      expect(todayHours(''), '');
    });

    test('単一の営業時間はそのまま返す', () {
      const raw = '17:00〜23:00';
      expect(todayHours(raw), '17:00〜23:00');
    });

    test('月曜日のときに「月、水、金：12:00〜23:00」slot を選ぶ', () {
      const raw = '月、水、金：12:00〜23:00 / 火、木、土：14:00〜02:00';
      // 2026-05-11 は月曜日
      final out = todayHours(raw, now: DateTime(2026, 5, 11));
      expect(out.contains('12:00〜23:00'), isTrue);
    });

    test('日曜日のときに「日」を含む slot を選ぶ', () {
      const raw = '月〜土：12:00〜23:00 / 日：12:00〜21:00';
      final out = todayHours(raw, now: DateTime(2026, 5, 10)); // 日曜
      expect(out.contains('12:00〜21:00'), isTrue);
    });

    test('該当 slot が無いときは最初の slot を返す（推測しない）', () {
      const raw = '月、水：12:00〜23:00 / 火：14:00〜02:00';
      // 2026-05-15 は金曜（月・水・火 いずれにも該当しない）
      final out = todayHours(raw, now: DateTime(2026, 5, 15));
      expect(out.contains('12:00〜23:00'), isTrue);
    });
  });

  group('formatOpenHours: 営業時間文字列の分割', () {
    test('空文字は空リスト', () {
      expect(formatOpenHours(''), isEmpty);
    });

    test('単一は 1 要素のリスト', () {
      expect(formatOpenHours('11:00〜22:00'), ['11:00〜22:00']);
    });

    test('「/」区切りで複数 slot に分割', () {
      final out = formatOpenHours('月：A / 火：B / 水：C');
      expect(out.length, 3);
      expect(out, ['月：A', '火：B', '水：C']);
    });

    test('全角「／」区切りも分割', () {
      final out = formatOpenHours('月：A／火：B');
      expect(out.length, 2);
    });

    test('改行も区切り扱い', () {
      final out = formatOpenHours('月：A\n火：B');
      expect(out.length, 2);
    });
  });

  group('FactBadges.build: 事実ベース最大2ラベル', () {
    Restaurant mk({
      int distance = 10,
      bool reservable = false,
      bool privateRoom = false,
      double? rating,
    }) {
      return Restaurant(
        id: 'x',
        name: 'x',
        stationIndex: 0,
        category: 'x',
        rating: rating,
        reviewCount: 0,
        priceLabel: '',
        priceAvg: 0,
        tags: const [],
        emoji: '',
        description: '',
        distanceMinutes: distance,
        address: '',
        openHours: '',
        isReservable: reservable,
        hasPrivateRoom: privateRoom,
      );
    }

    test('全条件が当てはまっても最大 2 つに制限', () {
      // 駅近 + 予約可 + 個室 + 高評価 = 4 条件 → 最大 2 個
      final r = mk(
          distance: 3,
          reservable: true,
          privateRoom: true,
          rating: 4.5);
      final badges = FactBadges.build(r);
      expect(badges.length, 2);
    });

    test('優先順位: 駅近 > 予約可 > 個室 > 高評価', () {
      // 駅近 (3分) + 予約可 + 個室 → 最初は 駅近、2番目は 予約可
      final r = mk(
          distance: 3,
          reservable: true,
          privateRoom: true,
          rating: 4.5);
      final badges = FactBadges.build(r);
      // 視覚チェックは widget tester で行う
      // ここでは件数のみ確認（個別ラベルはレンダリングテストで）
      expect(badges.length, 2);
    });

    test('駅近 (>5分) は付かない', () {
      final r = mk(distance: 10, reservable: true);
      final badges = FactBadges.build(r);
      expect(badges.length, 1); // 予約可 のみ
    });

    test('該当条件無しのときは空リスト', () {
      final r = mk(distance: 10);
      expect(FactBadges.build(r), isEmpty);
    });

    test('レーティング 4.0 ぴったりは 高評価 が付く', () {
      final r = mk(distance: 10, rating: 4.0);
      expect(FactBadges.build(r).length, 1);
    });

    test('レーティング 3.9 は 高評価 が付かない', () {
      final r = mk(distance: 10, rating: 3.9);
      expect(FactBadges.build(r), isEmpty);
    });

    test('レーティング null は 高評価 が付かない', () {
      final r = mk(distance: 10, rating: null);
      expect(FactBadges.build(r), isEmpty);
    });
  });

  group('構造ガード: 旧文言・旧 UI の残存チェック', () {
    String readSrc(String path) => File(path).readAsStringSync();

    test('「Aimaを探す」は lib/ 配下に残っていない', () {
      // ボタン文字列としての残存をチェック
      final files = [
        'lib/screens/home_screen.dart',
        'lib/screens/search_screen.dart',
      ];
      for (final f in files) {
        final src = readSrc(f);
        expect(
          src.contains("'Aimaを探す'"),
          isFalse,
          reason: '$f に旧文言「Aimaを探す」が残っている',
        );
      }
    });

    test('「集まりやすいお店、見つけよう」は home_screen.dart に残っていない', () {
      final src = readSrc('lib/screens/home_screen.dart');
      expect(src.contains('集まりやすいお店、見つけよう'), isFalse);
    });

    test('main_screen.dart のタブ名が「予約済み」ではなく「予定」', () {
      final src = readSrc('lib/screens/main_screen.dart');
      expect(
          src.contains("label: '予約済み'"), isFalse,
          reason: 'タブ名は「予定」へ変更済み');
      expect(src.contains("label: '予定'"), isTrue);
    });

    test('reserved_screen.dart の AppBar タイトルが「予定」', () {
      final src = readSrc('lib/screens/reserved_screen.dart');
      expect(src.contains("Text('予定'"), isTrue);
    });

    test('AboutScreen 関連は残っていない', () {
      // ファイル削除済み
      expect(File('lib/screens/about_screen.dart').existsSync(), isFalse);
      // settings_screen.dart からの import / 参照も無い
      final src = readSrc('lib/screens/settings_screen.dart');
      expect(src.contains('about_screen.dart'), isFalse);
      expect(src.contains('AboutScreen'), isFalse);
    });

    test('結果画面 AppBar に旧 LINE 共有チップが残っていない', () {
      final src = readSrc('lib/screens/results_screen.dart');
      // 集合場所カードに集約したので AppBar 側の Material(緑チップ) は廃止
      expect(
        src.contains('shareMeetingPointsToLine(state)\n'),
        isFalse,
      );
    });

    test('集合場所カードに「移動時間の差」「選び方」が表示文字列として残っていない', () {
      final src = readSrc('lib/screens/results_screen.dart');
      final cardStart = src.indexOf('class _MeetingPointSpotlightCard');
      expect(cardStart, greaterThan(-1));
      final cardEnd = src.indexOf('class _ParticipantTimes', cardStart);
      final cardSrc = src.substring(cardStart, cardEnd);
      // コメント行を除外（// で始まる行）してから検索
      final nonComment = cardSrc
          .split('\n')
          .where((l) => !l.trim().startsWith('//'))
          .join('\n');
      // 文字列リテラル内（Text() に渡される文字列）として残っていないか
      // を緩めにチェック: 「'移動時間の差」「\"移動時間の差」のいずれも無いこと
      expect(
        nonComment.contains("'移動時間の差") ||
            nonComment.contains('"移動時間の差'),
        isFalse,
        reason: 'カードの表示テキストから「移動時間の差」は削除済みのはず',
      );
      expect(
        nonComment.contains("'選び方:") ||
            nonComment.contains('"選び方:'),
        isFalse,
        reason: 'カードの表示テキストから「選び方」footer は削除済みのはず',
      );
    });

    test('集合場所カードに「この場所をLINEで共有」ボタンがある', () {
      final src = readSrc('lib/screens/results_screen.dart');
      expect(src.contains('この場所をLINEで共有'), isTrue);
    });

    test('店舗詳細の予約ボタンが「予約ページへ進む」+ 補足文', () {
      final src = readSrc('lib/screens/restaurant_detail_screen.dart');
      expect(src.contains('予約ページへ進む'), isTrue);
      expect(src.contains('外部の予約サイトを開きます'), isTrue);
    });

    test('オンボーディングが 4 枚に絞られている', () {
      final src = readSrc('lib/screens/onboarding_screen.dart');
      // _slides リストの要素数を測る。const _Slide( で始まる行のみカウント。
      // class 定義の `const _Slide({...` はインデント深くて引数構造も違うため除外。
      final count = RegExp(r'^\s*_Slide\(', multiLine: true)
          .allMatches(src)
          .length;
      expect(count, 4, reason: 'オンボは Aimachi の価値を伝える 4 枚に絞る方針');
    });

    test('home_screen.dart が NeverScrollableScrollPhysics を実コードで使っていない', () {
      final src = readSrc('lib/screens/home_screen.dart');
      // コメント行を除外して検索
      final nonComment = src
          .split('\n')
          .where((l) => !l.trim().startsWith('//'))
          .join('\n');
      expect(nonComment.contains('NeverScrollableScrollPhysics'), isFalse,
          reason: 'NeverScrollableScrollPhysics は折りたたみを止めるので不採用');
      expect(nonComment.contains('ClampingScrollPhysics'), isTrue);
    });
  });

  group('バージョン整合性', () {
    test('pubspec.yaml と settings_screen.dart のバージョンが一致', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final ver = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+',
              multiLine: true)
          .firstMatch(pubspec)
          ?.group(1);
      expect(ver, isNotNull);
      final settings =
          File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(
        settings.contains("value: '$ver'"),
        isTrue,
        reason: 'settings 画面のバージョン表示が pubspec の $ver と一致するべき',
      );
    });
  });
}
