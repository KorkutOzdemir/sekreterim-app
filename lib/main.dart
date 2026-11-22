import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

// Kendi yazdığımız servis ve ekran dosyalarını (import) içeri aktarıyoruz
import 'package:finansal_takip_app/services/database_services.dart';
import 'package:finansal_takip_app/views/login_view.dart';
import 'services/notification_service.dart';

// Uygulamanın renk paleti: her yerden tek noktadan yönetilir
class UygulamaRenkleri {
  static const Color lacivert = Color(0xFF1A237E); // Ana marka rengi
  static const Color safir = Color(0xFF0288D1); // Yan renk (vurgular)
  static const Color acikArkaPlan = Color(0xFFF5F7FA); // Sayfa zemini
  static const Color kartYuzeyi = Colors.white;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.initDatabase();

  // Türkçe tarih/takvim sembollerini hazırlıyoruz (takvim ekranı için)
  await initializeDateFormatting('tr_TR');

  // BİLDİRİM SERVİSİNİ BURADA BAŞLATIYORUZ:
  await NotificationService.initNotification();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sekreterim',
      debugShowCheckedModeBanner: false,
      theme: _temaOlustur(),
      // Türkçe arayüz: tarih seçiciler ve takvim Türkçe olur
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LoginView(),
    );
  }

  /// Uygulamanın tüm profesyonel teması tek yerden tanımlanır.
  static ThemeData _temaOlustur() {
    const Color lacivert = UygulamaRenkleri.lacivert;
    const Color safir = UygulamaRenkleri.safir;

    final ColorScheme renkSemasi = ColorScheme.fromSeed(
      seedColor: lacivert,
      primary: lacivert,
      secondary: safir,
      surface: UygulamaRenkleri.kartYuzeyi,
      error: const Color(0xFFD32F2F),
    );

    // Metin stilleri: başlıklar ve gövde yazıları için tutarlı hiyerarşi
    final TextTheme metinTemasi = Typography.blackCupertino.copyWith(
      titleLarge: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600),
      labelLarge: const TextStyle(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: renkSemasi,
      scaffoldBackgroundColor: UygulamaRenkleri.acikArkaPlan,
      textTheme: metinTemasi,

      // ---- ÜST BAR ----
      appBarTheme: const AppBarTheme(
        backgroundColor: lacivert,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ---- KARTLAR ----
      cardTheme: CardThemeData(
        color: UygulamaRenkleri.kartYuzeyi,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // ---- METİN ALANLARI ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: UygulamaRenkleri.kartYuzeyi,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: safir, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
      ),

      // ---- BUTONLAR ----
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lacivert,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: safir),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: lacivert,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ---- ÇİPLER ----
      chipTheme: ChipThemeData(
        selectedColor: lacivert,
        labelStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: Colors.grey.shade300),
      ),

      // ---- DİYALOGLAR ----
      dialogTheme: DialogThemeData(
        backgroundColor: UygulamaRenkleri.kartYuzeyi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF212121),
        ),
      ),

      // ---- SNACKBAR ----
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // ---- LİSTE ÖĞELERİ ----
      listTileTheme: const ListTileThemeData(
        iconColor: safir,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
    );
  }
}
