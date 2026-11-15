#Requires -Version 5.1
<#
Open =
-----+  QrCode
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/helpers/QrCode.ps1

.SYNOPSIS
    QR code encoder (ISO/IEC 18004, byte mode) of the hardware profile generator.

.DESCRIPTION
    Dot-sourced by Build-HardwareProfile.ps1. New-QrMatrix encodes a text (UTF-8) in byte mode with
    the smallest version 1..40 that holds it at the given error correction level (or a given minimum
    version) and the mask with the lowest penalty score.
    Result: hashtable Size, Version, Ec, Mask, Dark (byte[] Size*Size, row-major, 1 = dark module), EccPerBlock,
    Blocks, ModuleBlockCw (int[] Size*Size: block * 65536 + codeword index in its block, -1 = function module or
    remainder bit) for the error correction budget of a logo, IsFunction (bool[] Size*Size: finder, timing, alignment,
    format and version modules).

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# error correction codewords per block and number of blocks, index = version (0 unused)
$script:QrEccPerBlock = @{
  L = @(-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30)
  M = @(-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28)
  Q = @(-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30)
  H = @(-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30)
}
$script:QrBlocks = @{
  L = @(-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25)
  M = @(-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49)
  Q = @(-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68)
  H = @(-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81)
}
$script:QrEcFormatBits = @{ L = 1; M = 0; Q = 3; H = 2 }

# @brief Modules of a version available for codewords (without function patterns, format and version info)
function Get-QrRawDataModules([int]$Version) {
  $r = (16 * $Version + 128) * $Version + 64
  if ($Version -ge 2) {
    $na = [int][Math]::Floor($Version / 7) + 2
    $r -= (25 * $na - 10) * $na - 55
    if ($Version -ge 7) { $r -= 36 }
  }
  return $r
}

function Get-QrDataCodewords([int]$Version, [string]$Ec) {
  return [int][Math]::Floor((Get-QrRawDataModules $Version) / 8) - $script:QrEccPerBlock[$Ec][$Version] * $script:QrBlocks[$Ec][$Version]
}

function Get-QrAlignmentPositions([int]$Version) {
  if ($Version -eq 1) { return @() }
  $size = $Version * 4 + 17
  $na = [int][Math]::Floor($Version / 7) + 2
  if ($Version -eq 32) { $step = 26 } else { $step = [int][Math]::Ceiling(($Version * 4 + 4) / ($na * 2 - 2)) * 2 }
  $list = New-Object System.Collections.Generic.List[int]
  $pos = $size - 7
  while ($list.Count -lt ($na - 1)) { $list.Insert(0, $pos); $pos -= $step }
  $list.Insert(0, 6)
  return ,$list.ToArray()
}

# @brief GF(256) multiplication, reducing polynomial 0x11D
function Get-QrGfMul([int]$X, [int]$Y) {
  $z = 0
  for ($i = 7; $i -ge 0; $i--) {
    $z = (($z -shl 1) -bxor (($z -shr 7) * 0x11D)) -band 0xFF
    if ((($Y -shr $i) -band 1) -ne 0) { $z = $z -bxor $X }
  }
  return $z
}

function Get-QrRsDivisor([int]$Degree) {
  $res = New-Object int[] $Degree
  $res[$Degree - 1] = 1
  $root = 1
  for ($i = 0; $i -lt $Degree; $i++) {
    for ($j = 0; $j -lt $Degree; $j++) {
      $res[$j] = Get-QrGfMul $res[$j] $root
      if ($j + 1 -lt $Degree) { $res[$j] = $res[$j] -bxor $res[$j + 1] }
    }
    $root = Get-QrGfMul $root 2
  }
  return ,$res
}

function Get-QrRsRemainder([int[]]$Data, [int[]]$Divisor) {
  $d = $Divisor.Length
  $res = New-Object int[] $d
  foreach ($b in $Data) {
    $factor = $b -bxor $res[0]
    [Array]::Copy($res, 1, $res, 0, $d - 1)
    $res[$d - 1] = 0
    for ($i = 0; $i -lt $d; $i++) { $res[$i] = $res[$i] -bxor (Get-QrGfMul $Divisor[$i] $factor) }
  }
  return ,$res
}

