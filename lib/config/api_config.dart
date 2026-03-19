import 'secrets.dart';

/// API設定（設定画面から上書き可能）
class ApiConfig {
  /// Hotpepper グルメAPI キー（設定画面で変更可能）
  static String hotpepperApiKey = Secrets.hotpepperApiKey;

  /// Foursquare Places API v3 キー
  static String foursquareApiKey = Secrets.foursquareApiKey;
}
