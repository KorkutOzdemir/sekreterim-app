import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:finansal_takip_app/services/database_services.dart';

class TodoView extends StatefulWidget {
  const TodoView({super.key});

  @override
  State<TodoView> createState() => _TodoViewState();
}

class _TodoViewState extends State<TodoView> {
  final Box<Map> _todoBox = Hive.box<Map>(DatabaseService.todoBoxName);

  final TextEditingController _yaziKontrolcu = TextEditingController();

  // Göreve isteğe bağlı vade tarihi (takvimde görünmesi için)
  String _secilenTarih = "";

  @override
  void dispose() {
    _yaziKontrolcu.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final DateTime? secilen = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: "Görev Vade Tarihi",
    );
    if (secilen != null) {
      setState(() {
        _secilenTarih = DateFormat("dd.MM.yyyy").format(secilen);
      });
    }
  }

  void _gorevEkle() {
    if (_yaziKontrolcu.text.isNotEmpty) {
      String id = DateTime.now().millisecondsSinceEpoch.toString();

      // Doğrudan kutuya ekle (setState YOK)
      _todoBox.put(id, {
        "id": id,
        "title": _yaziKontrolcu.text,
        "isCompleted": false,
        if (_secilenTarih.isNotEmpty) "vadeTarihi": _secilenTarih,
      });
      _yaziKontrolcu.clear();
      setState(() { _secilenTarih = ""; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _yaziKontrolcu,
                        onSubmitted: (_) => _gorevEkle(),
                        decoration: InputDecoration(
                          labelText: "Yeni görev yazın...",
                          suffixIcon: IconButton(
                            tooltip: "Vade tarihi ekle (takvimde görünür)",
                            icon: Icon(
                              _secilenTarih.isEmpty ? Icons.event : Icons.event_available,
                              color: _secilenTarih.isEmpty ? Colors.grey : const Color(0xFF0288D1),
                            ),
                            onPressed: _tarihSec,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _gorevEkle,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(52, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
                // Seçilmiş vade tarihi çipi (kapatılabilir)
                if (_secilenTarih.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(Icons.event, size: 16, color: Color(0xFF0288D1)),
                        label: Text("Vade: $_secilenTarih"),
                        onDeleted: () => setState(() { _secilenTarih = ""; }),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            // Hive veritabanını canlı olarak dinleyen nöbetçiyi koyuyoruz
            child: ValueListenableBuilder(
              valueListenable: _todoBox.listenable(),
              builder: (context, Box<Map> box, _) {
                final gorevler = box.values.toList();

                if (gorevler.isEmpty) {
                  return const Center(
                    child: Text("Henüz bir görev eklenmedi."),
                  );
                }

                return ListView.builder(
                  itemCount: gorevler.length,
                  itemBuilder: (context, index) {
                    final gorev = gorevler[index];
                    final String gorevId = gorev["id"];
                    final String vadeTarihi = (gorev["vadeTarihi"] ?? "").toString();

                    return Card(
                      child: ListTile(
                        // Eğer görev tamamlandıysa yazının üstünü çiziyoruz
                        title: Text(
                          gorev["title"],
                          style: TextStyle(
                            decoration: gorev["isCompleted"]
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        // Vade tarihi varsa altta göster
                        subtitle: vadeTarihi.isEmpty ? null : Text(
                          "Vade: $vadeTarihi",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0288D1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // Sol taraftaki Checkbox Butonu
                        leading: IconButton(
                          icon: Icon(
                            gorev["isCompleted"]
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () {
                            // Doğrudan güncelle (setState YOK)
                            _todoBox.put(gorevId, {
                              ...gorev,
                              "isCompleted": !gorev["isCompleted"],
                            });
                          },
                        ),
                        // Sağ taraftaki Silme Butonu
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () {
                            _todoBox.delete(gorevId);
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
