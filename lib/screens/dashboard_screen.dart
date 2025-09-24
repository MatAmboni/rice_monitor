import 'package:flutter/material.dart';
import 'marker_details_screen.dart'; // Importar a nova tela

class DashboardScreen extends StatelessWidget {
  final Map<String, Map<String, dynamic>> markersState;

  const DashboardScreen({Key? key, required this.markersState})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    int totalMarkers = markersState.length;
    int openGates = markersState.values
        .where((marker) => marker['isGateOpen'] == true)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Nodes: $totalMarkers',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Open Gates: $openGates',
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: markersState.length,
                itemBuilder: (context, index) {
                  String markerKey = markersState.keys.elementAt(index);
                  Map<String, dynamic> marker = markersState[markerKey]!;
                  return Card(
                    child: ListTile(
                      title: Text(markerKey),
                      subtitle: Text(
                        'Gate Open: ${marker['isGateOpen'] == true ? "Yes" : "No"}',
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MarkerDetailsScreen(
                              markerKey: markerKey,
                              markerData: marker,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
