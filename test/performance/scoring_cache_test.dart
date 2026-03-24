// TDD Red フェーズ
// Cycle 22: 地図画面・結果画面パフォーマンス最適化
//
// スコープ:
//   sortOption / isCalculating / loadingMessage など
//   「スコアリング入力」に無関係なフィールドが変わっても
//   SearchState.scoredRestaurants が毎回 MidpointService.scoreRestaurants を
//   呼び直すという無駄な再計算を検出し、キャッシュ化を強制する。
//
// 現状:
//   SearchState は `late final scoredRestaurants = _computeScored()` を使って
//   インスタンス内ではキャッシュする。しかし copyWith() は毎回新インスタンスを
//   生成するため、sortOption 変更などでも _computeScored() が再実行される。
//
// 期待する改善:
//   スコアリング入力（participants, centroid, hotpepperRestaurants, categories,
//   occasion, maxBudget, timeSlot, showPrivateRoom, selectedDate）が
//   変わっていない場合、copyWith 後の scoredRestaurants は前の状態と
//   identical（同じオブジェクト参照）であるべき。

import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/participant.dart';
import 'package:mannaka/models/restaurant.dart';
import 'package:mannaka/providers/search_provider.dart';

// テスト用の固定データ
const _participants = [
  Participant(id: '1', name: 'Alice', lat: 35.658, lng: 139.701),
  Participant(id: '2', name: 'Bob', lat: 35.681, lng: 139.767),
];

const _restaurants = [
  Restaurant(
    id: 'r1',
    name: 'テスト店A',
    stationIndex: 0,
    category: '和食',
    rating: 4.0,
    reviewCount: 100,
    priceLabel: '¥3,000',
    priceAvg: 3000,
    tags: [],
    emoji: '',
    description: 'テスト',
    distanceMinutes: 5,
    address: '東京都渋谷区',
    openHours: '11:00-23:00',
    lat: 35.660,
    lng: 139.700,
    isReservable: true,
  ),
  Restaurant(
    id: 'r2',
    name: 'テスト店B',
    stationIndex: 4,
    category: 'イタリアン',
    rating: 3.5,
    reviewCount: 50,
    priceLabel: '¥4,000',
    priceAvg: 4000,
    tags: [],
    emoji: '',
    description: 'テスト',
    distanceMinutes: 3,
    address: '東京都千代田区',
    openHours: '17:00-23:00',
    lat: 35.681,
    lng: 139.767,
    isReservable: false,
  ),
];

