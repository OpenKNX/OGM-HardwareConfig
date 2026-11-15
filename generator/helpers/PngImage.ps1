#Requires -Version 5.1
<#
Open =
-----+  PngImage
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/helpers/PngImage.ps1

.SYNOPSIS
    PNG reader/writer and the QR code + link image of the hardware profile generator.

.DESCRIPTION
    Dot-sourced by Build-HardwareProfile.ps1 (needs QrCode.ps1). No System.Drawing: zlib streams via
    System.IO.Compression.DeflateStream, own CRC32 and Adler32, all five PNG row filters on read.
      Read-PngRgba           8-bit gray/gray+alpha/RGB/RGBA (tRNS of gray/RGB), non-interlaced -> Width, Height, Pixels (RGBA)
      Update-PngRgba         writes RGBA (filter 0) only when size or pixels differ from the file on disk
      New-QrLinkImage        device card: QR code (white quiet zone) + link in one line below, transparent background;
                             text from a glyph atlas at Scale times the size, averaged down (Add-GlyphTextScaled)

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

$script:PngSignature = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
$script:PngCrcTable = $null

function Get-PngCrcTable {
  if ($null -ne $script:PngCrcTable) { return ,$script:PngCrcTable }
  $t = New-Object long[] 256
  for ($n = 0; $n -lt 256; $n++) {
    [long]$c = $n
    for ($k = 0; $k -lt 8; $k++) {
      if (($c -band 1) -ne 0) { $c = 3988292384L -bxor ($c -shr 1) } else { $c = $c -shr 1 }
    }
    $t[$n] = $c
  }
  $script:PngCrcTable = $t
  return ,$t
}

# @brief CRC-32 (ISO 3309) over Bytes[Offset .. Offset+Count-1]
function Get-PngCrc32([byte[]]$Bytes, [int]$Offset, [int]$Count) {
  $t = Get-PngCrcTable
  [long]$c = 4294967295L
  $end = $Offset + $Count
  for ($i = $Offset; $i -lt $end; $i++) { $c = $t[($c -bxor $Bytes[$i]) -band 0xFF] -bxor ($c -shr 8) }
  return ($c -bxor 4294967295L)
}

function Get-PngAdler32([byte[]]$Bytes) {
  [long]$a = 1; [long]$b = 0
  $i = 0; $n = $Bytes.Length
  while ($i -lt $n) {
    $end = [Math]::Min($n, $i + 5552)   # sums stay below 2^63 without a modulo per byte
    for (; $i -lt $end; $i++) { $a += $Bytes[$i]; $b += $a }
    $a = $a % 65521; $b = $b % 65521
  }
  return ($b * 65536L) + $a
}

function Add-PngUInt32BE([System.Collections.Generic.List[byte]]$List, [long]$Value) {
  $List.Add([byte](($Value -shr 24) -band 0xFF)); $List.Add([byte](($Value -shr 16) -band 0xFF))
  $List.Add([byte](($Value -shr 8) -band 0xFF)); $List.Add([byte]($Value -band 0xFF))
}

function Get-PngUInt32BE([byte[]]$B, [int]$O) {
  return ([long]$B[$O] -shl 24) -bor ([long]$B[$O + 1] -shl 16) -bor ([long]$B[$O + 2] -shl 8) -bor [long]$B[$O + 3]
}

function Add-PngChunk([System.Collections.Generic.List[byte]]$List, [string]$Type, [byte[]]$Data) {
  Add-PngUInt32BE $List $Data.Length
  $body = New-Object byte[] (4 + $Data.Length)
  for ($i = 0; $i -lt 4; $i++) { $body[$i] = [byte][char]$Type[$i] }
  [Array]::Copy($Data, 0, $body, 4, $Data.Length)
  $List.AddRange($body)
  Add-PngUInt32BE $List (Get-PngCrc32 $body 0 $body.Length)
}

# @brief SHA-256 as "XX-XX-..." text; the CryptoServiceProvider class is FIPS-validated (SHA256::Create() is SHA256Managed on
#        .NET Framework, which a FIPS policy blocks)
function Get-PngSha256([byte[]]$Bytes) {
  $sha = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider
  try { return [System.BitConverter]::ToString($sha.ComputeHash($Bytes)) } finally { $sha.Dispose() }
}

