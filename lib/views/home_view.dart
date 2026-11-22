import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:finansal_takip_app/services/yedekleme_service.dart';
import 'package:finansal_takip_app/views/todo_view.dart';
import 'package:finansal_takip_app/views/login_view.dart';
import 'package:finansal_takip_app/views/cek_takip_view.dart';
import 'package:finansal_takip_app/views/doviz_kurlari_view.dart';
import 'package:finansal_takip_app/views/genel_durum_view.dart';
import 'package:finansal_takip_app/views/takvim_view.dart';
import 'package:finansal_takip_app/views/firma_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // O an hangi sekmede olduğumuzu tutan değişken
  // (0 = Genel Durum, 1 = To-Do, 2 = Çek-Senet, 3 = Takvim, 4 = Döviz, 5 = Firmalar)
  int _secilenIndeks = 0;

  // Menüden tıklandıkça ekrana gelecek olan gerçek sayfaların listesi
  final List<Widget> _sayfalar = [
    const GenelDurumView(),
    const TodoView(),
    const CekTakipView(),
    const TakvimView(),
    const DovizKurlariView(),
    const FirmaView(),
  ];

  // Sekme başlıkları (AppBar'da gösterilir)
  static const List<String> _basliklar = [
    "Genel Durum",
    "Muhasebe Günlük Görevler",
    "Çek - Senet Takip",
    "Takvim",
    "Canlı Döviz & Altın Takip",
    "Cari / Firmalar",
  ];

  // Drawer menü öğeleri: (ikon, başlık)
  static const List<(IconData, String)> _menuOgeleri = [
    (Icons.dashboard, "Genel Durum"),
    (Icons.check_box, "Günlük Görevler (To-Do)"),
    (Icons.description, "Çek - Senet Takip"),
    (Icons.calendar_month, "Takvim"),
    (Icons.monetization_on, "Canlı Döviz & Altın"),
    (Icons.business, "Cari / Firmalar"),
  ];

  // -----------------------------------------------------------------
  // YEDEKLEME
  // -----------------------------------------------------------------

  /// Tüm verileri (çekler, cariler, görevler) JSON dosyası olarak paylaşır.
  /// Dosya Drive/WhatsApp/e-posta ile saklanabilir.
  Future<void> _yedekAl() async {
    Navigator.pop(context); // Drawer'ı kapat
    try {
      final icerik = await YedeklemeService.yedekOlustur();
      final tamponKlasor = await getTemporaryDirectory();
      final dosyaAdi =
          "sekreterim_yedek_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json";
      final dosya = File("${tamponKlasor.path}/$dosyaAdi");
      await dosya.writeAsString(icerik, encoding: utf8);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(dosya.path)], title: dosyaAdi),
      );
    } catch (e) {
      debugPrint("Yedek alma hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Yedek dosyası oluşturulamadı.")),
        );
      }
    }
  }

  /// Daha önce alınmış JSON yedeğini seçip geri yükler.
  /// Onay diyalogunda mevcut verilerin silineceği açıkça belirtilir.
  Future<void> _yedektenGeriYukle() async {
    Navigator.pop(context); // Drawer'ı kapat
    try {
      final dosya = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ["json"],
      );
      if (dosya == null || dosya.path == null) return;

      final icerik =
          await File(dosya.path!).readAsString(encoding: utf8);

      // Özeti oku (dosya geçersizse FormatException fırlar)
      final ozet = YedeklemeService.yedekOzeti(icerik);

      if (!mounted) return;

      // Kullanıcıya net onay sor: üzerine yazma belirleyici
      final bool? onay = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Yedekten Geri Yükle"),
          content: Text(
            "${ozet.tarih} tarihli yedek:\n"
            "${ozet.cek} çek, ${ozet.firma} cari, ${ozet.gorev} görev\n\n"
                "Mevcut TÜM veriler silinip yedektekiler yüklenecek. "
                "Devam edilsin mi?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Vazgeç"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Geri Yükle",
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (onay != true) return;

      await YedeklemeService.geriYukle(icerik);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Yedek geri yüklendi: ${ozet.cek} çek, ${ozet.firma} cari, ${ozet.gorev} görev.",
            ),
          ),
        );
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Yedek yüklenemedi: ${e.message}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Geri yükleme hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Geri yükleme sırasında hata oluştu.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Temadan renkleri güvenli bir şekilde almak için değişkenleri tanımlıyoruz
    final ThemeData tema = Theme.of(context);
    final Color anaLacivert = tema.colorScheme.primary;
    final Color canliMavi = tema.colorScheme.secondary;

    return Scaffold(
      // Tıklanan sekmeye göre başlığın dinamik değişmesini sağlıyoruz
      appBar: AppBar(
        title: Text(_basliklar[_secilenIndeks]),
        // Arka plan rengini main.dart'ta tanımladığımız ana lacivertten alır
        backgroundColor: anaLacivert,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // ÜST KISIM: Lacivert gradyanlı marka alanı
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A237E), Color(0xFF283593)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Sekreterim",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Muhasebe yönetim sistemi",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // MENÜ ÖĞELERİ
            ..._menuOgeleri.asMap().entries.map(
                  (girdi) => ListTile(
                    leading: Icon(girdi.value.$1, color: canliMavi),
                    title: Text(girdi.value.$2),
                    selected: _secilenIndeks == girdi.key,
                    selectedTileColor: anaLacivert.withValues(alpha: 0.08),
                    selectedColor: anaLacivert,
                    onTap: () {
                      setState(() {
                        _secilenIndeks = girdi.key;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),

            const Divider(),

            // YEDEKLEME BÖLÜMÜ
            ListTile(
              leading: Icon(Icons.save, color: canliMavi),
              title: const Text("Yedek Al"),
              subtitle: const Text("Tüm verileri JSON dosyası olarak paylaş"),
              onTap: _yedekAl,
            ),
            ListTile(
              leading: Icon(Icons.restore, color: canliMavi),
              title: const Text("Yedekten Geri Yükle"),
              subtitle: const Text("JSON yedek dosyasından geri yükle"),
              onTap: _yedektenGeriYukle,
            ),

            const Divider(),
            const Spacer(),

            // ALT KISIM: Çıkış Butonu
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                "Hesaptan Çıkış Yap",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginView()),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: _sayfalar[_secilenIndeks],
    );
  }
}
