import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/participant.dart';
import '../models/meeting_point.dart';
import '../models/restaurant.dart';
import '../services/midpoint_service.dart';

enum Occasion {
  none,
  girlsNight,
  birthday,
  lunch,
  mixer,
  welcome,
  date,
}

extension OccasionExt on Occasion {
  String get label => switch (this) {
        Occasion.none => 'なし',
        Occasion.girlsNight => '女子会',
        Occasion.birthday => '誕生日',
        Occasion.lunch => 'ランチ会',
        Occasion.mixer => '合コン',
        Occasion.welcome => '歓迎会',
        Occasion.date => 'デート',
      };
  String get emoji => switch (this) {
        Occasion.none => '',
        Occasion.girlsNight => '👑',
        Occasion.birthday => '🎂',
        Occasion.lunch => '🥗',
        Occasion.mixer => '🥂',
        Occasion.welcome => '🎉',
        Occasion.date => '💕',
      };
  bool get filterFemale =>
      this == Occasion.girlsNight || this == Occasion.mixer || this == Occasion.date;
  bool get filterPrivate =>
      this == Occasion.birthday || this == Occasion.girlsNight || this == Occasion.welcome;
  bool get filterLunch => this == Occasion.lunch;
}

enum TimeSlot { all, lunch, dinner }

extension TimeSlotExt on TimeSlot {
  String get label => switch (this) {
        TimeSlot.all => 'すべて',
        TimeSlot.lunch => 'ランチ',
        TimeSlot.dinner => 'ディナー',
      };
  String get emoji => switch (this) {
        TimeSlot.all => '🕐',
        TimeSlot.lunch => '☀️',
        TimeSlot.dinner => '🌙',
      };
}

class SearchState {
  const SearchState({
    this.participants = const [],
    this.results = const [],
    this.isCalculating = false,
    this.hasCalculated = false,
    this.selectedMeetingPoint,
    this.restaurantCategory,
    this.showFemaleFriendly = false,
    this.showPrivateRoom = false,
    this.occasion = Occasion.none,
    this.timeSlot = TimeSlot.all,
    this.maxBudget = 0,
  });

  final List<Participant> participants;
  final List<MeetingPoint> results;
  final bool isCalculating;
  final bool hasCalculated;
  final MeetingPoint? selectedMeetingPoint;
  final String? restaurantCategory;
  final bool showFemaleFriendly;
  final bool showPrivateRoom;
  final Occasion occasion;
  final TimeSlot timeSlot;
  final int maxBudget; // 0 = 制限なし

  bool get canCalculate => participants.where((p) => p.hasStation).length >= 2;

  bool get _effectiveFemale => showFemaleFriendly || occasion.filterFemale;
  bool get _effectivePrivate => showPrivateRoom || occasion.filterPrivate;
  TimeSlot get _effectiveTimeSlot =>
      occasion.filterLunch ? TimeSlot.lunch : timeSlot;

  List<Restaurant> get restaurants {
    if (selectedMeetingPoint == null) return [];
    return MidpointService.getRestaurants(
      stationIndex: selectedMeetingPoint!.stationIndex,
      category: restaurantCategory,
      femaleFriendly: _effectiveFemale,
      hasPrivateRoom: _effectivePrivate,
      timeSlot: _effectiveTimeSlot,
      maxBudget: maxBudget,
    );
  }

  SearchState copyWith({
    List<Participant>? participants,
    List<MeetingPoint>? results,
    bool? isCalculating,
    bool? hasCalculated,
    MeetingPoint? selectedMeetingPoint,
    String? restaurantCategory,
    bool? showFemaleFriendly,
    bool? showPrivateRoom,
    Occasion? occasion,
    TimeSlot? timeSlot,
    int? maxBudget,
    bool clearMeetingPoint = false,
    bool clearCategory = false,
  }) {
    return SearchState(
      participants: participants ?? this.participants,
      results: results ?? this.results,
      isCalculating: isCalculating ?? this.isCalculating,
      hasCalculated: hasCalculated ?? this.hasCalculated,
      selectedMeetingPoint:
          clearMeetingPoint ? null : (selectedMeetingPoint ?? this.selectedMeetingPoint),
      restaurantCategory: clearCategory ? null : (restaurantCategory ?? this.restaurantCategory),
      showFemaleFriendly: showFemaleFriendly ?? this.showFemaleFriendly,
      showPrivateRoom: showPrivateRoom ?? this.showPrivateRoom,
      occasion: occasion ?? this.occasion,
      timeSlot: timeSlot ?? this.timeSlot,
      maxBudget: maxBudget ?? this.maxBudget,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState(
        participants: [Participant(id: '1', name: '自分')],
      );

  void addParticipant() {
    final count = state.participants.length + 1;
    final names = ['友達A', '友達B', '友達C', '友達D', '友達E'];
    final name = count <= names.length ? names[count - 1] : '参加者$count';
    state = state.copyWith(
      participants: [...state.participants, Participant(id: '$count', name: name)],
    );
  }

  void removeParticipant(String id) {
    if (state.participants.length <= 1) return;
    state = state.copyWith(
      participants: state.participants.where((p) => p.id != id).toList(),
    );
  }

  void updateParticipantName(String id, String name) {
    state = state.copyWith(
      participants:
          state.participants.map((p) => p.id == id ? p.copyWith(name: name) : p).toList(),
    );
  }

  void setStation(String id, int stationIndex, String stationName) {
    state = state.copyWith(
      participants: state.participants.map((p) {
        return p.id == id ? p.copyWith(stationIndex: stationIndex, stationName: stationName) : p;
      }).toList(),
      hasCalculated: false,
    );
  }

  void clearStation(String id) {
    state = state.copyWith(
      participants: state.participants.map((p) => p.id == id ? p.clearStation() : p).toList(),
      hasCalculated: false,
    );
  }

  void setOccasion(Occasion o) {
    state = state.copyWith(occasion: o);
  }

  void setTimeSlot(TimeSlot t) {
    state = state.copyWith(timeSlot: t);
  }

  void setMaxBudget(int budget) {
    state = state.copyWith(maxBudget: budget);
  }

  Future<void> calculate() async {
    if (!state.canCalculate) return;
    state = state.copyWith(isCalculating: true);
    await Future.delayed(const Duration(milliseconds: 700));
    final results = MidpointService.calculate(state.participants);
    state = state.copyWith(
      isCalculating: false,
      hasCalculated: true,
      results: results,
      selectedMeetingPoint: results.isNotEmpty ? results.first : null,
      clearCategory: true,
    );
  }

  void selectMeetingPoint(MeetingPoint point) {
    state = state.copyWith(selectedMeetingPoint: point, clearCategory: true);
  }

  void setRestaurantCategory(String? category) {
    state = state.copyWith(
      restaurantCategory: category,
      clearCategory: category == null,
    );
  }

  void setFemaleFriendly(bool value) {
    state = state.copyWith(showFemaleFriendly: value);
  }

  void setPrivateRoom(bool value) {
    state = state.copyWith(showPrivateRoom: value);
  }

  void startWithOccasion(Occasion o) {
    state = state.copyWith(occasion: o, hasCalculated: false);
  }

  void reset() {
    state = const SearchState(
      participants: [Participant(id: '1', name: '自分')],
    );
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
