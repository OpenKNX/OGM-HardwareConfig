# REG board component datasheets

Reference copies of the vendor documents for the parts the REG1 / REG2 hardware definitions in
`include/HardwareConfig/` refer to. Each stays the copyright of its manufacturer; the vendor source is
listed so a newer revision can be pulled at any time.

| File | Document | Referenced by |
|---|---|---|
| `PCA9557.pdf` | NXP PCA9557, Rev. 7, 30 pp. | REG2 front-panel I/O expander (`OPENKNX_PCA9557_PINS`, LEDs + buttons) |
| `TCA6408A.pdf` | TI TCA6408A, 50 pp. | REG1 SA-4xSELV app board (`OPENKNX_GPIO_T_TCA6408`) |
| `PCF8523.pdf` | NXP PCF8523, Rev. 7, 78 pp. | RTC option, I2C 0x57 (`OKNXHW_REG2_HWRTCLOCK_I2C_ADDRESS`) |
| `SSD1306.pdf` | Solomon Systech SSD1306, Rev 1.1 (Apr 2008), 65 pp. | REG2 OLED (`DEVICE_DISPLAY_MODULE`) |
| `SSD1315.pdf` | Solomon Systech SSD1315, Rev 1.1, 62 pp. | REG2 OLED variant (`DEVICE_DISPLAY_MODULE_SSD1315`) |

Missing: **DS3231** (RTC option, I2C 0x68). analog.com refuses the direct download; fetch
`https://www.analog.com/media/en/technical-documentation/data-sheets/DS3231.pdf` manually.

Not collected (large, add on demand): RP2040, RP2350 and ESP32-S3 datasheets / reference manuals.

The W5500 (REG1/REG2 ETH app board) and LAN8720A (REG1-LAN-TP-Base native ETH) live with the driver
that uses them, in `OFM-Network/doc/datasheets/`. The KNX transceivers (NCN5120/5121/5130) live in
`TPUart/doc/datasheets/`.

Sources: [PCA9557](https://www.nxp.com/docs/en/data-sheet/PCA9557.pdf) ·
[TCA6408A](https://www.ti.com/lit/ds/symlink/tca6408a.pdf) ·
[PCF8523](https://www.nxp.com/docs/en/data-sheet/PCF8523.pdf) ·
[SSD1306](https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf) ·
[SSD1315](https://cursedhardware.github.io/epd-driver-ic/SSD1315.pdf)

`pdftotext` is not installed here; extract text with PyMuPDF:

```bash
python3 -c "import fitz; d=fitz.open('doc/datasheets/PCA9557.pdf'); print(d[0].get_text())"  # d[N] = page N+1
```
