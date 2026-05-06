/// Firestore に保存する photo reference（API キーを含まない形）と、
/// 画面表示時に使う URL の相互変換ユーティリティ。
///
/// 設計意図:
/// - Google Places の写真 URL は API キーを末尾に含むため、Firestore に
///   そのまま保存するとキーが漏洩する経路が増える。
/// - photo reference (`places/.../photos/...`) のみ保存し、表示時に
///   `secrets.dart` のキーで URL を組み立てる。
/// - Hotpepper 等のキー不要 URL はそのまま保存・そのまま表示。
class PhotoRef {
  PhotoRef._();

  static final RegExp _googlePhotoRegex =
      RegExp(r'/v1/(places/[^/]+/photos/[^/]+)/media');

  /// 写真 URL から保存用の reference を取り出す。
  /// - "https://places.googleapis.com/.../media?key=..." → "places/.../photos/..."
  /// - "https://imgfp.hotp.jp/..." 等の Hotpepper URL → そのまま返す
  /// - reference のみの文字列 → そのまま返す
  static String toRef(String urlOrRef) {
    final match = _googlePhotoRegex.firstMatch(urlOrRef);
    if (match != null) return match.group(1)!;
    return urlOrRef;
  }

  /// 保存された reference / URL を表示用 URL に戻す。
  /// - "https://" で始まる → そのまま返す
  /// - "places/..." → Google Places media URL を組み立てる
  static String toUrl(String refOrUrl, {required String googleApiKey, int maxWidthPx = 800}) {
    if (refOrUrl.startsWith('https://')) return refOrUrl;
    return 'https://places.googleapis.com/v1/$refOrUrl/media?maxWidthPx=$maxWidthPx&key=$googleApiKey';
  }

  /// リストを一括変換（Restaurant.imageUrls → photoRefs 用）
  static List<String> listToRefs(List<String> urlsOrRefs) =>
      urlsOrRefs.map(toRef).toList();

  /// リストを一括変換（photoRefs → 表示用 URL リスト）
  static List<String> listToUrls(List<String> refs,
          {required String googleApiKey, int maxWidthPx = 800}) =>
      refs
          .map((r) => toUrl(r, googleApiKey: googleApiKey, maxWidthPx: maxWidthPx))
          .toList();
}
