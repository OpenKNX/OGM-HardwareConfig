#pragma once
/**
 * QuinLED Hardware definition header file
 *
 * File: QuinLed.h
 * Hardware: QuinLED
 * Responsible: u20p17
 *
 * ATTENTION:
 *    Do not include this file directly.
 *    It will be included by the HardwareConfig.h file.
 */

#pragma region "QuinLED Controllers"

#if defined(DEVICE_QUINLED_DIG_UNO_V3) && !defined(DEVICE_QUINLED_DIG_UNO_V3_WIFI) && !defined(DEVICE_QUINLED_DIG_UNO_V3_ETHERNET) && !defined(DEVICE_QUINLED_DIG_UNO_V3_WIFI_AE_PLUS)
    #if defined(KNX_IP_LAN)
        #define DEVICE_QUINLED_DIG_UNO_V3_ETHERNET
    #elif defined(QUINLED_ESP32_AE_PLUS) && QUINLED_ESP32_AE_PLUS
        #define DEVICE_QUINLED_DIG_UNO_V3_WIFI_AE_PLUS
    #else
        #define DEVICE_QUINLED_DIG_UNO_V3_WIFI
    #endif
#endif

#if defined(DEVICE_QUINLED_DIG_QUAD_V3) && !defined(DEVICE_QUINLED_DIG_QUAD_V3_WIFI) && !defined(DEVICE_QUINLED_DIG_QUAD_V3_ETHERNET) && !defined(DEVICE_QUINLED_DIG_QUAD_V3_WIFI_AE_PLUS)
    #if defined(KNX_IP_LAN)
        #define DEVICE_QUINLED_DIG_QUAD_V3_ETHERNET
    #elif defined(QUINLED_ESP32_AE_PLUS) && QUINLED_ESP32_AE_PLUS
        #define DEVICE_QUINLED_DIG_QUAD_V3_WIFI_AE_PLUS
    #else
        #define DEVICE_QUINLED_DIG_QUAD_V3_WIFI
    #endif
#endif

#if defined(DEVICE_QUINLED_DIG_OCTA_32_8L) && !defined(DEVICE_QUINLED_DIG_OCTA_32_8L_WIFI) && !defined(DEVICE_QUINLED_DIG_OCTA_32_8L_ETHERNET)
    #if defined(KNX_IP_WIFI)
        #define DEVICE_QUINLED_DIG_OCTA_32_8L_WIFI
    #else
        #define DEVICE_QUINLED_DIG_OCTA_32_8L_ETHERNET
    #endif
#endif

#if defined(DEVICE_QUINLED_DIG2GO) ||                   \
    defined(DEVICE_QUINLED_DIG_NEXT2) ||                \
    defined(DEVICE_QUINLED_DIG_UNO_V3_WIFI) ||          \
    defined(DEVICE_QUINLED_DIG_UNO_V3_ETHERNET) ||      \
    defined(DEVICE_QUINLED_DIG_UNO_V3_WIFI_AE_PLUS) ||  \
    defined(DEVICE_QUINLED_DIG_QUAD_V3_WIFI) ||         \
    defined(DEVICE_QUINLED_DIG_QUAD_V3_ETHERNET) ||     \
    defined(DEVICE_QUINLED_DIG_QUAD_V3_WIFI_AE_PLUS) || \
    defined(DEVICE_QUINLED_DIG_OCTA_32_8L_WIFI) ||      \
    defined(DEVICE_QUINLED_DIG_OCTA_32_8L_ETHERNET)
    #ifndef SERIAL_DEBUG
        #define SERIAL_DEBUG Serial
    #endif

    #ifndef PROG_LED_PIN
        #define PROG_LED_PIN (-1)
        #ifndef PROG_LED_PIN_ACTIVE_ON
            #define PROG_LED_PIN_ACTIVE_ON HIGH
        #endif
    #endif
#endif

