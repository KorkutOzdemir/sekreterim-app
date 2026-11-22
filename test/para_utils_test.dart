import 'package:flutter_test/flutter_test.dart';
import 'package:finansal_takip_app/utils/para_utils.dart';

void main() {
  group('ParaUtils.sayiyaCevir', () {
    test('Türkçe binlik/ondalık biçimini sayıya çevirir', () {
      expect(ParaUtils.sayiyaCevir("24.000,50"), 24000.5);
      expect(ParaUtils.sayiyaCevir("150000"), 150000);
      expect(ParaUtils.sayiyaCevir("1.000.000"), 1000000);
    });

    test('birim metni ve boşlukları temizler', () {
      expect(ParaUtils.sayiyaCevir("24.000 TL"), 24000);
      expect(ParaUtils.sayiyaCevir(" 5.000,25 USD "), 5000.25);
    });

    test('çevrilemeyen değerlerde null döner (kayıt toplama katılmaz)', () {
      expect(ParaUtils.sayiyaCevir("abc"), isNull);
      expect(ParaUtils.sayiyaCevir(""), isNull);
      expect(ParaUtils.sayiyaCevir(null), isNull);
      // Birden çok ondalık virgül geçersiz sayı üretir
      expect(ParaUtils.sayiyaCevir("1,000,000"), isNull);
    });
  });

  group('ParaUtils.yaz', () {
    test('binlik ayracı nokta, ondalık virgül kullanır', () {
      expect(ParaUtils.yaz(150000), "150.000");
      expect(ParaUtils.yaz(150000.5), "150.000,5");
      expect(ParaUtils.yaz(0), "0");
    });
  });

  group('ParaUtils.metneCevir', () {
    test('boş harita için "Kayıt yok" döner', () {
      expect(ParaUtils.metneCevir({}), "Kayıt yok");
    });

    test('para birimlerini sıralı ve ayraçlı birleştirir', () {
      final sonuc = ParaUtils.metneCevir({
        "USD": 5000,
        "TL": 150000,
      });
      expect(sonuc, "150.000 TL  •  5.000 USD");
    });
  });
}
