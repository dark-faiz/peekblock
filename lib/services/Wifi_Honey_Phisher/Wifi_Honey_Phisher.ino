#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <WiFi.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define DEVICE_NAME         "ESP_Camera_Detector"

// Forward declarations
void handleScanCommand();
void sendBLEMessage(String message);

BLEServer* pServer;
BLEService* pService;
BLECharacteristic* pCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;
String currentMac = "";

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Device connected");
    }

    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Device disconnected");
        delay(500);
        pServer->startAdvertising();
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = "";
        if(pCharacteristic->getValue().length() > 0) {
            value = String((char*)pCharacteristic->getData());
            Serial.println("Received command: " + value);

            if (value.startsWith("track:")) {
                currentMac = value.substring(6);
                Serial.println("Tracking MAC: " + currentMac);
            } else if (value == "scan") {
                handleScanCommand();
            }
        }
    }
};

void sendBLEMessage(String message) {
    if (deviceConnected) {
        Serial.println("Sending: " + message);
        pCharacteristic->setValue(message.c_str());
        pCharacteristic->notify();
        delay(20);
    }
}

void handleScanCommand() {
    Serial.println("Starting WiFi scan...");
    WiFi.mode(WIFI_STA);
    WiFi.disconnect();
    delay(100);
    
    int numNetworks = WiFi.scanNetworks();
    Serial.println("Found " + String(numNetworks) + " networks");

    if (numNetworks == 0) {
        sendBLEMessage("{\"status\":\"no_networks\"}");
    } else {
        for (int i = 0; i < numNetworks; ++i) {
            String mac = WiFi.BSSIDstr(i);
            int rssi = WiFi.RSSI(i);
            int port = random(1024, 65535);

            String jsonData = "{\"mac\":\"" + mac + "\",\"rssi\":" + rssi + ",\"port\":" + port + "}";
            sendBLEMessage(jsonData);
            delay(100);
        }
    }
    
    WiFi.scanDelete();
    sendBLEMessage("{\"status\":\"scan_complete\"}");
    Serial.println("Scan completed");
}

void setup() {
    Serial.begin(115200);
    Serial.println("Starting BLE Camera Detector");
    
    BLEDevice::init(DEVICE_NAME);
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());
    
    pService = pServer->createService(SERVICE_UUID);
    
    pCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID,
                        BLECharacteristic::PROPERTY_READ |
                        BLECharacteristic::PROPERTY_WRITE |
                        BLECharacteristic::PROPERTY_NOTIFY
                      );
    
    pCharacteristic->setCallbacks(new MyCallbacks());
    pCharacteristic->addDescriptor(new BLE2902());
    
    pService->start();
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();
    
    Serial.println("BLE Server Ready. Advertising started.");
}

void loop() {
    if (deviceConnected && currentMac != "") {
        String response = "{\"mac\":\"" + currentMac + "\",\"rssi\":" + String(random(-40, -90)) + ",\"port\":" + String(random(1024, 65535)) + "}";
        sendBLEMessage(response);
        delay(1000);
    }
    
    if (deviceConnected != oldDeviceConnected) {
        oldDeviceConnected = deviceConnected;
        if (!deviceConnected) {
            delay(500);
            pServer->startAdvertising();
            Serial.println("Restarting advertising");
        }
    }
    
    delay(100);
}
