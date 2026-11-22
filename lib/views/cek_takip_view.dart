import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:finansal_takip_app/services/database_services.dart';
import 'package:finansal_takip_app/services/ocr_service.dart';
import 'package:finansal_takip_app/services/notification_service.dart';
import 'package:finansal_takip_app/utils/csv_olusturucu.dart';
import 'package:finansal_takip_app/utils/giris_formatlayici.dart';
import 'package:finansal_takip_app/widgets/cek_karti.dart';

class CekTakipView extends StatefulWidget {
  const CekTakipView({super.key});

  @override
  State<CekTakipView> createState() => _CekTakipViewState();
}

class _CekTakipViewState extends State<CekTakipView> {
  final Box<Map> _cekBox = Hive.box<Map>(DatabaseService.cekBoxName);
  final Box<Map> _firmaBox = Hive.box<Map>(DatabaseService.firmaBoxName);
  final ImagePicker _imagePicker = ImagePicker();
  bool _yukleniyorMu = false;

  // Arama ve Filtreleme Değişkenleri
  String _aramaKelimesi = "";
  String _seciliFiltre = "Tümü"; // Tümü, Tahsil, Ödenecek, Ödenenler

  // Ödeme yapılacak para birimi seçenekleri
  static const List<String> _paraBirimleri = ["TL", "USD", "EUR", "GBP", "CHF", "SAR", "JPY", "CNY"];

  // -----------------------------------------------------------------
  // GİRİŞ YÖNTEMLERİ: Kamera / Galeri / Manuel
  // -----------------------------------------------------------------

