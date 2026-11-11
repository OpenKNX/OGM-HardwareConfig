#pragma once
/**
 * @file DemoBoards.h
 * @brief Demo boards for the ETS test product only (no firmware env): every kind of hardware dependence in one place.
 * @note IDs 0x3F00..0x3F1F (community range, never used by a real board). Defines HW_POWER_METER, HW_TEMP_SENSOR,
 *       HW_FRONT_CONTROLS, HW_SENSOR_* and HW_SLOT_SENSOR are the names proposed in generator/Anwendungsfaelle.md.
 */

// ---- room controller in three stages (fixed sensors on the board; Pro has a slot for a plug-in sensor module) ----
#ifdef DEMO_RAUMCONTROLLER_BASIC
    #define DEVICE_HW_ID 0x3F00
    #define DEVICE_ID "Demo-Raumcontroller-Basic"
    #define DEVICE_NAME "Demo Raumcontroller Basic"
    #define HW_INFO_TEXT "Demo: Raumcontroller mit Temperatur- und Feuchtesensor."
    #define HW_SENSOR_TEMP_HUM
    #define KNX_UART_RX_PIN 1
#endif
#ifdef DEMO_RAUMCONTROLLER_PLUS
    #define DEVICE_HW_ID 0x3F01
    #define DEVICE_ID "Demo-Raumcontroller-Plus"
    #define DEVICE_NAME "Demo Raumcontroller Plus"
    #define HW_INFO_TEXT "Demo: Raumcontroller mit Temperatur/Feuchte, CO2 und Helligkeit, 2 Tasteneingänge und 2 Status-LEDs."
    #define HW_INFO_URL "https://openknx.de"
    #define HW_SENSOR_TEMP_HUM
    #define HW_SENSOR_CO2
    #define HW_SENSOR_LUX
    #define OPENKNX_BI_GPIO_COUNT 2
    #define OPENKNX_SLED_COUNT 2
    #define KNX_UART_RX_PIN 1
#endif
#ifdef DEMO_RAUMCONTROLLER_PRO
    #define DEVICE_HW_ID 0x3F02
    #define DEVICE_ID "Demo-Raumcontroller-Pro"
    #define DEVICE_NAME "Demo Raumcontroller Pro"
    #define HW_SENSOR_TEMP_HUM
    #define HW_SENSOR_CO2
    #define HW_SENSOR_LUX
    #define HW_SENSOR_PRESENCE
    #define HW_SLOT_SENSOR            // slot for a plug-in sensor module: the firmware detects it at run time
    #define OPENKNX_BI_GPIO_COUNT 4
    #define OPENKNX_SLED_COUNT 4
    #define KNX_UART_RX_PIN 1
#endif

// ---- smart relays of a third party (example of a Shelly family, see generator/Anwendungsfaelle.md) ----
#ifdef DEMO_SHELLY_PLUS_1
    #define DEVICE_HW_ID 0x3F10
    #define DEVICE_ID "Demo-Shelly-Plus-1"
    #define DEVICE_NAME "Demo Shelly Plus 1"
    #define DEVICE_THIRD_PARTY
    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO 26
    #define OPENKNX_BI_GPIO_COUNT 1
    #define HW_TEMP_SENSOR
    #define KNX_IP_WIFI
#endif
#ifdef DEMO_SHELLY_PLUS_1PM
    #define DEVICE_HW_ID 0x3F11
    #define DEVICE_ID "Demo-Shelly-Plus-1PM"
    #define DEVICE_NAME "Demo Shelly Plus 1PM"
    #define DEVICE_THIRD_PARTY
    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO 26
    #define OPENKNX_BI_GPIO_COUNT 1
    #define HW_POWER_METER
    #define HW_TEMP_SENSOR
    #define KNX_IP_WIFI
#endif
#ifdef DEMO_SHELLY_PLUS_2PM
    #define DEVICE_HW_ID 0x3F12
    #define DEVICE_ID "Demo-Shelly-Plus-2PM"
    #define DEVICE_NAME "Demo Shelly Plus 2PM"
    #define DEVICE_THIRD_PARTY
    #define HW_INFO_TEXT "Demo: 2 Relais (auch als 1 Jalousie), 2 Eingänge, Leistungsmessung, Gerätetemperatur."
    #define HW_RELAY_COUNT 2
    #define HW_RELAY_1_GPIO 12
    #define HW_RELAY_2_GPIO 13
    #define OPENKNX_BI_GPIO_COUNT 2
    #define HW_POWER_METER
    #define HW_TEMP_SENSOR
    #define KNX_IP_WIFI
#endif
#ifdef DEMO_SHELLY_PLUS_I4
    #define DEVICE_HW_ID 0x3F13
    #define DEVICE_ID "Demo-Shelly-Plus-i4"
    #define DEVICE_NAME "Demo Shelly Plus i4"
    #define DEVICE_THIRD_PARTY
    #define OPENKNX_BI_GPIO_COUNT 4
    #define KNX_IP_WIFI
#endif
#ifdef DEMO_SHELLY_PLUG_S
    #define DEVICE_HW_ID 0x3F14
    #define DEVICE_ID "Demo-Shelly-Plug-S"
    #define DEVICE_NAME "Demo Shelly Plug S"
    #define DEVICE_THIRD_PARTY
    #define HW_INFO_URL "https://www.shelly.com"
    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO 4
    #define HW_POWER_METER
    #define HW_TEMP_SENSOR
    #define HW_FRONT_CONTROLS        // button and LED ring on the device
    #define KNX_IP_WIFI
#endif