#ifdef DEVICE_QUINLED_DIG2GO
    #define DEVICE_HW_ID 0x2100
    #define DEVICE_ID "QuinLED-Dig2Go"
    #define DEVICE_NAME "QuinLED Dig2Go"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_WIFI
    #endif
    #if !defined(QUINLED_HAS_IR)
        #define QUINLED_HAS_IR 0
    #endif
    #if !defined(QUINLED_HAS_AUDIO_INPUT)
        #define QUINLED_HAS_AUDIO_INPUT 0
    #endif

    #define QUINLED_LED_PORT_COUNT 1
    #define QUINLED_RELAY_COUNT 1

    #define QUINLED_BUTTON_GPIO 0     // Touch button
    #define QUINLED_RELAY1_GPIO 12    // LED Relay enable pin
    #define QUINLED_IR_GPIO 5         // Infra-Red Receiver
    #define QUINLED_LED_DATA1_GPIO 16 // LED Data output
    #define QUINLED_I2S_SD_GPIO 19    // Microphone SD
    #define QUINLED_I2S_WS_GPIO 4     // Microphone WS
    #define QUINLED_I2S_SCK_GPIO 18   // Microphone SCK
    #define QUINLED_EXTRA1_GPIO 21    // Free use (or I2C SDA)
    #define QUINLED_EXTRA2_GPIO 22    // Free use (or I2C SCL)
    #define QUINLED_EXTRA3_GPIO 23    // Extra
    #define QUINLED_EXTRA4_GPIO 25    // Extra (Has ADC function)
    #define QUINLED_I2C_SCL_GPIO QUINLED_EXTRA2_GPIO
    #define QUINLED_I2C_SDA_GPIO QUINLED_EXTRA1_GPIO
    #define QUINLED_ADC_GPIO QUINLED_EXTRA4_GPIO

    #ifndef PROG_BUTTON_PIN
        #define PROG_BUTTON_PIN QUINLED_BUTTON_GPIO
    #endif
#endif

#ifdef DEVICE_QUINLED_DIG_NEXT2
    #define DEVICE_HW_ID 0x2140
    #define DEVICE_ID "QuinLED-Dig-Next-2"
    #define DEVICE_NAME "QuinLED Dig-Next 2"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_WIFI
    #endif
    #if !defined(QUINLED_HAS_AUDIO_INPUT)
        #define QUINLED_HAS_AUDIO_INPUT 1
    #endif

    #define QUINLED_LED_PORT_COUNT 2
    #define QUINLED_RELAY_COUNT 1

    #define QUINLED_BUTTON_GPIO 34   // Button 1 input
    #define QUINLED_BUTTON2_GPIO 35  // Button 2 input
    #define QUINLED_RELAY1_GPIO 5    // External relay output
    #define QUINLED_Q1_GPIO 0        // QEXT yellow
    #define QUINLED_Q2_GPIO 25       // QEXT green
    #define QUINLED_Q3_GPIO 32       // QEXT blue
    #define QUINLED_Q4_GPIO 33       // QEXT white
    #define QUINLED_LED_DATA1_GPIO 2 // LED1 output
    #define QUINLED_LED_DATA2_GPIO 4 // LED2 output
    #define QUINLED_EXTRA1_GPIO 20   // 5A_1 output
    #define QUINLED_EXTRA2_GPIO 21   // 10A_1 output
    #define QUINLED_EXTRA3_GPIO 22   // 5A_2 output
    #define QUINLED_I2S_SD_GPIO 7    // Microphone SD (I2S PDM)
    #define QUINLED_I2S_WS_GPIO 8    // Microphone WS (I2S PDM)
    #define QUINLED_I2C_SDA_GPIO 15  // I2C SDA
    #define QUINLED_I2C_SCL_GPIO 14  // I2C SCL

    #ifndef PROG_BUTTON_PIN
        #define PROG_BUTTON_PIN QUINLED_BUTTON_GPIO
    #endif
#endif

#if defined(DEVICE_QUINLED_DIG_UNO_V3_WIFI)
    #define DEVICE_HW_ID 0x2110
    #define DEVICE_ID "QuinLED-Dig-Uno-V3-WiFi"
    #define DEVICE_NAME "QuinLED Dig-Uno V3 (WiFi)"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_WIFI
    #endif
    #define QUINLED_HAS_ETHERNET 0
    #define QUINLED_ESP32_AE_PLUS 0
    #define QUINLED_HAS_AUDIO_INPUT 0