/// スコアリング入力が揃った基準 SearchState を生成するヘルパー
SearchState _baseState({SortOption sort = SortOption.recommended}) {
  return SearchState(
    participants: _participants,
    centroidLat: 35.6695,
    centroidLng: 139.734,
    hotpepperRestaurants: _restaurants,
    sortOption: sort,
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // グループ1: 同一インスタンス内のキャッシュ（late final の基本動作 — GREEN）
  // ─────────────────────────────────────────────────────────────────────────
  group('SearchState.scoredRestaurants — 同一インスタンス内キャッシュ', () {
    test(
      '同じ SearchState インスタンスに2回アクセスすると '
      '同一オブジェクトを返す（late final による保証）',
      () {
        final state = _baseState();
        final first = state.scoredRestaurants;
        final second = state.scoredRestaurants;
        // late final なので同一インスタンス内では常に同じオブジェクト → GREEN
        expect(identical(first, second), isTrue,
            reason: 'late final により同一インスタンス内の2回目以降は再計算不要');
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // グループ2: ソート変更での不要な再計算を防ぐ（★ 現在は RED ★）
  // ─────────────────────────────────────────────────────────────────────────
  group('SearchState.scoredRestaurants — sortOption 変更時の不要再計算', () {
    test(
      'sortOption だけ変えたとき scoredRestaurants は '
      '再計算されず同一オブジェクトを返す',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants; // 初回計算

        // sortOption のみ変更 — スコアリング入力は一切変わっていない
        final state2 = state1.copyWith(sortOption: SortOption.rating);

        // ★ 現在は copyWith が新インスタンスを作るため _computeScored が再実行 → RED ★
        expect(
          identical(state2.scoredRestaurants, scored1),
          isTrue,
          reason: 'sortOption はスコアリング入力ではないため、'
              'scoredRestaurants は再計算されるべきでない',
        );
      },
    );

    test(
      'sortOption を推奨 → 距離 → 価格 と連続で変えても '
      'scoredRestaurants は常に初回計算の同一オブジェクトを返す',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final state2 = state1.copyWith(sortOption: SortOption.distance);
        final state3 = state2.copyWith(sortOption: SortOption.budget);
        final state4 = state3.copyWith(sortOption: SortOption.recommended);

        // ★ すべて RED ★
        expect(identical(state2.scoredRestaurants, scored1), isTrue,
            reason: 'SortOption.distance 変更後も scoredRestaurants は同一オブジェクト');
        expect(identical(state3.scoredRestaurants, scored1), isTrue,
            reason: 'SortOption.budget 変更後も scoredRestaurants は同一オブジェクト');
        expect(identical(state4.scoredRestaurants, scored1), isTrue,
            reason: 'SortOption.recommended 変更後も scoredRestaurants は同一オブジェクト');
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // グループ3: 表示状態変更での不要な再計算を防ぐ（★ 現在は RED ★）
  // ─────────────────────────────────────────────────────────────────────────
  group('SearchState.scoredRestaurants — 表示状態変更時の不要再計算', () {
    test(
      'isCalculating だけ変えたとき scoredRestaurants は再計算されない',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final state2 = state1.copyWith(isCalculating: true);

        // ★ 現在は RED ★
        expect(
          identical(state2.scoredRestaurants, scored1),
          isTrue,
          reason: 'isCalculating はスコアリング入力ではない',
        );
      },
    );

    test(
      'errorMessage だけ変えたとき scoredRestaurants は再計算されない',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final state2 = state1.copyWith(errorMessage: 'テストエラー');

        // ★ 現在は RED ★
        expect(
          identical(state2.scoredRestaurants, scored1),
          isTrue,
          reason: 'errorMessage はスコアリング入力ではない',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // グループ4: スコアリング入力変更時は必ず再計算する（ガードテスト — GREEN）
  // これらが GREEN のまま保たれることを確認する（キャッシュ実装後も通ること）
  // ─────────────────────────────────────────────────────────────────────────
  group('SearchState.scoredRestaurants — スコアリング入力変更時の再計算', () {
    test(
      'participants が変わったとき scoredRestaurants は別オブジェクト（再計算あり）',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final newParticipants = [
          const Participant(id: '1', name: 'Alice', lat: 35.700, lng: 139.800),
          const Participant(id: '2', name: 'Bob', lat: 35.720, lng: 139.820),
        ];
        final state2 = state1.copyWith(
          participants: newParticipants,
          centroidLat: 35.710,
          centroidLng: 139.810,
        );

        // 参加者が変わったら別オブジェクト（再計算が必要）→ 現在は GREEN
        expect(
          identical(state2.scoredRestaurants, scored1),
          isFalse,
          reason: 'participants 変更時は scoredRestaurants を再計算すべき',
        );
      },
    );

    test(
      'hotpepperRestaurants が変わったとき scoredRestaurants は別オブジェクト',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        const newRestaurants = [
          Restaurant(
            id: 'r3',
            name: 'テスト店C',
            stationIndex: 2,
            category: 'カフェ',
            rating: 4.5,
            reviewCount: 200,
            priceLabel: '¥2,000',
            priceAvg: 2000,
            tags: [],
            emoji: '',
            description: 'テスト',
            distanceMinutes: 2,
            address: '東京都新宿区',
            openHours: '08:00-22:00',
            lat: 35.690,
            lng: 139.720,
          ),
        ];
        final state2 =
            state1.copyWith(hotpepperRestaurants: newRestaurants);

        // レストランデータが変わったら再計算 → 現在は GREEN
        expect(
          identical(state2.scoredRestaurants, scored1),
          isFalse,
          reason: 'hotpepperRestaurants 変更時は scoredRestaurants を再計算すべき',
        );
      },
    );

    test(
      'centroidLat が変わったとき scoredRestaurants は別オブジェクト',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final state2 = state1.copyWith(centroidLat: 35.700);

        // 重心が変わったら再計算 → 現在は GREEN
        expect(
          identical(state2.scoredRestaurants, scored1),
          isFalse,
          reason: 'centroidLat 変更時は scoredRestaurants を再計算すべき',
        );
      },
    );

    test(
      'maxBudget が変わったとき scoredRestaurants は別オブジェクト',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final state2 = state1.copyWith(maxBudget: 3500);

        // maxBudget はハードフィルタに影響する → 再計算 → 現在は GREEN
        expect(
          identical(state2.scoredRestaurants, scored1),
          isFalse,
          reason: 'maxBudget 変更時は scoredRestaurants を再計算すべき',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // グループ5: sortedRestaurants のソート正確性（GREEN — 実装変更後も通ること）
  // ─────────────────────────────────────────────────────────────────────────
  group('SearchState.sortedRestaurants — ソート正確性', () {
    test(
      'SortOption.recommended のとき scoredRestaurants と同一要素・同一順序',
      () {
        final state = _baseState(sort: SortOption.recommended);
        final scored = state.scoredRestaurants;
        final sorted = state.sortedRestaurants;

        expect(sorted.length, scored.length);
        for (var i = 0; i < scored.length; i++) {
          expect(identical(sorted[i], scored[i]), isTrue,
              reason: 'recommended は scoredRestaurants の順序をそのまま使う');
        }
      },
    );

    test(
      'SortOption.distance のとき distanceKm 昇順になる',
      () {
        final state = _baseState(sort: SortOption.distance);
        final sorted = state.sortedRestaurants;

        for (var i = 0; i < sorted.length - 1; i++) {
          expect(
            sorted[i].distanceKm,
            lessThanOrEqualTo(sorted[i + 1].distanceKm),
            reason: 'distance ソートは distanceKm 昇順',
          );
        }
      },
    );

    test(
      'SortOption.rating のとき restaurant.rating 降順になる',
      () {
        final state = _baseState(sort: SortOption.rating);
        final sorted = state.sortedRestaurants;

        for (var i = 0; i < sorted.length - 1; i++) {
          expect(
            sorted[i].restaurant.rating,
            greaterThanOrEqualTo(sorted[i + 1].restaurant.rating),
            reason: 'rating ソートは rating 降順',
          );
        }
      },
    );

    test(
      'SortOption.budget のとき restaurant.priceAvg 昇順になる',
      () {
        final state = _baseState(sort: SortOption.budget);
        final sorted = state.sortedRestaurants;

        for (var i = 0; i < sorted.length - 1; i++) {
          expect(
            sorted[i].restaurant.priceAvg,
            lessThanOrEqualTo(sorted[i + 1].restaurant.priceAvg),
            reason: 'budget ソートは priceAvg 昇順',
          );
        }
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // グループ6: sortedRestaurants の不要再ソートを防ぐ（★ 現在は RED ★）
  // 非スコアリングフィールド（isCalculating, errorMessage）が変わっても
  // sortedRestaurants は前の状態と identical（同一オブジェクト参照）であるべき。
  // ─────────────────────────────────────────────────────────────────────────
  group('SearchState.sortedRestaurants — 非スコアリング変更時の不要再ソート', () {
    test(
      'isCalculating だけ変えたとき SortOption.distance の '
      'sortedRestaurants は同一オブジェクトを返す',
      () {
        final state1 = _baseState(sort: SortOption.distance);
        final sorted1 = state1.sortedRestaurants; // 初回ソート

        // isCalculating のみ変更 — ソート入力は一切変わっていない
        final state2 = state1.copyWith(isCalculating: true);

        // ★ 現在は copyWith が新インスタンスを作るため _computeSorted が再実行 → RED ★
        expect(
          identical(state2.sortedRestaurants, sorted1),
          isTrue,
          reason: 'isCalculating はソート入力ではないため、sortedRestaurants は再ソートされるべきでない',
        );
      },
    );

    test(
      'errorMessage だけ変えたとき SortOption.rating の '
      'sortedRestaurants は同一オブジェクトを返す',
      () {
        final state1 = _baseState(sort: SortOption.rating);
        final sorted1 = state1.sortedRestaurants;

        final state2 = state1.copyWith(errorMessage: 'テストエラー');

        // ★ 現在は RED ★
        expect(
          identical(state2.sortedRestaurants, sorted1),
          isTrue,
          reason: 'errorMessage はソート入力ではないため、sortedRestaurants は再ソートされるべきでない',
        );
      },
    );

    test(
      'isCalculating を true → false と連続で変えても '
      'SortOption.budget の sortedRestaurants は同一オブジェクトを返す',
      () {
        final state1 = _baseState(sort: SortOption.budget);
        final sorted1 = state1.sortedRestaurants;

        final state2 = state1.copyWith(isCalculating: true);
        final state3 = state2.copyWith(isCalculating: false);

        // ★ 現在は RED ★
        expect(identical(state2.sortedRestaurants, sorted1), isTrue,
            reason: 'isCalculating: true 変更後も sortedRestaurants は同一オブジェクト');
        expect(identical(state3.sortedRestaurants, sorted1), isTrue,
            reason: 'isCalculating: false 変更後も sortedRestaurants は同一オブジェクト');
      },
    );

    // ガードテスト: sortOption が変わったとき sortedRestaurants は別オブジェクト（GREEN）
    test(
      'sortOption が変わったとき sortedRestaurants は別オブジェクト（再ソートあり）',
      () {
        final state1 = _baseState(sort: SortOption.recommended);
        final sorted1 = state1.sortedRestaurants;

        final state2 = state1.copyWith(sortOption: SortOption.distance);

        // sortOption が変わったら別オブジェクト → 現在は GREEN
        expect(
          identical(state2.sortedRestaurants, sorted1),
          isFalse,
          reason: 'sortOption 変更時は sortedRestaurants を再ソートすべき',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // グループ7: フィルタ変更時のスコアリング再計算ガード（GREEN 確認・欠落補完）
  // showFemaleFriendly / occasion / timeSlot は isScoringUnchanged に含まれるため
  // 変更時は scoredRestaurants が必ず再計算される（別オブジェクト）。
  // これらのテストが欠落していたため、回帰防止として追加する。
  // ─────────────────────────────────────────────────────────────────────────
  group('SearchState.scoredRestaurants — フィルタ変更時の再計算ガード', () {
    test(
      'showFemaleFriendly が false → true になったとき '
      'scoredRestaurants は別オブジェクト（再計算あり）',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final state2 = state1.copyWith(showFemaleFriendly: true);

        expect(
          identical(state2.scoredRestaurants, scored1),
          isFalse,
          reason: 'showFemaleFriendly はスコアリング入力（femaleFriendlyフィルタに影響）のため再計算すべき',
        );
      },
    );

    test(
      'occasion が none → girlsNight になったとき '
      'scoredRestaurants は別オブジェクト（再計算あり）',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final state2 = state1.copyWith(occasion: Occasion.girlsNight);

        expect(
          identical(state2.scoredRestaurants, scored1),
          isFalse,
          reason: 'occasion はスコアリング入力（filterFemale/filterPrivateに影響）のため再計算すべき',
        );
      },
    );

    test(
      'timeSlot が all → dinner になったとき '
      'scoredRestaurants は別オブジェクト（再計算あり）',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final state2 = state1.copyWith(timeSlot: TimeSlot.dinner);

        expect(
          identical(state2.scoredRestaurants, scored1),
          isFalse,
          reason: 'timeSlot はスコアリング入力（営業時間フィルタに影響）のため再計算すべき',
        );
      },
    );

    test(
      'showPrivateRoom が false → true になったとき '
      'scoredRestaurants は別オブジェクト（再計算あり）',
      () {
        final state1 = _baseState();
        final scored1 = state1.scoredRestaurants;

        final state2 = state1.copyWith(showPrivateRoom: true);

        expect(
          identical(state2.scoredRestaurants, scored1),
          isFalse,
          reason: 'showPrivateRoom はスコアリング入力（個室フィルタに影響）のため再計算すべき',
        );
      },
    );
  });
}
