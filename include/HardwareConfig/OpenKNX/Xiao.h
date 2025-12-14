#pragma once
/**
 * OpenKNX Hardware Definition Header File
 *
 * File: OpenKNXiao-Hardware.h
 * Hardware: OpenKNXiao RP2040 / SAMD / ESP Based Boards
 * Responsible: OpenKNX - Erkan Çolak
 *
 * Defines hardware IO pins and functionalities for OpenKNXiao RP2040 / SAMD platform.
 * Includes pin assignments for LEDs, buttons, serial communication, I2C interfaces,
 * and other peripherals. Ensures compatibility with various application boards and
 * firmware features.
 *
 * Configurations are categorized by hardware versions and features:
 * - OpenKNXiao RP2040 ( Current Versions: V1 )
 * - OpenKNXiao SAMD ( Current Versions: V1 )
 * - OpenKNXiao ESP32 ( Current Versions: V1 )
 * - Wi-Fi
 * - Meter support, WS2812/NeoPixel, etc.
 *
 * Each configuration is guarded by preprocessor directives to enable/disable features.
 *
 * More info about the Hardware visit: www.openknx.de
 *
 * ATTENTION:
 *   Do not include this file directly.
 *   It will be included by the HardwareConfig.h file.
 *
 */

/**
 * Section: Device configurations / use cases ( Device is a full defined hardware has documentation in openknx wiki)
 * OpenKNXiao RP2040 / SAMD / ESP / ESP32-S2
 */

// Needs the new macro in common!
#if defined(OKNXHW_OPENKNXIAO_RP2040_MINI_V1) \
  || defined(OKNXHW_OPENKNXIAO_KNEOPIX_RP2040_V1) \
  || defined(OKNXHW_OPENKNXIAO_KNEOPIX_RP2350_V1) \
  || defined(OKNXHW_OPENKNXIAO_KNEOPIX_ESP32S3_V1) \
  || defined(OKNXHW_OPENKNXIAO_KNEOPIX_SAMD21_V1) \
  || defined(OKNXHW_OPENKNXIAO_SAMD21_MINI_V1) \
  || defined(OKNXHW_OPENKNXIAO_ESP32S3_MINI_V1)
    #define PREFIX_ID "OKNXIAO-"      // 10 characters
    #define PREFIX_NAME "OpenKNXiao " // 13 characters
#endif

// OpenKNXiao KNeoPix RP2040 V1
// https://github.com/OpenKNX/OpenKNX-KNeoPiX
#ifdef OKNXHW_OPENKNXIAO_KNEOPIX_RP2040_V1
    #define DEVICE_ID PREFIX_ID "V10-KNeoPix-2040"
    #define DEVICE_NAME PREFIX_NAME "V1.0 KNeoPix RP2040"
    #define OKNXHW_OPENKNXIAO_RP2040
    #define OKNXHW_OPENKNXIAO_V1_COMMON
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL_NEOPIX
    #define OKNXHW_OPENKNXIAO_RP2040_V1_LED1
    #define OKNXHW_OPENKNXIAO_RP2040_V1_LED2
    #define OKNXHW_OPENKNXIAO_V1_NEOPIXEL
#endif

// OpenKNXiao KNeoPix RP2350 V1.4
// https://...
#ifdef OKNXHW_OPENKNXIAO_KNEOPIX_RP2350_V1
    #define DEVICE_ID PREFIX_ID "V14-KNeoPix-2350"
    #define DEVICE_NAME PREFIX_NAME "V1.4 KNeoPix RP2350"
    #define OKNXHW_OPENKNXIAO_RP2350
    #define OKNXHW_OPENKNXIAO_V1_COMMON
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL_NEOPIX
    #define OKNXHW_OPENKNXIAO_V1_NEOPIXEL
#endif

// OpenKNXiao KNeoPix ESP32-S3 V1
// http://www.openknx.de/OpenKNX-KNeoPiX
#ifdef OKNXHW_OPENKNXIAO_KNEOPIX_ESP32S3_V1
    #define DEVICE_ID PREFIX_ID "V1-KNeoPix-ESP32S3"
    #define DEVICE_NAME PREFIX_NAME "V1 KNeoPix ESP32S3"
    #define OKNXHW_OPENKNXIAO_ESP32S3
    #define OKNXHW_OPENKNXIAO_V1_COMMON
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL_NEOPIX
    #define OKNXHW_OPENKNXIAO_V1_NEOPIXEL
