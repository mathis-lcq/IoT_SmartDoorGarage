#include <WiFi.h>           
#include <WebServer.h>
#include <EEPROM.h>
#include <ArduinoJson.h>    // Installer via Wokwi Libraries
#include <PubSubClient.h>   // Installer via Wokwi Libraries

WiFiClient espClient;
PubSubClient mqtt(espClient);

// Stockage des PINs en EEPROM
#define EEPROM_PIN_START 100
#define MAX_PINS 10
String validPins[MAX_PINS];
int pinCount = 0;

// MQTT Configuration
const char* mqtt_server = "broker.hivemq.com";
const int mqtt_port = 1883;
const char* topic_command = "smart_garage/command";
const char* topic_status = "smart_garage/status";
const char* topic_logs = "smart_garage/logs";
const char* topic_pins = "smart_garage/pins";

// ==================== CONFIGURATION ====================
#define DEVICE_NAME "SmartGarage_01"
#define WIFI_SSID "Wokwi-GUEST"
#define WIFI_PASSWORD ""

// Pin Definitions (ESP32 GPIO)
#define LED_DOOR 26        // GPIO2 - LED simulating door motor
#define LED_STATUS 27      // GPIO4 - Status LED
#define BUTTON_MANUAL 18   // GPIO5 - Manual override button

// Door States
enum DoorState { DOOR_CLOSED = 0, DOOR_OPENING, DOOR_OPEN, DOOR_CLOSING, DOOR_ERROR };

// ==================== GLOBAL VARIABLES ====================
WebServer server(80);
DoorState currentDoorState = DOOR_CLOSED;

// ==================== CORE FUNCTIONS ====================
void setup() {
  Serial.begin(9600);
  delay(1000);
  Serial.println("\nSmart Garage Door System (ESP32)");

  // Initialize pins
  pinMode(LED_DOOR, OUTPUT);
  pinMode(LED_STATUS, OUTPUT);
  pinMode(BUTTON_MANUAL, INPUT_PULLUP);

  digitalWrite(LED_DOOR, LOW);
  digitalWrite(LED_STATUS, LOW);

  delay(1000);
  Serial.println("Connecting WiFi...");
  setupWiFi();

  // MQTT
  mqtt.setServer(mqtt_server, mqtt_port);
  mqtt.setCallback(onMqttMessage);

  // PINs
  loadPinsFromEEPROM();
  mqtt.subscribe(topic_pins);
  publishPins();

  Serial.println("System Ready!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

void loop() {
  if (!mqtt.connected()) reconnectMQTT();
  mqtt.loop();

  // Check manual button
  if (digitalRead(BUTTON_MANUAL) == LOW) {
    delay(50);
    if (digitalRead(BUTTON_MANUAL) == LOW) {
      String source = "Home"; 
      String type = "Manual";
      toggleDoor(source, type);
      while (digitalRead(BUTTON_MANUAL) == LOW);
    }
  }

  server.handleClient();
}

void reconnectMQTT() {
  while (!mqtt.connected()) {
    while (WiFi.status() != WL_CONNECTED) setupWiFi();
    Serial.println("Connecting to MQTT...");
    if (mqtt.connect("ESP32_Garage")) {
      Serial.println("connected");
      mqtt.subscribe(topic_command);
      publishStatus();
    } else {
      delay(5000);
    }
  }
}

// ==================== MQTT CALLBACK ====================
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) message += (char)payload[i];
  Serial.println("MQTT: " + message);

  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, message);
  if (error) {
    Serial.print("Erreur JSON: "); Serial.println(error.c_str());
    return;
  }

  if (String(topic) == topic_pins) {
    JsonArray pinsArray = doc["pins"];
    if (pinsArray) {
      pinCount = 0;
      for (JsonVariant pin : pinsArray) if (pinCount < MAX_PINS) validPins[pinCount++] = pin.as<String>();
      savePinsToEEPROM();
      Serial.print("PINs synchronisés: "); Serial.println(pinCount);
    }
    return;
  }

  String command = doc["command"];
  String source = doc["source"];
  String type = doc["type"];
  if (command == "open") openDoor(source, type);
  else if (command == "close") closeDoor(source, type);
  else if (command == "toggle") toggleDoor(source, type);
  else if (command == "get_status") publishStatus();
  else Serial.println("Commande inconnue");
}

