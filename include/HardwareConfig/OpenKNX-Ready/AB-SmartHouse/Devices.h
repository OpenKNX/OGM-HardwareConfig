#pragma once
/**
 * AB-SmartHouse OpenKNX ready Hardware definition header file
 *
 * File: Device.h
 * Hardware: OpenKNX Miscellanous Hardware
 * Responsible: AB-SmartHouse
 *
 * Defines hardware IO pins and functionalities for the AB-SmartHouse Hardware.
 * Includes pin assignments for LEDs, buttons, serial communication, and other peripherals.
 *
 *
 * More info about the Hardware visit: https://www.OpenKNX.de  https://www.ab-smarthouse.com
 *
 * ATTENTION:
 *    Do not include this file directly.
 *    It will be included by the HardwareConfig.h file.
 */

/************************************************** */
//  Taster
/************************************************** */

#ifdef DEVICE_AB_BUT_GIR
    #define DEVICE_ID "AB-BUT-GIR"
    #define DEVICE_NAME "AB-SmartHouse Push Buttons for Gira"
    #define INFO_LED_PIN 11
    #define INFO_LED_PIN_ACTIVE_ON HIGH
    #define PROG_LED_PIN 10
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 9
    #define SAVE_INTERRUPT_PIN 20
    #define KNX_UART_NUM 0
    #define KNX_UART_TX_PIN 16
    #define KNX_UART_RX_PIN 17
    #define OPENKNX_BUZZER_PIN 25
    #define OPENKNX_VIBRATION_PIN 8
    #define I2C_WIRE Wire
    #define I2C_SDA_PIN 4
    #define I2C_SCL_PIN 5
    #define OPENKNX_BI_GPIO_COUNT 4
    #define OPENKNX_BI_GPIO_PINS 3,0,12,19
#endif

// #define SMARTMF_BE1_PIN 2
// #define SMARTMF_BE2_PIN 4
// #define SMARTMF_BE3_PIN 6
// #define SMARTMF_BE4_PIN 7

// #define SMARTMF_I2C0_SDA_PIN 20
// #define SMARTMF_I2C0_SCL_PIN 21

// #define SMARTMF_I2C1_SDA_PIN 14
// #define SMARTMF_I2C1_SCL_PIN 15

// #define SMARTMF_BUZZER_PIN 27

// // definitions for legacy support
// #define I2C_RGBLED_DEVICE_ADDRESS 0x60 // Address of PCA9632 RGBW-LED-Driver
// #define I2C_WIRE Wire
// #define I2C_SDA_PIN SMARTMF_I2C0_SDA_PIN
// #define I2C_SCL_PIN SMARTMF_I2C0_SCL_PIN
// #define COUNT_1WIRE_BUSMASTER 1
// #define COUNT_1WIRE_CHANNEL 30
// #define I2C_1WIRE_DEVICE_ADDRESSS 0x18 // Address of DS2484 1-Wire-Busmaster chip
// #define I2C_BUS_1WIRE Wire1
// #define I2C_SDA_1WIRE_PIN SMARTMF_I2C1_SDA_PIN
// #define I2C_SCL_1WIRE_PIN SMARTMF_I2C1_SCL_PIN
// #define ONEWIRE_5V_ENABLE 8
// #define ONEWIRE_5V_SHORT 9
// #define BUZZER_PIN SMARTMF_BUZZER_PIN
// #define HW_ANALOG_ID SMARTMF_HARDWARE_REVISION_ADC_PIN
// #define HW_REVISION_ID1 SMARTMF_HARDWARE_REVISION_ID1_PIN
// #define HW_REVISION_ID2 SMARTMF_HARDWARE_REVISION_ID2_PIN
// #define HW_REVISION_ID3 SMARTMF_HARDWARE_REVISION_ID3_PIN
// #define OPENKNX_BI_GPIO_PINS SMARTMF_BE1_PIN, SMARTMF_BE2_PIN, SMARTMF_BE3_PIN, SMARTMF_BE4_PIN
// #define OPENKNX_BI_GPIO_COUNT 4
// #define OPENKNX_ADC_ADS_ADDR 0x49
// #define OPENKNX_ADC_ADS_GAIN 2
// #define OPENKNX_ADC_ADS_WIRE I2C_BUS_1WIRE
// #define OPENKNX_ADC_ADS_SDA I2C_SDA_1WIRE_PIN
// #define OPENKNX_ADC_ADS_SCL I2C_SCL_1WIRE_PIN

#ifdef DEVICE_AB_PRE
    #define DEVICE_AB_PRE_BASE
    #define DEVICE_ID "AB-PRE"
    #define HARDWARE_NAME "AB-PRE"
    #define DEVICE_NAME "AB-SmartHouse Presence MultiSensor"
#endif