#endif

// OpenKNXiao Mini RP2040 V1
// https://github.com/OpenKNX/OpenKNXiao-Mini
#ifdef OKNXHW_OPENKNXIAO_RP2040_MINI_V1
    #define DEVICE_ID PREFIX_ID "V10-Mini-2040"
    #define DEVICE_NAME PREFIX_NAME " V1.0 Mini RP2040"
    #define OKNXHW_OPENKNXIAO_RP2040
    #define OKNXHW_OPENKNXIAO_V1_COMMON
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL_MINI
    #define OKNXHW_OPENKNXIAO_RP2040_V1_LED1
    #define OKNXHW_OPENKNXIAO_RP2040_V1_LED2
    #define OKNXHW_OPENKNXIAO_V1_NEOPIXEL
#endif

// OpenKNXiao Mini ESP32-S3 V1
// https://github.com/OpenKNX/OpenKNXiao-Mini
#ifdef OKNXHW_OPENKNXIAO_ESP32S3_MINI_V1
    #define DEVICE_ID PREFIX_ID "V10-Mini-ESP32S3"
    #define DEVICE_NAME PREFIX_NAME " V1.0 Mini ESP32S3"
    #define OKNXHW_OPENKNXIAO_ESP32S3
    #define OKNXHW_OPENKNXIAO_V1_COMMON
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL
    #define OKNXHW_OPENKNXIAO_V1_TERMINAL_MINI
    #define OKNXHW_OPENKNXIAO_V1_NEOPIXEL
#endif

// OpenKNXiao KNeoPix SAMD21 V1
// https://github.com/OpenKNX/OpenKNX-KNeoPiX
#ifdef OKNXHW_OPENKNXIAO_KNEOPIX_SAMD21_V1
    #define DEVICE_ID PREFIX_ID "V10-KNeoPix-SAMD21"
    #define DEVICE_NAME PREFIX_NAME " V1.0 KNeoPix SAMD21"
    #define OKNXHW_OPENKNXIAO_SAMD21
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_COMMON
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_TERMINAL
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_TERMINAL_NEOPIX
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_LED1
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_LED2
#endif

// OpenKNXiao Mini SAMD21 V1
// https://github.com/OpenKNX/OpenKNXiao-Mini
#ifdef OKNXHW_OPENKNXIAO_SAMD21_MINI_V1
    #define DEVICE_ID PREFIX_ID "V10-Mini-SAMD21"
    #define DEVICE_NAME PREFIX_NAME " V1.0 Mini SAMD21"
    #define OKNXHW_OPENKNXIAO_SAMD21
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_COMMON
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_TERMINAL
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_TERMINAL_MINI
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_LED1
    #define OKNXHW_OPENKNXIAO_SAMD21_V1_LED2
#endif


/* #################################################################################
 *
 * Section: General Hardware Definitions
 * OpenKNXiao RP2040 / Rp2350 / ESP / ESP32-S3-Plus
 * 
 * ################################################################################# */
//
#if defined(OKNXHW_OPENKNXIAO_RP2040)
    // XIAO RP2040 Pin Definitions
    #define OKNXHW_OPENKNXIAO_D0  26 // GPIO26 | SPI1 SCK  | UART1 CTS | I2C1 SDA | PWM5 A
    #define OKNXHW_OPENKNXIAO_D1  27 // GPIO27 | SPI1 TX   | UART1 RTS | I2C1 SCL | PWM5 B
    #define OKNXHW_OPENKNXIAO_D2  28 // GPIO28 | SPI1 RX   | UART0 TX  | I2C0 SDA | PWM6 A
    #define OKNXHW_OPENKNXIAO_D3  29 // GPIO29 | SPI1 CSn  | UART0 RX  | I2C0 SCL | PWM6 B
    #define OKNXHW_OPENKNXIAO_D4  6  // GPIO6  | SPI0 SCK  | UART1 CTS | I2C1 SDA | PWM3 A
    #define OKNXHW_OPENKNXIAO_D5  7  // GPIO7  | SPI0 TX   | UART1 RTS | I2C1 SCL | PWM3 B
    #define OKNXHW_OPENKNXIAO_D6  0  // GPIO0  | SPI0 RX   | UART0 TX  | I2C0 SDA | PWM0 A
    #define OKNXHW_OPENKNXIAO_D7  1  // GPIO1  | SPI0 CSn  | UART0 RX  | I2C0 SCL | PWM0 B
    #define OKNXHW_OPENKNXIAO_D8  2  // GPIO2  | SPI0 SCK  | UART0 CTS | I2C1 SDA | PWM1 A
    #define OKNXHW_OPENKNXIAO_D9  4  // GPIO4  | SPI0 RX   | UART1 TX  | I2C0 SDA | PWM2 A
    #define OKNXHW_OPENKNXIAO_D10 3  // GPIO3  | SPI0 TX   | UART0 RTS | I2C1 SCL | PWM1 B

    #define OKNXHW_OPENKNXIAO_LED_1_GREEN 16 // Build-In LED GREEN
    #define OKNXHW_OPENKNXIAO_LED_1_RED   17 // Build-In LED RED
    #define OKNXHW_OPENKNXIAO_LED_1_BLUE  25 // Build-In LED BLUE

    #define OKNXHW_OPENKNXIAO_NEOPIXEL_PWR 11 // Build-In NeoPixel Power Pin
    #define OKNXHW_OPENKNXIAO_NEOPIXEL 12   // Build-In NeoPixel Pin

