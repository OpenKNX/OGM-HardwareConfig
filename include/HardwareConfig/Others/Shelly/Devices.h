#pragma once
/**
 * OpenKNX Hardware definition header file
 *
 * File: Others/Shelly/Devices.h
 * Hardware: Shelly (Allterco Robotics), Plus / Gen3 series, ESP32 / ESP32-C3, KNX over IP (WiFi)
 * Responsible: <tbd>
 *
 * Pinout source: ESPHome device database (github.com/esphome/esphome-devices, src/docs/devices/<device>/index.md).
 * Not measured on a device by OpenKNX. Check each pin on the bench before a release.
 *
 * HW-ID group 0x25xx (Shelly): group table in README.md.
 *
 * ATTENTION:
 *    Do not include this file directly.
 *    It will be included by the HardwareConfig.h file.
 *
 * Generic defines read by the hardware profile generator (OGM-HardwareConfig/generator):
 *    HW_RELAY_COUNT          number of relays            -> Value "Relays"       (%HWP_VAL_Relays_GE_n%)
 *    OPENKNX_BI_GPIO_COUNT   number of switch inputs     -> Value "BinaryInputs" (Common.caps.xml)
 *    HW_POWER_METER          power metering chip present -> Capability "PowerMeter"  (%HWP_CAP_PowerMeter%)
 *    HW_TEMP_SENSOR          device temperature (NTC)    -> Capability "Temperature" (%HWP_CAP_Temperature%)
 *    DEVICE_THIRD_PARTY      third-party hardware        -> Capability "ThirdParty" (bit 0 of the device query)
 *    HW_RELAY_<n>_GPIO / _LABEL  hard-wired relays (README "Ports"), read by hwRelayGpio() and the conflict check
 * Other vendor pins carry the prefix SHELLY_.
 */

#pragma region "Shelly Plus (ESP32-U4WDH, 4 MB embedded flash)"

#ifdef DEVICE_SHELLY_PLUS_1
    // ============================================================================
    // Shelly Plus 1 - 1 relay (potential-free), 1 switch input, no power metering
    // ============================================================================
    //   GPIO0  - LED (inverted), Add-On DATA out     GPIO25 - Button (inverted, pull-up)
    //   GPIO1  - Add-On DATA in (UART0 TX)           GPIO26 - Relay
    //   GPIO3  - Add-On ANALOG IN (UART0 RX)         GPIO32 - NTC (ADC)
    //   GPIO4  - Switch input                        GPIO33 - Relay supply voltage sense (ADC)
    //   GPIO19 - Add-On DIGITAL IN
    // ============================================================================
    #define DEVICE_HW_ID 0x2500
    #define DEVICE_THIRD_PARTY
    #define DEVICE_ID "Shelly-Plus-1"
    #define DEVICE_NAME "Shelly Plus 1"
    #define DEVICE_FLASH_SIZE_MB 4
    #define HW_INFO_TEXT "Shelly Plus 1: 1 Relais (potentialfrei), 1 Schalteingang, Gerätetemperatur. KNX über WLAN."
    #define HW_INFO_URL "https://www.shelly.com"

    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO 26
    #define HW_RELAY_1_LABEL "O1"
    #define SHELLY_RELAY_ACTIVE_ON HIGH

    #define OPENKNX_BI_GPIO_COUNT 1
    #define OPENKNX_BI_GPIO_PINS 4

    #define HW_TEMP_SENSOR
    #define SHELLY_NTC_GPIO 32
    #define SHELLY_SUPPLY_SENSE_GPIO 33

    #define SHELLY_ADDON_DATA_OUT_GPIO 0 // shared with the LED
    #define SHELLY_ADDON_DATA_IN_GPIO 1  // UART0 TX: no serial debug with the Add-On
    #define SHELLY_ADDON_ANALOG_GPIO 3   // UART0 RX
    #define SHELLY_ADDON_DIGITAL_GPIO 19
#endif

