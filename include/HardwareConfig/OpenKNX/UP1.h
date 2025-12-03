#pragma once
/**
 * OpenKNX Hardware definition header file
 * 
 * File: UP1.h
 * Hardware: OpenKNX-UP1
 * Responsible: Ing-Dom
 *
 *
 * More info about the Hardware visit: https://github.com/OpenKNX/OpenKNX/wiki/OpenKNX-UP1
 *
 * ATTENTION:
 *    Do not include this file directly.
 *    It will be included by the HardwareConfig.h file.
 */

#pragma region "UP1 Geräte"

// SEN-UP1-8xTH
// https://github.com/OpenKNX/OpenKNX/wiki/UP1-SEN-8xTH
#ifdef DEVICE_SEN_UP1_8XTH
    #define DEVICE_ID "SEN-UP1-8xTH"
    #define DEVICE_NAME "OpenKNX UP1 8xSensor"

    #define OKNXHW_UP1_CONTROLLER2040

	#define OKNXHW_SENSOR_A1_SCL_PIN (29)
    #define OKNXHW_SENSOR_A2_SDA_PIN (28)
	#define OKNXHW_SENSOR_B1_SCL_PIN (27)
    #define OKNXHW_SENSOR_B2_SDA_PIN (26)
	#define OKNXHW_SENSOR_C1_SCL_PIN (25)
    #define OKNXHW_SENSOR_C2_SDA_PIN (24)
	#define OKNXHW_SENSOR_D1_SCL_PIN (23)
    #define OKNXHW_SENSOR_D2_SDA_PIN (22)
	#define OKNXHW_SENSOR_E1_SCL_PIN (21)
    #define OKNXHW_SENSOR_E2_SDA_PIN (20)
	#define OKNXHW_SENSOR_F1_SCL_PIN (19)
    #define OKNXHW_SENSOR_F2_SDA_PIN (18)
	#define OKNXHW_SENSOR_G1_SCL_PIN (17)
    #define OKNXHW_SENSOR_G2_SDA_PIN (16)
	#define OKNXHW_SENSOR_H1_SCL_PIN (15)
    #define OKNXHW_SENSOR_H2_SDA_PIN (14)
#endif

// UP1-SEN-8x
#ifdef DEVICE_UP1_SEN_8X
    #define DEVICE_ID "UP1-SEN-8x"
    #define DEVICE_NAME "OpenKNX UP1 8xSensor"

    #define OKNXHW_UP1_CONTROLLER2040

	#define OKNXHW_SENSOR_A1_SCL_PIN (29)
    #define OKNXHW_SENSOR_A2_SDA_PIN (28)
	#define OKNXHW_SENSOR_B1_SCL_PIN (27)
    #define OKNXHW_SENSOR_B2_SDA_PIN (26)
	#define OKNXHW_SENSOR_C1_SCL_PIN (25)
    #define OKNXHW_SENSOR_C2_SDA_PIN (24)
	#define OKNXHW_SENSOR_D1_SCL_PIN (23)
    #define OKNXHW_SENSOR_D2_SDA_PIN (22)
	#define OKNXHW_SENSOR_E1_SCL_PIN (21)
    #define OKNXHW_SENSOR_E2_SDA_PIN (20)
	#define OKNXHW_SENSOR_F1_SCL_PIN (19)
    #define OKNXHW_SENSOR_F2_SDA_PIN (18)
	#define OKNXHW_SENSOR_G1_SCL_PIN (17)
    #define OKNXHW_SENSOR_G2_SDA_PIN (16)
	#define OKNXHW_SENSOR_H1_SCL_PIN (15)
    #define OKNXHW_SENSOR_H2_SDA_PIN (14)
#endif

// UP1-PM-HF
// https://github.com/OpenKNX/OpenKNX/wiki/UP1-PM-HF
// note: valid for UP1-PM-HF >= V00.10
#ifdef DEVICE_UP1_PM_HF
    #define DEVICE_ID "UP1-PM-HF"
    #define DEVICE_NAME "OpenKNX UP1 Präsenzmelder+"

    #define OKNXHW_UP1_CONTROLLER2040

	#define OKNXHW_SENSOR_HF_SERIAL Serial2
    #define OKNXHW_SENSOR_HF_RX_PIN
    #define OKNXHW_SENSOR_HF_TX_PIN
    #define OKNXHW_SENSOR_HF_PWR_PIN

    #define OKNXHW_SENSOR_J40_WIRE Wire1
    #define OKNXHW_SENSOR_J40_SDA 10
    #define OKNXHW_SENSOR_J40_SCL 11

    #define RED_LED_PIN 25 // red channel of central RGB LED
    #define RED_LED_PIN_ACTIVE_ON LOW
    #define GREEN_LED_PIN 26 // green channel of central RGB LED
    #define GREEN_LED_PIN_ACTIVE_ON LOW
    #define BLUE_LED_PIN 27 // blue channel of central RGB LED
    #define BLUE_LED_PIN_ACTIVE_ON LOW

    #define PRESENCE_LED_PIN RED_LED_PIN
    #define PRESENCE_LED_PIN_ACTIVE_ON RED_LED_PIN_ACTIVE_ON
    #define MOVE_LED_PIN BLUE_LED_PIN
    #define MOVE_LED_PIN_ACTIVE_ON BLUE_LED_PIN_ACTIVE_ON

    #define I2C_WIRE Wire
    #define I2C_SDA_PIN 28
    #define I2C_SCL_PIN 29
    #define HF_SERIAL Serial2
    #define HF_SERIAL_SPEED 115200
    #define HF_POWER_PIN 18
    #define HF_UART_TX_PIN 20
    #define HF_UART_RX_PIN 21
    #define OPENKNX_BI_GPIO_PINS 19,22,23,24,11,10
    #define OPENKNX_BI_GPIO_COUNT 6
    #define OPENKNX_BI_ONLEVEL LOW

    // since INPUT_PULLDOWN is the default state and LED are Active LOW, LED must be deativated by setting to PULLUP
    #define DEVICE_INIT() \
        pinMode(RED_LED_PIN, INPUT_PULLUP); \
        pinMode(GREEN_LED_PIN, INPUT_PULLUP); \
        pinMode(BLUE_LED_PIN, INPUT_PULLUP); \