#elif defined(OKNXHW_OPENKNXIAO_RP2350)
    // XIAO RP2350 Pin Definitions
    #define OKNXHW_OPENKNXIAO_D0  26 // GPIO26 | SPI1 SCK  | UART1 CTS | I2C1 SDA | PWM5 A
    #define OKNXHW_OPENKNXIAO_D1  27 // GPIO27 | SPI1 TX   | UART1 RTS | I2C1 SCL | PWM5 B
    #define OKNXHW_OPENKNXIAO_D2  28 // GPIO28 | SPI1 RX   | UART0 TX  | I2C0 SDA | PWM6 A
    #define OKNXHW_OPENKNXIAO_D3  5  // GPIO5  | SPI0 CSn  | UART1 RX  | I2C0 SDA | PWM2 B
    #define OKNXHW_OPENKNXIAO_D4  6  // GPIO6  | SPI0 SCK  | UART1 CTS | I2C1 SDA | PWM3 A
    #define OKNXHW_OPENKNXIAO_D5  7  // GPIO7  | SPI0 TX   | UART1 RTS | I2C1 SCL | PWM3 B
    #define OKNXHW_OPENKNXIAO_D6  0  // GPIO0  | SPI0 RX   | UART0 TX  | I2C0 SDA | PWM0 A
    #define OKNXHW_OPENKNXIAO_D7  1  // GPIO1  | SPI0 CSn  | UART0 RX  | I2C0 SCL | PWM0 B
    #define OKNXHW_OPENKNXIAO_D8  2  // GPIO2  | SPI0 SCK  | UART0 CTS | I2C1 SDA | PWM1 A
    #define OKNXHW_OPENKNXIAO_D9  4  // GPIO4  | SPI0 RX   | UART1 TX  | I2C0 SDA | PWM2 A
    #define OKNXHW_OPENKNXIAO_D10 3  // GPIO3  | SPI0 TX   | UART0 RTS | I2C1 SCL | PWM1 B
    
    #define OKNXHW_OPENKNXIAO_LED_1_GREEN -1 // N/A
    #define OKNXHW_OPENKNXIAO_LED_1_RED   -1 // N/A
    #define OKNXHW_OPENKNXIAO_LED_1_BLUE  -1 // N/A
    #define OKNXHW_OPENKNXIAO_LED_1_YELLOW 25 // Build-In LED YELLOW

    #define OKNXHW_OPENKNXIAO_NEOPIXEL_PWR 23 // Build-In NeoPixel Power Pin
    #define OKNXHW_OPENKNXIAO_NEOPIXEL 22    // Build-In NeoPixel Pin