  /// Yeni çek ekleme menüsü (kamera, galeri, manuel giriş)
  void _yeniCekMenusuGoster() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Yeni Çek / Senet", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Kamera ile Çek"),
              subtitle: const Text("Çeki fotoğrafla, bilgiler otomatik okunsun"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galeriden Seç"),
              subtitle: const Text("Daha önce çekilmiş çek fotoğrafını kullan"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text("Manuel Giriş"),
              subtitle: const Text("Bilgileri elle doldur"),
              onTap: () => Navigator.pop(context, "manuel"),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((sonuc) {
      if (sonuc == "manuel") {
        _onayFormunuGoster("", "");
      } else if (sonuc is ImageSource) {
        _cekFotografiIsle(sonuc);
      }
    });
  }

  Future<void> _cekFotografiIsle(ImageSource kaynak) async {
    setState(() { _yukleniyorMu = true; });
    try {
      final XFile? foto = await _imagePicker.pickImage(
        source: kaynak,
        imageQuality: 100,
        maxWidth: 2200,
      );

      if (foto != null) {
        final Map<String, String> ocrSonuc = await OcrService.cekOku(foto.path);
        if (mounted) {
          _onayFormunuGoster(ocrSonuc["tarih"] ?? "", ocrSonuc["tutar"] ?? "");
        }
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fotoğraf işlenirken bir hata oluştu.")),
        );
      }
    } finally {
      if (mounted) { setState(() { _yukleniyorMu = false; }); }
    }
  }

  // -----------------------------------------------------------------
  // ONAY / KAYIT FORMU (OCR'lı ve manuel girişte ortak)
  // -----------------------------------------------------------------

  void _onayFormunuGoster(String gelenTarih, String gelenTutar) {
    final tarihController = TextEditingController(text: gelenTarih);
    final tutarController = TextEditingController(text: gelenTutar);
    final aciklamaController = TextEditingController();
    final cekNoController = TextEditingController();
    final bankaController = TextEditingController();

    String secilenTur = "odenecek"; // Varsayılan: ödenecek (borç)
    String secilenParaBirimi = "TL";
    String secilenFirmaId = ""; // Boş = cari seçilmedi

    final bool ocrEksik = gelenTarih.isEmpty || gelenTutar.isEmpty;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Çek / Senet Bilgileri"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ocrEksik
                      ? (gelenTarih.isEmpty && gelenTutar.isEmpty
                          ? "Bilgileri elle doldurun."
                          : "⚠️ Bazı alanlar okunamadı, eksikleri elle doldurun.")
                      : "Okunan bilgiler aşağıdadır, gerekirse düzeltin.",
                  style: TextStyle(
                    fontSize: 13,
                    color: ocrEksik && (gelenTarih.isEmpty != gelenTutar.isEmpty)
                        ? Colors.orange.shade700
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),

                // Çek türü seçimi: Tahsil edilecek (yeşil) / Ödenecek (kırmızı)
                const Text("Çek Türü", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: "tahsil",
                      icon: Icon(Icons.south_west, size: 18),
                      label: Text("Tahsil (Alacak)"),
                    ),
                    ButtonSegment(
                      value: "odenecek",
                      icon: Icon(Icons.north_east, size: 18),
                      label: Text("Ödenecek (Borç)"),
                    ),
                  ],
                  selected: {secilenTur},
                  onSelectionChanged: (secim) {
                    setDialogState(() { secilenTur = secim.first; });
                  },
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: tarihController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [TarihInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: "Son Ödeme Tarihi",
                    hintText: "GG.AA.YYYY (noktalar otomatik)",
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 12),

                // Tutar + para birimi yan yana
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: tutarController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: "Tutar",
                          prefixIcon: Icon(Icons.payments),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: secilenParaBirimi,
                        decoration: const InputDecoration(
                          labelText: "Para Birimi",
                          prefixIcon: Icon(Icons.currency_exchange),
                        ),
                        items: _paraBirimleri.map((birim) {
                          return DropdownMenuItem(value: birim, child: Text(birim));
                        }).toList(),
                        onChanged: (deger) {
                          setDialogState(() { secilenParaBirimi = deger ?? "TL"; });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Çek no + banka (opsiyonel detaylar)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: cekNoController,
                        decoration: const InputDecoration(
                          labelText: "Çek No (opsiyonel)",
                          prefixIcon: Icon(Icons.receipt_long),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: bankaController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: "Banka (opsiyonel)",
                          prefixIcon: Icon(Icons.account_balance),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Cari (firma) seçimi — opsiyonel, çek firma detayında toplanır
                ValueListenableBuilder(
                  valueListenable: _firmaBox.listenable(),
                  builder: (context, Box<Map> fbox, _) {
                    final firmalar = fbox.values.toList()
                      ..sort((a, b) => a["ad"].toString().compareTo(b["ad"].toString()));

                    return DropdownButtonFormField<String>(
                      initialValue: secilenFirmaId,
                      decoration: const InputDecoration(
                        labelText: "Cari / Firma (opsiyonel)",
                        prefixIcon: Icon(Icons.store),
                      ),
                      items: [
                        const DropdownMenuItem(value: "", child: Text("Seçilmedi")),
                        ...firmalar.map((firma) => DropdownMenuItem(
                              value: firma["id"].toString(),
                              child: Text(firma["ad"].toString()),
                            )),
                      ],
                      onChanged: (deger) {
                        setDialogState(() { secilenFirmaId = deger ?? ""; });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: aciklamaController,
                  decoration: const InputDecoration(
                    labelText: "Şirket / Açıklama",
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("İptal", style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () async {
                // --- VALIDASYON ---
                final String tarih = tarihController.text.trim();
                final String tutar = tutarController.text.trim();

                bool tarihGecerli = false;
                try {
                  DateTime? parsed = DateFormat("dd.MM.yyyy").parseStrict(tarih);
                  tarihGecerli = parsed.year >= 2000 && parsed.year <= 2100;
                } catch (_) {
                  tarihGecerli = false;
                }

                if (!tarihGecerli) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Tarih geçersiz! GG.AA.YYYY formatında girin (örn: 14.12.2026)."),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                final String temizTutar = tutar.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
                final double? tutarDeger = double.tryParse(temizTutar);
                if (tutar.isEmpty || tutarDeger == null || tutarDeger <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Tutar geçersiz! Örnek: 24.000,50"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                String id = DateTime.now().millisecondsSinceEpoch.toString();
                await _cekBox.put(id, {
                  "id": id,
                  "tur": secilenTur,
                  "tarih": tarih,
                  "tutar": tutar,
                  "paraBirimi": secilenParaBirimi,
                  "firmaId": secilenFirmaId,
                  "cekNo": cekNoController.text.trim(),
                  "banka": bankaController.text.trim(),
                  "aciklama": aciklamaController.text,
                  "isPaid": false,
                });

                // Bildirim başlığında açıklama yoksa cari adını kullan
                final String firmaAdi = DatabaseService.firmaAdiGetir(secilenFirmaId);
                final String bildirimBasligi = aciklamaController.text.isNotEmpty
                    ? aciklamaController.text
                    : (firmaAdi.isNotEmpty ? firmaAdi : "Çek/Senet");
                await NotificationService.cekBildirimleriniKur(
                  id, tarih,
                  "$bildirimBasligi (${secilenTur == "tahsil" ? "Tahsil" : "Ödenecek"})",
                  "$tutar $secilenParaBirimi",
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text("Kaydet"),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // CSV / EXCEL AKTARIMI
  // -----------------------------------------------------------------

  /// Görünen (filtrelenmiş) çek listesini CSV dosyası olarak paylaşır
  Future<void> _csvOlarakAktar() async {
    final cekler = _filtreliCekler(_cekBox.values.toList());
    if (cekler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aktarılacak çek yok.")),
      );
      return;
    }

    try {
      final tamponKlasor = await getTemporaryDirectory();
      final dosyaAdi =
          "cekler_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv";
      final dosya = File("${tamponKlasor.path}/$dosyaAdi");

      // UTF-8 BOM (﻿): Türkçe karakterler Excel'de bozuk görünmesin
      await dosya.writeAsString(
        "﻿${CsvOlusturucu.olustur(cekler)}",
        encoding: utf8,
      );

      await SharePlus.instance.share(
        ShareParams(files: [XFile(dosya.path)], title: dosyaAdi),
      );
    } catch (e) {
      debugPrint("CSV aktarım hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("CSV dosyası oluşturulamadı.")),
        );
      }
    }
  }

  // -----------------------------------------------------------------
  // LİSTE EKRANI
  // -----------------------------------------------------------------

  /// Arama ve filtre kriterlerine uyan çekleri döndürür
  /// (hem ekrandaki liste hem CSV aktarımı aynı kriteri kullanır)
  List<Map> _filtreliCekler(List<Map> tumCekler) {
    return tumCekler.where((cek) {
      final aciklama = (cek["aciklama"] ?? "").toString().toLowerCase();
      // Arama, açıklama VE cari (firma) adını kapsar
      final firmaAdi = DatabaseService.firmaAdiGetir(cek["firmaId"]).toLowerCase();
      bool aramaEslesti = aciklama.contains(_aramaKelimesi) || firmaAdi.contains(_aramaKelimesi);
      bool filtreEslesti = true;
      if (_seciliFiltre == "Tahsil") filtreEslesti = cek["tur"] == "tahsil" && cek["isPaid"] != true;
      if (_seciliFiltre == "Ödenecek") filtreEslesti = cek["tur"] != "tahsil" && cek["isPaid"] != true;
      if (_seciliFiltre == "Ödenenler") filtreEslesti = cek["isPaid"] == true;
      return aramaEslesti && filtreEslesti;
    }).toList();
  }

  /// En yakın vade en üstte görünsün diye sıralar
  void _vadeyeGoreSirala(List<Map> cekler) {
    cekler.sort((a, b) {
      DateTime ta, tb;
      try { ta = DateFormat("dd.MM.yyyy").parse((a["tarih"] ?? "")); } catch (_) { ta = DateTime(2100); }
      try { tb = DateFormat("dd.MM.yyyy").parse((b["tarih"] ?? "")); } catch (_) { tb = DateTime(2100); }
      return ta.compareTo(tb);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // ÜST FİLTRELEME VE ARAMA PANELİ
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (deger) {
                    setState(() { _aramaKelimesi = deger.toLowerCase(); });
                  },
                  decoration: InputDecoration(
                    labelText: "Şirket veya açıklama ara...",
                    prefixIcon: Icon(Icons.search, color: tema.colorScheme.primary),
                    // Görünen listeyi CSV/Excel'e aktarır
                    suffixIcon: IconButton(
                      icon: Icon(Icons.table_view, color: tema.colorScheme.primary),
                      tooltip: "Görünen listeyi CSV (Excel) olarak aktar",
                      onPressed: _csvOlarakAktar,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ["Tümü", "Tahsil", "Ödenecek", "Ödenenler"].map((filtre) {
                      bool seciliMi = _seciliFiltre == filtre;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(filtre, style: TextStyle(color: seciliMi ? Colors.white : Colors.black87)),
                          selected: seciliMi,
                          selectedColor: tema.colorScheme.primary,
                          onSelected: (secildi) {
                            setState(() { _seciliFiltre = filtre; });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // 📜 ÇEK LİSTESİ
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _cekBox.listenable(),
              builder: (context, Box<Map> box, _) {
                final filtrelenmisCekler = _filtreliCekler(box.values.toList());

                // En yakın vade en üstte görünsün
                _vadeyeGoreSirala(filtrelenmisCekler);

                if (filtrelenmisCekler.isEmpty) {
                  return const Center(child: Text("Kriterlere uygun çek bulunamadı.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: filtrelenmisCekler.length,
                  itemBuilder: (context, index) {
                    final cek = filtrelenmisCekler[index];
                    return CekKarti(
                      cek: cek,
                      firmaAdi: DatabaseService.firmaAdiGetir(cek["firmaId"]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _yukleniyorMu ? null : _yeniCekMenusuGoster,
        icon: _yukleniyorMu
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Icon(Icons.add)
        ,
        label: const Text("Yeni Çek"),
      ),
    );
  }
}
