import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finansal_takip_app/services/database_services.dart';
import 'package:finansal_takip_app/services/yedekleme_service.dart';

void main() {
  setUpAll(() async {
    // Servis doğrudan Hive.box(...) ile kutulara erişir; testte geçici
    // dizinde aynı isimlerle kutular açıyoruz (uygulamadaki init'in karşılığı)
    final temp = await Directory.systemTemp.createTemp('yedek_test');
    Hive.init(temp.path);
    await Hive.openBox<Map>(DatabaseService.todoBoxName);
    await Hive.openBox<Map>(DatabaseService.documentBoxName);
    await Hive.openBox<Map>(DatabaseService.cekBoxName);
    await Hive.openBox<Map>(DatabaseService.firmaBoxName);
  });

  tearDown(() async {
    await Hive.box<Map>(DatabaseService.todoBoxName).clear();
    await Hive.box<Map>(DatabaseService.documentBoxName).clear();
    await Hive.box<Map>(DatabaseService.cekBoxName).clear();
    await Hive.box<Map>(DatabaseService.firmaBoxName).clear();
  });

  test('yedek → veriyi sil → geri yükle turu veriyi birebir korur', () async {
    final cekKutusu = Hive.box<Map>(DatabaseService.cekBoxName);
    final firmaKutusu = Hive.box<Map>(DatabaseService.firmaBoxName);
    final gorevKutusu = Hive.box<Map>(DatabaseService.todoBoxName);

    await cekKutusu.put("10001", {
      "id": "10001",
      "tur": "tahsil",
      "tarih": "01.12.2026",
      "tutar": "24.000,50",
      "paraBirimi": "TL",
      "firmaId": "f1",
      "cekNo": "123",
      "banka": "Ziraat Bankası",
      "aciklama": "Malzeme ödemesi",
      "isPaid": false,
    });
    await firmaKutusu.put("f1", {
      "id": "f1",
      "ad": "Test Firması",
      "telefon": "05550001122",
      "aciklama": "",
    });
    await gorevKutusu.put("g1", {
      "id": "g1",
      "title": "Kasa sayımı",
      "isCompleted": false,
      "vadeTarihi": "20.11.2026",
    });

    // 1) Yedeği al
    final icerik = await YedeklemeService.yedekOlustur();
    final ozet = YedeklemeService.yedekOzeti(icerik);
    expect(ozet.cek, 1);
    expect(ozet.firma, 1);
    expect(ozet.gorev, 1);

    // 2) Veriyi sil + yabancı kayıt ekle (geri yükleme sonrası kalmamalı)
    await cekKutusu.clear();
    await firmaKutusu.clear();
    await gorevKutusu.clear();
    await firmaKutusu.put("f2", {"id": "f2", "ad": "Sonradan Eklenen"});

    // 3) Geri yükle
    await YedeklemeService.geriYukle(icerik);

    final cek = cekKutusu.get("10001");
    expect(cek, isNotNull);
    expect(cek!["tutar"], "24.000,50");
    expect(cek["firmaId"], "f1");
    expect(cek["cekNo"], "123");

    expect(firmaKutusu.length, 1, reason: "yedekte olmayan kayıt temizlenmeli");
    expect(firmaKutusu.get("f1")?["ad"], "Test Firması");
    expect(gorevKutusu.get("g1")?["title"], "Kasa sayımı");
  });

  test('geçersiz yedek dosyaları reddedilir (FormatException)', () {
    expect(
      () => YedeklemeService.yedekOzeti("bu bir json değil"),
      throwsFormatException,
    );
    expect(
      () => YedeklemeService.yedekOzeti('{"baska": "yapi"}'),
      throwsFormatException,
    );
    expect(
      () => YedeklemeService.yedekOzeti('{"surum": 1, "kutular": "liste"}'),
      throwsFormatException,
    );
  });

  test('yedek özeti boş kutular için sıfır sayı verir', () async {
    final icerik = await YedeklemeService.yedekOlustur();
    final ozet = YedeklemeService.yedekOzeti(icerik);
    expect(ozet.cek, 0);
    expect(ozet.firma, 0);
    expect(ozet.gorev, 0);
  });
}
