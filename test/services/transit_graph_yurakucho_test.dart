import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/data/transit_graph_data.dart';
import 'package:mannaka/services/transit_router.dart';

void main() {
  // ── 有楽町線エッジ補完テスト ────────────────────────────────────────────────
  //
  // 有楽町線の補完区間（今回追加）:
  //   池袋 →[1]→ 東池袋 →[3]→ 護国寺 →[3]→ 江戸川橋 →[4]→ 飯田橋
  //   飯田橋 →[3]→ 市ヶ谷 →[3]→ 麹町 →[3]→ 永田町
  //   永田町 →[3]→ 桜田門 →[3]→ 有楽町 →[2]→ 銀座一丁目 →[2]→ 新富町 →[5]→ 月島
  //
  // kTransitGraph の構造テスト（実装ファイル変更の確認）と
  // 有楽町線を使った kStations 間の経路改善テストの2軸で検証する。

  group('有楽町線グラフ構造テスト（kTransitGraph）', () {
    test('池袋から東池袋への有楽町線エッジが存在する', () {
      final edges = kTransitGraph['池袋'] ?? [];
      final yurakuchoEdges =
          edges.where((e) => e.to == '東池袋' && e.lineId == 'yurakucho').toList();
      expect(yurakuchoEdges, isNotEmpty,
          reason: '池袋→東池袋の有楽町線エッジが kTransitGraph に存在すること');
      expect(yurakuchoEdges.first.minutes, lessThanOrEqualTo(2),
          reason: '池袋→東池袋は1分（有楽町線の隣駅）');
    });

    test('東池袋ノードが護国寺・池袋への有楽町線エッジを持つ', () {
      final edges = kTransitGraph['東池袋'] ?? [];
      expect(edges, isNotEmpty, reason: '東池袋ノードが kTransitGraph に存在すること');
      final toGokokuji =
          edges.where((e) => e.to == '護国寺' && e.lineId == 'yurakucho').toList();
      final toIkebukuro =
          edges.where((e) => e.to == '池袋' && e.lineId == 'yurakucho').toList();
      expect(toGokokuji, isNotEmpty, reason: '東池袋→護国寺の有楽町線エッジ');
      expect(toIkebukuro, isNotEmpty, reason: '東池袋→池袋の有楽町線エッジ（双方向）');
    });

    test('江戸川橋ノードが飯田橋への有楽町線エッジを持つ', () {
      final edges = kTransitGraph['江戸川橋'] ?? [];
      expect(edges, isNotEmpty, reason: '江戸川橋ノードが kTransitGraph に存在すること');
      final toIidabashi =
          edges.where((e) => e.to == '飯田橋' && e.lineId == 'yurakucho').toList();
      expect(toIidabashi, isNotEmpty, reason: '江戸川橋→飯田橋の有楽町線エッジ');
    });

    test('飯田橋が市ヶ谷への有楽町線エッジを持つ', () {
      final edges = kTransitGraph['飯田橋'] ?? [];
      final toIchigaya =
          edges.where((e) => e.to == '市ヶ谷' && e.lineId == 'yurakucho').toList();
      expect(toIchigaya, isNotEmpty,
          reason: '飯田橋→市ヶ谷の有楽町線エッジが kTransitGraph に存在すること');
    });

    test('有楽町が桜田門・銀座一丁目への有楽町線エッジを持つ', () {
      final edges = kTransitGraph['有楽町'] ?? [];
      final toSakuradamon =
          edges.where((e) => e.to == '桜田門' && e.lineId == 'yurakucho').toList();
      final toGinzaItchome =
          edges.where((e) => e.to == '銀座一丁目' && e.lineId == 'yurakucho').toList();
      expect(toSakuradamon, isNotEmpty,
          reason: '有楽町→桜田門の有楽町線エッジが kTransitGraph に存在すること');
      expect(toGinzaItchome, isNotEmpty,
          reason: '有楽町→銀座一丁目の有楽町線エッジが kTransitGraph に存在すること');
    });

    test('永田町が麹町・桜田門への有楽町線エッジを持つ', () {
      final edges = kTransitGraph['永田町'] ?? [];
      final toKojimachi =
          edges.where((e) => e.to == '麹町' && e.lineId == 'yurakucho').toList();
      final toSakuradamon =
          edges.where((e) => e.to == '桜田門' && e.lineId == 'yurakucho').toList();
      expect(toKojimachi, isNotEmpty,
          reason: '永田町→麹町の有楽町線エッジが kTransitGraph に存在すること');
      expect(toSakuradamon, isNotEmpty,
          reason: '永田町→桜田門の有楽町線エッジが kTransitGraph に存在すること');
    });

    test('市ヶ谷が麹町への有楽町線エッジを持つ（kTransitGraph）', () {
      final edges = kTransitGraph['市ヶ谷'] ?? [];
      final toKojimachi =
          edges.where((e) => e.to == '麹町' && e.lineId == 'yurakucho').toList();
      expect(toKojimachi, isNotEmpty,
          reason: '市ヶ谷→麹町の有楽町線エッジが kTransitGraph に存在すること');
    });

    test('月島が新富町への有楽町線エッジを持つ（逆方向エッジの確認）', () {
      // 新富町→月島 は存在するが、月島→新富町 の逆エッジが必要
      final edges = kTransitGraph['月島'] ?? [];
      expect(edges, isNotEmpty,
          reason: '月島ノードが kTransitGraph に存在すること');
      final toShintomicho =
          edges.where((e) => e.to == '新富町' && e.lineId == 'yurakucho').toList();
      expect(toShintomicho, isNotEmpty,
          reason: '月島→新富町の有楽町線エッジが kTransitGraph に存在すること（逆方向エッジ欠落の修正）');
    });
  });

  group('有楽町線を使ったkStations間の経路改善テスト', () {
    // routeFromStation は kStations のみを返す設計のため、
    // 有楽町線の恩恵を受ける kStations 間の経路時間で検証する

    test('池袋から飯田橋への経路が有楽町線経由で15分以内', () {
      // 有楽町線なし: 池袋→山手線→高田馬場→東西線→飯田橋 ≈ 17分以上
      // 有楽町線あり: 池袋→東池袋(1)→護国寺(3)→江戸川橋(3)→飯田橋(4) = 11分
      final routes = TransitRouter.instance.routeFromStation('池袋');
      final time = routes['飯田橋'];
      expect(time, isNotNull, reason: '池袋から飯田橋への経路が存在すること');
      expect(time!, lessThanOrEqualTo(15),
          reason: '有楽町線経由で池袋→飯田橋は約11分。現在: $time分');
    });

    test('池袋から九段下への経路が有楽町線経由で改善される（25分以内）', () {
      // 有楽町線あり: 池袋→飯田橋(11)→九段下(tozai, 3+5penalty=8) = 19分
      // ※ 東西線と有楽町線の乗り換えペナルティが加算される
      final routes = TransitRouter.instance.routeFromStation('池袋');
      final time = routes['九段下'];
      expect(time, isNotNull, reason: '池袋から九段下への経路が存在すること');
      expect(time!, lessThanOrEqualTo(25),
          reason: '有楽町線経由 + 乗換で池袋→九段下。現在: $time分');
    });

    test('池袋から四ッ谷への有楽町線+南北線経由が30分以内', () {
      // 有楽町線: 池袋→飯田橋(11)→市ヶ谷(14)→南北線→四ッ谷
      // ※ 有楽町線と南北線の乗り換えペナルティあり
      final routes = TransitRouter.instance.routeFromStation('池袋');
      final time = routes['四ッ谷'];
      expect(time, isNotNull, reason: '池袋から四ッ谷への経路が存在すること');
      expect(time!, lessThanOrEqualTo(30),
          reason: '有楽町線+南北線経由で池袋→四ッ谷。現在: $time分');
    });

    test('池袋から神保町への有楽町線経由が改善される（25分以内）', () {
      // 有楽町線あり: 池袋→飯田橋(11)→東西線→神保町? 神保町は飯田橋から近い
      // 有楽町線の恩恵でこのエリアへのアクセスが改善する
      final routes = TransitRouter.instance.routeFromStation('池袋');
      final time = routes['神保町'];
      expect(time, isNotNull, reason: '池袋から神保町への経路が存在すること');
      expect(time!, lessThanOrEqualTo(25),
          reason: '有楽町線経由で池袋→神保町。現在: $time分');
    });
  });
}
