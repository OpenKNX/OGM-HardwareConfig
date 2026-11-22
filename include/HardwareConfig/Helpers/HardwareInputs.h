#pragma once
#include <stdint.h>
#include "HardwareConfig.h"
// HW_INPUT_n_MODE: 0=external bias, 1=internal pullup, 2=internal pulldown.
// HW_INPUT_n_ONLEVEL: 0=LOW (default), 1=HIGH. GPIO 255 disables a connection.
#define HW_INPUTS_MAX 64
#ifndef HW_INPUT_COUNT
    #define HW_INPUT_COUNT 0
#endif
static_assert(HW_INPUT_COUNT >= 0 && HW_INPUT_COUNT <= HW_INPUTS_MAX, "Invalid HW_INPUT_COUNT");
#if HW_INPUT_COUNT >= 1
    #ifndef HW_INPUT_1_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_1_GPIO >= 0 && HW_INPUT_1_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_1_MODE
        #define HW_INPUT_1_MODE 1
    #endif
    #ifndef HW_INPUT_1_ONLEVEL
        #define HW_INPUT_1_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_1_MODE >= 0 && HW_INPUT_1_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_1_ONLEVEL == 0 || HW_INPUT_1_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 2
    #ifndef HW_INPUT_2_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_2_GPIO >= 0 && HW_INPUT_2_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_2_MODE
        #define HW_INPUT_2_MODE 1
    #endif
    #ifndef HW_INPUT_2_ONLEVEL
        #define HW_INPUT_2_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_2_MODE >= 0 && HW_INPUT_2_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_2_ONLEVEL == 0 || HW_INPUT_2_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 3
    #ifndef HW_INPUT_3_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_3_GPIO >= 0 && HW_INPUT_3_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_3_MODE
        #define HW_INPUT_3_MODE 1
    #endif
    #ifndef HW_INPUT_3_ONLEVEL
        #define HW_INPUT_3_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_3_MODE >= 0 && HW_INPUT_3_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_3_ONLEVEL == 0 || HW_INPUT_3_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 4
    #ifndef HW_INPUT_4_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_4_GPIO >= 0 && HW_INPUT_4_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_4_MODE
        #define HW_INPUT_4_MODE 1
    #endif
    #ifndef HW_INPUT_4_ONLEVEL
        #define HW_INPUT_4_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_4_MODE >= 0 && HW_INPUT_4_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_4_ONLEVEL == 0 || HW_INPUT_4_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 5
    #ifndef HW_INPUT_5_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_5_GPIO >= 0 && HW_INPUT_5_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_5_MODE
        #define HW_INPUT_5_MODE 1
    #endif
    #ifndef HW_INPUT_5_ONLEVEL
        #define HW_INPUT_5_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_5_MODE >= 0 && HW_INPUT_5_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_5_ONLEVEL == 0 || HW_INPUT_5_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 6
    #ifndef HW_INPUT_6_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_6_GPIO >= 0 && HW_INPUT_6_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_6_MODE
        #define HW_INPUT_6_MODE 1
    #endif
    #ifndef HW_INPUT_6_ONLEVEL
        #define HW_INPUT_6_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_6_MODE >= 0 && HW_INPUT_6_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_6_ONLEVEL == 0 || HW_INPUT_6_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 7
    #ifndef HW_INPUT_7_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_7_GPIO >= 0 && HW_INPUT_7_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_7_MODE
        #define HW_INPUT_7_MODE 1
    #endif
    #ifndef HW_INPUT_7_ONLEVEL
        #define HW_INPUT_7_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_7_MODE >= 0 && HW_INPUT_7_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_7_ONLEVEL == 0 || HW_INPUT_7_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 8
    #ifndef HW_INPUT_8_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_8_GPIO >= 0 && HW_INPUT_8_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_8_MODE
        #define HW_INPUT_8_MODE 1
    #endif
    #ifndef HW_INPUT_8_ONLEVEL
        #define HW_INPUT_8_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_8_MODE >= 0 && HW_INPUT_8_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_8_ONLEVEL == 0 || HW_INPUT_8_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 9
    #ifndef HW_INPUT_9_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_9_GPIO >= 0 && HW_INPUT_9_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_9_MODE
        #define HW_INPUT_9_MODE 1
    #endif
    #ifndef HW_INPUT_9_ONLEVEL
        #define HW_INPUT_9_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_9_MODE >= 0 && HW_INPUT_9_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_9_ONLEVEL == 0 || HW_INPUT_9_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 10
    #ifndef HW_INPUT_10_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_10_GPIO >= 0 && HW_INPUT_10_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_10_MODE
        #define HW_INPUT_10_MODE 1
    #endif
    #ifndef HW_INPUT_10_ONLEVEL
        #define HW_INPUT_10_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_10_MODE >= 0 && HW_INPUT_10_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_10_ONLEVEL == 0 || HW_INPUT_10_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 11
    #ifndef HW_INPUT_11_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_11_GPIO >= 0 && HW_INPUT_11_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_11_MODE
        #define HW_INPUT_11_MODE 1
    #endif
    #ifndef HW_INPUT_11_ONLEVEL
        #define HW_INPUT_11_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_11_MODE >= 0 && HW_INPUT_11_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_11_ONLEVEL == 0 || HW_INPUT_11_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 12
    #ifndef HW_INPUT_12_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_12_GPIO >= 0 && HW_INPUT_12_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_12_MODE
        #define HW_INPUT_12_MODE 1
    #endif
    #ifndef HW_INPUT_12_ONLEVEL
        #define HW_INPUT_12_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_12_MODE >= 0 && HW_INPUT_12_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_12_ONLEVEL == 0 || HW_INPUT_12_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 13
    #ifndef HW_INPUT_13_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_13_GPIO >= 0 && HW_INPUT_13_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_13_MODE
        #define HW_INPUT_13_MODE 1
    #endif
    #ifndef HW_INPUT_13_ONLEVEL
        #define HW_INPUT_13_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_13_MODE >= 0 && HW_INPUT_13_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_13_ONLEVEL == 0 || HW_INPUT_13_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 14
    #ifndef HW_INPUT_14_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_14_GPIO >= 0 && HW_INPUT_14_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_14_MODE
        #define HW_INPUT_14_MODE 1
    #endif
    #ifndef HW_INPUT_14_ONLEVEL
        #define HW_INPUT_14_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_14_MODE >= 0 && HW_INPUT_14_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_14_ONLEVEL == 0 || HW_INPUT_14_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 15
    #ifndef HW_INPUT_15_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_15_GPIO >= 0 && HW_INPUT_15_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_15_MODE
        #define HW_INPUT_15_MODE 1
    #endif
    #ifndef HW_INPUT_15_ONLEVEL
        #define HW_INPUT_15_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_15_MODE >= 0 && HW_INPUT_15_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_15_ONLEVEL == 0 || HW_INPUT_15_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 16
    #ifndef HW_INPUT_16_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_16_GPIO >= 0 && HW_INPUT_16_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_16_MODE
        #define HW_INPUT_16_MODE 1
    #endif
    #ifndef HW_INPUT_16_ONLEVEL
        #define HW_INPUT_16_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_16_MODE >= 0 && HW_INPUT_16_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_16_ONLEVEL == 0 || HW_INPUT_16_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 17
    #ifndef HW_INPUT_17_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_17_GPIO >= 0 && HW_INPUT_17_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_17_MODE
        #define HW_INPUT_17_MODE 1
    #endif
    #ifndef HW_INPUT_17_ONLEVEL
        #define HW_INPUT_17_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_17_MODE >= 0 && HW_INPUT_17_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_17_ONLEVEL == 0 || HW_INPUT_17_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 18
    #ifndef HW_INPUT_18_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_18_GPIO >= 0 && HW_INPUT_18_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_18_MODE
        #define HW_INPUT_18_MODE 1
    #endif
    #ifndef HW_INPUT_18_ONLEVEL
        #define HW_INPUT_18_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_18_MODE >= 0 && HW_INPUT_18_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_18_ONLEVEL == 0 || HW_INPUT_18_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 19
    #ifndef HW_INPUT_19_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_19_GPIO >= 0 && HW_INPUT_19_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_19_MODE
        #define HW_INPUT_19_MODE 1
    #endif
    #ifndef HW_INPUT_19_ONLEVEL
        #define HW_INPUT_19_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_19_MODE >= 0 && HW_INPUT_19_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_19_ONLEVEL == 0 || HW_INPUT_19_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 20
    #ifndef HW_INPUT_20_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_20_GPIO >= 0 && HW_INPUT_20_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_20_MODE
        #define HW_INPUT_20_MODE 1
    #endif
    #ifndef HW_INPUT_20_ONLEVEL
        #define HW_INPUT_20_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_20_MODE >= 0 && HW_INPUT_20_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_20_ONLEVEL == 0 || HW_INPUT_20_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 21
    #ifndef HW_INPUT_21_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_21_GPIO >= 0 && HW_INPUT_21_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_21_MODE
        #define HW_INPUT_21_MODE 1
    #endif
    #ifndef HW_INPUT_21_ONLEVEL
        #define HW_INPUT_21_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_21_MODE >= 0 && HW_INPUT_21_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_21_ONLEVEL == 0 || HW_INPUT_21_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 22
    #ifndef HW_INPUT_22_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_22_GPIO >= 0 && HW_INPUT_22_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_22_MODE
        #define HW_INPUT_22_MODE 1
    #endif
    #ifndef HW_INPUT_22_ONLEVEL
        #define HW_INPUT_22_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_22_MODE >= 0 && HW_INPUT_22_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_22_ONLEVEL == 0 || HW_INPUT_22_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 23
    #ifndef HW_INPUT_23_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_23_GPIO >= 0 && HW_INPUT_23_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_23_MODE
        #define HW_INPUT_23_MODE 1
    #endif
    #ifndef HW_INPUT_23_ONLEVEL
        #define HW_INPUT_23_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_23_MODE >= 0 && HW_INPUT_23_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_23_ONLEVEL == 0 || HW_INPUT_23_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 24
    #ifndef HW_INPUT_24_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_24_GPIO >= 0 && HW_INPUT_24_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_24_MODE
        #define HW_INPUT_24_MODE 1
    #endif
    #ifndef HW_INPUT_24_ONLEVEL
        #define HW_INPUT_24_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_24_MODE >= 0 && HW_INPUT_24_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_24_ONLEVEL == 0 || HW_INPUT_24_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 25
    #ifndef HW_INPUT_25_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_25_GPIO >= 0 && HW_INPUT_25_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_25_MODE
        #define HW_INPUT_25_MODE 1
    #endif
    #ifndef HW_INPUT_25_ONLEVEL
        #define HW_INPUT_25_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_25_MODE >= 0 && HW_INPUT_25_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_25_ONLEVEL == 0 || HW_INPUT_25_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 26
    #ifndef HW_INPUT_26_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_26_GPIO >= 0 && HW_INPUT_26_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_26_MODE
        #define HW_INPUT_26_MODE 1
    #endif
    #ifndef HW_INPUT_26_ONLEVEL
        #define HW_INPUT_26_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_26_MODE >= 0 && HW_INPUT_26_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_26_ONLEVEL == 0 || HW_INPUT_26_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 27
    #ifndef HW_INPUT_27_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_27_GPIO >= 0 && HW_INPUT_27_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_27_MODE
        #define HW_INPUT_27_MODE 1
    #endif
    #ifndef HW_INPUT_27_ONLEVEL
        #define HW_INPUT_27_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_27_MODE >= 0 && HW_INPUT_27_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_27_ONLEVEL == 0 || HW_INPUT_27_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 28
    #ifndef HW_INPUT_28_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_28_GPIO >= 0 && HW_INPUT_28_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_28_MODE
        #define HW_INPUT_28_MODE 1
    #endif
    #ifndef HW_INPUT_28_ONLEVEL
        #define HW_INPUT_28_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_28_MODE >= 0 && HW_INPUT_28_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_28_ONLEVEL == 0 || HW_INPUT_28_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 29
    #ifndef HW_INPUT_29_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_29_GPIO >= 0 && HW_INPUT_29_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_29_MODE
        #define HW_INPUT_29_MODE 1
    #endif
    #ifndef HW_INPUT_29_ONLEVEL
        #define HW_INPUT_29_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_29_MODE >= 0 && HW_INPUT_29_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_29_ONLEVEL == 0 || HW_INPUT_29_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 30
    #ifndef HW_INPUT_30_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_30_GPIO >= 0 && HW_INPUT_30_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_30_MODE
        #define HW_INPUT_30_MODE 1
    #endif
    #ifndef HW_INPUT_30_ONLEVEL
        #define HW_INPUT_30_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_30_MODE >= 0 && HW_INPUT_30_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_30_ONLEVEL == 0 || HW_INPUT_30_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 31
    #ifndef HW_INPUT_31_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_31_GPIO >= 0 && HW_INPUT_31_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_31_MODE
        #define HW_INPUT_31_MODE 1
    #endif
    #ifndef HW_INPUT_31_ONLEVEL
        #define HW_INPUT_31_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_31_MODE >= 0 && HW_INPUT_31_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_31_ONLEVEL == 0 || HW_INPUT_31_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 32
    #ifndef HW_INPUT_32_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_32_GPIO >= 0 && HW_INPUT_32_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_32_MODE
        #define HW_INPUT_32_MODE 1
    #endif
    #ifndef HW_INPUT_32_ONLEVEL
        #define HW_INPUT_32_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_32_MODE >= 0 && HW_INPUT_32_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_32_ONLEVEL == 0 || HW_INPUT_32_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 33
    #ifndef HW_INPUT_33_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_33_GPIO >= 0 && HW_INPUT_33_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_33_MODE
        #define HW_INPUT_33_MODE 1
    #endif
    #ifndef HW_INPUT_33_ONLEVEL
        #define HW_INPUT_33_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_33_MODE >= 0 && HW_INPUT_33_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_33_ONLEVEL == 0 || HW_INPUT_33_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 34
    #ifndef HW_INPUT_34_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_34_GPIO >= 0 && HW_INPUT_34_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_34_MODE
        #define HW_INPUT_34_MODE 1
    #endif
    #ifndef HW_INPUT_34_ONLEVEL
        #define HW_INPUT_34_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_34_MODE >= 0 && HW_INPUT_34_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_34_ONLEVEL == 0 || HW_INPUT_34_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 35
    #ifndef HW_INPUT_35_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_35_GPIO >= 0 && HW_INPUT_35_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_35_MODE
        #define HW_INPUT_35_MODE 1
    #endif
    #ifndef HW_INPUT_35_ONLEVEL
        #define HW_INPUT_35_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_35_MODE >= 0 && HW_INPUT_35_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_35_ONLEVEL == 0 || HW_INPUT_35_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 36
    #ifndef HW_INPUT_36_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_36_GPIO >= 0 && HW_INPUT_36_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_36_MODE
        #define HW_INPUT_36_MODE 1
    #endif
    #ifndef HW_INPUT_36_ONLEVEL
        #define HW_INPUT_36_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_36_MODE >= 0 && HW_INPUT_36_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_36_ONLEVEL == 0 || HW_INPUT_36_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 37
    #ifndef HW_INPUT_37_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_37_GPIO >= 0 && HW_INPUT_37_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_37_MODE
        #define HW_INPUT_37_MODE 1
    #endif
    #ifndef HW_INPUT_37_ONLEVEL
        #define HW_INPUT_37_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_37_MODE >= 0 && HW_INPUT_37_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_37_ONLEVEL == 0 || HW_INPUT_37_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 38
    #ifndef HW_INPUT_38_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_38_GPIO >= 0 && HW_INPUT_38_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_38_MODE
        #define HW_INPUT_38_MODE 1
    #endif
    #ifndef HW_INPUT_38_ONLEVEL
        #define HW_INPUT_38_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_38_MODE >= 0 && HW_INPUT_38_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_38_ONLEVEL == 0 || HW_INPUT_38_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 39
    #ifndef HW_INPUT_39_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_39_GPIO >= 0 && HW_INPUT_39_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_39_MODE
        #define HW_INPUT_39_MODE 1
    #endif
    #ifndef HW_INPUT_39_ONLEVEL
        #define HW_INPUT_39_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_39_MODE >= 0 && HW_INPUT_39_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_39_ONLEVEL == 0 || HW_INPUT_39_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 40
    #ifndef HW_INPUT_40_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_40_GPIO >= 0 && HW_INPUT_40_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_40_MODE
        #define HW_INPUT_40_MODE 1
    #endif
    #ifndef HW_INPUT_40_ONLEVEL
        #define HW_INPUT_40_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_40_MODE >= 0 && HW_INPUT_40_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_40_ONLEVEL == 0 || HW_INPUT_40_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 41
    #ifndef HW_INPUT_41_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_41_GPIO >= 0 && HW_INPUT_41_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_41_MODE
        #define HW_INPUT_41_MODE 1
    #endif
    #ifndef HW_INPUT_41_ONLEVEL
        #define HW_INPUT_41_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_41_MODE >= 0 && HW_INPUT_41_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_41_ONLEVEL == 0 || HW_INPUT_41_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 42
    #ifndef HW_INPUT_42_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_42_GPIO >= 0 && HW_INPUT_42_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_42_MODE
        #define HW_INPUT_42_MODE 1
    #endif
    #ifndef HW_INPUT_42_ONLEVEL
        #define HW_INPUT_42_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_42_MODE >= 0 && HW_INPUT_42_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_42_ONLEVEL == 0 || HW_INPUT_42_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 43
    #ifndef HW_INPUT_43_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_43_GPIO >= 0 && HW_INPUT_43_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_43_MODE
        #define HW_INPUT_43_MODE 1
    #endif
    #ifndef HW_INPUT_43_ONLEVEL
        #define HW_INPUT_43_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_43_MODE >= 0 && HW_INPUT_43_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_43_ONLEVEL == 0 || HW_INPUT_43_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 44
    #ifndef HW_INPUT_44_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_44_GPIO >= 0 && HW_INPUT_44_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_44_MODE
        #define HW_INPUT_44_MODE 1
    #endif
    #ifndef HW_INPUT_44_ONLEVEL
        #define HW_INPUT_44_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_44_MODE >= 0 && HW_INPUT_44_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_44_ONLEVEL == 0 || HW_INPUT_44_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 45
    #ifndef HW_INPUT_45_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_45_GPIO >= 0 && HW_INPUT_45_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_45_MODE
        #define HW_INPUT_45_MODE 1
    #endif
    #ifndef HW_INPUT_45_ONLEVEL
        #define HW_INPUT_45_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_45_MODE >= 0 && HW_INPUT_45_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_45_ONLEVEL == 0 || HW_INPUT_45_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 46
    #ifndef HW_INPUT_46_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_46_GPIO >= 0 && HW_INPUT_46_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_46_MODE
        #define HW_INPUT_46_MODE 1
    #endif
    #ifndef HW_INPUT_46_ONLEVEL
        #define HW_INPUT_46_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_46_MODE >= 0 && HW_INPUT_46_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_46_ONLEVEL == 0 || HW_INPUT_46_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 47
    #ifndef HW_INPUT_47_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_47_GPIO >= 0 && HW_INPUT_47_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_47_MODE
        #define HW_INPUT_47_MODE 1
    #endif
    #ifndef HW_INPUT_47_ONLEVEL
        #define HW_INPUT_47_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_47_MODE >= 0 && HW_INPUT_47_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_47_ONLEVEL == 0 || HW_INPUT_47_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 48
    #ifndef HW_INPUT_48_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_48_GPIO >= 0 && HW_INPUT_48_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_48_MODE
        #define HW_INPUT_48_MODE 1
    #endif
    #ifndef HW_INPUT_48_ONLEVEL
        #define HW_INPUT_48_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_48_MODE >= 0 && HW_INPUT_48_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_48_ONLEVEL == 0 || HW_INPUT_48_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 49
    #ifndef HW_INPUT_49_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_49_GPIO >= 0 && HW_INPUT_49_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_49_MODE
        #define HW_INPUT_49_MODE 1
    #endif
    #ifndef HW_INPUT_49_ONLEVEL
        #define HW_INPUT_49_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_49_MODE >= 0 && HW_INPUT_49_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_49_ONLEVEL == 0 || HW_INPUT_49_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 50
    #ifndef HW_INPUT_50_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_50_GPIO >= 0 && HW_INPUT_50_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_50_MODE
        #define HW_INPUT_50_MODE 1
    #endif
    #ifndef HW_INPUT_50_ONLEVEL
        #define HW_INPUT_50_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_50_MODE >= 0 && HW_INPUT_50_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_50_ONLEVEL == 0 || HW_INPUT_50_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 51
    #ifndef HW_INPUT_51_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_51_GPIO >= 0 && HW_INPUT_51_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_51_MODE
        #define HW_INPUT_51_MODE 1
    #endif
    #ifndef HW_INPUT_51_ONLEVEL
        #define HW_INPUT_51_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_51_MODE >= 0 && HW_INPUT_51_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_51_ONLEVEL == 0 || HW_INPUT_51_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 52
    #ifndef HW_INPUT_52_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_52_GPIO >= 0 && HW_INPUT_52_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_52_MODE
        #define HW_INPUT_52_MODE 1
    #endif
    #ifndef HW_INPUT_52_ONLEVEL
        #define HW_INPUT_52_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_52_MODE >= 0 && HW_INPUT_52_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_52_ONLEVEL == 0 || HW_INPUT_52_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 53
    #ifndef HW_INPUT_53_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_53_GPIO >= 0 && HW_INPUT_53_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_53_MODE
        #define HW_INPUT_53_MODE 1
    #endif
    #ifndef HW_INPUT_53_ONLEVEL
        #define HW_INPUT_53_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_53_MODE >= 0 && HW_INPUT_53_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_53_ONLEVEL == 0 || HW_INPUT_53_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 54
    #ifndef HW_INPUT_54_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_54_GPIO >= 0 && HW_INPUT_54_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_54_MODE
        #define HW_INPUT_54_MODE 1
    #endif
    #ifndef HW_INPUT_54_ONLEVEL
        #define HW_INPUT_54_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_54_MODE >= 0 && HW_INPUT_54_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_54_ONLEVEL == 0 || HW_INPUT_54_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 55
    #ifndef HW_INPUT_55_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_55_GPIO >= 0 && HW_INPUT_55_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_55_MODE
        #define HW_INPUT_55_MODE 1
    #endif
    #ifndef HW_INPUT_55_ONLEVEL
        #define HW_INPUT_55_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_55_MODE >= 0 && HW_INPUT_55_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_55_ONLEVEL == 0 || HW_INPUT_55_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 56
    #ifndef HW_INPUT_56_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_56_GPIO >= 0 && HW_INPUT_56_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_56_MODE
        #define HW_INPUT_56_MODE 1
    #endif
    #ifndef HW_INPUT_56_ONLEVEL
        #define HW_INPUT_56_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_56_MODE >= 0 && HW_INPUT_56_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_56_ONLEVEL == 0 || HW_INPUT_56_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 57
    #ifndef HW_INPUT_57_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_57_GPIO >= 0 && HW_INPUT_57_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_57_MODE
        #define HW_INPUT_57_MODE 1
    #endif
    #ifndef HW_INPUT_57_ONLEVEL
        #define HW_INPUT_57_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_57_MODE >= 0 && HW_INPUT_57_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_57_ONLEVEL == 0 || HW_INPUT_57_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 58
    #ifndef HW_INPUT_58_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_58_GPIO >= 0 && HW_INPUT_58_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_58_MODE
        #define HW_INPUT_58_MODE 1
    #endif
    #ifndef HW_INPUT_58_ONLEVEL
        #define HW_INPUT_58_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_58_MODE >= 0 && HW_INPUT_58_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_58_ONLEVEL == 0 || HW_INPUT_58_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 59
    #ifndef HW_INPUT_59_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_59_GPIO >= 0 && HW_INPUT_59_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_59_MODE
        #define HW_INPUT_59_MODE 1
    #endif
    #ifndef HW_INPUT_59_ONLEVEL
        #define HW_INPUT_59_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_59_MODE >= 0 && HW_INPUT_59_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_59_ONLEVEL == 0 || HW_INPUT_59_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 60
    #ifndef HW_INPUT_60_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_60_GPIO >= 0 && HW_INPUT_60_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_60_MODE
        #define HW_INPUT_60_MODE 1
    #endif
    #ifndef HW_INPUT_60_ONLEVEL
        #define HW_INPUT_60_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_60_MODE >= 0 && HW_INPUT_60_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_60_ONLEVEL == 0 || HW_INPUT_60_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 61
    #ifndef HW_INPUT_61_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_61_GPIO >= 0 && HW_INPUT_61_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_61_MODE
        #define HW_INPUT_61_MODE 1
    #endif
    #ifndef HW_INPUT_61_ONLEVEL
        #define HW_INPUT_61_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_61_MODE >= 0 && HW_INPUT_61_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_61_ONLEVEL == 0 || HW_INPUT_61_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 62
    #ifndef HW_INPUT_62_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_62_GPIO >= 0 && HW_INPUT_62_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_62_MODE
        #define HW_INPUT_62_MODE 1
    #endif
    #ifndef HW_INPUT_62_ONLEVEL
        #define HW_INPUT_62_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_62_MODE >= 0 && HW_INPUT_62_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_62_ONLEVEL == 0 || HW_INPUT_62_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 63
    #ifndef HW_INPUT_63_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_63_GPIO >= 0 && HW_INPUT_63_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_63_MODE
        #define HW_INPUT_63_MODE 1
    #endif
    #ifndef HW_INPUT_63_ONLEVEL
        #define HW_INPUT_63_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_63_MODE >= 0 && HW_INPUT_63_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_63_ONLEVEL == 0 || HW_INPUT_63_ONLEVEL == 1, "Invalid input polarity");
