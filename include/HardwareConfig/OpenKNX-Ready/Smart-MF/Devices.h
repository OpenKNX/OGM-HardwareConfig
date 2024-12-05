#pragma once
/**
 * Smart-MF OpenKNX ready Hardware definition header file
 *
 * File: Devices.h
 * Hardware: OpenKNX Miscellanous Hardware
 * Responsible: Smart-MF
 *
 * Defines hardware IO pins and functionalities for the Smart-MF Hardware.
 * Includes pin assignments for LEDs, buttons, serial communication, and other peripherals.
 *
 *
 * More info about the Hardware visit: https://www.OpenKNX.de  https://www.Smart-Mf.de
 *
 * ATTENTION:
 *    Do not include this file directly.
 *    It will be included by the HardwareConfig.h file.
 */

// Smart-MF 1TE 3x Binary Inputs
#ifdef DEVICE_SMARTMF_1TE_BE_3CH
    #define DEVICE_ID "SMARTMF-1TE-BE-3CH"
    #define DEVICE_NAME "Smart-MF S0-Zählermodul"

    #define SMARTMF_HARDWARE_VARIANT_PIN 26
    #define SMARTMF_HARDWARE_REVISION_ID1_PIN 10
    #define SMARTMF_HARDWARE_REVISION_ID2_PIN 11
    #define SMARTMF_HARDWARE_REVISION_ID3_PIN 12

    #define PROG_LED_PIN 1
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 0
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
    #define SAVE_INTERRUPT_PIN 29
    #define KNX_UART_RX_PIN 17
    #define KNX_UART_TX_PIN 16

    #define SMARTMF_BE1_PIN 14
    #define SMARTMF_BE2_PIN 15
    #define SMARTMF_BE3_PIN 4

    #define SMARTMF_BE_VCC_PIN 5
#endif

// Smart-MF 1-Wire Gateway 3CH
#ifdef DEVICE_SMARTMF_1WIRE_3CH
    #define DEVICE_ID "SMARTMF-1Wire-3CH"
    #define DEVICE_NAME "Smart-MF 1-Wire Gateway 3CH"

    #define SMARTMF_HARDWARE_REVISION_ID1_PIN 2
    #define SMARTMF_HARDWARE_REVISION_ID2_PIN 3
    #define SMARTMF_HARDWARE_REVISION_ID3_PIN 15

    #define PROG_LED_PIN 11
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 14
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
    #define SAVE_INTERRUPT_PIN 8
    #define KNX_UART_RX_PIN 1
    #define KNX_UART_TX_PIN 0

    #define SMARTMF_CH1_I2C1_SDA_PIN 6
    #define SMARTMF_CH1_I2C1_SCL_PIN 7

    #define SMARTMF_CH2_I2C0_SDA_PIN 24
    #define SMARTMF_CH2_I2C0_SCL_PIN 25

    #define SMARTMF_CH3_I2C1_SDA_PIN 22
    #define SMARTMF_CH3_I2C1_SCL_PIN 23
#endif

// Smart-MF SML Reader (2x SML + 3x BIN)
#ifdef DEVICE_SMARTMF_2SML_3BE
    #define DEVICE_ID "SMARTMF-2SML-3BE"
    #define DEVICE_NAME "Smart-MF eHZ Schnittstelle"

    #define SMARTMF_HARDWARE_REVISION_ID1_PIN 2
    #define SMARTMF_HARDWARE_REVISION_ID2_PIN 3
    #define SMARTMF_HARDWARE_REVISION_ID3_PIN 15

    #define PROG_LED_PIN 11
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 14
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
    #define SAVE_INTERRUPT_PIN 8
    #define KNX_UART_RX_PIN 1
    #define KNX_UART_TX_PIN 0

    #define SMARTMF_BE1_PIN 26
    #define SMARTMF_BE2_PIN 27
    #define SMARTMF_BE3_PIN 29

    #define SMARTMF_SML_PWR_PIN 25
    #define SMARTMF_SML_PWR_FAULT_PIN 24

    #define SMARTMF_SML1_RX_PIN 5
    #define SMARTMF_SML1_TX_PIN 4

    #define SMARTMF_SML2_RX_PIN 22
    #define SMARTMF_SML2_TX_PIN 23
#endif

// Smart-MF Modbus Gateway + 3x BIN
#ifdef DEVICE_SMARTMF_MODBUS_RTU_3BE
    #define DEVICE_ID "SMARTMF-Modbus-RTU-3BE"
    #define DEVICE_NAME "Smart-MF Modbus-RTU Gateway"

    #define SMARTMF_HARDWARE_REVISION_ID1_PIN 2
    #define SMARTMF_HARDWARE_REVISION_ID2_PIN 3
    #define SMARTMF_HARDWARE_REVISION_ID3_PIN 15

    #define PROG_LED_PIN 11
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 14
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
    #define SAVE_INTERRUPT_PIN 8
    #define KNX_UART_RX_PIN 1
    #define KNX_UART_TX_PIN 0

    #define SMARTMF_BE1_PIN 25
    #define SMARTMF_BE2_PIN 27
    #define SMARTMF_BE3_PIN 26

    #define SMARTMF_MODBUS_RX_PIN 5
    #define SMARTMF_MODBUS_TX_PIN 4
    #define SMARTMF_MODBUS_DIR_PIN 24
#endif