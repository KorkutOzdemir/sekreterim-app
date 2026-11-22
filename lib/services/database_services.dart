import 'package:hive_flutter/hive_flutter.dart';

class DatabaseService {
  static const String todoBoxName = "todos_box";
  static const String documentBoxName = "documents_box";
  // 1. Çekler için yeni çekmece ismi ekliyoruz
  static const String cekBoxName = "cekler_box";
  // Cari (firma) kartları için çekmece
  static const String firmaBoxName = "firmalar_box";

  static Future<void> initDatabase() async {
    await Hive.initFlutter();

    await Hive.openBox<Map>(todoBoxName);

    await Hive.openBox<Map>(documentBoxName);
    // 2. Uygulama açılırken çek kutusunu da hafızada hazırla
    await Hive.openBox<Map>(cekBoxName);
    await Hive.openBox<Map>(firmaBoxName);
  }

  /// Firmayı ID'sinden bulup adını döndürür; bulamazsa boş string döner.
  static String firmaAdiGetir(String? firmaId) {
    if (firmaId == null || firmaId.isEmpty) return "";
    final Map? firma = Hive.box<Map>(firmaBoxName).get(firmaId);
    return (firma?["ad"] ?? "").toString();
  }

  /// Firmayı siler. Firmaya bağlı çekler SİLİNMEZ, yalnızca cari bağları
  /// kaldırılır (firmaId alanı boşaltılır).
  static Future<void> firmaSilVeCekleriAyir(String firmaId) async {
    final Box<Map> cekBox = Hive.box<Map>(cekBoxName);

    // Önce bağlantılı çeklerin firmaId alanını temizle
    for (final anahtar in cekBox.keys.toList()) {
      final Map? cek = cekBox.get(anahtar);
      if (cek != null && cek["firmaId"] == firmaId) {
        await cekBox.put(anahtar, {...cek, "firmaId": ""});
      }
    }

    await Hive.box<Map>(firmaBoxName).delete(firmaId);
  }
}