#elif defined(OKNXHW_OPENKNXIAO_ESP32S3) || defined(OKNXHW_OPENKNXIAO_ESP32S3_PLUS)
    // XIAO ESP32-S3 Plus Pin Definitions
    #define OKNXHW_OPENKNXIAO_D0  1 
    #define OKNXHW_OPENKNXIAO_D1  2
    #define OKNXHW_OPENKNXIAO_D2  3
    #define OKNXHW_OPENKNXIAO_D3  4
    #define OKNXHW_OPENKNXIAO_D4  5
    #define OKNXHW_OPENKNXIAO_D5  6
    #define OKNXHW_OPENKNXIAO_D6  43
    #define OKNXHW_OPENKNXIAO_D7  44
    #define OKNXHW_OPENKNXIAO_D8  7
    #define OKNXHW_OPENKNXIAO_D9  8
    #define OKNXHW_OPENKNXIAO_D10 9
    #define OKNXHW_OPENKNXIAO_D11 42
    #define OKNXHW_OPENKNXIAO_D12 41

    #define OKNXHW_OPENKNXIAO_LED_1_GREEN -1 // N/A
    #define OKNXHW_OPENKNXIAO_LED_1_RED   -1 // N/A
    #define OKNXHW_OPENKNXIAO_LED_1_BLUE  -1 // N/A
    #define OKNXHW_OPENKNXIAO_LED_1_YELLOW 21 // Build-In LED YELLOW

    #define OKNXHW_OPENKNXIAO_NEOPIXEL_PWR -1 // N/A
    #define OKNXHW_OPENKNXIAO_NEOPIXEL -1   // N/A
#else
    //#error "No OpenKNXiao RP2040 / Rp2350 / ESP / ESP32-S3 / SAMD21 hardware version defined!"
#endif




/**
 * Section: Hardware specific Pin Definitions
 * OpenKNXiao RP2040 / SAMD / ESP
 */



// OpenKNXiao RP2040 V1 RGB LED (NeoPixel LED)
#ifdef OKNXHW_OPENKNXIAO_V1_NEOPIXEL
    // Info: The NeoPixel LED is connected to GPIO12 with a power control on GPIO11.
    //       It needs to be enable the power before using the NeoPixel.
    //       pinMode(NEOPIX_LED_POWER_PIN, OUTPUT); digitalWrite(NEOPIX_LED_POWER_PIN, NEOPIX_LED_ACTIVE_ON); 
    #define NEOPIX_LED_POWER_PIN OKNXHW_OPENKNXIAO_NEOPIXEL_PWR   // NeoPixel LED Power Pin
    #define NEOPIX_LED_PIN OKNXHW_OPENKNXIAO_NEOPIXEL         // Build-In RGB NeoPixel LED
    #define NEOPIX_LED_COUNT 1        // Number of NeoPixel LEDs
    #define NEOPIX_LED_TYPE NEO_GRB   // NeoPixel LED Type
    #define NEOPIX_LED_ORDER NEO_GRB  // NeoPixel LED Order
    #define NEOPIX_LED_ACTIVE_ON HIGH // Active on HIGH
    #define NEOPIX_LED_SPEED 800000   // NeoPixel LED Speed (800 KHz / NEO_KHZ800)

    #define OPENKNX_SERIALLED_COLOR_RED 50, 0, 0
    #define OPENKNX_SERIALLED_COLOR_GREEN 0, 35, 0
    #define OPENKNX_SERIALLED_COLOR_BLUE 0, 0, 63
    #define OPENKNX_SERIALLED_COLOR_YELLOW 40, 30, 0

    //#define OPENKNX_SERIALLED_ENABLE
    //#define OPENKNX_SERIALLED_PIN NEOPIX_LED_PIN
    //#define OPENKNX_SERIALLED_NUM NEOPIX_LED_COUNT

    //#define PROG_LED_PIN 0
    //#define PROG_LED_COLOR OPENKNX_SERIALLED_COLOR_RED
    //#define INFO1_LED_PIN 0
    //#define INFO1_LED_COLOR OPENKNX_SERIALLED_COLOR_BLUE
    //#define INFO2_LED_PIN 0
    //#define INFO2_LED_COLOR OPENKNX_SERIALLED_COLOR_GREEN
    //#define INFO3_LED_PIN 0
    //#define INFO3_LED_COLOR OPENKNX_SERIALLED_COLOR_BLUE
    //#define OPENKNX_LEDEFFECT_PULSE_MIN 50
#endif

/**
 * Section: Common Hardware (CHW) Pin Definitions
 * OpenKNXiao RP2040
 */


