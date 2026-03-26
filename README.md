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
*(Hinweis: In einer älteren Version waren `GPIO 23` für den Haustür-Kontakt und `GPIO 22` für den Garagentor-Kontakt konfiguriert).*

**RGB LED (Common Cathode):**
- `GPIO 32`: Rot (PWM)
- `GPIO 33`: Grün (PWM)
- `GPIO 25`: Blau (PWM)

## Flashen (Ersteinrichtung per USB-TTL)

Falls das Gerät über WLAN (OTA) nicht erreichbar ist (z.B. wegen fehlendem `ota:` Block in alten Konfigurationen), muss es initial per **USB-zu-TTL Adapter** geflasht werden.

1. **Verkabelung**: 
   - `TX` (Adapter) ➔ `RX` (ESP)
   - `RX` (Adapter) ➔ `TX` (ESP)
   - `GND` ➔ `GND`
   - `5V` (oder `3.3V` je nach Board-Eingang) ➔ `5V` / `VCC`
2. **Boot-Modus erzwingen**:
   Wenn beim Flashen der Fehler `Failed to connect to ESP32: No serial data received.` auftritt, muss der ESP32 manuell in den Programmiermodus versetzt werden. Halte dazu den **BOOT**-Knopf (oder verbinde `IO0` / `GPIO0` mit `GND`), während das Gerät mit Strom versorgt wird oder sobald in der Konsole `Connecting...` steht.
3. **Kommando**:
   ```bash
   esphome run esphome_garage_door/esp32-door-and-garage.yaml
   ```

## Logik der RGB LED

Dieses Projekt verfügt über eine intelligente LED-Prioritätensteuerung direkt auf dem ESP32:

1. **Priorität 1: Tür Summer (Blaues Blinken)**
   Wird der Tür-Summer betätigt, blinkt die LED für 3 Sekunden blau. Diese Aktion hat die höchste Priorität.
2. **Priorität 2: Garagentor Fahrt (Grünes oder Rotes Blinken)**
   Wenn das Garagentor öffnet, blinkt die LED grün. Wenn es schließt, blinkt sie rot. Dies wird von Home Assistant gesteuert (durch Aufruf der ESPHome-Skripte `Garage Opening`, `Garage Closing` und `Garage Stopped`).
3. **Priorität 3: PIR Bewegung (Weißes Leuchten)**
   Wird Bewegung erkannt, leuchtet die LED für 10 Sekunden konstant weiß. Jede erneute Bewegung startet den Timer neu.

### Home Assistant Integration

Um die LED beim Öffnen und Schließen des Tors korrekt blinken zu lassen, benötigt Home Assistant Automatisierungen. Hier ein Beispiel, basierend auf Zigbee-Sensoren für "Zu" (`binary_sensor.0xa4c138e9b7bc2db6_contact`) und "Offen" (`binary_sensor.0xa4c13867aa0f13ee_contact`):

**1. Tor öffnet (Grün blinken)**
```yaml
alias: "Garage: Öffnen (Grün pulsieren)"
trigger:
  - platform: state
    entity_id: switch.esp32_garage_door_garage_trigger
    to: "on"
condition:
  - condition: state
    entity_id: binary_sensor.0xa4c138e9b7bc2db6_contact
    state: "on" # bzw. off (geschlossen)
action:
  - service: script.turn_on
    target:
      entity_id: script.esp32_garage_door_garage_opening
```

**2. Tor schließt (Rot blinken)**
```yaml
alias: "Garage: Schließen (Rot pulsieren)"
trigger:
  - platform: state
    entity_id: switch.esp32_garage_door_garage_trigger
    to: "on"
condition:
  - condition: state
    entity_id: binary_sensor.0xa4c13867aa0f13ee_contact
    state: "on" # bzw. off (offen)
action:
  - service: script.turn_on
    target:
      entity_id: script.esp32_garage_door_garage_closing
```

**3. Tor ist angekommen (Stoppen)**
```yaml
alias: "Garage: Fahrt beendet (LED Stop)"
trigger:
  - platform: state
    entity_id: binary_sensor.0xa4c138e9b7bc2db6_contact
    to: "on" # bzw. off (geschlossen)
  - platform: state
    entity_id: binary_sensor.0xa4c13867aa0f13ee_contact
    to: "on" # bzw. off (offen)
action:
  - service: script.turn_on
    target:
      entity_id: script.esp32_garage_door_garage_stopped
```

### Modul Ansichten
*(Bilder von AliExpress)*

**Vorderseite:**
![Vorderseite](https://ae01.alicdn.com/kf/Scd59dfd1306a4e4da5277bd90a6a16b77.jpg)

**Rückseite / Anschlüsse:**
![Rückseite](https://ae01.alicdn.com/kf/S14ceff9d5e62437baca6e6c4b3f30c0bb.jpg)