#ifdef DEVICE_SHELLY_PLUS_1PM
    // ============================================================================
    // Shelly Plus 1PM - 1 relay, 1 switch input, power metering (BL0937)
    // ============================================================================
    //   GPIO0  - LED (inverted), Add-On DATA out     GPIO19 - Add-On DIGITAL IN
    //   GPIO1  - Add-On DATA in (UART0 TX)           GPIO23 - BL0937 SEL (inverted)
    //   GPIO3  - Add-On ANALOG IN (UART0 RX)         GPIO25 - Button (inverted, pull-up)
    //   GPIO4  - Switch input                        GPIO26 - Relay
    //   GPIO5  - BL0937 CF                           GPIO32 - NTC (ADC)
    //   GPIO18 - BL0937 CF1                          GPIO33 - Relay supply voltage sense (ADC)
    // PCB v0.1.9 (single core, 160 MHz) and v0.2.0 (dual core, 240 MHz): same pins
    // ============================================================================
    #define DEVICE_HW_ID 0x2501
    #define DEVICE_THIRD_PARTY
    #define DEVICE_ID "Shelly-Plus-1PM"
    #define DEVICE_NAME "Shelly Plus 1PM"
    #define DEVICE_FLASH_SIZE_MB 4
    #define HW_INFO_TEXT "Shelly Plus 1PM: 1 Relais, 1 Schalteingang, Leistungsmessung, Gerätetemperatur. KNX über WLAN."
    #define HW_INFO_URL "https://www.shelly.com"

    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO 26
    #define HW_RELAY_1_LABEL "O1"
    #define SHELLY_RELAY_ACTIVE_ON HIGH

    #define OPENKNX_BI_GPIO_COUNT 1
    #define OPENKNX_BI_GPIO_PINS 4

    #define HW_POWER_METER
    #define SHELLY_PM_BL0937
    #define SHELLY_BL0937_CF_GPIO 5
    #define SHELLY_BL0937_CF1_GPIO 18
    #define SHELLY_BL0937_SEL_GPIO 23 // inverted

    #define HW_TEMP_SENSOR
    #define SHELLY_NTC_GPIO 32
    #define SHELLY_SUPPLY_SENSE_GPIO 33
#endif

// Plus 2PM: PCB v0.1.5 and v0.1.9 differ in 5 pins (button, switch 1, I2C SDA, ADE7953 IRQ, NTC).
// Different assembly = own HW-ID (README rule); the device query then tells ETS which PCB it is.
#ifdef DEVICE_SHELLY_PLUS_2PM_V015
    // ============================================================================
    // Shelly Plus 2PM, PCB v0.1.5 (sold until 2022) - 2 relays or 1 cover, 2 inputs, ADE7953
    // ============================================================================
    //   GPIO0  - LED (inverted)        GPIO13 - Relay 1          GPIO27 - Button (inverted, pull-up)
    //   GPIO2  - Switch 1 input        GPIO18 - Switch 2 input   GPIO33 - I2C SDA (ADE7953)
    //   GPIO12 - Relay 2               GPIO25 - I2C SCL          GPIO36 - ADE7953 IRQ (input only)
    //                                                            GPIO37 - NTC (input only)
    // ============================================================================
    #define DEVICE_HW_ID 0x2502
    #define DEVICE_THIRD_PARTY
    #define DEVICE_ID "Shelly-Plus-2PM-v015"
    #define DEVICE_NAME "Shelly Plus 2PM (PCB v0.1.5)"
    #define DEVICE_FLASH_SIZE_MB 4
    #define HW_INFO_TEXT "Shelly Plus 2PM (PCB v0.1.5): 2 Relais oder 1 Jalousie, 2 Schalteingänge, Leistungsmessung, Gerätetemperatur. KNX über WLAN."
    #define HW_INFO_URL "https://www.shelly.com"

    #define HW_RELAY_COUNT 2
    #define HW_RELAY_1_GPIO 13
    #define HW_RELAY_1_LABEL "O1"
    #define HW_RELAY_2_GPIO 12
    #define HW_RELAY_2_LABEL "O2"
    #define SHELLY_RELAY_ACTIVE_ON HIGH

    #define OPENKNX_BI_GPIO_COUNT 2
    #define OPENKNX_BI_GPIO_PINS 2, 18

    #define HW_POWER_METER
    #define SHELLY_PM_ADE7953
    #define SHELLY_I2C_SDA_GPIO 33
    #define SHELLY_I2C_SCL_GPIO 25
    #define SHELLY_ADE7953_IRQ_GPIO 36

    #define HW_TEMP_SENSOR
    #define SHELLY_NTC_GPIO 37

    #define SHELLY_BUTTON_GPIO 27
#endif