#endif

// device.openknx.de/UP1-GW-RS485
#ifdef DEVICE_UP1_GW_RS485
    #define DEVICE_ID "UP1-GW-RS485"
    #define DEVICE_NAME "OpenKNX UP1 RS485 Gateway"

    #define OKNXHW_UP1_CONTROLLER2040

    #define RS485_SERIAL Serial2
    #define RS485_UART_RX_PIN (21)
    #define RS485_UART_TX_PIN (20)
    #define RS485_UART_DIR_PIN (22)

    #define I2C_WIRE Wire
    #define I2C_SDA_PIN 16
    #define I2C_SCL_PIN 17

    #define OPENKNX_BI_GPIO_PINS 18
    #define OPENKNX_BI_GPIO_COUNT 1
    #define OPENKNX_BI_ONLEVEL LOW
#endif

// device.openknx.de/UP1-GW-2xUART
#ifdef DEVICE_UP1_GW_2XUART
    #define DEVICE_ID "UP1-GW-2xUART"
    #define DEVICE_NAME "OpenKNX UP1 UART Gateway"

    #define OKNXHW_UP1_CONTROLLER2040

    #define UART1_RX_PIN (21)
    #define UART1_TX_PIN (20)
    #define UART2_RX_PIN (29)
    #define UART2_TX_PIN (28)

    #define I2C_WIRE Wire
    #define I2C_SDA_PIN 16
    #define I2C_SCL_PIN 17
#endif

// device.openknx.de/UP1-WLAN-2xUART
// XIAO ESP32-S3
#ifdef DEVICE_UP1_WLAN_2XUART
    #define DEVICE_ID "UP1-WLAN-2xUART"
    #define DEVICE_NAME "OpenKNX UP1 WLAN UART Gateway"

    #ifdef DEVICE_UP1_WLAN_2XUART_ONBOARD
        #define PROG_LED_PIN LED_BUILTIN
        #define PROG_LED_PIN_ACTIVE_ON LOW
        #define PROG_BUTTON_PIN 0 // BOOT button
    #else
        #define PROG_LED_PIN (D8)    // D8 - GPIO7
        #define PROG_LED_PIN_ACTIVE_ON HIGH
        #define PROG_BUTTON_PIN (D7)  // D7 - GPIO44
    #endif

    #define SAVE_INTERRUPT_PIN (D6) // D6 - GPIO43

    #ifdef DEVICE_UP1_WLAN_2XUART_BCU
        #define KNX_SERIAL Serial1
        #define KNX_UART_NUM 0
        #define KNX_UART_RX_PIN (D10) // D10 - GPIO9
        #define KNX_UART_TX_PIN (D9) // D9 - GPIO8
    #else
        #define SAVE_POWER_PIN (D9) // D9 - GPIO8
        #define SAVE_POWER_PIN_POWER_OFF (LOW)
        #define SAVE_POWER_PIN_POWER_ON (HIGH)
    #endif

    #define UART1_RX_PIN (D2) // D2 - GPIO3
    #define UART1_TX_PIN (D4) // D4 - GPIO5
    #define UART2_RX_PIN (D3) // D3 - GPIO4
    #define UART2_TX_PIN (D5) // D5 - GPIO6

    #define I2C_WIRE Wire
    #define I2C_SDA_PIN (D0) // D0 - GPIO1
    #define I2C_SCL_PIN (D1) // D1 - GPIO2
#endif

#ifdef DEVICE_UP1_GW_IR
    #define DEVICE_ID "UP1-GW-IR"
    #define DEVICE_NAME "OpenKNX UP1 Infrared Gateway"

    #define OKNXHW_UP1_CONTROLLER2040

    #define OKNXHW_UP1_APP_IR
#endif

#pragma endregion

#pragma region "UP1 Controllers"

// UP1-Controller2040
#ifdef OKNXHW_UP1_CONTROLLER2040
    #define PROG_LED_PIN (6)
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN (7)
    #define SAVE_INTERRUPT_PIN (5)
    #define KNX_SERIAL Serial1
    #define KNX_UART_NUM 0
    #define KNX_UART_RX_PIN (1)
    #define KNX_UART_TX_PIN (0)
#endif

#pragma endregion

#pragma region "UP1 Apps"

#ifdef OKNXHW_UP1_APP_IR
    #define IR_PIN_REC (13)
    #define IR_PIN_SEND (2)
#endif

#pragma endregion