# @brief zlib stream (RFC 1950): header 78 9C, raw deflate, Adler-32 of the uncompressed data
function ConvertTo-PngZlib([byte[]]$Raw) {
  $ms = New-Object System.IO.MemoryStream
  $ms.WriteByte(0x78); $ms.WriteByte(0x9C)
  $ds = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionLevel]::Optimal, $true)
  $ds.Write($Raw, 0, $Raw.Length)
  $ds.Dispose()
  $ad = Get-PngAdler32 $Raw
  $ms.WriteByte([byte](($ad -shr 24) -band 0xFF)); $ms.WriteByte([byte](($ad -shr 16) -band 0xFF))
  $ms.WriteByte([byte](($ad -shr 8) -band 0xFF)); $ms.WriteByte([byte]($ad -band 0xFF))
  return ,$ms.ToArray()
}

function ConvertFrom-PngZlib([byte[]]$Data) {
  if ($Data.Length -lt 6 -or ($Data[0] -band 0x0F) -ne 8) { throw "PNG: IDAT is no zlib deflate stream" }
  $in = [System.IO.MemoryStream]::new($Data, 2, $Data.Length - 2)
  $ds = New-Object System.IO.Compression.DeflateStream($in, [System.IO.Compression.CompressionMode]::Decompress)
  $out = New-Object System.IO.MemoryStream
  $ds.CopyTo($out)
  $ds.Dispose()
  return ,$out.ToArray()
}

# @brief Reads the chunks of a PNG file: Width, Height, BitDepth, ColorType, Interlace, Idat (inflated)
function Read-PngRaw([string]$Path) {
  $b = [System.IO.File]::ReadAllBytes($Path)
  for ($i = 0; $i -lt 8; $i++) { if ($b[$i] -ne $script:PngSignature[$i]) { throw "PNG: $Path has no PNG signature" } }
  $pos = 8
  $idat = New-Object System.IO.MemoryStream
  $r = @{}
  while ($pos + 8 -le $b.Length) {
    $len = [int](Get-PngUInt32BE $b $pos)
    $type = [System.Text.Encoding]::ASCII.GetString($b, $pos + 4, 4)
    if ($pos + 12 + $len -gt $b.Length) { throw "PNG: $Path is truncated in chunk $type" }
    if ((Get-PngCrc32 $b ($pos + 4) ($len + 4)) -ne (Get-PngUInt32BE $b ($pos + 8 + $len))) { throw "PNG: $Path CRC error in chunk $type" }
    if ($type -eq "IHDR") {
      $r.Width = [int](Get-PngUInt32BE $b ($pos + 8)); $r.Height = [int](Get-PngUInt32BE $b ($pos + 12))
      $r.BitDepth = $b[$pos + 16]; $r.ColorType = $b[$pos + 17]; $r.Interlace = $b[$pos + 20]
    }
    elseif ($type -eq "IDAT") { $idat.Write($b, $pos + 8, $len) }
    elseif ($type -eq "tRNS") { $r.Trns = New-Object byte[] $len; [Array]::Copy($b, $pos + 8, $r.Trns, 0, $len) }
    elseif ($type -eq "IEND") { break }
    $pos += 12 + $len
  }
  if (-not $r.Width) { throw "PNG: $Path has no IHDR" }
  $r.Idat = ConvertFrom-PngZlib $idat.ToArray()
  return $r
}

