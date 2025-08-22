#include <Arduino.h>
#include <BLEServer.h>
#include <BLEDevice.h>
#include <BLE2902.h>
#include <BLEDescriptor.h>
#include <Adafruit_NeoPixel.h>
#include <unordered_set>
#include <unordered_map>

#define LED_PIN D10
#define POWER_PIN D0
#define NUM_LEDS 132
#define BRIGHTNESS 255

Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

// Create color service and characteristics
#define COLOR_SERVICE_UUID "f9bbfc69-8184-4a4b-af62-f560441faf50"
#define SECURITY_SERVICE_UUID "8a6ff27e-42f7-487c-892d-d4276e2b9438"
#define PASSWORD "ba1109ee-352f-4c22-9c67-b9c5350a2dc8"

#define AUTHENTICATE_CHARACTERISTIC_UUID "e2ded851-c0dd-4dca-b607-2cb0631bc549"
#define COLOR_CHARACTERISTIC_UUID "6cb02075-6a70-4f34-a51f-15120e7e1e2f"
#define COLOR_PATTERN_CHARACTERISTIC_UUID "ac1d5ac2-1641-4a96-9297-73a3fda2a664"
#define PATTERN_RATE_CHARACTERISTIC_UUID "ac1d5ac2-1641-4a96-9297-73a3fda2a663"
#define RAINBOW_MODE_CHARACTERISTIC_UUID "ac1d5ac2-1641-4a96-9297-73a3fda2a665"

class DeviceSettings
{
public:
  static uint16_t const baseInterval = 50; // milliseconds
  uint8_t red;
  uint8_t green;
  uint8_t blue;
  uint16_t interval;
  String pattern;
  bool rainbow;

  std::unordered_map<uint16_t, unsigned long> *devicesPendingAuthentication;
  std::unordered_set<uint16_t> *authenticatedDeviceSet;
  DeviceSettings()
  {
    red = 0;
    green = 0;
    blue = 0;
    pattern = "flat";
    interval = 50; // milliseconds
    rainbow = false;
    devicesPendingAuthentication = new std::unordered_map<uint16_t, unsigned long>();
    authenticatedDeviceSet = new std::unordered_set<uint16_t>();
  }

  bool isAuthenticated(uint16_t connectionID)
  {
    return this->authenticatedDeviceSet->find(connectionID) != this->authenticatedDeviceSet->end();
  }

  int generateHexCode()
  {
    return (this->red << 16) | (this->green << 8) | this->blue;
  }

  int rainbowMode()
  {
    return this->rainbow ? 1 : 0;
  }
};

class ServerCallbacks : public BLEServerCallbacks
{
private:
  DeviceSettings *deviceSettings;

public:
  ServerCallbacks(DeviceSettings *deviceSettings)
  {
    this->deviceSettings = deviceSettings;
  };

  void onConnect(BLEServer *pServer)
  {
    // Add the device ID for authentication.
    this->deviceSettings->devicesPendingAuthentication->insert({pServer->getConnId(), millis()});

    pServer->startAdvertising();
    auto colorCharacteristic = pServer->getServiceByUUID(COLOR_SERVICE_UUID)
                                   ->getCharacteristic(COLOR_CHARACTERISTIC_UUID);

    // Notify the newly connected client of the current color setting.
    if (colorCharacteristic != nullptr)
    {
      int color = this->deviceSettings->generateHexCode();
      colorCharacteristic->setValue(color);
      colorCharacteristic->notify();
    }

    // Notify the newly connected client of the current rainbow mode setting.
    auto rainbowCharacteristic = pServer->getServiceByUUID(COLOR_SERVICE_UUID)
                                     ->getCharacteristic(RAINBOW_MODE_CHARACTERISTIC_UUID);
    if (rainbowCharacteristic != nullptr)
    {
      int rainbowValue = deviceSettings->rainbowMode();
      rainbowCharacteristic->setValue(rainbowValue);
      rainbowCharacteristic->notify();
    }

    // COLOR_PATTERN_CHARACTERISTIC_UUID
    auto patternCharacteristic = pServer->getServiceByUUID(COLOR_SERVICE_UUID)
                                     ->getCharacteristic(COLOR_PATTERN_CHARACTERISTIC_UUID);
    if (patternCharacteristic != nullptr)
    {
      String pattern = deviceSettings->pattern;
      patternCharacteristic->setValue(pattern);
      patternCharacteristic->notify();
    }

    // PATTERN_RATE_CHARACTERISTIC_UUID
    auto patternRateCharacteristic = pServer->getServiceByUUID(COLOR_SERVICE_UUID)
                                         ->getCharacteristic(PATTERN_RATE_CHARACTERISTIC_UUID);
    if (patternRateCharacteristic != nullptr)
    {
      auto interval = deviceSettings->interval;
      patternRateCharacteristic->setValue(interval);
      patternRateCharacteristic->notify();
    }

    Serial.println("Client connected");
    Serial.printf("Connected client count: %d\n", pServer->getConnectedCount());
  };