#elif defined(DEVICE_QUINLED_DIG_UNO_V3_ETHERNET)
    #define DEVICE_HW_ID 0x2111
    #define DEVICE_ID "QuinLED-Dig-Uno-V3-Ethernet"
    #define DEVICE_NAME "QuinLED Dig-Uno V3 (Ethernet)"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_LAN
    #endif
    #define QUINLED_HAS_ETHERNET 1
    #define QUINLED_ESP32_AE_PLUS 0
    #define QUINLED_HAS_AUDIO_INPUT 0
#elif defined(DEVICE_QUINLED_DIG_UNO_V3_WIFI_AE_PLUS)
    #define DEVICE_HW_ID 0x2112
    #define DEVICE_ID "QuinLED-Dig-Uno-V3-WiFi-AE-Plus"
    #define DEVICE_NAME "QuinLED Dig-Uno V3 (WiFi + AE_Plus)"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_WIFI
    #endif
    #define QUINLED_HAS_ETHERNET 0
    #define QUINLED_ESP32_AE_PLUS 1
    #define QUINLED_HAS_AUDIO_INPUT 1
#endif

#if defined(DEVICE_QUINLED_DIG_UNO_V3_WIFI) || defined(DEVICE_QUINLED_DIG_UNO_V3_ETHERNET) || defined(DEVICE_QUINLED_DIG_UNO_V3_WIFI_AE_PLUS)

    #define QUINLED_LED_PORT_COUNT 2
    #define QUINLED_RELAY_COUNT 1

    #define QUINLED_BUTTON_GPIO 0 // WLED button (pulled high)
    #define QUINLED_Q1_GPIO 15    // Dedicated external GPIO Q1 (can be pulled low)
    #define QUINLED_Q2_GPIO 12    // Dedicated external GPIO Q2 (can be pulled low)
    #define QUINLED_Q3_GPIO 2     // Dedicated external GPIO Q3 (can be pulled high)
    #define QUINLED_Q4_GPIO 32    // Dedicated external GPIO Q4 (can be pulled high)

    #if QUINLED_HAS_ETHERNET
        #define QUINLED_ETHERNET_POWER_GPIO 5   // Ethernet PHY enable
        #define QUINLED_ETHERNET_MDC_GPIO 23    // Ethernet MDC
        #define QUINLED_ETHERNET_MDIO_GPIO 18   // Ethernet MDIO
        #define QUINLED_ETHERNET_TXD0_GPIO 19   // Ethernet TXD0
        #define QUINLED_ETHERNET_TX_EN_GPIO 21  // Ethernet TX_EN
        #define QUINLED_ETHERNET_TXD1_GPIO 22   // Ethernet TXD1
        #define QUINLED_ETHERNET_RXD0_GPIO 25   // Ethernet RXD0
        #define QUINLED_ETHERNET_RXD1_GPIO 26   // Ethernet RXD1
        #define QUINLED_ETHERNET_CRS_DV_GPIO 27 // Ethernet CRS_DV
        #define QUINLED_ETHERNET_CLK_MODE 17    // Ethernet clock mode
    #endif
    #if QUINLED_ESP32_AE_PLUS
        #define QUINLED_HAS_AUDIO_INPUT 1
        #define QUINLED_BUTTON_GPIO 33     // Touch button
        #define QUINLED_IR_GPIO 26         // Infra-Red Receiver
        #define QUINLED_LED_DATA6_GPIO 21  // LED6 output (AE+ pinout)
        #define QUINLED_LED_DATA7_GPIO 17  // LED7 output (AE+ pinout)
        #define QUINLED_LED_DATA8_GPIO 22  // LED8 output (AE+ pinout)
        #define QUINLED_I2S_WS_GPIO 27     // Microphone WS
        #define QUINLED_I2S_SD_GPIO 25     // Microphone SD
        #define QUINLED_I2S_SCK_GPIO 32    // Microphone SCK
        #define QUINLED_SDCARD_CLK_GPIO 18 // SD card CLK
        #define QUINLED_SDCARD_DI_GPIO 23  // SD card DI / MOSI
        #define QUINLED_SDCARD_CS_GPIO 5   // SD card CS
        #define QUINLED_SDCARD_DO_GPIO 19  // SD card DO / MISO
    #endif
    #define QUINLED_DS18B20_GPIO 13   // Onboard temperature sensor
    #define QUINLED_ADC_GPIO 36       // A0 analog audio input (SVP)
    #define QUINLED_LED_DATA1_GPIO 16 // LED1 output (QuinLED-ESP32 mapping)
    #define QUINLED_LED_DATA2_GPIO 3  // LED2 output (QuinLED-ESP32 mapping)

    #define QUINLED_RELAY1_GPIO QUINLED_Q1_GPIO
    #define QUINLED_EXTRA1_GPIO QUINLED_Q2_GPIO
    #define QUINLED_EXTRA2_GPIO QUINLED_Q3_GPIO
    #define QUINLED_EXTRA3_GPIO QUINLED_Q4_GPIO
    #define QUINLED_TEMP_SENSOR_GPIO QUINLED_DS18B20_GPIO
    #define QUINLED_AUDIO_INPUT_GPIO QUINLED_ADC_GPIO

    #ifndef PROG_BUTTON_PIN
        #define PROG_BUTTON_PIN QUINLED_BUTTON_GPIO
    #endif
