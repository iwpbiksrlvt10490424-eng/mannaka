import 'secrets.dart';

/// API設定
class ApiConfig {
  /// Hotpepper グルメAPI キー
  static final String hotpepperApiKey = Secrets.hotpepperApiKey;

  /// Foursquare Places API v3 キー
  static final String foursquareApiKey = Secrets.foursquareApiKey;

  /// Google Maps / Places API キー
  static final String googleMapsApiKey = Secrets.googleMapsApiKey;

  /// Places API (Legacy) 専用キー（HTTPリクエスト用）
  static final String placesApiKey = Secrets.placesApiKey;
}
