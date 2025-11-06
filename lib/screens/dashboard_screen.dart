import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  final DatabaseReference markersRef;

  const DashboardScreen({super.key, required this.markersRef});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: StreamBuilder(
        stream: markersRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          if (!snapshot.hasData ||
              snapshot.data == null ||
              snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Text(
                'Nenhum marcador encontrado.\nAdicione um no mapa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final markersState = <String, Map<String, dynamic>>{};
          final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          data.forEach((key, value) {
            if (value is Map<dynamic, dynamic>) {
              markersState[key] = {
                'humidity': value['humidity'] ?? 0,
                'waterlevel': value['waterlevel'] ?? 0,
                'waterFlow': value['waterFlow'] ?? 0,
                'ph': value['ph'] ?? 0.0,
                'isGateOpen': value['isGateOpen'] ?? false,
              };

              // Só salva no histórico se mudou
              saveMarkerHistoryIfChanged(
                markersRef.child(key),
                markersState[key]!,
              );
            }
          });

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: markersState.length,
            itemBuilder: (context, index) {
              final markerId = markersState.keys.elementAt(index);
              final markerData = markersState[markerId]!;

              return Card(
                elevation: 2.0,
                margin: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 4.0,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marker: $markerId',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // Indicador Nível de Água
                      _buildIndicator(
                        label: 'Water Level',
                        value: (markerData['waterlevel'] ?? 0).toDouble(),
                        unit: '%',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12.0),

                      // Indicador Umidade do Solo
                      _buildIndicator(
                        label: 'Soil Humidity',
                        value: (markerData['humidity'] ?? 0).toDouble(),
                        unit: '%',
                        color: Colors.brown,
                      ),
                      const SizedBox(height: 12.0),

                      // Indicador Fluxo de Água
                      _buildIndicator(
                        label: 'Water Flow',
                        value: (markerData['waterFlow'] ?? 0).toDouble(),
                        unit: 'L/min',
                        color: Colors.lightBlueAccent,
                        isPercentage: false,
                      ),
                      const SizedBox(height: 12.0),

                      // Indicador Ph
                      _buildIndicator(
                        label: 'Water Ph',
                        value: (markerData['ph'] ?? 0.0).toDouble(),
                        unit: '',
                        color: Colors.green,
                        isPercentage: false,
                        maxValue: 14.0,
                      ),
                      const SizedBox(height: 16.0),

                      // Status da Comporta
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Gate Status:',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            markerData['isGateOpen'] ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: markerData['isGateOpen']
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),

                      // Histórico (últimas 5 leituras)
                      StreamBuilder(
                        stream: markersRef
                            .child(markerId)
                            .child('history')
                            .orderByChild('timestamp')
                            .limitToLast(5)
                            .onValue,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData ||
                              snapshot.data?.snapshot.value == null) {
                            return const Text(
                              'Sem histórico disponível.',
                              style: TextStyle(color: Colors.grey),
                            );
                          }

                          final historyData =
                              snapshot.data!.snapshot.value
                                  as Map<dynamic, dynamic>;

                          final entries = historyData.entries.toList()
                            ..sort(
                              (a, b) => (b.value['timestamp'] ?? 0).compareTo(
                                a.value['timestamp'] ?? 0,
                              ),
                            );

                          return ExpansionTile(
                            title: const Text('Histórico recente'),
                            children: entries.map((entry) {
                              final e = entry.value as Map;
                              final date = DateTime.fromMillisecondsSinceEpoch(
                                e['timestamp'],
                              );
                              return ListTile(
                                title: Text(
                                  'Water: ${e['waterlevel']}% | Humidity: ${e['humidity']}% | Flow: ${e['waterFlow']} | pH: ${e['ph']}',
                                ),
                                subtitle: Text(
                                  'Gate: ${e['isGateOpen'] ? 'Open' : 'Closed'} - ${date.toLocal()}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Salva histórico apenas se houve alteração
  Future<void> saveMarkerHistoryIfChanged(
    DatabaseReference markerRef,
    Map<String, dynamic> newData,
  ) async {
    final historyRef = markerRef.child('history');

    // Lê o último histórico salvo
    final lastSnapshot = await historyRef
        .orderByChild('timestamp')
        .limitToLast(1)
        .get();

    bool hasChanged = true;

    if (lastSnapshot.exists) {
      final lastEntry =
          (lastSnapshot.value as Map<dynamic, dynamic>).values.first
              as Map<dynamic, dynamic>;

      hasChanged =
          newData['humidity'] != lastEntry['humidity'] ||
          newData['waterlevel'] != lastEntry['waterlevel'] ||
          newData['waterFlow'] != lastEntry['waterFlow'] ||
          newData['ph'] != lastEntry['ph'] ||
          newData['isGateOpen'] != lastEntry['isGateOpen'];
    }

    // Só adiciona se houve mudança
    if (hasChanged) {
      await historyRef.push().set({
        'timestamp': ServerValue.timestamp,
        ...newData,
      });

      // Mantém apenas os últimos 5 registros
      final allSnapshots = await historyRef.orderByChild('timestamp').get();
      if (allSnapshots.exists) {
        final allData = allSnapshots.value as Map<dynamic, dynamic>;
        final sortedKeys = allData.keys.toList()
          ..sort((a, b) {
            final at = allData[a]['timestamp'] ?? 0;
            final bt = allData[b]['timestamp'] ?? 0;
            return bt.compareTo(at);
          });

        for (int i = 5; i < sortedKeys.length; i++) {
          await historyRef.child(sortedKeys[i]).remove();
        }
      }
    }
  }

  /// Indicador visual
  Widget _buildIndicator({
    required String label,
    required double value,
    required String unit,
    required Color color,
    bool isPercentage = true,
    double maxValue = 100.0,
  }) {
    final double progressValue = (value / maxValue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            Text(
              '$value $unit',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 12.0,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
