import 'package:flutter/material.dart';

class MarkerDetailsScreen extends StatelessWidget {
  final String markerId;
  final Map<String, dynamic> markerData;

  const MarkerDetailsScreen({
    Key? key,
    required this.markerId,
    required this.markerData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Details for $markerId')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Water Level: ${markerData['waterlevel']}%'),
            Text('Flow Rate: ${markerData['humidity']}%'),
            Text(
              'Gate Status: ${markerData['isGateOpen'] ? 'Open' : 'Closed'}',
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                // Add logic to toggle gate status
              },
              child: Text(
                markerData['isGateOpen'] ? 'Close Gate' : 'Open Gate',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const SimpleBarChart({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BarChartPainter(values, labels),
      child: Container(),
    );
  }
}

class BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;

  BarChartPainter(this.values, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue;
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final barWidth = size.width / (values.length * 2);

    for (int i = 0; i < values.length; i++) {
      final x = (i * 2 + 1) * barWidth;
      final y = size.height * (1 - values[i] / 100);
      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, size.height - y), paint);

      // Draw labels
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(fontSize: 10, color: Colors.black),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x, size.height - 12));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
