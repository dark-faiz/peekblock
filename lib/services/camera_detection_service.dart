import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CameraDetectionService {
  static final CameraDetectionService _instance =
      CameraDetectionService._internal();
  factory CameraDetectionService() => _instance;
  CameraDetectionService._internal();

  // Pre-defined list of known camera vendors
  final Set<String> _knownCameraVendors = {
    'hikvision',
    'dahua',
    'axis',
    'bosch',
    'hanwha',
    'pelco',
    'uniview',
    'vivotek',
    'honeywell',
    'panasonic',
    'sony',
    'canon',
    'trendnet',
    'foscam',
    'wyze',
    'reolink',
    'nest',
    'arlo',
    'lorex',
    'swann',
    'amcrest',
    'eufy',
    'd-link',
    'tp-link',
    'Shanghai Imilab Technology',
  };

  // Common camera streaming ports
  final Set<int> _commonCameraPorts = {
    80, // HTTP
    443, // HTTPS
    554, // RTSP
    1935, // RTMP
    8000, // Hikvision
    8080, // Alternative HTTP
    8443, // Alternative HTTPS
    8554, // Alternative RTSP
    37777, // Dahua
    34567, // Some Chinese IPC manufacturers
    7001, // Some IP camera streams
    9000, // Some DVR systems
    10554, // Extended RTSP
  };

  // MAC Lookup API endpoint
  final String _macLookupUrl = "https://api.macvendors.com/";

  // Cached vendor information
  final Map<String, String> _vendorCache = {};

  // Check if a device is a camera based on vendor and port scanning
  Future<Map<String, dynamic>> checkDeviceIsCamera(
    Map<String, dynamic> device,
  ) async {
    final String macAddress = device['mac'];
    String? vendor = device['vendor'];

    // If vendor is not provided, look it up
    if (vendor == null || vendor.isEmpty) {
      vendor = await _lookupVendor(macAddress);
      device['vendor'] = vendor ?? 'Unknown';
    }

    // Generate random ports for simulation (in a real impl, you'd actually scan these)
    final openPorts = await _simulatePortScan(macAddress);
    device['openPorts'] = openPorts;

    // Check if any open ports match common camera ports
    final hasCameraPorts = openPorts.any(
      (port) => _commonCameraPorts.contains(port),
    );

    // Check if vendor is a known camera vendor
    final isKnownCameraVendor =
        vendor != null &&
        _knownCameraVendors.any(
          (knownVendor) =>
              vendor!.toLowerCase().contains(knownVendor.toLowerCase()),
        );

    // Determine camera status
    if (isKnownCameraVendor && hasCameraPorts) {
      // Confirmed camera - red
      device['isCameraActive'] = true;
      device['cameraConfidence'] = 'high'; // 'high', 'medium', 'low'
    } else if (isKnownCameraVendor || hasCameraPorts) {
      // Suspicious - yellow
      device['isCameraActive'] = false;
      device['isCameraSuspicious'] = true;
      device['cameraConfidence'] = 'medium';
    } else {
      // Not a camera - green
      device['isCameraActive'] = false;
      device['isCameraSuspicious'] = false;
      device['cameraConfidence'] = 'low';
    }

    return device;
  }

  // Look up MAC vendor using API
  Future<String?> _lookupVendor(String macAddress) async {
    try {
      // Check cache first
      if (_vendorCache.containsKey(macAddress)) {
        return _vendorCache[macAddress];
      }

      // Format MAC address by removing any separators
      final formattedMac = macAddress.replaceAll(RegExp(r'[^A-Fa-f0-9]'), '');
      final firstSixChars = formattedMac.substring(
        0,
        min(6, formattedMac.length),
      );

      // Make API request
      final response = await http
          .get(Uri.parse(_macLookupUrl + firstSixChars))
          .timeout(Duration(seconds: 5));

      if (response.statusCode == 200) {
        final vendor = response.body.trim();
        // Cache the result
        _vendorCache[macAddress] = vendor;
        return vendor;
      } else {
        debugPrint('MAC lookup failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error during MAC lookup: $e');
      return null;
    }
  }

  // Simulate port scanning - in a real app, you'd implement actual port scanning
  // Note: Actual port scanning might require native code and has security implications
  Future<List<int>> _simulatePortScan(String macAddress) async {
    // In a real implementation, you'd use a native plugin to perform port scanning
    // This is just a simulation for demonstration purposes
    await Future.delayed(Duration(milliseconds: 500));

    // Generate a deterministic but pseudo-random set of open ports based on MAC address
    // This ensures same MAC always returns same ports in this simulation
    final Random random = Random(macAddress.hashCode);

    // Determine number of open ports (1-5)
    final numOpenPorts = random.nextInt(5) + 1;

    // Generate list of open ports
    List<int> openPorts = [];

    // 30% chance of having a common camera port
    if (random.nextDouble() < 0.3) {
      final List<int> commonPortsList = _commonCameraPorts.toList();
      openPorts.add(commonPortsList[random.nextInt(commonPortsList.length)]);
    }

    // Fill remaining ports with random ports
    while (openPorts.length < numOpenPorts) {
      final port =
          1024 + random.nextInt(64511); // Random port between 1024-65535
      if (!openPorts.contains(port)) {
        openPorts.add(port);
      }
    }

    return openPorts;
  }
}
