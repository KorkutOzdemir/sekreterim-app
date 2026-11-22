import 'package:flutter/material.dart';
import 'package:finansal_takip_app/services/doviz_service.dart';

class DovizKurlariView extends StatefulWidget {
  const DovizKurlariView({super.key});

  @override
  State<DovizKurlariView> createState() => _DovizKurlariViewState();
}

class _DovizKurlariViewState extends State<DovizKurlariView> {
  late Future<List<DovizModel>> _piyasaGelecek;

  @override
  void initState() {
    super.initState();
    _piyasaGelecek = DovizService.piyasaVerileriniGetir();
  }

  Future<void> _kurlariYenile() async {
    setState(() { _piyasaGelecek = DovizService.piyasaVerileriniGetir(); });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _kurlariYenile,
        child: FutureBuilder<List<DovizModel>>(
          future: _piyasaGelecek,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: tema.colorScheme.primary));
            }

            if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.wifi_off, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      "Kurlar yüklenemedi.\nİnternet bağlantınızı kontrol edip\naşağı çekerek yenileyin.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            final veriler = snapshot.data!;
            final dovizler = veriler.where((v) => v.tur == "Doviz").toList();
            final metaller = veriler.where((v) => v.tur == "Altin").toList();

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: dovizler.length + metaller.length + 2,
              itemBuilder: (context, index) {
                // Bölüm başlıkları ve kartlar tek listede sıralanıyor
                if (index == 0) {
                  return _bolumBasligi("💵 Döviz Kurları", dovizler.isNotEmpty);
                }
                if (index == dovizler.length + 1) {
                  return _bolumBasligi("🥇 Altın & Gümüş", metaller.isNotEmpty);
                }

                final DovizModel kur;
                if (index <= dovizler.length) {
                  kur = dovizler[index - 1];
                } else {
                  kur = metaller[index - dovizler.length - 2];
                }
                return _kurKarti(kur, tema);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _bolumBasligi(String baslik, bool gorunur) {
    if (!gorunur) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
      child: Text(
        baslik,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A237E),
        ),
      ),
    );
  }

  Widget _kurKarti(DovizModel kur, ThemeData tema) {
    final bool altinMi = kur.tur == "Altin";

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tema.colorScheme.secondary.withValues(alpha: 0.15),
                    child: Icon(
                      altinMi ? Icons.workspace_premium : Icons.currency_exchange,
                      size: 20,
                      color: tema.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          kur.isim,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          altinMi ? kur.kod.replaceAll('-', ' ') : kur.kod,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Alış", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text("${kur.alis} ₺", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green, fontSize: 13)),
                  ],
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Satış", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text("${kur.satis} ₺", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