  void onDisconnect(BLEServer *pServer)
  {
    pServer->startAdvertising();

    auto connectionID = pServer->getConnId();
    this->deviceSettings->devicesPendingAuthentication->erase(connectionID);
    this->deviceSettings->authenticatedDeviceSet->erase(connectionID);

    Serial.println("Client disconnected");
  }
};

class AuthenticatedBLECharacteristicCallbacks : public BLECharacteristicCallbacks
{

protected:
  DeviceSettings *deviceSettings;
  BLEServer *pServer;

  AuthenticatedBLECharacteristicCallbacks(DeviceSettings *deviceSettings, BLEServer *pServer) : BLECharacteristicCallbacks()
  {
    this->deviceSettings = deviceSettings;
    this->pServer = pServer;
  }

  bool isAuthenticated()
  {
    return this->deviceSettings->isAuthenticated(this->pServer->getConnId());
  }

public:
  virtual ~AuthenticatedBLECharacteristicCallbacks() {}
  virtual void onWrite(BLECharacteristic *characteristic) = 0;
  virtual void onRead(BLECharacteristic *characteristic) = 0;
};

class RainbowModeCallbacks : public AuthenticatedBLECharacteristicCallbacks
{
private:
  DeviceSettings *deviceSettings;
  BLEServer *pServer;

public:
  RainbowModeCallbacks(DeviceSettings *deviceSettings, BLEServer *pServer) : AuthenticatedBLECharacteristicCallbacks(deviceSettings, pServer)
  {
    this->deviceSettings = deviceSettings;
    this->pServer = pServer;
  }

  void onWrite(BLECharacteristic *pCharacteristic) override
  {
    if (!this->isAuthenticated())
    {
      Serial.println("Unauthorized write attempt to rainbow mode characteristic.");
      return;
    }

    String value = pCharacteristic->getValue();

    if (value.length() > 0)
    {
      this->deviceSettings->rainbow = (value == "1");
      Serial.printf("Rainbow mode set to: %d\n", deviceSettings->rainbow ? 1 : 0);
    }
  }

  void onRead(BLECharacteristic *pCharacteristic) override
  {
    if (!this->isAuthenticated())
    {
      Serial.println("Unauthorized write attempt to rainbow mode characteristic.");
      return;
    }

    int rainbowValue = this->deviceSettings->rainbowMode();
    pCharacteristic->setValue(rainbowValue);
    Serial.printf("Rainbow mode read as: %d\n", rainbowValue);
  }
};

class AuthenticationCallbacks : public BLECharacteristicCallbacks
{
private:
  DeviceSettings *deviceSettings;
  BLEServer *pServer;

public:
  AuthenticationCallbacks(DeviceSettings *deviceSettings, BLEServer *pServer)
  {
    this->deviceSettings = deviceSettings;
    this->pServer = pServer;
  }

  void onWrite(BLECharacteristic *pCharacteristic) override
  {
    String value = pCharacteristic->getValue();

    auto connectionID = this->pServer->getConnId();

    Serial.printf("Attempting to authorize with password %s", value.c_str());

    if (value.length() > 0 && value == PASSWORD)
    {
      Serial.printf("Authentication successful for connection ID: %d\n", connectionID);
      this->deviceSettings->authenticatedDeviceSet->insert(connectionID);
      this->deviceSettings->devicesPendingAuthentication->erase(connectionID);
      pCharacteristic->setValue("OK");
      pCharacteristic->notify("OK");
    }
    else if (value == "OK")
    {
      return;
    }
    else
    {
      Serial.println("Authentication failed.");
      this->pServer->disconnect(connectionID);
      this->deviceSettings->authenticatedDeviceSet->erase(connectionID);
      this->deviceSettings->devicesPendingAuthentication->erase(connectionID);
    }
  }
};

