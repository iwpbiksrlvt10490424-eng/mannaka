class AppAd {
  const AppAd({
    required this.id,
    required this.restaurantName,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.ctaLabel,
    required this.hotpepperUrl,
    this.category = '',
    this.discount = '',
  });

  final String id;
  final String restaurantName;
  final String title;
  final String body;
  final String imageUrl;
  final String ctaLabel;
  final String hotpepperUrl;
  final String category;
  final String discount;
}
