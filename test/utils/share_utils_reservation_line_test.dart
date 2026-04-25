// TDD テスト: ShareUtils.buildReservationLineText
//
// 仕様:
//   Hotpepper で予約 → Aimachi に戻る → LINE 共有 のフローで、
//   LINE 本文に以下を入れる:
//     1. 「Aimachiで予約しました」のヘッダー
//     2. お店情報（店名・カテゴリ・最寄り駅・徒歩分）
//     3. 予約日時（meetingDate と meetingTime、片方だけでも OK）
//     4. チーム（groupNames）
//     5. Google Maps リンク（lat/lng があれば）
//
//   いずれの項目も「データが無い場合は黙って省く」のがルール。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/utils/share_utils.dart';

void main() {
  group('ShareUtils.buildReservationLineText — 予約済みLINE本文の組立', () {
    test('全フィールド埋まっているとき ヘッダー・店舗情報・日時・チーム・地図リンクが含まれる',
        () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'まんなか食堂',
        category: 'イタリアン',
        stationName: '渋谷',
        walkMinutes: 5,
        lat: 35.6580,
        lng: 139.7016,
        meetingDate: DateTime(2026, 4, 30),
        meetingTime: const TimeOfDay(hour: 19, minute: 30),
        groupNames: const ['あや', 'ゆう', 'たく'],
      );

      expect(text, contains('Aimachiで予約しました'),
          reason: 'ヘッダーで「Aimachiで予約した」事実が伝わるべき');
      expect(text, contains('まんなか食堂'), reason: '店名は必須');
      expect(text, contains('イタリアン'), reason: 'カテゴリも入れる');
      expect(text, contains('渋谷駅'), reason: '最寄り駅情報を含める');
      expect(text, contains('徒歩5分'), reason: '徒歩時間を含める');
      expect(text, contains('4/30'), reason: '日付は M/D 形式');
      expect(text, contains('19:30'), reason: '時刻は HH:MM 形式');
      expect(text, contains('あや'), reason: 'チームメンバー名を含める');
      expect(text, contains('ゆう'), reason: 'チームメンバー名を含める');
      expect(text, contains('たく'), reason: 'チームメンバー名を含める');
      expect(text, contains('maps.google.com'), reason: '地図リンクを含める');
    });

    test('日付だけあって時刻が無いとき 日付だけが表示される', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: DateTime(2026, 5, 10),
        meetingTime: null,
        groupNames: const [],
      );
      expect(text, contains('5/10'));
      expect(text, isNot(contains(':')),
          reason: '時刻が無いときは時刻フォーマットが現れない');
    });

    test('時刻だけあって日付が無いとき 時刻だけが表示される', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: const TimeOfDay(hour: 8, minute: 5),
        groupNames: const [],
      );
      expect(text, contains('08:05'),
          reason: '時刻は 0 パディング付き HH:MM 形式');
    });

    test('日時もチームも無いとき 該当行が出ない', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: 'カフェ',
        stationName: '新宿',
        walkMinutes: 3,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );
      expect(text, isNot(contains('🗓')),
          reason: '日時アイコン行は data がないときは出ない');
      expect(text, isNot(contains('👥')),
          reason: 'チームアイコン行は data がないときは出ない');
      expect(text, contains('テスト店'));
      expect(text, contains('新宿駅'));
    });

    test('lat/lng が片方欠けているとき 地図リンクは出ない', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: 35.0,
        lng: null, // 欠損
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );
      expect(text, isNot(contains('maps.google.com')),
          reason: '緯度経度のどちらかが null なら地図 URL は組まない');
    });

    test('walkMinutes が 0 以下のとき 徒歩行は出ない', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '池袋',
        walkMinutes: 0,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const [],
      );
      expect(text, contains('池袋駅'));
      expect(text, isNot(contains('徒歩')),
          reason: 'walkMinutes が 0 のときは徒歩表記を省く');
    });

    test('groupNames に空文字が混ざっていても 空文字は表示しない', () {
      final text = ShareUtils.buildReservationLineText(
        restaurantName: 'テスト店',
        category: '',
        stationName: '',
        walkMinutes: null,
        lat: null,
        lng: null,
        meetingDate: null,
        meetingTime: null,
        groupNames: const ['あや', '', 'ゆう'],
      );
      // 区切り文字「、」が連続しないこと（"あや、、ゆう" にならない）
      expect(text, isNot(contains('、、')),
          reason: '空名は黙って除外する。区切りが二重になるのは UI バグ');
      expect(text, contains('あや'));
      expect(text, contains('ゆう'));
    });
  });
}