class PatternCallbacks : public AuthenticatedBLECharacteristicCallbacks
{
private:
  DeviceSettings *deviceSettings;
  BLEServer *pServer;

public:
  PatternCallbacks(DeviceSettings *deviceSettings, BLEServer *pServer) : AuthenticatedBLECharacteristicCallbacks(deviceSettings, pServer)
  {
    this->deviceSettings = deviceSettings;
    this->pServer = pServer;
  }

  void onWrite(BLECharacteristic *pCharacteristic) override
  {
    if (!this->isAuthenticated())
    {
      Serial.println("Unauthorized write attempt to pattern characteristic.");
      return;
    }

    String value = pCharacteristic->getValue();

    if (value.length() > 0)
    {
      deviceSettings->pattern = value;
      Serial.printf("Pattern set to: %s\n", deviceSettings->pattern.c_str());
    }
  }

  void onRead(BLECharacteristic *pCharacteristic) override
  {
    if (!this->isAuthenticated())
    {
      Serial.println("Unauthorized read attempt to pattern characteristic.");
      return;
    }

    pCharacteristic->setValue(deviceSettings->pattern);
    Serial.printf("Pattern read as: %d\n", deviceSettings->pattern.c_str());
  }
};

class PatternRateCallbacks : public AuthenticatedBLECharacteristicCallbacks
{
private:
  DeviceSettings *deviceSettings;
  BLEServer *pServer;

public:
  PatternRateCallbacks(DeviceSettings *deviceSettings, BLEServer *pServer) : AuthenticatedBLECharacteristicCallbacks(deviceSettings, pServer)
  {
    this->deviceSettings = deviceSettings;
    this->pServer = pServer;
  }

  void onWrite(BLECharacteristic *pCharacteristic) override
  {
    if (!this->isAuthenticated())
    {
      Serial.println("Unauthorized write attempt to pattern rate characteristic.");
      return;
    }

    String value = pCharacteristic->getValue();

    if (value.length() == 8)
    {
      double receivedDouble;
      memcpy(&receivedDouble, value.c_str(), sizeof(double));
      this->deviceSettings->interval = static_cast<uint16_t>(receivedDouble * DeviceSettings::baseInterval);

      Serial.print("Received double: ");
      Serial.println(receivedDouble, 6);
    }
    else
    {
      Serial.println("Received data length mismatch!");
    }
  }

  void onRead(BLECharacteristic *pCharacteristic) override
  {
    if (!this->isAuthenticated())
    {
      Serial.println("Unauthorized read attempt to pattern rate characteristic.");
      return;
    }

    pCharacteristic->setValue(deviceSettings->interval);
    Serial.printf("Pattern rate read as: %i\n", deviceSettings->interval);
  }
};

class ColorCharacteristicCallbacks : public AuthenticatedBLECharacteristicCallbacks
{
private:
  DeviceSettings *deviceSettings;
  BLEServer *pServer;

public:
  ColorCharacteristicCallbacks(DeviceSettings *deviceSettings, BLEServer *pServer) : AuthenticatedBLECharacteristicCallbacks(deviceSettings, pServer)
  {
    this->deviceSettings = deviceSettings;
    this->pServer = pServer;
  }

  void onWrite(BLECharacteristic *pCharacteristic) override
  {
    if (!this->isAuthenticated())
    {
      Serial.println("Unauthorized write attempt to color characteristic.");
      return;
    }

    String value = pCharacteristic->getValue();
    if (value.length() == 3)
    {
      this->deviceSettings->red = (uint8_t)value[0];
      this->deviceSettings->green = (uint8_t)value[1];
      this->deviceSettings->blue = (uint8_t)value[2];
      Serial.printf("Color set to: R=%d, G=%d, B=%d\n", this->deviceSettings->red, this->deviceSettings->green, this->deviceSettings->blue);
    }
  }

  void onRead(BLECharacteristic *pCharacteristic) override
  {
    if (!this->isAuthenticated())
    {
      Serial.println("Unauthorized read attempt to color characteristic.");
      return;
    }

    uint8_t colorValue[3] = {this->deviceSettings->red, this->deviceSettings->green, this->deviceSettings->blue};
    pCharacteristic->setValue(colorValue, 3);
    Serial.printf("Color read as: R=%d, G=%d, B=%d\n", this->deviceSettings->red, this->deviceSettings->green, this->deviceSettings->blue);
  }
};

// PATTERNS
class Pattern
{
public:
  DeviceSettings *settings;
  virtual void update() = 0;
  virtual ~Pattern() {}
};

class FlatPattern : public Pattern
{
public:
  FlatPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    strip.fill(strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
  }
};

