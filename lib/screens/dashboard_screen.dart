import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/hydraulic_analysis_screen.dart';
import 'marker_details_screen.dart'; // Importar a nova tela

class DashboardScreen extends StatelessWidget {
  final Map<String, Map<String, dynamic>> markersState;

  const DashboardScreen({Key? key, required this.markersState})
    : super(key: key);

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
                  Text('Flow Rate: ${markerData['humidity']}%'),
                  Text(
                    'Gate Status: ${markerData['isGateOpen'] ? 'Open' : 'Closed'}',
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.analytics),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          HydraulicAnalysisScreen(markerId: markerId),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
