import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:finansal_takip_app/services/database_services.dart';

/// Takvimde bir güne düşen olay (görev veya çek/senet)
class TakvimOlayi {
  final String baslik;
  final DateTime tarih;
  final Color renk; // Tahsil çek: yeşil, Ödenecek çek: kırmızı, Görev: mavi
  final IconData ikon;
  final String etiket;

  TakvimOlayi({
    required this.baslik,
    required this.tarih,
    required this.renk,
    required this.ikon,
    required this.etiket,
  });
}

class TakvimView extends StatefulWidget {
  const TakvimView({super.key});

  @override
  State<TakvimView> createState() => _TakvimViewState();
}

class _TakvimViewState extends State<TakvimView> {
  final Box<Map> _todoBox = Hive.box<Map>(DatabaseService.todoBoxName);
  final Box<Map> _cekBox = Hive.box<Map>(DatabaseService.cekBoxName);
  final Box<Map> _firmaBox = Hive.box<Map>(DatabaseService.firmaBoxName);

  DateTime _seciliGun = DateTime.now();
  DateTime _odakliGun = DateTime.now();

  /// İki kutudan (görevler + çekler) takvim olaylarını toplar
  List<TakvimOlayi> _olaylariTopla() {
    final List<TakvimOlayi> olaylar = [];

    // Görevler (vade tarihi girilmişse)
    for (final gorev in _todoBox.values) {
      final String tarihStr = (gorev["vadeTarihi"] ?? "").toString();
      if (tarihStr.isEmpty) continue;
      try {
        final tarih = DateFormat("dd.MM.yyyy").parse(tarihStr);
        olaylar.add(TakvimOlayi(
          baslik: gorev["title"] ?? "Görev",
          tarih: tarih,
          renk: const Color(0xFF0288D1), // Görev: safir mavi
          ikon: Icons.check_box,
          etiket: (gorev["isCompleted"] ?? false) ? "Görev (Tamamlandı)" : "Görev",
        ));
      } catch (_) {}
    }

    // Çek / Senetler
    for (final cek in _cekBox.values) {
      final String tarihStr = (cek["tarih"] ?? "").toString();
      if (tarihStr.isEmpty) continue;
      try {
        final tarih = DateFormat("dd.MM.yyyy").parse(tarihStr);
        final bool tahsil = cek["tur"] == "tahsil";
        final bool isPaid = cek["isPaid"] ?? false;
        // Başlık önceliği: açıklama > cari adı > "İsimsiz Şirket"
        final String aciklama = (cek["aciklama"] ?? "").toString();
        final String firmaAdi = DatabaseService.firmaAdiGetir(cek["firmaId"]);
        final String baslik = aciklama.isNotEmpty
            ? aciklama
            : (firmaAdi.isNotEmpty ? firmaAdi : "İsimsiz Şirket");
        olaylar.add(TakvimOlayi(
          baslik:
              "$baslik — "
              "${cek["tutar"]} ${cek["paraBirimi"] ?? "TL"}",
          tarih: tarih,
          renk: tahsil ? Colors.green : Colors.red, // Tahsil: yeşil, Ödenecek: kırmızı
          ikon: isPaid
              ? Icons.check_circle
              : (tahsil ? Icons.south_west : Icons.north_east),
          etiket: isPaid
              ? "Çek (Ödendi)"
              : (tahsil ? "Çek — Tahsil Edilecek" : "Çek — Ödenecek"),
        ));
      } catch (_) {}
    }

    return olaylar;
  }

  List<TakvimOlayi> _gununOlaylari(DateTime gun, List<TakvimOlayi> tumOlaylar) {
    return tumOlaylar
        .where((o) => o.tarih.year == gun.year && o.tarih.month == gun.month && o.tarih.day == gun.day)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: _cekBox.listenable(),
        builder: (context, _, _) => ValueListenableBuilder(
          valueListenable: _firmaBox.listenable(),
          builder: (context, _, _) => ValueListenableBuilder(
          valueListenable: _todoBox.listenable(),
          builder: (context, _, _) {
            final tumOlaylar = _olaylariTopla();
            final seciliGunOlaylari = _gununOlaylari(_seciliGun, tumOlaylar);

            return Column(
              children: [
                // ---------------- TAKVİM ----------------
                TableCalendar<TakvimOlayi>(
                  locale: 'tr_TR',
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _odakliGun,
                  selectedDayPredicate: (gun) => isSameDay(_seciliGun, gun),
                  onDaySelected: (secilen, odak) {
                    setState(() {
                      _seciliGun = secilen;
                      _odakliGun = odak;
                    });
                  },
                  eventLoader: (gun) => _gununOlaylari(gun, tumOlaylar),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  daysOfWeekHeight: 32,
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF1A237E)),
                    rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF1A237E)),
                  ),
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Color(0xFF283593),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Color(0xFF1A237E),
                      shape: BoxShape.circle,
                    ),
                    markerMargin: EdgeInsets.symmetric(horizontal: 1),
                    markersMaxCount: 3,
                    markerSize: 7,
                  ),

                  // Gün altına olaylara göre RENKLİ noktalar koyar
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, gun, olaylar) {
                      if (olaylar.isEmpty) return null;
                      return Positioned(
                        bottom: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: olaylar.take(3).map((o) => _nokta(o.renk)).toList(),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 1),

                // ---------------- SEÇİLİ GÜN OLAYLARI ----------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(_seciliGun),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: seciliGunOlaylari.isEmpty
                              ? Colors.grey.withValues(alpha: 0.15)
                              : const Color(0xFF1A237E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${seciliGunOlaylari.length} kayıt",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A237E)),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: seciliGunOlaylari.isEmpty
                      ? const Center(
                          child: Text("Bu güne ait iş, çek veya senet yok.", style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: seciliGunOlaylari.length,
                          itemBuilder: (context, index) {
                            final olay = seciliGunOlaylari[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: olay.renk.withValues(alpha: 0.12),
                                  child: Icon(olay.ikon, color: olay.renk, size: 22),
                                ),
                                title: Text(
                                  olay.baslik,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  olay.etiket,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: olay.renk,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
          ),
        ),
      ),
    );
  }

  Widget _nokta(Color renk) {
    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
    );
  }
}