class GlowPattern : public Pattern
{
  unsigned long lastUpdate = 0;
  float brightness = 0;
  float step = 0.02;

public:
  GlowPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    brightness += step;
    if (brightness >= 1.0 || brightness <= 0.0)
      step = -step;
    strip.fill(strip.Color(
        uint8_t(floor(settings->red * brightness) - 1),
        uint8_t(floor(settings->green * brightness) - 1),
        uint8_t(floor(settings->blue * brightness) - 1)));
    strip.show();
  }
};

class PulsePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  float brightness = 0;
  float step = 0.05;

public:
  PulsePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    brightness += step;
    if (brightness >= 1.0 || brightness <= 0.0)
      step = -step;
    strip.fill(strip.Color(
        uint8_t(settings->red * brightness),
        uint8_t(settings->green * brightness),
        uint8_t(settings->blue * brightness)));
    strip.show();
  }
};

class StrobePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  bool on = false;

public:
  StrobePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    on = !on;
    strip.fill(on ? strip.Color(settings->red, settings->green, settings->blue)
                  : strip.Color(0, 0, 0));
    strip.show();
  }
};

class FadePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  float brightness = 0;
  float step = 0.02;

public:
  FadePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    brightness += step;
    if (brightness >= 1.0 || brightness <= 0.0)
      step = -step;
    strip.fill(strip.Color(
        uint8_t(settings->red * brightness),
        uint8_t(settings->green * brightness),
        uint8_t(settings->blue * brightness)));
    strip.show();
  }
};

class RainbowPattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int offset = 0;

public:
  RainbowPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      strip.setPixelColor(i, strip.ColorHSV((i * 65536L / strip.numPixels() + offset)));
    }
    strip.show();
    offset += 256;
  }
};

class CyclePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int position = 0;

public:
  CyclePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    strip.fill(strip.Color(0, 0, 0));
    strip.setPixelColor(position, strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
    position = (position + 1) % strip.numPixels();
  }
};

class BreathePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  float brightness = 0;
  float step = 0.02;

public:
  BreathePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    brightness += step;
    if (brightness >= 1.0 || brightness <= 0.0)
      step = -step;
    strip.fill(strip.Color(
        uint8_t(settings->red * brightness),
        uint8_t(settings->green * brightness),
        uint8_t(settings->blue * brightness)));
    strip.show();
  }
};

class WavePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int position = 0;

public:
  WavePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      float wave = sin((i + position) * 0.3) * 127 + 128;
      strip.setPixelColor(i, strip.Color(
                                 uint8_t(settings->red * wave / 255),
                                 uint8_t(settings->green * wave / 255),
                                 uint8_t(settings->blue * wave / 255)));
    }
    strip.show();
    position += 1;
  }
};

class FirePattern : public Pattern
{
  unsigned long lastUpdate = 0;

public:
  FirePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      int flicker = random(0, 50);
      int r = min(settings->red + flicker, 255);
      int g = min(settings->green + flicker / 2, 255);
      int b = 0;
      strip.setPixelColor(i, strip.Color(r, g, b));
    }
    strip.show();
  }
};

class SparklePattern : public Pattern
{
  unsigned long lastUpdate = 0;

public:
  SparklePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      strip.setPixelColor(i, strip.Color(
                                 settings->red / 2, settings->green / 2, settings->blue / 2));
    }
    int pos = random(strip.numPixels());
    strip.setPixelColor(pos, strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
  }
};

class FlashPattern : public Pattern
{
  unsigned long lastUpdate = 0;
  bool on = false;

public:
  FlashPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    on = !on;
    strip.fill(on ? strip.Color(settings->red, settings->green, settings->blue)
                  : strip.Color(0, 0, 0));
    strip.show();
  }
};

class ChasePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int position = 0;

public:
  ChasePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    strip.fill(strip.Color(0, 0, 0));
    strip.setPixelColor(position, strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
    position = (position + 1) % strip.numPixels();
  }
};

class TwinklePattern : public Pattern
{
  unsigned long lastUpdate = 0;

public:
  TwinklePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    int pos = random(strip.numPixels());
    strip.setPixelColor(pos, strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
  }
};

class MeteorPattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int position = 0;

public:
  MeteorPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      strip.setPixelColor(i, strip.Color(
                                 settings->red / 2, settings->green / 2, settings->blue / 2));
    }
    strip.setPixelColor(position, strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
    position = (position + 1) % strip.numPixels();
  }
};

class ScannerPattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int position = 0;
  bool forward = true;