#ifdef DEVICE_SHELLY_PLUS_2PM_V019
    // ============================================================================
    // Shelly Plus 2PM, PCB v0.1.9 (sold since 2022) - 2 relays or 1 cover, 2 inputs, ADE7953
    // ============================================================================
    //   GPIO0  - LED (inverted)        GPIO13 - Relay 1          GPIO26 - I2C SDA (ADE7953)
    //   GPIO4  - Button (inv., pull-up) GPIO18 - Switch 2 input  GPIO27 - ADE7953 IRQ
    //   GPIO5  - Switch 1 input        GPIO22 - Add-On DIGITAL IN GPIO35 - NTC (input only)
    //   GPIO12 - Relay 2               GPIO25 - I2C SCL
    // ============================================================================
    #define DEVICE_HW_ID 0x2503
    #define DEVICE_THIRD_PARTY
    #define DEVICE_ID "Shelly-Plus-2PM"
    #define DEVICE_NAME "Shelly Plus 2PM (PCB v0.1.9)"
    #define DEVICE_FLASH_SIZE_MB 4
    #define HW_INFO_TEXT "Shelly Plus 2PM (PCB v0.1.9): 2 Relais oder 1 Jalousie, 2 Schalteingänge, Leistungsmessung, Gerätetemperatur. KNX über WLAN."
    #define HW_INFO_URL "https://www.shelly.com"

    #define HW_RELAY_COUNT 2
    #define HW_RELAY_1_GPIO 13
    #define HW_RELAY_1_LABEL "O1"
    #define HW_RELAY_2_GPIO 12
    #define HW_RELAY_2_LABEL "O2"
    #define SHELLY_RELAY_ACTIVE_ON HIGH

    #define OPENKNX_BI_GPIO_COUNT 2
    #define OPENKNX_BI_GPIO_PINS 5, 18

    #define HW_POWER_METER
    #define SHELLY_PM_ADE7953
    #define SHELLY_I2C_SDA_GPIO 26
    #define SHELLY_I2C_SCL_GPIO 25
    #define SHELLY_ADE7953_IRQ_GPIO 27

    #define HW_TEMP_SENSOR
    #define SHELLY_NTC_GPIO 35

    #define SHELLY_BUTTON_GPIO 4
#endif

#ifdef DEVICE_SHELLY_PLUS_I4
    // ============================================================================
    // Shelly Plus i4 - 4 switch inputs, no relay
    // ============================================================================
    //   GPIO12 - Switch 1 input        GPIO27 - Switch 3 input
    //   GPIO14 - Switch 2 input        GPIO26 - Switch 4 input
    // Button / LED pins are not in the source; PROG_BUTTON_PIN stays open until measured.
    // ============================================================================
    #define DEVICE_HW_ID 0x2504
    #define DEVICE_THIRD_PARTY
    #define DEVICE_ID "Shelly-Plus-i4"
    #define DEVICE_NAME "Shelly Plus i4"
    #define DEVICE_FLASH_SIZE_MB 4
    #define HW_INFO_TEXT "Shelly Plus i4: 4 Schalteingänge, kein Relais. KNX über WLAN."
    #define HW_INFO_URL "https://www.shelly.com"

    #define HW_RELAY_COUNT 0

    #define OPENKNX_BI_GPIO_COUNT 4
    #define OPENKNX_BI_GPIO_PINS 12, 14, 27, 26 // switch order 1..4 (3 = GPIO27, 4 = GPIO26)
#endif

#pragma endregion

#pragma region "Shelly Gen3 (ESP32-C3, 8 MB flash)"

