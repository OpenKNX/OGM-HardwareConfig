#pragma once
/**
 * OpenKNX Hardware definition header file
 *
 * File: Gledopto.h
 * Hardware: Gledopto
 * Responsible: u20p17
 *
 * More info about the Hardware visit: https://www.gledopto.eu/esp32-wled-digital-unterputz
 * Datasheet: https://www.gledopto.eu/mediafiles/anleitungen/7014-gl-c-309wl-gl-c-310wl-de.pdf
 *
 * ATTENTION:
 *    Do not include this file directly.
 *    It will be included by the HardwareConfig.h file.
 */

#pragma region "Gledopto Controllers"
#ifdef DEVICE_GLEDOPTO_ESP32_WLED_DIGITAL_UP
    // ============================================================================
    // Gledopto GL-C-309WL / GL-C-310WL - ESP32 WLED Digital Unterputz
    // ============================================================================
    // Product: GL-C-309WL (7014-309) without mic / GL-C-310WL (7014-310) with mic
    // Chip:    ESP32, WiFi 2.4 GHz (2402-2480 MHz), max 18 dBm
    // Power:   DC 5-24V, 6A/channel max, 10A total max
    // Size:    42 x 38 x 17 mm, IP20
    //
    // IO-Port map (from datasheet):
    //   GPIO0  - Function button (short: on/off, >=1s: color, 10s: AP mode)
    //   GPIO16 - LED data output 1 (primary / default)
    //   GPIO2  - LED data output 2 (secondary)
    //   GPIO12 - Extended GPIO signal
    //   GPIO33 - Extended GPIO signal
    // GL-C-310WL additionally:
    //   GPIO26 - I2S SD  (microphone)
    //   GPIO5  - I2S WS  (microphone)
    //   GPIO21 - I2S SCK (microphone)
    // ============================================================================

    // -----------------------------------------------------------------
    // GPIO Pin Assignments (from datasheet 7014-gl-c-309wl-gl-c-310wl)
    // -----------------------------------------------------------------
    #define GLEDOPTO_BUTTON_GPIO 0     // Function button (active LOW)
    #define GLEDOPTO_LED_DATA1_GPIO 16 // LED data output 1 (primary)
    #define GLEDOPTO_LED_DATA2_GPIO 2  // LED data output 2 (secondary)
    #define GLEDOPTO_RELAIS1_GPIO 12   // Relais output 1
                                       // #define GLEDOPTO_GPIO 33         // Note: GPIO33 is input-only on ESP32-WROOM-32
                                       //  -----------------------------------------------------------------

    #define DEVICE_HW_ID 0x2000
    #define DEVICE_ID "GL-C-309WL"
    #define DEVICE_NAME "Gledopto GL-C-309WL ESP32"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_WIFI
    #endif

    #ifndef SERIAL_DEBUG
        #define SERIAL_DEBUG Serial
    #endif

    #ifndef KNX_SERIAL
        #define KNX_SERIAL Serial1
    #endif
    #ifndef KNX_UART_NUM
        #define KNX_UART_NUM 1
    #endif
    #ifndef KNX_UART_RX_PIN
        #define KNX_UART_RX_PIN 36
    #endif
    #ifndef KNX_UART_TX_PIN
        #define KNX_UART_TX_PIN 3
    #endif

    #ifndef PROG_LED_PIN
        #define PROG_LED_PIN (-1) // No dedicated prog LED on this hardware; keep the LED object but disable GPIO access.
        #ifndef PROG_LED_PIN_ACTIVE_ON
            #define PROG_LED_PIN_ACTIVE_ON HIGH
        #endif
    #endif

    #ifndef PROG_BUTTON_PIN
        #define PROG_BUTTON_PIN GLEDOPTO_BUTTON_GPIO
    #endif

#endif

#pragma endregion