// OpenKNXiao RP2040 CHW Pins
#ifdef OKNXHW_OPENKNXIAO_V1_COMMON
    #ifdef OKNXHW_OPENKNXIAO_RP2350
        #define PROG_LED_PIN OKNXHW_OPENKNXIAO_LED_1_YELLOW
        #define PROG_LED_PIN_ACTIVE_ON LOW
    #elif defined( OKNXHW_OPENKNXIAO_ESP32S3)
        #define PROG_LED_PIN OKNXHW_OPENKNXIAO_LED_1_YELLOW
        #define PROG_LED_PIN_ACTIVE_ON HIGH
    #elif defined(OKNXHW_OPENKNXIAO_RP2040)
        #define PROG_LED_PIN OKNXHW_OPENKNXIAO_LED_1_RED
        #define PROG_LED_PIN_ACTIVE_ON LOW
        #ifdef OKNXHW_OPENKNXIAO_RP2040_V1_LED1 // OpenKNXiao RP2040 V1 LED1
            #define INFO1_LED_PIN OKNXHW_OPENKNXIAO_LED_1_GREEN
            #define INFO1_LED_PIN_ACTIVE_ON LOW
        #endif
        #ifdef OKNXHW_OPENKNXIAO_RP2040_V1_LED2 // OpenKNXiao RP2040 V1 LED2
            #define INFO2_LED_PIN OKNXHW_OPENKNXIAO_LED_1_BLUE
            #define INFO2_LED_PIN_ACTIVE_ON LOW
        #endif
    #endif
    #define PROG_BUTTON_PIN OKNXHW_OPENKNXIAO_D0      // GPIO26 | SPI1 SCK | UART0 CTS | I2C1 SDA | PWM5 A | ADC0
    #define OPENKNX_BUTTON_DEBOUNCE 0                 // Software Debouncer in ms. 0 will Disables software debounce. Since we use the hardware debounce.
    
    #define KNX_SERIAL Serial1
    #define KNX_UART_NUM 0
    #define KNX_UART_RX_PIN OKNXHW_OPENKNXIAO_D7
    #define KNX_UART_TX_PIN OKNXHW_OPENKNXIAO_D6
#endif

// OpenKNXiao RP2040 V1 Terminal Connections
#ifdef OKNXHW_OPENKNXIAO_V1_TERMINAL
    #define KNXIAO_TERM_PIN1 OKNXHW_OPENKNXIAO_D1
    #define KNXIAO_TERM_PIN2 OKNXHW_OPENKNXIAO_D2
    #define KNXIAO_TERM_PIN3 OKNXHW_OPENKNXIAO_D3
    #ifdef OKNXHW_OPENKNXIAO_V1_TERMINAL_MINI // OpenKNXiao RP2040 V1 Terminal Mini Connections
      #define KNXIAO_TERM_PIN4 OKNXHW_OPENKNXIAO_D4
      #define KNXIAO_TERM_PIN5 OKNXHW_OPENKNXIAO_D5
    #elif defined(OKNXHW_OPENKNXIAO_V1_TERMINAL_NEOPIXEL) // OpenKNXiao RP2040 V1 Terminal Isolated Connections
      #define KNXIAO_TERM_PIN_NEOPIN1 OKNXHW_OPENKNXIAO_D4
      #define KNXIAO_TERM_PIN_NEOPIN2 OKNXHW_OPENKNXIAO_D5
    #endif
    #define KNXIAO_TERM_PIN6 OKNXHW_OPENKNXIAO_D8
    #define KNXIAO_TERM_PIN7 OKNXHW_OPENKNXIAO_D9
    #define KNXIAO_TERM_PIN8 OKNXHW_OPENKNXIAO_D10
#endif


/**
 * Section: Hardware specific Pin Definitions
 * OpenKNXiao SAMD21
 */

// OpenKNXiao SAMD V1 LED1
#ifdef OKNXHW_OPENKNXIAO_SAMD21_V1_LED1
    #define INFO1_LED_PIN 11 // Build-In 1st LED BLUE
    #define INFO1_LED_PIN_ACTIVE_ON HIGH
#endif

// OpenKNXiao SAMD V1 LED2
#ifdef OKNXHW_OPENKNXIAO_SAMD21_V1_LED2
    #define INFO2_LED_PIN 12 // Build-In 2nd LED also BLUE
    #define INFO2_LED_PIN_ACTIVE_ON HIGH
#endif

/**
 * Section: Common Hardware (CHW) Pin Definitions
 * OpenKNXiao SAMD21
 */

