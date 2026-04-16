import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../utils/ui_components.dart';

bool _asHumidityBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'humido';
  }
  return false;
}

bool _asWaterLevelBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'alto' ||
        normalized == 'high' ||
        normalized == 'sim') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'baixo' ||
        normalized == 'low' ||
        normalized == 'nao' ||
        normalized == 'não') {
      return false;
    }
  }
  return false;
}

enum MarkerFilter { all, gateOpen, humidSoil, drySoil, criticalPh, noWater }

enum MarkerSort { idAsc, idDesc, dryFirst, humidFirst, phAsc, phDesc }

class DashboardScreen extends StatefulWidget {
  final DatabaseReference markersRef;

  const DashboardScreen({super.key, required this.markersRef});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  MarkerFilter _activeFilter = MarkerFilter.all;
  MarkerSort _activeSort = MarkerSort.idAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isCritical(Map<String, dynamic> markerData) {
    final humidity = _asHumidityBool(markerData['humidity']);
    final waterLevel = _asWaterLevelBool(markerData['waterlevel']);
    final ph = (markerData['ph'] ?? 0.0) as num;
    return !humidity || !waterLevel || ph < 6.0 || ph > 8.0;
  }

  bool _matchesFilter(
    MarkerFilter filter,
    String markerId,
    Map<String, dynamic> markerData,
  ) {
    switch (filter) {
      case MarkerFilter.all:
        return true;
      case MarkerFilter.gateOpen:
        return markerData['isGateOpen'] == true;
      case MarkerFilter.humidSoil:
        return _asHumidityBool(markerData['humidity']);
      case MarkerFilter.drySoil:
        return !_asHumidityBool(markerData['humidity']);
      case MarkerFilter.criticalPh:
        final ph = (markerData['ph'] ?? 0.0) as num;
        return ph < 6.0 || ph > 8.0;
      case MarkerFilter.noWater:
        return !_asWaterLevelBool(markerData['waterlevel']);
    }
  }

  List<MapEntry<String, Map<String, dynamic>>> _applySort(
    List<MapEntry<String, Map<String, dynamic>>> markers,
  ) {
    markers.sort((a, b) {
      switch (_activeSort) {
        case MarkerSort.idAsc:
          return a.key.compareTo(b.key);
        case MarkerSort.idDesc:
          return b.key.compareTo(a.key);
        case MarkerSort.dryFirst:
          final ah = _asHumidityBool(a.value['humidity']) ? 1 : 0;
          final bh = _asHumidityBool(b.value['humidity']) ? 1 : 0;
          return ah.compareTo(bh);
        case MarkerSort.humidFirst:
          final ah = _asHumidityBool(a.value['humidity']) ? 1 : 0;
          final bh = _asHumidityBool(b.value['humidity']) ? 1 : 0;
          return bh.compareTo(ah);
        case MarkerSort.phAsc:
          final aph = (a.value['ph'] ?? 0.0) as num;
          final bph = (b.value['ph'] ?? 0.0) as num;
          return aph.compareTo(bph);
        case MarkerSort.phDesc:
          final aph = (a.value['ph'] ?? 0.0) as num;
          final bph = (b.value['ph'] ?? 0.0) as num;
          return bph.compareTo(aph);
      }
    });
    return markers;
  }

  String _sortLabel(MarkerSort sort) {
    switch (sort) {
      case MarkerSort.idAsc:
        return 'ID (A-Z)';
      case MarkerSort.idDesc:
        return 'ID (Z-A)';
      case MarkerSort.dryFirst:
        return 'Solo seco primeiro';
      case MarkerSort.humidFirst:
        return 'Solo úmido primeiro';
      case MarkerSort.phAsc:
        return 'pH crescente';
      case MarkerSort.phDesc:
        return 'pH decrescente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resumo operacional')),
      body: StreamBuilder<DatabaseEvent>(
        stream: widget.markersRef.onValue,
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
                'humidity': _asHumidityBool(value['humidity']),
                'waterlevel': _asWaterLevelBool(value['waterlevel']),
                'waterFlow': value['waterFlow'] ?? 0,
                'ph': value['ph'] ?? 0.0,
                'isGateOpen': value['isGateOpen'] ?? false,
              };

