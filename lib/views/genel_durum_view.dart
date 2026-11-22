import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:finansal_takip_app/services/database_services.dart';
import 'package:finansal_takip_app/services/doviz_service.dart';
import 'package:finansal_takip_app/utils/para_utils.dart';
import 'package:finansal_takip_app/widgets/cek_karti.dart';

/// Uygulamanın açılış ekranı: çek portföyü özeti.
/// Toplam tahsil/ödenecek (canlı kurrla TL karşılığı dahil), net durum,
/// vadesi geçen ve yaklaşan çekler ile bugünün görevleri tek bakışta gösterilir.
class GenelDurumView extends StatefulWidget {
  const GenelDurumView({super.key});

  @override
  State<GenelDurumView> createState() => _GenelDurumViewState();
}

class _GenelDurumViewState extends State<GenelDurumView> {
  final Box<Map> _cekBox = Hive.box<Map>(DatabaseService.cekBoxName);
  final Box<Map> _todoBox = Hive.box<Map>(DatabaseService.todoBoxName);

  // Canlı kurlar (TL karşılığı hesabı için)
  Map<String, double> _alisKurlari = {};
  Map<String, double> _satisKurlari = {};
  bool _kurYukleniyor = true; // Alan başlangıcı: initState'te setState gerekmez
  DateTime? _kurZamani;
  bool _ilkYukleme = true;

  @override
  void initState() {
    super.initState();
    _kurlariGetir();
  }

  Future<void> _kurlariGetir() async {
    // İlk çağrı initState'ten gelir; o sırada setState çağrılamaz
    if (!_ilkYukleme && mounted) {
      setState(() { _kurYukleniyor = true; });
    }
    _ilkYukleme = false;

    final tablo = await DovizService.kurTablosunuGetir();
    if (!mounted) return;
    setState(() {
      _alisKurlari = tablo.alis;
      _satisKurlari = tablo.satis;
      _kurYukleniyor = false;
      _kurZamani = tablo.alis.isNotEmpty ? DateTime.now() : null;
    });
  }

  // -----------------------------------------------------------------
  // HESAPLAMA YARDIMCILARI
  // -----------------------------------------------------------------

  /// Vade metnini ("dd.MM.yyyy") tarihe çevirir; geçersizse null döner
  DateTime? _vadeTarihi(Map cek) {
    try {
      return DateFormat("dd.MM.yyyy").parse((cek["tarih"] ?? "").toString());
    } catch (_) {
      return null;
    }
  }

  /// Belirtilen türdeki açık çeklerin toplamını para birimi bazında döndürür
  Map<String, double> _turToplami(List<Map> cekler, String tur) {
    final Map<String, double> toplam = {};
    for (final cek in cekler) {
      if (cek["isPaid"] == true || cek["tur"] != tur) continue;
      final double? deger = ParaUtils.sayiyaCevir(cek["tutar"]);
      if (deger == null) continue;
      final String birim = (cek["paraBirimi"] ?? "TL").toString();
      toplam[birim] = (toplam[birim] ?? 0) + deger;
    }
    return toplam;
  }

  /// Para birimi bazlı toplamları verilen kur tablosuyla TL'ye çevirir.
  /// Kur bulunamayan para birimleri toplama katılmaz.
  double _tlKarsiligi(Map<String, double> toplamlar, Map<String, double> kurlar) {
    double toplam = 0;
    toplamlar.forEach((birim, deger) {
      if (birim == "TL") {
        toplam += deger;
      } else {
        final double? kur = kurlar[birim];
        if (kur != null) toplam += deger * kur;
      }
    });
    return toplam;
  }

  /// Kur tablosunda bulunamayan para birimlerini listeler
  List<String> _eksikKurlar(Map<String, double> toplamlar) {
    final eksikler = toplamlar.keys
        .where((birim) => birim != "TL" && !_satisKurlari.containsKey(birim))
        .toList();
    eksikler.sort();
    return eksikler;
  }

  /// Açık çekleri vadeye göre sıralar (en yakın/eskiden yeniye)
  void _vadeyeGoreSirala(List<Map> cekler) {
    cekler.sort((a, b) {
      final ta = _vadeTarihi(a);
      final tb = _vadeTarihi(b);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return ta.compareTo(tb);
    });
  }

