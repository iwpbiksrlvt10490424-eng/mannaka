import '../models/restaurant.dart';

final List<Restaurant> kRestaurants = [
  // ─── 渋谷 (0) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r001', name: 'ガーデン テラス 渋谷', stationIndex: 0,
    category: '洋食', rating: 4.5, reviewCount: 412, priceLabel: '¥¥¥', priceAvg: 5000,
    tags: ['個室あり', '女子会OK', '予約可', '記念日'],
    emoji: '🥂', description: '渋谷の隠れ家的ガーデンビストロ。テラス席で乾杯が最高。',
    distanceMinutes: 3, address: '渋谷区道玄坂1-2-3', openHours: '11:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r002', name: '焼肉 黒澤 渋谷本店', stationIndex: 0,
    category: '焼肉', rating: 4.2, reviewCount: 328, priceLabel: '¥¥¥', priceAvg: 4500,
    tags: ['個室あり', '予約可', '高級'],
    emoji: '🥩', description: '厳選和牛を個室でゆっくり楽しめる人気焼肉店。',
    distanceMinutes: 5, address: '渋谷区渋谷2-4-6', openHours: '17:00〜23:30',
    isReservable: true, isFemalePopular: false, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r003', name: 'チョコラ カフェ', stationIndex: 0,
    category: 'カフェ', rating: 4.3, reviewCount: 267, priceLabel: '¥¥', priceAvg: 1500,
    tags: ['インスタ映え', '女子会OK', 'スイーツ'],
    emoji: '🍰', description: 'チョコレート専門のおしゃれカフェ。フォトジェニックなパフェが人気。',
    distanceMinutes: 4, address: '渋谷区神南1-6-8', openHours: '10:00〜21:00',
    isReservable: false, isFemalePopular: true, hasPrivateRoom: false,
  ),

  // ─── 新宿 (1) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r004', name: '海鮮居酒屋 新宿磯っぺ', stationIndex: 1,
    category: '居酒屋', rating: 4.2, reviewCount: 543, priceLabel: '¥¥', priceAvg: 3000,
    tags: ['個室あり', '宴会OK', '飲み放題'],
    emoji: '🐟', description: '毎朝仕入れる新鮮魚介が自慢の海鮮居酒屋。個室充実。',
    distanceMinutes: 3, address: '新宿区西新宿7-1-2', openHours: '17:00〜翌1:00',
    isReservable: true, isFemalePopular: false, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r005', name: '和牛バル 肉研究所 新宿', stationIndex: 1,
    category: '洋食', rating: 4.4, reviewCount: 389, priceLabel: '¥¥¥', priceAvg: 5500,
    tags: ['女子会OK', '記念日', 'ワイン'],
    emoji: '🍷', description: '和牛×ワインが楽しめるスタイリッシュなバル。インスタ映え間違いなし。',
    distanceMinutes: 4, address: '新宿区新宿3-15-7', openHours: '17:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r006', name: 'ルノワール カフェ 新宿南口', stationIndex: 1,
    category: 'カフェ', rating: 3.8, reviewCount: 156, priceLabel: '¥', priceAvg: 800,
    tags: ['気軽に', 'ゆっくり', 'Wi-Fi'],
    emoji: '☕', description: '落ち着いた雰囲気のチェーンカフェ。待ち合わせに最適。',
    distanceMinutes: 2, address: '新宿区新宿3-22-1', openHours: '8:00〜22:00',
    isReservable: false, isFemalePopular: false, hasPrivateRoom: false,
  ),

  // ─── 池袋 (2) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r007', name: '個室居酒屋 花みず木', stationIndex: 2,
    category: '居酒屋', rating: 4.1, reviewCount: 478, priceLabel: '¥¥', priceAvg: 3500,
    tags: ['個室あり', '女子会OK', '飲み放題', '記念日'],
    emoji: '🌸', description: '全席個室のおしゃれ居酒屋。女子会コースが充実。',
    distanceMinutes: 5, address: '豊島区東池袋1-12-3', openHours: '17:00〜翌2:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r008', name: 'イタリアン チェーロ 池袋', stationIndex: 2,
    category: '洋食', rating: 4.2, reviewCount: 234, priceLabel: '¥¥', priceAvg: 3000,
    tags: ['女子会OK', 'パスタ', 'ワイン', '予約可'],
    emoji: '🍝', description: '本格ナポリピッツァと手打ちパスタが楽しめるイタリアン。',
    distanceMinutes: 6, address: '豊島区南池袋1-24-5', openHours: '11:30〜22:30',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r009', name: 'ラーメン 晴れる屋', stationIndex: 2,
    category: 'ラーメン', rating: 4.5, reviewCount: 823, priceLabel: '¥', priceAvg: 1000,
    tags: ['行列必至', '食べログ高評価', 'こだわり'],
    emoji: '🍜', description: '食べログ3.9超えの名店。濃厚鶏白湯が絶品。',
    distanceMinutes: 7, address: '豊島区池袋2-52-8', openHours: '11:00〜23:00',
    isReservable: false, isFemalePopular: false, hasPrivateRoom: false,
  ),

  // ─── 上野 (3) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r010', name: '寿司 弁天 上野', stationIndex: 3,
    category: '和食', rating: 4.4, reviewCount: 312, priceLabel: '¥¥¥', priceAvg: 6000,
    tags: ['個室あり', '接待', '記念日', '予約可'],
    emoji: '🍣', description: '上野アメ横近くの本格江戸前寿司。デートや記念日に。',
    distanceMinutes: 4, address: '台東区上野5-7-2', openHours: '11:30〜22:00',
    isReservable: true, isFemalePopular: false, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r011', name: '韓国料理 ソウルガーデン', stationIndex: 3,
    category: '韓国', rating: 4.2, reviewCount: 267, priceLabel: '¥¥', priceAvg: 2500,
    tags: ['女子会OK', 'チーズダッカルビ', 'インスタ映え'],
    emoji: '🌶️', description: 'チーズタッカルビ・サムギョプサルが楽しめる韓国料理店。',
    distanceMinutes: 3, address: '台東区上野4-3-8', openHours: '11:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),

  // ─── 東京 (4) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r012', name: '日本料理 一葉 丸の内', stationIndex: 4,
    category: '和食', rating: 4.6, reviewCount: 198, priceLabel: '¥¥¥¥', priceAvg: 12000,
    tags: ['個室あり', '接待', '記念日', '高級'],
    emoji: '🍱', description: '丸の内の老舗日本料理店。洗練された空間で特別な時間を。',
    distanceMinutes: 3, address: '千代田区丸の内2-1-1', openHours: '11:30〜22:00',
    isReservable: true, isFemalePopular: false, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r013', name: 'ビストロ 丸の内テラス', stationIndex: 4,
    category: '洋食', rating: 4.4, reviewCount: 356, priceLabel: '¥¥¥', priceAvg: 5000,
    tags: ['女子会OK', '記念日', 'テラス席', '予約可'],
    emoji: '🥗', description: 'テラス席から東京駅が見える絶景ビストロ。ランチも人気。',
    distanceMinutes: 2, address: '千代田区丸の内1-9-1', openHours: '11:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r014', name: 'バル デ ジャポン', stationIndex: 4,
    category: '洋食', rating: 4.1, reviewCount: 289, priceLabel: '¥¥', priceAvg: 3500,
    tags: ['飲み放題', 'タパス', '気軽に'],
    emoji: '🍸', description: '気軽に立ち寄れるスペインバル。タパスとワインが充実。',
    distanceMinutes: 5, address: '千代田区有楽町1-2-3', openHours: '11:30〜翌1:00',
    isReservable: false, isFemalePopular: false, hasPrivateRoom: false,
  ),

  // ─── 品川 (5) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r015', name: '焼肉 品格 品川店', stationIndex: 5,
    category: '焼肉', rating: 4.3, reviewCount: 445, priceLabel: '¥¥¥', priceAvg: 5000,
    tags: ['個室あり', '黒毛和牛', '予約可'],
    emoji: '🥩', description: 'A5ランク黒毛和牛専門。品川随一の高品質焼肉店。',
    distanceMinutes: 4, address: '港区港南2-16-3', openHours: '17:00〜23:00',
    isReservable: true, isFemalePopular: false, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r016', name: 'ワイン食堂 港南テラス', stationIndex: 5,
    category: '洋食', rating: 4.1, reviewCount: 213, priceLabel: '¥¥', priceAvg: 3000,
    tags: ['女子会OK', 'ワイン豊富', 'テラス'],
    emoji: '🍷', description: '港南エリアのナチュラルワイン食堂。海の見えるテラスが人気。',
    distanceMinutes: 6, address: '港区港南3-5-12', openHours: '17:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),

  // ─── 秋葉原 (6) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r017', name: '台湾料理 台北食堂', stationIndex: 6,
    category: '中華', rating: 4.2, reviewCount: 334, priceLabel: '¥¥', priceAvg: 2000,
    tags: ['本格派', 'ランチ人気', '小籠包'],
    emoji: '🥟', description: '本場台湾の味を再現。ふわふわ小籠包が絶品。',
    distanceMinutes: 5, address: '千代田区外神田4-8-2', openHours: '11:00〜22:30',
    isReservable: false, isFemalePopular: false, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r018', name: '和食ダイニング 千代田', stationIndex: 6,
    category: '和食', rating: 4.0, reviewCount: 187, priceLabel: '¥¥', priceAvg: 2500,
    tags: ['定食', 'ランチ', '落ち着いた'],
    emoji: '🍚', description: '秋葉原の喧騒から離れた落ち着いた和食処。',
    distanceMinutes: 4, address: '千代田区外神田3-6-5', openHours: '11:30〜22:00',
    isReservable: false, isFemalePopular: false, hasPrivateRoom: false,
  ),

  // ─── 横浜 (7) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r019', name: '中華街 翠華楼', stationIndex: 7,
    category: '中華', rating: 4.3, reviewCount: 621, priceLabel: '¥¥', priceAvg: 3000,
    tags: ['中華街', '本格中華', '宴会OK'],
    emoji: '🏮', description: '横浜中華街の老舗。本格広東料理が楽しめる。',
    distanceMinutes: 12, address: '横浜市中区山下町164', openHours: '11:00〜22:00',
    isReservable: true, isFemalePopular: false, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r020', name: '港の見えるカフェ マリーン', stationIndex: 7,
    category: 'カフェ', rating: 4.4, reviewCount: 389, priceLabel: '¥¥', priceAvg: 1800,
    tags: ['海が見える', 'インスタ映え', '女子会OK'],
    emoji: '⛵', description: 'みなとみらいの夜景とコーヒー。横浜随一の絶景カフェ。',
    distanceMinutes: 15, address: '横浜市中区山下町27', openHours: '10:00〜22:00',
    isReservable: false, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r021', name: 'ヨコハマ ビストロ 馬車道', stationIndex: 7,
    category: '洋食', rating: 4.2, reviewCount: 267, priceLabel: '¥¥¥', priceAvg: 4500,
    tags: ['記念日', 'ワイン', '個室あり'],
    emoji: '🍽️', description: '馬車道の洋館で楽しむフランス料理。横浜の雰囲気満点。',
    distanceMinutes: 18, address: '横浜市中区本町4-43', openHours: '18:00〜22:30',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: true,
  ),

  // ─── 北千住 (8) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r022', name: 'そば処 花岡 北千住', stationIndex: 8,
    category: '和食', rating: 4.3, reviewCount: 198, priceLabel: '¥', priceAvg: 1200,
    tags: ['老舗', '手打ちそば', '気軽に'],
    emoji: '🍵', description: '北千住の名物手打ちそば屋。コシのある十割蕎麦が絶品。',
    distanceMinutes: 3, address: '足立区千住2-5-8', openHours: '11:00〜21:00',
    isReservable: false, isFemalePopular: false, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r023', name: '肉バル ミート北千住', stationIndex: 8,
    category: '洋食', rating: 4.0, reviewCount: 234, priceLabel: '¥¥', priceAvg: 3000,
    tags: ['女子会OK', '飲み放題', '気軽に'],
    emoji: '🍖', description: 'コスパ最強の肉バル。飲み放題コースが充実。',
    distanceMinutes: 4, address: '足立区千住3-92-3', openHours: '17:00〜翌1:00',
    isReservable: true, isFemalePopular: false, hasPrivateRoom: false,
  ),

  // ─── 吉祥寺 (9) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r024', name: '井の頭テラスカフェ', stationIndex: 9,
    category: 'カフェ', rating: 4.5, reviewCount: 512, priceLabel: '¥¥', priceAvg: 1600,
    tags: ['緑に囲まれた', 'インスタ映え', '女子会OK', 'ペット可'],
    emoji: '🌿', description: '井の頭公園のほとり。四季の自然と共にほっこり過ごせる。',
    distanceMinutes: 8, address: '武蔵野市吉祥寺南町1-8-4', openHours: '9:00〜20:00',
    isReservable: false, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r025', name: 'ハーモニカ横丁 酒場', stationIndex: 9,
    category: '居酒屋', rating: 4.2, reviewCount: 378, priceLabel: '¥¥', priceAvg: 2500,
    tags: ['レトロ', '昭和の雰囲気', 'せんべろ'],
    emoji: '🏮', description: '吉祥寺名物ハーモニカ横丁の小さな酒場。レトロな雰囲気が魅力。',
    distanceMinutes: 3, address: '武蔵野市吉祥寺本町1-1-2', openHours: '17:00〜翌2:00',
    isReservable: false, isFemalePopular: false, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r026', name: 'タイ料理 サワディー 吉祥寺', stationIndex: 9,
    category: 'アジア', rating: 4.1, reviewCount: 289, priceLabel: '¥¥', priceAvg: 2000,
    tags: ['本格タイ料理', '女子会OK', 'スパイシー'],
    emoji: '🌴', description: 'バンコク仕込みの本格タイ料理。グリーンカレーが絶品。',
    distanceMinutes: 5, address: '武蔵野市吉祥寺南町2-14-3', openHours: '11:30〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),

  // ─── 恵比寿 (10) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r027', name: 'ガーデンプレイス ビストロ 蔦', stationIndex: 10,
    category: '洋食', rating: 4.6, reviewCount: 423, priceLabel: '¥¥¥¥', priceAvg: 8000,
    tags: ['記念日', '個室あり', '高級', 'ガーデンプレイス'],
    emoji: '🌿', description: '恵比寿ガーデンプレイスの隠れ家フレンチ。特別な日に。',
    distanceMinutes: 5, address: '渋谷区恵比寿4-20-3', openHours: '18:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r028', name: 'ビストロ メゾン 恵比寿', stationIndex: 10,
    category: '洋食', rating: 4.4, reviewCount: 356, priceLabel: '¥¥¥', priceAvg: 5500,
    tags: ['女子会OK', 'ワイン', 'おしゃれ'],
    emoji: '🍷', description: 'フランス直輸入ワインと本格フレンチを気軽に。',
    distanceMinutes: 3, address: '渋谷区恵比寿1-12-6', openHours: '17:30〜23:30',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r029', name: 'イタリアン オリーヴ', stationIndex: 10,
    category: '洋食', rating: 4.3, reviewCount: 298, priceLabel: '¥¥', priceAvg: 3500,
    tags: ['女子会OK', 'パスタ', 'コスパ良い'],
    emoji: '🫒', description: '恵比寿で人気のカジュアルイタリアン。石窯ピッツァが看板メニュー。',
    distanceMinutes: 4, address: '渋谷区恵比寿西1-5-9', openHours: '12:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),

  // ─── 中目黒 (11) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r030', name: '目黒川カフェ フルール', stationIndex: 11,
    category: 'カフェ', rating: 4.6, reviewCount: 634, priceLabel: '¥¥', priceAvg: 1800,
    tags: ['目黒川沿い', 'インスタ映え', '女子会OK', 'テラス'],
    emoji: '🌸', description: '目黒川沿いの人気カフェ。季節のお花を見ながらランチを。',
    distanceMinutes: 3, address: '目黒区青葉台1-15-2', openHours: '9:00〜22:00',
    isReservable: false, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r031', name: 'フレンチ ラ・フィーユ', stationIndex: 11,
    category: '洋食', rating: 4.7, reviewCount: 289, priceLabel: '¥¥¥¥', priceAvg: 10000,
    tags: ['記念日', '個室あり', 'デート', 'ミシュラン'],
    emoji: '🌹', description: 'ミシュラン1つ星の実力を持つ中目黒フレンチ。最高の記念日に。',
    distanceMinutes: 5, address: '目黒区中目黒1-4-5', openHours: '18:00〜22:30',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r032', name: '和食 なかめぐろ邸', stationIndex: 11,
    category: '和食', rating: 4.3, reviewCount: 234, priceLabel: '¥¥¥', priceAvg: 6000,
    tags: ['個室あり', '女子会OK', '割烹'],
    emoji: '🍶', description: '古民家をリノベした落ち着いた割烹。季節の食材を使った料理が自慢。',
    distanceMinutes: 7, address: '目黒区青葉台2-17-8', openHours: '18:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: true,
  ),

  // ─── 表参道 (12) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r033', name: 'カフェ シロ 表参道', stationIndex: 12,
    category: 'カフェ', rating: 4.4, reviewCount: 567, priceLabel: '¥¥', priceAvg: 1600,
    tags: ['インスタ映え', '女子会OK', 'ホワイトインテリア'],
    emoji: '☁️', description: '真っ白なインテリアが映えるSNSで話題のカフェ。',
    distanceMinutes: 4, address: '港区南青山3-18-5', openHours: '10:00〜20:00',
    isReservable: false, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r034', name: 'ビストロ アオヤマ', stationIndex: 12,
    category: '洋食', rating: 4.5, reviewCount: 423, priceLabel: '¥¥¥', priceAvg: 6000,
    tags: ['女子会OK', '記念日', 'テラス', '予約困難'],
    emoji: '🌷', description: '表参道の人気フレンチビストロ。テラス席から青山の街並みを望む。',
    distanceMinutes: 3, address: '港区南青山5-4-41', openHours: '12:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r035', name: '和食 原宿天宮', stationIndex: 12,
    category: '和食', rating: 4.2, reviewCount: 312, priceLabel: '¥¥¥', priceAvg: 5000,
    tags: ['個室あり', '女子会OK', '和の雰囲気'],
    emoji: '⛩️', description: '原宿の路地裏に佇む和食処。こだわりの出汁料理が話題。',
    distanceMinutes: 8, address: '渋谷区神宮前4-28-3', openHours: '18:00〜23:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: true,
  ),

  // ─── 銀座 (13) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r036', name: '割烹 銀座 水晶', stationIndex: 13,
    category: '和食', rating: 4.7, reviewCount: 234, priceLabel: '¥¥¥¥', priceAvg: 15000,
    tags: ['高級', '接待', '個室あり', '記念日'],
    emoji: '💎', description: '銀座の名料亭。季節の食材を活かした格調高い日本料理。',
    distanceMinutes: 3, address: '中央区銀座6-7-2', openHours: '12:00〜22:30',
    isReservable: true, isFemalePopular: false, hasPrivateRoom: true,
  ),
  Restaurant(
    id: 'r037', name: 'プランタン ブラッスリー 銀座', stationIndex: 13,
    category: '洋食', rating: 4.4, reviewCount: 378, priceLabel: '¥¥¥', priceAvg: 5000,
    tags: ['女子会OK', 'ランチ人気', 'アフタヌーンティー'],
    emoji: '🫖', description: 'アフタヌーンティーが絶品。銀座でゆったり過ごすなら。',
    distanceMinutes: 4, address: '中央区銀座4-6-16', openHours: '10:00〜22:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r038', name: 'シャンパン バー ル・クール', stationIndex: 13,
    category: '洋食', rating: 4.3, reviewCount: 289, priceLabel: '¥¥¥', priceAvg: 5500,
    tags: ['シャンパン', '女子会OK', 'デート', 'おしゃれ'],
    emoji: '🥂', description: '70種以上のシャンパンが揃う銀座の大人バー。特別な夜に。',
    distanceMinutes: 2, address: '中央区銀座5-14-1', openHours: '18:00〜翌1:00',
    isReservable: true, isFemalePopular: true, hasPrivateRoom: false,
  ),

  // ─── 新橋 (14) ─────────────────────────────────────────────────
  Restaurant(
    id: 'r039', name: '焼き鳥 烏森 本店', stationIndex: 14,
    category: '居酒屋', rating: 4.2, reviewCount: 534, priceLabel: '¥¥', priceAvg: 2500,
    tags: ['焼き鳥', '大人の居酒屋', '煙が香ばしい'],
    emoji: '🍢', description: '新橋の老舗焼き鳥屋。備長炭で丁寧に焼かれる絶品焼き鳥。',
    distanceMinutes: 3, address: '港区新橋4-17-3', openHours: '17:00〜23:00',
    isReservable: false, isFemalePopular: false, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r040', name: '海鮮 新橋魚市', stationIndex: 14,
    category: '和食', rating: 4.1, reviewCount: 423, priceLabel: '¥¥', priceAvg: 3000,
    tags: ['新鮮魚介', '宴会', '飲み放題'],
    emoji: '🐠', description: '築地から直送の新鮮魚介を使った海鮮料理店。',
    distanceMinutes: 4, address: '港区新橋2-11-5', openHours: '17:00〜翌0:00',
    isReservable: true, isFemalePopular: false, hasPrivateRoom: false,
  ),
  Restaurant(
    id: 'r041', name: 'ワインバー バックストリート', stationIndex: 14,
    category: '洋食', rating: 4.3, reviewCount: 198, priceLabel: '¥¥', priceAvg: 3500,
    tags: ['ワイン', '女子会OK', 'チーズ', '大人の隠れ家'],
    emoji: '🍷', description: '新橋のバックストリートに佇む大人のワインバー。',
    distanceMinutes: 5, address: '港区新橋5-32-8', openHours: '18:00〜翌2:00',
    isReservable: false, isFemalePopular: true, hasPrivateRoom: false,
  ),
];
