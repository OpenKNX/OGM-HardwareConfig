#pragma once
/**
 * OpenKNX Hardware Definition Header File
 *
 * File: OpenKNX-REG2-PiPico-Hardware.h
 * Hardware: REG2-Pi-Pico Based Boards (V1)
 * Responsible: OpenKNX - Erkan Çolak
 *
 * Defines hardware IO pins and functionalities for OpenKNX REG2-Pi-Pico platform.
 *
 * ATTENTION:
 *    Do not include this file directly.
 *    It will be included by the REG2.h file.
 *
 */

/** ToDo: 
 *  
 * Idea:
 * Section: Product configurations / use cases
 *          Describes the available configurations for the OpenKNX REG2-Pi-Pico hardware.
 * Section: Hardware specific Pin Definitions
 *          Defines the pin assignments for the seperate hardware specific configurations.
 * Section: Common Hardware (CHW) Pin Definitions
 *          Defines the pin assignments for the common hardware features.
 * Section: Device Module based IO and Pin Definitions
 *          Defines the pin assignments for the firmware features.
 * 
 * 
 */


/**
 * Section: Device configurations / use cases ( Device is a full defined hardware has documentation in openknx wiki)
 * OpenKNX REG2-Pi-Pico
 */

#if EITHER( OKNXHW_REG2_PIPICO_V1, OKNXHW_REG2_PIPICO_V1_DD_METER, OKNXHW_REG2_PIPICO_ETH_V1, \
            OKNXHW_REG2_PIPICO_ETH_V1_DD_METER, OKNXHW_REG2_PIPICO_W_V1, OKNXHW_REG2_PIPICO_W_V1_DD_METER, \
            OKNXHW_REG2_PIPICO_W_ETH_V1, OKNXHW_REG2_PIPICO_W_ETH_V1_DD_METER)
    #define PREFIX_ID "REG2-PP-V1" // 12 characters
    #define PREFIX_NAME "OpenKNX REG2 PiPico V1" // 24 characters
#endif

// REG2-Pi-Pico V1
#ifdef OKNXHW_REG2_PIPICO_V1
    #define DEVICE_ID   PREFIX_ID
    #define DEVICE_NAME PREFIX_NAME
    #define OKNXHW_REG2_PIPICO_V1_COMMON // Common pins for all REG2-Pi-Pico
    #define OKNXHW_REG2_PIPICO_V1_LED1   // LED1
    #define OKNXHW_REG2_PIPICO_V1_LED2   // LED2
    #define OKNXHW_REG2_PIPICO_V1_LED3   // LED3
#endif

// REG2-Pi-Pico V1 (Device Display + Meter) 
#ifdef OKNXHW_REG2_PIPICO_V1_DD_METER
    #define DEVICE_ID   PREFIX_ID "-DD-Meter" // 12 + 8 = 20 characters
    #define DEVICE_NAME PREFIX_NAME " DeviceDisplay Meter" // 24 + 16 = 40 characters
    #define OKNXHW_REG2_PIPICO_V1_COMMON // Common pins for all REG2-Pi-Pico
    #define OKNXHW_REG2_PIPICO_V1_LED1   // LED1
    #define OKNXHW_REG2_PIPICO_V1_LED2   // LED2
    #define OKNXHW_REG2_PIPICO_V1_LED3   // LED3
    #define OKNXHW_REG2_DEVICE_DISPLAY   // Device Display Support
    #define OKNXHW_REG2_METER            // Meter Support
    #define OKNXHW_REG2_DEVICE_RTC      // RTC Support
#endif

// REG2-Pi-Pico V1 ETH App
#ifdef OKNXHW_REG2_PIPICO_ETH_V1
    #define DEVICE_ID   PREFIX_ID "-ETH" // 12 + 4 = 16 characters
    #define DEVICE_NAME PREFIX_NAME " Ethernet" // 24 + 9 = 33 characters
    #define OKNXHW_REG2_PIPICO_V1
    #define OKNXHW_REG2_PIPICO_V1_COMMON
    #define OKNXHW_REG2_PIPICO_V1_LED1
    #define OKNXHW_REG2_PIPICO_V1_LED2
    #define OKNXHW_REG2_PIPICO_V1_LED3
    #define OKNXHW_REG2_PIPICO_APP_ETH