// OpenKNXiao SAMD21 CHW Pins
#ifdef OKNXHW_OPENKNXIAO_SAMD21_V1_COMMON
    #define PROG_LED_PIN 13                      // Build-In LED YELLOW
    #define PROG_LED_PIN_ACTIVE_ON HIGH          // Active on HIGH
    #define PROG_BUTTON_PIN 0                    // GPIO0 | UART0 RX | I2C1 SDA | PWM0 A
    #define OPENKNX_BUTTON_DEBOUNCE 0            // Software Debouncer delay in ms. 0 will Disables software debounce. Since we use the hardware debounce.
    
    #define KNX_SERIAL Serial1                   // Serial1 for UART1
    #define KNX_UART_NUM 0
    #define KNX_UART_RX_PIN 6                    // GPIO6 | SPI1 TX  | UART1 RX  | I2C0 SCL | PWM4 B
    #define KNX_UART_TX_PIN 7                    // GPIO7 | SPI1 RX  | UART1 TX  | I2C0 SDA | PWM4 A

    // Possible pins for the OpenKNXiao SAMD21 V1
    #define KNXIAO_SAMD21_PIN1 1  // GPIO1  | SPI0 CSn | UART1 RTS | I2C1 SCL | PWM1 A
    #define KNXIAO_SAMD21_PIN2 2  // GPIO2  | SPI0 TX  | UART1 RTS | I2C1 SDA | PWM1 B
    #define KNXIAO_SAMD21_PIN3 3  // GPIO3  | SPI0 RX  | UART1 TX  | I2C1 SCL | PWM2 B
    #define KNXIAO_SAMD21_PIN4 4  // GPIO4  | SPI0 RX  | UART1 TX  | I2C0 SDA | PWM2 A
    #define KNXIAO_SAMD21_PIN5 5  // GPIO5  | SPI0 TX  | UART1 RX  | I2C0 SCL | PWM3 A
    #define KNXIAO_SAMD21_PIN6 8  // GPIO8  | SPI1 RX  | UART1 TX  | I2C0 SDA | PWM4 A
    #define KNXIAO_SAMD21_PIN7 9  // GPIO9  | SPI1 TX  | UART1 RX  | I2C0 SCL | PWM4 B
    #define KNXIAO_SAMD21_PIN8 10 // GPIO10 | SPI1 SCK | UART1 CTS | I2C1 SDA | PWM5 A
#endif

// OpenKNXiao SAMD21 V1 Terminal Connections
#ifdef OKNXHW_OPENKNXIAO_SAMD21_V1_TERMINAL
    #define KNXIAO_SAMD21_TERM_PIN1 KNXIAO_SAMD21_PIN1 // GPIO1  | SPI0 CSn | UART1 RTS | I2C1 SCL | PWM1 A
    #define KNXIAO_SAMD21_TERM_PIN2 KNXIAO_SAMD21_PIN2 // GPIO2  | SPI0 TX  | UART1 RTS | I2C1 SDA | PWM1 B
    #define KNXIAO_SAMD21_TERM_PIN3 KNXIAO_SAMD21_PIN3 // GPIO3  | SPI0 RX  | UART1 TX  | I2C1 SCL | PWM2 B

    #define KNXIAO_SAMD21_TERM_PIN6 KNXIAO_SAMD21_PIN6 // GPIO8  | SPI1 RX  | UART1 TX  | I2C0 SDA | PWM4 A
    #define KNXIAO_SAMD21_TERM_PIN7 KNXIAO_SAMD21_PIN7 // GPIO9  | SPI1 TX  | UART1 RX  | I2C0 SCL | PWM4 B
    #define KNXIAO_SAMD21_TERM_PIN8 KNXIAO_SAMD21_PIN8 // GPIO10 | SPI1 SCK | UART1 CTS | I2C1 SDA | PWM5 A
#endif

// OpenKNXiao SAMD21 V1 Terminal Mini Connections
#ifdef OKNXHW_OPENKNXIAO_SAMD21_TERMINAL_MINI
    #define KNXIAO_SAMD21_TERM_PIN4 KNXIAO_SAMD21_PIN4 // GPIO4  | SPI0 RX  | UART1 TX  | I2C0 SDA | PWM2 A
    #define KNXIAO_SAMD21_TERM_PIN5 KNXIAO_SAMD21_PIN5 // GPIO5  | SPI0 TX  | UART1 RX  | I2C0 SCL | PWM3 A
#endif