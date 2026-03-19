import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'participantNames': participantNames,
        'meetingPoint': meetingPoint.toJson(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        participantNames: List<String>.from(j['participantNames'] as List),
        meetingPoint:
            MeetingPoint.fromJson(j['meetingPoint'] as Map<String, dynamic>),
      );
}

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  static const _key = 'history_v1';

  @override
  List<HistoryEntry> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      state = raw
          .map((s) => HistoryEntry.fromJson(
              jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('HistoryNotifier: _load failed - ${e.runtimeType}');
      state = [];
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, state.map((e) => jsonEncode(e.toJson())).toList());
    } catch (e) {
      debugPrint('HistoryNotifier: _save failed - ${e.runtimeType}');
    }
  }

  void add(List<String> names, MeetingPoint point) {
    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      participantNames: names,
      meetingPoint: point,
    );
    state = [entry, ...state];
    _save();
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    _save();
  }
}

final historyProvider =
    NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);