#endif

// REG2-Pi-Pico V1 ETH App (Device Display + Meter)
#ifdef OKNXHW_REG2_PIPICO_ETH_V1_DD_METER
    #define DEVICE_ID   PREFIX_ID "-ETH-DD" // 12 + 12 = 24 characters
    #define DEVICE_NAME PREFIX_NAME " Ethernet Display Meter" // 24 + 20 = 44 characters
    #define OKNXHW_REG2_PIPICO_V1
    #define OKNXHW_REG2_PIPICO_V1_COMMON
    #define OKNXHW_REG2_PIPICO_V1_LED1
    #define OKNXHW_REG2_PIPICO_V1_LED2
    #define OKNXHW_REG2_PIPICO_V1_LED3
    #define OKNXHW_REG2_PIPICO_APP_ETH
    #define OKNXHW_REG2_DEVICE_DISPLAY
    #define OKNXHW_REG2_METER
#endif

/**
 * Section: Product configurations / use cases
 * OpenKNX REG2-Pi-Pico Wi-Fi
 */

// REG2-Pi-Pico Wi-Fi V1
#ifdef OKNXHW_REG2_PIPICO_W_V1
    #define DEVICE_ID   PREFIX_ID "-W" // 12 + 2 = 14 characters
    #define DEVICE_NAME PREFIX_NAME " WiFi" // 24 + 5 = 29 characters --> + 14 = 43 characters
    #define OKNXHW_REG2_PIPICO_V1_COMMON
    #define OKNXHW_REG2_PIPICO_W_V1_LED1
    #define OKNXHW_REG2_PIPICO_V1_LED2
    #define OKNXHW_REG2_PIPICO_V1_LED3
#endif

// REG2-Pi-Pico Wi-Fi V1 (Device Display + Meter)
#ifdef OKNXHW_REG2_PIPICO_W_V1_DD_METER
    #define DEVICE_ID   PREFIX_ID "-W-DD-Meter" // 12 + 8 = 20 characters
    #define DEVICE_NAME PREFIX_NAME " WiFi Display Meter" // 24 + 20 = 44 characters --> + 20 = 64 characters
    #define OKNXHW_REG2_PIPICO_V1_COMMON
    #define OKNXHW_REG2_PIPICO_W_V1_LED1
    #define OKNXHW_REG2_PIPICO_V1_LED2
    #define OKNXHW_REG2_PIPICO_V1_LED3
    #define OKNXHW_REG2_DEVICE_DISPLAY
    #define OKNXHW_REG2_METER
#endif

// REG2-Pi-Pico WiFi V1 ETH App
#ifdef OKNXHW_REG2_PIPICO_W_ETH_V1
    #define DEVICE_ID   PREFIX_ID "-W-ETH" // 12 + 6 = 18 characters
    #define DEVICE_NAME PREFIX_NAME " WiFi Ethernet" // 24 + 9 = 33 characters --> + 18 = 51 characters
    #define OKNXHW_REG2_PIPICO_W_V1
    #define OKNXHW_REG2_PIPICO_V1_COMMON
    #define OKNXHW_REG2_PIPICO_W_V1_LED1
    #define OKNXHW_REG2_PIPICO_V1_LED2
    #define OKNXHW_REG2_PIPICO_V1_LED3
    #define OKNXHW_REG2_PIPICO_APP_ETH
#endif

// REG2-Pi-Pico WiFi V1 ETH App (Device Display + Meter)
#ifdef OKNXHW_REG2_PIPICO_W_ETH_V1_DD_METER
    #define DEVICE_ID   PREFIX_ID "-W-ETH-DD-Meter" // 12 + 12 = 24 characters
    #define DEVICE_NAME PREFIX_NAME " WiFi Eth Disp. Meter" // 24 + 20 = 44 characters --> + 24 = 68 characters
    #define OKNXHW_REG2_PIPICO_W_V1
    #define OKNXHW_REG2_PIPICO_V1_COMMON
    #define OKNXHW_REG2_PIPICO_W_V1_LED1
    #define OKNXHW_REG2_PIPICO_V1_LED2
    #define OKNXHW_REG2_PIPICO_V1_LED3
    #define OKNXHW_REG2_PIPICO_APP_ETH
    #define OKNXHW_REG2_DEVICE_DISPLAY
    #define OKNXHW_REG2_METER
