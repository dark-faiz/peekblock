import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:peekblock/services/camera_detection_service.dart';

class BLEService {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  // BLE Configuration
  static const String _serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String _characteristicUUID =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String _deviceName = "ESP_Camera_Detector";
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _scanTimeout = Duration(seconds: 15);
  static const int _maxRetries = 3;

  // BLE State
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _txCharacteristic;
  final StreamController<Map<String, dynamic>> _dataStream =
      StreamController.broadcast();
  final StreamController<bool> _connectionStream = StreamController.broadcast();
  final StreamController<String> _logStream = StreamController.broadcast();
  bool _initializing = false;
  bool _connecting = false;
  bool _isScanning = false; // Added scan state tracking
  int _connectionAttempts = 0;
  Completer<void>? _connectionCompleter;

  // Camera detection service
  final CameraDetectionService _cameraDetection = CameraDetectionService();

  // Public API
  Stream<Map<String, dynamic>> get dataStream => _dataStream.stream;
  Stream<bool> get connectionStream => _connectionStream.stream;
  Stream<String> get logs => _logStream.stream;
  bool get isConnected => _connectedDevice?.isConnected ?? false;
  bool get isFullyConnected => isConnected && _txCharacteristic != null;
  bool get isScanning => _isScanning; // Expose scan state

