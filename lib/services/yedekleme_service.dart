import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:finansal_takip_app/services/database_services.dart';
import 'package:finansal_takip_app/services/notification_service.dart';

/// Tüm Hive kutularını tek bir JSON dosyasına yedekleyen ve geri yükleyen servis.
///
/// Yedek dosya biçimi:
/// {
///   "surum": 1,
///   "tarih": "15.11.2026 14:30",
///   "kutular": {
///     "todos_box": { `"<id>"`: { ...kayıt... }, ... },
///     "cekler_box": { ... },
///     "firmalar_box": { ... }
///   }
/// }
class YedeklemeService {
  /// Yedeğe dahil edilen kutular
  static const List<String> _kutular = [
    DatabaseService.todoBoxName,
    DatabaseService.documentBoxName,
    DatabaseService.cekBoxName,
    DatabaseService.firmaBoxName,
  ];

  /// Tüm kutuların içeriğini okunabilir (girintili) JSON metni olarak döndürür.
  static Future<String> yedekOlustur() async {
    final Map<String, dynamic> kutular = {};
    for (final kutuAdi in _kutular) {
      final Box<Map> kutu = Hive.box<Map>(kutuAdi);
      kutular[kutuAdi] = {
        for (final anahtar in kutu.keys) anahtar.toString(): kutu.get(anahtar),
      };
    }

    final Map<String, dynamic> yedek = {
      "surum": 1,
      "tarih": DateFormat("dd.MM.yyyy HH:mm").format(DateTime.now()),
      "kutular": kutular,
    };

    return const JsonEncoder.withIndent("  ").convert(yedek);
  }

  /// Yedek dosyasının özetini döndürür (onay diyalogunda gösterilir).
  /// Dosya geçersizse FormatException fırlatır.
  static ({String tarih, int cek, int firma, int gorev}) yedekOzeti(String icerik) {
    final Map<String, dynamic> veri = _ayristir(icerik);
    final Map<String, dynamic> kutular = veri["kutular"];

    return (
      tarih: (veri["tarih"] ?? "bilinmiyor").toString(),
      cek: _kayitSayisi(kutular, DatabaseService.cekBoxName),
      firma: _kayitSayisi(kutular, DatabaseService.firmaBoxName),
      gorev: _kayitSayisi(kutular, DatabaseService.todoBoxName),
    );
  }

  /// Yedeği geri yükler: mevcut kutu içerikleri silinir, yedektekiler yazılır.
  /// Silinen çeklerin bildirimleri iptal edilir, geri yüklenen açık çekler için
  /// yeniden kurulur (geçmiş vadeler otomatik atlanır).
  static Future<void> geriYukle(String icerik) async {
    final Map<String, dynamic> veri = _ayristir(icerik);
    final Map<String, dynamic> kutular = veri["kutular"];

    final Box<Map> cekKutusu = Hive.box<Map>(DatabaseService.cekBoxName);

    // 1) Mevcut çeklerin bildirimlerini iptal et (kayacak kayıt kalmasın)
    for (final cek in cekKutusu.values) {
      final String id = (cek["id"] ?? "").toString();
      if (id.isNotEmpty) {
        await NotificationService.cekBildirimleriniIptalEt(id);
      }
    }

    // 2) Kutuları boşalt ve yedektekileri yaz
    for (final kutuAdi in _kutular) {
      final Box<Map> kutu = Hive.box<Map>(kutuAdi);
      await kutu.clear();

      final kayitlar = kutular[kutuAdi];
      if (kayitlar is! Map<String, dynamic>) continue;
      for (final girdi in kayitlar.entries) {
        if (girdi.value is Map) {
          await kutu.put(girdi.key, Map<String, dynamic>.from(girdi.value));
        }
      }
    }

    // 3) Geri yüklenen açık çekler için bildirimleri yeniden kur
    for (final cek in cekKutusu.values) {
      if (cek["isPaid"] == true) continue;
      final String id = (cek["id"] ?? "").toString();
      final String tarih = (cek["tarih"] ?? "").toString();
      if (id.isEmpty || tarih.isEmpty) continue;

      // Bildirim başlığı: açıklama > cari adı > genel ad
      final String aciklama = (cek["aciklama"] ?? "").toString();
      final String firmaAdi = DatabaseService.firmaAdiGetir(cek["firmaId"]);
      final String baslik = aciklama.isNotEmpty
          ? aciklama
          : (firmaAdi.isNotEmpty ? firmaAdi : "Çek/Senet");

      await NotificationService.cekBildirimleriniKur(
        id, tarih, baslik, "${cek["tutar"]} ${cek["paraBirimi"] ?? "TL"}",
      );
    }
  }

  /// JSON metnini ayrıştırır ve temel yapıyı doğrular.
  /// Geçersizse FormatException fırlatır (çağıran tarafa hata mesajı bırakır).
  static Map<String, dynamic> _ayristir(String icerik) {
    final dynamic veri;
    try {
      veri = json.decode(icerik);
    } catch (e) {
      throw const FormatException("Dosya JSON olarak okunamadı.");
    }

    if (veri is! Map<String, dynamic> ||
        veri["kutular"] is! Map<String, dynamic>) {
      throw const FormatException("Dosya bir Sekreterim yedeği değil.");
    }
    return veri;
  }

  /// Belirtilen kutunun yedekteki kayıt sayısını döndürür
  static int _kayitSayisi(Map<String, dynamic> kutular, String kutuAdi) {
    final kayitlar = kutular[kutuAdi];
    if (kayitlar is! Map<String, dynamic>) return 0;
    return kayitlar.values.whereType<Map>().length;
  }
}
