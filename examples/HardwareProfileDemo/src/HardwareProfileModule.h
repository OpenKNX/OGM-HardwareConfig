#pragma once
/**
 * @file HardwareProfileModule.h
 * @brief Reports the hardware profile of this firmware to ETS and checks the ETS hardware selection.
 * @note Candidate for OGM-Common: the device query would then be one common function property.
 */
#include "OpenKNX.h"

class HardwareProfileModule : public OpenKNX::Module
{
  public:
    const std::string name() override;
    const std::string version() override;
    void setup(bool configured) override;
    bool processFunctionProperty(uint8_t objectIndex, uint8_t propertyId, uint8_t length, uint8_t *data, uint8_t *resultData, uint8_t &resultLength) override;
    bool processCommand(const std::string cmd, bool diagnoseKo) override;
    void showHelp() override;

  private:
    void showProfile();
};

extern HardwareProfileModule openknxHardwareProfileModule;