#endif

/**
 * Section: Firmware Features (FwF) based IO and Pin Definitions
 * OpenKNX REG2-Pi-Pico
 */

// REG2-Pi-Pico FwF: Device Display Support
#ifdef OKNXHW_REG2_DEVICE_DISPLAY
    // Default pins for the I2C bus to connect the hardware display
    #define OKNXHW_REG2_HWDISPLAY_I2C_0_1 1        // 0: I2C0, 1: I2C1
    #define OKNXHW_REG2_HWDISPLAY_I2C_SDA 26       // GPIO26 | SPI1 SCK | UART0 CTS | I2C1 SDA | PWM5 A | ADC0
    #define OKNXHW_REG2_HWDISPLAY_I2C_SCL 27       // GPIO27 | SPI1 TX  | UART0 RX  | I2C0 SCL | PWM6 B | ADC1
    #define OKNXHW_REG2_HWDISPLAY_I2C_ADDRESS 0x3C // Set here the i2c address of the display. I.e. 0x3C, 0x3D
    #define OKNXHW_REG2_HWRTCLOCK_I2C_ADDRESS 0x68 // Set here the i2c address of the RTC. I.e. 0x68 for DS3231. 0x57 for PCF8523. 0x51 for DS3232
    #define OKNXHW_REG2_DEVICE_DISPLAY_WIDTH 128   // Set here the width of the device display. I.e. 128
    #define OKNXHW_REG2_DEVICE_DISPLAY_HEIGHT 64   // Set here the height of the device display. I.e. 64
    
    // Set there now the generall setting definition for the OFM-DeviceDisplay
    #define OKNXHW_DEVICE_DISPLAY_I2C_0_1 OKNXHW_REG2_HWDISPLAY_I2C_0_1
    #define OKNXHW_DEVICE_DISPLAY_I2C_SDA OKNXHW_REG2_HWDISPLAY_I2C_SDA
    #define OKNXHW_DEVICE_DISPLAY_I2C_SCL OKNXHW_REG2_HWDISPLAY_I2C_SCL
    #define OKNXHW_DEVICE_DISPLAY_I2C_ADDRESS OKNXHW_REG2_HWDISPLAY_I2C_ADDRESS
    #define OKNXHW_DEVICE_DISPLAY_WIDTH OKNXHW_REG2_DEVICE_DISPLAY_WIDTH
    #define OKNXHW_DEVICE_DISPLAY_HEIGHT OKNXHW_REG2_DEVICE_DISPLAY_HEIGHT

#endif // REG2-Pi-Pico FwF: Device Display Support

// REG2-Pi-Pico FwF: Device RTC Support
#ifdef OKNXHW_REG2_DEVICE_RTC
    // Default pins for the I2C bus to connect the hardware RTC
    #define OKNXHW_REG2_HWRTC_I2C_ADDRESS 0x68 // Set here the i2c address of the RTC. I.e. 0x68 for DS3231. 0x57 for PCF8523. 0x51 for DS3232
    #define OKNXHW_REG2_HWRTC_I2C_0_1 1        // 0: I2C0, 1: I2C1
    #define OKNXHW_REG2_HWRTC_I2C_SDA 26       // GPIO26 | SPI1 SCK | UART0 CTS | I2C1 SDA | PWM5 A | ADC0
    #define OKNXHW_REG2_HWRTC_I2C_SCL 27       // GPIO27 | SPI1 TX  | UART0 RX  | I2C0 SCL | PWM6 B | ADC1
    
    // Set there now the generall setting definition for the OFM-DeviceRTC
    #define OKNXHW_DEVICE_RTC_I2C_ADDRESS OKNXHW_REG2_HWRTC_I2C_ADDRESS
    #define OKNXHW_DEVICE_RTC_I2C_SDA OKNXHW_REG2_HWRTC_I2C_SDA
    #define OKNXHW_DEVICE_RTC_I2C_SCL OKNXHW_REG2_HWRTC_I2C_SCL
    #define OKNXHW_DEVICE_RTC_I2C_0_1 OKNXHW_REG2_HWRTC_I2C_0_1
