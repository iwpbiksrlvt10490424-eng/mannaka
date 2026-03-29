import 'transit_edge.dart';

/// 駅別乗換ペナルティ（分）
/// 未定義駅は kDefaultTransferMinutes（5分）を使う
/// 重い乗換（8-10分）: 構内が広大・混雑で乗換に時間がかかる駅
/// 軽い乗換（3分）: 同一ホーム対面乗換や小規模駅
const int kDefaultTransferMinutes = 5;
const Map<String, int> kStationTransferMinutes = {
  // ── 重い乗換（8分）──────────────────────────────────────────────
  '新宿':   8,
  '渋谷':   8,
  '池袋':   8,
  '東京':   8,
  '大手町': 8,
  '横浜':   8,
  '品川':   7,
  '上野':   7,
  '北千住': 7,
  '新橋':   7,
  '秋葉原': 7,
  '高田馬場': 7,
  '恵比寿': 6,
  '目黒':   6,
  '三鷹':   6,
  '川越':   6,
  '大宮':   6,
  '船橋':   6,
  '千葉':   6,
  // ── 軽い乗換（3分）: 同一改札・対面乗換 ─────────────────────────
  '日比谷':   3,
  '銀座':     3,
  '表参道':   3,
  '赤坂見附': 3,
  '永田町':   3,
  '飯田橋':   3,
  '神谷町':   3,
  '溜池山王': 3,
  '国会議事堂前': 3,
};

/// 乗り換えペナルティ（分）- 後方互換のため残す
const int kTransferPenaltyMinutes = kDefaultTransferMinutes;

