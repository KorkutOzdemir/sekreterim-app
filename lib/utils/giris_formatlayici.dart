import 'package:flutter/services.dart';

/// Kullanıcı sadece rakam yazsın, noktaları sistem kendisi koysun.
/// "14112026" yazınca alan "14.11.2026" olur (GG.AA.YYYY).
class TarihInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Sadece rakamları al, en fazla 8 hane (GGAAYYYY)
    final rakamlar = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final kirpilmis = rakamlar.length > 8 ? rakamlar.substring(0, 8) : rakamlar;

    final buffer = StringBuffer();
    for (int i = 0; i < kirpilmis.length; i++) {
      buffer.write(kirpilmis[i]);
      // Gün ve ay kısımlarından sonra otomatik nokta ekle
      if (i == 1 || i == 3) {
        if (kirpilmis.length > i + 1) buffer.write('.');
      }
    }

    final String formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