function Read-PngRgba([string]$Path) {
  $r = Read-PngRaw $Path
  $chan = @{ 0 = 1; 2 = 3; 4 = 2; 6 = 4 }
  if ($r.BitDepth -ne 8 -or -not $chan.ContainsKey([int]$r.ColorType) -or $r.Interlace -ne 0) {
    throw ("PNG: {0}: only 8-bit gray/RGB/gray+alpha/RGBA, non-interlaced (bit depth {1}, color type {2}, interlace {3})" -f $Path, $r.BitDepth, $r.ColorType, $r.Interlace)
  }
  $bpp = $chan[[int]$r.ColorType]
  # tRNS of gray/RGB: one 16-bit sample per channel names the transparent color (8-bit images use the low byte)
  $key = $null
  if ($r.Trns) {
    if ($bpp -eq 1 -and $r.Trns.Length -ge 2) { $key = @($r.Trns[1]) }
    elseif ($bpp -eq 3 -and $r.Trns.Length -ge 6) { $key = @($r.Trns[1], $r.Trns[3], $r.Trns[5]) }
    else { throw "PNG: $Path has a tRNS chunk this reader does not support" }
  }
  $w = $r.Width; $h = $r.Height
  $stride = $w * $bpp
  $raw = $r.Idat
  if ($raw.Length -lt ($stride + 1) * $h) { throw "PNG: $Path has too little image data" }
  $cur = New-Object byte[] $stride
  $prev = New-Object byte[] $stride
  $px = New-Object byte[] ($w * $h * 4)
  for ($y = 0; $y -lt $h; $y++) {
    $o = $y * ($stride + 1)
    $f = $raw[$o]
    if ($f -eq 0) { [Array]::Copy($raw, $o + 1, $cur, 0, $stride) }
    else {
      for ($i = 0; $i -lt $stride; $i++) {
        $x = [int]$raw[$o + 1 + $i]
        if ($i -ge $bpp) { $a = [int]$cur[$i - $bpp]; $c = [int]$prev[$i - $bpp] } else { $a = 0; $c = 0 }
        $up = [int]$prev[$i]
        switch ($f) {
          0 { $v = $x }
          1 { $v = $x + $a }
          2 { $v = $x + $up }
          3 { $v = $x + [int][Math]::Floor(($a + $up) / 2) }
          4 {
            $p = $a + $up - $c
            $pa = [Math]::Abs($p - $a); $pb = [Math]::Abs($p - $up); $pc = [Math]::Abs($p - $c)
            if ($pa -le $pb -and $pa -le $pc) { $pr = $a } elseif ($pb -le $pc) { $pr = $up } else { $pr = $c }
            $v = $x + $pr
          }
          default { throw "PNG: $Path unknown filter $f in row $y" }
        }
        $cur[$i] = [byte]($v -band 0xFF)
      }
    }
    $d = $y * $w * 4
    for ($xx = 0; $xx -lt $w; $xx++) {
      $s = $xx * $bpp
      switch ($bpp) {
        1 {
          $px[$d] = $cur[$s]; $px[$d + 1] = $cur[$s]; $px[$d + 2] = $cur[$s]; $px[$d + 3] = 255
          if ($null -ne $key -and $cur[$s] -eq $key[0]) { $px[$d + 3] = 0 }
        }
        2 { $px[$d] = $cur[$s]; $px[$d + 1] = $cur[$s]; $px[$d + 2] = $cur[$s]; $px[$d + 3] = $cur[$s + 1] }
        3 {
          $px[$d] = $cur[$s]; $px[$d + 1] = $cur[$s + 1]; $px[$d + 2] = $cur[$s + 2]; $px[$d + 3] = 255
          if ($null -ne $key -and $cur[$s] -eq $key[0] -and $cur[$s + 1] -eq $key[1] -and $cur[$s + 2] -eq $key[2]) { $px[$d + 3] = 0 }
        }
        4 { $px[$d] = $cur[$s]; $px[$d + 1] = $cur[$s + 1]; $px[$d + 2] = $cur[$s + 2]; $px[$d + 3] = $cur[$s + 3] }
      }
      $d += 4
    }
    $t = $prev; $prev = $cur; $cur = $t
  }
  return @{ Width = $w; Height = $h; Pixels = $px }
}

# @brief Scanlines with filter byte 0 (the form Update-PngRgba writes and compares)
function ConvertTo-PngScanlines([int]$Width, [int]$Height, [byte[]]$Pixels) {
  $stride = $Width * 4
  $raw = New-Object byte[] (($stride + 1) * $Height)
  for ($y = 0; $y -lt $Height; $y++) { [Array]::Copy($Pixels, $y * $stride, $raw, $y * ($stride + 1) + 1, $stride) }
  return ,$raw
}

# @brief Writes an 8-bit RGBA PNG unless the file on disk has the same size and pixels
# @return $true when the file was written (an unchanged file keeps its timestamp, which the producer puts into the knxprod)
function Update-PngRgba([string]$Path, [int]$Width, [int]$Height, [byte[]]$Pixels) {
  $raw = ConvertTo-PngScanlines $Width $Height $Pixels
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    try {
      # a file this function wrote holds exactly these scanlines (filter 0 in every row)
      $old = Read-PngRaw $Path
      if ($old.Width -eq $Width -and $old.Height -eq $Height -and $old.BitDepth -eq 8 -and $old.ColorType -eq 6 -and $old.Interlace -eq 0 -and
          [System.Convert]::ToBase64String($old.Idat) -ceq [System.Convert]::ToBase64String($raw)) { return $false }
    }
    catch { }   # unreadable file: write it again
  }
  if ($script:CheckMode) { return $true }   # Build-HardwareProfile.ps1 -Check: report, never write
  $png = New-Object System.Collections.Generic.List[byte]
  $png.AddRange($script:PngSignature)
  $ihdr = New-Object System.Collections.Generic.List[byte]
  Add-PngUInt32BE $ihdr $Width
  Add-PngUInt32BE $ihdr $Height
  $ihdr.AddRange([byte[]](8, 6, 0, 0, 0))   # 8 bit, RGBA, deflate, filter method 0, no interlace
  Add-PngChunk $png "IHDR" $ihdr.ToArray()
  Add-PngChunk $png "IDAT" (ConvertTo-PngZlib $raw)
  Add-PngChunk $png "IEND" (New-Object byte[] 0)
  $dir = [System.IO.Path]::GetDirectoryName($Path)
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  [System.IO.File]::WriteAllBytes($Path, $png.ToArray())
  return $true
}