#endif

#if defined(DEVICE_QUINLED_DIG_QUAD_V3_WIFI)
    #define DEVICE_HW_ID 0x2120
    #define DEVICE_ID "QuinLED-Dig-Quad-V3-WiFi"
    #define DEVICE_NAME "QuinLED Dig-Quad V3 (WiFi)"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_WIFI
    #endif
    #define QUINLED_HAS_ETHERNET 0
    #define QUINLED_ESP32_AE_PLUS 0
    #define QUINLED_HAS_AUDIO_INPUT 0
#elif defined(DEVICE_QUINLED_DIG_QUAD_V3_ETHERNET)
    #define DEVICE_HW_ID 0x2121
    #define DEVICE_ID "QuinLED-Dig-Quad-V3-Ethernet"
    #define DEVICE_NAME "QuinLED Dig-Quad V3 (Ethernet)"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_LAN
    #endif
    #define QUINLED_HAS_ETHERNET 1
    #define QUINLED_ESP32_AE_PLUS 0
    #define QUINLED_HAS_AUDIO_INPUT 0
#elif defined(DEVICE_QUINLED_DIG_QUAD_V3_WIFI_AE_PLUS)
    #define DEVICE_HW_ID 0x2122
    #define DEVICE_ID "QuinLED-Dig-Quad-V3-WiFi-AE-Plus"
    #define DEVICE_NAME "QuinLED Dig-Quad V3 (WiFi + AE_Plus)"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_WIFI
    #endif
    #define QUINLED_HAS_ETHERNET 0
    #define QUINLED_ESP32_AE_PLUS 1
    #define QUINLED_HAS_AUDIO_INPUT 1
#endif

