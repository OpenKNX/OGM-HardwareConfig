#pragma once
/**
 * OpenKNX Hardware definition header file
 *
 * File: Adafruit.h
 * Hardware: Adafruit
 * Responsible: mgeramb
 *
 *
 * More info about the Hardware visit: https://github.com/OpenKNX/OpenKNX/wiki/Adafruit-ESP32-Feather-V2
 *
 * ATTENTION:
 *    Do not include this file directly.
 *    It will be included by the HardwareConfig.h file.
 */
#pragma region "Adafruit Dev Boards"
// https://github.com/OpenKNX/OpenKNX/wiki/Adafruit-ESP32-Feather-V2
#ifdef DEVICE_ADAFRUIT_ESP32_FEATHER_V2
    #define DEVICE_ID "ADF-ESP32-FEATHER-V2"
    #define DEVICE_NAME "Adafruit ESP32 Feather V2"
    #ifndef SERIAL_DEBUG
    #define SERIAL_DEBUG Serial
    #endif
    #ifndef KNX_SERIAL
        #define KNX_SERIAL Serial1
        #define KNX_UART_NUM 0
        #ifndef KNX_UART_TX_PIN
        #define KNX_UART_RX_PIN 34
        #endif
        #ifndef KNX_UART_TX_PIN
        #define KNX_UART_TX_PIN 25
        #endif
    #endif
    #ifndef PROG_LED_PIN
        #define PROG_LED_PIN LED_BUILTIN
        #ifndef PROG_LED_PIN_ACTIVE_ON
        #define PROG_LED_PIN_ACTIVE_ON HIGH
        #endif
    #endif
    #ifndef PROG_BUTTON_PIN
        #define PROG_BUTTON_PIN 38
    #endif
    #define KNX_IP_WIFI
     
#endif
#pragma endregion