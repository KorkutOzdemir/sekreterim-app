import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:finansal_takip_app/services/database_services.dart';
import 'package:finansal_takip_app/services/notification_service.dart';

/// Tek bir çek/senet kaydını gösteren kart.
/// Hem ana çek listesinde hem firma (cari) detay ekranında kullanılır.
class CekKarti extends StatelessWidget {
  final Map cek;

  /// Bu çeke bağlı cari (firma) adı. Boşsa "Cari:" satırı gösterilmez.
  final String firmaAdi;

  const CekKarti({super.key, required this.cek, this.firmaAdi = ""});

  /// Çek türü: "tahsil" (alacağım, yeşil) veya "odenecek" (borcum, kırmızı)
  bool get _tahsilMi => cek["tur"] == "tahsil";

  /// Vade tarihine kalan gün sayısını hesaplayan akıllı fonksiyon
  String _vadeDurumuHesapla(String tarihStr) {
    try {
      DateTime vadeTarihi = DateFormat("dd.MM.yyyy").parse(tarihStr);
      DateTime bugun = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      vadeTarihi = DateTime(vadeTarihi.year, vadeTarihi.month, vadeTarihi.day);

      int fark = vadeTarihi.difference(bugun).inDays;

      if (fark == 0) {
        return "⚠️ BUGÜN ÖDENECEK!";
      } else if (fark > 0) {
        return "⏳ Vadeye $fark gün kaldı";
      } else {
        return "🚨 Vadesi ${fark.abs()} gün geçti!";
      }
    } catch (e) {
      return "Tarih formatı belirsiz";
    }
  }

  /// Kalan günün durumuna göre karta renk veren fonksiyon
  Color _vadeRengiGetir(String tarihStr, bool isPaid) {
    if (isPaid) return Colors.green;
    try {
      DateTime vadeTarihi = DateFormat("dd.MM.yyyy").parse(tarihStr);
      DateTime bugun = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      int fark = vadeTarihi.difference(bugun).inDays;

      if (fark < 0) return Colors.red.shade700;
      if (fark == 0 || fark <= 3) return Colors.orange.shade700;
      return Colors.blueGrey;
    } catch (e) {
      return Colors.grey;
    }
  }

  /// Ödeme durumunu tersine çevirir (ödedi ↔ beklemede) ve bildirimleri günceller
  Future<void> _odemeDurumuDegistir() async {
    final Box<Map> cekBox = Hive.box<Map>(DatabaseService.cekBoxName);
    final String cekId = (cek["id"] ?? "").toString();
    final bool yeniDurum = !(cek["isPaid"] ?? false);

    await cekBox.put(cekId, {...cek, "isPaid": yeniDurum});
    if (yeniDurum) {
      await NotificationService.cekBildirimleriniIptalEt(cekId);
    } else {
      await NotificationService.cekBildirimleriniKur(
        cekId, cek["tarih"], cek["aciklama"] ?? "Çek", cek["tutar"],
      );
    }
  }

  /// Çeki ve varsa zamanlanmış bildirimlerini siler
  Future<void> _sil() async {
    final String cekId = (cek["id"] ?? "").toString();
    await Hive.box<Map>(DatabaseService.cekBoxName).delete(cekId);
    await NotificationService.cekBildirimleriniIptalEt(cekId);
  }

  @override
  Widget build(BuildContext context) {
    final bool isPaid = cek["isPaid"] ?? false;
    final bool tahsil = _tahsilMi;
    final String paraBirimi = cek["paraBirimi"] ?? "TL";
    final String aciklama = (cek["aciklama"] ?? "").toString();
    final String cekNo = (cek["cekNo"] ?? "").toString();
    final String banka = (cek["banka"] ?? "").toString();

    // Başlık önceliği: açıklama > firma adı > "İsimsiz Şirket"
    final String baslik = aciklama.isNotEmpty
        ? aciklama
        : (firmaAdi.isNotEmpty ? firmaAdi : "İsimsiz Şirket");

    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              // Tahsil = yeşil şerit, Ödenecek = kırmızı şerit
              color: isPaid ? Colors.green : (tahsil ? Colors.green : Colors.red),
              width: 4,
            ),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Icon(
            isPaid ? Icons.check_circle : (tahsil ? Icons.south_west : Icons.north_east),
            color: isPaid ? Colors.green : (tahsil ? Colors.green.shade700 : Colors.red.shade700),
            size: 32,
          ),
          title: Text(
            baslik,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              decoration: isPaid ? TextDecoration.lineThrough : null,
              color: isPaid ? Colors.grey : Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "${cek["tutar"]} $paraBirimi",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: tahsil ? Colors.green.withValues(alpha: 0.12) : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tahsil ? "Tahsil Edilecek" : "Ödenecek",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: tahsil ? Colors.green.shade800 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                // Çek no / banka detayı (girildiyse)
                if (cekNo.isNotEmpty || banka.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.receipt_long, size: 13, color: Colors.blueGrey.shade400),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          [
                            if (cekNo.isNotEmpty) "No: $cekNo",
                            if (banka.isNotEmpty) banka,
                          ].join(" • "),
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                // Açıklama doluysa cari adını ayrıca göster
                if (firmaAdi.isNotEmpty && aciklama.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.store, size: 13, color: Colors.blueGrey.shade400),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          firmaAdi,
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
                Text("Vade: ${cek["tarih"]}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  isPaid ? "✓ Ödeme Tamamlandı" : _vadeDurumuHesapla(cek["tarih"]),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _vadeRengiGetir(cek["tarih"], isPaid),
                  ),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(isPaid ? Icons.refresh : Icons.check, color: Colors.green.shade700),
                onPressed: _odemeDurumuDegistir,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _sil,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