public:
  ScannerPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    strip.fill(strip.Color(0, 0, 0));
    strip.setPixelColor(position, strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
    if (forward)
      position++;
    else
      position--;
    if (position >= strip.numPixels())
    {
      position = strip.numPixels() - 1;
      forward = false;
    }
    if (position < 0)
    {
      position = 0;
      forward = true;
    }
  }
};

class CometPattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int position = 0;

public:
  CometPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      uint32_t c = strip.getPixelColor(i);
      strip.setPixelColor(i, (c >> 1) & 0x7F7F7F);
    }
    strip.setPixelColor(position, strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
    position = (position + 1) % strip.numPixels();
  }
};

class WipePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int position = 0;

public:
  WipePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    if (position < strip.numPixels())
    {
      strip.setPixelColor(position, strip.Color(settings->red, settings->green, settings->blue));
      strip.show();
      position++;
    }
    else
    {
      strip.fill(strip.Color(0, 0, 0));
      strip.show();
      position = 0;
    }
  }
};

class LarsonPattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int position = 0;
  int length = 5;
  bool forward = true;

public:
  LarsonPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    strip.fill(strip.Color(0, 0, 0));
    for (int i = 0; i < length; i++)
    {
      int pos = position - i;
      if (pos >= 0 && pos < strip.numPixels())
      {
        strip.setPixelColor(pos, strip.Color(settings->red, settings->green, settings->blue));
      }
    }
    strip.show();
    if (forward)
      position++;
    else
      position--;
    if (position >= strip.numPixels())
      forward = false;
    if (position <= 0)
      forward = true;
  }
};

class FireworksPattern : public Pattern
{
  unsigned long lastUpdate = 0;

public:
  FireworksPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      uint32_t c = strip.getPixelColor(i);
      strip.setPixelColor(i, (c >> 1) & 0x7F7F7F);
    }
    if (random(255) < 50)
    {
      int pos = random(strip.numPixels());
      strip.setPixelColor(pos, strip.Color(settings->red, settings->green, settings->blue));
    }
    strip.show();
  }
};

class ConfettiPattern : public Pattern
{
  unsigned long lastUpdate = 0;

public:
  ConfettiPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      uint32_t c = strip.getPixelColor(i);
      strip.setPixelColor(i, (c >> 1) & 0x7F7F7F);
    }
    int pos = random(strip.numPixels());
    strip.setPixelColor(pos, strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
  }
};

class RipplePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int position = 0;

public:
  RipplePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      int distance = abs(i - position);
      int brightness = max(0, 255 - distance * 50);
      strip.setPixelColor(i, strip.Color(
                                 settings->red * brightness / 255,
                                 settings->green * brightness / 255,
                                 settings->blue * brightness / 255));
    }
    strip.show();
    position = (position + 1) % strip.numPixels();
  }
};

class NoisePattern : public Pattern
{
  unsigned long lastUpdate = 0;

public:
  NoisePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    for (int i = 0; i < strip.numPixels(); i++)
    {
      strip.setPixelColor(i, strip.Color(
                                 random(settings->red),
                                 random(settings->green),
                                 random(settings->blue)));
    }
    strip.show();
  }
};

class ILYPattern : public Pattern
{
  unsigned long lastUpdate = 0;
  int burst = 0;
  bool burstOn = false;
  bool offPhase = false;

public:
  ILYPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }

  void update() override
  {
    unsigned long now = millis();

    if (offPhase)
    {
      if (now - lastUpdate < settings->interval * 40)
        return;

      offPhase = false;
      burstOn = false;
      burst = 0;
      lastUpdate = now;
    }

    if (now - lastUpdate < settings->interval * 15)
      return;

    lastUpdate = now;

    if (burstOn)
    {
      strip.fill(strip.Color(0, 0, 0));
      strip.show();
      burstOn = false;
      return;
    }

    if (burst < 3)
    {
      strip.fill(strip.Color(settings->red, settings->green, settings->blue));
      strip.show();
      burstOn = true;
      burst++;
    }
    else
    {
      strip.fill(strip.Color(0, 0, 0));
      strip.show();
      offPhase = true;
    }
  }
};