# @brief Encodes Text (UTF-8, byte mode); Ec = L/M/Q/H; MinVersion raises the version (e.g. room for a logo)
function New-QrMatrix([string]$Text, [string]$Ec = "M", [int]$MinVersion = 1) {
  if (-not $script:QrEcFormatBits.ContainsKey($Ec)) { throw (T "QR: unknown error correction level '{0}'" $Ec) }
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $version = 0
  for ($v = [Math]::Max(1, $MinVersion); $v -le 40; $v++) {
    $ccBits = 8; if ($v -ge 10) { $ccBits = 16 }
    $need = 4 + $ccBits + 8 * $bytes.Length
    if ($need -le (Get-QrDataCodewords $v $Ec) * 8) { $version = $v; break }
  }
  if ($version -eq 0) { throw (T "QR: text of {0} bytes does not fit version 40-{1}" $bytes.Length $Ec) }
  $capBits = (Get-QrDataCodewords $version $Ec) * 8

  # data bit stream: mode 0100, character count, bytes, terminator, padding
  $bits = New-Object System.Collections.Generic.List[byte]
  $addBits = { param($val, $n) for ($i = $n - 1; $i -ge 0; $i--) { $bits.Add([byte](($val -shr $i) -band 1)) } }
  & $addBits 4 4
  $ccBits = 8; if ($version -ge 10) { $ccBits = 16 }
  & $addBits $bytes.Length $ccBits
  foreach ($b in $bytes) { & $addBits ([int]$b) 8 }
  & $addBits 0 ([Math]::Min(4, $capBits - $bits.Count))
  & $addBits 0 ((8 - ($bits.Count % 8)) % 8)
  $pad = 0xEC
  while ($bits.Count -lt $capBits) { & $addBits $pad 8; $pad = $pad -bxor (0xEC -bxor 0x11) }
  $data = New-Object int[] ($capBits / 8)
  for ($i = 0; $i -lt $bits.Count; $i++) { $data[$i -shr 3] = $data[$i -shr 3] -bor ([int]$bits[$i] -shl (7 - ($i -band 7))) }

  # error correction blocks and interleaving
  $numBlocks = $script:QrBlocks[$Ec][$version]
  $eccLen = $script:QrEccPerBlock[$Ec][$version]
  $rawCodewords = [int][Math]::Floor((Get-QrRawDataModules $version) / 8)
  $numShort = $numBlocks - ($rawCodewords % $numBlocks)
  $shortLen = [int][Math]::Floor($rawCodewords / $numBlocks)
  $divisor = Get-QrRsDivisor $eccLen
  $blocks = @()
  $k = 0
  for ($i = 0; $i -lt $numBlocks; $i++) {
    $datLen = $shortLen - $eccLen
    if ($i -ge $numShort) { $datLen++ }
    $dat = New-Object int[] $datLen
    [Array]::Copy($data, $k, $dat, 0, $datLen)
    $k += $datLen
    $ecc = Get-QrRsRemainder $dat $divisor
    $blk = New-Object System.Collections.Generic.List[int]
    $blk.AddRange($dat)
    if ($i -lt $numShort) { $blk.Add(0) }
    $blk.AddRange($ecc)
    $blocks += ,$blk
  }
  $all = New-Object System.Collections.Generic.List[int]
  $allOrigin = New-Object System.Collections.Generic.List[int]   # block * 65536 + position in the block
  for ($i = 0; $i -lt $blocks[0].Count; $i++) {
    for ($j = 0; $j -lt $blocks.Count; $j++) {
      if ($i -ne ($shortLen - $eccLen) -or $j -ge $numShort) { $all.Add($blocks[$j][$i]); $allOrigin.Add($j * 65536 + $i) }
    }
  }

  # function patterns
  $size = $version * 4 + 17
  $dark = New-Object byte[] ($size * $size)
  $isFn = New-Object bool[] ($size * $size)
  $moduleCw = New-Object int[] ($size * $size)
  for ($i = 0; $i -lt $moduleCw.Length; $i++) { $moduleCw[$i] = -1 }
  $setFn = { param($x, $y, $on) $dark[$y * $size + $x] = [byte][int]$on; $isFn[$y * $size + $x] = $true }
  for ($i = 0; $i -lt $size; $i++) {
    & $setFn 6 $i (($i % 2) -eq 0)
    & $setFn $i 6 (($i % 2) -eq 0)
  }
  foreach ($c in @(@(3, 3), @(($size - 4), 3), @(3, ($size - 4)))) {
    for ($dy = -4; $dy -le 4; $dy++) {
      for ($dx = -4; $dx -le 4; $dx++) {
        $xx = $c[0] + $dx; $yy = $c[1] + $dy
        if ($xx -lt 0 -or $xx -ge $size -or $yy -lt 0 -or $yy -ge $size) { continue }
        $dist = [Math]::Max([Math]::Abs($dx), [Math]::Abs($dy))
        & $setFn $xx $yy (($dist -ne 2) -and ($dist -ne 4))
      }
    }
  }
  $ap = Get-QrAlignmentPositions $version
  $na = $ap.Length
  for ($i = 0; $i -lt $na; $i++) {
    for ($j = 0; $j -lt $na; $j++) {
      if (($i -eq 0 -and $j -eq 0) -or ($i -eq 0 -and $j -eq $na - 1) -or ($i -eq $na - 1 -and $j -eq 0)) { continue }
      for ($dy = -2; $dy -le 2; $dy++) {
        for ($dx = -2; $dx -le 2; $dx++) {
          & $setFn ($ap[$i] + $dx) ($ap[$j] + $dy) ([Math]::Max([Math]::Abs($dx), [Math]::Abs($dy)) -ne 1)
        }
      }
    }
  }
  # format area reserved (written after the mask is chosen), version information
  $drawFormat = {
    param($mask)
    $d = ($script:QrEcFormatBits[$Ec] -shl 3) -bor $mask
    $rem = $d
    for ($i = 0; $i -lt 10; $i++) { $rem = ($rem -shl 1) -bxor (($rem -shr 9) * 0x537) }
    $fb = (($d -shl 10) -bor $rem) -bxor 0x5412
    for ($i = 0; $i -le 5; $i++) { & $setFn 8 $i ((($fb -shr $i) -band 1) -ne 0) }
    & $setFn 8 7 ((($fb -shr 6) -band 1) -ne 0)
    & $setFn 8 8 ((($fb -shr 7) -band 1) -ne 0)
    & $setFn 7 8 ((($fb -shr 8) -band 1) -ne 0)
    for ($i = 9; $i -lt 15; $i++) { & $setFn (14 - $i) 8 ((($fb -shr $i) -band 1) -ne 0) }
    for ($i = 0; $i -lt 8; $i++) { & $setFn ($size - 1 - $i) 8 ((($fb -shr $i) -band 1) -ne 0) }
    for ($i = 8; $i -lt 15; $i++) { & $setFn 8 ($size - 15 + $i) ((($fb -shr $i) -band 1) -ne 0) }
    & $setFn 8 ($size - 8) $true
  }
  & $drawFormat 0
  if ($version -ge 7) {
    $rem = $version
    for ($i = 0; $i -lt 12; $i++) { $rem = ($rem -shl 1) -bxor (($rem -shr 11) * 0x1F25) }
    $vb = ($version -shl 12) -bor $rem
    for ($i = 0; $i -lt 18; $i++) {
      $on = ((($vb -shr $i) -band 1) -ne 0)
      $a = $size - 11 + ($i % 3); $b = [int][Math]::Floor($i / 3)
      & $setFn $a $b $on
      & $setFn $b $a $on
    }
  }

  # codewords in the zigzag order
  $bitIdx = 0
  $totalBits = $all.Count * 8
  for ($right = $size - 1; $right -ge 1; $right -= 2) {
    if ($right -eq 6) { $right = 5 }
    $upward = ((($right + 1) -band 2) -eq 0)
    for ($vert = 0; $vert -lt $size; $vert++) {
      if ($upward) { $y = $size - 1 - $vert } else { $y = $vert }
      for ($j = 0; $j -lt 2; $j++) {
        $x = $right - $j
        $idx = $y * $size + $x
        if (-not $isFn[$idx] -and $bitIdx -lt $totalBits) {
          $dark[$idx] = [byte](($all[$bitIdx -shr 3] -shr (7 - ($bitIdx -band 7))) -band 1)
          $moduleCw[$idx] = $allOrigin[$bitIdx -shr 3]
          $bitIdx++
        }
      }
    }
  }

  # mask with the lowest penalty
  $best = -1; $bestScore = [int]::MaxValue; $bestDark = $null
  for ($m = 0; $m -lt 8; $m++) {
    $cand = $dark.Clone()
    for ($y = 0; $y -lt $size; $y++) {
      for ($x = 0; $x -lt $size; $x++) {
        $idx = $y * $size + $x
        if ($isFn[$idx]) { continue }
        switch ($m) {
          0 { $inv = ((($x + $y) % 2) -eq 0) }
          1 { $inv = (($y % 2) -eq 0) }
          2 { $inv = (($x % 3) -eq 0) }
          3 { $inv = ((($x + $y) % 3) -eq 0) }
          4 { $inv = ((([Math]::Floor($x / 3) + [Math]::Floor($y / 2)) % 2) -eq 0) }
          5 { $inv = (((($x * $y) % 2) + (($x * $y) % 3)) -eq 0) }
          6 { $inv = ((((($x * $y) % 2) + (($x * $y) % 3)) % 2) -eq 0) }
          7 { $inv = ((((($x + $y) % 2) + (($x * $y) % 3)) % 2) -eq 0) }
        }
        if ($inv) { $cand[$idx] = [byte](1 - $cand[$idx]) }
      }
    }
    $saveDark = $dark; $dark = $cand
    & $drawFormat $m
    $dark = $saveDark
    $score = Get-QrPenalty $cand $size
    if ($score -lt $bestScore) { $bestScore = $score; $best = $m; $bestDark = $cand }
  }
  return @{ Size = $size; Version = $version; Ec = $Ec; Mask = $best; Dark = $bestDark; DataCodewords = $data.Length; EccPerBlock = $eccLen; Blocks = $numBlocks; ModuleBlockCw = $moduleCw; IsFunction = $isFn }
}

