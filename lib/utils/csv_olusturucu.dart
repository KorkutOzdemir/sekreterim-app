import 'package:finansal_takip_app/services/database_services.dart';

/// Çek listelerini Türkçe Excel uyumlu CSV metnine çevirir.
/// Noktalı virgül ayraçlıdır (TR bölge ayarları); tutar ve tarih alanları
/// zaten Türkçe biçimde ("24.000,50" / "dd.MM.yyyy") tutulur.
class CsvOlusturucu {
  CsvOlusturucu._(); // Yalnızca static metotlar içerir, örnek oluşturulamaz

  /// CSV başlık satırı
  static const String baslikSatiri =
      "Tür;Durum;Vade Tarihi;Tutar;Para Birimi;Cari;Çek No;Banka;Açıklama";

  /// Hücrede ; " veya satır sonu varsa çift tırnakla sarar (CSV kuralı)
  static String hucreyiKacisYaz(String deger) {
    if (deger.contains(';') || deger.contains('"') || deger.contains('\n')) {
      return '"${deger.replaceAll('"', '""')}"';
    }
    return deger;
  }

  /// Çek listesini CSV metnine çevirir.
  /// Cari adı, kayıttaki `firmaId`'den güncel olarak çözülür.
  static String olustur(List<Map> cekler) {
    final satirlar = <String>[baslikSatiri];
    for (final cek in cekler) {
      satirlar.add(
        [
          cek["tur"] == "tahsil" ? "Tahsil" : "Ödenecek",
          cek["isPaid"] == true ? "Ödendi" : "Bekliyor",
          (cek["tarih"] ?? "").toString(),
          (cek["tutar"] ?? "").toString(),
          (cek["paraBirimi"] ?? "TL").toString(),
          DatabaseService.firmaAdiGetir(cek["firmaId"]),
          (cek["cekNo"] ?? "").toString(),
          (cek["banka"] ?? "").toString(),
          (cek["aciklama"] ?? "").toString(),
        ].map(hucreyiKacisYaz).join(";"),
      );
    }
    return satirlar.join("\r\n");
  }
}
