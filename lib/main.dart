import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late GoogleMapController mapController;
  bool isGateOpen = false;
  final LatLng _center = const LatLng(-28.813556, -49.341167);

  void toggleGate() {
    setState(() {
      isGateOpen = !isGateOpen;
    });
  }

  Set<Marker> _createMarkers(BuildContext context) {
    return {
      Marker(
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
                        children: const [
                          Icon(Icons.water_drop, color: Colors.blue),
                          SizedBox(width: 8.0),
                          Text('Humidity: 50.0%'),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: const [
                          Icon(Icons.layers, color: Colors.green),
                          SizedBox(width: 8.0),
                          Text('Water Level: 2%'),
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
        appBar: AppBar(title: const Text('Maps Sample App'), elevation: 2),
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
