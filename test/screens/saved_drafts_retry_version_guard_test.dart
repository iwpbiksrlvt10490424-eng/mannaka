// Cycle 18 + Cycle 19 — `saved_drafts_screen_retry_test.dart` の
// Riverpod バージョン依存を静的に担保するガード。
//
// 背景:
//   Cycle 17 Critic WARNING-1:
//   `saved_drafts_screen_retry_test.dart` は Riverpod 2.6.x の
//   「`AsyncNotifierProvider.overrideWith` の factory が
//   `ref.invalidate` で再実行されない」挙動に依存している。
//   flutter_riverpod を 3.x 系に major bump した場合、この前提が崩れ、
//   テストはサイレントに偽グリーン化する可能性がある。
//
// 本テストの責務:
//   [1] 対象テストファイル冒頭に「Riverpod 2.6.x 依存」の警告マーカー
//       （⚠️ or WARNING or 警告）が含まれる
//   [2] 警告コメントに対象 major bump（3.x / major bump のいずれか）が
//       明示されている
//   [3] 警告コメントに「再設計必須」相当の指示が含まれる
//   [4] 警告コメントは import ディレクティブより前にある（ヘッダとして機能）
//   [5] `pubspec.yaml` の flutter_riverpod バージョンが ^2.x 系であること
//       （警告が現実と整合していることを担保。3.x に bump されたら本ガードが
//        赤くなって「テスト再設計が必要」と知らせる）
//   [6] Cycle 19: `pubspec.yaml` の flutter_riverpod の **minor** が 6 以上で
//       あること。major のみの検査では `^2.5.0` 等の minor downgrade
//       （2.5 以下への下方修正）を見逃し、Riverpod 2.6.x で導入された挙動
//       に依存するテストがサイレントに偽グリーン化する。
//
// 非目標:
//   - `lib/` 配下の本番コード変更は行わない。
//   - `pubspec.yaml` の変更は行わない。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _retryTestFile = 'test/screens/saved_drafts_screen_retry_test.dart';
const _pubspecFile = 'pubspec.yaml';

String _readFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('$path が存在しません。ファイルパスが変わっていないか確認してください。');
  }
  return file.readAsStringSync();
}

/// 対象テストファイルの冒頭ヘッダ（最初の `import` より前）を抽出する。
String _extractHeader(String source) {
  final importIdx = source.indexOf(RegExp(r"^import\s", multiLine: true));
  if (importIdx < 0) {
    fail('$_retryTestFile に import ディレクティブが見つからない（想定外）');
  }
  return source.substring(0, importIdx);
}

