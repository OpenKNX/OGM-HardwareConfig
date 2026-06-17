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

#ifdef DEVICE_GLEDOPTO_GL_C_620WL
// ============================================================================
// Gledopto GL-C-620WL - ESP32 LAN Controller
// ============================================================================
// Product: GL-C-620WL
// Chip:    ESP32-D0WD-V3 (Revision 3.1)
// Network: LAN8720A Ethernet PHY connected to the ESP32 RMII interface
//
// Confirmed IO-Port map:
//   GPIO13 - Programming / function button
//   GPIO16 - LED data output 1 (Strip1)
//   GPIO2  - LED data output 2 (Strip2)
//   GPIO18 - Relay output
//
// Confirmed RMII data lines: (fixed ESP32 RMII pin)
//   GPIO21 - LAN8720A TX_EN
//   GPIO26 - LAN8720A RXD1
//   GPIO25 - LAN8720A RXD0
//   GPIO22 - LAN8720A TXD1
//   GPIO19 - LAN8720A TXD0
//   GPIO27 - LAN8720A CRS_DV
// ============================================================================

    #define GLEDOPTO_BUTTON_GPIO 13
    #define GLEDOPTO_LED_DATA1_GPIO 16
    #define GLEDOPTO_LED_DATA2_GPIO 2
    #define GLEDOPTO_RELAIS1_GPIO 18

    #define GLEDOPTO_ETHERNET_TXEN_GPIO 21
    #define GLEDOPTO_ETHERNET_TXD0_GPIO 19
    #define GLEDOPTO_ETHERNET_TXD1_GPIO 22
    #define GLEDOPTO_ETHERNET_RXD0_GPIO 25
    #define GLEDOPTO_ETHERNET_RXD1_GPIO 26
    #define GLEDOPTO_ETHERNET_CRS_DV_GPIO 27

    #define GLEDOPTO_ETHERNET_MDC_GPIO 23
    #define GLEDOPTO_ETHERNET_MDIO_GPIO 33
    #define GLEDOPTO_ETHERNET_POWER_GPIO 5
    #define GLEDOPTO_ETHERNET_CLK_MODE ETH_CLOCK_GPIO0_IN

    #define DEVICE_HW_ID 0x2001
    #define DEVICE_ID "GL-C-620WL"
    #define DEVICE_NAME "Gledopto GL-C-620WL ESP32"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_LAN
    #endif

    #ifndef ETH_PHY_TYPE
        #define ETH_PHY_TYPE ETH_PHY_LAN8720
    #endif
    #ifndef ETH_PHY_ADDR
        #define ETH_PHY_ADDR 1
    #endif
    #ifndef ETH_PHY_MDC
        #define ETH_PHY_MDC GLEDOPTO_ETHERNET_MDC_GPIO
    #endif
    #ifndef ETH_PHY_MDIO
        #define ETH_PHY_MDIO GLEDOPTO_ETHERNET_MDIO_GPIO
    #endif
    #ifndef ETH_PHY_POWER
        #define ETH_PHY_POWER GLEDOPTO_ETHERNET_POWER_GPIO
    #endif
    #ifndef ETH_CLK_MODE
        #define ETH_CLK_MODE GLEDOPTO_ETHERNET_CLK_MODE
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
        #define PROG_LED_PIN (-1) // No dedicated prog LED for this hardware
        #ifndef PROG_LED_PIN_ACTIVE_ON
            #define PROG_LED_PIN_ACTIVE_ON HIGH
        #endif
    #endif

    #ifndef PROG_BUTTON_PIN
        #define PROG_BUTTON_PIN GLEDOPTO_BUTTON_GPIO
    #endif

#endif

#pragma endregion
