import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Cari (firma) ekleme/düzenleme formu.
/// Hem FirmaView (liste) hem FirmaDetayView tarafından kullanılır.
class FirmaFormu extends StatefulWidget {
  final Box<Map> firmaBox;

  /// Doluysa düzenleme, boşsa yeni kayıt modunda açılır.
  final Map? mevcutFirma;

  const FirmaFormu({super.key, required this.firmaBox, this.mevcutFirma});

  /// Formu diyalog olarak açar.
  static void goster(BuildContext context, Box<Map> firmaBox, {Map? mevcutFirma}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => FirmaFormu(firmaBox: firmaBox, mevcutFirma: mevcutFirma),
    );
  }

  @override
  State<FirmaFormu> createState() => _FirmaFormuState();
}

class _FirmaFormuState extends State<FirmaFormu> {
  late final TextEditingController _adController;
  late final TextEditingController _telefonController;
  late final TextEditingController _aciklamaController;

  @override
  void initState() {
    super.initState();
    _adController = TextEditingController(text: widget.mevcutFirma?["ad"] ?? "");
    _telefonController = TextEditingController(text: widget.mevcutFirma?["telefon"] ?? "");
    _aciklamaController = TextEditingController(text: widget.mevcutFirma?["aciklama"] ?? "");
  }

  @override
  void dispose() {
    _adController.dispose();
    _telefonController.dispose();
    _aciklamaController.dispose();
    super.dispose();
  }

  Future<void> _kaydet(BuildContext dialogContext) async {
    final String ad = _adController.text.trim();
    if (ad.isEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(
          content: Text("Firma adı zorunludur."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (widget.mevcutFirma != null) {
      await widget.firmaBox.put(widget.mevcutFirma!["id"], {
        ...widget.mevcutFirma!,
        "ad": ad,
        "telefon": _telefonController.text.trim(),
        "aciklama": _aciklamaController.text.trim(),
      });
    } else {
      String id = DateTime.now().millisecondsSinceEpoch.toString();
      await widget.firmaBox.put(id, {
        "id": id,
        "ad": ad,
        "telefon": _telefonController.text.trim(),
        "aciklama": _aciklamaController.text.trim(),
      });
    }
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  @override
  Widget build(BuildContext context) {
    final bool duzenleme = widget.mevcutFirma != null;

    return AlertDialog(
      title: Text(duzenleme ? "Cari Kartını Düzenle" : "Yeni Cari Kartı"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _adController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Firma / Kişi Adı *",
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Telefon (opsiyonel)",
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aciklamaController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Not (opsiyonel)",
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("İptal", style: TextStyle(color: Colors.redAccent)),
        ),
        ElevatedButton(
          onPressed: () => _kaydet(context),
          child: const Text("Kaydet"),
        ),
      ],
    );
  }
}