class BrokenNeonPattern : public Pattern
{
  unsigned long lastUpdate = 0;
  unsigned long nextChange = 0;
  bool isOn = false;

public:
  BrokenNeonPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }

  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    if (now < nextChange)
      return; // wait until it's time

    if (isOn)
    {
      // turn off
      strip.clear();
      strip.show();
      isOn = false;

      // long OFF gap, randomized
      unsigned long offTime = random(25, 100) * settings->interval;
      nextChange = now + offTime;
    }
    else
    {
      // turn on with broken-neon flicker
      for (int i = 0; i < strip.numPixels(); i++)
      {
        if (random(0, 100) < 70) // 70% chance pixel is ON
          strip.setPixelColor(i, strip.Color(settings->red, settings->green, settings->blue));
        else
          strip.setPixelColor(i, 0); // some pixels stay dark
      }
      strip.show();
      isOn = true;

      // short ON burst, randomized
      unsigned long onTime = random(10, 50) * settings->interval;
      nextChange = now + onTime;
    }
  }
};

class ApocalypseLightning : public Pattern
{
  unsigned long lastUpdate = 0;
  int phase = 0;        // 0 = waiting, 1 = flickering
  int flickerCount = 0; // how many flashes left
  int startPixel = 0;
  int segLength = 0;

public:
  ApocalypseLightning(DeviceSettings *settings)
  {
    this->settings = settings;
  }

  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval * 5)
      return;
    lastUpdate = now;

    if (phase == 0)
    {
      // 80% chance to stay off (big gaps)
      if (random(0, 100) < 80)
      {
        strip.fill(strip.Color(0, 0, 0));
        strip.show();
        return;
      }

      // Start a flicker burst
      startPixel = random(0, strip.numPixels());
      segLength = max(1, strip.numPixels() / 5); // ~20%
      flickerCount = random(3, 7);               // number of flashes
      phase = 1;
    }

    if (phase == 1)
    {
      if (flickerCount <= 0)
      {
        strip.fill(strip.Color(0, 0, 0));
        strip.show();
        phase = 0;
        return;
      }

      // Toggle on/off for shaky flicker
      if (flickerCount % 2 == 0)
      {
        for (int i = 0; i < segLength; i++)
        {
          int idx = (startPixel + i) % strip.numPixels();
          // shaky intensity
          int r = random(settings->red / 2, settings->red);
          int g = random(settings->green / 2, settings->green);
          int b = random(settings->blue / 2, settings->blue);
          strip.setPixelColor(idx, strip.Color(r, g, b));
        }
      }
      else
      {
        strip.fill(strip.Color(0, 0, 0));
      }
      strip.show();
      flickerCount--;
    }
  }
};

class SineWavePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  float phase = 0;

public:
  SineWavePattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    strip.clear();
    int n = strip.numPixels();
    for (int i = 0; i < n; i++)
    {
      float brightness = (sin(phase + (i * 0.3f)) + 1.0f) * 0.5f; // 0–1
      int r = settings->red * brightness;
      int g = settings->green * brightness;
      int b = settings->blue * brightness;
      strip.setPixelColor(i, strip.Color(r, g, b));
    }
    strip.show();
    phase += 0.2f;
  }
};

class BlizzardPattern : public Pattern
{
  unsigned long lastUpdate = 0;

public:
  BlizzardPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    strip.clear();
    int n = strip.numPixels();
    int flicker = random(200, 256); // brightness variation
    for (int i = 0; i < n; i++)
    {
      int r = (settings->red * flicker) / 255;
      int g = (settings->green * flicker) / 255;
      int b = (settings->blue * flicker) / 255;
      strip.setPixelColor(i, strip.Color(r, g, b));
    }
    strip.show();
  }
};

class RainbowModeHandler
{
private:
  unsigned long lastUpdate = 0;
  DeviceSettings *settings;
  int offset = 0;

  void hsvToRgb(uint16_t h, uint8_t s, uint8_t v, uint8_t &r, uint8_t &g, uint8_t &b)
  {
    float hf = (float)h / 60.0f; // hue sector 0..6
    int i = (int)hf;
    float f = hf - i;
    float p = v * (1.0f - (s / 255.0f));
    float q = v * (1.0f - f * (s / 255.0f));
    float t = v * (1.0f - (1.0f - f) * (s / 255.0f));

    switch (i % 6)
    {
    case 0:
      r = v;
      g = t;
      b = p;
      break;
    case 1:
      r = q;
      g = v;
      b = p;
      break;
    case 2:
      r = p;
      g = v;
      b = t;
      break;
    case 3:
      r = p;
      g = q;
      b = v;
      break;
    case 4:
      r = t;
      g = p;
      b = v;
      break;
    case 5:
      r = v;
      g = p;
      b = q;
      break;
    }
  }

public:
  RainbowModeHandler(DeviceSettings *settings)
  {
    this->settings = settings;
  }

