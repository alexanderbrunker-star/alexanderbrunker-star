# ESP32 Garage & Door Controller

Dieses Projekt enthält die ESPHome-Konfiguration für ein ESP32 Dual-Relais-Board zur Steuerung eines Türsummers und eines Garagentors.

## Hardware

- **Board**: ESP32 (ESP32-WROOM-32E) Dual-Relais Modul
- **Bezugsquelle**: [AliExpress](https://de.aliexpress.com/item/1005008500006945.html)
- **Features**: 2 Relais, GPIO-Pins für Sensoren, integriertes ESP32-Modul mit Wi-Fi & Bluetooth.

### Pin-Belegung (`esp32-door-and-garage.yaml`)

**Relais (Ausgänge):**
- `GPIO 16`: Tür Summer (Relais 1)
- `GPIO 17`: Garage Trigger (Relais 2)

**Sensoren (Eingänge):**
- `GPIO 21`: PIR Bewegungsmelder (HC-SR501)

**RGB LED (Common Cathode):**
- `GPIO 32`: Rot (PWM)
- `GPIO 33`: Grün (PWM)
- `GPIO 25`: Blau (PWM)

## Flashen (Ersteinrichtung per USB-TTL)

Falls das Gerät über WLAN (OTA) nicht erreichbar ist, muss es initial per **USB-zu-TTL Adapter** geflasht werden.

1. **Verkabelung**: 
   - `TX` (Adapter) ➔ `RX` (ESP)
   - `RX` (Adapter) ➔ `TX` (ESP)
   - `GND` ➔ `GND`
   - `5V` (oder `3.3V` je nach Board-Eingang) ➔ `5V` / `VCC`
2. **Boot-Modus erzwingen**:
   Halte den **BOOT**-Knopf (oder verbinde `IO0` / `GPIO0` mit `GND`), während das Gerät mit Strom versorgt wird oder kurz den **EN/RST**-Knopf drückst, damit der ESP32 in den Flash-Modus geht.
3. **Kommando**:
   ```bash
   esphome run esphome_garage_door/esp32-door-and-garage.yaml
   ```

## Logik der RGB LED

Dieses Projekt verfügt über eine intelligente LED-Prioritätensteuerung **direkt auf dem ESP32**. Es ist keine Logik in Home Assistant notwendig.

1. **Priorität 1: Tür Summer (Blaues Blinken)**
   Wird der Tür-Summer betätigt, blinkt die LED für 3 Sekunden blau.
2. **Priorität 2: Garagentor Trigger (Grünes Blinken)**
   Wenn der `Garage Trigger` (auch via Home Assistant) betätigt wird, blinkt die LED für 5 Sekunden grün.
3. **Priorität 3: PIR Bewegung (Weißes Leuchten)**
   Wird Bewegung erkannt, leuchtet die LED für 10 Sekunden konstant weiß. Jede erneute Bewegung startet den Timer neu.

### Home Assistant Integration

Da die gesamte Logik auf dem ESP32 liegt, müssen in Home Assistant **keine** komplexen Automatisierungen für die LED erstellt werden. Alles funktioniert automatisch, sobald die entsprechenden Entitäten (`switch.esp32_garage_door_garage_trigger`, `switch.esp32_garage_door_tuer_summer`, `binary_sensor.esp32_garage_door_pir_bewegung`) geschaltet werden.

### Modul Ansichten
*(Bilder von AliExpress)*

**Vorderseite:**
![Vorderseite](https://ae01.alicdn.com/kf/Scd59dfd1306a4e4da5277bd90a6a16b77.jpg)

**Rückseite / Anschlüsse:**
![Rückseite](https://ae01.alicdn.com/kf/S14ceff9d5e62437baca6e6c4b3f30c0bb.jpg)
