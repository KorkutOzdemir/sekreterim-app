import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class DovizModel {
  final String kod; // "USD" ya da "gram-altin"
  final String isim; // "ABD Doları" ya da "Gram Altın"
  final String alis;
  final String satis;
  final String tur; // "Doviz" veya "Altin"

  DovizModel({
    required this.kod,
    required this.isim,
    required this.alis,
    required this.satis,
    required this.tur,
  });
}

class DovizService {
  // Ana kaynak: hem döviz hem altın/gümüş verir
  static const String _anaKaynak = 'https://finans.truncgil.com/today.json';
  // Yedek kaynak: sadece döviz verir (ana kaynak erişilemezse)
  static const String _yedekKaynak = 'https://www.tcmb.gov.tr/kurlar/today.xml';

  /// Ekranda gösterilecek dövizler (istek üzerine CNY ve JPY eklendi)
  static const List<String> _istenenDovizler = [
    'USD', 'EUR', 'GBP', 'CHF', 'SAR', 'JPY', 'CNY',
  ];

  /// Ekranda gösterilecek altın / gümüş çeşitleri
  static const List<String> _istenenMetaller = [
    'gram-altin', 'gram-has-altin', 'ceyrek-altin', 'yarim-altin',
    'tam-altin', 'cumhuriyet-altini', 'ata-altin', 'resat-altin',
    'ikibucuk-altin', 'besli-altin', 'gremse-altin',
    '14-ayar-altin', '18-ayar-altin', 'gumus',
  ];

  static const Map<String, String> _gorselAdlar = {
    'USD': 'ABD Doları', 'EUR': 'Euro', 'GBP': 'İngiliz Sterlini',
    'CHF': 'İsviçre Frangı', 'SAR': 'Suudi Riyali', 'JPY': 'Japon Yeni',
    'CNY': 'Çin Yuanı', 'TRY': 'Türk Lirası',
    'gram-altin': 'Gram Altın', 'gram-has-altin': 'Gram Has Altın',
    'ceyrek-altin': 'Çeyrek Altın', 'yarim-altin': 'Yarım Altın',
    'tam-altin': 'Tam Altın', 'cumhuriyet-altini': 'Cumhuriyet Altını',
    'ata-altin': 'Ata Lira', 'resat-altin': 'Reşat Altın',
    'ikibucuk-altin': 'İki Buçuklu Altın', 'besli-altin': 'Beşli Altın',
    'gremse-altin': 'Gremse Altın', '14-ayar-altin': '14 Ayar Altın',
    '18-ayar-altin': '18 Ayar Altın', 'gumus': 'Gümüş (Gram)',
  };

  /// Döviz + altın/gümüş verilerini getirir.
  /// Ana kaynak erişilemezse TCMB'ye düşer (yalnız döviz listesi döner).
  static Future<List<DovizModel>> piyasaVerileriniGetir() async {
    try {
      final liste = await _truncgildenGetir();
      if (liste.isNotEmpty) return liste;
    } catch (e) {
      debugPrint("Ana piyasa kaynağına erişilemedi, TCMB deneniyor: $e");
    }

    // Yedek: TCMB (yalnız döviz)
    return _tcmbdenGetir();
  }

  /// TL karşılığı hesaplamada kullanılmak üzere döviz kurlarını
  /// "1 birim = X TL" haritaları olarak döndürür.
  /// - Alış kuru: elinizdeki dövizi bozdururken (tahsil çekleri)
  /// - Satış kuru: döviz alırken (ödenecek çekler)
  /// İki kaynak da erişilemezse boş haritalar döner.
  static Future<({Map<String, double> alis, Map<String, double> satis})>
      kurTablosunuGetir() async {
    final bos = (
      alis: <String, double>{},
      satis: <String, double>{},
    );
    try {
      final liste = await piyasaVerileriniGetir();
      if (liste.isEmpty) return bos;

      final Map<String, double> alis = {};
      final Map<String, double> satis = {};
      for (final doviz in liste) {
        if (doviz.tur != "Doviz") continue;
        double? alisDegeri = double.tryParse(doviz.alis.replaceAll(',', '.'));
        double? satisDegeri = double.tryParse(doviz.satis.replaceAll(',', '.'));
        if (alisDegeri == null || satisDegeri == null) continue;

        // TCMB JPY'yi 100 birim üzerinden bildirir; tek birime indir
        // (truncgil zaten tek birim verir: ~0,2 TL)
        if (doviz.kod == "JPY") {
          if (alisDegeri > 5) alisDegeri /= 100;
          if (satisDegeri > 5) satisDegeri /= 100;
        }

        alis[doviz.kod] = alisDegeri;
        satis[doviz.kod] = satisDegeri;
      }
      return (alis: alis, satis: satis);
    } catch (e) {
      debugPrint("Kur tablosu alınamadı: $e");
      return bos;
    }
  }

