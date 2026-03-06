import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meeting_point.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.participantNames,
    required this.meetingPoint,
  });

  final String id;
  final DateTime createdAt;
  final List<String> participantNames;
  final MeetingPoint meetingPoint;
}

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  @override
  List<HistoryEntry> build() => [];

  void add(List<String> names, MeetingPoint point) {
    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      participantNames: names,
      meetingPoint: point,
    );
    state = [entry, ...state];
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);