              saveMarkerHistoryIfChanged(
                widget.markersRef.child(markerId),
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
          final int humidCount = markerValues
              .where((e) => _asHumidityBool(e['humidity']))
              .length;
          final int dryCount = markerValues.length - humidCount;
          final int availableWaterCount = markerValues
              .where((e) => _asWaterLevelBool(e['waterlevel']))
              .length;
          final int openGateCount = markerValues
              .where((e) => (e['isGateOpen'] ?? false) == true)
              .length;
          final int criticalCount = markerValues.where(_isCritical).length;
          final double avgPh =
              markerValues
                  .map((e) => (e['ph'] ?? 0.0) as num)
                  .fold<num>(0, (sum, value) => sum + value)
                  .toDouble() /
              markerValues.length;

          final searchText = _searchController.text.trim().toLowerCase();
          final filteredEntries = markersState.entries.where((entry) {
            final idMatch = entry.key.toLowerCase().contains(searchText);
            final filterMatch = _matchesFilter(
              _activeFilter,
              entry.key,
              entry.value,
            );
            return idMatch && filterMatch;
          }).toList();

          final sortedEntries = _applySort(filteredEntries);
          final bool isDesktop = MediaQuery.of(context).size.width >= 1100;

          final listView = ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: sortedEntries.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Resumo operacional',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            BadgeChip(
                              icon: criticalCount > 0
                                  ? Icons.report_problem
                                  : Icons.verified,
                              text: criticalCount > 0
                                  ? '$criticalCount em alerta'
                                  : 'Tudo estável',
                              color: criticalCount > 0
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            BadgeChip(
                              icon: Icons.hub,
                              text: '${markersState.length} pontos',
                              color: Colors.teal.shade700,
                            ),
                            BadgeChip(
                              icon: Icons.water_drop,
                              text: '$availableWaterCount com água',
                              color: Colors.blue.shade700,
                            ),
                            BadgeChip(
                              icon: Icons.grass,
                              text: '$humidCount úmidos / $dryCount secos',
                              color: Colors.brown.shade700,
                            ),
                            BadgeChip(
                              icon: Icons.lock,
                              text: '$openGateCount comportas abertas',
                              color: Colors.green.shade700,
                            ),
                            BadgeChip(
                              icon: Icons.warning_amber,
                              text: '$criticalCount alertas',
                              color: criticalCount > 0
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                            BadgeChip(
                              icon: Icons.science,
                              text: 'pH médio ${avgPh.toStringAsFixed(1)}',
                              color: Colors.indigo.shade700,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (index == 1) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Buscar por ID do ponto',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('Todos', MarkerFilter.all),
                              _buildFilterChip(
                                'Comporta aberta',
                                MarkerFilter.gateOpen,
                              ),
                              _buildFilterChip(
                                'Solo úmido',
                                MarkerFilter.humidSoil,
                              ),
                              _buildFilterChip(
                                'Solo seco',
                                MarkerFilter.drySoil,
                              ),
                              _buildFilterChip(
                                'pH critico',
                                MarkerFilter.criticalPh,
                              ),
                              _buildFilterChip(
                                'Sem agua',
                                MarkerFilter.noWater,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.sort, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<MarkerSort>(
                                value: _activeSort,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
                                items: MarkerSort.values
                                    .map(
                                      (sort) => DropdownMenuItem(
                                        value: sort,
                                        child: Text(_sortLabel(sort)),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _activeSort = value);
                                },
                              ),
                            ),
                          ],
                        ),
                        if (sortedEntries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Nenhum ponto encontrado para os filtros selecionados.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              final markerId = sortedEntries[index - 2].key;
              final markerData = sortedEntries[index - 2].value;
              final bool isGateOpen = markerData['isGateOpen'] == true;
              final bool critical = _isCritical(markerData);

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
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          BadgeChip(
                            icon: critical ? Icons.error_outline : Icons.check,
                            text: critical
                                ? 'Status: Critico'
                                : 'Status: Estavel',
                            color: critical ? Colors.red : Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      BadgeChip(
                        icon: _asWaterLevelBool(markerData['waterlevel'])
                            ? Icons.water_drop
                            : Icons.warning_amber,
                        text: _asWaterLevelBool(markerData['waterlevel'])
                            ? 'Nivel de agua: alto'
                            : 'Nivel de agua: baixo',
                        color: _asWaterLevelBool(markerData['waterlevel'])
                            ? Colors.blue.shade700
                            : Colors.red.shade700,
                      ),
                      const SizedBox(height: 12),
                      BadgeChip(
                        icon: _asHumidityBool(markerData['humidity'])
                            ? Icons.water_drop
                            : Icons.grass,
                        text: _asHumidityBool(markerData['humidity'])
                            ? 'Umidade do solo: úmido'
                            : 'Umidade do solo: seco',
                        color: _asHumidityBool(markerData['humidity'])
                            ? Colors.green.shade700
                            : Colors.brown.shade700,
                      ),
                      const SizedBox(height: 12),
                      _buildIndicator(
                        label: 'Fluxo de água',
                        value: (markerData['waterFlow'] ?? 0).toDouble(),
                        unit: 'L/min',
                        color: Colors.lightBlueAccent,
                        maxValue: 30,
                      ),
                      const SizedBox(height: 12),
                      _buildIndicator(
                        label: 'pH da água',
                        value: (markerData['ph'] ?? 0.0).toDouble(),
                        unit: '',
                        color: Colors.green,
                        maxValue: 14,
                      ),
                      const SizedBox(height: 16),

                      const SizedBox(height: 10),
                      StreamBuilder<DatabaseEvent>(
                        stream: widget.markersRef
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
                                  'Agua: ${_asWaterLevelBool(e['waterlevel']) ? 'alto' : 'baixo'} | Umidade: ${_asHumidityBool(e['humidity']) ? 'Úmido' : 'Seco'} | Fluxo: ${e['waterFlow']} | pH: ${e['ph']}',
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

          if (!isDesktop) {
            return listView;
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: listView,
            ),
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
          _asWaterLevelBool(newData['waterlevel']) !=
              _asWaterLevelBool(lastEntry['waterlevel']) ||
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

  Widget _buildFilterChip(String label, MarkerFilter filter) {
    final selected = _activeFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _activeFilter = filter;
          });
        },
      ),
    );
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
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
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