# ------------------------------------------------------------------------------------------------
# QR code + link of the device card (<InfoImage>): proportional glyph atlas, text supersampled
# ------------------------------------------------------------------------------------------------
# @brief Reads a glyph atlas <Dir>/<Name>.png (alpha = coverage) and its metrics <Name>.txt
#        (lines "height h", "baseline b", "code x width lsb advance64")
function Read-GlyphFont([string]$Dir, [string]$Name) {
  $png = [System.IO.Path]::Combine($Dir, $Name + ".png")
  $txt = [System.IO.Path]::Combine($Dir, $Name + ".txt")
  if (-not (Test-Path -LiteralPath $png) -or -not (Test-Path -LiteralPath $txt)) { throw "glyph atlas $Name not found in $Dir" }
  $img = Read-PngRgba $png
  $f = @{ Name = $Name; Width = $img.Width; Pixels = $img.Pixels; Height = 0; Baseline = 0; Glyphs = @{} }
  foreach ($l in [System.IO.File]::ReadAllLines($txt)) {
    if ($l -match '^height (\d+)$') { $f.Height = [int]$Matches[1] }
    elseif ($l -match '^baseline (\d+)$') { $f.Baseline = [int]$Matches[1] }
    elseif ($l -match '^(\d+) (\d+) (\d+) (-?\d+) (\d+)$') {
      $f.Glyphs[[int]$Matches[1]] = @{ X = [int]$Matches[2]; W = [int]$Matches[3]; Lsb = [int]$Matches[4]; Adv = [int]$Matches[5] }
    }
  }
  if ($f.Height -ne $img.Height -or $f.Glyphs.Count -eq 0) { throw "glyph atlas $Name : metrics do not match the image" }
  return $f
}

# @brief Width of Text in atlas px (advances summed in 1/64 px, rounded up); stops on a character without glyph
function Measure-GlyphText($Font, [string]$Text) {
  $pen = 0
  foreach ($ch in $Text.ToCharArray()) {
    $g = $Font.Glyphs[[int]$ch]
    if ($null -eq $g) { throw ("no glyph for '{0}' (U+{1:X4}) in {2}" -f $ch, [int]$ch, $Font.Name) }
    $pen += $g.Adv
  }
  return [int][Math]::Ceiling($pen / 64.0)
}

# @brief Draws Text from an atlas rendered at Scale times the target size: glyphs at atlas resolution into a buffer, then
#        Scale x Scale blocks averaged (glyph positions exact to 1/Scale px, no per-glyph rounding to whole target pixels).
#        X = left edge in target px (in 1/Scale px steps), Y = top of the line box (atlas cell height / Scale, rounded up).
function Add-GlyphTextScaled([byte[]]$Px, [int]$ImgW, [int]$ImgH, $Font, [int]$Scale, [string]$Text, [double]$X, [int]$Y, [byte[]]$Rgb) {
  $x0 = [int][Math]::Floor($X)
  $shift = [int][Math]::Round(($X - $x0) * $Scale)
  $outW = [int][Math]::Ceiling(($shift + (Measure-GlyphText $Font $Text)) / $Scale) + 2
  $outH = [int][Math]::Ceiling($Font.Height / $Scale)
  $bw = $outW * $Scale; $bh = $outH * $Scale
  $buf = New-Object byte[] ($bw * $bh)
  $fw = $Font.Width; $fp = $Font.Pixels; $fh = $Font.Height
  $pen = $shift * 64
  foreach ($ch in $Text.ToCharArray()) {
    $g = $Font.Glyphs[[int]$ch]
    $gx = [int][Math]::Round($pen / 64.0) + $g.Lsb
    for ($yy = 0; $yy -lt $fh; $yy++) {
      $src = ($yy * $fw + $g.X) * 4 + 3
      for ($xx = 0; $xx -lt $g.W; $xx++) {
        $a = $fp[$src + $xx * 4]
        if ($a -eq 0) { continue }
        $dx = $gx + $xx
        if ($dx -lt 0 -or $dx -ge $bw) { continue }
        $d = $yy * $bw + $dx
        if ($a -gt $buf[$d]) { $buf[$d] = $a }
      }
    }
    $pen += $g.Adv
  }
  $area = $Scale * $Scale
  for ($oy = 0; $oy -lt $outH; $oy++) {
    $ty = $Y + $oy
    if ($ty -lt 0 -or $ty -ge $ImgH) { continue }
    for ($ox = 0; $ox -lt $outW; $ox++) {
      $tx = $x0 + $ox
      if ($tx -lt 0 -or $tx -ge $ImgW) { continue }
      $sum = 0
      for ($sy = 0; $sy -lt $Scale; $sy++) {
        $row = ($oy * $Scale + $sy) * $bw + $ox * $Scale
        for ($sx = 0; $sx -lt $Scale; $sx++) { $sum += $buf[$row + $sx] }
      }
      if ($sum -eq 0) { continue }
      $a = [int][Math]::Round($sum / $area)
      $d = ($ty * $ImgW + $tx) * 4
      if ($a -gt $Px[$d + 3]) { $Px[$d] = $Rgb[0]; $Px[$d + 1] = $Rgb[1]; $Px[$d + 2] = $Rgb[2]; $Px[$d + 3] = $a }
    }
  }
}

