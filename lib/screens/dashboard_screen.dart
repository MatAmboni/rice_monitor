import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../utils/ui_components.dart';

class DashboardScreen extends StatelessWidget {
  final DatabaseReference markersRef;

  const DashboardScreen({super.key, required this.markersRef});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard de Irrigacao')),
      body: StreamBuilder<DatabaseEvent>(
        stream: markersRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }

          final snapshotValue = snapshot.data?.snapshot.value;
          if (snapshotValue == null) {
            return const Center(
              child: Text(
                'Nenhum marcador encontrado.\nAdicione um no mapa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final markersState = <String, Map<String, dynamic>>{};
          final data = snapshotValue as Map<dynamic, dynamic>;

          data.forEach((key, value) {
            if (value is Map<dynamic, dynamic>) {
              final markerId = key.toString();
              markersState[markerId] = {
                'humidity': value['humidity'] ?? 0,
                'waterlevel': value['waterlevel'] ?? 0,
                'waterFlow': value['waterFlow'] ?? 0,
                'ph': value['ph'] ?? 0.0,
                'isGateOpen': value['isGateOpen'] ?? false,
              };

              saveMarkerHistoryIfChanged(
                markersRef.child(markerId),
                markersState[markerId]!,
              );
            }
          });

          if (markersState.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum marcador encontrado.\nAdicione um no mapa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final markerValues = markersState.values.toList();
          final double avgHumidity =
              markerValues
                  .map((e) => (e['humidity'] ?? 0) as num)
                  .fold<num>(0, (sum, value) => sum + value)
                  .toDouble() /
              markerValues.length;
          final int availableWaterCount = markerValues
              .where((e) => (e['waterlevel'] ?? 0) == 1)
              .length;
          final int openGateCount = markerValues
              .where((e) => (e['isGateOpen'] ?? false) == true)
              .length;

          final markerIds = markersState.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: markerIds.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo Operacional',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            BadgeChip(
                              icon: Icons.hub,
                              text: '${markersState.length} pontos monitorados',
                              color: Colors.teal.shade700,
                            ),
                            BadgeChip(
                              icon: Icons.opacity,
                              text:
                                  'Umidade media ${avgHumidity.toStringAsFixed(1)}%',
                              color: Colors.brown.shade600,
                            ),
                            BadgeChip(
                              icon: Icons.water_drop,
                              text: '$availableWaterCount com agua disponivel',
                              color: Colors.blue.shade700,
                            ),
                            BadgeChip(
                              icon: Icons.door_front_door,
                              text: '$openGateCount comportas abertas',
                              color: Colors.green.shade700,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              final markerId = markerIds[index - 1];
              final markerData = markersState[markerId]!;
              final bool isGateOpen = markerData['isGateOpen'] == true;

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 4,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ponto: $markerId',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          BadgeChip(
                            icon: isGateOpen ? Icons.lock_open : Icons.lock,
                            text: isGateOpen
                                ? 'Comporta aberta'
                                : 'Comporta fechada',
                            color: isGateOpen ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildIndicator(
                        label: 'Nivel de agua',
                        value: (markerData['waterlevel'] ?? 0).toDouble(),
                        unit: '%',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildIndicator(
                        label: 'Umidade do solo',
                        value: (markerData['humidity'] ?? 0).toDouble(),
                        unit: '%',
                        color: Colors.brown,
                      ),
                      const SizedBox(height: 12),
                      _buildIndicator(
                        label: 'Fluxo de agua',
                        value: (markerData['waterFlow'] ?? 0).toDouble(),
                        unit: 'L/min',
                        color: Colors.lightBlueAccent,
                        maxValue: 30,
                      ),
                      const SizedBox(height: 12),
                      _buildIndicator(
                        label: 'pH da agua',
                        value: (markerData['ph'] ?? 0.0).toDouble(),
                        unit: '',
                        color: Colors.green,
                        maxValue: 14,
                      ),
                      const SizedBox(height: 16),
                  
                      const SizedBox(height: 10),
                      StreamBuilder<DatabaseEvent>(
                        stream: markersRef
                            .child(markerId)
                            .child('history')
                            .orderByChild('timestamp')
                            .limitToLast(5)
                            .onValue,
                        builder: (context, historySnapshot) {
                          if (!historySnapshot.hasData ||
                              historySnapshot.data?.snapshot.value == null) {
                            return const Text(
                              'Sem historico disponivel.',
                              style: TextStyle(color: Colors.grey),
                            );
                          }

                          final historyData =
                              historySnapshot.data!.snapshot.value
                                  as Map<dynamic, dynamic>;
                          final entries = historyData.entries.toList()
                            ..sort((a, b) {
                              final bt = b.value['timestamp'] ?? 0;
                              final at = a.value['timestamp'] ?? 0;
                              return bt.compareTo(at);
                            });

                          return ExpansionTile(
                            title: const Text('Historico recente'),
                            children: entries.map((entry) {
                              final e = entry.value as Map<dynamic, dynamic>;
                              final date = DateTime.fromMillisecondsSinceEpoch(
                                e['timestamp'] ?? 0,
                              );
                              return ListTile(
                                title: Text(
                                  'Agua: ${e['waterlevel']}% | Umidade: ${e['humidity']}% | Fluxo: ${e['waterFlow']} | pH: ${e['ph']}',
                                ),
                                subtitle: Text(
                                  'Comporta: ${e['isGateOpen'] == true ? 'Aberta' : 'Fechada'} - ${date.toLocal()}',
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

  Future<void> saveMarkerHistoryIfChanged(
    DatabaseReference markerRef,
    Map<String, dynamic> newData,
  ) async {
    final historyRef = markerRef.child('history');
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

    if (hasChanged) {
      await historyRef.push().set({
        'timestamp': ServerValue.timestamp,
        ...newData,
      });

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

  Widget _buildIndicator({
    required String label,
    required double value,
    required String unit,
    required Color color,
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
              '${value.toStringAsFixed(1)} $unit',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 12,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
