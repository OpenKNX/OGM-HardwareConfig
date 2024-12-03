#pragma once
/**
 * OpenKNX Hardware Definition Header File
 *
 * File: REG2-ESP-S3-Pico.h
 * Hardware: REG2-ESP-S3-Pico Based Boards (V1) (NOT TESTED !!!)
 * Responsible: OpenKNX - Erkan Çolak
 * 
 * Hardware Info visit: https://github.com/OpenKNX/OpenKNX-Pi-Pico-REG2
 *
 * ATTENTION:
 *    Do not include this file directly.
 *    It will be included by the REG2.h file.
 *
 */


// Example: REG2-ESP-S3-Pico V1
#if EITHER(OKNXHW_REG2_ESP_S3_PICO_V1, OKNXHW_REG2_ESP_S3_PICO_V1_DD_METER, OKNXHW_REG2_ESP_S3_PICO_W_V1, \
           OKNXHW_REG2_ESP_S3_PICO_W_V1_DD_METER, OKNXHW_REG2_ESP_S3_PICO_W_ETH_V1, OKNXHW_REG2_ESP_S3_PICO_W_ETH_V1_DD_METER)
    #define PREFIX_ID "REG2-ESP-V1" // 12 characters
    #define PREFIX_NAME "OpenKNX REG2 ESP-Pico V1" // 24 characters
#endif

/*
Mapping PiPico to ESP-S3-Pico
GPIO0  -> GPIO11        GPIO16 -> GPIO42     
GPIO1  -> GPIO12        GPIO17 -> GPIO41     
GPIO2  -> GPIO13        GPIO18 -> GPIO1      
GPIO3  -> GPIO14        GPIO19 -> GPIO2      
GPIO4  -> GPIO15        GPIO20 -> GPIO4      
GPIO5  -> GPIO16        GPIO21 -> GPIO5      
GPIO6  -> GPIO17        GPIO22 -> GPIO6      
GPIO7  -> GPIO18        RUN    -> RUN        
GPIO8  -> GPIO33        GPIO26 -> GPIO7      
GPIO9  -> GPIO34        GPIO27 -> GPIO8      
GPIO10 -> GPIO35        GPIO28 -> GPIO9      
GPIO11 -> GPIO36        ADC_VREF -> GPIO10   
GPIO12 -> GPIO37        3V3    -> 3V3        
GPIO13 -> GPIO38        3v3_EN -> 3v3_EN     
GPIO14 -> GPIO39        GND    -> GND        
GPIO15 -> GPIO40        VSYS   -> VSYS       
                        VBUS   -> VBUS       
*/

/*
ESP32-S3 GPIO Pinout and Features

 PiPico    | ESP Pin| Digital I/O | PWM | ADC | I2C  | SPI  | UART  | Special Features          | Debugging (JTAG)
 ----------| -------|-------------|-----|-----|------|------|-------|-------------------------- |-----------------
(GPIO0   ) | GPIO11 | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO1   ) | GPIO12 | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO2   ) | GPIO13 | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO3   ) | GPIO14 | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO4   ) | GPIO15 | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO5   ) | GPIO16 | Yes         | Yes | No  | I2C1 | SPI3 | UART1 | -                         | -  
(GPIO6   ) | GPIO17 | Yes         | Yes | No  | I2C1 | SPI3 | UART1 | -                         | -  
(GPIO7   ) | GPIO18 | Yes         | Yes | No  | I2C1 | SPI3 | UART1 | -                         | -  
(GPIO8   ) | GPIO33 | Yes         | No  | Yes | No   | No   | No    | ADC1 Channel (Input only) | -  
(GPIO9   ) | GPIO34 | Yes         | No  | Yes | No   | No   | No    | ADC1 Channel (Input only) | -  
(GPIO10  ) | GPIO35 | Yes (Input) | No  | Yes | No   | No   | No    | ADC1 Channel (Input only) | -  
(GPIO11  ) | GPIO36 | Yes         | No  | Yes | No   | No   | No    | ADC1 Channel              | -  
(GPIO12  ) | GPIO37 | Yes (Input) | No  | Yes | No   | No   | No    | ADC1 Channel (Input only) | -  
(GPIO13  ) | GPIO38 | Yes (Input) | No  | Yes | No   | No   | No    | ADC1 Channel (Input only) | 
(GPIO14  ) | GPIO39 | Yes (Input) | No  | Yes | No   | No   | No    | ADC1 Channel (Input only) | JTAG-TCK (Test Clock)
(GPIO15  ) | GPIO40 | Yes         | Yes | No  | No   | No   | No    | -                         | JTAG-TDO (Test Data Out)
(GPIO16  ) | GPIO42 | Yes         | Yes | No  | No   | No   | No    | -                         | JTAG TMS (Test Mode Select)
(GPIO17  ) | GPIO41 | Yes         | Yes | No  | No   | No   | No    | -                         | JTAG TDI (Test Data In)
(GPIO18  ) | GPIO1  | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO19  ) | GPIO2  | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO20  ) | GPIO4  | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO21  ) | GPIO5  | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO22  ) | GPIO6  | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(RUN     ) | RUN    | -           | -   | -   | -    | -    | -     | System reset pin          | -  
(GPIO26  ) | GPIO7  | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO27  ) | GPIO8  | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(GPIO28  ) | GPIO9  | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
(ADC_VREF) | GPIO10 | Yes         | Yes | No  | I2C0 | SPI2 | UART0 | -                         | -  
*/

