import '../config/secrets.dart';
import '../utils/photo_ref.dart';

/// LINE で送る前に保留した候補シェアの下書き。
/// あとで送信したいユーザー向けに SharedPreferences にローカル保存する。
class SavedShareDraft {
  const SavedShareDraft({
    required this.id,
    required this.createdAt,
    required this.stationName,
    required this.date,
    required this.meetingTime,
    required this.participantTimes,
    required this.candidates,
    required this.note,
  });

  final String id;
  final DateTime createdAt;
  final String stationName;
  /// ISO8601 文字列（日付なしは空）
  final String date;
  /// HH:mm（時刻なしは空）
  final String meetingTime;
  /// 参加者名 → 移動分数
  final Map<String, int> participantTimes;
  /// 候補レストランの最小表現（保存・復元できる軽量データ）
  final List<SavedShareCandidate> candidates;
  /// 任意メモ
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'stationName': stationName,
        'date': date,
        'meetingTime': meetingTime,
        'participantTimes': participantTimes,
        'candidates': candidates.map((c) => c.toJson()).toList(),
        'note': note,
      };

  factory SavedShareDraft.fromJson(Map<String, dynamic> j) => SavedShareDraft(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        stationName: j['stationName'] as String? ?? '',
        date: j['date'] as String? ?? '',
        meetingTime: j['meetingTime'] as String? ?? '',
        participantTimes: (j['participantTimes'] as Map?)
                ?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ??
            const {},
        candidates: ((j['candidates'] as List?) ?? [])
            .map((e) =>
                SavedShareCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
        note: j['note'] as String? ?? '',
      );
}

class SavedShareCandidate {
  const SavedShareCandidate({
    required this.name,
    required this.category,
    required this.priceStr,
    this.rating,
    required this.lat,
    required this.lng,
    required this.address,
    required this.imageUrl,
    required this.hotpepperUrl,
    required this.isReservable,
  });

  final String name;
  final String category;
  final String priceStr;
  final double? rating;
  final double? lat;
  final double? lng;
  final String address;
  final String? imageUrl;
  final String? hotpepperUrl;
  final bool isReservable;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'priceStr': priceStr,
        'rating': rating,
        'lat': lat,
        'lng': lng,
        'address': address,
        'imageUrl': imageUrl == null ? null : PhotoRef.toRef(imageUrl!),
        'hotpepperUrl': hotpepperUrl,
        'isReservable': isReservable,
      };

  factory SavedShareCandidate.fromJson(Map<String, dynamic> j) =>
      SavedShareCandidate(
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? '',
        priceStr: j['priceStr'] as String? ?? '',
        rating: (j['rating'] as num?)?.toDouble(),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        address: j['address'] as String? ?? '',
        imageUrl: (j['imageUrl'] as String?) == null
            ? null
            : PhotoRef.toUrl(j['imageUrl'] as String,
                googleApiKey: Secrets.placesApiKey),
        hotpepperUrl: j['hotpepperUrl'] as String?,
        isReservable: j['isReservable'] as bool? ?? true,
      );
}