#if defined(DEVICE_QUINLED_DIG_QUAD_V3_WIFI) || defined(DEVICE_QUINLED_DIG_QUAD_V3_ETHERNET) || defined(DEVICE_QUINLED_DIG_QUAD_V3_WIFI_AE_PLUS)

    #if QUINLED_HAS_ETHERNET
        #define QUINLED_ETHERNET_POWER_GPIO 5   // Ethernet PHY enable
        #define QUINLED_ETHERNET_MDC_GPIO 23    // Ethernet MDC
        #define QUINLED_ETHERNET_MDIO_GPIO 18   // Ethernet MDIO
        #define QUINLED_ETHERNET_TXD0_GPIO 19   // Ethernet TXD0
        #define QUINLED_ETHERNET_TX_EN_GPIO 21  // Ethernet TX_EN
        #define QUINLED_ETHERNET_TXD1_GPIO 22   // Ethernet TXD1
        #define QUINLED_ETHERNET_RXD0_GPIO 25   // Ethernet RXD0
        #define QUINLED_ETHERNET_RXD1_GPIO 26   // Ethernet RXD1
        #define QUINLED_ETHERNET_CRS_DV_GPIO 27 // Ethernet CRS_DV
        #define QUINLED_ETHERNET_CLK_MODE 17    // Ethernet clock mode
    #endif
    #if QUINLED_ESP32_AE_PLUS
        #define QUINLED_HAS_AUDIO_INPUT 1
        #define QUINLED_BUTTON_GPIO 33     // Touch button
        #define QUINLED_IR_GPIO 26         // Infra-Red Receiver
        #define QUINLED_LED_DATA5_GPIO 21  // LED5 output (AE+ pinout)
        #define QUINLED_LED_DATA6_GPIO 17  // LED6 output (AE+ pinout)
        #define QUINLED_LED_DATA7_GPIO 22  // LED7 output (AE+ pinout)
        #define QUINLED_I2S_WS_GPIO 27     // Microphone WS
        #define QUINLED_I2S_SD_GPIO 25     // Microphone SD
        #define QUINLED_I2S_SCK_GPIO 32    // Microphone SCK
        #define QUINLED_SDCARD_CLK_GPIO 18 // SD card CLK
        #define QUINLED_SDCARD_DI_GPIO 23  // SD card DI / MOSI
        #define QUINLED_SDCARD_CS_GPIO 5   // SD card CS
        #define QUINLED_SDCARD_DO_GPIO 19  // SD card DO / MISO
    #endif

    #define QUINLED_LED_PORT_COUNT 4
    #define QUINLED_RELAY_COUNT 1

    #define QUINLED_BUTTON_GPIO 0 // WLED Button (is pulled high)
    #define QUINLED_IR_GPIO (-1)
    #define QUINLED_Q1_GPIO 15        // Relais
    #define QUINLED_Q2_GPIO 12        // External GPIO (can be pulled low)
    #define QUINLED_Q3_GPIO 2         // External GPIO (can be pulled high)
    #define QUINLED_Q4_GPIO 4         // External GPIO (can be pulled high)
    #define QUINLED_LED_DATA1_GPIO 16 // LED1 output
    #define QUINLED_LED_DATA2_GPIO 3  // LED2 output
    #define QUINLED_LED_DATA3_GPIO 1  // LED3 output
    #define QUINLED_LED_DATA4_GPIO 4  // LED4 output

    #define QUINLED_RELAY1_GPIO QUINLED_Q1_GPIO // External GPIO (can be pulled low)

    #define QUINLED_TEMPERATURE_SENSOR_1WIRE_GPIO 13 // Onboard Tempsensor DS18B20
    #define QUINLED_AUDIO_INPUT_GPIO 36              // A0 analog audio input (SVP)

    #ifndef PROG_BUTTON_PIN
        #define PROG_BUTTON_PIN QUINLED_BUTTON_GPIO
    #endif
#endif

#if defined(DEVICE_QUINLED_DIG_OCTA_32_8L_ETHERNET)
    #define DEVICE_HW_ID 0x2130
    #define DEVICE_ID "QuinLED-Dig-Octa-32-8L-Ethernet"
    #define DEVICE_NAME "QuinLED Dig-Octa 32-8L (Ethernet)"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_LAN
    #endif
    #define QUINLED_HAS_ETHERNET 1
#elif defined(DEVICE_QUINLED_DIG_OCTA_32_8L_WIFI)
    #define DEVICE_HW_ID 0x2131
    #define DEVICE_ID "QuinLED-Dig-Octa-32-8L-WiFi"
    #define DEVICE_NAME "QuinLED Dig-Octa 32-8L (WiFi)"

    #if !defined(KNX_IP_LAN) && !defined(KNX_IP_WIFI)
        #define KNX_IP_WIFI
    #endif
    #define QUINLED_HAS_ETHERNET 0
#endif