  // ---------------------------------------------------------------
  // ANA KAYNAK: truncgil (döviz + altın + gümüş)
  // ---------------------------------------------------------------
  static Future<List<DovizModel>> _truncgildenGetir() async {
    final cevap = await http
        .get(Uri.parse(_anaKaynak))
        .timeout(const Duration(seconds: 15));

    if (cevap.statusCode != 200) {
      throw Exception("Ana kaynak HTTP ${cevap.statusCode} döndürdü");
    }

    final Map<String, dynamic> veri =
        json.decode(utf8.decode(cevap.bodyBytes)) as Map<String, dynamic>;

    final List<DovizModel> liste = [];

    for (final kod in _istenenDovizler) {
      final eleman = veri[kod];
      if (eleman is Map<String, dynamic>) {
        liste.add(_modelOlustur(kod, eleman, "Doviz"));
      }
    }
    for (final kod in _istenenMetaller) {
      final eleman = veri[kod];
      if (eleman is Map<String, dynamic>) {
        liste.add(_modelOlustur(kod, eleman, "Altin"));
      }
    }
    return liste;
  }

  static DovizModel _modelOlustur(
    String kod, Map<String, dynamic> eleman, String tur) {
    return DovizModel(
      kod: kod,
      isim: _gorselAdlar[kod] ?? kod,
      alis: _fiyatYaz(eleman['Alış']),
      satis: _fiyatYaz(eleman['Satış']),
      tur: tur,
    );
  }

  /// "50,3596" gibi gelen değeri "50.36" formatına çevirir.
  static String _fiyatYaz(dynamic deger) {
    final String metin = (deger ?? '').toString().trim().replaceAll(',', '.');
    if (metin.isEmpty) return "-";
    final double? sayi = double.tryParse(metin);
    if (sayi == null) return metin;
    // Küçük değerlerde (gümüş, JPY) 4 hane, büyüklerde 2 hane anlamlı
    return sayi.toStringAsFixed(sayi < 10 ? 4 : 2);
  }

  // ---------------------------------------------------------------
  // YEDEK KAYNAK: TCMB (yalnız döviz)
  // ---------------------------------------------------------------
  static Future<List<DovizModel>> _tcmbdenGetir() async {
    final List<DovizModel> kurListesi = [];

    final cevap = await http
        .get(Uri.parse(_yedekKaynak))
        .timeout(const Duration(seconds: 15));

    if (cevap.statusCode != 200) return kurListesi;

    final dokuman = xml.XmlDocument.parse(utf8.decode(cevap.bodyBytes));

    for (var element in dokuman.findAllElements('Currency')) {
      final String kod = element.getAttribute('CurrencyCode') ?? '';

      if (_istenenDovizler.contains(kod)) {
        final isimler = element.findElements('Isim');
        final alislar = element.findElements('ForexBuying');
        final satislar = element.findElements('ForexSelling');
        if (isimler.isEmpty || alislar.isEmpty || satislar.isEmpty) continue;

        kurListesi.add(DovizModel(
          kod: kod,
          isim: _gorselAdlar[kod] ?? isimler.first.innerText,
          alis: alislar.first.innerText,
          satis: satislar.first.innerText,
          tur: "Doviz",
        ));
      }
    }
    return kurListesi;
  }
}