# @brief QR code + link, Width px wide, transparent: QR code of Url (EC M, version Version or the smallest larger one that fits,
#        Module px per module, quiet zone 4 modules opaque white) centered at the top; below it Shown in one line, centered
#        (atlas Font at Scale times the target size, color Rgb). Stops when the QR code or the line is wider than Width.
# @return Width, Height, Pixels, Qr, QrPx, TextW
function New-QrLinkImage([string]$Url, [string]$Shown, [int]$Width, [int]$Module, [int]$Version, $Font, [int]$Scale, [byte[]]$Rgb) {
  foreach ($ch in $Url.ToCharArray()) { if ([int]$ch -lt 32 -or [int]$ch -gt 126) { throw "info URL has a character outside ASCII 32..126: $Url" } }
  $quiet = 4
  $q = New-QrMatrix $Url "M" $Version
  $n = $q.Size; $mp = $Module
  $qrPx = ($n + 2 * $quiet) * $mp
  if ($qrPx -gt $Width) { throw ("QR code {0} px (version {1}) is wider than the image ({2} px): {3}" -f $qrPx, $q.Version, $Width, $Url) }
  $textW = (Measure-GlyphText $Font $Shown) / $Scale
  if ($textW -gt $Width) { throw ("link '{0}' is {1:N1} px wide, the image {2} px (shorter link or larger width)" -f $Shown, $textW, $Width) }
  $gap = 4
  $h = $qrPx + $gap + [int][Math]::Ceiling($Font.Height / $Scale)
  $px = New-Object byte[] ($Width * $h * 4)
  $stride = $Width * 4
  $qrX = [int][Math]::Floor(($Width - $qrPx) / 2)
  $white = New-Object byte[] ($qrPx * 4)
  for ($i = 0; $i -lt $qrPx * 4; $i++) { $white[$i] = 255 }
  for ($yy = 0; $yy -lt $qrPx; $yy++) { [Array]::Copy($white, 0, $px, $yy * $stride + $qrX * 4, $qrPx * 4) }
  for ($yy = 0; $yy -lt $n; $yy++) {
    for ($x = 0; $x -lt $n; $x++) {
      if ($q.Dark[$yy * $n + $x] -eq 0) { continue }
      for ($r = 0; $r -lt $mp; $r++) {
        $o = (($quiet + $yy) * $mp + $r) * $stride + ($qrX + ($quiet + $x) * $mp) * 4
        for ($c = 0; $c -lt $mp; $c++) { $px[$o + $c * 4] = 0; $px[$o + $c * 4 + 1] = 0; $px[$o + $c * 4 + 2] = 0 }
      }
    }
  }
  # line center at the image center, in 1/Scale px steps
  $tx = [Math]::Round((($Width - $textW) / 2) * $Scale) / $Scale
  Add-GlyphTextScaled $px $Width $h $Font $Scale $Shown $tx ($qrPx + $gap) $Rgb
  return @{ Width = $Width; Height = $h; Pixels = $px; Qr = $q; QrPx = $qrPx; TextW = $textW }
}