/**
 * Section: Common Hardware (CHW) Pin Definitions
 * REG2-ESP-S3-Pico V1
 */

// REG2-ESP-S3-Pico V1 CHW Pins
#ifdef OKNXHW_REG2_ESPS3PICO_V1_COMMON
  #define PROG_LED_PIN 13
  #define PROG_LED_PIN_ACTIVE_ON HIGH
  #define PROG_BUTTON_PIN 4
  #define PROG_BUTTON_PIN_INTERRUPT_ON FALLING
  #define KNX_SERIAL Serial1
  #define KNX_UART_RX_PIN 12
  #define KNX_UART_TX_PIN 11

  #define SAVE_INTERRUPT_PIN 5

  // Application board
  #define REG2_APP_PIN1 2  // GPIO2  | SPI0 TX  | UART0 RTS | I2C1 SCL | PWM1 B
  #define REG2_APP_PIN2 9  // GPIO9  | SPI1 RX  | UART0 TX  | I2C0 SDA | PWM6 A | ADC2
  #define REG2_APP_PIN3 8  // GPIO8  | SPI1 TX  | UART0 RX  | I2C0 SCL | PWM6 B | ADC1
  #define REG2_APP_PIN4 7  // GPIO7  | SPI1 SCK | UART0 CTS | I2C1 SDA | PWM5 A | ADC0
  #define REG2_APP_PIN5 1  // GPIO1  | SPI0 SCK | UART0 CTS | I2C1 SDA | PWM1 A
  #define REG2_APP_PIN6 41 // GPIO41 | SPI0 CSn | UART0 RX  | I2C0 SCL | PWM0 B
  #define REG2_APP_PIN7 42 // GPIO42 | SPI0 RX  | UART0 TX  | I2C0 SDA | PWM0 A

  // Application board extended pins
  #define REG2_APP_PIN8 10  // GPIO10 | SPI1 SCK | UART1 CTS | I2C1 SDA | PWM5 A
  #define REG2_APP_PIN9 11  // GPIO11 | SPI1 TX  | UART1 RTS | I2C1 SCL | PWM7 B
  #define REG2_APP_PIN10 12 // GPIO12 | SPI1 RX  | UART0 TX  | I2C0 SDA | PWM6 A
  #define REG2_APP_PIN11 13 // GPIO13 | SPI1 RX  | UART0 TX  | I2C0 SDA | PWM6 B
  #define REG2_APP_PIN12 14 // GPIO14 | SPI1 SCK | UART0 CTS | I2C1 SDA | PWM7 A
  #define REG2_APP_PIN13 15 // GPIO15 | SPI1 TX  | UART0 RTS | I2C1 SCL | PWM7 B

  // Terminal board
  #define REG2_TERM_PIN10 6  // GPIO6  | SPI0 SCK | UART1 CTS | I2C1 SDA | PWM3 A
  #define REG2_TERM_PIN9 34  // GPIO34 | SPI1 TX  | UART1 RX  | I2C0 SCL | PWM4 B
  #define REG2_TERM_PIN8 33  // GPIO33 | SPI1 RX  | UART1 TX  | I2C0 SDA | PWM4 A
  #define REG2_TERM_PIN7 18  // GPIO18 | SPI0 CSn | UART1 RTS | I2C1 SCL | PWM3 B
  #define REG2_TERM_PIN6 17  // GPIO17 | SPI0 SCK | UART1 CTS | I2C1 SDA | PWM3 A
  #define REG2_TERM_PIN5 16  // GPIO16 | SPI0 TX  | UART1 RX  | I2C0 SCL | PWM2 B
  #define REG2_TERM_PIN4 15  // GPIO15 | SPI0 RX  | UART1 TX  | I2C0 SDA | PWM2 A

#endif
