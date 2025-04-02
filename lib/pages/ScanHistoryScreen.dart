import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ScanHistoryScreen extends StatefulWidget {
  @override
  _ScanHistoryScreenState createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  List<Map<String, dynamic>> _scanHistory = [];
  bool _isLoading = true;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _loadScanHistory();
  }

  Future<void> _loadScanHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = "";
      });

      final prefs = await SharedPreferences.getInstance();
      List<String>? history = prefs.getStringList("scan_history") ?? [];

      List<Map<String, dynamic>> parsedHistory = [];

      for (String entry in history) {
        try {
          Map<String, dynamic> data = jsonDecode(entry);
          parsedHistory.add(data);
        } catch (e) {
          debugPrint("Error decoding history entry: $e\n$entry");
          try {
            String fixedJson = _fixJsonFormat(entry);
            Map<String, dynamic> data = jsonDecode(fixedJson);
            parsedHistory.add(data);
          } catch (e2) {
            debugPrint("Failed to fix and parse entry: $e2");
            parsedHistory.add({
              "error": "Invalid entry",
              "raw_data":
                  entry.length > 50 ? "${entry.substring(0, 50)}..." : entry,
            });
          }
        }
      }

      setState(() {
        _scanHistory = parsedHistory.reversed.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load scan history: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  String _fixJsonFormat(String badJson) {
    // Step 1: Add quotes around property names
    String fixed = badJson.replaceAllMapped(
      RegExp(r'([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)(\s*:)'),
      (match) => '${match.group(1)}"${match.group(2)}"${match.group(3)}',
    );

    // Step 2: Replace single-quoted strings with double-quoted strings
    fixed = fixed.replaceAllMapped(
      RegExp(r":\s*'([^']*)'"),
      (match) => ': "${match.group(1)}"',
    );

    // Step 3: Handle values that aren't strings (numbers, booleans, arrays)
    fixed = fixed.replaceAllMapped(
      RegExp(r':\s*([a-zA-Z0-9._+-]+)(?=[,\]}])'),
      (match) {
        final value = match.group(1)!;
        // Don't quote numbers, booleans, or null
        if (double.tryParse(value) != null ||
            value == 'true' ||
            value == 'false' ||
            value == 'null') {
          return ': $value';
        }
        return ': "$value"';
      },
    );

    // Step 4: Handle array values
    fixed = fixed.replaceAllMapped(
      RegExp(r':\s*(\[[^\]]*\])'),
      (match) => ': ${match.group(1)}',
    );

    return fixed;
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Clear History"),
            content: Text("Are you sure you want to delete all scan history?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Clear", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("scan_history");
      setState(() {
        _scanHistory.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Scan history cleared"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Scan History"),
        backgroundColor: Colors.grey[850],
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _scanHistory.isEmpty ? null : _clearHistory,
            tooltip: "Clear History",
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadScanHistory,
            tooltip: "Refresh",
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.tealAccent));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadScanHistory,
                child: Text("Retry"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.tealAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_scanHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              "No scan history available",
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              "Scan some devices to see them here",
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _scanHistory.length,
      itemBuilder: (context, index) {
        final device = _scanHistory[index];

        if (device.containsKey("error")) {
          return _buildErrorCard(device);
        }

        return _buildDeviceCard(device);
      },
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    Widget statusIcon;
    String statusText = "";
    Color statusColor = Colors.grey;

    if (device["isCameraActive"] == true) {
      statusIcon = Icon(Icons.videocam, color: Colors.red);
      statusText = "Camera detected!";
      statusColor = Colors.red;
    } else if (device["isCameraSuspicious"] == true) {
      statusIcon = Icon(Icons.warning, color: Colors.amber);
      statusText = "Suspicious device";
      statusColor = Colors.amber;
    } else {
      statusIcon = Icon(Icons.check_circle, color: Colors.green);
      statusText = "Safe device";
      statusColor = Colors.green;
    }

    return Card(
      color: Colors.grey[800],
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          device["mac"] ?? "Unknown MAC",
          style: TextStyle(color: Colors.white),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Vendor: ${device["vendor"] ?? "Unknown"}\n"
              "RSSI: ${device["rssi"] ?? "N/A"}\n"
              "Time: ${_formatTimestamp(device["timestamp"])}",
              style: TextStyle(color: Colors.white70),
            ),
            if (device.containsKey("openPorts") &&
                device["openPorts"] is List &&
                (device["openPorts"] as List).isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  "Open ports: ${(device["openPorts"] as List).join(', ')}",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            if (statusText.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4),
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
        onTap: () => _showDeviceDetails(device),
      ),
    );
  }

  Widget _buildErrorCard(Map<String, dynamic> errorEntry) {
    return Card(
      color: Colors.grey[900],
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Icon(Icons.error_outline, color: Colors.orange),
        title: Text("Invalid entry", style: TextStyle(color: Colors.white)),
        subtitle: Text(
          errorEntry["raw_data"] ?? "Corrupted data",
          style: TextStyle(color: Colors.white54),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Unknown time";

    try {
      if (timestamp is int || timestamp is String) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          int.parse(timestamp.toString()),
        );
        return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
      }
    } catch (e) {
      debugPrint("Error formatting timestamp: $e");
    }
    return timestamp.toString();
  }

  void _showDeviceDetails(Map<String, dynamic> device) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Device Details"),
            backgroundColor: Colors.grey[850],
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow("MAC Address", device["mac"] ?? "Unknown"),
                  _buildDetailRow("Vendor", device["vendor"] ?? "Unknown"),
                  _buildDetailRow("RSSI", device["rssi"]?.toString() ?? "N/A"),
                  _buildDetailRow(
                    "Timestamp",
                    _formatTimestamp(device["timestamp"]),
                  ),
                  if (device.containsKey("openPorts") &&
                      device["openPorts"] is List)
                    _buildDetailRow(
                      "Open Ports",
                      (device["openPorts"] as List).join(', '),
                    ),
                  if (device.containsKey("ipAddress"))
                    _buildDetailRow("IP Address", device["ipAddress"]),
                  if (device.containsKey("hostname"))
                    _buildDetailRow("Hostname", device["hostname"]),
                  SizedBox(height: 16),
                  Text(
                    "Raw Data:",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(device),
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close"),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value, style: TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