  void update()
  {

    if (!this->settings->rainbow)
    {
      return;
    }

    unsigned long now = millis();
    if (now - lastUpdate < this->settings->interval / 2)
    {
      return;
    }

    static uint16_t hue = 0;
    hue = (hue + 1) % 360;

    uint8_t r, g, b;
    hsvToRgb(hue, 255, 255, r, g, b);

    settings->red = r;
    settings->green = g;
    settings->blue = b;

    lastUpdate = now;

    offset += 256;
  }
};

class SecurityService
{
private:
  DeviceSettings *settings;
  BLEServer *server;
  const ulong timeout = 10000;

public:
  SecurityService(DeviceSettings *settings, BLEServer *server)
  {
    this->settings = settings;
    this->server = server;
  }

  void verifyDevices()
  {
    auto now = millis();

    std::unordered_set<uint16_t> toRemove = std::unordered_set<uint16_t>();

    // iterate over connected devices and disconnect those that are not authenticated if time has elapsed longer than timeout
    for (auto it = settings->devicesPendingAuthentication->begin(); it != settings->devicesPendingAuthentication->end();)
    {
      auto connId = it->first;
      auto connectedAt = it->second;

      // Remove devices that are authenticated from the pending authentication list.
      if (settings->authenticatedDeviceSet->find(connId) != settings->authenticatedDeviceSet->end())
      {
        // already authenticated → remove from pending
        toRemove.insert(connId);
        ++it;
        continue;
      }

      // not authenticated in time
      if (now - connectedAt > timeout)
      {
        Serial.printf("Disconnecting unauthenticated device with connection ID: %d\n", connId);
        server->disconnect(connId);
        toRemove.insert(connId);
      }

      ++it;
    }

    // remove collected devices from pending authentication
    for (auto connId : toRemove)
    {
      settings->devicesPendingAuthentication->erase(connId);
      Serial.printf("Removed device with connection ID: %d from pending authentication list.\n", connId);
    }
  }
};

Pattern *createPattern(String name, DeviceSettings *settings)
{
  if (name == "flat")
    return new FlatPattern(settings);
  if (name == "glow")
    return new GlowPattern(settings);
  if (name == "pulse")
    return new PulsePattern(settings);
  if (name == "strobe")
    return new StrobePattern(settings);
  if (name == "fade")
    return new FadePattern(settings);
  if (name == "rainbow")
    return new RainbowPattern(settings);
  if (name == "cycle")
    return new CyclePattern(settings);
  if (name == "breathe")
    return new BreathePattern(settings);
  if (name == "wave")
    return new WavePattern(settings);
  if (name == "fire")
    return new FirePattern(settings);
  if (name == "sparkle")
    return new SparklePattern(settings);
  if (name == "flash")
    return new FlashPattern(settings);
  if (name == "chase")
    return new ChasePattern(settings);
  if (name == "twinkle")
    return new TwinklePattern(settings);
  if (name == "meteor")
    return new MeteorPattern(settings);
  if (name == "scanner")
    return new ScannerPattern(settings);
  if (name == "comet")
    return new CometPattern(settings);
  if (name == "wipe")
    return new WipePattern(settings);
  if (name == "larson")
    return new LarsonPattern(settings);
  if (name == "fireworks")
    return new FireworksPattern(settings);
  if (name == "confetti")
    return new ConfettiPattern(settings);
  if (name == "ripple")
    return new RipplePattern(settings);
  if (name == "noise")
    return new NoisePattern(settings);
  if (name == "ily")
    return new ILYPattern(settings);
  if (name == "broken_neon")
    return new BrokenNeonPattern(settings);
  if (name == "apocalypse")
    return new ApocalypseLightning(settings);
  if (name == "sine")
    return new SineWavePattern(settings);
  if (name == "blizzard")
    return new BlizzardPattern(settings);

  return nullptr;
}

// PATTERNS END
BLEServer *pServer = nullptr;
DeviceSettings *deviceSettings = nullptr;
RainbowModeHandler *rainbowModeHandler = nullptr;
SecurityService *authenticationtimeoutHandler = nullptr;

