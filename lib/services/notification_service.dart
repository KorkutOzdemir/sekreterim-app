import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Uygulama ilk açıldığında bildirim altyapısını işletim sistemine kaydeder
  static Future<void> initNotification() async {
    // Türkiye saat dilimini (Europe/Istanbul) sisteme tanıtıyoruz
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android için uygulamanın kendi ikonunu bildirim ikonu olarak belirliyoruz
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  /// Bir çek kaydedildiğinde vade tarihine 3, 2 ve 1 gün kala için 3 adet alarm kurar
  static Future<void> cekBildirimleriniKur(
      String id, String tarihStr, String aciklama, String tutar) async {
    try {
      // Formdan gelen "16.11.2012" metnini DateTime objesine dönüştürüyoruz
      DateTime vadeTarihi = DateFormat("dd.MM.yyyy").parse(tarihStr);
      
      // Bildirimlerin vade günlerinde sabah saat 09:00'da gelmesini hedefliyoruz
      DateTime vadeGunuSaatDokuz =
          DateTime(vadeTarihi.year, vadeTarihi.month, vadeTarihi.day, 9, 0);

      // Eşsiz alt ID'ler üretebilmek için çekin ID'sinin son 5 hanesini sayıya çeviriyoruz
      int temelId = int.parse(id.substring(id.length - 5));

      // 3, 2 ve 1 gün öncesi için döngüyle alarmları işletim sistemine diziyoruz
      for (int i = 3; i >= 1; i--) {
        DateTime bildirimZamani = vadeGunuSaatDokuz.subtract(Duration(days: i));

        // Eğer kurulan bildirim zamanı şu anki zamandan ilerideyse (geçmişe bildirim kurulamaz)
        if (bildirimZamani.isAfter(DateTime.now())) {
          await _notificationsPlugin.zonedSchedule(
            temelId + i, // Her gün için benzersiz ID üretir (Örn: 48291, 48292, 48293)
            "Çek Ödeme Hatırlatması! 🚨",
            "$aciklama firmasına ait $tutar TL tutarındaki çekin vadesine $i gün kaldı.",
            tz.TZDateTime.from(bildirimZamani, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'cek_hatirlatici_kanali', // Arka plan kanal ID'si
                'Çek Hatırlatıcı Bildirimleri', // Arkadaşının ayarlarda göreceği kanal adı
                channelDescription: 'Çek vadesine kalan günleri bildiren kanal',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }
    } catch (e) {
      debugPrint("Bildirim zamanlaması kurulurken hata oluştu: $e");
    }
  }

  /// Çek ödendiğinde veya silindiğinde o çeke ait kurulmuş olan 3 alarmı da iptal eder
  static Future<void> cekBildirimleriniIptalEt(String id) async {
    try {
      int temelId = int.parse(id.substring(id.length - 5));
      
      // Sistem kuyruğundaki 3 günü de tek tek iptal ediyoruz
      await _notificationsPlugin.cancel(temelId + 3);
      await _notificationsPlugin.cancel(temelId + 2);
      await _notificationsPlugin.cancel(temelId + 1);
    } catch (e) {
      debugPrint("Bildirim iptal edilirken hata oluştu: $e");
    }
  }
}