import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:peekblock/services/esp_service.dart';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  _CameraScannerScreenState createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen> {
  bool isScanning = false;
  List<Map<String, dynamic>> scannedDevices = [];

  Future<void> startScan() async {
    setState(() {
      isScanning = true;
      scannedDevices = [];
    });

    print("Starting scan...");

    List<Map<String, dynamic>> devices = await ESPService.scanDevices();

    print("Received devices: $devices");

    await Future.delayed(const Duration(seconds: 5)); // Wait for animations

    setState(() {
      isScanning = false;
      scannedDevices = devices;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("WiFi Camera Scanner"),
        backgroundColor: Colors.grey[900],
      ),
      body: Column(
        children: [
          // **Animation while scanning**
          if (isScanning)
            Lottie.asset(
              'lib/assets/animations/scan_animation.json',
              width: 200,
              height: 200,
            ),

          // **No Devices Found Animation**
          if (!isScanning && scannedDevices.isEmpty)
            Lottie.asset(
              'lib/assets/animations/success_animation.json',
              width: 200,
              height: 200,
            ),

          // **List of Detected Devices**
          Expanded(
            child: ListView.builder(
              itemCount: scannedDevices.length,
              itemBuilder: (context, index) {
                var device = scannedDevices[index];
                return Card(
                  color: Colors.grey[800],
                  child: ListTile(
                    title: Text(
                      device["mac"],
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "Vendor: ${device["vendor"]}",
                      style: TextStyle(color: Colors.white70),
                    ),
                    trailing:
                        device["isCameraActive"]
                            ? const Icon(Icons.videocam, color: Colors.red)
                            : const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                  ),
                );
              },
            ),
          ),

          // **Scan Button**
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: startScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
              ),
              child: const Text(
                "Start Scanning",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
