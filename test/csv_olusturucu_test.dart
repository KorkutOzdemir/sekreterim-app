import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finansal_takip_app/services/database_services.dart';
import 'package:finansal_takip_app/utils/csv_olusturucu.dart';

void main() {
  setUpAll(() async {
    // CsvOlusturucu, cari adını çözerken Hive firmalar kutusunu okur
    final temp = await Directory.systemTemp.createTemp('csv_test');
    Hive.init(temp.path);
    await Hive.openBox<Map>(DatabaseService.firmaBoxName);
  });

  Map<String, dynamic> ornekCek({
    String firmaId = "",
    String aciklama = "Malzeme ödemesi",
    bool isPaid = false,
  }) =>
      {
        "id": "10001",
        "tur": "tahsil",
        "tarih": "01.12.2026",
        "tutar": "24.000,50",
        "paraBirimi": "TL",
        "firmaId": firmaId,
        "cekNo": "123",
        "banka": "Ziraat Bankası",
        "aciklama": aciklama,
        "isPaid": isPaid,
      };

  test('başlık satırı ve çek satırı doğru üretilir', () {
    final csv = CsvOlusturucu.olustur([ornekCek()]);
    final satirlar = csv.split("\r\n");

    expect(satirlar.length, 2);
    expect(
      satirlar.first,
      "Tür;Durum;Vade Tarihi;Tutar;Para Birimi;Cari;Çek No;Banka;Açıklama",
    );
    expect(
      satirlar[1],
      "Tahsil;Bekliyor;01.12.2026;24.000,50;TL;;123;Ziraat Bankası;Malzeme ödemesi",
    );
  });

  test('ödemiş çek "Ödendi", ödenecek tür "Ödenecek" yazar', () {
    final csv = CsvOlusturucu.olustur([
      ornekCek(isPaid: true),
      {...ornekCek(), "tur": "odenecek"},
    ]);
    final satirlar = csv.split("\r\n");
    expect(satirlar[1].startsWith("Tahsil;Ödendi"), isTrue);
    expect(satirlar[2].startsWith("Ödenecek;Bekliyor"), isTrue);
  });

  test('cari adı firmaId üzerinden güncel olarak çözülür', () async {
    final firmaKutusu = Hive.box<Map>(DatabaseService.firmaBoxName);
    await firmaKutusu.put("f1", {"id": "f1", "ad": "Test Firması A.Ş."});

    final csv = CsvOlusturucu.olustur([ornekCek(firmaId: "f1")]);
    expect(csv.split("\r\n")[1].contains("Test Firması A.Ş."), isTrue);

    await firmaKutusu.clear();
  });

  test('noktalı virgül veya tırnak içeren hücreler CSV kuralıyla kaçışlanır', () {
    expect(CsvOlusturucu.hucreyiKacisYaz("normal"), "normal");
    expect(CsvOlusturucu.hucreyiKacisYaz("a;b"), '"a;b"');
    expect(CsvOlusturucu.hucreyiKacisYaz('5" x'), '"5"" x"');

    // Kaçışlanan hücre satır içinde bütünlüğünü korur
    final csv = CsvOlusturucu.olustur([ornekCek(aciklama: "vade; uzatıldı")]);
    expect(csv.split("\r\n")[1].contains('"vade; uzatıldı"'), isTrue);
  });

  test('boş liste yalnızca başlık satırı üretir', () {
    final csv = CsvOlusturucu.olustur([]);
    expect(csv, CsvOlusturucu.baslikSatiri);
  });
}
