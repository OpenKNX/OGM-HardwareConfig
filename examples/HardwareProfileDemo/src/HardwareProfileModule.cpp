#include "HardwareProfileModule.h"
#include "HardwareProfileData.h"

const std::string HardwareProfileModule::name()
{
    return "HardwareProfile";
}

const std::string HardwareProfileModule::version()
{
    return "0.1";
}

void HardwareProfileModule::setup(bool configured)
{
    showProfile();
    if (!configured)
        return;

    // ETS stores the selected DEVICE_HW_ID; a different value means the product was configured for other hardware
    const uint16_t selected = ParamHWP_HardwareSelect;
    switch (HardwareProfile::checkSelection(selected))
    {
        case HardwareProfile::Selection::NotSelected:
            logWarningP("ETS: no hardware selected - the application hides every hardware dependent setting");
            break;
        case HardwareProfile::Selection::Other:
            logWarningP("ETS: hardware 0x%04X selected, this firmware is built for 0x%04X - settings may not match the device", selected, HardwareProfile::OWN_HW_ID);
            break;
        case HardwareProfile::Selection::Match:
            logInfoP("ETS: hardware selection matches this firmware (0x%04X)", selected);
            break;
    }

    // GPIO role: ETS writes the byte only for the selected board and only if that board offers pins
    if (selected != HardwareProfile::OWN_HW_ID || !HardwareProfile::ROLE_Pin_ON_OWN_BOARD)
        return;
    const uint8_t pin1 = HWP_ROLE_Pin_1;
    const uint8_t pin2 = HWP_ROLE_Pin_2;
    logInfoP("ETS: Freier Anschluss 1 = %s%u, 2 = %s%u",
             pin1 == HardwareProfile::PIN_UNUSED ? "unused " : "GPIO ", pin1 == HardwareProfile::PIN_UNUSED ? 0 : pin1,
             pin2 == HardwareProfile::PIN_UNUSED ? "unused " : "GPIO ", pin2 == HardwareProfile::PIN_UNUSED ? 0 : pin2);
}

bool HardwareProfileModule::processFunctionProperty(uint8_t objectIndex, uint8_t propertyId, uint8_t length, uint8_t *data, uint8_t *resultData, uint8_t &resultLength)
{
    // device query (FP 158/4): answer generated into HardwareProfileData.h; runtime="true" capabilities come from the
    // firmware (a real board probes its slot here, e.g. an I2C address; the demo has no module)
    const bool sensorModuleFound = false;
    const uint32_t runtimeCaps = sensorModuleFound ? (1u << HardwareProfile::CapSensorModule) : 0u;
    if (!HardwareProfile::answerQuery(objectIndex, propertyId, resultData, resultLength, runtimeCaps))
        return false;
    logInfoP("ETS query answered: 0x%04X caps 0x%08lX", HardwareProfile::OWN_HW_ID, (unsigned long)(HardwareProfile::OWN_CAPS | (runtimeCaps & HardwareProfile::RUNTIME_CAPS)));
    return true;
}

#ifdef DEVICE_NAME
    #define HWP_OWN_NAME DEVICE_NAME
#else
    #define HWP_OWN_NAME "unnamed board"
#endif

void HardwareProfileModule::showProfile()
{
    logInfoP("Hardware 0x%04X %s (%s in the ETS list)", HardwareProfile::OWN_HW_ID, HWP_OWN_NAME,
             HardwareProfile::isKnown(HardwareProfile::OWN_HW_ID) ? "present" : "MISSING");
    logIndentUp();
    for (uint8_t i = 0; i < HardwareProfile::CAPABILITY_COUNT; i++)
        logInfoP("%-12s %s", HardwareProfile::CAPABILITY_NAMES[i],
                 ((HardwareProfile::OWN_CAPS >> i) & 1) ? "yes" : (((HardwareProfile::RUNTIME_CAPS >> i) & 1) ? "slot (run time)" : "-"));
    for (uint8_t i = 0; i < HardwareProfile::VALUE_COUNT; i++)
        logInfoP("%-12s %u", HardwareProfile::VALUE_NAMES[i], HardwareProfile::OWN_VALUES[i]);
    logIndentDown();
}

bool HardwareProfileModule::processCommand(const std::string cmd, bool diagnoseKo)
{
    if (cmd == "hwp")
    {
        showProfile();
        return true;
    }
    return false;
}

void HardwareProfileModule::showHelp()
{
    openknx.console.printHelpLine("hwp", "Show the hardware profile of this firmware");
}

HardwareProfileModule openknxHardwareProfileModule;