#ifdef DEVICE_SHELLY_2PM_GEN3
    // ============================================================================
    // Shelly 2PM Gen3 - 2 relays or 1 cover, 2 inputs, ADE7953
    // ============================================================================
    //   GPIO0  - ADE7953 RST           GPIO5  - Relay 2          GPIO10 - Switch input (see note)
    //   GPIO1  - ADE7953 IRQ           GPIO6  - I2C SDA          GPIO18 - Switch input (see note)
    //   GPIO2  - LED (inverted)        GPIO7  - I2C SCL          GPIO19 - Button
    //   GPIO3  - Relay 1               GPIO4  - NTC (ADC)
    // Note: the source table says GPIO10 = switch 1, GPIO18 = switch 2, its example YAML uses GPIO10
    //       for channel 2. Order of OPENKNX_BI_GPIO_PINS to be measured.
    // ============================================================================
    #define DEVICE_HW_ID 0x2510
    #define DEVICE_THIRD_PARTY
    #define DEVICE_ID "Shelly-2PM-Gen3"
    #define DEVICE_NAME "Shelly 2PM Gen3"
    #define DEVICE_FLASH_SIZE_MB 8
    #define HW_INFO_TEXT "Shelly 2PM Gen3: 2 Relais oder 1 Jalousie, 2 Schalteingänge, Leistungsmessung, Gerätetemperatur. KNX über WLAN."
    #define HW_INFO_URL "https://www.shelly.com"

    #define HW_RELAY_COUNT 2
    #define HW_RELAY_1_GPIO 3
    #define HW_RELAY_1_LABEL "O1"
    #define HW_RELAY_2_GPIO 5
    #define HW_RELAY_2_LABEL "O2"
    #define SHELLY_RELAY_ACTIVE_ON HIGH

    #define OPENKNX_BI_GPIO_COUNT 2
    #define OPENKNX_BI_GPIO_PINS 10, 18

    #define HW_POWER_METER
    #define SHELLY_PM_ADE7953
    #define SHELLY_I2C_SDA_GPIO 6
    #define SHELLY_I2C_SCL_GPIO 7
    #define SHELLY_ADE7953_IRQ_GPIO 1
    #define SHELLY_ADE7953_RST_GPIO 0

    #define HW_TEMP_SENSOR
    #define SHELLY_NTC_GPIO 4

    #define SHELLY_BUTTON_GPIO 19
#endif

#ifdef DEVICE_SHELLY_PLUG_S_GEN3
    // ============================================================================
    // Shelly Plug S MTR Gen3 - plug, 1 relay, power metering (BL0942 UART), RGB ring (WS2812)
    // ============================================================================
    //   GPIO3  - NTC (ADC)             GPIO6  - BL0942 TX (to ESP RX)
    //   GPIO4  - Relay                 GPIO7  - BL0942 RX (from ESP TX)
    //   GPIO5  - LED ring WS2812       GPIO18 - Button (inverted)
    // First flash only over UART (plug has to be opened), no OTA from the stock firmware.
    // ============================================================================
    #define DEVICE_HW_ID 0x2511
    #define DEVICE_THIRD_PARTY
    #define DEVICE_ID "Shelly-Plug-S-Gen3"
    #define DEVICE_NAME "Shelly Plug S MTR Gen3"
    #define DEVICE_FLASH_SIZE_MB 8
    #define HW_INFO_TEXT "Shelly Plug S MTR Gen3: Zwischenstecker, 1 Relais, Leistungsmessung, Gerätetemperatur, LED-Ring. KNX über WLAN."
    #define HW_INFO_URL "https://www.shelly.com"

    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO 4
    #define HW_RELAY_1_LABEL "O1"
    #define SHELLY_RELAY_ACTIVE_ON HIGH

    // no OPENKNX_BI_GPIO_COUNT: no wired input (the button is the prog button), generator default 0

    #define HW_POWER_METER
    #define SHELLY_PM_BL0942
    #define SHELLY_BL0942_RX_GPIO 6 // ESP RX
    #define SHELLY_BL0942_TX_GPIO 7 // ESP TX

    #define HW_TEMP_SENSOR
    #define SHELLY_NTC_GPIO 3

    #define SHELLY_LED_RING_GPIO 5 // WS2812, not a plain prog LED

    #define SHELLY_BUTTON_GPIO 18
#endif

#pragma endregion

#pragma region "Shelly common (all devices above)"

#if defined(DEVICE_HW_ID) && (DEVICE_HW_ID >= 0x2500) && (DEVICE_HW_ID <= 0x25FF)
    // no KNX TP transceiver on a Shelly: KNX over IP, WiFi unless the env chooses otherwise
    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_WIFI
    #endif

    // prog button = the device button (Plus 1/1PM: GPIO25, the other devices set SHELLY_BUTTON_GPIO)
    #ifndef SHELLY_BUTTON_GPIO
        #if defined(DEVICE_SHELLY_PLUS_1) || defined(DEVICE_SHELLY_PLUS_1PM)
            #define SHELLY_BUTTON_GPIO 25
        #endif
    #endif
    #if !defined(PROG_BUTTON_PIN) && defined(SHELLY_BUTTON_GPIO)
        #define PROG_BUTTON_PIN SHELLY_BUTTON_GPIO
        #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING // inverted, pull-up
    #endif

    // prog LED = the status LED (Plus: GPIO0, 2PM Gen3: GPIO2, both inverted); Plug S Gen3 has only the WS2812 ring
    #ifndef PROG_LED_PIN
        #if defined(DEVICE_SHELLY_PLUS_1) || defined(DEVICE_SHELLY_PLUS_1PM) || defined(DEVICE_SHELLY_PLUS_2PM_V015) || defined(DEVICE_SHELLY_PLUS_2PM_V019)
            #define PROG_LED_PIN 0 // strapping pin, output only after boot
            #define PROG_LED_PIN_ACTIVE_ON LOW
        #elif defined(DEVICE_SHELLY_2PM_GEN3)
            #define PROG_LED_PIN 2 // strapping pin
            #define PROG_LED_PIN_ACTIVE_ON LOW
        #else
            #define PROG_LED_PIN (-1) // no plain LED (i4: not documented, Plug S Gen3: WS2812 ring)
            #define PROG_LED_PIN_ACTIVE_ON HIGH
        #endif
    #endif

    #ifndef SERIAL_DEBUG
        #define SERIAL_DEBUG Serial
    #endif