#ifdef DEVICE_AB_PRE_MR16
    #define DEVICE_AB_PRE_BASE
    #define DEVICE_ID "AB-PRE-MR16"
    #define HARDWARE_NAME "AB-PRE-MR16"
    #define DEVICE_NAME "AB-SmartHouse Presence MR16"
#endif

#ifdef DEVICE_AB_PRE_WALL
    #define DEVICE_AB_PRE_BASE
    #define DEVICE_ID "AB-PRE-WALL"
    #define HARDWARE_NAME "AB-PRE-WALL"
    #define DEVICE_NAME "AB-SmartHouse Presence Wall"
#endif

#ifdef DEVICE_AB_PRE_WALL_OUT
    #define DEVICE_ID "AB-PRE-WALL-OUT"
    #define HARDWARE_NAME "AB-PRE-WALL-OUT"
    #define DEVICE_NAME "AB-SmartHouse Presence Wall Outside"
    #define PROG_LED_PIN 10
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 9
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
    #define INFO_LED_PIN 11
    #define INFO_LED_PIN_ACTIVE_ON HIGH
    #define KNX_UART_TX_PIN 12
    #define KNX_UART_RX_PIN 13
    #define SAVE_INTERRUPT_PIN 0
    #define I2C_WIRE Wire1
    #define I2C_SDA_PIN 2
    #define I2C_SCL_PIN 3
    #define HF_SERIAL Serial2
    #define HF_SERIAL_SPEED 115200
    #define HF_POWER_PIN 27
    #define HF_UART_TX_PIN 4
    #define HF_UART_RX_PIN 5
    #define PIR_PIN 18
#endif

// Sensormodul auf RP2040 Basis
#ifdef DEVICE_AB_PRE_BASE
    #define PROG_LED_PIN 10
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 9
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
    #define INFO_LED_PIN 11
    #define INFO_LED_PIN_ACTIVE_ON HIGH
    #define PRESENCE_LED_PIN 28
    #define PRESENCE_LED_PIN_ACTIVE_ON HIGH
    #define MOVE_LED_PIN 29
    #define MOVE_LED_PIN_ACTIVE_ON HIGH
    #define KNX_UART_TX_PIN 12
    #define KNX_UART_RX_PIN 13
    #define SAVE_INTERRUPT_PIN 0
    #define I2C_WIRE Wire1
    #define I2C_SDA_PIN 2
    #define I2C_SCL_PIN 3
    #define HF_SERIAL Serial2
    #define HF_SERIAL_SPEED 115200
    #define HF_POWER_PIN 27
    #define HF_UART_TX_PIN 4
    #define HF_UART_RX_PIN 5
    #define PIR_PIN 26
    #define OPENKNX_BI_GPIO_PINS 14, 15
    #define OPENKNX_BI_GPIO_COUNT 2
    #define OPENKNX_BI_ONLEVEL LOW

    #define OPENKNX_SLED_IDs OpenKNX::Led::LED_TYPE_USER, OpenKNX::Led::LED_TYPE_USER+1

    #define DEVICE_INIT()                     \
        pinMode(PRESENCE_LED_PIN, INPUT_PULLUP);   \
        pinMode(MOVE_LED_PIN, INPUT_PULLUP); 

    #define LED_INIT()                        \
        openknx.leds.addLed(new OpenKNX::Led::GPIO(PROG_LED_PIN, PROG_LED_PIN_ACTIVE_ON), OpenKNX::Led::LED_TYPE_PROG); \
        openknx.leds.addLed(new OpenKNX::Led::GPIO(PRESENCE_LED_PIN, PRESENCE_LED_PIN_ACTIVE_ON), OpenKNX::Led::LED_TYPE_USER); \
        openknx.leds.addLed(new OpenKNX::Led::GPIO(MOVE_LED_PIN, MOVE_LED_PIN_ACTIVE_ON), OpenKNX::Led::LED_TYPE_USER+1);

#endif

#ifdef DEVICE_AB_TOUCH_ROUND_RP2350
    #define DEVICE_ID "AB-TOUCH-ROUND"
    #define HARDWARE_NAME "AB-TOUCH-ROUND"
    #define DEVICE_NAME "AB-SmartHouse Touch Round"
    #define INFO_LED_PIN 11
    #define INFO_LED_PIN_ACTIVE_ON HIGH
    #define PROG_LED_PIN 10
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 9
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING

    #define KNX_UART_NUM 0
    #define KNX_UART_TX_PIN 12
    #define KNX_UART_RX_PIN 13

    #define SAVE_INTERRUPT_PIN 0

    #define TOUCH_LEFT_PIN 24
    #define TOUCH_RIGHT_PIN 25

    #define I2C_WIRE Wire1
    #define I2C_SDA_PIN 26
    #define I2C_SCL_PIN 27
#endif