#if defined(DEVICE_QUINLED_DIG_OCTA_32_8L_ETHERNET) || defined(DEVICE_QUINLED_DIG_OCTA_32_8L_WIFI)

    #define QUINLED_LED_PORT_COUNT 8
    #define QUINLED_RELAY_COUNT 1

    #if QUINLED_HAS_ETHERNET
        #define QUINLED_ETHERNET_CLK_OUT_GPIO 17 // Ethernet Clock Out
        #define QUINLED_ETHERNET_MDIO_GPIO 18    // Ethernet MDIO
        #define QUINLED_ETHERNET_TXD0_GPIO 19    // Ethernet TXD0
        #define QUINLED_ETHERNET_TXEN_GPIO 21    // Ethernet TXEN
        #define QUINLED_ETHERNET_TXD1_GPIO 22    // Ethernet TXD1
        #define QUINLED_ETHERNET_MDC_GPIO 23     // Ethernet MDC
        #define QUINLED_ETHERNET_RXD0_GPIO 25    // Ethernet RXD0
        #define QUINLED_ETHERNET_RXD1_GPIO 26    // Ethernet RXD1
        #define QUINLED_ETHERNET_CRS_DV_GPIO 27  // Ethernet CRS_DV
    #endif

    #define QUINLED_BUTTON1_GPIO 34 // Connecting button/switch
    #define QUINLED_BUTTON2_GPIO 35 // Connecting button/switch
    #define QUINLED_RELAY1_GPIO 33  // Relay Trigger
    #define QUINLED_IR_GPIO (-1)
    #define QUINLED_LED_DATA1_GPIO 0   // LED1 Data output channel
    #define QUINLED_LED_DATA2_GPIO 1   // LED2 Data output channel
    #define QUINLED_LED_DATA3_GPIO 2   // LED3 Data output channel
    #define QUINLED_LED_DATA4_GPIO 3   // LED4 Data output channel
    #define QUINLED_LED_DATA5_GPIO 4   // LED5 Data output channel
    #define QUINLED_LED_DATA6_GPIO 5   // LED6 Data output channel
    #define QUINLED_LED_DATA7_GPIO 12  // LED7 Data output channel
    #define QUINLED_LED_DATA8_GPIO 13  // LED8 Data output channel, *Shared with I2C
    #define QUINLED_I2C_SDA_GPIO 32    // I2C SDA
    #define QUINLED_I2C_SCL_GPIO 13    // I2C SCL (shared with LED8)
    #define QUINLED_SDCARD_CLK_GPIO 14 // SD card CLK, *also available on pin header v2r2+
    #define QUINLED_SDCARD_DI_GPIO 15  // SD card MOSI, *also available on pin header v2r2+
    #define QUINLED_SDCARD_CS_GPIO 16  // SD card CS, *also available on pin header v2r2+
    #define QUINLED_SDCARD_DO_GPIO 36  // SD card MISO

    #ifndef PROG_BUTTON_PIN
        #define PROG_BUTTON_PIN QUINLED_BUTTON1_GPIO
    #endif
#endif

#if defined(QUINLED_HAS_ETHERNET) && QUINLED_HAS_ETHERNET
    #ifndef ETH_PHY_TYPE
        #define ETH_PHY_TYPE ETH_PHY_LAN8720
    #endif
    #ifndef ETH_PHY_ADDR
        #define ETH_PHY_ADDR 0
    #endif
    #ifndef ETH_PHY_MDC
        #define ETH_PHY_MDC QUINLED_ETHERNET_MDC_GPIO
    #endif
    #ifndef ETH_PHY_MDIO
        #define ETH_PHY_MDIO QUINLED_ETHERNET_MDIO_GPIO
    #endif
    #ifndef ETH_PHY_POWER
        #ifdef QUINLED_ETHERNET_POWER_GPIO
            #define ETH_PHY_POWER QUINLED_ETHERNET_POWER_GPIO
        #else
            #define ETH_PHY_POWER (-1)
        #endif
    #endif
    #ifndef ETH_CLK_MODE
        #if defined(QUINLED_ETHERNET_CLK_OUT_GPIO) && (QUINLED_ETHERNET_CLK_OUT_GPIO == 17)
            #define ETH_CLK_MODE ETH_CLOCK_GPIO17_OUT
        #elif defined(QUINLED_ETHERNET_CLK_MODE) && (QUINLED_ETHERNET_CLK_MODE == 17)
            #define ETH_CLK_MODE ETH_CLOCK_GPIO17_OUT
        #else
            #error Unsupported QuinLED Ethernet clock mode
        #endif
    #endif
#endif

#pragma endregion