#endif

#pragma endregion

/*
 * ============================================================================
 * Examples
 * ============================================================================
 *
 * 1) Register the header (include/HardwareConfig.h, next to the other vendors):
 *        #include "HardwareConfig/Others/Shelly/Devices.h"
 *
 * 2) PlatformIO env per device (platformio.custom.ini of the OAM):
 *        [env:release_SHELLY_PLUS_2PM]
 *        extends = <ESP32 release base env of the OAM>   ; Gen3 = ESP32-C3, 8 MB
 *        build_flags = ${RELEASE.build_flags} -D DEVICE_SHELLY_PLUS_2PM_V019
 *
 * 3) Firmware: map the generic defines to the modules of the OAM (include/hardware.h):
 *        #define OPENKNX_SWA_CHANNEL_COUNT HW_RELAY_COUNT
 *        #if HW_RELAY_COUNT == 1
 *            #define OPENKNX_SWA_SET_PINS HW_RELAY_1_GPIO
 *        #elif HW_RELAY_COUNT == 2
 *            #define OPENKNX_SWA_SET_PINS HW_RELAY_1_GPIO, HW_RELAY_2_GPIO
 *        #endif
 *        #define OPENKNX_SWA_SET_ACTIVE_ON SHELLY_RELAY_ACTIVE_ON
 *        // OFM-SwitchActuator (OpenKNX main) drives SET + RESET pins (bistable relays); the Shelly relays
 *        // are monostable (one pin), so the OFM needs a one-pin mode or the OAM keeps its own relay driver
 *        // OPENKNX_BI_GPIO_PINS / _COUNT come from this header unchanged
 *
 *        #ifdef HW_POWER_METER          // one #if per chip, not per device
 *          #if defined(SHELLY_PM_ADE7953)  ... I2C SHELLY_I2C_SDA_GPIO / SHELLY_I2C_SCL_GPIO
 *          #elif defined(SHELLY_PM_BL0937) ... CF / CF1 / SEL
 *          #elif defined(SHELLY_PM_BL0942) ... UART SHELLY_BL0942_RX_GPIO / _TX_GPIO
 *          #endif
 *        #endif
 *
 * 4) ETS: the manifest (HardwareProfile.xml) turns the same defines into feature flags:
 *        <Value name="Relays" text="Schaltkanäle" expr="HW_RELAY_COUNT" default="0" max="16" />
 *        <Capability name="PowerMeter"  text="Leistungsmessung" expr="defined(HW_POWER_METER)" />
 *        <Capability name="Temperature" text="Gerätetemperatur" expr="defined(HW_TEMP_SENSOR)" />
 *    and in the module XML:
 *        <choose ParamRefId="%HWP_SelectRef%">          <!-- one choose per feature -->
 *          <when test="%HWP_VAL_Relays_GE_1%"> ... switch actuator channels ... </when>
 *        </choose>
 *        <choose ParamRefId="%HWP_SelectRef%">
 *          <when test="%HWP_VAL_Relays_GE_2%"> ... cover (SHC) ... </when>
 *        </choose>
 *        <choose ParamRefId="%HWP_SelectRef%">
 *          <when test="%HWP_VAL_BinaryInputs_GE_1%"> ... binary inputs ... </when>
 *        </choose>
 *        <choose ParamRefId="%HWP_SelectRef%">
 *          <when test="%HWP_CAP_PowerMeter%"> ... power / energy KOs ... </when>
 *        </choose>
 *    Boards in the manifest: <Board define="DEVICE_SHELLY_PLUS_1" /> ... or <Boards platformio="release_*" />
 */
