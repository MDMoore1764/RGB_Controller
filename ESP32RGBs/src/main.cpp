#include <Arduino.h>
#include <BLEServer.h>
#include <BLEDevice.h>
#include <BLE2902.h>
#include <BLEDescriptor.h>
#include <Adafruit_NeoPixel.h>

#define LED_PIN D10
#define NUM_LEDS 30
#define BRIGHTNESS 255

Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

// Create color service and characteristics
#define COLOR_SERVICE_UUID "f9bbfc69-8184-4a4b-af62-f560441faf50"
#define COLOR_CHARACTERISTIC_UUID "6cb02075-6a70-4f34-a51f-15120e7e1e2f"
#define COLOR_PATTERN_CHARACTERISTIC_UUID "ac1d5ac2-1641-4a96-9297-73a3fda2a664"
#define RAINBOW_MODE_CHARACTERISTIC_UUID "ac1d5ac2-1641-4a96-9297-73a3fda2a665"

class DeviceSettings
{
public:
  uint8_t red;
  uint8_t green;
  uint8_t blue;
  uint16_t interval;
  String pattern;
  bool rainbow;
  DeviceSettings()
  {
    red = 255;
    green = 255;
    blue = 255;
    pattern = "flat";
    interval = 500; // milliseconds
    rainbow = false;
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
      String rainbowValue = deviceSettings->pattern;
      patternCharacteristic->setValue(rainbowValue);
      patternCharacteristic->notify();
    }

    Serial.println("Client connected");
    Serial.printf("Connected client count: %d\n", pServer->getConnectedCount());
  };

  void onDisconnect(BLEServer *pServer)
  {
    pServer->startAdvertising();
    Serial.println("Client disconnected");
  }
};

class RainbowModeCallbacks : public BLECharacteristicCallbacks
{
private:
  DeviceSettings *deviceSettings;

public:
  RainbowModeCallbacks(DeviceSettings *deviceSettings)
  {
    this->deviceSettings = deviceSettings;
  }

  void onWrite(BLECharacteristic *pCharacteristic) override
  {
    String value = pCharacteristic->getValue();

    if (value.length() > 0)
    {
      this->deviceSettings->rainbow = (value == "1");
      Serial.printf("Rainbow mode set to: %d\n", deviceSettings->rainbow ? 1 : 0);
    }
  }

  void onRead(BLECharacteristic *pCharacteristic) override
  {
    int rainbowValue = this->deviceSettings->rainbowMode();
    pCharacteristic->setValue(rainbowValue);
    Serial.printf("Rainbow mode read as: %d\n", rainbowValue);
  }
};

class PatternCallbacks : public BLECharacteristicCallbacks
{
private:
  DeviceSettings *deviceSettings;

public:
  PatternCallbacks(DeviceSettings *deviceSettings)
  {
    this->deviceSettings = deviceSettings;
  }

  void onWrite(BLECharacteristic *pCharacteristic) override
  {
    String value = pCharacteristic->getValue();

    if (value.length() > 0)
    {
      deviceSettings->pattern = value;
      Serial.printf("Pattern set to: %s\n", deviceSettings->pattern.c_str());
    }
  }

  void onRead(BLECharacteristic *pCharacteristic) override
  {
    pCharacteristic->setValue(deviceSettings->pattern);
    Serial.printf("Pattern read as: %d\n", deviceSettings->pattern.c_str());
  }
};

class ColorCharacteristicCallbacks : public BLECharacteristicCallbacks
{
private:
  DeviceSettings *deviceSettings;

public:
  ColorCharacteristicCallbacks(DeviceSettings *deviceSettings)
  {
    this->deviceSettings = deviceSettings;
  }

  void onWrite(BLECharacteristic *pCharacteristic) override
  {
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

class FlashPattern : public Pattern
{
  unsigned long lastToggle = 0;
  bool on = false;

public:
  FlashPattern(DeviceSettings *settings)
  {
    this->settings = settings;
  }

  void update() override
  {
    unsigned long now = millis();
    if (now - lastToggle < settings->interval)
    {
      return;
    }

    lastToggle = now;
    on = !on;
    strip.fill(on ? strip.Color(settings->red, settings->green, settings->blue) : strip.Color(0, 0, 0));
    strip.show();
  }
};

Pattern *createPattern(String name, DeviceSettings *settings)
{
  if (name == "flat")
    return new FlatPattern(settings);
  if (name == "flash")
    return new FlashPattern(settings);
  return nullptr;
}

// PATTERNS END
BLEServer *pServer = nullptr;
DeviceSettings *deviceSettings = nullptr;
void setup()
{
  Serial.begin(115200);

  BLEDevice::init("Frame 1");

  deviceSettings = new DeviceSettings();
  pServer = BLEDevice::createServer();

  pServer->setCallbacks(new ServerCallbacks(deviceSettings));

  BLEService *pColorService = pServer->createService(COLOR_SERVICE_UUID);

  auto pColorModeChar = pColorService->createCharacteristic(
      COLOR_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);

  BLEDescriptor *pColorModeCharDescriptor = new BLEDescriptor((uint16_t)0x2901);
  pColorModeCharDescriptor->setValue("The hexadecimal color of the lights, when rainbow mode is disabled.");

  pColorModeChar->addDescriptor(pColorModeCharDescriptor);
  pColorModeChar->addDescriptor(new BLE2902());
  pColorModeChar->setCallbacks(new ColorCharacteristicCallbacks(deviceSettings));

  BLEDescriptor *pRainbowModeCharDescriptor = new BLEDescriptor((uint16_t)0x2901);
  pRainbowModeCharDescriptor->setValue("Rainbow mode enabled/disabled bit characteristic.");

  auto pRainbowModeChar = pColorService->createCharacteristic(
      RAINBOW_MODE_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);

  pRainbowModeChar->addDescriptor(pRainbowModeCharDescriptor);
  pRainbowModeChar->addDescriptor(new BLE2902());
  pRainbowModeChar->setCallbacks(new RainbowModeCallbacks(deviceSettings));

  BLEDescriptor *pPatternCharDescriptor = new BLEDescriptor((uint16_t)0x2901);
  pPatternCharDescriptor->setValue("The active color pattern.");

  auto pPatternModeChar = pColorService->createCharacteristic(
      COLOR_PATTERN_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);

  pPatternModeChar->addDescriptor(pPatternCharDescriptor);
  pPatternModeChar->addDescriptor(new BLE2902());
  pPatternModeChar->setCallbacks(new PatternCallbacks(deviceSettings));

  pColorService->start();

  pServer->startAdvertising();
  pServer->getAdvertising()->start();

  Serial.printf("Server initialized with appId: %d\n", pServer->m_appId);
}

Pattern *activePattern = nullptr;
String currentPattern = "";
void loop()
{
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
    activePattern->update();
  }
}
