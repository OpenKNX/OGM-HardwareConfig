# Generator assets

Rendered once and committed; `Build-HardwareProfile.ps1` only decodes and composes them (`helpers/PngImage.ps1`).

| File | Content | Source | License |
|---|---|---|---|
| `third-party-badge.png` | badge of third-party boards on the device card: "Drittanbieter" / "Hardware" in a frame, 100x34 RGBA | Noto Sans SemiBold 13 px `#1E1E1E` / Regular 10 px `#444444`, frame 1.5 px `#333333` radius 3 | SIL Open Font License 1.1, see `LICENSE-NotoSans.txt` |
| `fonts/NotoSans-Regular-44.png/.txt` | glyph atlas of the caption below the QR code, 4x the drawn size (11 px): one row of glyph cells (white, alpha = coverage), metrics per line `code x width lsb advance64` plus `height` and `baseline`; ASCII 32..126, ÄÖÜäöüß, U+00B7, U+2013, U+201E, U+201C, é, µ, ° | Noto Sans Regular | SIL Open Font License 1.1, see `LICENSE-NotoSans.txt` |
| `query-steps.svg` / `.png` | Schritt-Bild der Hardware-Seite (`<Page queryImage>`): 1 physikalische Adresse programmieren (Finger auf der Programmiertaste, Adresse 1.1.20), 2 andere Seite im Baum und zurück, 3 Knopf klicken (Haken); 532x70 RGBA, transparent, Piktogramme 65 %, Inhalt mittig, kein Wort im Bild | eigene Zeichnung (SVG) | OpenKNX |
| `icons/memory.png` | page icon `memory`, 32x32 black RGBA like the OGM-Common icons | Material Design Icons (Pictogrammers), `mdi-memory` | Apache-2.0 |

## Rendering

```sh
sed 's/fill="white"/fill="#1C1F1C"/g' logo.svg > logo-dark.svg
rsvg-convert -h 44 logo-dark.svg -o ../../include/HardwareConfig/OpenKNX/logo.png
rsvg-convert -w 32 -h 32 memory.svg -o icons/memory.png
rsvg-convert -w 532 -h 70 query-steps.svg -o query-steps.png
```
`third-party-badge.png`: frame and both lines drawn with Pillow at 4x the size, reduced with Lanczos to 100x34.

Glyph atlas: each glyph rendered once with FreeType (Pillow `ImageFont.truetype(44)`, antialiased) at its integer pen position
on the baseline; cell = ink box + 1 px each side; `lsb` = cell start relative to the pen, `advance64` = advance in 1/64 px.
The generator draws the caption at atlas size and averages 4x4 blocks (`Add-GlyphTextScaled` in `helpers/PngImage.ps1`, `<InfoImage
supersample>`), so glyph positions are exact to 1/4 px instead of rounded to whole pixels per glyph.

## Logos of the device card (next to the board headers)

The left column of the device card shows `HW_INFO_LOGO` of the board block (a path found like an `#include`), boards without it
the OpenKNX logo (`<InfoImage logo>`, default `include/HardwareConfig/OpenKNX/logo.png`); third-party boards without
`HW_INFO_LOGO` show the badge in its place. A logo is at most 100x74 px (left column, QR code height); the files fit into 100x44 px.

| File | Source |
|---|---|
| `include/HardwareConfig/OpenKNX/logo.png` | OFM-Network `web/assets/logo.svg`, letters `#1C1F1C`, `rsvg-convert -h 44` |
| `include/HardwareConfig/Others/AB-SmartHouse/logo.png` | logo provided by the maintainer, trimmed, 44 px high |
| `include/HardwareConfig/Others/Adafruit/logo.png` | Wikimedia Commons `File:Adafruit logo.svg`, fit into 100x44 |
| `include/HardwareConfig/Others/Gledopto/logo.png` | gledopto.eu shop logo, cropped to the Gledopto mark (without the reseller line), 44 px high |
| `include/HardwareConfig/Others/QuinLed/logo.png` | logo of Intermit.Tech (maker of the QuinLED boards), GitHub avatar of `intermittech` (transparent background), trimmed, fit into 100x44 (100x30) |
| `include/HardwareConfig/Others/Shelly/logo.png` | Wikipedia (de) `Datei:Shelly Group logo.svg`, fit into 100x44 |
| `include/HardwareConfig/Others/Smart-MF/logo.png` | smart-mf.de header logo, trimmed, fit into 100x44 |

The logos are trademarks of their owners; they mark the hardware of the vendor on the device card.
