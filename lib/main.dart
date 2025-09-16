import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
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
  final LatLng _center = const LatLng(-28.813556, -49.341167);

  // Lista de markers
  Set<Marker> markers = {};

  // Referências ao Firebase
  final DatabaseReference gateStatusRef = database.ref('gateStatus');
  final DatabaseReference humidityRef = database.ref('humidity');
  final DatabaseReference waterLevelRef = database.ref('waterLevel');

  @override
  void initState() {
    super.initState();
    markersState = {};
    _readGateStatus();
    _readHumidity();
    _readWaterLevel();

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
                    'isGateOpen': markerData['isGateOpen'] ?? false,
                  };
                  markers.add(_buildMarker(position, key, context));
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
                      'isGateOpen': false,
                    })
                    .then((_) => print('Marker $markerId added to Firebase'))
                    .catchError(
                      (error) => print('Failed to add marker: $error'),
                    );
              }
            });
          })
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
    _readMarkerData(markerId); // Ler dados do marker específico
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Details for $markerId',
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  const Icon(Icons.water_drop, color: Colors.blue),
                  const SizedBox(width: 8.0),
                  Text('Ph: ${markersState[markerId]?['humidity'] ?? 0}%'),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  const Icon(Icons.layers, color: Colors.green),
                  const SizedBox(width: 8.0),
                  Text(
                    'Water Level: ${markersState[markerId]?['waterlevel'] ?? 0}%',
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Gate Status:', style: TextStyle(fontSize: 16.0)),
                  Switch(
                    value: markersState[markerId]?['isGateOpen'] ?? false,
                    onChanged: (value) {
                      toggleGate(markerId, value);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

  void _readGateStatus() {
    gateStatusRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data.containsKey('isGateOpen')) {
        setState(() {
          // This is no longer used as isGateOpen is now per marker
        });
      }
    });
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
            'isGateOpen': false,
          })
          .then((_) => print('Marker $markerId added to Firebase'))
          .catchError((error) => print('Failed to add marker: $error'));
    });
  }

  void _readMarkerData(String markerId) {
    database.ref('markers/$markerId').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          markersState[markerId] = {
            'humidity': data['humidity'] ?? 0,
            'waterlevel': data['waterlevel'] ?? 0,
            'isGateOpen': data['isGateOpen'] ?? false,
          };
        });
      }
    });
  }

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
          // Enviar notificação para exemplo
          if (waterLevelValue > 80) {
            _sendLocalNotification(
              'Atenção',
              'Nível de água alto no $markerId!',
            );
          }
          if (humidityValue < 20) {
            _sendLocalNotification('Atenção', 'Umidade baixa no $markerId!');
          }
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

  void _sendLocalNotification(String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title: $body'), duration: Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green[700]),
      home: Scaffold(
        appBar: AppBar(title: const Text('TCC'), elevation: 2),
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
      ),
    );
  }
}