void main() {
  group('saved_drafts_screen_retry_test.dart — Riverpod バージョン依存ヘッダ警告', () {
    // ══════════════════════════════════════════════════════════════════════
    // [1] 警告マーカー（⚠️ / WARNING / 警告）
    // ══════════════════════════════════════════════════════════════════════
    test('[1] 冒頭ヘッダに警告マーカー（⚠️ / WARNING / 警告）が含まれる', () {
      final header = _extractHeader(_readFile(_retryTestFile));

      final hasMarker = header.contains('⚠️') ||
          RegExp(r'\bWARNING\b', caseSensitive: false).hasMatch(header) ||
          header.contains('警告');

      expect(
        hasMarker,
        isTrue,
        reason:
            'ファイル冒頭に「⚠️」「WARNING」「警告」のいずれかの警告マーカーを付けてください。\n'
            '通常の背景説明コメントでは目立たず、将来の major bump 時に読み飛ばされるリスクがあります。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [2] 「Riverpod 2.6.x 依存」の版指定
    // ══════════════════════════════════════════════════════════════════════
    test('[2] 冒頭ヘッダに「Riverpod 2.6.x 依存」または「Riverpod 2.6 依存」の版指定が含まれる',
        () {
      final header = _extractHeader(_readFile(_retryTestFile));

      final hasVersionBinding = RegExp(
        r'Riverpod\s*2\.6(\.\d+|\.x)?\s*(系|依存|に依存)',
      ).hasMatch(header);

      expect(
        hasVersionBinding,
        isTrue,
        reason:
            '冒頭ヘッダに「Riverpod 2.6.x 依存」等の明示的な版指定が見当たりません。\n'
            '単に「Riverpod 2.6.1 の挙動」と触れるだけでは依存宣言として弱いです。\n'
            '例: 「⚠️ 本テストは Riverpod 2.6.x に依存する」',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [3] major bump 時の再設計必須の明示
    // ══════════════════════════════════════════════════════════════════════
    test('[3] 冒頭ヘッダに「major bump / 3.x 時は再設計必須」相当の指示が含まれる', () {
      final header = _extractHeader(_readFile(_retryTestFile));

      final hasMajorBumpMention =
          RegExp(r'major\s*bump', caseSensitive: false).hasMatch(header) ||
              RegExp(r'3\.x').hasMatch(header) ||
              RegExp(r'3\.0').hasMatch(header);

      final hasRedesignMention = header.contains('再設計') ||
          header.contains('要再設計') ||
          header.contains('書き直し');

      expect(
        hasMajorBumpMention,
        isTrue,
        reason:
            '冒頭ヘッダに「major bump」「3.x」「3.0」のいずれかが見当たりません。\n'
            '将来 flutter_riverpod を 3.x 系に上げた読み手が、本テストが依存している'
            '挙動が崩れる可能性を把握できません。',
      );

      expect(
        hasRedesignMention,
        isTrue,
        reason:
            '冒頭ヘッダに「再設計」「要再設計」「書き直し」等の対応指示が見当たりません。\n'
            'major bump 時に何をすべきかを明記してください。\n'
            '例: 「major bump（3.x 以降）時は再設計必須」',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [4] 警告コメントは import より前（ヘッダとして機能）
    // ══════════════════════════════════════════════════════════════════════
    test('[4] 「Riverpod 2.6」の言及が最初の import より前の冒頭ブロックにある', () {
      final source = _readFile(_retryTestFile);
      final header = _extractHeader(source);

      final headerMentionsVersion =
          RegExp(r'Riverpod\s*2\.6').hasMatch(header);

      expect(
        headerMentionsVersion,
        isTrue,
        reason:
            '「Riverpod 2.6」の言及が最初の import より前のヘッダブロックに見当たりません。\n'
            'ファイルを開いた瞬間に視界に入る位置（ヘッダコメント）に書いてください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [5] pubspec.yaml と整合（flutter_riverpod が ^2.x 系）
    // ══════════════════════════════════════════════════════════════════════
    test('[5] pubspec.yaml の flutter_riverpod が ^2.x 系（警告が現実と整合）', () {
      final pubspec = _readFile(_pubspecFile);

      final match = RegExp(
        r'^\s*flutter_riverpod:\s*\^?(\d+)\.(\d+)(?:\.\d+)?\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(
        match,
        isNotNull,
        reason: 'pubspec.yaml に flutter_riverpod の version 指定が見つかりません。',
      );

      final major = int.parse(match!.group(1)!);

      expect(
        major,
        equals(2),
        reason:
            'flutter_riverpod の major バージョンが 2 系でない（= $major.x）。\n'
            '本テスト（saved_drafts_screen_retry_test.dart）は Riverpod 2.6.x の\n'
            '`AsyncNotifierProvider.overrideWith` factory が `ref.invalidate` で\n'
            '再実行されない挙動に依存しています。major bump したなら、\n'
            '同テストを新しい Riverpod 仕様に合わせて再設計してから\n'
            '本ガードの expected major を更新してください。',
      );
    });

    // ══════════════════════════════════════════════════════════════════════
    // [6] Cycle 19: pubspec.yaml の flutter_riverpod の minor が 6 以上
    //
    // なぜ minor まで検証するか:
    //   [5] の major のみ検査では `flutter_riverpod: ^2.5.0` 等の
    //   **minor downgrade**（2.5 以下への下方修正）を見逃す。Riverpod 2.6.x
    //   で導入された `AsyncNotifierProvider.overrideWith` factory の
    //   「`ref.invalidate` で再実行されない」挙動に依存する
    //   `saved_drafts_screen_retry_test.dart` は、minor を下げた瞬間に
    //   挙動が変わり得るため、minor を下げたら本ガードが赤く落ちるようにする。
    // ══════════════════════════════════════════════════════════════════════
    test('[6] pubspec.yaml の flutter_riverpod の minor が 6 以上（minor downgrade 防止）',
        () {
      final pubspec = _readFile(_pubspecFile);

      final match = RegExp(
        r'^\s*flutter_riverpod:\s*\^?(\d+)\.(\d+)(?:\.\d+)?\s*$',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(
        match,
        isNotNull,
        reason: 'pubspec.yaml に flutter_riverpod の version 指定が見つかりません。',
      );

      final minor = int.parse(match!.group(2)!);

      expect(
        minor,
        greaterThanOrEqualTo(6),
        reason:
            'flutter_riverpod の minor バージョンが 6 未満（= 2.$minor.x）。\n'
            '`saved_drafts_screen_retry_test.dart` は Riverpod 2.6.x の\n'
            '`AsyncNotifierProvider.overrideWith` factory が `ref.invalidate` で\n'
            '再実行されない挙動に依存しています。`^2.5.0` 等へ minor を下げた\n'
            '場合、本テストはサイレントに偽グリーン化します。minor を下げたなら\n'
            '同テストを当該バージョンの仕様で再設計してから、本ガードの\n'
            '閾値を更新してください。',
      );
    });
  });
}
