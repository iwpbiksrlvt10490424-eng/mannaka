/// 隣接する駅間のエッジ（Dijkstra用）
class TransitEdge {
  final String to;
  final int minutes;
  final String lineId;
  const TransitEdge(this.to, this.minutes, this.lineId);
}