# @brief Penalty score (rules N1..N4 of ISO/IEC 18004); only the choice of the mask depends on it
function Get-QrPenalty([byte[]]$Dark, [int]$Size) {
  $score = 0
  $lines = New-Object System.Collections.Generic.List[string]
  $sbRow = New-Object System.Text.StringBuilder
  for ($y = 0; $y -lt $Size; $y++) {
    [void]$sbRow.Clear()
    for ($x = 0; $x -lt $Size; $x++) { [void]$sbRow.Append([char](48 + $Dark[$y * $Size + $x])) }
    $lines.Add($sbRow.ToString())
  }
  for ($x = 0; $x -lt $Size; $x++) {
    [void]$sbRow.Clear()
    for ($y = 0; $y -lt $Size; $y++) { [void]$sbRow.Append([char](48 + $Dark[$y * $Size + $x])) }
    $lines.Add($sbRow.ToString())
  }
  foreach ($l in $lines) {
    foreach ($mt in [regex]::Matches($l, '0{5,}|1{5,}')) { $score += 3 + ($mt.Length - 5) }
    foreach ($pat in @('10111010000', '00001011101')) {
      $at = $l.IndexOf($pat)
      while ($at -ge 0) { $score += 40; $at = $l.IndexOf($pat, $at + 1) }
    }
  }
  for ($y = 0; $y -lt $Size - 1; $y++) {
    for ($x = 0; $x -lt $Size - 1; $x++) {
      $c = $Dark[$y * $Size + $x]
      if ($c -eq $Dark[$y * $Size + $x + 1] -and $c -eq $Dark[($y + 1) * $Size + $x] -and $c -eq $Dark[($y + 1) * $Size + $x + 1]) { $score += 3 }
    }
  }
  $darkCount = 0
  foreach ($b in $Dark) { $darkCount += $b }
  $total = $Size * $Size
  $k = [int][Math]::Ceiling([Math]::Abs($darkCount * 20 - $total * 10) / $total) - 1
  if ($k -gt 0) { $score += $k * 10 }
  return $score
}
