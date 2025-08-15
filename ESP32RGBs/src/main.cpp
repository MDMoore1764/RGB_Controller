#include <Arduino.h>
#include <BLEServer.h>
#include <BLEDevice.h>
#include <BLE2902.h>
#include <BLEDescriptor.h>
#include <Adafruit_NeoPixel.h>

#define LED_PIN D10
#define NUM_LEDS 100
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
    red = 0;
    green = 0;
    blue = 0;
    pattern = "flat";
    interval = 50; // milliseconds
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
  FlatPattern(DeviceSettings *settings) { this->settings = settings; }
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
  GlowPattern(DeviceSettings *settings) { this->settings = settings; }
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

class PulsePattern : public Pattern
{
  unsigned long lastUpdate = 0;
  float brightness = 0;
  float step = 0.05;

public:
  PulsePattern(DeviceSettings *settings) { this->settings = settings; }
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
  StrobePattern(DeviceSettings *settings) { this->settings = settings; }
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
  FadePattern(DeviceSettings *settings) { this->settings = settings; }
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
  RainbowPattern(DeviceSettings *settings) { this->settings = settings; }
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
  CyclePattern(DeviceSettings *settings) { this->settings = settings; }
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
  BreathePattern(DeviceSettings *settings) { this->settings = settings; }
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
  WavePattern(DeviceSettings *settings) { this->settings = settings; }
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
  FirePattern(DeviceSettings *settings) { this->settings = settings; }
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
  SparklePattern(DeviceSettings *settings) { this->settings = settings; }
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
  FlashPattern(DeviceSettings *settings) { this->settings = settings; }
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
  ChasePattern(DeviceSettings *settings) { this->settings = settings; }
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
  TwinklePattern(DeviceSettings *settings) { this->settings = settings; }
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
  MeteorPattern(DeviceSettings *settings) { this->settings = settings; }
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
  ScannerPattern(DeviceSettings *settings) { this->settings = settings; }
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
  CometPattern(DeviceSettings *settings) { this->settings = settings; }
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
  WipePattern(DeviceSettings *settings) { this->settings = settings; }
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
  LarsonPattern(DeviceSettings *settings) { this->settings = settings; }
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
  FireworksPattern(DeviceSettings *settings) { this->settings = settings; }
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
  ConfettiPattern(DeviceSettings *settings) { this->settings = settings; }
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
  RipplePattern(DeviceSettings *settings) { this->settings = settings; }
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
  NoisePattern(DeviceSettings *settings) { this->settings = settings; }
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
  int pos = 0;

public:
  ILYPattern(DeviceSettings *settings) { this->settings = settings; }
  void update() override
  {
    unsigned long now = millis();
    if (now - lastUpdate < settings->interval)
      return;
    lastUpdate = now;

    // simple “heart-like” animation placeholder
    strip.fill(strip.Color(0, 0, 0));
    int mid = strip.numPixels() / 2;
    for (int i = -1; i <= 1; i++)
      strip.setPixelColor(mid + i + pos, strip.Color(settings->red, settings->green, settings->blue));
    strip.show();
    pos = (pos + 1) % strip.numPixels();
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
  auto brightness = (deviceSettings->red + deviceSettings->green + deviceSettings->blue) / 3;
  strip.setBrightness(brightness);

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
