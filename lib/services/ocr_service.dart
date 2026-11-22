import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

class OcrService {
  /// Çek fotoğrafını okuyup vade tarihi ve tutar bilgisini çıkarır.
  static Future<Map<String, String>> cekOku(String dosyaYolu) async {
    final inputImage = InputImage.fromFilePath(dosyaYolu);
    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final RecognizedText recognizedText = await textRecognizer
          .processImage(inputImage);
      final String hamMetin = recognizedText.text.toUpperCase();

      return {
        "tarih": _tarihBul(hamMetin),
        "tutar": _tutarBul(hamMetin),
      };
    } catch (e) {
      debugPrint("OCR İşleme Hatası: $e");
      return {"tarih": "", "tutar": ""};
    } finally {
      textRecognizer.close();
    }
  }

  // ---------------------------------------------------------------
  // TARİH BULMA
  // ---------------------------------------------------------------

  /// "14.11.2026", "14/11/2026", "14 11 2026", aralarda boşluk olsa bile yakalar.
  static final RegExp _tarihRegex = RegExp(
    r'(\d{1,2})\s*[./\- ]\s*(\d{1,2})\s*[./\- ]\s*(\d{4})',
  );

  /// Çekte iki tarih bulunur: KEŞİDE tarihi (düzenleme) ve VADE tarihi (ödeme).
  /// Formda istenen "Son Ödeme Tarihi" olduğu için tüm tarihleri toplayıp
  /// EN GEÇ olanı (vadeyi) döndürüyoruz.
  static String _tarihBul(String metin) {
    DateTime? enGecTarih;

    for (final Match m in _tarihRegex.allMatches(metin)) {
      final int? gun = int.tryParse(m.group(1)!.trim());
      final int? ay = int.tryParse(m.group(2)!.trim());
      final int? yil = int.tryParse(m.group(3)!.trim());

      if (gun == null || ay == null || yil == null) continue;
      if (gun < 1 || gun > 31 || ay < 1 || ay > 12) continue;
      if (yil < 2000 || yil > 2100) continue;

      final DateTime? aday = DateTime.tryParse(
        '$yil-${_ikiHane(ay)}-${_ikiHane(gun)}',
      );
      if (aday == null) continue;

      if (enGecTarih == null || aday.isAfter(enGecTarih)) {
        enGecTarih = aday;
      }
    }

    if (enGecTarih == null) return "";
    return DateFormat('dd.MM.yyyy').format(enGecTarih);
  }

  static String _ikiHane(int sayi) => sayi.toString().padLeft(2, '0');

  // ---------------------------------------------------------------
  // TUTAR BULMA
  // ---------------------------------------------------------------

  /// Türk çeklerinde tutar biçimleri: "#24.000,00#", "24.000.-#",
  /// "1.250 TL", "500,00 TL", "500 TL", "24. 000 TL" (araya boşluk kaçmış).
  /// Seri numaraları ("0382723" gibi) ayraç içermediği için elenir.
  static String _tutarBul(String metin) {
    // 1) Tarihe ait rakamlar tutar sanılmasın: tarihleri metinden sil
    final String temizMetin = metin.replaceAllMapped(_tarihRegex, (m) => ' ');

    // 2) Paraya benzeyen tüm sayı adaylarını tara
    final RegExp adayRegex = RegExp(r'\d[\d.,\s]*\d');

    double? enIyiDeger;
    bool enIyideIsaretVar = false;

    for (final Match m in adayRegex.allMatches(temizMetin)) {
      final String token = m.group(0)!.replaceAll(' ', '');

      if (token.isEmpty) continue;
      final bool ayracVar = token.contains('.') || token.contains(',');

      // 3) Bağlam kontrolü: yakınında "#" veya "TL" var mı?
      final String sonraki = temizMetin.substring(
        m.end,
        (m.end + 6).clamp(m.end, temizMetin.length),
      );
      final String onceki = temizMetin.substring(
        (m.start - 6).clamp(0, m.start),
        m.start,
      );
      final bool paraIsaretiVar =
          sonraki.contains('#') ||
          onceki.contains('#') ||
          sonraki.contains('TL') ||
          onceki.contains('TL');

      // 4) Eleme kuralları:
      //    - Ayraç yoksa ve yakında #/TL de yoksa -> seri numarası veya tarih artığı, atla
      //    - Ayraç yoksa, #/TL var ama 5+ hane -> seri numarası olabilir, atla
      if (!ayracVar && !paraIsaretiVar) continue;
      if (!ayracVar && token.length >= 5) continue;

      final double? deger = _sayiDegeri(token);
      if (deger == null || deger <= 0) continue;

      // 5) Seçim: önce para işareti bağlamı olan, sonra büyük olan kazanır
      final bool dahaIyi = enIyiDeger == null ||
          (paraIsaretiVar && !enIyideIsaretVar) ||
          (paraIsaretiVar == enIyideIsaretVar && deger > enIyiDeger);

      if (dahaIyi) {
        enIyiDeger = deger;
        enIyideIsaretVar = paraIsaretiVar;
      }
    }

    if (enIyiDeger == null) return "";

    // 6) Türk formatında yaz: "24.000,50" gibi
    final NumberFormat format = NumberFormat('#,##0.##', 'tr');
    return format.format(enIyiDeger);
  }

  /// "24.000,50" -> 24000.5 gibi, OCR'nin okuduğu token'ı sayıya çevirir.
  /// Kural: son ayraç ondalıktır; "24.000" / "24,000" gibi sadece binlik
  /// gruplardan oluşuyorsa ayraçlar silinir.
  static double? _sayiDegeri(String s) {
    final bool noktaVar = s.contains('.');
    final bool virgulVar = s.contains(',');

    String normalized;
    if (noktaVar && virgulVar) {
      // İkisi de varsa: en son görünen ayraç ondalık, diğeri binlik
      final String ondalikAyrac =
          s.lastIndexOf('.') > s.lastIndexOf(',') ? '.' : ',';
      final String binlikAyrac = ondalikAyrac == '.' ? ',' : '.';
      normalized = s.replaceAll(binlikAyrac, '').replaceAll(ondalikAyrac, '.');
    } else if (virgulVar) {
      // Sadece virgül: "500,00" ondalık, "24,000" / "24,000,000" binlik
      final bool binlikGrup =
          RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(s) && !s.endsWith(',00');
      normalized = binlikGrup
          ? s.replaceAll(',', '')
          : s.replaceFirst(',', '.');
    } else if (noktaVar) {
      // Sadece nokta: "24.000" binlik, "500.00" ondalık
      final bool binlikGrup = RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s);
      normalized = binlikGrup ? s.replaceAll('.', '') : s;
    } else {
      normalized = s; // "500" gibi düz sayı
    }

    return double.tryParse(normalized);
  }
}
