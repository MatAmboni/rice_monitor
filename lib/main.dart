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

  // Referências ao Firebase
  final DatabaseReference gateStatusRef = database.ref('gateStatus');
  final DatabaseReference humidityRef = database.ref('humidity');
  final DatabaseReference waterLevelRef = database.ref('waterLevel');

  @override
  void initState() {
    super.initState();
    _readGateStatus(); // Ler o status inicial do portão
    _readHumidity(); // Ler o valor inicial da umidade
    _readWaterLevel(); // Ler o valor inicial do nível de água
  }

  void toggleGate() {
    setState(() {
      isGateOpen = !isGateOpen;
    });
    _writeGateStatus(isGateOpen);
  }

  void _writeGateStatus(bool status) {
    gateStatusRef
        .set({'isGateOpen': status})
        .then((_) {
          print('Gate status updated in Firebase');
        })
        .catchError((error) {
          print('Failed to update gate status: $error');
        });
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

  Set<Marker> _createMarkers(BuildContext context) {
    return {
      Marker(
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isGateOpen ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueRed,
        ),
        markerId: const MarkerId('target_location'),
        position: const LatLng(-28.813556, -49.341167),
        infoWindow: InfoWindow(
          title: 'Target Location',
          snippet: 'Tap for controls',
          onTap: () {
            showModalBottomSheet(
              context: context,
              builder: (BuildContext context) {
                return Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16.0),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Target Location Details',
                        style: TextStyle(
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
                          const Text(
                            'Gate Status:',
                            style: TextStyle(fontSize: 16.0),
                          ),
                          Switch(
                            value: isGateOpen,
                            onChanged: (value) {
                              toggleGate();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    };
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
              markers: _createMarkers(scaffoldContext),
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 15.0,
              ),
            );
          },
        ),
      ),
    );
  }
}
