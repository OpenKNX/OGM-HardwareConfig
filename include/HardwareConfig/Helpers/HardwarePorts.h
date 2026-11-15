#pragma once
/**
 * @file HardwareConfig/Helpers/HardwarePorts.h
 * @brief GPIO of a hardware port value (value = port number - 1) from HW_PORT_<n>_GPIO of the board header.
 * @note ETS stores port n as n - 1 (generator README "Ports"); 255 = the board does not describe that port.
 * Ports 1..HW_PORTS_MAX, GPIO 0..254. Also the hard-wired relays (HW_RELAY_COUNT, HW_RELAY_<n>_GPIO).
 * Firmware helper (not a board definition): #include "HardwareConfig/Helpers/HardwarePorts.h".
 */
#include <stdint.h>
#include "HardwareConfig.h"

// highest port number read here and by OGM-HardwareConfig/generator; raising it needs the list below extended
#define HW_PORTS_MAX 64

#if defined(HW_PORT_COUNT) && (HW_PORT_COUNT) > HW_PORTS_MAX
    #error "HW_PORT_COUNT of the board header is above HW_PORTS_MAX (HardwarePorts.h)"
#endif

#ifdef HW_PORT_1_GPIO
    static_assert((HW_PORT_1_GPIO) >= 0 && (HW_PORT_1_GPIO) <= 254, "HW_PORT_1_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_1 ((uint8_t)(HW_PORT_1_GPIO))
#else
    #define HWPORTS_GPIO_1 ((uint8_t)255)
#endif
#ifdef HW_PORT_2_GPIO
    static_assert((HW_PORT_2_GPIO) >= 0 && (HW_PORT_2_GPIO) <= 254, "HW_PORT_2_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_2 ((uint8_t)(HW_PORT_2_GPIO))
#else
    #define HWPORTS_GPIO_2 ((uint8_t)255)
#endif
#ifdef HW_PORT_3_GPIO
    static_assert((HW_PORT_3_GPIO) >= 0 && (HW_PORT_3_GPIO) <= 254, "HW_PORT_3_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_3 ((uint8_t)(HW_PORT_3_GPIO))
#else
    #define HWPORTS_GPIO_3 ((uint8_t)255)
#endif
#ifdef HW_PORT_4_GPIO
    static_assert((HW_PORT_4_GPIO) >= 0 && (HW_PORT_4_GPIO) <= 254, "HW_PORT_4_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_4 ((uint8_t)(HW_PORT_4_GPIO))
#else
    #define HWPORTS_GPIO_4 ((uint8_t)255)
#endif
#ifdef HW_PORT_5_GPIO
    static_assert((HW_PORT_5_GPIO) >= 0 && (HW_PORT_5_GPIO) <= 254, "HW_PORT_5_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_5 ((uint8_t)(HW_PORT_5_GPIO))
#else
    #define HWPORTS_GPIO_5 ((uint8_t)255)
#endif
#ifdef HW_PORT_6_GPIO
    static_assert((HW_PORT_6_GPIO) >= 0 && (HW_PORT_6_GPIO) <= 254, "HW_PORT_6_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_6 ((uint8_t)(HW_PORT_6_GPIO))
#else
    #define HWPORTS_GPIO_6 ((uint8_t)255)
#endif
#ifdef HW_PORT_7_GPIO
    static_assert((HW_PORT_7_GPIO) >= 0 && (HW_PORT_7_GPIO) <= 254, "HW_PORT_7_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_7 ((uint8_t)(HW_PORT_7_GPIO))
#else
    #define HWPORTS_GPIO_7 ((uint8_t)255)
#endif
#ifdef HW_PORT_8_GPIO
    static_assert((HW_PORT_8_GPIO) >= 0 && (HW_PORT_8_GPIO) <= 254, "HW_PORT_8_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_8 ((uint8_t)(HW_PORT_8_GPIO))
#else
    #define HWPORTS_GPIO_8 ((uint8_t)255)
#endif
#ifdef HW_PORT_9_GPIO
    static_assert((HW_PORT_9_GPIO) >= 0 && (HW_PORT_9_GPIO) <= 254, "HW_PORT_9_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_9 ((uint8_t)(HW_PORT_9_GPIO))
#else
    #define HWPORTS_GPIO_9 ((uint8_t)255)
#endif
#ifdef HW_PORT_10_GPIO
    static_assert((HW_PORT_10_GPIO) >= 0 && (HW_PORT_10_GPIO) <= 254, "HW_PORT_10_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_10 ((uint8_t)(HW_PORT_10_GPIO))
#else
    #define HWPORTS_GPIO_10 ((uint8_t)255)
#endif
#ifdef HW_PORT_11_GPIO
    static_assert((HW_PORT_11_GPIO) >= 0 && (HW_PORT_11_GPIO) <= 254, "HW_PORT_11_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_11 ((uint8_t)(HW_PORT_11_GPIO))
#else
    #define HWPORTS_GPIO_11 ((uint8_t)255)
#endif
#ifdef HW_PORT_12_GPIO
    static_assert((HW_PORT_12_GPIO) >= 0 && (HW_PORT_12_GPIO) <= 254, "HW_PORT_12_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_12 ((uint8_t)(HW_PORT_12_GPIO))
#else
    #define HWPORTS_GPIO_12 ((uint8_t)255)
#endif
#ifdef HW_PORT_13_GPIO
    static_assert((HW_PORT_13_GPIO) >= 0 && (HW_PORT_13_GPIO) <= 254, "HW_PORT_13_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_13 ((uint8_t)(HW_PORT_13_GPIO))
#else
    #define HWPORTS_GPIO_13 ((uint8_t)255)
#endif
#ifdef HW_PORT_14_GPIO
    static_assert((HW_PORT_14_GPIO) >= 0 && (HW_PORT_14_GPIO) <= 254, "HW_PORT_14_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_14 ((uint8_t)(HW_PORT_14_GPIO))
#else
    #define HWPORTS_GPIO_14 ((uint8_t)255)
#endif
#ifdef HW_PORT_15_GPIO
    static_assert((HW_PORT_15_GPIO) >= 0 && (HW_PORT_15_GPIO) <= 254, "HW_PORT_15_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_15 ((uint8_t)(HW_PORT_15_GPIO))
#else
    #define HWPORTS_GPIO_15 ((uint8_t)255)
#endif
#ifdef HW_PORT_16_GPIO
    static_assert((HW_PORT_16_GPIO) >= 0 && (HW_PORT_16_GPIO) <= 254, "HW_PORT_16_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_16 ((uint8_t)(HW_PORT_16_GPIO))
#else
    #define HWPORTS_GPIO_16 ((uint8_t)255)
#endif
#ifdef HW_PORT_17_GPIO
    static_assert((HW_PORT_17_GPIO) >= 0 && (HW_PORT_17_GPIO) <= 254, "HW_PORT_17_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_17 ((uint8_t)(HW_PORT_17_GPIO))
#else
    #define HWPORTS_GPIO_17 ((uint8_t)255)
#endif
#ifdef HW_PORT_18_GPIO
    static_assert((HW_PORT_18_GPIO) >= 0 && (HW_PORT_18_GPIO) <= 254, "HW_PORT_18_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_18 ((uint8_t)(HW_PORT_18_GPIO))
#else
    #define HWPORTS_GPIO_18 ((uint8_t)255)
#endif
#ifdef HW_PORT_19_GPIO
    static_assert((HW_PORT_19_GPIO) >= 0 && (HW_PORT_19_GPIO) <= 254, "HW_PORT_19_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_19 ((uint8_t)(HW_PORT_19_GPIO))
#else
    #define HWPORTS_GPIO_19 ((uint8_t)255)
#endif
#ifdef HW_PORT_20_GPIO
    static_assert((HW_PORT_20_GPIO) >= 0 && (HW_PORT_20_GPIO) <= 254, "HW_PORT_20_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_20 ((uint8_t)(HW_PORT_20_GPIO))
#else
    #define HWPORTS_GPIO_20 ((uint8_t)255)
#endif
#ifdef HW_PORT_21_GPIO
    static_assert((HW_PORT_21_GPIO) >= 0 && (HW_PORT_21_GPIO) <= 254, "HW_PORT_21_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_21 ((uint8_t)(HW_PORT_21_GPIO))
#else
    #define HWPORTS_GPIO_21 ((uint8_t)255)
#endif
#ifdef HW_PORT_22_GPIO
    static_assert((HW_PORT_22_GPIO) >= 0 && (HW_PORT_22_GPIO) <= 254, "HW_PORT_22_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_22 ((uint8_t)(HW_PORT_22_GPIO))
#else
    #define HWPORTS_GPIO_22 ((uint8_t)255)
#endif
#ifdef HW_PORT_23_GPIO
    static_assert((HW_PORT_23_GPIO) >= 0 && (HW_PORT_23_GPIO) <= 254, "HW_PORT_23_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_23 ((uint8_t)(HW_PORT_23_GPIO))
#else
    #define HWPORTS_GPIO_23 ((uint8_t)255)
#endif
#ifdef HW_PORT_24_GPIO
    static_assert((HW_PORT_24_GPIO) >= 0 && (HW_PORT_24_GPIO) <= 254, "HW_PORT_24_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_24 ((uint8_t)(HW_PORT_24_GPIO))
#else
    #define HWPORTS_GPIO_24 ((uint8_t)255)
#endif
#ifdef HW_PORT_25_GPIO
    static_assert((HW_PORT_25_GPIO) >= 0 && (HW_PORT_25_GPIO) <= 254, "HW_PORT_25_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_25 ((uint8_t)(HW_PORT_25_GPIO))
#else
    #define HWPORTS_GPIO_25 ((uint8_t)255)
#endif
#ifdef HW_PORT_26_GPIO
    static_assert((HW_PORT_26_GPIO) >= 0 && (HW_PORT_26_GPIO) <= 254, "HW_PORT_26_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_26 ((uint8_t)(HW_PORT_26_GPIO))
#else
    #define HWPORTS_GPIO_26 ((uint8_t)255)
#endif
#ifdef HW_PORT_27_GPIO
    static_assert((HW_PORT_27_GPIO) >= 0 && (HW_PORT_27_GPIO) <= 254, "HW_PORT_27_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_27 ((uint8_t)(HW_PORT_27_GPIO))
#else
    #define HWPORTS_GPIO_27 ((uint8_t)255)
#endif
#ifdef HW_PORT_28_GPIO
    static_assert((HW_PORT_28_GPIO) >= 0 && (HW_PORT_28_GPIO) <= 254, "HW_PORT_28_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_28 ((uint8_t)(HW_PORT_28_GPIO))
#else
    #define HWPORTS_GPIO_28 ((uint8_t)255)
#endif
#ifdef HW_PORT_29_GPIO
    static_assert((HW_PORT_29_GPIO) >= 0 && (HW_PORT_29_GPIO) <= 254, "HW_PORT_29_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_29 ((uint8_t)(HW_PORT_29_GPIO))
#else
    #define HWPORTS_GPIO_29 ((uint8_t)255)
#endif
#ifdef HW_PORT_30_GPIO
    static_assert((HW_PORT_30_GPIO) >= 0 && (HW_PORT_30_GPIO) <= 254, "HW_PORT_30_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_30 ((uint8_t)(HW_PORT_30_GPIO))
#else
    #define HWPORTS_GPIO_30 ((uint8_t)255)
#endif
#ifdef HW_PORT_31_GPIO
    static_assert((HW_PORT_31_GPIO) >= 0 && (HW_PORT_31_GPIO) <= 254, "HW_PORT_31_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_31 ((uint8_t)(HW_PORT_31_GPIO))
#else
    #define HWPORTS_GPIO_31 ((uint8_t)255)
#endif
#ifdef HW_PORT_32_GPIO
    static_assert((HW_PORT_32_GPIO) >= 0 && (HW_PORT_32_GPIO) <= 254, "HW_PORT_32_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_32 ((uint8_t)(HW_PORT_32_GPIO))
#else
    #define HWPORTS_GPIO_32 ((uint8_t)255)
#endif
#ifdef HW_PORT_33_GPIO
    static_assert((HW_PORT_33_GPIO) >= 0 && (HW_PORT_33_GPIO) <= 254, "HW_PORT_33_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_33 ((uint8_t)(HW_PORT_33_GPIO))
#else
    #define HWPORTS_GPIO_33 ((uint8_t)255)
#endif
#ifdef HW_PORT_34_GPIO
    static_assert((HW_PORT_34_GPIO) >= 0 && (HW_PORT_34_GPIO) <= 254, "HW_PORT_34_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_34 ((uint8_t)(HW_PORT_34_GPIO))
#else
    #define HWPORTS_GPIO_34 ((uint8_t)255)
#endif
#ifdef HW_PORT_35_GPIO
    static_assert((HW_PORT_35_GPIO) >= 0 && (HW_PORT_35_GPIO) <= 254, "HW_PORT_35_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_35 ((uint8_t)(HW_PORT_35_GPIO))
#else
    #define HWPORTS_GPIO_35 ((uint8_t)255)
#endif
#ifdef HW_PORT_36_GPIO
    static_assert((HW_PORT_36_GPIO) >= 0 && (HW_PORT_36_GPIO) <= 254, "HW_PORT_36_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_36 ((uint8_t)(HW_PORT_36_GPIO))
#else
    #define HWPORTS_GPIO_36 ((uint8_t)255)
#endif
#ifdef HW_PORT_37_GPIO
    static_assert((HW_PORT_37_GPIO) >= 0 && (HW_PORT_37_GPIO) <= 254, "HW_PORT_37_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_37 ((uint8_t)(HW_PORT_37_GPIO))
#else
    #define HWPORTS_GPIO_37 ((uint8_t)255)
#endif
#ifdef HW_PORT_38_GPIO
    static_assert((HW_PORT_38_GPIO) >= 0 && (HW_PORT_38_GPIO) <= 254, "HW_PORT_38_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_38 ((uint8_t)(HW_PORT_38_GPIO))
#else
    #define HWPORTS_GPIO_38 ((uint8_t)255)
#endif
#ifdef HW_PORT_39_GPIO
    static_assert((HW_PORT_39_GPIO) >= 0 && (HW_PORT_39_GPIO) <= 254, "HW_PORT_39_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_39 ((uint8_t)(HW_PORT_39_GPIO))
#else
    #define HWPORTS_GPIO_39 ((uint8_t)255)
#endif
#ifdef HW_PORT_40_GPIO
    static_assert((HW_PORT_40_GPIO) >= 0 && (HW_PORT_40_GPIO) <= 254, "HW_PORT_40_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_40 ((uint8_t)(HW_PORT_40_GPIO))
#else
    #define HWPORTS_GPIO_40 ((uint8_t)255)
#endif
#ifdef HW_PORT_41_GPIO
    static_assert((HW_PORT_41_GPIO) >= 0 && (HW_PORT_41_GPIO) <= 254, "HW_PORT_41_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_41 ((uint8_t)(HW_PORT_41_GPIO))
#else
    #define HWPORTS_GPIO_41 ((uint8_t)255)
#endif
#ifdef HW_PORT_42_GPIO
    static_assert((HW_PORT_42_GPIO) >= 0 && (HW_PORT_42_GPIO) <= 254, "HW_PORT_42_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_42 ((uint8_t)(HW_PORT_42_GPIO))
#else
    #define HWPORTS_GPIO_42 ((uint8_t)255)
#endif
#ifdef HW_PORT_43_GPIO
    static_assert((HW_PORT_43_GPIO) >= 0 && (HW_PORT_43_GPIO) <= 254, "HW_PORT_43_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_43 ((uint8_t)(HW_PORT_43_GPIO))
#else
    #define HWPORTS_GPIO_43 ((uint8_t)255)
#endif
#ifdef HW_PORT_44_GPIO
    static_assert((HW_PORT_44_GPIO) >= 0 && (HW_PORT_44_GPIO) <= 254, "HW_PORT_44_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_44 ((uint8_t)(HW_PORT_44_GPIO))
#else
    #define HWPORTS_GPIO_44 ((uint8_t)255)
#endif
#ifdef HW_PORT_45_GPIO
    static_assert((HW_PORT_45_GPIO) >= 0 && (HW_PORT_45_GPIO) <= 254, "HW_PORT_45_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_45 ((uint8_t)(HW_PORT_45_GPIO))
#else
    #define HWPORTS_GPIO_45 ((uint8_t)255)
#endif
#ifdef HW_PORT_46_GPIO
    static_assert((HW_PORT_46_GPIO) >= 0 && (HW_PORT_46_GPIO) <= 254, "HW_PORT_46_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_46 ((uint8_t)(HW_PORT_46_GPIO))
#else
    #define HWPORTS_GPIO_46 ((uint8_t)255)
#endif
#ifdef HW_PORT_47_GPIO
    static_assert((HW_PORT_47_GPIO) >= 0 && (HW_PORT_47_GPIO) <= 254, "HW_PORT_47_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_47 ((uint8_t)(HW_PORT_47_GPIO))
#else
    #define HWPORTS_GPIO_47 ((uint8_t)255)
#endif
#ifdef HW_PORT_48_GPIO
    static_assert((HW_PORT_48_GPIO) >= 0 && (HW_PORT_48_GPIO) <= 254, "HW_PORT_48_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_48 ((uint8_t)(HW_PORT_48_GPIO))
#else
    #define HWPORTS_GPIO_48 ((uint8_t)255)
#endif
#ifdef HW_PORT_49_GPIO
    static_assert((HW_PORT_49_GPIO) >= 0 && (HW_PORT_49_GPIO) <= 254, "HW_PORT_49_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_49 ((uint8_t)(HW_PORT_49_GPIO))
#else
    #define HWPORTS_GPIO_49 ((uint8_t)255)
#endif
#ifdef HW_PORT_50_GPIO
    static_assert((HW_PORT_50_GPIO) >= 0 && (HW_PORT_50_GPIO) <= 254, "HW_PORT_50_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_50 ((uint8_t)(HW_PORT_50_GPIO))
#else
    #define HWPORTS_GPIO_50 ((uint8_t)255)
#endif
#ifdef HW_PORT_51_GPIO
    static_assert((HW_PORT_51_GPIO) >= 0 && (HW_PORT_51_GPIO) <= 254, "HW_PORT_51_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_51 ((uint8_t)(HW_PORT_51_GPIO))
#else
    #define HWPORTS_GPIO_51 ((uint8_t)255)
#endif
#ifdef HW_PORT_52_GPIO
    static_assert((HW_PORT_52_GPIO) >= 0 && (HW_PORT_52_GPIO) <= 254, "HW_PORT_52_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_52 ((uint8_t)(HW_PORT_52_GPIO))
#else
    #define HWPORTS_GPIO_52 ((uint8_t)255)
#endif
#ifdef HW_PORT_53_GPIO
    static_assert((HW_PORT_53_GPIO) >= 0 && (HW_PORT_53_GPIO) <= 254, "HW_PORT_53_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_53 ((uint8_t)(HW_PORT_53_GPIO))
#else
    #define HWPORTS_GPIO_53 ((uint8_t)255)
#endif
#ifdef HW_PORT_54_GPIO
    static_assert((HW_PORT_54_GPIO) >= 0 && (HW_PORT_54_GPIO) <= 254, "HW_PORT_54_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_54 ((uint8_t)(HW_PORT_54_GPIO))
#else
    #define HWPORTS_GPIO_54 ((uint8_t)255)
#endif
#ifdef HW_PORT_55_GPIO
    static_assert((HW_PORT_55_GPIO) >= 0 && (HW_PORT_55_GPIO) <= 254, "HW_PORT_55_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_55 ((uint8_t)(HW_PORT_55_GPIO))
#else
    #define HWPORTS_GPIO_55 ((uint8_t)255)
#endif
#ifdef HW_PORT_56_GPIO
    static_assert((HW_PORT_56_GPIO) >= 0 && (HW_PORT_56_GPIO) <= 254, "HW_PORT_56_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_56 ((uint8_t)(HW_PORT_56_GPIO))
#else
    #define HWPORTS_GPIO_56 ((uint8_t)255)
#endif
#ifdef HW_PORT_57_GPIO
    static_assert((HW_PORT_57_GPIO) >= 0 && (HW_PORT_57_GPIO) <= 254, "HW_PORT_57_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_57 ((uint8_t)(HW_PORT_57_GPIO))
#else
    #define HWPORTS_GPIO_57 ((uint8_t)255)
#endif
#ifdef HW_PORT_58_GPIO
    static_assert((HW_PORT_58_GPIO) >= 0 && (HW_PORT_58_GPIO) <= 254, "HW_PORT_58_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_58 ((uint8_t)(HW_PORT_58_GPIO))
#else
    #define HWPORTS_GPIO_58 ((uint8_t)255)
#endif
#ifdef HW_PORT_59_GPIO
    static_assert((HW_PORT_59_GPIO) >= 0 && (HW_PORT_59_GPIO) <= 254, "HW_PORT_59_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_59 ((uint8_t)(HW_PORT_59_GPIO))
#else
    #define HWPORTS_GPIO_59 ((uint8_t)255)
#endif
#ifdef HW_PORT_60_GPIO
    static_assert((HW_PORT_60_GPIO) >= 0 && (HW_PORT_60_GPIO) <= 254, "HW_PORT_60_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_60 ((uint8_t)(HW_PORT_60_GPIO))
#else
    #define HWPORTS_GPIO_60 ((uint8_t)255)
#endif
#ifdef HW_PORT_61_GPIO
    static_assert((HW_PORT_61_GPIO) >= 0 && (HW_PORT_61_GPIO) <= 254, "HW_PORT_61_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_61 ((uint8_t)(HW_PORT_61_GPIO))
#else
    #define HWPORTS_GPIO_61 ((uint8_t)255)
#endif
#ifdef HW_PORT_62_GPIO
    static_assert((HW_PORT_62_GPIO) >= 0 && (HW_PORT_62_GPIO) <= 254, "HW_PORT_62_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_62 ((uint8_t)(HW_PORT_62_GPIO))
#else
    #define HWPORTS_GPIO_62 ((uint8_t)255)
#endif
#ifdef HW_PORT_63_GPIO
    static_assert((HW_PORT_63_GPIO) >= 0 && (HW_PORT_63_GPIO) <= 254, "HW_PORT_63_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_63 ((uint8_t)(HW_PORT_63_GPIO))
#else
    #define HWPORTS_GPIO_63 ((uint8_t)255)
#endif
#ifdef HW_PORT_64_GPIO
    static_assert((HW_PORT_64_GPIO) >= 0 && (HW_PORT_64_GPIO) <= 254, "HW_PORT_64_GPIO must be a GPIO 0..254");
    #define HWPORTS_GPIO_64 ((uint8_t)(HW_PORT_64_GPIO))
#else
    #define HWPORTS_GPIO_64 ((uint8_t)255)
#endif

/// @brief GPIO of port value 0..63 (port 1..64); 255 for a port the board header does not describe or a larger value
constexpr uint8_t hwPortGpio(uint8_t value)
{
    return value == 0 ? HWPORTS_GPIO_1
         : value == 1 ? HWPORTS_GPIO_2
         : value == 2 ? HWPORTS_GPIO_3
         : value == 3 ? HWPORTS_GPIO_4
         : value == 4 ? HWPORTS_GPIO_5
         : value == 5 ? HWPORTS_GPIO_6
         : value == 6 ? HWPORTS_GPIO_7
         : value == 7 ? HWPORTS_GPIO_8
         : value == 8 ? HWPORTS_GPIO_9
         : value == 9 ? HWPORTS_GPIO_10
         : value == 10 ? HWPORTS_GPIO_11
         : value == 11 ? HWPORTS_GPIO_12
         : value == 12 ? HWPORTS_GPIO_13
         : value == 13 ? HWPORTS_GPIO_14
         : value == 14 ? HWPORTS_GPIO_15
         : value == 15 ? HWPORTS_GPIO_16
         : value == 16 ? HWPORTS_GPIO_17
         : value == 17 ? HWPORTS_GPIO_18
         : value == 18 ? HWPORTS_GPIO_19
         : value == 19 ? HWPORTS_GPIO_20
         : value == 20 ? HWPORTS_GPIO_21
         : value == 21 ? HWPORTS_GPIO_22
         : value == 22 ? HWPORTS_GPIO_23
         : value == 23 ? HWPORTS_GPIO_24
         : value == 24 ? HWPORTS_GPIO_25
         : value == 25 ? HWPORTS_GPIO_26
         : value == 26 ? HWPORTS_GPIO_27
         : value == 27 ? HWPORTS_GPIO_28
         : value == 28 ? HWPORTS_GPIO_29
         : value == 29 ? HWPORTS_GPIO_30
         : value == 30 ? HWPORTS_GPIO_31
         : value == 31 ? HWPORTS_GPIO_32
         : value == 32 ? HWPORTS_GPIO_33
         : value == 33 ? HWPORTS_GPIO_34
         : value == 34 ? HWPORTS_GPIO_35
         : value == 35 ? HWPORTS_GPIO_36
         : value == 36 ? HWPORTS_GPIO_37
         : value == 37 ? HWPORTS_GPIO_38
         : value == 38 ? HWPORTS_GPIO_39
         : value == 39 ? HWPORTS_GPIO_40
         : value == 40 ? HWPORTS_GPIO_41
         : value == 41 ? HWPORTS_GPIO_42
         : value == 42 ? HWPORTS_GPIO_43
         : value == 43 ? HWPORTS_GPIO_44
         : value == 44 ? HWPORTS_GPIO_45
         : value == 45 ? HWPORTS_GPIO_46
         : value == 46 ? HWPORTS_GPIO_47
         : value == 47 ? HWPORTS_GPIO_48
         : value == 48 ? HWPORTS_GPIO_49
         : value == 49 ? HWPORTS_GPIO_50
         : value == 50 ? HWPORTS_GPIO_51
         : value == 51 ? HWPORTS_GPIO_52
         : value == 52 ? HWPORTS_GPIO_53
         : value == 53 ? HWPORTS_GPIO_54
         : value == 54 ? HWPORTS_GPIO_55
         : value == 55 ? HWPORTS_GPIO_56
         : value == 56 ? HWPORTS_GPIO_57
         : value == 57 ? HWPORTS_GPIO_58
         : value == 58 ? HWPORTS_GPIO_59
         : value == 59 ? HWPORTS_GPIO_60
         : value == 60 ? HWPORTS_GPIO_61
         : value == 61 ? HWPORTS_GPIO_62
         : value == 62 ? HWPORTS_GPIO_63
         : value == 63 ? HWPORTS_GPIO_64
         : (uint8_t)255;
}

#undef HWPORTS_GPIO_1
#undef HWPORTS_GPIO_2
#undef HWPORTS_GPIO_3
#undef HWPORTS_GPIO_4
#undef HWPORTS_GPIO_5
#undef HWPORTS_GPIO_6
#undef HWPORTS_GPIO_7
#undef HWPORTS_GPIO_8
#undef HWPORTS_GPIO_9
#undef HWPORTS_GPIO_10
#undef HWPORTS_GPIO_11
#undef HWPORTS_GPIO_12
#undef HWPORTS_GPIO_13
#undef HWPORTS_GPIO_14
#undef HWPORTS_GPIO_15
#undef HWPORTS_GPIO_16
#undef HWPORTS_GPIO_17
#undef HWPORTS_GPIO_18
#undef HWPORTS_GPIO_19
#undef HWPORTS_GPIO_20
#undef HWPORTS_GPIO_21
#undef HWPORTS_GPIO_22
#undef HWPORTS_GPIO_23
#undef HWPORTS_GPIO_24
#undef HWPORTS_GPIO_25
#undef HWPORTS_GPIO_26
#undef HWPORTS_GPIO_27
#undef HWPORTS_GPIO_28
#undef HWPORTS_GPIO_29
#undef HWPORTS_GPIO_30
#undef HWPORTS_GPIO_31
#undef HWPORTS_GPIO_32
#undef HWPORTS_GPIO_33
#undef HWPORTS_GPIO_34
#undef HWPORTS_GPIO_35
#undef HWPORTS_GPIO_36
#undef HWPORTS_GPIO_37
#undef HWPORTS_GPIO_38
#undef HWPORTS_GPIO_39
#undef HWPORTS_GPIO_40
#undef HWPORTS_GPIO_41
#undef HWPORTS_GPIO_42
#undef HWPORTS_GPIO_43
#undef HWPORTS_GPIO_44
#undef HWPORTS_GPIO_45
#undef HWPORTS_GPIO_46
#undef HWPORTS_GPIO_47
#undef HWPORTS_GPIO_48
#undef HWPORTS_GPIO_49
#undef HWPORTS_GPIO_50
#undef HWPORTS_GPIO_51
#undef HWPORTS_GPIO_52
#undef HWPORTS_GPIO_53
#undef HWPORTS_GPIO_54
#undef HWPORTS_GPIO_55
#undef HWPORTS_GPIO_56
#undef HWPORTS_GPIO_57
#undef HWPORTS_GPIO_58
#undef HWPORTS_GPIO_59
#undef HWPORTS_GPIO_60
#undef HWPORTS_GPIO_61
#undef HWPORTS_GPIO_62
#undef HWPORTS_GPIO_63
#undef HWPORTS_GPIO_64

// Hard-wired relays of the board header (HW_RELAY_COUNT, HW_RELAY_<n>_GPIO); 0 relays without HW_RELAY_COUNT
#if defined(HW_RELAY_COUNT) && (HW_RELAY_COUNT) > 8
    #error "HW_RELAY_COUNT of the board header is above 8 (HardwarePorts.h)"
#endif
#if defined(HW_RELAY_COUNT) && (HW_RELAY_COUNT) > 0
#if (HW_RELAY_COUNT) >= 1
    #ifndef HW_RELAY_1_GPIO
        #error "HW_RELAY_COUNT counts relay 1, but HW_RELAY_1_GPIO is missing"
    #endif
    static_assert((HW_RELAY_1_GPIO) >= 0 && (HW_RELAY_1_GPIO) <= 254, "HW_RELAY_1_GPIO must be a GPIO 0..254");
    #define HWPORTS_RELAY_1 ((uint8_t)(HW_RELAY_1_GPIO))
#else
    #define HWPORTS_RELAY_1 ((uint8_t)255)
#endif
#if (HW_RELAY_COUNT) >= 2
    #ifndef HW_RELAY_2_GPIO
        #error "HW_RELAY_COUNT counts relay 2, but HW_RELAY_2_GPIO is missing"
    #endif
    static_assert((HW_RELAY_2_GPIO) >= 0 && (HW_RELAY_2_GPIO) <= 254, "HW_RELAY_2_GPIO must be a GPIO 0..254");
    #define HWPORTS_RELAY_2 ((uint8_t)(HW_RELAY_2_GPIO))
#else
    #define HWPORTS_RELAY_2 ((uint8_t)255)
#endif
#if (HW_RELAY_COUNT) >= 3
    #ifndef HW_RELAY_3_GPIO
        #error "HW_RELAY_COUNT counts relay 3, but HW_RELAY_3_GPIO is missing"
    #endif
    static_assert((HW_RELAY_3_GPIO) >= 0 && (HW_RELAY_3_GPIO) <= 254, "HW_RELAY_3_GPIO must be a GPIO 0..254");
    #define HWPORTS_RELAY_3 ((uint8_t)(HW_RELAY_3_GPIO))
#else
    #define HWPORTS_RELAY_3 ((uint8_t)255)
#endif
#if (HW_RELAY_COUNT) >= 4
    #ifndef HW_RELAY_4_GPIO
        #error "HW_RELAY_COUNT counts relay 4, but HW_RELAY_4_GPIO is missing"
    #endif
    static_assert((HW_RELAY_4_GPIO) >= 0 && (HW_RELAY_4_GPIO) <= 254, "HW_RELAY_4_GPIO must be a GPIO 0..254");
    #define HWPORTS_RELAY_4 ((uint8_t)(HW_RELAY_4_GPIO))
#else
    #define HWPORTS_RELAY_4 ((uint8_t)255)
#endif
#if (HW_RELAY_COUNT) >= 5
    #ifndef HW_RELAY_5_GPIO
        #error "HW_RELAY_COUNT counts relay 5, but HW_RELAY_5_GPIO is missing"
    #endif
    static_assert((HW_RELAY_5_GPIO) >= 0 && (HW_RELAY_5_GPIO) <= 254, "HW_RELAY_5_GPIO must be a GPIO 0..254");
    #define HWPORTS_RELAY_5 ((uint8_t)(HW_RELAY_5_GPIO))
#else
    #define HWPORTS_RELAY_5 ((uint8_t)255)
#endif
#if (HW_RELAY_COUNT) >= 6
    #ifndef HW_RELAY_6_GPIO
        #error "HW_RELAY_COUNT counts relay 6, but HW_RELAY_6_GPIO is missing"
    #endif
    static_assert((HW_RELAY_6_GPIO) >= 0 && (HW_RELAY_6_GPIO) <= 254, "HW_RELAY_6_GPIO must be a GPIO 0..254");
    #define HWPORTS_RELAY_6 ((uint8_t)(HW_RELAY_6_GPIO))
#else
    #define HWPORTS_RELAY_6 ((uint8_t)255)
#endif
#if (HW_RELAY_COUNT) >= 7
    #ifndef HW_RELAY_7_GPIO
        #error "HW_RELAY_COUNT counts relay 7, but HW_RELAY_7_GPIO is missing"
    #endif
    static_assert((HW_RELAY_7_GPIO) >= 0 && (HW_RELAY_7_GPIO) <= 254, "HW_RELAY_7_GPIO must be a GPIO 0..254");
    #define HWPORTS_RELAY_7 ((uint8_t)(HW_RELAY_7_GPIO))
#else
    #define HWPORTS_RELAY_7 ((uint8_t)255)
#endif
#if (HW_RELAY_COUNT) >= 8
    #ifndef HW_RELAY_8_GPIO
        #error "HW_RELAY_COUNT counts relay 8, but HW_RELAY_8_GPIO is missing"
    #endif
    static_assert((HW_RELAY_8_GPIO) >= 0 && (HW_RELAY_8_GPIO) <= 254, "HW_RELAY_8_GPIO must be a GPIO 0..254");
    #define HWPORTS_RELAY_8 ((uint8_t)(HW_RELAY_8_GPIO))
#else
    #define HWPORTS_RELAY_8 ((uint8_t)255)
#endif

/// @brief Number of hard-wired relays of the board (HW_RELAY_COUNT, 0 without)
constexpr uint8_t hwRelayCount() { return (uint8_t)(HW_RELAY_COUNT); }

/// @brief GPIO of hard-wired relay index 0..7 (relay index + 1); 255 for an index the board header does not describe
constexpr uint8_t hwRelayGpio(uint8_t index)
{
    return index >= (uint8_t)(HW_RELAY_COUNT) ? (uint8_t)255
         : index == 0 ? HWPORTS_RELAY_1
         : index == 1 ? HWPORTS_RELAY_2
         : index == 2 ? HWPORTS_RELAY_3
         : index == 3 ? HWPORTS_RELAY_4
         : index == 4 ? HWPORTS_RELAY_5
         : index == 5 ? HWPORTS_RELAY_6
         : index == 6 ? HWPORTS_RELAY_7
         : index == 7 ? HWPORTS_RELAY_8
         : (uint8_t)255;
}

/// @brief true when the GPIO is one of the hard-wired relays of the board
constexpr bool isHwRelayGpio(uint8_t gpio, uint8_t index = 0)
{
    return gpio != 255 && index < (uint8_t)(HW_RELAY_COUNT) && (hwRelayGpio(index) == gpio || isHwRelayGpio(gpio, index + 1));
}

#undef HWPORTS_RELAY_1
#undef HWPORTS_RELAY_2
#undef HWPORTS_RELAY_3
#undef HWPORTS_RELAY_4
#undef HWPORTS_RELAY_5
#undef HWPORTS_RELAY_6
#undef HWPORTS_RELAY_7
#undef HWPORTS_RELAY_8
#else
// no hard-wired relay: no comparison against 0 (-Wtype-limits)
constexpr uint8_t hwRelayCount() { return 0; }
constexpr uint8_t hwRelayGpio(uint8_t) { return (uint8_t)255; }
constexpr bool isHwRelayGpio(uint8_t, uint8_t = 0) { return false; }
#endif
