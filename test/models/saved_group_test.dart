import 'package:flutter_test/flutter_test.dart';
import 'package:mannaka/models/saved_group.dart';

void main() {
  group('SavedGroup', () {
    test('toJson()とfromJson()のラウンドトリップ', () {
      final original = SavedGroup(
        id: 'g1',
        name: '会社の同僚',
        memberNames: ['Alice', 'Bob', 'Carol'],
        createdAt: DateTime(2026, 3, 11, 12, 0, 0),
      );

      final json = original.toJson();
      final restored = SavedGroup.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.memberNames, equals(original.memberNames));
      expect(restored.createdAt, equals(original.createdAt));
    });

    test('全フィールドがtoJsonで正しく保存される', () {
      final group = SavedGroup(
        id: 'test-id',
        name: 'テストグループ',
        memberNames: ['太郎', '花子'],
        createdAt: DateTime(2026, 1, 15, 18, 30, 0),
      );

      final json = group.toJson();

      expect(json['id'], equals('test-id'));
      expect(json['name'], equals('テストグループ'));
      expect(json['memberNames'], equals(['太郎', '花子']));
      expect(json['createdAt'], equals('2026-01-15T18:30:00.000'));
    });

    test('空のmemberNamesでも正しく動作する', () {
      final original = SavedGroup(
        id: 'g2',
        name: '空グループ',
        memberNames: [],
        createdAt: DateTime(2026, 3, 11),
      );

      final json = original.toJson();
      final restored = SavedGroup.fromJson(json);

      expect(restored.memberNames, isEmpty);
    });

    test('日本語の名前が正しく保存・復元される', () {
      final original = SavedGroup(
        id: 'g3',
        name: '大学の友達🎉',
        memberNames: ['山田太郎', '鈴木花子', '田中一郎'],
        createdAt: DateTime(2026, 3, 11),
      );

      final json = original.toJson();
      final restored = SavedGroup.fromJson(json);

      expect(restored.name, equals('大学の友達🎉'));
      expect(restored.memberNames, equals(['山田太郎', '鈴木花子', '田中一郎']));
    });
  });
}
