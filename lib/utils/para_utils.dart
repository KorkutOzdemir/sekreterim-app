import 'package:intl/intl.dart';

/// Para tutarlarıyla ilgili ortak yardımcılar.
/// Tutarlar Hive'da serbest metin ("24.000,50" gibi) tutulduğundan
/// toplama ve TL karşılığı hesaplamalarında bu yardımcılar kullanılır.
class ParaUtils {
  ParaUtils._(); // Yalnızca static metotlar içerir, örnek oluşturulamaz

  static final NumberFormat _format = NumberFormat("#,##0.##", "tr_TR");

  /// "24.000,50" gibi serbest metin tutarı sayıya çevirir.
  /// Çevrilemiyorsa null döner (kayıt toplama katılmaz).
  static double? sayiyaCevir(dynamic tutar) {
    final String temiz = tutar
        .toString()
        .replaceAll(RegExp(r'[^0-9,]'), '')
        .replaceAll(',', '.');
    return double.tryParse(temiz);
  }

  /// Sayıyı "150.000,5" biçiminde Türkçe formata çevirir.
  static String yaz(double deger) => _format.format(deger);

  /// {"TL": 150000.0, "USD": 5000.0} haritasını
  /// "150.000 TL • 5.000 USD" biçiminde metne çevirir.
  static String metneCevir(Map<String, double> toplamlar) {
    if (toplamlar.isEmpty) return "Kayıt yok";
    final parcalar = toplamlar.entries
        .map((girdi) => "${yaz(girdi.value)} ${girdi.key}")
        .toList()
      ..sort();
    return parcalar.join("  •  ");
  }
}
