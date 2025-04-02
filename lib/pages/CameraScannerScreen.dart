import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:peekblock/services/ble_service.dart';
import 'package:peekblock/pages/SignalStrengthScreen.dart';
import 'package:peekblock/pages/ScanHistoryScreen.dart';
import 'package:peekblock/pages/EditProfileScreen.dart';
import 'package:peekblock/pages/LoginScreen.dart';
import 'dart:async';

class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({Key? key}) : super(key: key);

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen>
    with TickerProviderStateMixin {
  final BLEService _ble = BLEService();
  bool _isScanning = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  final List<Map<String, dynamic>> _devices = [];
  String _statusMessage = "Initializing...";
  late final AnimationController _animationController;

  StreamSubscription<Map<String, dynamic>>? _dataSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<String>? _logSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _initBLE();
  }

  Future<void> _initBLE() async {
    try {
      setState(() {
        _statusMessage = "Initializing BLE...";
      });

      await _ble.initialize();

      _connectionSubscription = _ble.connectionStream.listen((connected) {
        if (mounted) {
          setState(() {
            _isConnected = connected;
            _statusMessage = connected ? "Connected" : "Disconnected";
          });
        }
      });

      _dataSubscription = _ble.dataStream.listen(_handleDeviceData);
      _logSubscription = _ble.logs.listen((log) => debugPrint("BLE Log: $log"));

      setState(() {
        _statusMessage = "Ready to scan";
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "BLE initialization error: ${e.toString()}";
        });
      }
    }
  }

  void _handleDeviceData(Map<String, dynamic> data) {
    if (!mounted || !_isScanning || !data.containsKey("mac")) return;

    try {
      if (data["mac"] == null || data["rssi"] == null) {
        throw FormatException("Missing required device fields");
      }

      setState(() {
        final index = _devices.indexWhere(
          (device) => device["mac"] == data["mac"],
        );
        if (index >= 0) {
          _devices[index] = data;
        } else {
          _devices.add(data);
        }
      });
    } catch (e) {
      debugPrint("Error handling device data: $e");
    }
  }

  Future<void> _startScan() async {
    if (!mounted || _isScanning) return;

    setState(() {
      _isConnecting = true;
      _statusMessage = "Preparing scan...";
      _devices.clear();
    });

    try {
      if (!_ble.isFullyConnected) {
        await _ble.connect();
      }

      setState(() {
        _isScanning = true;
        _statusMessage = "Scanning...";
      });

      await _ble.startScan();
      _animationController.repeat();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error: ${e.toString()}";
          _isScanning = false;
          _animationController.stop();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Scan failed: ${e.toString()}")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _stopScan() async {
    if (!mounted || !_isScanning) return;

    try {
      await _ble.stopScan();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error stopping scan: ${e.toString()}")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = "Scan stopped";
          _animationController.stop();
        });
      }
    }
  }

  void _navigateToScanHistory() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ScanHistoryScreen()),
    );
  }

  void _navigateToEditProfile() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfileScreen()),
    );
  }

  void _logout() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Logged out successfully")));
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    _logSubscription?.cancel();
    _ble.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("PEEKBLOCK"),
        backgroundColor: const Color.fromARGB(255, 124, 123, 123),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              _isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: _isConnected ? Colors.tealAccent : Colors.red,
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.grey[850],
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 124, 123, 123),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PEEKBLOCK',
                      style: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Status: ${_isConnected ? "Connected" : "Disconnected"}',
                      style: TextStyle(
                        color: _isConnected ? Colors.tealAccent : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  'Edit Profile',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: _navigateToEditProfile,
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.white),
                title: const Text(
                  'Scan History',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: _navigateToScanHistory,
              ),
              const Divider(color: Colors.white38),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            width: double.infinity,
            color: Colors.grey[850],
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          if (_isScanning)
            Lottie.asset(
              'lib/assets/animations/scan_animation.json',
              controller: _animationController,
              onLoaded: (composition) {
                _animationController.duration = composition.duration;
                if (_isScanning) {
                  _animationController.repeat();
                }
              },
              width: 200,
              height: 200,
            ),
          if (!_isScanning && !_isConnecting && _devices.isEmpty)
            Lottie.asset(
              'lib/assets/animations/scan.json',
              width: 200,
              height: 200,
            ),
          Expanded(
            child:
                _devices.isEmpty
                    ? Center(
                      child: Text(
                        "No devices found",
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _devices.length,
                      itemBuilder:
                          (context, index) => _DeviceCard(
                            device: _devices[index],
                            onTap: () {
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => SignalStrengthScreen(
                                        mac: _devices[index]["mac"],
                                      ),
                                ),
                              );
                            },
                          ),
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed:
                  _isConnecting ? null : (_isScanning ? _stopScan : _startScan),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isConnected
                        ? (_isScanning ? Colors.red : Colors.teal)
                        : Colors.grey,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 32,
                ),
              ),
              child: Text(
                _isConnecting
                    ? "Connecting..."
                    : _isScanning
                    ? "Stop Scanning"
                    : "Start Scanning",
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget statusIcon;
    String statusText = "";
    Color statusColor = Colors.grey;

    if (device["isCameraActive"] == true) {
      statusIcon = const Icon(Icons.videocam, color: Colors.red);
      statusText = "Camera detected!";
      statusColor = Colors.red;
    } else if (device["isCameraSuspicious"] == true) {
      statusIcon = const Icon(Icons.warning, color: Colors.amber);
      statusText = "Suspicious device";
      statusColor = Colors.amber;
    } else {
      statusIcon = const Icon(Icons.check_circle, color: Colors.green);
      statusText = "Safe device";
      statusColor = Colors.green;
    }

    String portsInfo = "";
    if (device.containsKey("openPorts") && device["openPorts"] is List) {
      final List ports = device["openPorts"] as List;
      if (ports.isNotEmpty) {
        portsInfo = "Ports: ${ports.join(', ')}";
      }
    }

    return Card(
      color: Colors.grey[800],
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          device["mac"] ?? "Unknown MAC",
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Vendor: ${device["vendor"] ?? "Unknown"}\nRSSI: ${device["rssi"] ?? "N/A"}",
              style: const TextStyle(color: Colors.white70),
            ),
            if (portsInfo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  portsInfo,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            if (statusText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: statusIcon,
        onTap: onTap,
      ),
    );
  }
}
