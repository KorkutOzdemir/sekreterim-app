import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finansal_takip_app/services/database_services.dart';
import 'package:finansal_takip_app/views/firma_detay_view.dart';
import 'package:finansal_takip_app/widgets/firma_formu.dart';

/// Cari (firma) kartlarının listelendiği ekran.
/// Bir firmaya dokununca o firmanın çekleri ve toplamları açılır.
class FirmaView extends StatefulWidget {
  const FirmaView({super.key});

  @override
  State<FirmaView> createState() => _FirmaViewState();
}

class _FirmaViewState extends State<FirmaView> {
  final Box<Map> _firmaBox = Hive.box<Map>(DatabaseService.firmaBoxName);
  final Box<Map> _cekBox = Hive.box<Map>(DatabaseService.cekBoxName);

  String _aramaKelimesi = "";

  /// Bir firmaya bağlı açık (ödenmemiş) çek sayılarını döndürür
  (int tahsil, int odenecek) _acikCekSayilari(String firmaId) {
    int tahsil = 0;
    int odenecek = 0;
    for (final cek in _cekBox.values) {
      if (cek["firmaId"] != firmaId || cek["isPaid"] == true) continue;
      if (cek["tur"] == "tahsil") {
        tahsil++;
      } else {
        odenecek++;
      }
    }
    return (tahsil, odenecek);
  }

  /// Bir firmaya bağlı toplam çek sayısı (ödenmiş dahil)
  int _toplamCekSayisi(String firmaId) {
    return _cekBox.values.where((cek) => cek["firmaId"] == firmaId).length;
  }

  // -----------------------------------------------------------------
  // SİLME (bağlı çekler varsa uyar)
  // -----------------------------------------------------------------

  Future<void> _firmaSil(Map firma) async {
    final String firmaId = firma["id"];
    final int cekSayisi = _toplamCekSayisi(firmaId);

    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Cari Kartını Sil"),
        content: Text(
          cekSayisi > 0
              ? "\"${firma["ad"]}\" firmasına bağlı $cekSayisi çek kaydı var.\n\n"
                  "Firma silinince çekler SİLİNMEZ, yalnızca cari bağları kaldırılır."
              : "\"${firma["ad"]}\" cari kartı silinsin mi?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Sil", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (onay == true) {
      await DatabaseService.firmaSilVeCekleriAyir(firmaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("\"${firma["ad"]}\" silindi.")),
        );
      }
    }
  }

  // -----------------------------------------------------------------
  // LİSTE EKRANI
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (deger) {
                setState(() { _aramaKelimesi = deger.toLowerCase(); });
              },
              decoration: InputDecoration(
                labelText: "Cari ara...",
                prefixIcon: Icon(Icons.search, color: tema.colorScheme.primary),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          Expanded(
            // Çek kutusu da dinlenir: çek eklendiğinde/silindiğinde sayaçlar güncel kalsın
            child: ValueListenableBuilder(
              valueListenable: _firmaBox.listenable(),
              builder: (context, Box<Map> fbox, _) => ValueListenableBuilder(
                valueListenable: _cekBox.listenable(),
                builder: (context, Box<Map> cbox, _) {
                  final firmalar = fbox.values.toList()
                    ..sort((a, b) => a["ad"].toString().compareTo(b["ad"].toString()));

                  final filtrelenmis = firmalar.where((firma) {
                    final ad = (firma["ad"] ?? "").toString().toLowerCase();
                    return ad.contains(_aramaKelimesi);
                  }).toList();

                  if (filtrelenmis.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store, size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            firmalar.isEmpty
                                ? "Henüz cari kartı eklenmedi.\nSağ alttaki butonla ekleyin."
                                : "Aramaya uygun cari bulunamadı.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: filtrelenmis.length,
                    itemBuilder: (context, index) {
                      final firma = filtrelenmis[index];
                      final (tahsilSayisi, odenecekSayisi) = _acikCekSayilari(firma["id"]);
                      final String telefon = (firma["telefon"] ?? "").toString();

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tema.colorScheme.primary.withValues(alpha: 0.1),
                            child: Icon(Icons.business, color: tema.colorScheme.primary),
                          ),
                          title: Text(
                            firma["ad"],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (tahsilSayisi > 0)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "$tahsilSayisi tahsil",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    if (odenecekSayisi > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "$odenecekSayisi ödenecek",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    if (tahsilSayisi == 0 && odenecekSayisi == 0)
                                      const Text(
                                        "Açık çek kaydı yok",
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                  ],
                                ),
                                if (telefon.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(telefon, style: const TextStyle(fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    FirmaFormu.goster(context, _firmaBox, mevcutFirma: firma),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _firmaSil(firma),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FirmaDetayView(firmaId: firma["id"]),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => FirmaFormu.goster(context, _firmaBox),
        icon: const Icon(Icons.add),
        label: const Text("Yeni Cari"),
      ),
    );
  }
}
