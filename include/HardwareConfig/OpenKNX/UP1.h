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

#pragma endregion

#pragma region "UP1 Controllers"

// UP1-Controller2040
#ifdef OKNXHW_UP1_CONTROLLER2040
    #define PROG_LED_PIN (6)
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN (7)
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
    #define SAVE_INTERRUPT_PIN (5)
    #define KNX_SERIAL Serial1
    #define KNX_UART_RX_PIN (1)
    #define KNX_UART_TX_PIN (0)
#endif

#pragma endregion