  // -----------------------------------------------------------------
  // EKRAN
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: _cekBox.listenable(),
        builder: (context, _, _) => ValueListenableBuilder(
          valueListenable: _todoBox.listenable(),
          builder: (context, _, _) {
            // ---------------- VERİ HAZIRLIĞI ----------------
            final bugun = DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day);
            final String bugunStr = DateFormat("dd.MM.yyyy").format(bugun);

            final acikCekler =
                _cekBox.values.where((c) => c["isPaid"] != true).toList();

            final List<Map> geciken = [];
            final List<Map> buHafta = [];
            final List<Map> sonraki = [];
            for (final cek in acikCekler) {
              final vade = _vadeTarihi(cek);
              if (vade == null) {
                sonraki.add(cek); // Tarihi okunamayanlar "sonraki" bölümünde sayılır
                continue;
              }
              final v = DateTime(vade.year, vade.month, vade.day);
              if (v.isBefore(bugun)) {
                geciken.add(cek);
              } else if (!v.isAfter(bugun.add(const Duration(days: 7)))) {
                buHafta.add(cek);
              } else {
                sonraki.add(cek);
              }
            }
            _vadeyeGoreSirala(geciken);
            _vadeyeGoreSirala(buHafta);

            // Toplamlar ve TL karşılıkları
            final tahsilToplam = _turToplami(acikCekler, "tahsil");
            final odenecekToplam = _turToplami(acikCekler, "odenecek");
            final tahsilEksik = _eksikKurlar(tahsilToplam);
            final odemeEksik = _eksikKurlar(odenecekToplam);

            final bool kurVar = _satisKurlari.isNotEmpty && !_kurYukleniyor;
            final double tahsilTL = kurVar ? _tlKarsiligi(tahsilToplam, _alisKurlari) : 0;
            final double odemeTL = kurVar ? _tlKarsiligi(odenecekToplam, _satisKurlari) : 0;
            final double netDurum = tahsilTL - odemeTL;

            // Kur tablosunda bulunamayan tüm para birimleri (birleşik, sıralı)
            final List<String> tumEksikKurlar =
                {...tahsilEksik, ...odemeEksik}.toList()..sort();

            // Görev sayıları
            final acikGorevler =
                _todoBox.values.where((g) => g["isCompleted"] != true).toList();
            final int bugunGorevSayisi =
                acikGorevler.where((g) => g["vadeTarihi"] == bugunStr).length;

            // ---------------- BOŞ DURUM ----------------
            if (_cekBox.isEmpty) {
              return RefreshIndicator(
                onRefresh: _kurlariGetir,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Icon(Icons.account_balance_wallet,
                        size: 64, color: Color(0xFFB0BEC5)),
                    SizedBox(height: 16),
                    Center(
                      child: Text(
                        "Henüz çek kaydı yok.",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(height: 6),
                    Center(
                      child: Text(
                        "Çek-Senet sekmesinden yeni çek/senet ekleyerek\nportföy özetini görmeye başlayın.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            }

            // ---------------- ANA GÖRÜNÜM ----------------
            return RefreshIndicator(
              onRefresh: _kurlariGetir,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                children: [
                  // Toplam kartları
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _kpiKarti(
                            baslik: "Tahsil Edilecek",
                            detay: ParaUtils.metneCevir(tahsilToplam),
                            tlSatiri: kurVar
                                ? "≈ ${ParaUtils.yaz(tahsilTL)} TL"
                                    "${tahsilEksik.isNotEmpty ? " *" : ""}"
                                : (_kurYukleniyor ? "Kur bekleniyor..." : "TL karşılığı yok"),
                            renk: Colors.green,
                            ikon: Icons.south_west,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _kpiKarti(
                            baslik: "Ödenecek",
                            detay: ParaUtils.metneCevir(odenecekToplam),
                            tlSatiri: kurVar
                                ? "≈ ${ParaUtils.yaz(odemeTL)} TL"
                                    "${odemeEksik.isNotEmpty ? " *" : ""}"
                                : (_kurYukleniyor ? "Kur bekleniyor..." : "TL karşılığı yok"),
                            renk: Colors.red,
                            ikon: Icons.north_east,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Net durum
                  if (kurVar)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _netDurumKarti(netDurum),
                    ),

                  // Kur bilgisi satırı
                  _kurSatiri(kurVar, tumEksikKurlar),

                  // Vadesi geçmiş çekler
                  if (geciken.isNotEmpty) ...[
                    _bolumBasligi(
                        "Vadesi Geçmiş", geciken.length, Colors.red, Icons.warning),
                    ...geciken.map((cek) => CekKarti(
                          cek: cek,
                          firmaAdi:
                              DatabaseService.firmaAdiGetir(cek["firmaId"]),
                        )),
                  ],

                  // Önümüzdeki 7 gün
                  if (buHafta.isNotEmpty) ...[
                    _bolumBasligi("Önümüzdeki 7 Gün", buHafta.length,
                        Colors.orange, Icons.event),
                    ...buHafta.map((cek) => CekKarti(
                          cek: cek,
                          firmaAdi:
                              DatabaseService.firmaAdiGetir(cek["firmaId"]),
                        )),
                  ],

                  // Bugünün görevleri
                  if (acikGorevler.isNotEmpty) _gorevKarti(bugunGorevSayisi, acikGorevler.length),

                  // Daha sonraki vadeler
                  if (sonraki.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        "📅 Daha sonraki vadelerde ${sonraki.length} açık çek var "
                        "(Çek-Senet sekmesinde).",
                        style: TextStyle(
                            fontSize: 13, color: Colors.blueGrey.shade600),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // PARÇA WIDGET'LAR
  // -----------------------------------------------------------------

  Widget _kpiKarti({
    required String baslik,
    required String detay,
    required String tlSatiri,
    required MaterialColor renk,
    required IconData ikon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        color: renk.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              detay,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              tlSatiri,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: renk.shade700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _netDurumKarti(double netDurum) {
    final bool pozitif = netDurum >= 0;
    final Color renk = pozitif ? Colors.green.shade700 : Colors.red.shade700;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  (pozitif ? Colors.green : Colors.red).withValues(alpha: 0.12),
              child: Icon(
                pozitif ? Icons.trending_up : Icons.trending_down,
                color: renk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Net Durum (TL karşılığı)",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${pozitif ? "+" : ""}${ParaUtils.yaz(netDurum)} TL",
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: renk),
                  ),
                  const Text(
                    "Tahsil edilecekler − ödenecekler (alacak alış, borç satış kuruyla)",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kurSatiri(bool kurVar, List<String> eksikKurlar) {
    Widget icerik;
    if (_kurYukleniyor) {
      icerik = Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text("Kurlar yükleniyor...",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      );
    } else if (!kurVar) {
      icerik = Row(
        children: [
          Icon(Icons.wifi_off, size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "Kura erişilemedi — TL karşılığı gösterilemiyor. Yenilemek için aşağı çekin.",
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            ),
          ),
        ],
      );
    } else {
      String metin =
          "Kur: ${DateFormat('HH:mm').format(_kurZamani ?? DateTime.now())} itibarıyla";
      if (eksikKurlar.isNotEmpty) {
        metin += " — * ${eksikKurlar.join(", ")} kuru alınamadı, TL toplamına katılmadı";
      }
      icerik = Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.blueGrey.shade400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              metin,
              style:
                  TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: icerik,
    );
  }

  Widget _bolumBasligi(
      String baslik, int adet, MaterialColor renk, IconData ikon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Icon(ikon, size: 18, color: renk.shade700),
          const SizedBox(width: 6),
          Text(
            baslik,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: renk.shade700),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$adet",
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: renk.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gorevKarti(int bugunGorevSayisi, int toplamGorev) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0288D1).withValues(alpha: 0.12),
          child: const Icon(Icons.check_box, color: Color(0xFF0288D1)),
        ),
        title: Text(
          bugunGorevSayisi > 0
              ? "Bugün: $bugunGorevSayisi görev"
              : "Bugün vadesi olan görev yok",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Toplam bekleyen görev: $toplamGorev",
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
