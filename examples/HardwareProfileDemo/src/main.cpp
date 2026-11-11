#include "OpenKNX.h"
#include "HardwareProfileModule.h"

void setup()
{
#ifdef FIRMWARE_REVISION
    openknx.init();
#else
    const uint8_t firmwareRevision = 0;
    openknx.init(firmwareRevision);
#endif
    openknx.addModule(1, openknxHardwareProfileModule);
    openknx.setup();
}

void loop()
{
    openknx.loop();
}