/// 東京圏の主要路線の隣接リスト（双方向）
/// lineId は路線を識別するためのキー（乗り換えペナルティ計算に使用）
const Map<String, List<TransitEdge>> kTransitGraph = {
  // ─── JR山手線 (yamanote) ─────────────────────────────────────────
  '品川': [
    TransitEdge('大崎', 2, 'yamanote'),
    TransitEdge('高輪ゲートウェイ', 2, 'yamanote'),
    TransitEdge('大井町', 4, 'keihin_tohoku'),
    TransitEdge('川崎', 10, 'shonan'),
    TransitEdge('西大井', 5, 'shonan'),
    TransitEdge('西大井', 5, 'saikyo'),
  ],
  '大崎': [
    TransitEdge('品川', 2, 'yamanote'),
    TransitEdge('五反田', 2, 'yamanote'),
    TransitEdge('武蔵小杉', 8, 'saikyo'),
    TransitEdge('恵比寿', 5, 'saikyo'),
    TransitEdge('恵比寿', 5, 'shonan'),
    TransitEdge('西大井', 5, 'shonan'),
    TransitEdge('西大井', 5, 'saikyo'),
  ],
  '五反田': [
    TransitEdge('大崎', 2, 'yamanote'),
    TransitEdge('目黒', 2, 'yamanote'),
    TransitEdge('高輪台', 3, 'toei_asakusa'),
    TransitEdge('戸越', 3, 'toei_asakusa'),
  ],
  '目黒': [
    TransitEdge('五反田', 2, 'yamanote'),
    TransitEdge('恵比寿', 2, 'yamanote'),
    TransitEdge('白金台', 3, 'namboku'),
    TransitEdge('白金台', 3, 'toei_mita'),
    TransitEdge('不動前', 3, 'meguro'),
  ],
  '恵比寿': [
    TransitEdge('目黒', 2, 'yamanote'),
    TransitEdge('渋谷', 3, 'yamanote'),
    TransitEdge('中目黒', 3, 'hibiya'),
    TransitEdge('広尾', 4, 'hibiya'),
    TransitEdge('大崎', 5, 'saikyo'),
    TransitEdge('大崎', 5, 'shonan'),
    TransitEdge('渋谷', 3, 'saikyo'),
    TransitEdge('渋谷', 3, 'shonan'),
  ],
  '渋谷': [
    TransitEdge('恵比寿', 3, 'yamanote'),
    TransitEdge('原宿', 2, 'yamanote'),
    TransitEdge('代官山', 2, 'toyoko'),
    TransitEdge('池尻大橋', 3, 'denentoshi'),
    TransitEdge('表参道', 3, 'ginza'),
    TransitEdge('表参道', 3, 'hanzomon'),
    TransitEdge('明治神宮前', 3, 'fukutoshin'),
    TransitEdge('恵比寿', 3, 'saikyo'),
    TransitEdge('恵比寿', 3, 'shonan'),
    TransitEdge('新宿', 6, 'saikyo'),
    TransitEdge('新宿', 6, 'shonan'),
  ],
  '原宿': [
    TransitEdge('渋谷', 2, 'yamanote'),
    TransitEdge('代々木', 2, 'yamanote'),
  ],
  '代々木': [
    TransitEdge('原宿', 2, 'yamanote'),
    TransitEdge('新宿', 2, 'yamanote'),
    TransitEdge('千駄ヶ谷', 2, 'chuo_sobu'),
    TransitEdge('新宿', 2, 'chuo_rapid'),
    TransitEdge('新宿', 2, 'chuo_sobu'),
  ],
  '新宿': [
    TransitEdge('代々木', 2, 'yamanote'),
    TransitEdge('新大久保', 2, 'yamanote'),
    TransitEdge('大久保', 3, 'chuo_rapid'),
    TransitEdge('大久保', 3, 'chuo_sobu'),
    TransitEdge('代々木', 2, 'chuo_rapid'),
    TransitEdge('代々木', 2, 'chuo_sobu'),
    TransitEdge('南新宿', 2, 'odakyu'),
    TransitEdge('西新宿', 2, 'marunouchi'),
    TransitEdge('新宿三丁目', 2, 'marunouchi'),
    TransitEdge('新宿三丁目', 2, 'toei_shinjuku'),
    TransitEdge('渋谷', 6, 'saikyo'),
    TransitEdge('渋谷', 6, 'shonan'),
    TransitEdge('池袋', 10, 'saikyo'),
    TransitEdge('池袋', 8, 'shonan'),
  ],
  '新大久保': [
    TransitEdge('新宿', 2, 'yamanote'),
    TransitEdge('高田馬場', 2, 'yamanote'),
  ],
  '高田馬場': [
    TransitEdge('新大久保', 2, 'yamanote'),
    TransitEdge('目白', 2, 'yamanote'),
    TransitEdge('落合', 4, 'tozai'),
    TransitEdge('早稲田', 3, 'tozai'),
  ],
  '目白': [
    TransitEdge('高田馬場', 2, 'yamanote'),
    TransitEdge('池袋', 2, 'yamanote'),
  ],
  '池袋': [
    TransitEdge('目白', 2, 'yamanote'),
    TransitEdge('大塚', 3, 'yamanote'),
    TransitEdge('新大塚', 3, 'marunouchi'),
    TransitEdge('要町', 2, 'fukutoshin'),
    TransitEdge('北池袋', 3, 'tobu_tojo'),
    TransitEdge('椎名町', 3, 'seibu_ikebukuro'),
    TransitEdge('新宿', 10, 'saikyo'),
    TransitEdge('新宿', 8, 'shonan'),
    TransitEdge('赤羽', 10, 'shonan'),
    TransitEdge('板橋', 4, 'saikyo'),
    TransitEdge('東池袋', 1, 'yurakucho'),
  ],
  '大塚': [
    TransitEdge('池袋', 3, 'yamanote'),
    TransitEdge('巣鴨', 2, 'yamanote'),
  ],
  '巣鴨': [
    TransitEdge('大塚', 2, 'yamanote'),
    TransitEdge('駒込', 2, 'yamanote'),
    TransitEdge('千石', 3, 'toei_mita'),
    TransitEdge('西巣鴨', 3, 'toei_mita'),
  ],
  '駒込': [
    TransitEdge('巣鴨', 2, 'yamanote'),
    TransitEdge('田端', 3, 'yamanote'),
    TransitEdge('本駒込', 2, 'namboku'),
    TransitEdge('西ヶ原', 3, 'namboku'),
  ],
  '田端': [
    TransitEdge('駒込', 3, 'yamanote'),
    TransitEdge('西日暮里', 2, 'yamanote'),
    TransitEdge('上中里', 2, 'keihin_tohoku'),
  ],
  '西日暮里': [
    TransitEdge('田端', 2, 'yamanote'),
    TransitEdge('日暮里', 2, 'yamanote'),
    TransitEdge('田端', 2, 'keihin_tohoku'),
    TransitEdge('日暮里', 2, 'keihin_tohoku'),
    TransitEdge('千駄木', 3, 'chiyoda'),
    TransitEdge('町屋', 3, 'chiyoda'),
  ],
  '日暮里': [
    TransitEdge('西日暮里', 2, 'yamanote'),
    TransitEdge('鶯谷', 2, 'yamanote'),
    TransitEdge('西日暮里', 2, 'keihin_tohoku'),
    TransitEdge('鶯谷', 2, 'keihin_tohoku'),
  ],
  '鶯谷': [
    TransitEdge('日暮里', 2, 'yamanote'),
    TransitEdge('上野', 2, 'yamanote'),
    TransitEdge('日暮里', 2, 'keihin_tohoku'),
    TransitEdge('上野', 2, 'keihin_tohoku'),
  ],
  '上野': [
    TransitEdge('鶯谷', 2, 'yamanote'),
    TransitEdge('御徒町', 2, 'yamanote'),
    TransitEdge('鶯谷', 2, 'keihin_tohoku'),
    TransitEdge('御徒町', 2, 'keihin_tohoku'),
    TransitEdge('上野広小路', 2, 'ginza'),
    TransitEdge('仲御徒町', 2, 'hibiya'),
    TransitEdge('入谷', 2, 'hibiya'),
  ],
  '御徒町': [
    TransitEdge('上野', 2, 'yamanote'),
    TransitEdge('秋葉原', 2, 'yamanote'),
    TransitEdge('上野', 2, 'keihin_tohoku'),
    TransitEdge('秋葉原', 2, 'keihin_tohoku'),
  ],
  '秋葉原': [
    TransitEdge('御徒町', 2, 'yamanote'),
    TransitEdge('神田', 2, 'yamanote'),
    TransitEdge('御徒町', 2, 'keihin_tohoku'),
    TransitEdge('神田', 2, 'keihin_tohoku'),
    TransitEdge('御茶ノ水', 3, 'chuo_sobu'),
    TransitEdge('浅草橋', 3, 'chuo_sobu'),
    TransitEdge('小伝馬町', 2, 'hibiya'),
    TransitEdge('仲御徒町', 2, 'hibiya'),
  ],
  '神田': [
    TransitEdge('秋葉原', 2, 'yamanote'),
    TransitEdge('東京', 2, 'yamanote'),
    TransitEdge('秋葉原', 2, 'keihin_tohoku'),
    TransitEdge('東京', 2, 'keihin_tohoku'),
    TransitEdge('御茶ノ水', 2, 'chuo_rapid'),
    TransitEdge('東京', 2, 'chuo_rapid'),
    TransitEdge('末広町', 2, 'ginza'),
    TransitEdge('三越前', 2, 'ginza'),
  ],
  '東京': [
    TransitEdge('神田', 2, 'yamanote'),
    TransitEdge('有楽町', 2, 'yamanote'),
    TransitEdge('神田', 2, 'keihin_tohoku'),
    TransitEdge('有楽町', 2, 'keihin_tohoku'),
    TransitEdge('神田', 2, 'chuo_rapid'),
    TransitEdge('銀座', 3, 'marunouchi'),
    TransitEdge('大手町', 2, 'marunouchi'),
    TransitEdge('日本橋', 3, 'tozai'),
    TransitEdge('大手町', 3, 'tozai'),
  ],
  '有楽町': [
    TransitEdge('東京', 2, 'yamanote'),
    TransitEdge('新橋', 2, 'yamanote'),
    TransitEdge('東京', 2, 'keihin_tohoku'),
    TransitEdge('新橋', 2, 'keihin_tohoku'),
    TransitEdge('桜田門', 3, 'yurakucho'),
    TransitEdge('銀座一丁目', 2, 'yurakucho'),
  ],
  '新橋': [
    TransitEdge('有楽町', 2, 'yamanote'),
    TransitEdge('浜松町', 3, 'yamanote'),
    TransitEdge('有楽町', 2, 'keihin_tohoku'),
    TransitEdge('浜松町', 3, 'keihin_tohoku'),
    TransitEdge('銀座', 3, 'ginza'),
    TransitEdge('虎ノ門', 2, 'ginza'),
    TransitEdge('東銀座', 3, 'toei_asakusa'),
    TransitEdge('大門', 3, 'toei_asakusa'),
  ],
  '浜松町': [
    TransitEdge('新橋', 3, 'yamanote'),
    TransitEdge('田町', 2, 'yamanote'),
    TransitEdge('新橋', 3, 'keihin_tohoku'),
    TransitEdge('田町', 2, 'keihin_tohoku'),
  ],
  '田町': [
    TransitEdge('浜松町', 2, 'yamanote'),
    TransitEdge('高輪ゲートウェイ', 2, 'yamanote'),
    TransitEdge('浜松町', 2, 'keihin_tohoku'),
    TransitEdge('高輪ゲートウェイ', 2, 'keihin_tohoku'),
  ],
  '高輪ゲートウェイ': [
    TransitEdge('田町', 2, 'yamanote'),
    TransitEdge('品川', 2, 'yamanote'),
    TransitEdge('田町', 2, 'keihin_tohoku'),
    TransitEdge('品川', 2, 'keihin_tohoku'),
  ],

  // ─── JR中央線快速 (chuo_rapid) ──────────────────────────────────
  '御茶ノ水': [
    TransitEdge('神田', 2, 'chuo_rapid'),
    TransitEdge('四ッ谷', 5, 'chuo_rapid'),
    TransitEdge('秋葉原', 3, 'chuo_sobu'),
    TransitEdge('水道橋', 3, 'chuo_sobu'),
    TransitEdge('新御茶ノ水', 3, 'chiyoda'),
    TransitEdge('淡路町', 2, 'marunouchi'),
  ],
  '四ッ谷': [
    TransitEdge('御茶ノ水', 5, 'chuo_rapid'),
    TransitEdge('信濃町', 3, 'chuo_rapid'),
    TransitEdge('市ヶ谷', 3, 'chuo_sobu'),
    TransitEdge('信濃町', 3, 'chuo_sobu'),
    TransitEdge('赤坂見附', 3, 'marunouchi'),
    TransitEdge('市ヶ谷', 3, 'namboku'),
    TransitEdge('永田町', 3, 'namboku'),
  ],
  '信濃町': [
    TransitEdge('四ッ谷', 3, 'chuo_rapid'),
    TransitEdge('千駄ヶ谷', 2, 'chuo_rapid'),
    TransitEdge('四ッ谷', 3, 'chuo_sobu'),
    TransitEdge('千駄ヶ谷', 2, 'chuo_sobu'),
  ],
  '千駄ヶ谷': [
    TransitEdge('信濃町', 2, 'chuo_rapid'),
    TransitEdge('代々木', 2, 'chuo_rapid'),
    TransitEdge('信濃町', 2, 'chuo_sobu'),
    TransitEdge('代々木', 2, 'chuo_sobu'),
  ],
  '大久保': [
    TransitEdge('新宿', 3, 'chuo_rapid'),
    TransitEdge('東中野', 2, 'chuo_rapid'),
    TransitEdge('新宿', 3, 'chuo_sobu'),
    TransitEdge('東中野', 2, 'chuo_sobu'),
  ],
  '東中野': [
    TransitEdge('大久保', 2, 'chuo_rapid'),
    TransitEdge('中野', 3, 'chuo_rapid'),
    TransitEdge('大久保', 2, 'chuo_sobu'),
    TransitEdge('中野', 3, 'chuo_sobu'),
  ],
  '中野': [
    TransitEdge('東中野', 3, 'chuo_rapid'),
    TransitEdge('高円寺', 3, 'chuo_rapid'),
    TransitEdge('東中野', 3, 'chuo_sobu'),
    TransitEdge('高円寺', 3, 'chuo_sobu'),
    TransitEdge('落合', 4, 'tozai'),
  ],
  '高円寺': [
    TransitEdge('中野', 3, 'chuo_rapid'),
    TransitEdge('阿佐ヶ谷', 2, 'chuo_rapid'),
    TransitEdge('中野', 3, 'chuo_sobu'),
    TransitEdge('阿佐ヶ谷', 2, 'chuo_sobu'),
  ],
  '阿佐ヶ谷': [
    TransitEdge('高円寺', 2, 'chuo_rapid'),
    TransitEdge('荻窪', 2, 'chuo_rapid'),
    TransitEdge('高円寺', 2, 'chuo_sobu'),
    TransitEdge('荻窪', 2, 'chuo_sobu'),
  ],
  '荻窪': [
    TransitEdge('阿佐ヶ谷', 2, 'chuo_rapid'),
    TransitEdge('西荻窪', 3, 'chuo_rapid'),
    TransitEdge('阿佐ヶ谷', 2, 'chuo_sobu'),
    TransitEdge('西荻窪', 3, 'chuo_sobu'),
    TransitEdge('南阿佐ヶ谷', 3, 'marunouchi'),
    TransitEdge('西荻窪', 3, 'marunouchi'),
  ],
  '西荻窪': [
    TransitEdge('荻窪', 3, 'chuo_rapid'),
    TransitEdge('吉祥寺', 3, 'chuo_rapid'),
    TransitEdge('荻窪', 3, 'chuo_sobu'),
    TransitEdge('吉祥寺', 3, 'chuo_sobu'),
  ],
  '吉祥寺': [
    TransitEdge('西荻窪', 3, 'chuo_rapid'),
    TransitEdge('三鷹', 3, 'chuo_rapid'),
    TransitEdge('西荻窪', 3, 'chuo_sobu'),
    TransitEdge('三鷹', 3, 'chuo_sobu'),
  ],
  '三鷹': [
    TransitEdge('吉祥寺', 3, 'chuo_rapid'),
    TransitEdge('武蔵境', 4, 'chuo_rapid'),
    TransitEdge('吉祥寺', 3, 'chuo_sobu'),
  ],
  '武蔵境': [
    TransitEdge('三鷹', 4, 'chuo_rapid'),
    TransitEdge('東小金井', 3, 'chuo_rapid'),
  ],
  '東小金井': [
    TransitEdge('武蔵境', 3, 'chuo_rapid'),
    TransitEdge('武蔵小金井', 3, 'chuo_rapid'),
  ],
  '武蔵小金井': [
    TransitEdge('東小金井', 3, 'chuo_rapid'),
    TransitEdge('国分寺', 3, 'chuo_rapid'),
  ],
  '国分寺': [
    TransitEdge('武蔵小金井', 3, 'chuo_rapid'),
    TransitEdge('西国分寺', 3, 'chuo_rapid'),
  ],
  '西国分寺': [
    TransitEdge('国分寺', 3, 'chuo_rapid'),
    TransitEdge('国立', 3, 'chuo_rapid'),
    TransitEdge('東恋ヶ窪', 3, 'musashino'),
  ],
  '国立': [
    TransitEdge('西国分寺', 3, 'chuo_rapid'),
    TransitEdge('立川', 4, 'chuo_rapid'),
  ],
  '立川': [
    TransitEdge('国立', 4, 'chuo_rapid'),
    TransitEdge('西国立', 3, 'nambu'),
  ],

  // ─── JR中央・総武線各停 (chuo_sobu) ────────────────────────────
  '千葉': [
    TransitEdge('稲毛', 5, 'chuo_sobu'),
    TransitEdge('幕張', 5, 'chuo_sobu'),
  ],
  '稲毛': [
    TransitEdge('千葉', 5, 'chuo_sobu'),
    TransitEdge('西千葉', 3, 'chuo_sobu'),
  ],
  '西千葉': [
    TransitEdge('稲毛', 3, 'chuo_sobu'),
    TransitEdge('千葉', 3, 'chuo_sobu'),
  ],
  '幕張': [
    TransitEdge('千葉', 5, 'chuo_sobu'),
    TransitEdge('幕張本郷', 3, 'chuo_sobu'),
  ],
  '幕張本郷': [
    TransitEdge('幕張', 3, 'chuo_sobu'),
    TransitEdge('津田沼', 3, 'chuo_sobu'),
  ],
  '津田沼': [
    TransitEdge('幕張本郷', 3, 'chuo_sobu'),
    TransitEdge('東船橋', 3, 'chuo_sobu'),
  ],
  '東船橋': [
    TransitEdge('津田沼', 3, 'chuo_sobu'),
    TransitEdge('船橋', 3, 'chuo_sobu'),
  ],
  '船橋': [
    TransitEdge('東船橋', 3, 'chuo_sobu'),
    TransitEdge('下総中山', 4, 'chuo_sobu'),
  ],
  '下総中山': [
    TransitEdge('船橋', 4, 'chuo_sobu'),
    TransitEdge('本八幡', 3, 'chuo_sobu'),
  ],
  '本八幡': [
    TransitEdge('下総中山', 3, 'chuo_sobu'),
    TransitEdge('市川', 3, 'chuo_sobu'),
    TransitEdge('篠崎', 4, 'toei_shinjuku'),
  ],
  '市川': [
    TransitEdge('本八幡', 3, 'chuo_sobu'),
    TransitEdge('小岩', 5, 'chuo_sobu'),
  ],
  '小岩': [
    TransitEdge('市川', 5, 'chuo_sobu'),
    TransitEdge('新小岩', 3, 'chuo_sobu'),
  ],
  '新小岩': [
    TransitEdge('小岩', 3, 'chuo_sobu'),
    TransitEdge('平井', 3, 'chuo_sobu'),
  ],
  '平井': [
    TransitEdge('新小岩', 3, 'chuo_sobu'),
    TransitEdge('亀戸', 3, 'chuo_sobu'),
  ],
  '亀戸': [
    TransitEdge('平井', 3, 'chuo_sobu'),
    TransitEdge('錦糸町', 3, 'chuo_sobu'),
  ],
  '錦糸町': [
    TransitEdge('亀戸', 3, 'chuo_sobu'),
    TransitEdge('両国', 3, 'chuo_sobu'),
    TransitEdge('住吉', 3, 'hanzomon'),
    TransitEdge('押上', 3, 'hanzomon'),
    TransitEdge('菊川', 2, 'toei_shinjuku'),
  ],
  '両国': [
    TransitEdge('錦糸町', 3, 'chuo_sobu'),
    TransitEdge('浅草橋', 3, 'chuo_sobu'),
  ],
  '浅草橋': [
    TransitEdge('両国', 3, 'chuo_sobu'),
    TransitEdge('秋葉原', 3, 'chuo_sobu'),
    TransitEdge('東日本橋', 2, 'toei_asakusa'),
    TransitEdge('蔵前', 3, 'toei_asakusa'),
  ],
  '水道橋': [
    TransitEdge('御茶ノ水', 3, 'chuo_sobu'),
    TransitEdge('飯田橋', 3, 'chuo_sobu'),
    TransitEdge('神保町', 3, 'toei_mita'),
    TransitEdge('春日', 2, 'toei_mita'),
  ],
  '飯田橋': [
    TransitEdge('水道橋', 3, 'chuo_sobu'),
    TransitEdge('市ヶ谷', 3, 'chuo_sobu'),
    TransitEdge('市ヶ谷', 3, 'namboku'),
    TransitEdge('後楽園', 4, 'namboku'),
    TransitEdge('神楽坂', 3, 'tozai'),
    TransitEdge('九段下', 3, 'tozai'),
    TransitEdge('江戸川橋', 4, 'yurakucho'),
    TransitEdge('市ヶ谷', 3, 'yurakucho'),
  ],
  '市ヶ谷': [
    TransitEdge('飯田橋', 3, 'chuo_sobu'),
    TransitEdge('四ッ谷', 3, 'chuo_sobu'),
    TransitEdge('飯田橋', 3, 'namboku'),
    TransitEdge('四ッ谷', 3, 'namboku'),
    TransitEdge('曙橋', 3, 'toei_shinjuku'),
    TransitEdge('九段下', 3, 'toei_shinjuku'),
    TransitEdge('飯田橋', 3, 'yurakucho'),
    TransitEdge('麹町', 3, 'yurakucho'),
  ],

  // ─── JR京浜東北線 (keihin_tohoku) ──────────────────────────────
  '大宮': [
    TransitEdge('さいたま新都心', 4, 'keihin_tohoku'),
    TransitEdge('北与野', 4, 'saikyo'),
    TransitEdge('浦和', 8, 'shonan'),
  ],
  'さいたま新都心': [
    TransitEdge('大宮', 4, 'keihin_tohoku'),
    TransitEdge('与野', 3, 'keihin_tohoku'),
  ],
  '与野': [
    TransitEdge('さいたま新都心', 3, 'keihin_tohoku'),
    TransitEdge('北浦和', 3, 'keihin_tohoku'),
  ],
  '北浦和': [
    TransitEdge('与野', 3, 'keihin_tohoku'),
    TransitEdge('浦和', 3, 'keihin_tohoku'),
  ],
  '浦和': [
    TransitEdge('北浦和', 3, 'keihin_tohoku'),
    TransitEdge('南浦和', 4, 'keihin_tohoku'),
    TransitEdge('大宮', 8, 'shonan'),
    TransitEdge('赤羽', 7, 'shonan'),
  ],
  '南浦和': [
    TransitEdge('浦和', 4, 'keihin_tohoku'),
    TransitEdge('蕨', 4, 'keihin_tohoku'),
  ],
  '蕨': [
    TransitEdge('南浦和', 4, 'keihin_tohoku'),
    TransitEdge('西川口', 3, 'keihin_tohoku'),
  ],
  '西川口': [
    TransitEdge('蕨', 3, 'keihin_tohoku'),
    TransitEdge('川口', 3, 'keihin_tohoku'),
  ],
  '川口': [
    TransitEdge('西川口', 3, 'keihin_tohoku'),
    TransitEdge('赤羽', 5, 'keihin_tohoku'),
  ],
  '赤羽': [
    TransitEdge('川口', 5, 'keihin_tohoku'),
    TransitEdge('東十条', 4, 'keihin_tohoku'),
    TransitEdge('北赤羽', 3, 'saikyo'),
    TransitEdge('十条', 3, 'saikyo'),
    TransitEdge('浦和', 7, 'shonan'),
    TransitEdge('池袋', 10, 'shonan'),
    TransitEdge('赤羽岩淵', 3, 'namboku'),
  ],
  '東十条': [
    TransitEdge('赤羽', 4, 'keihin_tohoku'),
    TransitEdge('王子', 3, 'keihin_tohoku'),
  ],
  '王子': [
    TransitEdge('東十条', 3, 'keihin_tohoku'),
    TransitEdge('上中里', 2, 'keihin_tohoku'),
    TransitEdge('王子神谷', 3, 'namboku'),
    TransitEdge('西ヶ原', 3, 'namboku'),
  ],
  '上中里': [
    TransitEdge('王子', 2, 'keihin_tohoku'),
    TransitEdge('田端', 3, 'keihin_tohoku'),
  ],
  '大井町': [
    TransitEdge('品川', 4, 'keihin_tohoku'),
    TransitEdge('大森', 4, 'keihin_tohoku'),
  ],
  '大森': [
    TransitEdge('大井町', 4, 'keihin_tohoku'),
    TransitEdge('蒲田', 4, 'keihin_tohoku'),
  ],
  '蒲田': [
    TransitEdge('大森', 4, 'keihin_tohoku'),
    TransitEdge('川崎', 6, 'keihin_tohoku'),
  ],
  '川崎': [
    TransitEdge('蒲田', 6, 'keihin_tohoku'),
    TransitEdge('鶴見', 5, 'keihin_tohoku'),
    TransitEdge('品川', 10, 'shonan'),
    TransitEdge('横浜', 10, 'shonan'),
    TransitEdge('矢向', 4, 'nambu'),
  ],
  '鶴見': [
    TransitEdge('川崎', 5, 'keihin_tohoku'),
    TransitEdge('新子安', 4, 'keihin_tohoku'),
  ],
  '新子安': [
    TransitEdge('鶴見', 4, 'keihin_tohoku'),
    TransitEdge('東神奈川', 3, 'keihin_tohoku'),
  ],
  '東神奈川': [
    TransitEdge('新子安', 3, 'keihin_tohoku'),
    TransitEdge('横浜', 3, 'keihin_tohoku'),
  ],
  '横浜': [
    TransitEdge('東神奈川', 3, 'keihin_tohoku'),
    TransitEdge('反町', 3, 'toyoko'),
    TransitEdge('川崎', 10, 'shonan'),
  ],

  // ─── 東急東横線 (toyoko) ─────────────────────────────────────────
  '代官山': [
    TransitEdge('渋谷', 2, 'toyoko'),
    TransitEdge('中目黒', 3, 'toyoko'),
  ],
  '中目黒': [
    TransitEdge('代官山', 3, 'toyoko'),
    TransitEdge('祐天寺', 3, 'toyoko'),
    TransitEdge('恵比寿', 3, 'hibiya'),
    TransitEdge('広尾', 4, 'hibiya'),
  ],
  '祐天寺': [
    TransitEdge('中目黒', 3, 'toyoko'),
    TransitEdge('学芸大学', 3, 'toyoko'),
  ],
  '学芸大学': [
    TransitEdge('祐天寺', 3, 'toyoko'),
    TransitEdge('都立大学', 3, 'toyoko'),
  ],
  '都立大学': [
    TransitEdge('学芸大学', 3, 'toyoko'),
    TransitEdge('自由が丘', 3, 'toyoko'),
  ],
  '自由が丘': [
    TransitEdge('都立大学', 3, 'toyoko'),
    TransitEdge('田園調布', 3, 'toyoko'),
    TransitEdge('大岡山', 2, 'meguro'),
  ],
  '田園調布': [
    TransitEdge('自由が丘', 3, 'toyoko'),
    TransitEdge('多摩川', 2, 'toyoko'),
    TransitEdge('奥沢', 2, 'meguro'),
    TransitEdge('多摩川', 2, 'meguro'),
  ],
  '多摩川': [
    TransitEdge('田園調布', 2, 'toyoko'),
    TransitEdge('新丸子', 4, 'toyoko'),
    TransitEdge('田園調布', 2, 'meguro'),
    TransitEdge('新丸子', 4, 'meguro'),
  ],
  '新丸子': [
    TransitEdge('多摩川', 4, 'toyoko'),
    TransitEdge('武蔵小杉', 2, 'toyoko'),
    TransitEdge('多摩川', 4, 'meguro'),
    TransitEdge('武蔵小杉', 2, 'meguro'),
  ],
  '武蔵小杉': [
    TransitEdge('新丸子', 2, 'toyoko'),
    TransitEdge('元住吉', 3, 'toyoko'),
    TransitEdge('新丸子', 2, 'meguro'),
    TransitEdge('大崎', 8, 'saikyo'),
    TransitEdge('西大井', 5, 'nambu'),
    TransitEdge('武蔵中原', 4, 'nambu'),
  ],
  '元住吉': [
    TransitEdge('武蔵小杉', 3, 'toyoko'),
    TransitEdge('日吉', 3, 'toyoko'),
  ],
  '日吉': [
    TransitEdge('元住吉', 3, 'toyoko'),
    TransitEdge('綱島', 4, 'toyoko'),
  ],
  '綱島': [
    TransitEdge('日吉', 4, 'toyoko'),
    TransitEdge('大倉山', 3, 'toyoko'),
  ],
  '大倉山': [
    TransitEdge('綱島', 3, 'toyoko'),
    TransitEdge('菊名', 3, 'toyoko'),
  ],
  '菊名': [
    TransitEdge('大倉山', 3, 'toyoko'),
    TransitEdge('妙蓮寺', 3, 'toyoko'),
  ],
  '妙蓮寺': [
    TransitEdge('菊名', 3, 'toyoko'),
    TransitEdge('白楽', 2, 'toyoko'),
  ],
  '白楽': [
    TransitEdge('妙蓮寺', 2, 'toyoko'),
    TransitEdge('東白楽', 2, 'toyoko'),
  ],
  '東白楽': [
    TransitEdge('白楽', 2, 'toyoko'),
    TransitEdge('反町', 2, 'toyoko'),
  ],
  '反町': [
    TransitEdge('東白楽', 2, 'toyoko'),
    TransitEdge('横浜', 3, 'toyoko'),
  ],

  // ─── 東急目黒線 (meguro) ─────────────────────────────────────────
  '不動前': [
    TransitEdge('目黒', 3, 'meguro'),
    TransitEdge('武蔵小山', 2, 'meguro'),
  ],
  '武蔵小山': [
    TransitEdge('不動前', 2, 'meguro'),
    TransitEdge('西小山', 2, 'meguro'),
  ],
  '西小山': [
    TransitEdge('武蔵小山', 2, 'meguro'),
    TransitEdge('洗足', 2, 'meguro'),
  ],
  '洗足': [
    TransitEdge('西小山', 2, 'meguro'),
    TransitEdge('大岡山', 2, 'meguro'),
  ],
  '大岡山': [
    TransitEdge('洗足', 2, 'meguro'),
    TransitEdge('奥沢', 2, 'meguro'),
    TransitEdge('自由が丘', 2, 'meguro'),
  ],
  '奥沢': [
    TransitEdge('大岡山', 2, 'meguro'),
    TransitEdge('田園調布', 2, 'meguro'),
  ],

  // ─── 東急田園都市線 (denentoshi) ────────────────────────────────
  '池尻大橋': [
    TransitEdge('渋谷', 3, 'denentoshi'),
    TransitEdge('三軒茶屋', 2, 'denentoshi'),
  ],
  '三軒茶屋': [
    TransitEdge('池尻大橋', 2, 'denentoshi'),
    TransitEdge('駒沢大学', 3, 'denentoshi'),
  ],
  '駒沢大学': [
    TransitEdge('三軒茶屋', 3, 'denentoshi'),
    TransitEdge('桜新町', 3, 'denentoshi'),
  ],
  '桜新町': [
    TransitEdge('駒沢大学', 3, 'denentoshi'),
    TransitEdge('用賀', 3, 'denentoshi'),
  ],
  '用賀': [
    TransitEdge('桜新町', 3, 'denentoshi'),
    TransitEdge('二子玉川', 3, 'denentoshi'),
  ],
  '二子玉川': [
    TransitEdge('用賀', 3, 'denentoshi'),
    TransitEdge('二子新地', 2, 'denentoshi'),
  ],
  '二子新地': [
    TransitEdge('二子玉川', 2, 'denentoshi'),
    TransitEdge('高津', 2, 'denentoshi'),
  ],
  '高津': [
    TransitEdge('二子新地', 2, 'denentoshi'),
    TransitEdge('溝の口', 2, 'denentoshi'),
  ],
  '溝の口': [
    TransitEdge('高津', 2, 'denentoshi'),
    TransitEdge('梶が谷', 3, 'denentoshi'),
    TransitEdge('武蔵溝ノ口', 4, 'nambu'),
  ],
  '梶が谷': [
    TransitEdge('溝の口', 3, 'denentoshi'),
    TransitEdge('宮崎台', 3, 'denentoshi'),
  ],
  '宮崎台': [
    TransitEdge('梶が谷', 3, 'denentoshi'),
    TransitEdge('宮前平', 3, 'denentoshi'),
  ],
  '宮前平': [
    TransitEdge('宮崎台', 3, 'denentoshi'),
    TransitEdge('鷺沼', 3, 'denentoshi'),
  ],
  '鷺沼': [
    TransitEdge('宮前平', 3, 'denentoshi'),
    TransitEdge('たまプラーザ', 3, 'denentoshi'),
  ],
  'たまプラーザ': [
    TransitEdge('鷺沼', 3, 'denentoshi'),
    TransitEdge('あざみ野', 3, 'denentoshi'),
  ],
  'あざみ野': [
    TransitEdge('たまプラーザ', 3, 'denentoshi'),
    TransitEdge('江田', 3, 'denentoshi'),
  ],
  '江田': [
    TransitEdge('あざみ野', 3, 'denentoshi'),
    TransitEdge('市が尾', 3, 'denentoshi'),
  ],
  '市が尾': [
    TransitEdge('江田', 3, 'denentoshi'),
    TransitEdge('藤が丘', 3, 'denentoshi'),
  ],
  '藤が丘': [
    TransitEdge('市が尾', 3, 'denentoshi'),
    TransitEdge('青葉台', 3, 'denentoshi'),
  ],
  '青葉台': [
    TransitEdge('藤が丘', 3, 'denentoshi'),
    TransitEdge('田奈', 4, 'denentoshi'),
  ],
  '田奈': [
    TransitEdge('青葉台', 4, 'denentoshi'),
    TransitEdge('長津田', 4, 'denentoshi'),
  ],
  '長津田': [
    TransitEdge('田奈', 4, 'denentoshi'),
  ],

  // ─── 小田急線 (odakyu) ──────────────────────────────────────────
  '南新宿': [
    TransitEdge('新宿', 2, 'odakyu'),
    TransitEdge('参宮橋', 2, 'odakyu'),
  ],
  '参宮橋': [
    TransitEdge('南新宿', 2, 'odakyu'),
    TransitEdge('代々木八幡', 2, 'odakyu'),
  ],
  '代々木八幡': [
    TransitEdge('参宮橋', 2, 'odakyu'),
    TransitEdge('代々木上原', 2, 'odakyu'),
  ],
  '代々木上原': [
    TransitEdge('代々木八幡', 2, 'odakyu'),
    TransitEdge('東北沢', 2, 'odakyu'),
    TransitEdge('代々木公園', 2, 'chiyoda'),
    TransitEdge('明治神宮前', 2, 'chiyoda'),
  ],
  '東北沢': [
    TransitEdge('代々木上原', 2, 'odakyu'),
    TransitEdge('下北沢', 2, 'odakyu'),
  ],
  '下北沢': [
    TransitEdge('東北沢', 2, 'odakyu'),
    TransitEdge('世田谷代田', 2, 'odakyu'),
  ],
  '世田谷代田': [
    TransitEdge('下北沢', 2, 'odakyu'),
    TransitEdge('梅ヶ丘', 2, 'odakyu'),
  ],
  '梅ヶ丘': [
    TransitEdge('世田谷代田', 2, 'odakyu'),
    TransitEdge('豪徳寺', 2, 'odakyu'),
  ],
  '豪徳寺': [
    TransitEdge('梅ヶ丘', 2, 'odakyu'),
    TransitEdge('経堂', 3, 'odakyu'),
  ],
  '経堂': [
    TransitEdge('豪徳寺', 3, 'odakyu'),
    TransitEdge('千歳船橋', 3, 'odakyu'),
  ],
  '千歳船橋': [
    TransitEdge('経堂', 3, 'odakyu'),
    TransitEdge('祖師ヶ谷大蔵', 3, 'odakyu'),
  ],
  '祖師ヶ谷大蔵': [
    TransitEdge('千歳船橋', 3, 'odakyu'),
    TransitEdge('成城学園前', 3, 'odakyu'),
  ],
  '成城学園前': [
    TransitEdge('祖師ヶ谷大蔵', 3, 'odakyu'),
    TransitEdge('喜多見', 3, 'odakyu'),
  ],
  '喜多見': [
    TransitEdge('成城学園前', 3, 'odakyu'),
    TransitEdge('狛江', 3, 'odakyu'),
  ],
  '狛江': [
    TransitEdge('喜多見', 3, 'odakyu'),
    TransitEdge('和泉多摩川', 3, 'odakyu'),
  ],
  '和泉多摩川': [
    TransitEdge('狛江', 3, 'odakyu'),
    TransitEdge('登戸', 3, 'odakyu'),
  ],
  '登戸': [
    TransitEdge('和泉多摩川', 3, 'odakyu'),
    TransitEdge('向ヶ丘遊園', 3, 'odakyu'),
    TransitEdge('中野島', 4, 'nambu'),
    TransitEdge('宿河原', 3, 'nambu'),
  ],
  '向ヶ丘遊園': [
    TransitEdge('登戸', 3, 'odakyu'),
    TransitEdge('生田', 3, 'odakyu'),
  ],
  '生田': [
    TransitEdge('向ヶ丘遊園', 3, 'odakyu'),
    TransitEdge('読売ランド前', 3, 'odakyu'),
  ],
  '読売ランド前': [
    TransitEdge('生田', 3, 'odakyu'),
    TransitEdge('百合ヶ丘', 3, 'odakyu'),
  ],
  '百合ヶ丘': [
    TransitEdge('読売ランド前', 3, 'odakyu'),
    TransitEdge('新百合ヶ丘', 3, 'odakyu'),
  ],
  '新百合ヶ丘': [
    TransitEdge('百合ヶ丘', 3, 'odakyu'),
    TransitEdge('柿生', 4, 'odakyu'),
  ],
  '柿生': [
    TransitEdge('新百合ヶ丘', 4, 'odakyu'),
    TransitEdge('鶴川', 4, 'odakyu'),
  ],
  '鶴川': [
    TransitEdge('柿生', 4, 'odakyu'),
    TransitEdge('玉川学園前', 4, 'odakyu'),
  ],
  '玉川学園前': [
    TransitEdge('鶴川', 4, 'odakyu'),
    TransitEdge('町田', 4, 'odakyu'),
  ],
  '町田': [
    TransitEdge('玉川学園前', 4, 'odakyu'),
    TransitEdge('相模大野', 4, 'odakyu'),
  ],
  '相模大野': [
    TransitEdge('町田', 4, 'odakyu'),
    TransitEdge('小田急相模原', 4, 'odakyu'),
  ],
  '小田急相模原': [
    TransitEdge('相模大野', 4, 'odakyu'),
    TransitEdge('相武台前', 4, 'odakyu'),
  ],
  '相武台前': [
    TransitEdge('小田急相模原', 4, 'odakyu'),
    TransitEdge('座間', 4, 'odakyu'),
  ],
  '座間': [
    TransitEdge('相武台前', 4, 'odakyu'),
    TransitEdge('海老名', 4, 'odakyu'),
  ],
  '海老名': [
    TransitEdge('座間', 4, 'odakyu'),
    TransitEdge('厚木', 3, 'odakyu'),
  ],
  '厚木': [
    TransitEdge('海老名', 3, 'odakyu'),
    TransitEdge('本厚木', 2, 'odakyu'),
  ],
  '本厚木': [
    TransitEdge('厚木', 2, 'odakyu'),
  ],

  // ─── 東京メトロ銀座線 (ginza) ───────────────────────────────────
  '表参道': [
    TransitEdge('渋谷', 3, 'ginza'),
    TransitEdge('外苑前', 2, 'ginza'),
    TransitEdge('渋谷', 3, 'hanzomon'),
    TransitEdge('青山一丁目', 3, 'hanzomon'),
    TransitEdge('明治神宮前', 3, 'chiyoda'),
    TransitEdge('乃木坂', 3, 'chiyoda'),
  ],
  '外苑前': [
    TransitEdge('表参道', 2, 'ginza'),
    TransitEdge('青山一丁目', 2, 'ginza'),
  ],
  '青山一丁目': [
    TransitEdge('外苑前', 2, 'ginza'),
    TransitEdge('赤坂見附', 3, 'ginza'),
    TransitEdge('表参道', 3, 'hanzomon'),
    TransitEdge('永田町', 4, 'hanzomon'),
  ],
  '赤坂見附': [
    TransitEdge('青山一丁目', 3, 'ginza'),
    TransitEdge('溜池山王', 3, 'ginza'),
    TransitEdge('四ッ谷', 3, 'marunouchi'),
    TransitEdge('国会議事堂前', 3, 'marunouchi'),
  ],
  '溜池山王': [
    TransitEdge('赤坂見附', 3, 'ginza'),
    TransitEdge('虎ノ門', 2, 'ginza'),
    TransitEdge('永田町', 2, 'namboku'),
    TransitEdge('六本木一丁目', 3, 'namboku'),
  ],
  '虎ノ門': [
    TransitEdge('溜池山王', 2, 'ginza'),
    TransitEdge('新橋', 3, 'ginza'),
  ],
  '銀座': [
    TransitEdge('新橋', 3, 'ginza'),
    TransitEdge('京橋', 2, 'ginza'),
    TransitEdge('東銀座', 2, 'hibiya'),
    TransitEdge('日比谷', 2, 'hibiya'),
    TransitEdge('東京', 3, 'marunouchi'),
    TransitEdge('霞ヶ関', 3, 'marunouchi'),
  ],
  '京橋': [
    TransitEdge('銀座', 2, 'ginza'),
    TransitEdge('日本橋', 2, 'ginza'),
  ],
  '日本橋': [
    TransitEdge('京橋', 2, 'ginza'),
    TransitEdge('三越前', 2, 'ginza'),
    TransitEdge('大手町', 3, 'tozai'),  // 東西線 西方向（大手町→竹橋→九段下→飯田橋）
    TransitEdge('茅場町', 2, 'tozai'),  // 東西線 東方向（茅場町→門前仲町→西船橋）
    TransitEdge('人形町', 3, 'toei_asakusa'),
    TransitEdge('宝町', 2, 'toei_asakusa'),
  ],
  '三越前': [
    TransitEdge('日本橋', 2, 'ginza'),
    TransitEdge('神田', 2, 'ginza'),
    TransitEdge('大手町', 2, 'hanzomon'),
    TransitEdge('水天宮前', 3, 'hanzomon'),
  ],
  '末広町': [
    TransitEdge('神田', 2, 'ginza'),
    TransitEdge('上野広小路', 2, 'ginza'),
  ],
  '上野広小路': [
    TransitEdge('末広町', 2, 'ginza'),
    TransitEdge('上野', 2, 'ginza'),
  ],
  '稲荷町': [
    TransitEdge('上野', 2, 'ginza'),
    TransitEdge('田原町', 2, 'ginza'),
  ],
  '田原町': [
    TransitEdge('稲荷町', 2, 'ginza'),
    TransitEdge('浅草', 2, 'ginza'),
  ],
  '浅草': [
    TransitEdge('田原町', 2, 'ginza'),
    TransitEdge('本所吾妻橋', 3, 'toei_asakusa'),
    TransitEdge('蔵前', 3, 'toei_asakusa'),
    TransitEdge('とうきょうスカイツリー', 2, 'tobu_skytree'),
  ],

  // ─── 東京メトロ丸ノ内線 (marunouchi) ───────────────────────────
  '南阿佐ヶ谷': [
    TransitEdge('荻窪', 3, 'marunouchi'),
    TransitEdge('新高円寺', 3, 'marunouchi'),
  ],
  '新高円寺': [
    TransitEdge('南阿佐ヶ谷', 3, 'marunouchi'),
    TransitEdge('東高円寺', 2, 'marunouchi'),
  ],
  '東高円寺': [
    TransitEdge('新高円寺', 2, 'marunouchi'),
    TransitEdge('新中野', 2, 'marunouchi'),
  ],
  '新中野': [
    TransitEdge('東高円寺', 2, 'marunouchi'),
    TransitEdge('中野富士見町', 2, 'marunouchi'),
  ],
  '中野富士見町': [
    TransitEdge('新中野', 2, 'marunouchi'),
    TransitEdge('中野新橋', 2, 'marunouchi'),
  ],
  '中野新橋': [
    TransitEdge('中野富士見町', 2, 'marunouchi'),
    TransitEdge('中野坂上', 2, 'marunouchi'),
  ],
  '中野坂上': [
    TransitEdge('中野新橋', 2, 'marunouchi'),
    TransitEdge('西新宿', 3, 'marunouchi'),
  ],
  '西新宿': [
    TransitEdge('中野坂上', 3, 'marunouchi'),
    TransitEdge('新宿', 2, 'marunouchi'),
  ],
  '新宿三丁目': [
    TransitEdge('新宿', 2, 'marunouchi'),
    TransitEdge('新宿御苑前', 2, 'marunouchi'),
    TransitEdge('新宿', 2, 'toei_shinjuku'),
    TransitEdge('曙橋', 3, 'toei_shinjuku'),
    TransitEdge('北参道', 3, 'fukutoshin'),
    TransitEdge('東新宿', 3, 'fukutoshin'),
  ],
  '新宿御苑前': [
    TransitEdge('新宿三丁目', 2, 'marunouchi'),
    TransitEdge('四谷三丁目', 3, 'marunouchi'),
  ],
  '四谷三丁目': [
    TransitEdge('新宿御苑前', 3, 'marunouchi'),
    TransitEdge('四ッ谷', 3, 'marunouchi'),
  ],
  '国会議事堂前': [
    TransitEdge('赤坂見附', 3, 'marunouchi'),
    TransitEdge('霞ヶ関', 2, 'marunouchi'),
    TransitEdge('霞ヶ関', 2, 'chiyoda'),
    TransitEdge('赤坂', 3, 'chiyoda'),
  ],
  '霞ヶ関': [
    TransitEdge('国会議事堂前', 2, 'marunouchi'),
    TransitEdge('銀座', 3, 'marunouchi'),
    TransitEdge('日比谷', 2, 'hibiya'),
    TransitEdge('神谷町', 3, 'hibiya'),
    TransitEdge('日比谷', 2, 'chiyoda'),
    TransitEdge('国会議事堂前', 2, 'chiyoda'),
  ],
  '大手町': [
    TransitEdge('東京', 2, 'marunouchi'),
    TransitEdge('淡路町', 3, 'marunouchi'),
    TransitEdge('三越前', 2, 'hanzomon'),
    TransitEdge('神保町', 3, 'hanzomon'),
    TransitEdge('日本橋', 3, 'tozai'),
    TransitEdge('竹橋', 3, 'tozai'),
    TransitEdge('二重橋前', 2, 'chiyoda'),
    TransitEdge('新御茶ノ水', 3, 'chiyoda'),
    TransitEdge('神保町', 4, 'toei_mita'),
    TransitEdge('日比谷', 3, 'toei_mita'),
  ],
  '淡路町': [
    TransitEdge('大手町', 3, 'marunouchi'),
    TransitEdge('御茶ノ水', 2, 'marunouchi'),
  ],
  '本郷三丁目': [
    TransitEdge('御茶ノ水', 3, 'marunouchi'),
    TransitEdge('後楽園', 3, 'marunouchi'),
  ],
  '後楽園': [
    TransitEdge('本郷三丁目', 3, 'marunouchi'),
    TransitEdge('茗荷谷', 3, 'marunouchi'),
    TransitEdge('飯田橋', 4, 'namboku'),
    TransitEdge('東大前', 3, 'namboku'),
    TransitEdge('春日', 2, 'toei_mita'),
  ],
  '茗荷谷': [
    TransitEdge('後楽園', 3, 'marunouchi'),
    TransitEdge('新大塚', 3, 'marunouchi'),
  ],
  '新大塚': [
    TransitEdge('茗荷谷', 3, 'marunouchi'),
    TransitEdge('池袋', 3, 'marunouchi'),
  ],

  // ─── 東京メトロ日比谷線 (hibiya) ────────────────────────────────
  '広尾': [
    TransitEdge('恵比寿', 4, 'hibiya'),
    TransitEdge('六本木', 4, 'hibiya'),
  ],
  '六本木': [
    TransitEdge('広尾', 4, 'hibiya'),
    TransitEdge('神谷町', 3, 'hibiya'),
  ],
  '神谷町': [
    TransitEdge('六本木', 3, 'hibiya'),
    TransitEdge('霞ヶ関', 3, 'hibiya'),
  ],
  '日比谷': [
    TransitEdge('霞ヶ関', 2, 'hibiya'),
    TransitEdge('銀座', 2, 'hibiya'),
    TransitEdge('大手町', 3, 'toei_mita'),
    TransitEdge('内幸町', 2, 'toei_mita'),
    TransitEdge('日比谷', 2, 'chiyoda'),
    TransitEdge('二重橋前', 2, 'chiyoda'),
  ],
  '東銀座': [
    TransitEdge('銀座', 2, 'hibiya'),
    TransitEdge('築地', 2, 'hibiya'),
    TransitEdge('新橋', 3, 'toei_asakusa'),
    TransitEdge('宝町', 2, 'toei_asakusa'),
  ],
  '築地': [
    TransitEdge('東銀座', 2, 'hibiya'),
    TransitEdge('八丁堀', 3, 'hibiya'),
  ],
  '八丁堀': [
    TransitEdge('築地', 3, 'hibiya'),
    TransitEdge('茅場町', 2, 'hibiya'),
  ],
  '茅場町': [
    TransitEdge('八丁堀', 2, 'hibiya'),
    TransitEdge('人形町', 3, 'hibiya'),
    TransitEdge('日本橋', 2, 'tozai'),
    TransitEdge('門前仲町', 4, 'tozai'),
  ],
  '人形町': [
    TransitEdge('茅場町', 3, 'hibiya'),
    TransitEdge('小伝馬町', 2, 'hibiya'),
    TransitEdge('日本橋', 3, 'toei_asakusa'),
    TransitEdge('東日本橋', 2, 'toei_asakusa'),
  ],
  '小伝馬町': [
    TransitEdge('人形町', 2, 'hibiya'),
    TransitEdge('秋葉原', 2, 'hibiya'),
  ],
  '仲御徒町': [
    TransitEdge('秋葉原', 2, 'hibiya'),
    TransitEdge('上野', 2, 'hibiya'),
  ],
  '入谷': [
    TransitEdge('上野', 2, 'hibiya'),
    TransitEdge('三ノ輪', 3, 'hibiya'),
  ],
  '三ノ輪': [
    TransitEdge('入谷', 3, 'hibiya'),
    TransitEdge('南千住', 3, 'hibiya'),
  ],
  '南千住': [
    TransitEdge('三ノ輪', 3, 'hibiya'),
    TransitEdge('北千住', 3, 'hibiya'),
  ],
  '北千住': [
    TransitEdge('南千住', 3, 'hibiya'),
    TransitEdge('町屋', 4, 'chiyoda'),
    TransitEdge('牛田', 3, 'tobu_skytree'),
    TransitEdge('小菅', 3, 'tobu_skytree'),
  ],

  // ─── 東京メトロ千代田線 (chiyoda) ───────────────────────────────
  '代々木公園': [
    TransitEdge('代々木上原', 2, 'chiyoda'),
    TransitEdge('明治神宮前', 2, 'chiyoda'),
  ],
  '明治神宮前': [
    TransitEdge('代々木公園', 2, 'chiyoda'),
    TransitEdge('表参道', 3, 'chiyoda'),
    TransitEdge('渋谷', 3, 'fukutoshin'),
    TransitEdge('北参道', 3, 'fukutoshin'),
  ],
  '乃木坂': [
    TransitEdge('表参道', 3, 'chiyoda'),
    TransitEdge('赤坂', 3, 'chiyoda'),
  ],
  '赤坂': [
    TransitEdge('乃木坂', 3, 'chiyoda'),
    TransitEdge('国会議事堂前', 3, 'chiyoda'),
  ],
  '二重橋前': [
    TransitEdge('日比谷', 2, 'chiyoda'),
    TransitEdge('大手町', 2, 'chiyoda'),
  ],
  '新御茶ノ水': [
    TransitEdge('大手町', 3, 'chiyoda'),
    TransitEdge('湯島', 3, 'chiyoda'),
  ],
  '湯島': [
    TransitEdge('新御茶ノ水', 3, 'chiyoda'),
    TransitEdge('根津', 3, 'chiyoda'),
  ],
  '根津': [
    TransitEdge('湯島', 3, 'chiyoda'),
    TransitEdge('千駄木', 3, 'chiyoda'),
  ],
  '千駄木': [
    TransitEdge('根津', 3, 'chiyoda'),
    TransitEdge('西日暮里', 3, 'chiyoda'),
  ],
  '町屋': [
    TransitEdge('西日暮里', 3, 'chiyoda'),
    TransitEdge('北千住', 4, 'chiyoda'),
  ],

  // ─── 東京メトロ半蔵門線 (hanzomon) ─────────────────────────────
  '永田町': [
    TransitEdge('青山一丁目', 4, 'hanzomon'),
    TransitEdge('半蔵門', 3, 'hanzomon'),
    TransitEdge('溜池山王', 2, 'namboku'),
    TransitEdge('四ッ谷', 3, 'namboku'),
    TransitEdge('麹町', 3, 'yurakucho'),
    TransitEdge('桜田門', 3, 'yurakucho'),
  ],
  '半蔵門': [
    TransitEdge('永田町', 3, 'hanzomon'),
    TransitEdge('九段下', 3, 'hanzomon'),
  ],
  '九段下': [
    TransitEdge('半蔵門', 3, 'hanzomon'),
    TransitEdge('神保町', 2, 'hanzomon'),
    TransitEdge('飯田橋', 3, 'tozai'),
    TransitEdge('竹橋', 3, 'tozai'),
    TransitEdge('市ヶ谷', 3, 'toei_shinjuku'),
    TransitEdge('神保町', 2, 'toei_shinjuku'),
  ],
  '神保町': [
    TransitEdge('九段下', 2, 'hanzomon'),
    TransitEdge('大手町', 3, 'hanzomon'),
    TransitEdge('九段下', 2, 'toei_shinjuku'),
    TransitEdge('小川町', 2, 'toei_shinjuku'),
    TransitEdge('大手町', 4, 'toei_mita'),
    TransitEdge('水道橋', 3, 'toei_mita'),
  ],
  '水天宮前': [
    TransitEdge('三越前', 3, 'hanzomon'),
    TransitEdge('清澄白河', 4, 'hanzomon'),
  ],
  '清澄白河': [
    TransitEdge('水天宮前', 4, 'hanzomon'),
    TransitEdge('住吉', 3, 'hanzomon'),
  ],
  '住吉': [
    TransitEdge('清澄白河', 3, 'hanzomon'),
    TransitEdge('錦糸町', 3, 'hanzomon'),
    TransitEdge('西大島', 3, 'toei_shinjuku'),
    TransitEdge('菊川', 2, 'toei_shinjuku'),
  ],
  '押上': [
    TransitEdge('錦糸町', 3, 'hanzomon'),
    TransitEdge('曳舟', 3, 'tobu_skytree'),
    TransitEdge('本所吾妻橋', 2, 'toei_asakusa'),
    TransitEdge('とうきょうスカイツリー', 2, 'tobu_skytree'),
  ],

  // ─── 東京メトロ副都心線 (fukutoshin) ───────────────────────────
  '和光市': [
    TransitEdge('地下鉄成増', 3, 'fukutoshin'),
    TransitEdge('朝霞', 4, 'tobu_tojo'),
    TransitEdge('成増', 3, 'tobu_tojo'),
  ],
  '地下鉄成増': [
    TransitEdge('和光市', 3, 'fukutoshin'),
    TransitEdge('地下鉄赤塚', 3, 'fukutoshin'),
  ],
  '地下鉄赤塚': [
    TransitEdge('地下鉄成増', 3, 'fukutoshin'),
    TransitEdge('平和台', 3, 'fukutoshin'),
  ],
  '平和台': [
    TransitEdge('地下鉄赤塚', 3, 'fukutoshin'),
    TransitEdge('氷川台', 3, 'fukutoshin'),
  ],
  '氷川台': [
    TransitEdge('平和台', 3, 'fukutoshin'),
    TransitEdge('小竹向原', 3, 'fukutoshin'),
  ],
  '小竹向原': [
    TransitEdge('氷川台', 3, 'fukutoshin'),
    TransitEdge('千川', 2, 'fukutoshin'),
  ],
  '千川': [
    TransitEdge('小竹向原', 2, 'fukutoshin'),
    TransitEdge('要町', 2, 'fukutoshin'),
  ],
  '要町': [
    TransitEdge('千川', 2, 'fukutoshin'),
    TransitEdge('池袋', 3, 'fukutoshin'),
  ],
  '雑司が谷': [
    TransitEdge('池袋', 3, 'fukutoshin'),
    TransitEdge('西早稲田', 3, 'fukutoshin'),
  ],
  '西早稲田': [
    TransitEdge('雑司が谷', 3, 'fukutoshin'),
    TransitEdge('東新宿', 3, 'fukutoshin'),
  ],
  '東新宿': [
    TransitEdge('西早稲田', 3, 'fukutoshin'),
    TransitEdge('新宿三丁目', 2, 'fukutoshin'),
  ],
  '北参道': [
    TransitEdge('新宿三丁目', 3, 'fukutoshin'),
    TransitEdge('明治神宮前', 3, 'fukutoshin'),
  ],

  // ─── 東京メトロ南北線 (namboku) ─────────────────────────────────
  '白金台': [
    TransitEdge('目黒', 3, 'namboku'),
    TransitEdge('白金高輪', 2, 'namboku'),
    TransitEdge('目黒', 3, 'toei_mita'),
    TransitEdge('白金高輪', 2, 'toei_mita'),
  ],
  '白金高輪': [
    TransitEdge('白金台', 2, 'namboku'),
    TransitEdge('麻布十番', 4, 'namboku'),
    TransitEdge('白金台', 2, 'toei_mita'),
    TransitEdge('三田', 4, 'toei_mita'),
  ],
  '麻布十番': [
    TransitEdge('白金高輪', 4, 'namboku'),
    TransitEdge('六本木一丁目', 3, 'namboku'),
  ],
  '六本木一丁目': [
    TransitEdge('麻布十番', 3, 'namboku'),
    TransitEdge('溜池山王', 3, 'namboku'),
  ],
  '東大前': [
    TransitEdge('後楽園', 3, 'namboku'),
    TransitEdge('本駒込', 3, 'namboku'),
  ],
  '本駒込': [
    TransitEdge('東大前', 3, 'namboku'),
    TransitEdge('駒込', 2, 'namboku'),
  ],
  '西ヶ原': [
    TransitEdge('駒込', 3, 'namboku'),
    TransitEdge('王子', 3, 'namboku'),
  ],
  '王子神谷': [
    TransitEdge('王子', 3, 'namboku'),
    TransitEdge('志茂', 3, 'namboku'),
  ],
  '志茂': [
    TransitEdge('王子神谷', 3, 'namboku'),
    TransitEdge('赤羽岩淵', 3, 'namboku'),
  ],
  '赤羽岩淵': [
    TransitEdge('志茂', 3, 'namboku'),
    TransitEdge('赤羽', 3, 'namboku'),
  ],

  // ─── 都営浅草線 (toei_asakusa) ──────────────────────────────────
  '西馬込': [
    TransitEdge('馬込', 3, 'toei_asakusa'),
  ],
  '馬込': [
    TransitEdge('西馬込', 3, 'toei_asakusa'),
    TransitEdge('中延', 3, 'toei_asakusa'),
  ],
  '中延': [
    TransitEdge('馬込', 3, 'toei_asakusa'),
    TransitEdge('戸越', 3, 'toei_asakusa'),
  ],
  '戸越': [
    TransitEdge('中延', 3, 'toei_asakusa'),
    TransitEdge('五反田', 3, 'toei_asakusa'),
  ],
  '高輪台': [
    TransitEdge('五反田', 3, 'toei_asakusa'),
    TransitEdge('泉岳寺', 3, 'toei_asakusa'),
  ],
  '泉岳寺': [
    TransitEdge('高輪台', 3, 'toei_asakusa'),
    TransitEdge('三田', 3, 'toei_asakusa'),
  ],
  '三田': [
    TransitEdge('泉岳寺', 3, 'toei_asakusa'),
    TransitEdge('大門', 3, 'toei_asakusa'),
    TransitEdge('白金高輪', 4, 'toei_mita'),
    TransitEdge('芝公園', 3, 'toei_mita'),
  ],
  '大門': [
    TransitEdge('三田', 3, 'toei_asakusa'),
    TransitEdge('新橋', 3, 'toei_asakusa'),
  ],
  '宝町': [
    TransitEdge('東銀座', 2, 'toei_asakusa'),
    TransitEdge('日本橋', 3, 'toei_asakusa'),
  ],
  '東日本橋': [
    TransitEdge('人形町', 2, 'toei_asakusa'),
    TransitEdge('浅草橋', 2, 'toei_asakusa'),
  ],
  '蔵前': [
    TransitEdge('浅草橋', 3, 'toei_asakusa'),
    TransitEdge('浅草', 3, 'toei_asakusa'),
  ],
  '本所吾妻橋': [
    TransitEdge('浅草', 3, 'toei_asakusa'),
    TransitEdge('押上', 2, 'toei_asakusa'),
  ],

  // ─── 都営三田線 (toei_mita) ─────────────────────────────────────
  '芝公園': [
    TransitEdge('三田', 3, 'toei_mita'),
    TransitEdge('御成門', 2, 'toei_mita'),
  ],
  '御成門': [
    TransitEdge('芝公園', 2, 'toei_mita'),
    TransitEdge('内幸町', 2, 'toei_mita'),
  ],
  '内幸町': [
    TransitEdge('御成門', 2, 'toei_mita'),
    TransitEdge('日比谷', 2, 'toei_mita'),
  ],
  '春日': [
    TransitEdge('水道橋', 2, 'toei_mita'),
    TransitEdge('白山', 3, 'toei_mita'),
    TransitEdge('後楽園', 2, 'toei_mita'),
  ],
  '白山': [
    TransitEdge('春日', 3, 'toei_mita'),
    TransitEdge('千石', 3, 'toei_mita'),
  ],
  '千石': [
    TransitEdge('白山', 3, 'toei_mita'),
    TransitEdge('巣鴨', 2, 'toei_mita'),
  ],
  '西巣鴨': [
    TransitEdge('巣鴨', 3, 'toei_mita'),
    TransitEdge('新板橋', 3, 'toei_mita'),
  ],
  '新板橋': [
    TransitEdge('西巣鴨', 3, 'toei_mita'),
    TransitEdge('板橋区役所前', 3, 'toei_mita'),
  ],
  '板橋区役所前': [
    TransitEdge('新板橋', 3, 'toei_mita'),
    TransitEdge('板橋本町', 2, 'toei_mita'),
  ],
  '板橋本町': [
    TransitEdge('板橋区役所前', 2, 'toei_mita'),
    TransitEdge('本蓮沼', 3, 'toei_mita'),
  ],
  '本蓮沼': [
    TransitEdge('板橋本町', 3, 'toei_mita'),
    TransitEdge('志村坂上', 3, 'toei_mita'),
  ],
  '志村坂上': [
    TransitEdge('本蓮沼', 3, 'toei_mita'),
    TransitEdge('志村三丁目', 2, 'toei_mita'),
  ],
  '志村三丁目': [
    TransitEdge('志村坂上', 2, 'toei_mita'),
    TransitEdge('蓮根', 3, 'toei_mita'),
  ],
  '蓮根': [
    TransitEdge('志村三丁目', 3, 'toei_mita'),
    TransitEdge('西台', 3, 'toei_mita'),
  ],
  '西台': [
    TransitEdge('蓮根', 3, 'toei_mita'),
    TransitEdge('高島平', 3, 'toei_mita'),
  ],
  '高島平': [
    TransitEdge('西台', 3, 'toei_mita'),
    TransitEdge('新高島平', 3, 'toei_mita'),
  ],
  '新高島平': [
    TransitEdge('高島平', 3, 'toei_mita'),
    TransitEdge('西高島平', 3, 'toei_mita'),
  ],
  '西高島平': [
    TransitEdge('新高島平', 3, 'toei_mita'),
  ],

  // ─── 都営新宿線 (toei_shinjuku) ─────────────────────────────────
  '曙橋': [
    TransitEdge('新宿三丁目', 3, 'toei_shinjuku'),
    TransitEdge('市ヶ谷', 3, 'toei_shinjuku'),
  ],
  '小川町': [
    TransitEdge('神保町', 2, 'toei_shinjuku'),
    TransitEdge('岩本町', 3, 'toei_shinjuku'),
  ],
  '岩本町': [
    TransitEdge('小川町', 3, 'toei_shinjuku'),
    TransitEdge('馬喰横山', 3, 'toei_shinjuku'),
  ],
  '馬喰横山': [
    TransitEdge('岩本町', 3, 'toei_shinjuku'),
    TransitEdge('浜町', 2, 'toei_shinjuku'),
  ],
  '浜町': [
    TransitEdge('馬喰横山', 2, 'toei_shinjuku'),
    TransitEdge('森下', 3, 'toei_shinjuku'),
  ],
  '森下': [
    TransitEdge('浜町', 3, 'toei_shinjuku'),
    TransitEdge('菊川', 2, 'toei_shinjuku'),
  ],
  '菊川': [
    TransitEdge('森下', 2, 'toei_shinjuku'),
    TransitEdge('住吉', 3, 'toei_shinjuku'),
  ],
  '西大島': [
    TransitEdge('住吉', 3, 'toei_shinjuku'),
    TransitEdge('大島', 3, 'toei_shinjuku'),
  ],
  '大島': [
    TransitEdge('西大島', 3, 'toei_shinjuku'),
    TransitEdge('東大島', 4, 'toei_shinjuku'),
  ],
  '東大島': [
    TransitEdge('大島', 4, 'toei_shinjuku'),
    TransitEdge('船堀', 5, 'toei_shinjuku'),
  ],
  '船堀': [
    TransitEdge('東大島', 5, 'toei_shinjuku'),
    TransitEdge('一之江', 4, 'toei_shinjuku'),
  ],
  '一之江': [
    TransitEdge('船堀', 4, 'toei_shinjuku'),
    TransitEdge('瑞江', 4, 'toei_shinjuku'),
  ],
  '瑞江': [
    TransitEdge('一之江', 4, 'toei_shinjuku'),
    TransitEdge('篠崎', 4, 'toei_shinjuku'),
  ],
  '篠崎': [
    TransitEdge('瑞江', 4, 'toei_shinjuku'),
    TransitEdge('本八幡', 4, 'toei_shinjuku'),
  ],

  // ─── 東武東上線 (tobu_tojo) ─────────────────────────────────────
  '北池袋': [
    TransitEdge('池袋', 3, 'tobu_tojo'),
    TransitEdge('下板橋', 2, 'tobu_tojo'),
  ],
  '下板橋': [
    TransitEdge('北池袋', 2, 'tobu_tojo'),
    TransitEdge('大山', 3, 'tobu_tojo'),
  ],
  '大山': [
    TransitEdge('下板橋', 3, 'tobu_tojo'),
    TransitEdge('中板橋', 2, 'tobu_tojo'),
  ],
  '中板橋': [
    TransitEdge('大山', 2, 'tobu_tojo'),
    TransitEdge('ときわ台', 3, 'tobu_tojo'),
  ],
  'ときわ台': [
    TransitEdge('中板橋', 3, 'tobu_tojo'),
    TransitEdge('上板橋', 3, 'tobu_tojo'),
  ],
  '上板橋': [
    TransitEdge('ときわ台', 3, 'tobu_tojo'),
    TransitEdge('東武練馬', 3, 'tobu_tojo'),
  ],
  '東武練馬': [
    TransitEdge('上板橋', 3, 'tobu_tojo'),
    TransitEdge('下赤塚', 3, 'tobu_tojo'),
  ],
  '下赤塚': [
    TransitEdge('東武練馬', 3, 'tobu_tojo'),
    TransitEdge('成増', 3, 'tobu_tojo'),
  ],
  '成増': [
    TransitEdge('下赤塚', 3, 'tobu_tojo'),
    TransitEdge('和光市', 4, 'tobu_tojo'),
  ],
  '朝霞': [
    TransitEdge('和光市', 4, 'tobu_tojo'),
    TransitEdge('朝霞台', 3, 'tobu_tojo'),
  ],
  '朝霞台': [
    TransitEdge('朝霞', 3, 'tobu_tojo'),
    TransitEdge('志木', 3, 'tobu_tojo'),
  ],
  '志木': [
    TransitEdge('朝霞台', 3, 'tobu_tojo'),
    TransitEdge('柳瀬川', 4, 'tobu_tojo'),
  ],
  '柳瀬川': [
    TransitEdge('志木', 4, 'tobu_tojo'),
    TransitEdge('みずほ台', 3, 'tobu_tojo'),
  ],
  'みずほ台': [
    TransitEdge('柳瀬川', 3, 'tobu_tojo'),
    TransitEdge('鶴瀬', 3, 'tobu_tojo'),
  ],
  '鶴瀬': [
    TransitEdge('みずほ台', 3, 'tobu_tojo'),
    TransitEdge('ふじみ野', 4, 'tobu_tojo'),
  ],
  'ふじみ野': [
    TransitEdge('鶴瀬', 4, 'tobu_tojo'),
    TransitEdge('上福岡', 4, 'tobu_tojo'),
  ],
  '上福岡': [
    TransitEdge('ふじみ野', 4, 'tobu_tojo'),
    TransitEdge('新河岸', 4, 'tobu_tojo'),
  ],
  '新河岸': [
    TransitEdge('上福岡', 4, 'tobu_tojo'),
    TransitEdge('川越', 5, 'tobu_tojo'),
  ],
  '川越': [
    TransitEdge('新河岸', 5, 'tobu_tojo'),
  ],

  // ─── 東武スカイツリーライン (tobu_skytree) ──────────────────────
  'とうきょうスカイツリー': [
    TransitEdge('浅草', 2, 'tobu_skytree'),
    TransitEdge('押上', 2, 'tobu_skytree'),
  ],
  '曳舟': [
    TransitEdge('押上', 3, 'tobu_skytree'),
    TransitEdge('東向島', 2, 'tobu_skytree'),
  ],
  '東向島': [
    TransitEdge('曳舟', 2, 'tobu_skytree'),
    TransitEdge('鐘ヶ淵', 2, 'tobu_skytree'),
  ],
  '鐘ヶ淵': [
    TransitEdge('東向島', 2, 'tobu_skytree'),
    TransitEdge('堀切', 3, 'tobu_skytree'),
  ],
  '堀切': [
    TransitEdge('鐘ヶ淵', 3, 'tobu_skytree'),
    TransitEdge('牛田', 2, 'tobu_skytree'),
  ],
  '牛田': [
    TransitEdge('堀切', 2, 'tobu_skytree'),
    TransitEdge('北千住', 3, 'tobu_skytree'),
  ],
  '小菅': [
    TransitEdge('北千住', 3, 'tobu_skytree'),
    TransitEdge('五反野', 2, 'tobu_skytree'),
  ],
  '五反野': [
    TransitEdge('小菅', 2, 'tobu_skytree'),
    TransitEdge('梅島', 3, 'tobu_skytree'),
  ],
  '梅島': [
    TransitEdge('五反野', 3, 'tobu_skytree'),
    TransitEdge('西新井', 3, 'tobu_skytree'),
  ],
  '西新井': [
    TransitEdge('梅島', 3, 'tobu_skytree'),
    TransitEdge('竹ノ塚', 4, 'tobu_skytree'),
  ],
  '竹ノ塚': [
    TransitEdge('西新井', 4, 'tobu_skytree'),
    TransitEdge('谷塚', 5, 'tobu_skytree'),
  ],
  '谷塚': [
    TransitEdge('竹ノ塚', 5, 'tobu_skytree'),
    TransitEdge('草加', 4, 'tobu_skytree'),
  ],
  '草加': [
    TransitEdge('谷塚', 4, 'tobu_skytree'),
  ],

  // ─── JR埼京線 (saikyo) ──────────────────────────────────────────
  '北与野': [
    TransitEdge('大宮', 4, 'saikyo'),
    TransitEdge('与野本町', 3, 'saikyo'),
  ],
  '与野本町': [
    TransitEdge('北与野', 3, 'saikyo'),
    TransitEdge('中浦和', 3, 'saikyo'),
  ],
  '中浦和': [
    TransitEdge('与野本町', 3, 'saikyo'),
    TransitEdge('南与野', 3, 'saikyo'),
  ],
  '南与野': [
    TransitEdge('中浦和', 3, 'saikyo'),
    TransitEdge('武蔵浦和', 3, 'saikyo'),
  ],
  '武蔵浦和': [
    TransitEdge('南与野', 3, 'saikyo'),
    TransitEdge('戸田公園', 4, 'saikyo'),
  ],
  '戸田公園': [
    TransitEdge('武蔵浦和', 4, 'saikyo'),
    TransitEdge('戸田', 3, 'saikyo'),
  ],
  '戸田': [
    TransitEdge('戸田公園', 3, 'saikyo'),
    TransitEdge('北赤羽', 4, 'saikyo'),
  ],
  '北赤羽': [
    TransitEdge('戸田', 4, 'saikyo'),
    TransitEdge('赤羽', 3, 'saikyo'),
  ],
  '十条': [
    TransitEdge('赤羽', 3, 'saikyo'),
    TransitEdge('板橋', 3, 'saikyo'),
  ],
  '板橋': [
    TransitEdge('十条', 3, 'saikyo'),
    TransitEdge('池袋', 4, 'saikyo'),
  ],
  '西大井': [
    TransitEdge('大崎', 5, 'saikyo'),
    TransitEdge('品川', 5, 'saikyo'),
    TransitEdge('大崎', 5, 'shonan'),
    TransitEdge('品川', 5, 'shonan'),
    TransitEdge('武蔵小杉', 5, 'nambu'),
  ],

  // ─── 西武池袋線 (seibu_ikebukuro) ──────────────────────────────
  '椎名町': [
    TransitEdge('池袋', 3, 'seibu_ikebukuro'),
    TransitEdge('東長崎', 3, 'seibu_ikebukuro'),
  ],
  '東長崎': [
    TransitEdge('椎名町', 3, 'seibu_ikebukuro'),
    TransitEdge('江古田', 3, 'seibu_ikebukuro'),
  ],
  '江古田': [
    TransitEdge('東長崎', 3, 'seibu_ikebukuro'),
    TransitEdge('桜台', 2, 'seibu_ikebukuro'),
  ],
  '桜台': [
    TransitEdge('江古田', 2, 'seibu_ikebukuro'),
    TransitEdge('練馬', 3, 'seibu_ikebukuro'),
  ],
  '練馬': [
    TransitEdge('桜台', 3, 'seibu_ikebukuro'),
    TransitEdge('中村橋', 3, 'seibu_ikebukuro'),
  ],
  '中村橋': [
    TransitEdge('練馬', 3, 'seibu_ikebukuro'),
    TransitEdge('富士見台', 2, 'seibu_ikebukuro'),
  ],
  '富士見台': [
    TransitEdge('中村橋', 2, 'seibu_ikebukuro'),
    TransitEdge('練馬高野台', 3, 'seibu_ikebukuro'),
  ],
  '練馬高野台': [
    TransitEdge('富士見台', 3, 'seibu_ikebukuro'),
    TransitEdge('石神井公園', 3, 'seibu_ikebukuro'),
  ],
  '石神井公園': [
    TransitEdge('練馬高野台', 3, 'seibu_ikebukuro'),
    TransitEdge('大泉学園', 4, 'seibu_ikebukuro'),
  ],
  '大泉学園': [
    TransitEdge('石神井公園', 4, 'seibu_ikebukuro'),
    TransitEdge('保谷', 4, 'seibu_ikebukuro'),
  ],
  '保谷': [
    TransitEdge('大泉学園', 4, 'seibu_ikebukuro'),
    TransitEdge('ひばりが丘', 4, 'seibu_ikebukuro'),
  ],
  'ひばりが丘': [
    TransitEdge('保谷', 4, 'seibu_ikebukuro'),
    TransitEdge('東久留米', 4, 'seibu_ikebukuro'),
  ],
  '東久留米': [
    TransitEdge('ひばりが丘', 4, 'seibu_ikebukuro'),
    TransitEdge('清瀬', 5, 'seibu_ikebukuro'),
  ],
  '清瀬': [
    TransitEdge('東久留米', 5, 'seibu_ikebukuro'),
    TransitEdge('秋津', 4, 'seibu_ikebukuro'),
  ],
  '秋津': [
    TransitEdge('清瀬', 4, 'seibu_ikebukuro'),
    TransitEdge('所沢', 4, 'seibu_ikebukuro'),
  ],
  '所沢': [
    TransitEdge('秋津', 4, 'seibu_ikebukuro'),
  ],

  // ─── JR武蔵野線 (musashino) ─────────────────────────────────────
  '東恋ヶ窪': [
    TransitEdge('西国分寺', 3, 'musashino'),
    TransitEdge('新小平', 4, 'musashino'),
  ],
  '新小平': [
    TransitEdge('東恋ヶ窪', 4, 'musashino'),
    TransitEdge('新秋津', 5, 'musashino'),
  ],
  '新秋津': [
    TransitEdge('新小平', 5, 'musashino'),
    TransitEdge('東所沢', 5, 'musashino'),
  ],
  '東所沢': [
    TransitEdge('新秋津', 5, 'musashino'),
  ],

  // ─── JR南武線 (nambu) ───────────────────────────────────────────
  '矢向': [
    TransitEdge('川崎', 4, 'nambu'),
    TransitEdge('鹿島田', 3, 'nambu'),
  ],
  '鹿島田': [
    TransitEdge('矢向', 3, 'nambu'),
    TransitEdge('平間', 3, 'nambu'),
  ],
  '平間': [
    TransitEdge('鹿島田', 3, 'nambu'),
    TransitEdge('向河原', 3, 'nambu'),
  ],
  '向河原': [
    TransitEdge('平間', 3, 'nambu'),
    TransitEdge('武蔵小杉', 3, 'nambu'),
  ],
  '武蔵中原': [
    TransitEdge('武蔵小杉', 4, 'nambu'),
    TransitEdge('武蔵新城', 3, 'nambu'),
  ],
  '武蔵新城': [
    TransitEdge('武蔵中原', 3, 'nambu'),
    TransitEdge('武蔵溝ノ口', 4, 'nambu'),
  ],
  '武蔵溝ノ口': [
    TransitEdge('武蔵新城', 4, 'nambu'),
    TransitEdge('溝の口', 4, 'nambu'),
    TransitEdge('津田山', 3, 'nambu'),
  ],
  '津田山': [
    TransitEdge('武蔵溝ノ口', 3, 'nambu'),
    TransitEdge('久地', 3, 'nambu'),
  ],
  '久地': [
    TransitEdge('津田山', 3, 'nambu'),
    TransitEdge('宿河原', 3, 'nambu'),
  ],
  '宿河原': [
    TransitEdge('久地', 3, 'nambu'),
    TransitEdge('登戸', 3, 'nambu'),
  ],
  '中野島': [
    TransitEdge('登戸', 4, 'nambu'),
    TransitEdge('稲田堤', 3, 'nambu'),
  ],
  '稲田堤': [
    TransitEdge('中野島', 3, 'nambu'),
    TransitEdge('矢野口', 4, 'nambu'),
  ],
  '矢野口': [
    TransitEdge('稲田堤', 4, 'nambu'),
    TransitEdge('稲城長沼', 3, 'nambu'),
  ],
  '稲城長沼': [
    TransitEdge('矢野口', 3, 'nambu'),
    TransitEdge('南多摩', 4, 'nambu'),
  ],
  '南多摩': [
    TransitEdge('稲城長沼', 4, 'nambu'),
    TransitEdge('府中本町', 4, 'nambu'),
  ],
  '府中本町': [
    TransitEdge('南多摩', 4, 'nambu'),
    TransitEdge('分倍河原', 4, 'nambu'),
  ],
  '分倍河原': [
    TransitEdge('府中本町', 4, 'nambu'),
    TransitEdge('西府', 3, 'nambu'),
  ],
  '西府': [
    TransitEdge('分倍河原', 3, 'nambu'),
    TransitEdge('谷保', 4, 'nambu'),
  ],
  '谷保': [
    TransitEdge('西府', 4, 'nambu'),
    TransitEdge('矢川', 3, 'nambu'),
  ],
  '矢川': [
    TransitEdge('谷保', 3, 'nambu'),
    TransitEdge('西国立', 3, 'nambu'),
  ],
  '西国立': [
    TransitEdge('矢川', 3, 'nambu'),
    TransitEdge('立川', 3, 'nambu'),
  ],

  // ─── 東京メトロ東西線 (tozai) ───────────────────────────────────
  '落合': [
    TransitEdge('中野', 4, 'tozai'),
    TransitEdge('高田馬場', 4, 'tozai'),
  ],
  '早稲田': [
    TransitEdge('高田馬場', 3, 'tozai'),
    TransitEdge('神楽坂', 3, 'tozai'),
  ],
  '神楽坂': [
    TransitEdge('早稲田', 3, 'tozai'),
    TransitEdge('飯田橋', 3, 'tozai'),
  ],
  '竹橋': [
    TransitEdge('九段下', 3, 'tozai'),
    TransitEdge('大手町', 3, 'tozai'),
  ],
  '門前仲町': [
    TransitEdge('茅場町', 4, 'tozai'),
    TransitEdge('木場', 3, 'tozai'),
  ],
  '木場': [
    TransitEdge('門前仲町', 3, 'tozai'),
    TransitEdge('東陽町', 3, 'tozai'),
  ],
  '東陽町': [
    TransitEdge('木場', 3, 'tozai'),
    TransitEdge('南砂町', 3, 'tozai'),
  ],
  '南砂町': [
    TransitEdge('東陽町', 3, 'tozai'),
    TransitEdge('西葛西', 5, 'tozai'),
  ],
  '西葛西': [
    TransitEdge('南砂町', 5, 'tozai'),
    TransitEdge('葛西', 3, 'tozai'),
  ],
  '葛西': [
    TransitEdge('西葛西', 3, 'tozai'),
    TransitEdge('浦安', 5, 'tozai'),
  ],
  '浦安': [
    TransitEdge('葛西', 5, 'tozai'),
    TransitEdge('南行徳', 3, 'tozai'),
  ],
  '南行徳': [
    TransitEdge('浦安', 3, 'tozai'),
    TransitEdge('行徳', 3, 'tozai'),
  ],
  '行徳': [
    TransitEdge('南行徳', 3, 'tozai'),
    TransitEdge('妙典', 3, 'tozai'),
  ],
  '妙典': [
    TransitEdge('行徳', 3, 'tozai'),
    TransitEdge('原木中山', 4, 'tozai'),
  ],
  '原木中山': [
    TransitEdge('妙典', 4, 'tozai'),
    TransitEdge('西船橋', 3, 'tozai'),
  ],
  '西船橋': [
    TransitEdge('原木中山', 3, 'tozai'),
  ],

  // ─── 藤沢（小田急江ノ島線・JR東海道線方面）─────────────────────
  // 藤沢は kStations に含まれるが主要路線に含まれていないため接続を追加
  '藤沢': [
    TransitEdge('相模大野', 15, 'odakyu'),
    TransitEdge('横浜', 20, 'jr_tokaido'),
  ],

  // ─── 柏（常磐線）────────────────────────────────────────────────
  '柏': [
    TransitEdge('北千住', 25, 'joban'),
    TransitEdge('松戸', 10, 'joban'),
  ],
  '松戸': [
    TransitEdge('柏', 10, 'joban'),
    TransitEdge('北千住', 15, 'joban'),
  ],

  // ─── 有楽町線 (yurakucho) ────────────────────────────────────────
  '東池袋': [
    TransitEdge('池袋', 1, 'yurakucho'),
    TransitEdge('護国寺', 3, 'yurakucho'),
  ],
  '護国寺': [
    TransitEdge('東池袋', 3, 'yurakucho'),
    TransitEdge('江戸川橋', 3, 'yurakucho'),
  ],
  '江戸川橋': [
    TransitEdge('護国寺', 3, 'yurakucho'),
    TransitEdge('飯田橋', 4, 'yurakucho'),
  ],
  '麹町': [
    TransitEdge('市ヶ谷', 3, 'yurakucho'),
    TransitEdge('永田町', 3, 'yurakucho'),
  ],
  '桜田門': [
    TransitEdge('永田町', 3, 'yurakucho'),
    TransitEdge('有楽町', 3, 'yurakucho'),
  ],
  '銀座一丁目': [
    TransitEdge('有楽町', 2, 'yurakucho'),
    TransitEdge('新富町', 2, 'yurakucho'),
  ],
  '新富町': [
    TransitEdge('銀座一丁目', 2, 'yurakucho'),
    TransitEdge('月島', 5, 'yurakucho'),
  ],
  '月島': [
    TransitEdge('新富町', 5, 'yurakucho'),
  ],
};
