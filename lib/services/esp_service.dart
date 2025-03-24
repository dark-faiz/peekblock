import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class ESPService {
  static const String espUrl =
      "http://192.168.45.65:3000/scan"; // Change to your local IP
  static const String macLookupUrl = "https://api.macvendors.com/";

  // Fetch devices from ESP
  static Future<List<Map<String, dynamic>>> scanDevices() async {
    try {
      final response = await http.get(Uri.parse(espUrl));

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> devices = List<Map<String, dynamic>>.from(
          jsonDecode(response.body),
        );

        for (var device in devices) {
          String mac = device["mac"];
          device["vendor"] = await checkMacVendor(mac);
          device["isCameraActive"] = await isCameraActive(mac);
        }

        return devices;
      } else {
        throw Exception("Failed to scan devices");
      }
    } catch (e) {
      print("Error connecting to ESP: $e");
      return [];
    }
  }

  // MAC Lookup to Identify Device Type
  static Future<String> checkMacVendor(String mac) async {
    try {
      final response = await http.get(Uri.parse(macLookupUrl + mac));

      if (response.statusCode == 200) {
        String vendor = response.body;
        print("Vendor for $mac: $vendor");
        return vendor;
      }
    } catch (e) {
      print("Error checking MAC vendor: $e");
    }
    return "Unknown";
  }

  // Port Scanning to Check Camera Activity
  static Future<bool> isCameraActive(String ip) async {
    List<int> cameraPorts = [554, 8554, 80, 8080]; // RTSP, HTTP, MJPEG

    for (int port in cameraPorts) {
      try {
        Socket socket = await Socket.connect(
          ip,
          port,
          timeout: Duration(seconds: 2),
        );
        socket.destroy();
        print("Device at $ip has port $port open (Possible Camera)");
        return true;
      } catch (e) {
        continue;
      }
    }
    return false;
  }
}
