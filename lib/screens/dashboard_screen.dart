import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  final Map<String, Map<String, dynamic>> markersState;

  const DashboardScreen({super.key, required this.markersState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView.builder(
        itemCount: markersState.length,
        itemBuilder: (context, index) {
          final markerId = markersState.keys.elementAt(index);
          final markerData = markersState[markerId]!;
          return Card(
            child: ListTile(
              title: Text('Marker: $markerId'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Water Level: ${markerData['waterlevel']}%'),
                  Text('Soil Humidity: ${markerData['humidity']}%'),
                  Text('Water Flow: ${markerData['waterFlow']}%'),
                  Text('Water Ph: ${markerData['ph']}%'),
                  Text(
                    'Gate Status: ${markerData['isGateOpen'] ? 'Open' : 'Closed'}',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
