import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:finansal_takip_app/services/database_services.dart';
import 'package:finansal_takip_app/utils/para_utils.dart';
import 'package:finansal_takip_app/widgets/cek_karti.dart';
import 'package:finansal_takip_app/widgets/firma_formu.dart';

/// Seçilen carinin bilgilerini, para birimi bazlı toplamlarını
/// ve bu firmaya bağlı tüm çekleri gösteren ekran.
class FirmaDetayView extends StatefulWidget {
  final String firmaId;

  const FirmaDetayView({super.key, required this.firmaId});

  @override
  State<FirmaDetayView> createState() => _FirmaDetayViewState();
}

class _FirmaDetayViewState extends State<FirmaDetayView> {
  final Box<Map> _firmaBox = Hive.box<Map>(DatabaseService.firmaBoxName);
  final Box<Map> _cekBox = Hive.box<Map>(DatabaseService.cekBoxName);

  /// Belirtilen türdeki (tahsil/ödenecek) AÇIK çeklerin toplamını
  /// para birimi bazında döndürür: {"TL": 150000.0, "USD": 5000.0}
  Map<String, double> _toplamlar(List<Map> cekler, String tur) {
    final Map<String, double> toplam = {};
    for (final cek in cekler) {
      if (cek["tur"] != tur || cek["isPaid"] == true) continue;
      final double? deger = ParaUtils.sayiyaCevir(cek["tutar"]);
      if (deger == null) continue;
      final String birim = (cek["paraBirimi"] ?? "TL").toString();
      toplam[birim] = (toplam[birim] ?? 0) + deger;
    }
    return toplam;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Cari Detay")),
      body: ValueListenableBuilder(
        valueListenable: _firmaBox.listenable(),
        builder: (context, Box<Map> fbox, _) {
          // Firma silinmişse (başka ekrandan) boş durum göster
          final Map? firma = fbox.get(widget.firmaId);
          if (firma == null) {
            return const Center(
              child: Text("Bu cari kartı silinmiş.", style: TextStyle(color: Colors.grey)),
            );
          }

          return ValueListenableBuilder(
            valueListenable: _cekBox.listenable(),
            builder: (context, Box<Map> cbox, _) {
              final firmaCekleri = cbox.values
                  .where((cek) => cek["firmaId"] == widget.firmaId)
                  .toList()
                // En yakın vade en üstte görünsün
                ..sort((a, b) {
                  DateTime ta, tb;
                  try { ta = DateFormat("dd.MM.yyyy").parse((a["tarih"] ?? "")); } catch (_) { ta = DateTime(2100); }
                  try { tb = DateFormat("dd.MM.yyyy").parse((b["tarih"] ?? "")); } catch (_) { tb = DateTime(2100); }
                  return ta.compareTo(tb);
                });

              final tahsilToplam = _toplamlar(firmaCekleri, "tahsil");
              final odenecekToplam = _toplamlar(firmaCekleri, "odenecek");
              final int odulenSayisi = firmaCekleri.where((c) => c["isPaid"] == true).length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // ---------------- FİRMA BİLGİLERİ ----------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: tema.colorScheme.primary.withValues(alpha: 0.1),
                                child: Icon(Icons.business, color: tema.colorScheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  firma["ad"],
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: "Cari kartını düzenle",
                                onPressed: () =>
                                    FirmaFormu.goster(context, _firmaBox, mevcutFirma: firma),
                              ),
                            ],
                          ),
                          if ((firma["telefon"] ?? "").toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 16),
                                const SizedBox(width: 6),
                                Text(firma["telefon"], style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ],
                          if ((firma["aciklama"] ?? "").toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.notes, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    firma["aciklama"],
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ---------------- TOPLAM ÖZETİ ----------------
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ozetKarti(
                            baslik: "Tahsil Edilecek",
                            metin: ParaUtils.metneCevir(tahsilToplam),
                            renk: Colors.green,
                            ikon: Icons.south_west,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ozetKarti(
                            baslik: "Ödenecek",
                            metin: ParaUtils.metneCevir(odenecekToplam),
                            renk: Colors.red,
                            ikon: Icons.north_east,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (odulenSayisi > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                      child: Text(
                        "$odulenSayisi ödenmiş çek aşağıda listeleniyor.",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),

                  // ---------------- ÇEK LİSTESİ ----------------
                  if (firmaCekleri.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          "Bu firmaya ait çek kaydı yok.\nÇek eklerken cari olarak bu firmayı seçin.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ...firmaCekleri.map(
                      (cek) => CekKarti(cek: cek, firmaAdi: firma["ad"].toString()),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _ozetKarti({
    required String baslik,
    required String metin,
    required MaterialColor renk,
    required IconData ikon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 16, color: renk.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    baslik,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: renk.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              metin,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
