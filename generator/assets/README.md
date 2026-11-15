# Generator assets

Rendered once and committed; `Build-HardwareProfile.ps1` only decodes and composes them (`helpers/PngImage.ps1`).

| File | Content | Source | License |
|---|---|---|---|
| `card-badge.png` | OpenKNX logo of the device card (`<InfoImage>`, boards without the third-party capability), 44x26 RGBA | OFM-Network `web/assets/logo.svg`, letters recolored from white to `#1C1F1C` | OpenKNX |
| `third-party-badge.png` | badge of third-party boards on the device card: "Drittanbieter" / "Hardware" in a thin frame, 84x26 RGBA | Noto Sans SemiBold 11 px / Regular 10 px, `#5C5C5C`, frame `#9A9A9A` radius 3 | SIL Open Font License 1.1, see `LICENSE-NotoSans.txt` |
| `fonts/NotoSans-Regular-44.png/.txt` | glyph atlas of the link below the QR code, 4x the drawn size (11 px): one row of glyph cells (white, alpha = coverage), metrics per line `code x width lsb advance64` plus `height` and `baseline`; ASCII 32..126, ÄÖÜäöüß, U+00B7, U+2013, U+201E, U+201C, é, µ, ° | Noto Sans Regular | SIL Open Font License 1.1, see `LICENSE-NotoSans.txt` |
| `query-steps.svg` / `.png` | Schritt-Bild der Hardware-Seite (`<Page queryImage>`): 1 physikalische Adresse programmieren (Finger auf der Programmiertaste, Adresse 1.1.20), 2 andere Seite im Baum und zurück, 3 Knopf klicken (Haken); 532x70 RGBA, transparent, Piktogramme 65 %, Inhalt mittig, kein Wort im Bild | eigene Zeichnung (SVG) | OpenKNX |
| `icons/memory.png` | page icon `memory`, 32x32 black RGBA like the OGM-Common icons | Material Design Icons (Pictogrammers), `mdi-memory` | Apache-2.0 |

## Rendering

```sh
sed 's/fill="white"/fill="#1C1F1C"/g' logo.svg > logo-dark.svg
rsvg-convert -h 26 logo-dark.svg -o card-badge.png
rsvg-convert -w 32 -h 32 memory.svg -o icons/memory.png
rsvg-convert -w 532 -h 70 query-steps.svg -o query-steps.png
```
`third-party-badge.png`: frame and both lines drawn with Pillow at 4x the size, reduced with Lanczos to 84x26.

Glyph atlas: each glyph rendered once with FreeType (Pillow `ImageFont.truetype(44)`, antialiased) at its integer pen position
on the baseline; cell = ink box + 1 px each side; `lsb` = cell start relative to the pen, `advance64` = advance in 1/64 px.
The generator draws the link at atlas size and averages 4x4 blocks (`Add-GlyphTextScaled` in `helpers/PngImage.ps1`, `<InfoImage
supersample>`), so glyph positions are exact to 1/4 px instead of rounded to whole pixels per glyph.
