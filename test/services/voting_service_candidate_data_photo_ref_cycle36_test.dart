// TDD Red フェーズ — Cycle 36: VotingService.createSession の candidateData が
// Firestore に API キーを書き出さない（PhotoRef.toRef 経由）
//
// 背景（Critic CRITICAL — Cycle 35 残存リーク経路）:
//   `lib/services/voting_service.dart:25` が
//     'imageUrl': s.restaurant.imageUrl ?? ''
//   と Map リテラル直書きしており、`Restaurant.imageUrl` に Hotpepper フォールバック
//   と Google Places の URL（末尾に `&key=$apiKey`）が混在し得る現状では、
//   `voting_sessions/{id}.candidates[].imageUrl` フィールドへ API キー入りの URL が
//   そのまま書かれる。
//
//   さらに `firestore.rules:16` は `voting_sessions` を「認証済み任意ユーザーが
//   read 可」に開放しているため、投票リンクで参加した第三者を含めて誰でも
//   `&key=...` を読み取れる。
//
//   Cycle 35 の構造ガード（toJson( ブロック起点抽出）はサービス層 Map リテラル
//   直書きを **設計上検出不能** なため、本サイクルで:
//     - createSession の candidateData 構築を `PhotoRef.toRef` 経由化
//     - サービス層を含む `lib/` 全域 Map リテラル `'imageUrl':` の構造ガード
//   の両方を入れる。
//
// このファイルの責務:
//   - createSession が組み立てる candidateData の `imageUrl` フィールドが
//     PhotoRef.toRef 経由で正規化されることを **ランタイム** に担保する。
//   - Firebase 初期化を要求しないよう、Engineer は createSession 内部の Map
//     構築ロジックを `@visibleForTesting` の静的ヘルパー
//     `VotingService.buildCandidateData(List<ScoredRestaurant>)` に切り出す
//     ことで Red を Green にする想定。
//     （createSession 自体は当該ヘルパーを呼び出すだけのリファクタとなる）
//
// 受入条件:
//   [A] Google Places URL を渡しても candidateData['imageUrl'] に `&key=` が
//       一切含まれない（API キー流出経路の遮断）
//   [B] Google Places URL は `places/{placeId}/photos/{photoId}` reference 形式に
//       正規化されて保存される
//   [C] Hotpepper の URL（キー不要）はそのまま保存される
//   [D] imageUrl が null のときは空文字 '' で保存される（既存挙動互換）
//
// 不変項（侵してはならない）:
//   - VotingService の他メソッド（vote / closeSession / watchSession / getSession）の
//     シグネチャ・挙動は変更しない
//   - candidateData の他フィールド（id / name / category / priceStr / address /
//     votes / voters）の値は変更しない
//   - Cycle 27〜30 / 33 / 34 / 35 の snapshot 全サブテストは 1 バイト不変
//
// 参考:
//   - lib/utils/photo_ref.dart の PhotoRef.toRef は
//       Google: 'https://places.googleapis.com/v1/places/X/photos/Y/media?...&key=...'
//         → 'places/X/photos/Y'
//       Hotpepper / その他: そのまま返す
//     と動作する純関数。

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/models/scored_restaurant.dart';
import 'package:mannaka/services/voting_service.dart';

const _googleUrl =
    'https://places.googleapis.com/v1/places/ChIJvotingABC/photos/AeYy_VotePhoto/media?maxWidthPx=800&key=DUMMY_LEAKED_KEY_CYCLE36_VOTING';
const _hotpepperUrl = 'https://imgfp.hotp.jp/IMGH/voting/example.jpg';

Restaurant _restaurant({String? imageUrl}) => Restaurant(
      id: 'r-vote-1',
      name: '投票候補テスト店',
      stationIndex: 0,
      category: 'カフェ',
      rating: 4.0,
      reviewCount: 50,
      priceLabel: '¥¥',
      priceAvg: 3000,
      tags: const [],
      emoji: '🍽️',
      description: 'テスト用',
      distanceMinutes: 5,
      address: '東京都千代田区1-1',
      openHours: '11:00-23:00',
      imageUrl: imageUrl,
    );