// ==================== WIFI SETUP ====================
void setupWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    digitalWrite(LED_STATUS, !digitalRead(LED_STATUS));
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP: "); Serial.println(WiFi.localIP());
    digitalWrite(LED_STATUS, HIGH);
  } else {
    Serial.println("\nWiFi Failed!");
    digitalWrite(LED_STATUS, LOW);
  }
}

// ==================== DOOR CONTROL ====================
void openDoor(String source, String type) {
  if (currentDoorState == DOOR_OPEN) return;
  Serial.println("Opening door: " + source);
  currentDoorState = DOOR_OPENING;

  for (int i = 0; i < 5; i++) {
    digitalWrite(LED_DOOR, HIGH); delay(200);
    digitalWrite(LED_DOOR, LOW); delay(200);
  }

  digitalWrite(LED_DOOR, HIGH);
  currentDoorState = DOOR_OPEN;
  publishStatus();
  publishLog(source, type, "Door opened");
}

void closeDoor(String source, String type) {
  if (currentDoorState == DOOR_CLOSED) return;
  Serial.println("Closing door: " + source);
  currentDoorState = DOOR_CLOSING;

  for (int i = 0; i < 5; i++) {
    digitalWrite(LED_DOOR, LOW); delay(200);
    digitalWrite(LED_DOOR, HIGH); delay(200);
  }

  digitalWrite(LED_DOOR, LOW);
  currentDoorState = DOOR_CLOSED;
  publishStatus();
  publishLog(source, type, "Door closed");
}

void toggleDoor(String source, String type) {
  if (currentDoorState == DOOR_OPEN || currentDoorState == DOOR_OPENING) closeDoor(source, type);
  else openDoor(source, type);
  publishStatus();
}

// ==================== PIN STORAGE ====================
void loadPinsFromEEPROM() {
  EEPROM.begin(512);
  pinCount = EEPROM.read(EEPROM_PIN_START);
  if (pinCount > MAX_PINS) pinCount = 0;

  for (int i = 0; i < pinCount; i++) {
    char pin[7] = {0};
    for (int j = 0; j < 6; j++) pin[j] = EEPROM.read(EEPROM_PIN_START + 1 + (i*6) + j);
    validPins[i] = String(pin);
  }
  EEPROM.end();
}

void savePinsToEEPROM() {
  EEPROM.begin(512);
  EEPROM.write(EEPROM_PIN_START, pinCount);
  for (int i = 0; i < pinCount; i++)
    for (int j = 0; j < 6; j++)
      EEPROM.write(EEPROM_PIN_START + 1 + (i*6) + j, validPins[i][j]);
  EEPROM.commit();
  EEPROM.end();
}

void publishPins() {
  StaticJsonDocument<500> doc;
  JsonArray pinsArray = doc.createNestedArray("pins");
  for (int i = 0; i < pinCount; i++) pinsArray.add(validPins[i]);
  String output;
  serializeJson(doc, output);
  mqtt.publish(topic_pins, output.c_str(), true);
}

// ==================== LOGS ====================
void publishLog(String source, String type, const char* message) {
  StaticJsonDocument<200> doc;
  doc["message"] = message;
  doc["source"] = source;
  doc["type"] = type;
  doc["timestamp"] = millis();
  String output;
  serializeJson(doc, output);
  mqtt.publish(topic_logs, output.c_str());
}

void publishStatus() {
  StaticJsonDocument<200> doc;
  doc["status"] = currentDoorState == DOOR_OPEN ? "open" : "closed";
  String output;
  serializeJson(doc, output);
  mqtt.publish(topic_status, output.c_str());
}
