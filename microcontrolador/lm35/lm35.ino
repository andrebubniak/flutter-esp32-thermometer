#include <BLEDevice.h>
#include <BLEServer.h>
#include <Ticker.h>
#include "esp_adc_cal.h"

#define BLE_SERVICE_UUID "c097aeb9-0d5e-4fb2-817f-29d6fd5184fd"
#define SEND_DATA_CHARACTERISTIC_UUID "9a542120-3f62-4aec-8223-809f94d0bab5"
#define DEVICE_NAME "ESP32_LM35"
#define LM35_PIN 34
#define SAMPLE_COUNT 100

#define LED_PIN 2

BLEServer *pServer = NULL;

BLECharacteristic *sendDataCharacteristic = NULL;
bool isBLEConnected = false;

float samples[SAMPLE_COUNT];
int currentSampleIndex = 0;

Ticker ticker;

void changeLed() {digitalWrite(LED_PIN, !digitalRead(LED_PIN));}


float average(float* vector, int length)
{
  float sum = 0;
  for(int i = 0;i < length;i++)
  {
    sum += vector[i];
  }
  return sum / length;
}


class MyBLEServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *pServer)
  {
    Serial.println("Bluetooth Connected");
    isBLEConnected = true;
    ticker.detach();
    digitalWrite(LED_PIN, LOW);
  }

  void onDisconnect(BLEServer *pServer)
  {
    digitalWrite(LED_PIN, HIGH);
    Serial.println("Bluetooth Disconnected");
    isBLEConnected = false;

    delay(1000);
    BLEDevice::startAdvertising();
    Serial.println("Waiting a client connection to notify...");
    ticker.attach(0.3, changeLed);
  }
};


//init ble server and its characteristics
void initBLE()
{
  //init ble
  BLEDevice::init(DEVICE_NAME);

  //create server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyBLEServerCallbacks());

  //create the service
  BLEService *pService = pServer->createService(BLE_SERVICE_UUID);

  //create characteristic
  sendDataCharacteristic = pService->createCharacteristic(SEND_DATA_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_NOTIFY);

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(BLE_SERVICE_UUID);
  BLEDevice::startAdvertising();
  Serial.println("Waiting a client connection to notify...");
  ticker.attach(0.3, changeLed);

}





void setup() 
{
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);
  Serial.begin(115200);
  delay(1000);
  initBLE();
}

void loop() 
{
  if(!isBLEConnected) return;

  if(currentSampleIndex == SAMPLE_COUNT)
  {
    
    char jsonBuffer[20];
    
    sprintf(jsonBuffer, "%.2f", average(samples, SAMPLE_COUNT)-3); 
    
    sendDataCharacteristic->setValue(jsonBuffer);
    sendDataCharacteristic->notify();
    
    Serial.println(average(samples, SAMPLE_COUNT)-3);
    currentSampleIndex = 0;
    delay(1000);
    return;
  }


  int value = analogRead(LM35_PIN);

  //calibra e retorna mV
  float voltage = readADC_Cal(value);

  float tempCelsius = voltage / 10;  // voltage(mV) / 10 => escala lm35

  samples[currentSampleIndex] = tempCelsius;
  currentSampleIndex++;
  
}


uint32_t readADC_Cal(int ADC_Raw)
{
  esp_adc_cal_characteristics_t adc_chars;
  
  esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_11, ADC_WIDTH_BIT_12, 1100, &adc_chars);
  return(esp_adc_cal_raw_to_voltage(ADC_Raw, &adc_chars));
}
