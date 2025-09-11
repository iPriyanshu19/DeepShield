import 'package:flutter/material.dart';
import 'dart:convert';

class ResultScreen extends StatelessWidget {
  final String resultJson;

  const ResultScreen({super.key, required this.resultJson});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> result = {};
    try {
      result = json.decode(resultJson);
    } catch (e) {
      result = {
        'output': 'Error decoding result',
        'confidence': 0,
        'processing_time': 'N/A',
      };
    }
    final String output = result['output']?.toString() ?? '';
    final double confidence =
        double.tryParse(result['confidence']?.toString() ?? '') ?? 0.0;
    final String processingTime = result['processing_time']?.toString() ?? '';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Detection Result'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                output,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: output == 'FAKE' ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Confidence: ${confidence.toStringAsFixed(2)}%',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Processing Time: $processingTime s',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