#endif // REG2-Pi-Pico FwF: Device RTC Support

// REG2-Pi-Pico FwF: Meter Support
#ifdef OKNXHW_REG2_METER
    // Default pins for the Meter Sensors typ Rx/Tx
    #define OKNXHW_REG2_MSENS_1_SDA0_TX_PIN 4 // GPIO4  | SPI0 RX  | UART1 TX  | I2C0 SDA | PWM2 A
    #define OKNXHW_REG2_MSENS_1_SCL0_RX_PIN 5 // GPIO5  | SPI0 TX  | UART1 RX  | I2C0 SCL | PWM2 B
    #define OKNXHW_REG2_MSENS_2_SDA1_TX_PIN 6 // GPIO6  | SPI0 SCK | UART1 CTS | I2C1 SDA | PWM3 A
    #define OKNXHW_REG2_MSENS_2_SCL1_RX_PIN 7 // GPIO7  | SPI0 CSn | UART1 RTS | I2C1 SCL | PWM3 B
#endif                                        // REG2-Pi-Pico (Device Display + Meter)

/**
 * Section: Hardware specific Pin Definitions
 * OpenKNX REG2-Pi-Pico
 */

// REG2-Pi-Pico V1: Info1 LED
#ifdef OKNXHW_REG2_PIPICO_V1_LED1
    #define INFO1_LED_PIN 25 // PiPico Onboard LED
    #define INFO1_LED_PIN_ACTIVE_ON HIGH
#endif

// REG2-Pi-Pico Wifi V1: Info1 LED
#ifdef OKNXHW_REG2_PIPICO_W_V1_LED1
    #define INFO1_LED_PIN 32 // PiPicoW Onboard LED
    #define INFO1_LED_PIN_ACTIVE_ON HIGH
#endif

// REG2-Pi-Pico V1: Info2 LED
#ifdef OKNXHW_REG2_PIPICO_V1_LED2
    #define INFO2_LED_PIN 3
    #define INFO2_LED_PIN_ACTIVE_ON HIGH
#endif
// REG2-Pi-Pico V1: Info3 LED
#ifdef OKNXHW_REG2_PIPICO_V1_LED3
    #define INFO3_LED_PIN 21
    #define INFO3_LED_PIN_ACTIVE_ON HIGH
#endif

// REG2-Pi-Pico V1: Interrupt Pin
#ifdef OKNXHW_REG2_PIPICO_V1_SAVE_INTERRUPT
    #define SAVE_INTERRUPT_PIN 21
#endif

/**
 * Section: Common Hardware (CHW) Pin Definitions
 * REG2-Pi-Pico V1
 */
