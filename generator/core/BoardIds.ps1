#Requires -Version 5.1
<#
Open =
-----+  BoardIds
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/BoardIds.ps1

.SYNOPSIS
    Board identity (DEVICE_HW_ID, DEVICE_ID, DEVICE_NAME) and the -ListIds / -NextId modes.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Get-AllHardwareIdBoards, Get-BoardIdentity, Invoke-ListIds, Invoke-NextId.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# ------------------------------------------------------------------------------------------------
# Board discovery (all boards with DEVICE_HW_ID in OGM-HardwareConfig)
# ------------------------------------------------------------------------------------------------
function Get-AllHardwareIdBoards {
  $root = [System.IO.Path]::Combine($script:HwInclude, "HardwareConfig")
  $boards = New-Object System.Collections.Generic.List[string]
  foreach ($f in (Get-ChildItem -Path $root -Recurse -Filter "*.h")) {
    $lastGuard = $null
    foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
      if ($line -match '^\s*#\s*(ifdef|(el)?if\s+defined\s*\(?)\s*((DEVICE|OKNXHW|BOARD)_[A-Za-z0-9_]+)') { $lastGuard = $Matches[3] }
      elseif ($line -match '^\s*#\s*define\s+DEVICE_HW_ID\s') {
        if ($lastGuard -and -not $boards.Contains($lastGuard)) { $boards.Add($lastGuard) }
      }
    }
  }
  return $boards
}
function Get-BoardIdentity([string]$Board, [string[]]$Defines) {
  if (-not $Defines) { $Defines = @($Board) }
  $src = "#include `"HardwareConfig.h`"`n" +
    "#ifdef DEVICE_HW_ID`n@@ `"HWID`" DEVICE_HW_ID`n#endif`n" +
    "#ifdef DEVICE_ID`n@@ `"ID`" DEVICE_ID`n#endif`n" +
    "#ifdef DEVICE_NAME`n@@ `"NAME`" DEVICE_NAME`n#endif`n" +
    "#ifdef HW_INFO_TEXT`n@@ `"INFOTEXT`" HW_INFO_TEXT`n#endif`n"
  $lines = Invoke-Preprocessor -Source $src -Defines $Defines
  $r = @{ Board = $Board; HwId = $null; Id = $null; Name = $null; Errors = @() }
  foreach ($l in $lines) {
    if ($l -match '^@@ "(\w+)" (.*)$') {
      $key = $Matches[1]; $val = $Matches[2]
      if ($key -eq "HWID") {
        $r.HwId = ConvertFrom-CInteger $val
        if ($null -eq $r.HwId) { $r.Errors += "DEVICE_HW_ID is not an integer: $val" }
      } else {
        $s = ConvertFrom-CString $val
        $macro = "DEVICE_$key"
        if ($key -eq "INFOTEXT") { $macro = "HW_INFO_TEXT" }
        if ($null -eq $s) { $r.Errors += "$macro does not resolve to a string: $val" }
        elseif ($key -eq "ID") { $r.Id = $s }
        elseif ($key -eq "INFOTEXT") { if ($s.Length -gt 255) { $r.Errors += ("HW_INFO_TEXT has {0} characters, ETS shows at most 255" -f $s.Length) } }
        else { $r.Name = $s }
      }
    }
  }
  # header rules (README "Hardware-ID"): a board with an ID has a DEVICE_ID of a-z A-Z 0-9 _ - and a DEVICE_NAME
  if ($null -ne $r.HwId) {
    if (-not $r.Id) { $r.Errors += "DEVICE_ID is missing" }
    elseif ($r.Id -notmatch '^[A-Za-z0-9_-]+$') { $r.Errors += ("DEVICE_ID '{0}' has characters outside a-z A-Z 0-9 _ -" -f $r.Id) }
    if (-not $r.Name) { $r.Errors += "DEVICE_NAME is missing" }
  }
  return $r
}
# ------------------------------------------------------------------------------------------------
# Mode: -ListIds
# ------------------------------------------------------------------------------------------------
function Invoke-ListIds {
  $boards = Get-AllHardwareIdBoards
  $rows = @()
  foreach ($b in $boards) { $rows += (Get-BoardIdentity $b) }
  $rows = $rows | Sort-Object { $_.HwId }
  $fail = $false
  if ($Markdown) {
    Write-Output "| HW-ID | Board define | DEVICE_ID | DEVICE_NAME |"
    Write-Output "|---|---|---|---|"
  }
  foreach ($r in $rows) {
    $idText = "-"
    if ($null -ne $r.HwId) { $idText = "0x{0:X4}" -f $r.HwId }
    if ($Markdown) { Write-Output ("| {0} | {1} | {2} | {3} |" -f $idText, $r.Board, $r.Id, $r.Name) }
    else { Write-Output ("{0}  {1,-44} {2,-30} {3}" -f $idText, $r.Board, $r.Id, $r.Name) }
    foreach ($e in $r.Errors) { Write-Warn ("{0}: {1}" -f $r.Board, $e); $fail = $true }
  }
  $dups = $rows | Where-Object { $null -ne $_.HwId } | Group-Object { $_.HwId } | Where-Object { $_.Count -gt 1 }
  foreach ($d in $dups) {
    Write-Warn ("Duplicate DEVICE_HW_ID 0x{0:X4}: {1}" -f [int]$d.Name, (($d.Group | ForEach-Object { $_.Board }) -join ", "))
    $fail = $true
  }
  Write-Host ""
  Write-Host ("  {0} boards with DEVICE_HW_ID, {1} duplicate ID(s)" -f $rows.Count, @($dups).Count)
  if ($fail) { exit 1 }
  exit 0
}
# ------------------------------------------------------------------------------------------------
# Mode: -NextId <group>
# ------------------------------------------------------------------------------------------------
# @brief Next free DEVICE_HW_ID of a group: the ID after the highest used one (an ID is never reused, so a gap left by a
#        removed board stays free); prints it and a board block to start from
function Invoke-NextId {
  $mm = [regex]::Match($NextId.Trim(), '^(0[xX])?([0-9A-Fa-f]{2,3})$')
  if (-not $mm.Success) { Stop-WithError "-NextId: give a group prefix of 2 or 3 hex digits, e.g. 0x21 (0x2100..0x21FF) or 0x213 (0x2130..0x213F)" }
  $digits = $mm.Groups[2].Value
  $shift = 4 * (4 - $digits.Length)
  $low = [Convert]::ToInt32($digits, 16) -shl $shift
  $high = $low + (1 -shl $shift) - 1
  if ($high -gt 0xFFFE) { $high = 0xFFFE } # 0xFFFF is no valid DEVICE_HW_ID
  if ($low -lt 0x1000) { Stop-WithError ("-NextId: 0x{0:X4} is below the main groups (0x1000 OpenKNX, 0x2000 partners, 0x3000 community)" -f $low) }
  $rows = @()
  foreach ($b in (Get-AllHardwareIdBoards)) { $rows += (Get-BoardIdentity $b) }
  $inRange = @($rows | Where-Object { $null -ne $_.HwId -and $_.HwId -ge $low -and $_.HwId -le $high } | Sort-Object { $_.HwId })
  if ($inRange.Count -eq 0) { $next = $low; $after = "none used yet" }
  else {
    $top = $inRange[$inRange.Count - 1]
    $next = $top.HwId + 1
    $after = "after 0x{0:X4} {1}" -f $top.HwId, $top.Name
  }
  if ($next -gt $high) { Stop-WithError ("-NextId: 0x{0:X4}..0x{1:X4} is full (highest 0x{2:X4}) - take the next group" -f $low, $high, $top.HwId) }
  Write-Output ("Next free DEVICE_HW_ID in 0x{0:X4}..0x{1:X4}: 0x{2:X4} ({3}; {4} board(s) in this range)" -f $low, $high, $next, $after, $inRange.Count)
  foreach ($r in $inRange) { Write-Output ("  0x{0:X4}  {1,-44} {2}" -f $r.HwId, $r.Board, $r.Name) }
  Write-Output ""
  Write-Output "#ifdef DEVICE_<MAKER>_<BOARD>"
  Write-Output ("    #define DEVICE_HW_ID 0x{0:X4}" -f $next)
  Write-Output "    #define DEVICE_ID `"<Maker>-<Board>`""
  Write-Output "    #define DEVICE_NAME `"<Maker> <Board>`""
  if ($low -ge 0x2000 -and $low -lt 0x3000) { Write-Output "    #define DEVICE_THIRD_PARTY // only for hardware without OpenKNX support" }
  Write-Output "#endif"
  exit 0
}