ScoredRestaurant _scored({String? imageUrl}) => ScoredRestaurant(
      restaurant: _restaurant(imageUrl: imageUrl),
      score: 0.8,
      distanceKm: 0.4,
      participantDistances: const {},
      fairnessScore: 0.8,
    );

void main() {
  group('Cycle 36: VotingService.buildCandidateData が API キーを Firestore に書き出さない',
      () {
    // ──────────────────────────────────────────────────────────────────
    // [A] `&key=` 完全排除
    // ──────────────────────────────────────────────────────────────────
    test('Google Places URL を渡しても candidateData[0].imageUrl に `&key=` が一切含まれない',
        () {
      final list = VotingService.buildCandidateData([_scored(imageUrl: _googleUrl)]);
      expect(list, hasLength(1),
          reason: 'candidateData は 1 件返るはず');
      final saved = list.first['imageUrl'] as String?;
      expect(saved, isNotNull,
          reason: 'imageUrl を渡したのに candidateData に保存されていない');
      expect(
        saved!.contains('&key='),
        isFalse,
        reason: 'VotingService.buildCandidateData の imageUrl に `&key=` が残っています:\n'
            '  $saved\n\n'
            'createSession 内の Map 構築で PhotoRef.toRef を経由してください。\n'
            'firestore.rules は voting_sessions を任意の認証ユーザーに read 開放しているため、\n'
            '投票リンクから入った第三者が API キーを読み出せる経路になります。',
      );
      expect(
        saved.contains('DUMMY_LEAKED_KEY_CYCLE36_VOTING'),
        isFalse,
        reason: 'candidateData[].imageUrl に元のキー文字列がそのまま入っています:\n  $saved',
      );
      // 全フィールド出力にもキーが残っていないこと（保険）
      final whole = list.first.toString();
      expect(whole.contains('&key='), isFalse,
          reason: 'candidateData 全体の文字列表現にも `&key=` が混入しています:\n$whole');
    });

    // ──────────────────────────────────────────────────────────────────
    // [B] Google Places URL → reference 形式
    // ──────────────────────────────────────────────────────────────────
    test('Google Places URL は `places/{placeId}/photos/{photoId}` reference 形式に正規化される',
        () {
      final list = VotingService.buildCandidateData([_scored(imageUrl: _googleUrl)]);
      final saved = list.first['imageUrl'] as String?;

      expect(
        saved,
        equals('places/ChIJvotingABC/photos/AeYy_VotePhoto'),
        reason: 'Google Places の写真 URL は reference 形式に正規化して保存してください。\n'
            '実値: $saved',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [C] Hotpepper URL（キー不要）はそのまま保存
    // ──────────────────────────────────────────────────────────────────
    test('Hotpepper の URL（キー不要）はそのまま保存される', () {
      final list =
          VotingService.buildCandidateData([_scored(imageUrl: _hotpepperUrl)]);
      final saved = list.first['imageUrl'] as String?;

      expect(
        saved,
        equals(_hotpepperUrl),
        reason: 'Hotpepper の写真 URL は API キーを含まないのでそのまま保存して問題ない。\n'
            'PhotoRef.toRef は Google Places 以外の URL を素通しする純関数。',
      );
    });

    // ──────────────────────────────────────────────────────────────────
    // [D] imageUrl が null
    // ──────────────────────────────────────────────────────────────────
    test('imageUrl が null のとき candidateData[].imageUrl は空文字 '
        '\'\' で保存される（既存挙動互換）', () {
      final list = VotingService.buildCandidateData([_scored(imageUrl: null)]);
      final saved = list.first['imageUrl'];

      expect(
        saved,
        equals(''),
        reason: 'imageUrl が null のときは空文字 \'\' で保存される既存挙動を維持してください。\n'
            'PhotoRef.toRef(\'\') は \'\' をそのまま返すため、null → \'\' → toRef(\'\') == \'\' で\n'
            '従来挙動と一致します。\n'
            '実値: $saved',
      );
    });
  });
}
