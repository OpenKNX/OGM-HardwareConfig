#pragma once
/**
 * AB-SmartHouse Hardware definition header file
 *
 * File: Devices.h
 * Hardware: Other
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

    #define BUTTON_TOP_LEFT_PIN 12
    #define BUTTON_BOTTOM_LEFT_PIN 3
    #define BUTTON_TOP_RIGHT_PIN 19
    #define BUTTON_BOTTOM_RIGHT_PIN 0


    #define OPENKNX_BI_GPIO_COUNT 4
    #define OPENKNX_BI_GPIO_PINS BUTTON_TOP_LEFT_PIN,BUTTON_BOTTOM_LEFT_PIN,BUTTON_TOP_RIGHT_PIN,BUTTON_BOTTOM_RIGHT_PIN

    #define LED1_R_PIN 15
    #define LED1_G_PIN 13
    #define LED1_B_PIN 14
    #define LED1_ACTIVE_ON LOW

    #define LED2_R_PIN 1
    #define LED2_G_PIN 2
    #define LED2_B_PIN 6
    #define LED2_ACTIVE_ON LOW    

    #define OPENKNX_SLED_COUNT 2
    #define OPENKNX_SLED_IDs 10, 11

    #define DEVICE_INIT()                      \
        pinMode(LED1_R_PIN, INPUT_PULLUP);     \
        pinMode(LED1_G_PIN, INPUT_PULLUP);     \
        pinMode(LED1_B_PIN, INPUT_PULLUP);     \
        pinMode(LED2_R_PIN, INPUT_PULLUP);     \
        pinMode(LED2_G_PIN, INPUT_PULLUP);     \
        pinMode(LED2_B_PIN, INPUT_PULLUP);     

    #define LED_INIT()                                                                                                                                                               \
        openknx.leds.addLed(new OpenKNX::Led::GPIO(PROG_LED_PIN, PROG_LED_PIN_ACTIVE_ON), OpenKNX::Led::LED_TYPE_PROG);                                                              \
        openknx.leds.addLed(new OpenKNX::Led::GPIO(INFO_LED_PIN, INFO_LED_PIN_ACTIVE_ON), OpenKNX::Led::LED_TYPE_INFO1);                                                              \
        openknx.leds.addLed(new OpenKNX::Led::GPIO_RGB(LED1_R_PIN, LED1_G_PIN, LED1_B_PIN, LED1_ACTIVE_ON, OpenKNX::Led::Color::Blue), OpenKNX::Led::LED_TYPE_USER);                 \
        openknx.leds.addLed(new OpenKNX::Led::GPIO_RGB(LED2_R_PIN, LED2_G_PIN, LED2_B_PIN, LED2_ACTIVE_ON, OpenKNX::Led::Color::Blue), OpenKNX::Led::LED_TYPE_USER + 1);             

#endif

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

    #define OPENKNX_SLED_COUNT 2
    #define OPENKNX_SLED_IDs OpenKNX::Led::LED_TYPE_USER, OpenKNX::Led::LED_TYPE_USER+1

    #define DEVICE_INIT()                     \
        pinMode(PRESENCE_LED_PIN, INPUT_PULLUP);   \
        pinMode(MOVE_LED_PIN, INPUT_PULLUP); 

    #define LED_INIT()                        \
        openknx.leds.addLed(new OpenKNX::Led::GPIO(PROG_LED_PIN, PROG_LED_PIN_ACTIVE_ON), OpenKNX::Led::LED_TYPE_PROG); \
        openknx.leds.addLed(new OpenKNX::Led::GPIO(INFO_LED_PIN, INFO_LED_PIN_ACTIVE_ON), OpenKNX::Led::LED_TYPE_INFO1); \
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

#ifdef DEVICE_AB_SMARTHOUSE_ESP32_P4_1TP
    #define DEVICE_ID "AB-IP-1TP"
    #define HARDWARE_NAME "AB-IP-1TP"
    #define DEVICE_NAME "AB-SmartHouse IP with 1x TP"

    #define PROG_LED_PIN 19
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define INFO_LED_PIN 20
    #define INFO_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 18
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
    #define SAVE_INTERRUPT_PIN 33
    #define KNX_UART_NUM 0
    #define KNX_UART_RX_PIN 11
    #define KNX_UART_TX_PIN 12
    #define KNX_TREQ_PIN 14
    #define KNX_MODE2_PIN 15
    #define KNX_MODE1_PIN 16
    #define KNX_SCK_UC2_PIN 10
    #define KNX_CSB_UC1_PIN 13
    #define KNX_TRIG_PIN 17
    #define KNX_RESETB_PIN 37
    #define KNX_ANAOUT_PIN 32

    #define ETH_PHY_RST 51

    // NCN5130 communication mode, set by the level of the mode pins at power-up.

    // 9-bit UART-Mode, 19200 bps
    // #define DEVICE_INIT() \
    //     pinMode(KNX_TREQ_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_MODE2_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_MODE1_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_SCK_UC2_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_CSB_UC1_PIN, INPUT_PULLDOWN)

    // 9-bit UART-Mode, 38400 bps
    #define DEVICE_INIT() \
        pinMode(KNX_TREQ_PIN, INPUT_PULLDOWN); \
        pinMode(KNX_MODE2_PIN, INPUT_PULLDOWN); \
        pinMode(KNX_MODE1_PIN, INPUT_PULLDOWN); \
        pinMode(KNX_SCK_UC2_PIN, INPUT_PULLDOWN); \
        pinMode(KNX_CSB_UC1_PIN, INPUT_PULLUP)

    // 8-bit UART-Mode, 19200 bps
    // #define DEVICE_INIT() \
    //     pinMode(KNX_TREQ_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_MODE2_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_MODE1_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_SCK_UC2_PIN, INPUT_PULLUP); \
    //     pinMode(KNX_CSB_UC1_PIN, INPUT_PULLDOWN)

    // 8-bit UART-Mode, 38400 bps
    // #define DEVICE_INIT() \
    //     pinMode(KNX_TREQ_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_MODE2_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_MODE1_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_SCK_UC2_PIN, INPUT_PULLUP); \
    //     pinMode(KNX_CSB_UC1_PIN, INPUT_PULLUP)

    // Analog Mode
    // #define DEVICE_INIT() \
    //     pinMode(KNX_TREQ_PIN, INPUT_PULLUP); \
    //     pinMode(KNX_MODE2_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_MODE1_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_SCK_UC2_PIN, OUTPUT); \
    //     pinMode(KNX_CSB_UC1_PIN, OUTPUT)

    // SPI Master, 125 kbps
    // #define DEVICE_INIT() \
    //     pinMode(KNX_TREQ_PIN, OUTPUT); \
    //     pinMode(KNX_MODE2_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_MODE1_PIN, INPUT_PULLUP); \
    //     pinMode(KNX_SCK_UC2_PIN, OUTPUT); \
    //     pinMode(KNX_CSB_UC1_PIN, OUTPUT)

    // SPI Master, 500 kbps
    // #define DEVICE_INIT() \
    //     pinMode(KNX_TREQ_PIN, OUTPUT); \
    //     pinMode(KNX_MODE2_PIN, INPUT_PULLUP); \
    //     pinMode(KNX_MODE1_PIN, INPUT_PULLDOWN); \
    //     pinMode(KNX_SCK_UC2_PIN, OUTPUT); \
    //     pinMode(KNX_CSB_UC1_PIN, OUTPUT)
#endif