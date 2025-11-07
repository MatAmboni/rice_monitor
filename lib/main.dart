import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
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

class _MyAppState extends State<MyApp> {
  late GoogleMapController mapController;
  Map<String, Map<String, dynamic>> markersState = {};
  int humidity = 0;
  int waterlevel = 0;
  int waterflow = 0;
  int ph = 0;
  bool isGateOpen = false;
  final LatLng _center = const LatLng(-28.813556, -49.341167);

  // Lista de markers
  Set<Marker> markers = {};

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
                    'humidity': markerData['humidity'] ?? 0,
                    'waterlevel': markerData['waterlevel'] ?? 0,
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
              } else {
                final markerId = 'marker_0';
                markers.add(_buildMarker(_center, markerId, context));
                database
                    .ref('markers/$markerId')
                    .set({
                      'latitude': _center.latitude,
                      'longitude': _center.longitude,
                      'humidity': 0,
                      'waterlevel': 0,
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
              }
            });
          })
          // ignore: invalid_return_type_for_catch_error
          .catchError((error) => print('Failed to fetch markers: $error'));
    });
  }

  Marker _buildMarker(LatLng position, String id, BuildContext context) {
    return Marker(
      markerId: MarkerId(id),
      draggable: true,
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        markersState[id]?['isGateOpen'] == true
            ? BitmapDescriptor.hueBlue
            : BitmapDescriptor.hueRed,
      ),
      infoWindow: InfoWindow(
        title: 'Target Location',
        snippet: 'Tap for controls',
        onTap: () {
          // MODIFICADO: Não precisamos mais chamar _readMarkerData aqui
          // porque ele já está sendo chamado no initState para todos os marcadores.
          // O listener .onValue já garante que os dados estarão atualizados.
          _showMarkerDetails(context, id);
        },
      ),
      onDragEnd: (newPosition) {
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
            final waterLevelValue =
                (currentMarkerData['waterlevel'] ?? 0) as num;
            final availableWaterText = waterLevelValue == 1 ? 'Sim' : 'Não';
            final availableWaterColor = waterLevelValue == 1
                ? Colors.green
                : Colors.red;

            // 3. Lógica da Umidade (Seca/Úmida)
            final humidityValue = (currentMarkerData['humidity'] ?? 0) as num;
            final bool isHumid = humidityValue > 50;
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
                color: phIconColor.withOpacity(0.1),
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
                  Row(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16.0),
                          _buildInfoRow(
                            Icons.waves,
                            waterFlowColor,
                            'Fluxo de Água', // Traduzido
                            waterFlowText,
                          ),

                          _buildInfoRow(
                            Icons.layers,
                            availableWaterColor,
                            'Água Disponível', // Traduzido
                            availableWaterText,
                          ),

                          _buildInfoRow(
                            Icons.opacity,
                            humidityColor, // Cor dinâmica
                            'Umidade do Solo', // Traduzido
                            humidityText, // Texto dinâmico
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [const Spacer(), phStatusCircle],
                        ),
                      ),
                    ],
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
                    label: const Text('Remover Marcador'),
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
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12.0),
          Text('$label: ', style: const TextStyle(fontSize: 16)),
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
      markerState['humidity'] ?? 0,
      markerState['waterlevel'] ?? 0,
    );
  }

  void _readHumidity() {
    humidityRef.onValue.listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          humidity = data;
        });
      }
    });
  }

  void _readWaterLevel() {
    waterLevelRef.onValue.listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          waterlevel = data;
        });
      }
    });
  }

  void _readWaterFlow() {
    waterFlowRef.onValue.listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          waterflow = data;
        });
      }
    });
  }

  void _readWaterPh() {
    waterPHRef.onValue.listen((event) {
      final data = event.snapshot.value as int?;
      if (data != null) {
        setState(() {
          ph = data;
        });
      }
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
            'humidity': 0,
            'waterlevel': 0,
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
    database.ref('markers/$markerId').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final newMarkerData = {
          'humidity': data['humidity'] ?? 0,
          'waterlevel': data['waterlevel'] ?? 0,
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
    final oldWaterLevel = (oldData['waterlevel'] ?? -1) as num;
    final newWaterLevel = (newData['waterlevel'] ?? -1) as num;
    if (oldWaterLevel != newWaterLevel) {
      if (newWaterLevel == 0) {
        _sendLocalNotification(
          'Alerta de Nível da Água',
          'Nível de água baixo (indisponível) no $markerId!',
        );
      } else if (newWaterLevel == 1) {
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
    final oldHumidity = (oldData['humidity'] ?? -1) as num;
    final newHumidity = (newData['humidity'] ?? -1) as num;
    if (oldHumidity != newHumidity) {
      if (newHumidity < 40) {
        _sendLocalNotification(
          'Solo Seco',
          'A umidade do solo está baixa em $markerId ($newHumidity%).',
        );
      } else if (newHumidity >= 40 && newHumidity <= 70) {
        _sendLocalNotification(
          'Solo Úmido',
          'A umidade do solo está adequada em $markerId ($newHumidity%).',
        );
      } else if (newHumidity > 70) {
        _sendLocalNotification(
          'Solo Encharcado',
          'A umidade do solo está muito alta em $markerId ($newHumidity%).',
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
    int humidityValue,
    int waterLevelValue,
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
          setState(() {
            markers.removeWhere((marker) => marker.markerId.value == markerId);
            markersState.remove(markerId);
          });
        })
        .catchError((error) => print('Failed to remove marker: $error'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green[700]),
      // MODIFICADO: Atribui a GlobalKey ao MaterialApp
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Rice Monitor App'),
              elevation: 2,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
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
                return GoogleMap(
                  onMapCreated: (controller) => mapController = controller,
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
                  mapType: MapType.satellite,
                );
              },
            ),
            floatingActionButton: Builder(
              builder: (scaffoldContext) {
                return FloatingActionButton(
                  onPressed: () => _addNewMarker(scaffoldContext),
                  child: const Icon(Icons.add_location_alt),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