void setup()
{
  Serial.begin(115200);

  pinMode(D0, OUTPUT);
  digitalWrite(D0, LOW);

  BLEDevice::init("M and M - Frame 1");

  deviceSettings = new DeviceSettings();
  rainbowModeHandler = new RainbowModeHandler(deviceSettings);
  pServer = BLEDevice::createServer();
  authenticationtimeoutHandler = new SecurityService(deviceSettings, pServer);

  pServer->setCallbacks(new ServerCallbacks(deviceSettings));

  // SECTION Security
  BLEService *pSecurityService = pServer->createService(SECURITY_SERVICE_UUID);

  auto pAuthenticateChar = pSecurityService->createCharacteristic(
      AUTHENTICATE_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_WRITE);

  pAuthenticateChar->setCallbacks(new AuthenticationCallbacks(deviceSettings, pServer));

  //! SECTION Security

  BLEService *pColorService = pServer->createService(COLOR_SERVICE_UUID);

  auto pColorModeChar = pColorService->createCharacteristic(
      COLOR_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);

  BLEDescriptor *pColorModeCharDescriptor = new BLEDescriptor((uint16_t)0x2901);
  pColorModeCharDescriptor->setValue("The hexadecimal color of the lights, when rainbow mode is disabled.");

  pColorModeChar->addDescriptor(pColorModeCharDescriptor);
  pColorModeChar->addDescriptor(new BLE2902());
  pColorModeChar->setCallbacks(new ColorCharacteristicCallbacks(deviceSettings, pServer));

  BLEDescriptor *pRainbowModeCharDescriptor = new BLEDescriptor((uint16_t)0x2901);
  pRainbowModeCharDescriptor->setValue("Rainbow mode enabled/disabled bit characteristic.");

  auto pRainbowModeChar = pColorService->createCharacteristic(
      RAINBOW_MODE_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);

  pRainbowModeChar->addDescriptor(pRainbowModeCharDescriptor);
  pRainbowModeChar->addDescriptor(new BLE2902());
  pRainbowModeChar->setCallbacks(new RainbowModeCallbacks(deviceSettings, pServer));

  BLEDescriptor *pPatternCharDescriptor = new BLEDescriptor((uint16_t)0x2901);
  pPatternCharDescriptor->setValue("The active color pattern.");

  auto pPatternModeChar = pColorService->createCharacteristic(
      COLOR_PATTERN_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);

  pPatternModeChar->addDescriptor(pPatternCharDescriptor);
  pPatternModeChar->addDescriptor(new BLE2902());
  pPatternModeChar->setCallbacks(new PatternCallbacks(deviceSettings, pServer));

  // SECTION Pattern Rate Characteristic

  BLEDescriptor *pPatternRateCharDescriptor = new BLEDescriptor((uint16_t)0x2901);
  pPatternRateCharDescriptor->setValue("The active color pattern.");

  auto pPatternRateChar = pColorService->createCharacteristic(
      PATTERN_RATE_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);

  pPatternRateChar->addDescriptor(pPatternRateCharDescriptor);
  pPatternRateChar->addDescriptor(new BLE2902());
  pPatternRateChar->setCallbacks(new PatternRateCallbacks(deviceSettings, pServer));

  // !SECTION

  pSecurityService->start();
  pColorService->start();

  auto advertisement = pServer->getAdvertising();
  advertisement->addServiceUUID(COLOR_SERVICE_UUID);
  advertisement->setScanResponse(true);
  advertisement->setMinPreferred(0x06); // functions that help with iPhone connections issue

  advertisement->start();

  Serial.printf("Server initialized with appId: %d\n", pServer->m_appId);
}

Pattern *activePattern = nullptr;
String currentPattern = "";
bool isOff = false;
void loop()
{
  if (pServer->getConnectedCount() > 0)
  {
    authenticationtimeoutHandler->verifyDevices();
  }

  auto brightness = (deviceSettings->red + deviceSettings->green + deviceSettings->blue) / 3;
  strip.setBrightness(brightness);

  if (brightness <= 3 && !isOff)
  {
    strip.fill(strip.Color(0, 0, 0));
    strip.show();

    digitalWrite(D0, LOW);
    digitalWrite(D10, LOW);
    isOff = true;
  }
  else if (brightness > 3 && isOff)
  {
    isOff = false;
    digitalWrite(D0, HIGH);
    digitalWrite(D10, HIGH);
  }

  if (isOff)
  {
    delay(250);
    return;
  }

  if (deviceSettings->pattern != currentPattern)
  {
    currentPattern = deviceSettings->pattern;
    if (activePattern)
    {
      delete activePattern;
    }
    activePattern = createPattern(currentPattern, deviceSettings);
  }

  if (activePattern)
  {
    rainbowModeHandler->update();
    activePattern->update();
  }
}
