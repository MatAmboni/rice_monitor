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
  bool isGateOpen = false;
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
    _readGateStatus();
    _readHumidity();
    _readWaterLevel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        final markerId = 'marker_0'; // ID único para o primeiro marker
        markers.add(_buildMarker(_center, markerId, context));

        // Salvar o primeiro marker no banco de dados
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
            .catchError((error) => print('Failed to add marker: $error'));
      });
    });
  }

  Marker _buildMarker(LatLng position, String id, BuildContext context) {
    return Marker(
      icon: BitmapDescriptor.defaultMarkerWithHue(
        isGateOpen ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueRed,
      ),
      markerId: MarkerId(id),
      draggable: true,
      position: position, // Mantém a posição atual do marker
      infoWindow: InfoWindow(
        title: 'Target Location',
        snippet: 'Tap for controls',
        onTap: () {
          _showMarkerDetails(context, id);
        },
      ),
      onDragEnd: (newPosition) {
        // Atualiza a posição do marker no banco de dados ao ser arrastado
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
          // Atualiza a posição local do marker
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
                  Text('Humidity: $humidity%'),
                ],
              ),
              const SizedBox(height: 8.0),
              Row(
                children: [
                  const Icon(Icons.layers, color: Colors.green),
                  const SizedBox(width: 8.0),
                  Text('Water Level: $waterlevel%'),
                ],
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Gate Status:', style: TextStyle(fontSize: 16.0)),
                  Switch(
                    value: isGateOpen,
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
    setState(() {
      isGateOpen = status;
    });
    _writeMarkerData(markerId, status, humidity, waterlevel);
  }

  void _readGateStatus() {
    gateStatusRef.onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null && data.containsKey('isGateOpen')) {
        setState(() {
          isGateOpen = data['isGateOpen'];
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
          humidity = data['humidity'] ?? 0;
          waterlevel = data['waterlevel'] ?? 0;
          isGateOpen = data['isGateOpen'] ?? false;
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
        .then((_) => print('Marker $markerId data updated in Firebase'))
        .catchError((error) => print('Failed to update marker data: $error'));
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
