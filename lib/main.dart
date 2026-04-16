import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/firebase_options.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'screens/dashboard_screen.dart';
import 'utils/app_theme.dart';
import 'utils/ui_components.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // home: MyApp(),
      home: LoginScreen(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

FirebaseDatabase database = FirebaseDatabase.instance;

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

class _MyAppState extends State<MyApp> {
  late GoogleMapController mapController;
  final fm.MapController _webMapController = fm.MapController();
  final CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();
  Map<String, Map<String, dynamic>> markersState = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _markerSubscriptions =
      {};
  StreamSubscription<DatabaseEvent>? _humiditySub;
  StreamSubscription<DatabaseEvent>? _waterLevelSub;
  StreamSubscription<DatabaseEvent>? _waterFlowSub;
  StreamSubscription<DatabaseEvent>? _waterPhSub;
  MapType _mapType = MapType.satellite;
  bool _isMapCreated = false;
  bool _hasCenteredOnFirstMarker = false;
  bool humidity = false;
  bool waterlevel = false;
  int waterflow = 0;
  int ph = 0;
  bool isGateOpen = false;
  final List<String> _recentAlerts = [];
  final LatLng _center = const LatLng(-28.813556, -49.341167);

  // Lista de markers
  Set<Marker> markers = {};

  ll.LatLng get _webCenter => ll.LatLng(_center.latitude, _center.longitude);

  // Referências ao Firebase
  final DatabaseReference humidityRef = database.ref('humidity');
  final DatabaseReference waterLevelRef = database.ref('waterlevel');
  final DatabaseReference waterFlowRef = database.ref('waterFlow');
  final DatabaseReference waterPHRef = database.ref('ph');
  final DatabaseReference gateRef = database.ref('isGateOpen');

  // NOVO: Chave global para acessar o ScaffoldMessenger
  // Isso é necessário para mostrar o SnackBar de qualquer lugar,
  // inclusive de dentro dos listeners do Firebase.
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    markersState = {};
    _readHumidity();
    _readWaterLevel();
    _readWaterFlow();
    _readWaterPh();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      database
          .ref('markers')
          .once()
          .then((snapshot) {
            final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
            setState(() {
              if (data != null) {
                data.forEach((key, value) {
                  final markerData = value as Map<dynamic, dynamic>;
                  final position = LatLng(
                    markerData['latitude'] as double,
                    markerData['longitude'] as double,
                  );
                  markersState[key] = {
                    'humidity': _asHumidityBool(markerData['humidity']),
                    'waterlevel': _asWaterLevelBool(markerData['waterlevel']),
                    'waterFlow':
                        markerData['waterFlow'] ?? 0, // Include waterFlow
                    'ph': markerData['ph'] ?? 0, // Include ph
                    'isGateOpen': markerData['isGateOpen'] ?? false,
                  };
                  markers.add(_buildMarker(position, key, context));

                  // NOVO: Inicia o listener para dados em tempo real
                  // e verifica os dados assim que o marcador é carregado
                  _readMarkerData(key);
                });
                _tryCenterMapOnFirstMarker();
              } else {
                final markerId = 'marker_0';
                markers.add(_buildMarker(_center, markerId, context));
                database
                    .ref('markers/$markerId')
                    .set({
                      'latitude': _center.latitude,
                      'longitude': _center.longitude,
                      'humidity': false,
                      'waterlevel': false,
                      'waterFlow': 0, // Initialize waterFlow
                      'ph': 0, // Initialize ph
                      'isGateOpen': false,
                    })
                    .then((_) => print('Marker $markerId added to Firebase'))
                    .catchError(
                      (error) => print('Failed to add marker: $error'),
                    );
                // NOVO: Inicia o listener para o novo marcador
                _readMarkerData(markerId);
                _tryCenterMapOnFirstMarker();
              }
            });
          })
          // ignore: invalid_return_type_for_catch_error
          .catchError((error) => print('Failed to fetch markers: $error'));
    });
  }

  Marker _buildMarker(LatLng position, String id, BuildContext context) {
    final markerData = markersState[id] ?? const <String, dynamic>{};
    final bool isGateOpen = markerData['isGateOpen'] == true;

    return Marker(
      markerId: MarkerId(id),
      consumeTapEvents: true,
      draggable: true,
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isGateOpen ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueRed,
      ),
      infoWindow: InfoWindow.noText,
      onTap: () {
        _centerMapOnMarker(position);
        _showRoundedMarkerInfoWindow(id, position);
      },
      onDragEnd: (newPosition) {
        _customInfoWindowController.hideInfoWindow?.call();
        database
            .ref('markers/$id')
            .update({
              'latitude': newPosition.latitude,
              'longitude': newPosition.longitude,
            })
            .then((_) => print('Marker $id position updated'))
            .catchError(
              (error) => print('Failed to update marker position: $error'),
            );

        setState(() {
          markers = markers.map((marker) {
            if (marker.markerId.value == id) {
              return marker.copyWith(positionParam: newPosition);
            }
            return marker;
          }).toSet();
        });
      },
    );
  }

  fm.Marker _buildWebMarker(String id, ll.LatLng position) {
    final markerData = markersState[id] ?? const <String, dynamic>{};
    final bool isGateOpen = markerData['isGateOpen'] == true;

    return fm.Marker(
      point: position,
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () => _showWebMarkerDetails(id, position),
        child: Container(
          decoration: BoxDecoration(
            color: isGateOpen ? Colors.blue : Colors.red,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  List<fm.Marker> _buildWebMarkers() {
    return markersState.entries.map((entry) {
      final markerData = entry.value;
      final latitude = markerData['latitude'] as double? ?? _center.latitude;
      final longitude = markerData['longitude'] as double? ?? _center.longitude;
      return _buildWebMarker(entry.key, ll.LatLng(latitude, longitude));
    }).toList();
  }

  void _showWebMarkerDetails(String markerId, ll.LatLng position) {
    final markerData = markersState[markerId] ?? const <String, dynamic>{};

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Marcador $markerId'),
          content: Text(
            'Latitude: ${position.latitude.toStringAsFixed(5)}\n'
            'Longitude: ${position.longitude.toStringAsFixed(5)}\n'
            'Comporta: ${markerData['isGateOpen'] == true ? 'aberta' : 'fechada'}\n'
            'Umidade: ${_asHumidityBool(markerData['humidity']) ? 'sim' : 'nao'}\n'
            'Nivel da agua: ${_asWaterLevelBool(markerData['waterlevel']) ? 'alto' : 'baixo'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _centerMapOnMarker(LatLng position) {
    if (kIsWeb) {
      _webMapController.move(
        ll.LatLng(position.latitude, position.longitude),
        16.5,
      );
      return;
    }

    if (!_isMapCreated) {
      return;
    }

    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: 16.5),
      ),
    );
  }

  void _showRoundedMarkerInfoWindow(String markerId, LatLng position) {
    final markerData = markersState[markerId] ?? const <String, dynamic>{};
    final bool isGateOpen = markerData['isGateOpen'] == true;
    final bool hasHumidity = _asHumidityBool(markerData['humidity']);
    final bool hasWater = _asWaterLevelBool(markerData['waterlevel']);
    final double phValue = ((markerData['ph'] ?? 0.0) as num).toDouble();
    final bool isCritical =
        !hasHumidity || !hasWater || phValue < 6.0 || phValue > 8.0;

    final Color accent = isCritical
        ? Colors.red.shade700
        : Colors.green.shade700;
    final String gateLabel = isGateOpen ? 'Aberta' : 'Fechada';
    final String humidityLabel = hasHumidity ? 'Úmido' : 'Seco';
    final String waterLabel = hasWater ? 'Alto' : 'Baixo';

    _customInfoWindowController.addInfoWindow?.call(
      GestureDetector(
        onTap: () {
          _customInfoWindowController.hideInfoWindow?.call();
          _showMarkerDetails(context, markerId);
        },
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCritical
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle,
                    color: accent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ponto $markerId • ${isCritical ? 'ALERTA' : 'ESTÁVEL'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Comporta: $gateLabel | Solo: $humidityLabel',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                'Água: $waterLabel | pH: ${phValue.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.center,
                child: Text(
                  'Toque para detalhes',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A4A4A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      position,
    );
  }

  void _showMarkerDetails(BuildContext context, String markerId) {
    // MODIFICADO: A leitura de dados agora é constante (no initState),
    // então aqui apenas mostramos o modal.
    // _readMarkerData(markerId); // Esta linha não é mais necessária aqui.

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            final currentMarkerData = markersState[markerId] ?? {};
            final waterFlowValue = (currentMarkerData['waterFlow'] ?? 0) as num;
            final waterFlowText = waterFlowValue > 0 ? 'Sim' : 'Não';
            final waterFlowColor = waterFlowValue > 0
                ? Colors.blue
                : Colors.grey;

            // 2. Lógica da Água Disponível (Sim/Não)
            final waterLevelHigh = _asWaterLevelBool(
              currentMarkerData['waterlevel'],
            );
            final availableWaterText = waterLevelHigh ? 'Alto' : 'Baixo';
            final availableWaterColor = waterLevelHigh
                ? Colors.green
                : Colors.red;

            // 3. Lógica da Umidade (Seca/Úmida)
            final bool isHumid = _asHumidityBool(currentMarkerData['humidity']);
            final String humidityText = isHumid ? 'Terra Úmida' : 'Terra Seca';
            final Color humidityColor = isHumid
                ? Colors.brown.shade700
                : Colors.orange.shade800;

            // 4. Lógica do Círculo pH
            final phValue = (currentMarkerData['ph'] ?? 0.0).toDouble();
            final bool isPhOk = phValue >= 6.0 && phValue <= 8.0;
            final IconData phIcon = isPhOk
                ? Icons.check_circle
                : Icons.warning_amber;
            final Color phIconColor = isPhOk
                ? Colors.green.shade700
                : Colors.orange.shade700;

            // Widget do Círculo pH (MAIOR)
            Widget phStatusCircle = Container(
              width: 80, // Tamanho aumentado
              height: 80, // Tamanho aumentado
              margin: const EdgeInsets.only(left: 16.0, right: 8.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: phIconColor, width: 3.0),
                color: phIconColor.withValues(alpha: 0.1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'pH',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // Fonte aumentada
                      color: phIconColor,
                    ),
                  ),
                  Icon(phIcon, color: phIconColor, size: 28), // Ícone aumentado
                ],
              ),
            );

            return Container(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalhes de $markerId', // Traduzido
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool useStackedLayout = constraints.maxWidth < 390;

                      if (useStackedLayout) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              Icons.waves,
                              waterFlowColor,
                              'Fluxo de Água',
                              waterFlowText,
                            ),
                            _buildInfoRow(
                              Icons.layers,
                              availableWaterColor,
                              'Água Disponível',
                              availableWaterText,
                            ),
                            _buildInfoRow(
                              Icons.opacity,
                              humidityColor,
                              'Umidade do Solo',
                              humidityText,
                            ),
                            const SizedBox(height: 12),
                            Center(child: phStatusCircle),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                  Icons.waves,
                                  waterFlowColor,
                                  'Fluxo de Água',
                                  waterFlowText,
                                ),
                                _buildInfoRow(
                                  Icons.layers,
                                  availableWaterColor,
                                  'Água Disponível',
                                  availableWaterText,
                                ),
                                _buildInfoRow(
                                  Icons.opacity,
                                  humidityColor,
                                  'Umidade do Solo',
                                  humidityText,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: phStatusCircle,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Controle da Comporta",
                        style: TextStyle(fontSize: 16),
                      ),
                      Switch(
                        value: currentMarkerData['isGateOpen'] ?? false,
                        onChanged: (value) {
                          toggleGate(markerId, value);
                          modalSetState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _removeMarker(markerId);
                    },
                    icon: const Icon(Icons.delete, color: Colors.white),
                    label: const Text('Remover ponto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Icon(icon, color: color, size: 22),
          Text('$label:', style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void toggleGate(String markerId, bool status) {
    final markerState = markersState[markerId] ?? {};
    markerState['isGateOpen'] = status;

    setState(() {
      markersState[markerId] = markerState;
    });

    _writeMarkerData(
      markerId,
      status,
      _asHumidityBool(markerState['humidity']),
      _asWaterLevelBool(markerState['waterlevel']),
    );
  }

  void _readHumidity() {
    _humiditySub = humidityRef.onValue.listen((event) {
      final data = _asHumidityBool(event.snapshot.value);
      setState(() {
        humidity = data;
      });
    });
  }

  void _readWaterLevel() {
    _waterLevelSub = waterLevelRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null) {
        setState(() {
          waterlevel = _asWaterLevelBool(data);
        });
      }
    });
  }

  void _readWaterFlow() {
    _waterFlowSub = waterFlowRef.onValue.listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          waterflow = data;
        });
      }
    });
  }

  void _readWaterPh() {
    _waterPhSub = waterPHRef.onValue.listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          ph = data;
        });
      }
    });
  }

  void _tryCenterMapOnFirstMarker() {
    if (_hasCenteredOnFirstMarker || !_isMapCreated || markers.isEmpty) {
      if (kIsWeb && markers.isNotEmpty) {
        _webMapController.move(
          ll.LatLng(
            markers.first.position.latitude,
            markers.first.position.longitude,
          ),
          16.0,
        );
        _hasCenteredOnFirstMarker = true;
      }
      return;
    }

    _hasCenteredOnFirstMarker = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || markers.isEmpty) {
        return;
      }

      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: markers.first.position, zoom: 16.0),
        ),
      );
    });
  }

  void _addNewMarker(BuildContext context) {
    setState(() {
      final newPosition = LatLng(
        _center.latitude + (markers.length * 0.001), // desloca um pouco
        _center.longitude,
      );
      final markerId = 'marker_${markers.length}';
      markers.add(_buildMarker(newPosition, markerId, context));

      // Criar entrada no banco de dados para o novo marker
      database
          .ref('markers/$markerId')
          .set({
            'latitude': newPosition.latitude,
            'longitude': newPosition.longitude,
            'humidity': false,
            'waterlevel': false,
            'waterFlow': 0,
            'ph': 0,
            'isGateOpen': false,
          })
          .then((_) => print('Marker $markerId added to Firebase'))
          .catchError((error) => print('Failed to add marker: $error'));

      // NOVO: Inicia o listener para o novo marcador
      _readMarkerData(markerId);
    });
  }

  void _readMarkerData(String markerId) {
    _markerSubscriptions[markerId]?.cancel();
    _markerSubscriptions[markerId] = database
        .ref('markers/$markerId')
        .onValue
        .listen((event) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data != null) {
            final newMarkerData = {
              'humidity': _asHumidityBool(data['humidity']),
              'waterlevel': _asWaterLevelBool(data['waterlevel']),
              'isGateOpen': data['isGateOpen'] ?? false,
              'waterFlow': data['waterFlow'] ?? 0,
              'ph': (data['ph'] ?? 0).toDouble(),
            };

            final oldMarkerData = Map<String, dynamic>.from(
              markersState[markerId] ?? {},
            );

            if (mounted) {
              setState(() {
                markersState[markerId] = newMarkerData;
              });
            }

            // Só notifica se algo mudou
            _checkSensorValuesAndNotify(markerId, oldMarkerData, newMarkerData);
          }
        });
  }

  @override
  void dispose() {
    _customInfoWindowController.dispose();
    _humiditySub?.cancel();
    _waterLevelSub?.cancel();
    _waterFlowSub?.cancel();
    _waterPhSub?.cancel();
    for (final sub in _markerSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _checkSensorValuesAndNotify(
    String markerId,
    Map<String, dynamic> oldData,
    Map<String, dynamic> newData,
  ) {
    // === Comparar pH ===
    final oldPh = (oldData['ph'] ?? 0.0).toDouble();
    final newPh = (newData['ph'] ?? 0.0).toDouble();
    if (oldPh != newPh) {
      if (newPh < 6.0 && newPh > 0) {
        _sendLocalNotification(
          'Alerta de pH Baixo',
          'O pH no $markerId está muito baixo ($newPh)!',
        );
      } else if (newPh > 8.0) {
        _sendLocalNotification(
          'Alerta de pH Alto',
          'O pH no $markerId está muito alto ($newPh)!',
        );
      } else if (newPh >= 6.0 && newPh <= 8.0) {
        _sendLocalNotification(
          'pH Normalizado',
          'O pH no $markerId voltou ao normal ($newPh).',
        );
      }
    }

    // === Comparar nível da água ===
    final oldWaterLevel = _asWaterLevelBool(oldData['waterlevel']);
    final newWaterLevel = _asWaterLevelBool(newData['waterlevel']);
    if (oldWaterLevel != newWaterLevel) {
      if (!newWaterLevel) {
        _sendLocalNotification(
          'Alerta de Nível da Água',
          'Nível de água baixo (indisponível) no $markerId!',
        );
      } else {
        _sendLocalNotification(
          'Nível de Água Restaurado',
          'Nível de água normalizado no $markerId.',
        );
      }
    }

    // === Comparar fluxo de água ===
    final oldFlow = (oldData['waterFlow'] ?? -1) as num;
    final newFlow = (newData['waterFlow'] ?? -1) as num;
    if (oldFlow != newFlow) {
      if (newFlow > 0) {
        _sendLocalNotification(
          'Fluxo de Água Ativo',
          'Há fluxo de água detectado em $markerId.',
        );
      } else {
        _sendLocalNotification(
          'Fluxo de Água Interrompido',
          'Fluxo de água interrompido em $markerId.',
        );
      }
    }

    // === Comparar umidade ===
    final oldHumidity = _asHumidityBool(oldData['humidity']);
    final newHumidity = _asHumidityBool(newData['humidity']);
    if (oldHumidity != newHumidity) {
      if (!newHumidity) {
        _sendLocalNotification(
          'Solo Seco',
          'A umidade do solo está baixa em $markerId.',
        );
      } else {
        _sendLocalNotification(
          'Solo Úmido',
          'A umidade do solo foi restabelecida em $markerId.',
        );
      }
    }

    // === Comparar estado da comporta ===
    final oldGate = oldData['isGateOpen'] ?? false;
    final newGate = newData['isGateOpen'] ?? false;
    if (oldGate != newGate) {
      if (newGate == true) {
        _sendLocalNotification(
          'Comporta Aberta',
          'A comporta do $markerId foi aberta.',
        );
      } else {
        _sendLocalNotification(
          'Comporta Fechada',
          'A comporta do $markerId foi fechada.',
        );
      }
    }
  }

  // MODIFICADO: Lógica de notificação de sensores removida daqui
  void _writeMarkerData(
    String markerId,
    bool gateStatus,
    bool humidityValue,
    bool waterLevelValue,
  ) {
    database
        .ref('markers/$markerId')
        .update({
          'isGateOpen': gateStatus,
          'humidity': humidityValue,
          'waterlevel': waterLevelValue,
        })
        .then((_) {
          print('Marker $markerId data updated in Firebase');
          // A notificação sobre o portão permanece aqui,
          // pois é um feedback direto da ação do usuário.
          if (gateStatus) {
            _sendLocalNotification(
              'Portão aberto',
              'O portão do $markerId foi aberto.',
            );
          } else {
            _sendLocalNotification(
              'Portão fechado',
              'O portão do $markerId foi fechado.',
            );
          }
        })
        .catchError((error) {
          return null;
        });
  }

  // MODIFICADO: Usa a GlobalKey (_scaffoldMessengerKey) para mostrar o SnackBar
  void _sendLocalNotification(String title, String body) {
    setState(() {
      _recentAlerts.insert(0, '$title: $body');
      if (_recentAlerts.length > 20) {
        _recentAlerts.removeLast();
      }
    });

    // Verifica se o currentState não é nulo antes de usar
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('$title: $body'), duration: Duration(seconds: 3)),
    );
  }

  void _removeMarker(String markerId) {
    database
        .ref('markers/$markerId')
        .remove()
        .then((_) {
          print('Marker $markerId removed from Firebase');
          _markerSubscriptions.remove(markerId)?.cancel();
          setState(() {
            markers.removeWhere((marker) => marker.markerId.value == markerId);
            markersState.remove(markerId);
          });
        })
        // ignore: invalid_return_type_for_catch_error
        .catchError((error) => print('Failed to remove marker: $error'));
  }

  Widget _buildTopStatusPanel() {
    final int markerCount = markersState.length;
    final int openGates = markersState.values
        .where((marker) => marker['isGateOpen'] == true)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BadgeChip(
              icon: Icons.location_on,
              text: '$markerCount marcadores',
              color: Colors.teal.shade700,
            ),
            BadgeChip(
              icon: Icons.door_front_door,
              text: '$openGates comportas abertas',
              color: Colors.blue.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapQuickActions(BuildContext scaffoldContext) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'legend',
          onPressed: _showLegendSheet,
          child: const Icon(Icons.info_outline),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.small(
          heroTag: 'centerMap',
          onPressed: kIsWeb
              ? () {
                  _webMapController.move(_webCenter, 15);
                }
              : () {
                  mapController.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: _center, zoom: 15),
                    ),
                  );
                },
          child: const Icon(Icons.my_location),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'addMarker',
          onPressed: () => _addNewMarker(scaffoldContext),
          child: const Icon(Icons.add_location_alt),
        ),
      ],
    );
  }

  void _showLegendSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Legenda do Mapa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: Colors.red,
                  text: 'Marcador vermelho: comporta fechada',
                ),
                _buildLegendItem(
                  color: Colors.blue,
                  text: 'Marcador azul: comporta aberta',
                ),
                _buildLegendItem(
                  color: Colors.green,
                  text: 'pH entre 6.0 e 8.0: faixa ideal',
                ),
                _buildLegendItem(
                  color: Colors.orange,
                  text: 'pH fora da faixa: requer atencao',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem({required Color color, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  void _showRecentAlertsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Alertas Recentes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_recentAlerts.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _recentAlerts.clear();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Limpar'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_recentAlerts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Sem alertas ainda. Eles aparecerao aqui conforme eventos forem detectados.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _recentAlerts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final alert = _recentAlerts[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.notifications_active),
                          title: Text(alert),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // MODIFICADO: Atribui a GlobalKey ao MaterialApp
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Rice Monitor'),
              elevation: 2,
              actions: [
                PopupMenuButton<MapType>(
                  tooltip: 'Tipo de mapa',
                  icon: const Icon(Icons.layers_outlined),
                  onSelected: (selectedType) {
                    setState(() {
                      _mapType = selectedType;
                    });
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: MapType.satellite,
                      child: Text('Satelite'),
                    ),
                    PopupMenuItem(
                      value: MapType.hybrid,
                      child: Text('Hibrido'),
                    ),
                    PopupMenuItem(value: MapType.normal, child: Text('Normal')),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: _showRecentAlertsSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Sair da sessao'),
                          content: const Text(
                            'Deseja realmente sair e voltar para o login?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancelar'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text('Sair'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.dashboard),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DashboardScreen(
                          markersRef: database.ref('markers'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: Builder(
              builder: (scaffoldContext) {
                return Stack(
                  children: [
                    if (kIsWeb)
                      Positioned.fill(
                        child: fm.FlutterMap(
                          mapController: _webMapController,
                          options: fm.MapOptions(
                            initialCenter: _webCenter,
                            initialZoom: 15,
                            onTap: (_, __) {
                              _customInfoWindowController.hideInfoWindow
                                  ?.call();
                            },
                          ),
                          children: [
                            fm.TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.amboni.flutterApplication1',
                            ),
                            fm.MarkerLayer(markers: _buildWebMarkers()),
                          ],
                        ),
                      )
                    else
                      GoogleMap(
                        onMapCreated: (controller) {
                          mapController = controller;
                          _customInfoWindowController.googleMapController =
                              controller;
                          _isMapCreated = true;
                          _tryCenterMapOnFirstMarker();
                        },
                        onTap: (_) {
                          _customInfoWindowController.hideInfoWindow?.call();
                        },
                        onCameraMove: (_) {
                          _customInfoWindowController.onCameraMove?.call();
                        },
                        markers: markers
                            .map(
                              (m) => _buildMarker(
                                m.position,
                                m.markerId.value,
                                scaffoldContext,
                              ),
                            )
                            .toSet(),
                        initialCameraPosition: CameraPosition(
                          target: _center,
                          zoom: 15.0,
                        ),
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        mapType: _mapType,
                      ),
                    if (!kIsWeb)
                      CustomInfoWindow(
                        controller: _customInfoWindowController,
                        height: 130,
                        width: 260,
                        offset: 40,
                      ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _buildTopStatusPanel(),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 20,
                      child: _buildMapQuickActions(scaffoldContext),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