// REG2-Pi-Pico V1 CHW Pins
#ifdef OKNXHW_REG2_PIPICO_V1_COMMON
    #define PROG_LED_PIN 2
    #define PROG_LED_PIN_ACTIVE_ON HIGH
    #define PROG_BUTTON_PIN 20
    #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
    #define KNX_SERIAL Serial1
    #define KNX_UART_RX_PIN 1
    #define KNX_UART_TX_PIN 0

    // Application board
    #define REG2_APP_PIN1 19 // GPIO19 | SPI0 TX  | UART0 RTS | I2C1 SCL | PWM1 B
    #define REG2_APP_PIN2 28 // GPIO28 | SPI1 RX  | UART0 TX  | I2C0 SDA | PWM6 A | ADC2
    #define REG2_APP_PIN3 27 // GPIO27 | SPI1 TX  | UART0 RX  | I2C0 SCL | PWM6 B | ADC1
    #define REG2_APP_PIN4 26 // GPIO26 | SPI1 SCK | UART0 CTS | I2C1 SDA | PWM5 A | ADC0
    #define REG2_APP_PIN5 18 // GPIO18 | SPI0 SCK | UART0 CTS | I2C1 SDA | PWM1 A
    #define REG2_APP_PIN6 17 // GPIO17 | SPI0 CSn | UART0 RX  | I2C0 SCL | PWM0 B
    #define REG2_APP_PIN7 16 // GPIO16 | SPI0 RX  | UART0 TX  | I2C0 SDA | PWM0 A

    // Application board extended pins
    #define REG2_APP_PIN8 10  // GPIO10 | SPI1 SCK | UART1 CTS | I2C1 SDA | PWM5 A
    #define REG2_APP_PIN9 11  // GPIO11 | SPI1 TX  | UART1 RTS | I2C1 SCL | PWM7 B
    #define REG2_APP_PIN10 12 // GPIO12 | SPI1 RX  | UART0 TX  | I2C0 SDA | PWM6 A
    #define REG2_APP_PIN11 13 // GPIO13 | SPI1 RX  | UART0 TX  | I2C0 SDA | PWM6 B
    #define REG2_APP_PIN12 14 // GPIO14 | SPI1 SCK | UART0 CTS | I2C1 SDA | PWM7 A
    #define REG2_APP_PIN13 15 // GPIO15 | SPI1 TX  | UART0 RTS | I2C1 SCL | PWM7 B

    // Terminal board
    #define REG2_TERM_PIN10 22 // GPIO22 | SPI0 SCK | UART1 CTS | I2C1 SDA | PWM3 A
    #define REG2_TERM_PIN9 9   // GPIO9  | SPI1 TX  | UART1 RX  | I2C0 SCL | PWM4 B
    #define REG2_TERM_PIN8 8   // GPIO8  | SPI1 RX  | UART1 TX  | I2C0 SDA | PWM4 A
    #define REG2_TERM_PIN7 7   // GPIO7  | SPI0 CSn | UART1 RTS | I2C1 SCL | PWM3 B
    #define REG2_TERM_PIN6 6   // GPIO6  | SPI0 SCK | UART1 CTS | I2C1 SDA | PWM3 A
    #define REG2_TERM_PIN5 5   // GPIO5  | SPI0 TX  | UART1 RX  | I2C0 SCL | PWM2 B
    #define REG2_TERM_PIN4 4   // GPIO4  | SPI0 RX  | UART1 TX  | I2C0 SDA | PWM2 A

#endif

/**
 * Section: FwF and CHW based Pin Definitions
 * OpenKNX REG2-Pi-Pico
 */

// REG2-Pi-Pico (WiFi) ETH App and FwF
#if defined OKNXHW_REG2_PIPICO_APP_ETH
    #define ETH_SPI_INTERFACE SPI        // SPI or SPI1, depends on the pins
    #define PIN_ETH_MISO (REG2_APP_PIN7) // ETH_MISO - GPIO16 SPI0 RX UART0 TX I2C0 SDA PWM0_A SIO PIO0 PIO1
    #define PIN_ETH_SS (REG2_APP_PIN6)   // ETH_CS   - GPIO17 SPI0 CSn UART0 RX I2C0 SCL PWM0_B SIO PIO0 PIO1
    #define PIN_ETH_SCK (REG2_APP_PIN5)  // ETH_SCK  - GPIO18 SPI0 SCK UART0 CTS I2C1 SDA PWM1_A SIO PIO0 PIO1
    #define PIN_ETH_MOSI (REG2_APP_PIN1) // ETH_MOSI - GPIO19 SPI0 TX UART0 RTS I2C1 SCL PWM1_B SIO PIO0 PIO1
    #define PIN_ETH_INT (REG2_APP_PIN4)  // ETH_RES  - GPIO26 SPI1 SCK UART0 CTS I2C1 SDA PWM5_A SIO PIO0 PIO1
    #define PIN_ETH_RES (REG2_APP_PIN3)  // ETH_INT  - GPIO27 SPI1 TX UART0 RTS I2C1 SCL PWM5_B SIO PIO0 PIO1
#endif