#pragma once
/**
 * OpenKNX Hardware definition header file
 *
 * File: Others/Gledopto/Devices.h
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

#ifdef DEVICE_GL_C_309WL
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
    #define GLEDOPTO_RELAIS1_GPIO 12   // I/O port (no relay on the board)
                                       // #define GLEDOPTO_GPIO 33         // Note: GPIO33 is input-only on ESP32-WROOM-32
                                       //  -----------------------------------------------------------------

    #define DEVICE_HW_ID 0x2000
    #define HW_INFO_LOGO "HardwareConfig/Others/Gledopto/logo.png" // device card picture (<InfoImage>), found like an #include
    #define DEVICE_THIRD_PARTY // third-party hardware, no OpenKNX support
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

#ifdef DEVICE_GL_C_017WL
// ============================================================================
// Gledopto GL-C-017WL - ESP32 controller with 4 LED outputs and 2 relais
// ============================================================================
// Chip: ESP32, WiFi 2.4 GHz
//
// IO-Port map:
//   GPIO16 - LED data output 1
//   GPIO12 - LED data output 2
//   GPIO4  - LED data output 3
//   GPIO2  - LED data output 4
//   GPIO13 - Relais output 1
//   GPIO18 - Onboard relais
// ============================================================================

    #define GLEDOPTO_BUTTON_GPIO 17    // Function button
    #define GLEDOPTO_LED_DATA1_GPIO 16 // LED data output 1
    #define GLEDOPTO_LED_DATA2_GPIO 12 // LED data output 2
    #define GLEDOPTO_LED_DATA3_GPIO 4  // LED data output 3
    #define GLEDOPTO_LED_DATA4_GPIO 2  // LED data output 4
    #define GLEDOPTO_RELAIS1_GPIO 13   // extension GPIO port (free use, e.g. external relay)
    #define GLEDOPTO_RELAIS2_GPIO 18   // Onboard relais

    #define GLEDOPTO_MIC_SD_GPIO 32
    #define GLEDOPTO_MIC_WS_GPIO 15

    #define DEVICE_HW_ID 0x2001
    #define HW_INFO_LOGO "HardwareConfig/Others/Gledopto/logo.png" // device card picture (<InfoImage>), found like an #include
    #define HW_INFO_TEXT "ESP32-Controller von Gledopto mit 4 LED-Ausgängen und eingebautem Relais (IO18). KNX über IP per WLAN." // board description on the ETS hardware page (max. 255 characters)
    #define DEVICE_THIRD_PARTY // third-party hardware, no OpenKNX support
    #define DEVICE_ID "GL-C-017WL"
    #define DEVICE_NAME "Gledopto GL-C-017WL ESP32"

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

#ifdef DEVICE_GL_C_620WL
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
    #define GLEDOPTO_ETHERNET_CLK_IN_GPIO 0 // RMII clock input of ETH_CLOCK_GPIO0_IN

    #define DEVICE_HW_ID 0x2002
    #define HW_INFO_LOGO "HardwareConfig/Others/Gledopto/logo.png" // device card picture (<InfoImage>), found like an #include
    #define DEVICE_THIRD_PARTY // third-party hardware, no OpenKNX support
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

/**
 * Section: Port description
 * HW_PORT_COUNT, HW_PORT_<n>_GPIO and HW_PORT_<n>_LABEL name the outputs an application may offer
 * as ports, in this order. Read by the firmware and by OGM-HardwareConfig/generator.
 */
#pragma region Port description

#if defined(DEVICE_GL_C_309WL)
    #define HW_PORT_COUNT 3
    #define HW_PORT_1_GPIO GLEDOPTO_LED_DATA1_GPIO
    #define HW_PORT_1_LABEL "IO16 (LED Primary)"
    #define HW_PORT_2_GPIO GLEDOPTO_LED_DATA2_GPIO
    #define HW_PORT_2_LABEL "IO2 (LED Secondary)"
    #define HW_PORT_3_GPIO GLEDOPTO_RELAIS1_GPIO
    #define HW_PORT_3_LABEL "IO12 (Relais)"
#elif defined(DEVICE_GL_C_017WL)
    #define HW_PORT_COUNT 6
    #define HW_PORT_1_GPIO GLEDOPTO_LED_DATA1_GPIO
    #define HW_PORT_1_LABEL "IO16 (LED 1)"
    #define HW_PORT_2_GPIO GLEDOPTO_LED_DATA2_GPIO
    #define HW_PORT_2_LABEL "IO12 (LED 2)"
    #define HW_PORT_3_GPIO GLEDOPTO_LED_DATA3_GPIO
    #define HW_PORT_3_LABEL "IO4 (LED 3)"
    #define HW_PORT_4_GPIO GLEDOPTO_LED_DATA4_GPIO
    #define HW_PORT_4_LABEL "IO2 (LED 4)"
    #define HW_PORT_5_GPIO GLEDOPTO_RELAIS1_GPIO
    #define HW_PORT_5_LABEL "IO13 (Relais)"
    #define HW_PORT_6_GPIO GLEDOPTO_RELAIS2_GPIO
    #define HW_PORT_6_LABEL "IO18 (Onboard Relais)"
#elif defined(DEVICE_GL_C_620WL)
    #define HW_PORT_COUNT 3
    #define HW_PORT_1_GPIO GLEDOPTO_LED_DATA1_GPIO
    #define HW_PORT_1_LABEL "IO16 (LED 1)"
    #define HW_PORT_2_GPIO GLEDOPTO_LED_DATA2_GPIO
    #define HW_PORT_2_LABEL "IO2 (LED 2)"
    #define HW_PORT_3_GPIO GLEDOPTO_RELAIS1_GPIO
    #define HW_PORT_3_LABEL "IO18 (Relais)"
#endif

#pragma endregion

/**
 * Section: Relay description
 * HW_RELAY_COUNT, HW_RELAY_<n>_GPIO and HW_RELAY_<n>_LABEL name the relay outputs wired on the board (hard-wired, not
 * a free port). Read by the firmware and by OGM-HardwareConfig/generator.
 */
#pragma region Relay description

// onboard relay on IO18 of GL-C-017WL and GL-C-620WL; IO13 of GL-C-017WL and IO12 of GL-C-309WL are free ports
#if defined(DEVICE_GL_C_017WL)
    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO GLEDOPTO_RELAIS2_GPIO
    #define HW_RELAY_1_LABEL "IO18 (Onboard Relais)"
#elif defined(DEVICE_GL_C_620WL)
    #define HW_RELAY_COUNT 1
    #define HW_RELAY_1_GPIO GLEDOPTO_RELAIS1_GPIO
    #define HW_RELAY_1_LABEL "IO18 (Relais)"
#endif

#pragma endregion
