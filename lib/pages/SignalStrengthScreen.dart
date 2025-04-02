import 'package:flutter/material.dart';
import 'package:peekblock/services/ble_service.dart';
import 'dart:async'; // Add this import

class SignalStrengthScreen extends StatefulWidget {
  final String mac;
  const SignalStrengthScreen({required this.mac, Key? key}) : super(key: key);

  @override
  State<SignalStrengthScreen> createState() => _SignalStrengthScreenState();
}

class _SignalStrengthScreenState extends State<SignalStrengthScreen> {
  final BLEService _ble = BLEService();
  int _rssi = -100;
  bool _isConnected = false;
  final List<int> _rssiHistory = [];

  // Fixed declaration of StreamSubscriptions
  StreamSubscription<Map<String, dynamic>>? _dataSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    _connectionSubscription = _ble.connectionStream.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });

    _dataSubscription = _ble.dataStream.listen((data) {
      if (data["mac"] == widget.mac && data["rssi"] != null && mounted) {
        setState(() {
          _rssi = data["rssi"];
          _updateRssiHistory(_rssi);
        });
      }
    });

    await _ble.sendCommand("track:${widget.mac}");
  }

  void _updateRssiHistory(int rssi) {
    _rssiHistory.add(rssi);
    if (_rssiHistory.length > 20) _rssiHistory.removeAt(0);
  }

  double _getSmoothedRssi() {
    if (_rssiHistory.isEmpty) return _rssi.toDouble();
    return _rssiHistory.reduce((a, b) => a + b) / _rssiHistory.length;
  }

  double _getSignalStrength() {
    return ((_getSmoothedRssi() + 100) / 40).clamp(0.0, 1.0);
  }

  String _getDistanceText() {
    final rssi = _getSmoothedRssi();
    return rssi > -50
        ? "Very Close (0-2m)"
        : rssi > -65
        ? "Nearby (2-5m)"
        : rssi > -80
        ? "Far (5-10m)"
        : "Very Far (10m+)";
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final smoothedRssi =
        _rssiHistory.isEmpty ? _rssi : _getSmoothedRssi().round();
    final signalStrength = _getSignalStrength();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Tracking ${widget.mac}"),
        backgroundColor: Colors.grey[900],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isConnected ? "$smoothedRssi dBm" : "Disconnected",
              style: TextStyle(
                fontSize: 32,
                color: _isConnected ? Colors.tealAccent : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Vertical Signal Bar
            Container(
              width: 40,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 40,
                    height: 200 * signalStrength,
                    decoration: BoxDecoration(
                      color: Colors.tealAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _getDistanceText(),
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 30),
            Icon(
              Icons.location_searching,
              size: 60,
              color: Colors.tealAccent.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}
