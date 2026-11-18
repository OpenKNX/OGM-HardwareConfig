#pragma once
/**
 * OpenKNX Hardware Configuration Header File
 *
 * Defines hardware properties for various reusable OpenKNX hardware modules and
 * includes hardware definition headers for various OpenKNX modules.
 *
 * Note: This file should only contain include directives for hardware configuration headers.
 *       No hardware configurations should be made directly in this file.
 *
 * Naming Conventions for OpenKNX Hardware Definitions:
 *     1. to be defined.
 *
 * Naming Conventions for 3rd Party Hardware Definitions (Others/<vendor>/Devices.h, logo.png next to it):
 *     1. to be defined.
 */

/**
 * Include hardware definition headers:
 *
 */

// OpenKNX Hardware Configurations
#include "HardwareConfig/OpenKNX/REG1.h"
#include "HardwareConfig/OpenKNX/REG2.h"
#include "HardwareConfig/OpenKNX/UP1.h"
#include "HardwareConfig/OpenKNX/Xiao.h"
#include "HardwareConfig/OpenKNX/misc.h"

// 3rd Party Hardware Configurations: one folder per vendor (Devices.h, logo.png)
//  #include "HardwareConfig/Others/XYZ/Devices.h"
#include "HardwareConfig/Others/AB-SmartHouse/Devices.h"
#include "HardwareConfig/Others/Adafruit/Devices.h"
#include "HardwareConfig/Others/Gledopto/Devices.h"
#include "HardwareConfig/Others/QuinLed/Devices.h"
#include "HardwareConfig/Others/Shelly/Devices.h"
#include "HardwareConfig/Others/Smart-MF/Devices.h"