  Future<void> initialize() async {
    if (_initializing) {
      _log("Initialization already in progress");
      return;
    }

    _initializing = true;

    try {
      if (!await FlutterBluePlus.isAvailable) {
        throw "Bluetooth not available on this device";
      }

      await _handlePlatformPermissions();

      FlutterBluePlus.adapterState.listen((state) {
        _log("Bluetooth adapter state: $state");
        if (state == BluetoothAdapterState.off) {
          _connectionStream.add(false);
        }
      });

      _log("BLE Service initialized");
    } catch (e, stack) {
      _log("Initialization failed: $e\n$stack", isError: true);
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  Future<void> _handlePlatformPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _log("Checking Android permissions");
        try {
          await FlutterBluePlus.turnOn();
          _log("Bluetooth turned on or already on");
        } catch (e) {
          _log(
            "Couldn't turn on Bluetooth: $e - continuing anyway",
            isError: true,
          );
        }
      }
    } on PlatformException catch (e) {
      _log("Permission error: ${e.message}", isError: true);
      throw "Bluetooth permissions required";
    }
  }

  // New scan control methods
  Future<void> startScan() async {
    if (_isScanning) return;
    _isScanning = true;
    await sendCommand("scan");
    _log("Scan started");
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    await sendCommand("stop_scan");
    _log("Scan stopped");
  }

  Future<void> connect() async {
    if (isFullyConnected) {
      _log("Already fully connected");
      _connectionStream.add(true);
      return;
    }

    if (_connecting) {
      _log("Connection already in progress - waiting for it to complete");
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        try {
          await _connectionCompleter!.future.timeout(
            Duration(seconds: 10),
            onTimeout: () {
              _log("Timed out waiting for previous connection", isError: true);
              _connecting = false;
              if (!_connectionCompleter!.isCompleted) {
                _connectionCompleter!.completeError("Connection timeout");
              }
              throw "Connection timeout";
            },
          );
          if (isFullyConnected) {
            _log("Previous connection completed successfully");
            return;
          } else {
            _log("Previous connection didn't establish fully, retrying");
          }
        } catch (e) {
          _log("Error waiting for previous connection: $e", isError: true);
        }
      }
    }

    _connecting = true;
    _connectionAttempts = 0;
    _connectionCompleter = Completer<void>();

    try {
      while (_connectionAttempts < _maxRetries) {
        _connectionAttempts++;
        _log("Connection attempt ${_connectionAttempts}/${_maxRetries}");

        try {
          await _attemptConnection();
          if (!_connectionCompleter!.isCompleted) {
            _connectionCompleter!.complete();
          }
          return;
        } catch (e) {
          _log(
            "Connection attempt ${_connectionAttempts} failed: $e",
            isError: true,
          );

          if (_connectionAttempts >= _maxRetries) {
            throw "Failed after $_maxRetries connection attempts: $e";
          }

          await Future.delayed(Duration(seconds: 2));
        }
      }
    } catch (e, stack) {
      _log("Connection failed: $e\n$stack", isError: true);
      await disconnect();
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(e);
      }
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  Future<void> _attemptConnection() async {
    _log("Starting BLE scan for device: $_deviceName");

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    await FlutterBluePlus.startScan(timeout: _scanTimeout);
    _log("Waiting for scan results...");

    final completer = Completer<void>();
    late StreamSubscription scanSubscription;
    Timer timer = Timer(_connectionTimeout, () {
      if (!completer.isCompleted) {
        scanSubscription.cancel();
        completer.completeError("Connection timeout");
      }
    });

    scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) async {
        _log("Found ${results.length} devices in scan");
        for (final r in results) {
          if (r.device.localName.isNotEmpty) {
            _log(
              "Device: ${r.device.localName} [${r.device.id}], RSSI: ${r.rssi}",
            );
          }
        }

        for (final result in results) {
          if (result.device.localName == _deviceName) {
            _log(
              "Found target device: ${result.device.localName} [${result.device.id}]",
            );

            try {
              await FlutterBluePlus.stopScan();
              _connectedDevice = result.device;
              await _establishConnection();

              if (!completer.isCompleted) {
                completer.complete();
              }
            } catch (e) {
              _log("Error connecting to device: $e", isError: true);
              if (!completer.isCompleted) {
                completer.completeError(e);
              }
            }
            break;
          }
        }
      },
      onError: (e) {
        _log("Scan error: $e", isError: true);
        if (!completer.isCompleted) {
          completer.completeError("Scan error: $e");
        }
      },
    );

    try {
      await completer.future;
      _log("Device connection established");
    } finally {
      timer.cancel();
      await scanSubscription.cancel();
    }
  }

  Future<void> _establishConnection() async {
    if (_connectedDevice == null) {
      throw "No device selected for connection";
    }

    try {
      _log("Connecting to device: ${_connectedDevice!.localName}");

      bool isDeviceConnected = false;
      try {
        isDeviceConnected = await _connectedDevice!.isConnected;
      } catch (e) {
        _log("Error checking connection: $e", isError: true);
      }

      if (!isDeviceConnected) {
        _log("Initiating connection...");
        await _connectedDevice!.connect(
          autoConnect: false,
          timeout: _connectionTimeout,
        );
        await Future.delayed(Duration(milliseconds: 1000));
      } else {
        _log("Device already connected, skipping connect call");
      }

      _connectedDevice!.connectionState.listen((state) {
        final connected = state == BluetoothConnectionState.connected;
        _connectionStream.add(connected);
        _log("Connection state changed: $state");

        if (!connected) {
          _txCharacteristic = null;
        }
      });

      _log("Discovering services...");
      final services = await _connectedDevice!.discoverServices();
      await Future.delayed(Duration(milliseconds: 500));
      _log("Found ${services.length} services");

      BluetoothService? targetService;
      for (final service in services) {
        _log("Service: ${service.uuid}");
        if (service.uuid.toString().toLowerCase() ==
            _serviceUUID.toLowerCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw "Required service not found on device";
      }

      for (final characteristic in targetService.characteristics) {
        _log("Characteristic: ${characteristic.uuid}");
        if (characteristic.uuid.toString().toLowerCase() ==
            _characteristicUUID.toLowerCase()) {
          _txCharacteristic = characteristic;
          break;
        }
      }

      if (_txCharacteristic == null) {
        throw "Required characteristic not found on device";
      }

      _log("Setting up notifications...");
      await _txCharacteristic!.setNotifyValue(true);
      await Future.delayed(Duration(milliseconds: 500));
      _txCharacteristic!.onValueReceived.listen(_handleIncomingData);

      _connectionStream.add(true);
      _log("BLE connection fully established");
    } catch (e, stack) {
      _log("Connection error: $e\n$stack", isError: true);
      await disconnect();
      rethrow;
    }
  }

  Future<void> sendCommand(String command) async {
    try {
      if (!isFullyConnected) {
        _log(
          "Not fully connected - attempting to connect before sending command",
        );
        await disconnect();
        await Future.delayed(Duration(milliseconds: 500));
        await connect();
        await Future.delayed(Duration(milliseconds: 1000));

        if (_txCharacteristic == null) {
          throw "Characteristic not available after connection attempt";
        }
      }

      _log("Sending command: $command");
      await Future.delayed(Duration(milliseconds: 200));
      await _txCharacteristic!.write(
        utf8.encode(command),
        withoutResponse: false,
      );
      _log("Command sent successfully");
    } catch (e, stack) {
      _log("Command failed: $e\n$stack", isError: true);
      rethrow;
    }
  }

  void _handleIncomingData(List<int> data) {
    try {
      final rawData = utf8.decode(data);
      if (rawData.isEmpty) {
        _log("Received empty packet", isError: true);
        return;
      }

      _log("Received data: $rawData");

      try {
        final decoded = jsonDecode(rawData) as Map<String, dynamic>;

        if (decoded.containsKey("mac")) {
          _log("Received MAC data: ${decoded["mac"]}");
          _processMacData(decoded);
        } else if (decoded.containsKey("status")) {
          _log("Status update: ${decoded["status"]}");
          _dataStream.add(decoded);
        } else {
          _dataStream.add(decoded);
        }
      } on FormatException catch (e) {
        _log(
          "JSON Format Error: ${e.message}\nSource data: $rawData",
          isError: true,
        );
      }
    } catch (e, stack) {
      _log("Data handling error: $e\n$stack", isError: true);
    }
  }

  Future<void> _processMacData(Map<String, dynamic> deviceData) async {
    try {
      _dataStream.add(deviceData);
      final processedData = await _cameraDetection.checkDeviceIsCamera(
        deviceData,
      );
      _dataStream.add(processedData);

      final status =
          processedData["isCameraActive"]
              ? 'Active Camera'
              : (processedData["isCameraSuspicious"]
                  ? 'Suspicious Device'
                  : 'Not a Camera');

      _log("Processed device: ${processedData["mac"]}, Status: $status");
    } catch (e) {
      _log("Error processing MAC data: $e", isError: true);
    }
  }

  Future<void> disconnect() async {
    try {
      _log("Disconnecting...");

      if (_txCharacteristic != null) {
        try {
          await _txCharacteristic!.setNotifyValue(false);
        } catch (e) {
          _log("Error disabling notifications: $e", isError: true);
        }
      }

      if (_connectedDevice != null) {
        try {
          bool isConnected = false;
          try {
            isConnected = await _connectedDevice!.isConnected;
          } catch (e) {
            _log("Error checking connection status: $e", isError: true);
          }

          if (isConnected) {
            await _connectedDevice!.disconnect();
          }
        } catch (e) {
          _log("Error disconnecting: $e", isError: true);
        }
      }

      _connectedDevice = null;
      _txCharacteristic = null;
      _connectionStream.add(false);
      _log("Disconnected successfully");
    } catch (e, stack) {
      _log("Disconnection error: $e\n$stack", isError: true);
      rethrow;
    }
  }

  Future<void> dispose() async {
    await disconnect();
    if (!_dataStream.isClosed) await _dataStream.close();
    if (!_connectionStream.isClosed) await _connectionStream.close();
    if (!_logStream.isClosed) await _logStream.close();
  }

  void _log(String message, {bool isError = false}) {
    final entry = "[${DateTime.now()}] ${isError ? 'ERROR: ' : ''}$message";
    if (isError)
      debugPrint("BLE-ERR: $entry");
    else
      debugPrint("BLE: $entry");

    try {
      if (!_logStream.isClosed) _logStream.add(entry);
    } catch (e) {
      debugPrint("Error logging to stream: $e");
    }
  }
}
