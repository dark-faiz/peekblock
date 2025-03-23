import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lottie/lottie.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool isScanning = false;
  bool scanComplete = false;
  bool isConnectedToESP = false;
  List<Map<String, dynamic>> detectedDevices = [];

  final String espIp = "192.168.4.1"; // Change if ESP has a different IP

  /// ✅ Check if connected to ESP Wi-Fi
  Future<void> checkWiFiConnection() async {
    try {
      final response = await http.get(Uri.parse("http://$espIp/status"));
      if (response.statusCode == 200) {
        setState(() {
          isConnectedToESP = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connected to ESP Wi-Fi!")),
        );
      }
    } catch (e) {
      setState(() {
        isConnectedToESP = false;
      });
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                "Connection Failed",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/failed_animation.json',
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Could not connect to ESP. Please check your Wi-Fi connection.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("OK", style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
      );
    }
  }

  /// ✅ Start scanning when ESP is connected
  Future<void> startScan() async {
    if (!isConnectedToESP) {
      _showNotConnectedAlert();
      return;
    }

    setState(() {
      isScanning = true;
      scanComplete = false;
    });

    try {
      final response = await http.get(Uri.parse("http://$espIp/scan"));
      if (response.statusCode == 200) {
        List<dynamic> devices = json.decode(response.body);

        setState(() {
          detectedDevices =
              devices.map((device) {
                return {
                  "mac": device["mac"],
                  "rssi": device["rssi"],
                  "timestamp": device["timestamp"],
                };
              }).toList();
          scanComplete = true;
        });
      }
    } catch (e) {
      print("Error fetching scan results: $e");
    }

    setState(() {
      isScanning = false;
    });
  }

  /// Show alert if not connected to ESP Wi-Fi
  void _showNotConnectedAlert() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              "Not Connected",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "Please connect to the ESP Wi-Fi first.",
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("OK", style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // ✅ Dark mode enabled
      appBar: AppBar(
        title: const Text("Wi-Fi Camera Scanner"),
        backgroundColor: Colors.grey[900],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: checkWiFiConnection,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: Text(
              isConnectedToESP
                  ? "Connected to Scanner"
                  : "Check ESP Connection",
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: isScanning ? null : startScan,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child:
                isScanning
                    ? const Text("Scanning...")
                    : const Text("Start Scanning"),
          ),
          const SizedBox(height: 20),
          Expanded(
            child:
                isScanning
                    ? Center(
                      child: Lottie.asset(
                        'assets/animations/scan_animation.json',
                        width: 200,
                        height: 200,
                      ),
                    )
                    : detectedDevices.isEmpty && scanComplete
                    ? Center(
                      child: Lottie.asset(
                        'assets/animations/success_animation.json',
                        width: 200,
                        height: 200,
                      ),
                    )
                    : ListView.builder(
                      itemCount: detectedDevices.length,
                      itemBuilder: (context, index) {
                        var device = detectedDevices[index];
                        return Card(
                          color: Colors.grey[900], // ✅ Dark mode for cards
                          child: ListTile(
                            title: Text(
                              "MAC: ${device['mac']}",
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              "RSSI: ${device['rssi']} dBm",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