#endif
#if HW_INPUT_COUNT >= 64
    #ifndef HW_INPUT_64_GPIO
        #error "HW_INPUT entries must be contiguous starting at 1"
    #endif
    static_assert(HW_INPUT_64_GPIO >= 0 && HW_INPUT_64_GPIO <= 254, "Invalid input GPIO");
    #ifndef HW_INPUT_64_MODE
        #define HW_INPUT_64_MODE 1
    #endif
    #ifndef HW_INPUT_64_ONLEVEL
        #define HW_INPUT_64_ONLEVEL 0
    #endif
    static_assert(HW_INPUT_64_MODE >= 0 && HW_INPUT_64_MODE <= 2, "Invalid input bias");
    static_assert(HW_INPUT_64_ONLEVEL == 0 || HW_INPUT_64_ONLEVEL == 1, "Invalid input polarity");
#endif
constexpr uint8_t hwInputGpio(uint8_t value)
{
    return
#if HW_INPUT_COUNT >= 1
        value == 0 ? HW_INPUT_1_GPIO :
#endif
#if HW_INPUT_COUNT >= 2
        value == 1 ? HW_INPUT_2_GPIO :
#endif
#if HW_INPUT_COUNT >= 3
        value == 2 ? HW_INPUT_3_GPIO :
#endif
#if HW_INPUT_COUNT >= 4
        value == 3 ? HW_INPUT_4_GPIO :
#endif
#if HW_INPUT_COUNT >= 5
        value == 4 ? HW_INPUT_5_GPIO :
#endif
#if HW_INPUT_COUNT >= 6
        value == 5 ? HW_INPUT_6_GPIO :
#endif
#if HW_INPUT_COUNT >= 7
        value == 6 ? HW_INPUT_7_GPIO :
#endif
#if HW_INPUT_COUNT >= 8
        value == 7 ? HW_INPUT_8_GPIO :
#endif
#if HW_INPUT_COUNT >= 9
        value == 8 ? HW_INPUT_9_GPIO :
#endif
#if HW_INPUT_COUNT >= 10
        value == 9 ? HW_INPUT_10_GPIO :
#endif
#if HW_INPUT_COUNT >= 11
        value == 10 ? HW_INPUT_11_GPIO :
#endif
#if HW_INPUT_COUNT >= 12
        value == 11 ? HW_INPUT_12_GPIO :
#endif
#if HW_INPUT_COUNT >= 13
        value == 12 ? HW_INPUT_13_GPIO :
#endif
#if HW_INPUT_COUNT >= 14
        value == 13 ? HW_INPUT_14_GPIO :
#endif
#if HW_INPUT_COUNT >= 15
        value == 14 ? HW_INPUT_15_GPIO :
#endif
#if HW_INPUT_COUNT >= 16
        value == 15 ? HW_INPUT_16_GPIO :
#endif
#if HW_INPUT_COUNT >= 17
        value == 16 ? HW_INPUT_17_GPIO :
#endif
#if HW_INPUT_COUNT >= 18
        value == 17 ? HW_INPUT_18_GPIO :
#endif
#if HW_INPUT_COUNT >= 19
        value == 18 ? HW_INPUT_19_GPIO :
#endif
#if HW_INPUT_COUNT >= 20
        value == 19 ? HW_INPUT_20_GPIO :
#endif
#if HW_INPUT_COUNT >= 21
        value == 20 ? HW_INPUT_21_GPIO :
#endif
#if HW_INPUT_COUNT >= 22
        value == 21 ? HW_INPUT_22_GPIO :
#endif
#if HW_INPUT_COUNT >= 23
        value == 22 ? HW_INPUT_23_GPIO :
#endif
#if HW_INPUT_COUNT >= 24
        value == 23 ? HW_INPUT_24_GPIO :
#endif
#if HW_INPUT_COUNT >= 25
        value == 24 ? HW_INPUT_25_GPIO :
#endif
#if HW_INPUT_COUNT >= 26
        value == 25 ? HW_INPUT_26_GPIO :
#endif
#if HW_INPUT_COUNT >= 27
        value == 26 ? HW_INPUT_27_GPIO :
#endif
#if HW_INPUT_COUNT >= 28
        value == 27 ? HW_INPUT_28_GPIO :
#endif
#if HW_INPUT_COUNT >= 29
        value == 28 ? HW_INPUT_29_GPIO :
#endif
#if HW_INPUT_COUNT >= 30
        value == 29 ? HW_INPUT_30_GPIO :
#endif
#if HW_INPUT_COUNT >= 31
        value == 30 ? HW_INPUT_31_GPIO :
#endif
#if HW_INPUT_COUNT >= 32
        value == 31 ? HW_INPUT_32_GPIO :
#endif
#if HW_INPUT_COUNT >= 33
        value == 32 ? HW_INPUT_33_GPIO :
#endif
#if HW_INPUT_COUNT >= 34
        value == 33 ? HW_INPUT_34_GPIO :
#endif
#if HW_INPUT_COUNT >= 35
        value == 34 ? HW_INPUT_35_GPIO :
#endif
#if HW_INPUT_COUNT >= 36
        value == 35 ? HW_INPUT_36_GPIO :
#endif
#if HW_INPUT_COUNT >= 37
        value == 36 ? HW_INPUT_37_GPIO :
#endif
#if HW_INPUT_COUNT >= 38
        value == 37 ? HW_INPUT_38_GPIO :
#endif
#if HW_INPUT_COUNT >= 39
        value == 38 ? HW_INPUT_39_GPIO :
#endif
#if HW_INPUT_COUNT >= 40
        value == 39 ? HW_INPUT_40_GPIO :
#endif
#if HW_INPUT_COUNT >= 41
        value == 40 ? HW_INPUT_41_GPIO :
#endif
#if HW_INPUT_COUNT >= 42
        value == 41 ? HW_INPUT_42_GPIO :
#endif
#if HW_INPUT_COUNT >= 43
        value == 42 ? HW_INPUT_43_GPIO :
#endif
#if HW_INPUT_COUNT >= 44
        value == 43 ? HW_INPUT_44_GPIO :
#endif
#if HW_INPUT_COUNT >= 45
        value == 44 ? HW_INPUT_45_GPIO :
#endif
#if HW_INPUT_COUNT >= 46
        value == 45 ? HW_INPUT_46_GPIO :
#endif
#if HW_INPUT_COUNT >= 47
        value == 46 ? HW_INPUT_47_GPIO :
#endif
#if HW_INPUT_COUNT >= 48
        value == 47 ? HW_INPUT_48_GPIO :
#endif
#if HW_INPUT_COUNT >= 49
        value == 48 ? HW_INPUT_49_GPIO :
#endif
#if HW_INPUT_COUNT >= 50
        value == 49 ? HW_INPUT_50_GPIO :
#endif
#if HW_INPUT_COUNT >= 51
        value == 50 ? HW_INPUT_51_GPIO :
#endif
#if HW_INPUT_COUNT >= 52
        value == 51 ? HW_INPUT_52_GPIO :
#endif
#if HW_INPUT_COUNT >= 53
        value == 52 ? HW_INPUT_53_GPIO :
#endif
#if HW_INPUT_COUNT >= 54
        value == 53 ? HW_INPUT_54_GPIO :
#endif
#if HW_INPUT_COUNT >= 55
        value == 54 ? HW_INPUT_55_GPIO :
#endif
#if HW_INPUT_COUNT >= 56
        value == 55 ? HW_INPUT_56_GPIO :
#endif
#if HW_INPUT_COUNT >= 57
        value == 56 ? HW_INPUT_57_GPIO :
#endif
#if HW_INPUT_COUNT >= 58
        value == 57 ? HW_INPUT_58_GPIO :
#endif
#if HW_INPUT_COUNT >= 59
        value == 58 ? HW_INPUT_59_GPIO :
#endif
#if HW_INPUT_COUNT >= 60
        value == 59 ? HW_INPUT_60_GPIO :
#endif
#if HW_INPUT_COUNT >= 61
        value == 60 ? HW_INPUT_61_GPIO :
#endif
#if HW_INPUT_COUNT >= 62
        value == 61 ? HW_INPUT_62_GPIO :
#endif
#if HW_INPUT_COUNT >= 63
        value == 62 ? HW_INPUT_63_GPIO :
#endif
#if HW_INPUT_COUNT >= 64
        value == 63 ? HW_INPUT_64_GPIO :
#endif
        255;
}
constexpr uint8_t hwInputMode(uint8_t value)
{
    return
#if HW_INPUT_COUNT >= 1
        value == 0 ? HW_INPUT_1_MODE :
#endif
#if HW_INPUT_COUNT >= 2
        value == 1 ? HW_INPUT_2_MODE :
#endif
#if HW_INPUT_COUNT >= 3
        value == 2 ? HW_INPUT_3_MODE :
#endif
#if HW_INPUT_COUNT >= 4
        value == 3 ? HW_INPUT_4_MODE :
#endif
#if HW_INPUT_COUNT >= 5
        value == 4 ? HW_INPUT_5_MODE :
#endif
#if HW_INPUT_COUNT >= 6
        value == 5 ? HW_INPUT_6_MODE :
#endif
#if HW_INPUT_COUNT >= 7
        value == 6 ? HW_INPUT_7_MODE :
#endif
#if HW_INPUT_COUNT >= 8
        value == 7 ? HW_INPUT_8_MODE :
#endif
#if HW_INPUT_COUNT >= 9
        value == 8 ? HW_INPUT_9_MODE :
#endif
#if HW_INPUT_COUNT >= 10
        value == 9 ? HW_INPUT_10_MODE :
#endif
#if HW_INPUT_COUNT >= 11
        value == 10 ? HW_INPUT_11_MODE :
#endif
#if HW_INPUT_COUNT >= 12
        value == 11 ? HW_INPUT_12_MODE :
#endif
#if HW_INPUT_COUNT >= 13
        value == 12 ? HW_INPUT_13_MODE :
#endif
#if HW_INPUT_COUNT >= 14
        value == 13 ? HW_INPUT_14_MODE :
#endif
#if HW_INPUT_COUNT >= 15
        value == 14 ? HW_INPUT_15_MODE :
#endif
#if HW_INPUT_COUNT >= 16
        value == 15 ? HW_INPUT_16_MODE :
#endif
#if HW_INPUT_COUNT >= 17
        value == 16 ? HW_INPUT_17_MODE :
#endif
#if HW_INPUT_COUNT >= 18
        value == 17 ? HW_INPUT_18_MODE :
#endif
#if HW_INPUT_COUNT >= 19
        value == 18 ? HW_INPUT_19_MODE :
#endif
#if HW_INPUT_COUNT >= 20
        value == 19 ? HW_INPUT_20_MODE :
#endif
#if HW_INPUT_COUNT >= 21
        value == 20 ? HW_INPUT_21_MODE :
#endif
#if HW_INPUT_COUNT >= 22
        value == 21 ? HW_INPUT_22_MODE :
#endif
#if HW_INPUT_COUNT >= 23
        value == 22 ? HW_INPUT_23_MODE :
#endif
#if HW_INPUT_COUNT >= 24
        value == 23 ? HW_INPUT_24_MODE :
#endif
#if HW_INPUT_COUNT >= 25
        value == 24 ? HW_INPUT_25_MODE :
#endif
#if HW_INPUT_COUNT >= 26
        value == 25 ? HW_INPUT_26_MODE :
#endif
#if HW_INPUT_COUNT >= 27
        value == 26 ? HW_INPUT_27_MODE :
#endif
#if HW_INPUT_COUNT >= 28
        value == 27 ? HW_INPUT_28_MODE :
#endif
#if HW_INPUT_COUNT >= 29
        value == 28 ? HW_INPUT_29_MODE :
#endif
#if HW_INPUT_COUNT >= 30
        value == 29 ? HW_INPUT_30_MODE :
#endif
#if HW_INPUT_COUNT >= 31
        value == 30 ? HW_INPUT_31_MODE :
#endif
#if HW_INPUT_COUNT >= 32
        value == 31 ? HW_INPUT_32_MODE :
#endif
#if HW_INPUT_COUNT >= 33
        value == 32 ? HW_INPUT_33_MODE :
#endif
#if HW_INPUT_COUNT >= 34
        value == 33 ? HW_INPUT_34_MODE :
#endif
#if HW_INPUT_COUNT >= 35
        value == 34 ? HW_INPUT_35_MODE :
#endif
#if HW_INPUT_COUNT >= 36
        value == 35 ? HW_INPUT_36_MODE :
#endif
#if HW_INPUT_COUNT >= 37
        value == 36 ? HW_INPUT_37_MODE :
#endif
#if HW_INPUT_COUNT >= 38
        value == 37 ? HW_INPUT_38_MODE :
#endif
#if HW_INPUT_COUNT >= 39
        value == 38 ? HW_INPUT_39_MODE :
#endif
#if HW_INPUT_COUNT >= 40
        value == 39 ? HW_INPUT_40_MODE :
#endif
#if HW_INPUT_COUNT >= 41
        value == 40 ? HW_INPUT_41_MODE :
#endif
#if HW_INPUT_COUNT >= 42
        value == 41 ? HW_INPUT_42_MODE :
#endif
#if HW_INPUT_COUNT >= 43
        value == 42 ? HW_INPUT_43_MODE :
#endif
#if HW_INPUT_COUNT >= 44
        value == 43 ? HW_INPUT_44_MODE :
#endif
#if HW_INPUT_COUNT >= 45
        value == 44 ? HW_INPUT_45_MODE :
#endif
#if HW_INPUT_COUNT >= 46
        value == 45 ? HW_INPUT_46_MODE :
#endif
#if HW_INPUT_COUNT >= 47
        value == 46 ? HW_INPUT_47_MODE :
#endif
#if HW_INPUT_COUNT >= 48
        value == 47 ? HW_INPUT_48_MODE :
#endif
#if HW_INPUT_COUNT >= 49
        value == 48 ? HW_INPUT_49_MODE :
#endif
#if HW_INPUT_COUNT >= 50
        value == 49 ? HW_INPUT_50_MODE :
#endif
#if HW_INPUT_COUNT >= 51
        value == 50 ? HW_INPUT_51_MODE :
#endif
#if HW_INPUT_COUNT >= 52
        value == 51 ? HW_INPUT_52_MODE :
#endif
#if HW_INPUT_COUNT >= 53
        value == 52 ? HW_INPUT_53_MODE :
#endif
#if HW_INPUT_COUNT >= 54
        value == 53 ? HW_INPUT_54_MODE :
#endif
#if HW_INPUT_COUNT >= 55
        value == 54 ? HW_INPUT_55_MODE :
#endif
#if HW_INPUT_COUNT >= 56
        value == 55 ? HW_INPUT_56_MODE :
#endif
#if HW_INPUT_COUNT >= 57
        value == 56 ? HW_INPUT_57_MODE :
#endif
#if HW_INPUT_COUNT >= 58
        value == 57 ? HW_INPUT_58_MODE :
#endif
#if HW_INPUT_COUNT >= 59
        value == 58 ? HW_INPUT_59_MODE :
#endif
#if HW_INPUT_COUNT >= 60
        value == 59 ? HW_INPUT_60_MODE :
#endif
#if HW_INPUT_COUNT >= 61
        value == 60 ? HW_INPUT_61_MODE :
#endif
#if HW_INPUT_COUNT >= 62
        value == 61 ? HW_INPUT_62_MODE :
#endif
#if HW_INPUT_COUNT >= 63
        value == 62 ? HW_INPUT_63_MODE :
#endif
#if HW_INPUT_COUNT >= 64
        value == 63 ? HW_INPUT_64_MODE :
#endif
        0;
}
constexpr uint8_t hwInputOnLevel(uint8_t value)
{
    return
#if HW_INPUT_COUNT >= 1
        value == 0 ? HW_INPUT_1_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 2
        value == 1 ? HW_INPUT_2_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 3
        value == 2 ? HW_INPUT_3_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 4
        value == 3 ? HW_INPUT_4_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 5
        value == 4 ? HW_INPUT_5_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 6
        value == 5 ? HW_INPUT_6_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 7
        value == 6 ? HW_INPUT_7_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 8
        value == 7 ? HW_INPUT_8_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 9
        value == 8 ? HW_INPUT_9_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 10
        value == 9 ? HW_INPUT_10_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 11
        value == 10 ? HW_INPUT_11_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 12
        value == 11 ? HW_INPUT_12_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 13
        value == 12 ? HW_INPUT_13_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 14
        value == 13 ? HW_INPUT_14_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 15
        value == 14 ? HW_INPUT_15_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 16
        value == 15 ? HW_INPUT_16_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 17
        value == 16 ? HW_INPUT_17_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 18
        value == 17 ? HW_INPUT_18_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 19
        value == 18 ? HW_INPUT_19_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 20
        value == 19 ? HW_INPUT_20_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 21
        value == 20 ? HW_INPUT_21_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 22
        value == 21 ? HW_INPUT_22_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 23
        value == 22 ? HW_INPUT_23_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 24
        value == 23 ? HW_INPUT_24_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 25
        value == 24 ? HW_INPUT_25_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 26
        value == 25 ? HW_INPUT_26_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 27
        value == 26 ? HW_INPUT_27_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 28
        value == 27 ? HW_INPUT_28_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 29
        value == 28 ? HW_INPUT_29_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 30
        value == 29 ? HW_INPUT_30_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 31
        value == 30 ? HW_INPUT_31_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 32
        value == 31 ? HW_INPUT_32_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 33
        value == 32 ? HW_INPUT_33_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 34
        value == 33 ? HW_INPUT_34_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 35
        value == 34 ? HW_INPUT_35_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 36
        value == 35 ? HW_INPUT_36_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 37
        value == 36 ? HW_INPUT_37_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 38
        value == 37 ? HW_INPUT_38_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 39
        value == 38 ? HW_INPUT_39_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 40
        value == 39 ? HW_INPUT_40_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 41
        value == 40 ? HW_INPUT_41_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 42
        value == 41 ? HW_INPUT_42_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 43
        value == 42 ? HW_INPUT_43_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 44
        value == 43 ? HW_INPUT_44_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 45
        value == 44 ? HW_INPUT_45_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 46
        value == 45 ? HW_INPUT_46_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 47
        value == 46 ? HW_INPUT_47_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 48
        value == 47 ? HW_INPUT_48_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 49
        value == 48 ? HW_INPUT_49_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 50
        value == 49 ? HW_INPUT_50_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 51
        value == 50 ? HW_INPUT_51_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 52
        value == 51 ? HW_INPUT_52_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 53
        value == 52 ? HW_INPUT_53_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 54
        value == 53 ? HW_INPUT_54_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 55
        value == 54 ? HW_INPUT_55_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 56
        value == 55 ? HW_INPUT_56_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 57
        value == 56 ? HW_INPUT_57_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 58
        value == 57 ? HW_INPUT_58_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 59
        value == 58 ? HW_INPUT_59_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 60
        value == 59 ? HW_INPUT_60_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 61
        value == 60 ? HW_INPUT_61_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 62
        value == 61 ? HW_INPUT_62_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 63
        value == 62 ? HW_INPUT_63_ONLEVEL :
#endif
#if HW_INPUT_COUNT >= 64
        value == 63 ? HW_INPUT_64_ONLEVEL :
#endif
        0;
}
