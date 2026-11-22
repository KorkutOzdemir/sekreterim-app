import 'package:flutter_test/flutter_test.dart';
import 'package:finansal_takip_app/utils/giris_formatlayici.dart';

void main() {
  final formatter = TarihInputFormatter();

  TextEditingValue yaz(String metin) => formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: metin),
      );

  test('tam tarih otomatik noktalarla biçimlenir', () {
    expect(yaz("14112026").text, "14.11.2026");
  });

  test('eksik girişte fazladan nokta eklenmez', () {
    expect(yaz("1").text, "1");
    expect(yaz("14").text, "14");
    expect(yaz("141").text, "14.1");
    expect(yaz("1411").text, "14.11");
  });

  test('harf ve işaretler ayıklanır', () {
    expect(yaz("14a11b").text, "14.11");
    expect(yaz("14.11.20").text, "14.11.20");
  });

  test('8 haneden fazlası kırpılır (GGAAYYYY sınırı)', () {
    expect(yaz("141120269").text, "14.11.2026");
  });

  test('boş giriş boş kalır', () {
    expect(yaz("").text, "");
  });
}
