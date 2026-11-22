#Requires -Version 5.1
<#
Open =
-----+  Boards
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Boards.ps1

.SYNOPSIS
    Boards: PlatformIO envs and flags, variant pins, board tables, capabilities/values/pins/ports per board.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Invoke-BoardTablePreprocessor, Get-BoardTableValues, Split-PioFlagLine, ConvertFrom-PioFlagLine, Get-PioBoardJson, Get-PioMcuName, ConvertTo-PioSections, Get-PioCommand, Get-PlatformIOBoards, Get-VariantPinConstants, Resolve-VariantPin, Resolve-Board, Set-BoardMaps.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# @brief Preprocessor run of a <BoardTable>: on a failure stop with the table name, the header and the first compiler error
function Invoke-BoardTablePreprocessor($Table, [string]$Define, [string]$Source, [string[]]$Defines, [switch]$MacroList) {
  try { return (Invoke-Preprocessor -Source $Source -Defines $Defines -MacroList:$MacroList) }
  catch {
    $err = "$($_.Exception.Message)"
    $first = [regex]::Match($err, '\S*:\d+:\d+:\s*(fatal\s+)?error:[^|]*')
    if ($first.Success) { $err = $first.Value.Trim() }
    Stop-WithError (T "{0}: <BoardTable name=`"{1}`">: preprocessing {2} failed: {3}" $Define $Table.Name $Table.HeaderAttr $err)
  }
}
# @brief <BoardTable> values of one env/board: macros of HardwareConfig.h + the table header whose name matches scan,
#        index = group 1, value = the expanded integer; returns index -> value
function Get-BoardTableValues($Table, [string]$Define, [string[]]$Defines) {
  $src = "#include `"HardwareConfig.h`"`n#include `"" + ($Table.Header -replace '\\', '/') + "`"`n"
  $names = @(Invoke-BoardTablePreprocessor $Table $Define $src $Defines -MacroList |
    ForEach-Object { if ("$_" -match '^#define (\w+)') { $Matches[1] } } | Where-Object { $_ -cmatch $Table.Scan })
  $names = @(Get-OrdinalSorted $names -Unique)
  $vals = @{}
  if ($names.Count -eq 0) { return $vals }
  $Table.Found = $true
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append($src)
  for ($i = 0; $i -lt $names.Count; $i++) { [void]$sb.AppendLine("@@ `"BT$i`" " + $names[$i]) }
  $res = @{}
  foreach ($l in (Invoke-BoardTablePreprocessor $Table $Define $sb.ToString() $Defines)) { if ($l -match '^@@ "(\w+)" (.*)$') { $res[$Matches[1]] = $Matches[2] } }
  $seen = @{}
  for ($i = 0; $i -lt $names.Count; $i++) {
    [void]($names[$i] -cmatch $Table.Scan)
    $grp = "$($Matches[1])"
    $idx = $null
    if ($grp -match '^\d{1,4}$') { $idx = [int]$grp }
    if ($null -eq $idx -or $idx -gt 1023) { Stop-WithError (T "{0}: <BoardTable name=`"{1}`">: {2} - group 1 of scan must be an index 0..1023, is '{3}'" $Define $Table.Name $names[$i] $grp) }
    if ($vals.ContainsKey($idx)) { Stop-WithError (T "{0}: <BoardTable name=`"{1}`">: two macros for index {2} ({3}, {4})" $Define $Table.Name $idx $seen[$idx] $names[$i]) }
    $seen[$idx] = $names[$i]
    # strip outer parentheses and casts in any order, e.g. ((uint8_t)1u), (uint8_t)(3); a value outside a cast's range stops
    $vt = "$($res["BT$i"])".Trim()
    $max = [long]2147483647
    $castRx = '^\(\s*(unsigned\s+char|signed\s+char|unsigned\s+short|unsigned\s+int|unsigned\s+long|unsigned|char|short|int|long|u?int(8|16|32|64)_t)\s*\)\s*(.+)$'
    $casts = New-Object System.Collections.Generic.List[string]
    while ($true) {
      if ($vt -match $castRx) {
        $ct = $Matches[1] -replace '\s+', ' '
        $vt = $Matches[3].Trim()
        # plain char is unsigned on ARM/RISC-V and signed on Xtensa: its range depends on the target
        if ($ct -eq 'char') { Stop-WithError (T "{0}: {1}: {2} = '{3}': a plain (char) cast depends on the target, use int8_t or uint8_t" $Define $Table.HeaderAttr $names[$i] $res["BT$i"]) }
        $casts.Add($ct)
        $lim = @{ 'uint8_t' = 255; 'unsigned char' = 255; 'int8_t' = 127; 'signed char' = 127; 'uint16_t' = 65535; 'unsigned short' = 65535; 'int16_t' = 32767; 'short' = 32767 }
        if ($lim.ContainsKey($ct) -and $lim[$ct] -lt $max) { $max = [long]$lim[$ct] }
        continue
      }
      if ($vt -match '^\((.*)\)$') { $vt = $Matches[1].Trim(); continue }
      break
    }
    $v = ConvertFrom-CInteger $vt
    if ($null -eq $v -or $v -lt 0) { Stop-WithError (T "{0}: {1}: {2} = '{3}' does not resolve to an integer 0..2147483647" $Define $Table.HeaderAttr $names[$i] $res["BT$i"]) }
    if ($v -gt $max) { Stop-WithError (T "{0}: {1}: {2} = '{3}': {4} is outside the range of the cast ({5}, 0..{6})" $Define $Table.HeaderAttr $names[$i] $res["BT$i"] $v ($casts -join ', ') $max) }
    $vals[[int]$idx] = [long]$v
  }
  return $vals
}
# ------------------------------------------------------------------------------------------------
# Boards from the PlatformIO envs of the OAM (one source: the envs that are built anyway)
# ------------------------------------------------------------------------------------------------
# '"-DNAME=\"x y\""' / '-D NAME' / '-DNAME=1' -> "NAME=\"x y\"" style define (without -D); $null for other flags
# split one build_flags element like a POSIX shell (PlatformIO/SCons do the same): whitespace separates,
# "..." keeps spaces and turns \" into ", '...' is literal, \x outside quotes is x
function Split-PioFlagLine([string]$Line) {
  $tokens = New-Object System.Collections.Generic.List[string]
  $cur = New-Object System.Text.StringBuilder
  $has = $false; $quote = [char]0
  for ($i = 0; $i -lt $Line.Length; $i++) {
    $c = $Line[$i]
    if ($quote -eq [char]39) {
      if ($c -eq [char]39) { $quote = [char]0 } else { [void]$cur.Append($c) }
      continue
    }
    if ($quote -eq [char]34) {
      if ($c -eq [char]92 -and $i + 1 -lt $Line.Length -and ($Line[$i + 1] -eq [char]34 -or $Line[$i + 1] -eq [char]92)) { $i++; [void]$cur.Append($Line[$i]) }
      elseif ($c -eq [char]34) { $quote = [char]0 }
      else { [void]$cur.Append($c) }
      continue
    }
    if ([char]::IsWhiteSpace($c)) {
      if ($has) { $tokens.Add($cur.ToString()); [void]$cur.Clear(); $has = $false }
      continue
    }
    $has = $true
    if ($c -eq [char]34 -or $c -eq [char]39) { $quote = $c; continue }
    if ($c -eq [char]92 -and $i + 1 -lt $Line.Length) { $i++; [void]$cur.Append($Line[$i]); continue }
    [void]$cur.Append($c)
  }
  if ($quote -ne [char]0) { throw (T "unbalanced quote in build flag: {0}" $Line) }
  if ($has) { $tokens.Add($cur.ToString()) }
  return ,$tokens.ToArray()
}
# one build_flags element -> list of defines "NAME" / "NAME=VALUE" (without -D); other options are ignored
# -Lenient: a flag that cannot be evaluated is left out instead of stopping the run (excluded envs only)
function ConvertFrom-PioFlagLine([string]$Line, [string]$EnvName = "", [switch]$Lenient) {
  $defs = @()
  $tok = Split-PioFlagLine $Line
  for ($i = 0; $i -lt $tok.Count; $i++) {
    $t = $tok[$i]
    if ($t -eq "-D" -and $i + 1 -lt $tok.Count) { $i++; $t = "-D" + $tok[$i] }
    if ($t -cmatch '^-D([A-Za-z_][A-Za-z0-9_]*)(=.*)?$') {
      if ($Matches[2] -and $Matches[2].EndsWith([string][char]92)) {
        # legal for gcc, but as a #define line it would swallow the next line; a dropped define could change a capability
        if ($Lenient) { continue }
        Stop-WithError (T "env {0}: build flag {1} ends with a backslash and cannot be evaluated; leaving it out could change a capability (e.g. a feature flag) - change the flag or leave the env out (<Boards exclude=...>)" $EnvName $t)
      }
      $defs += ($Matches[1] + $Matches[2])
    }
  }
  return ,$defs
}
# @brief Board manifest <id>.json (project boards folder, then the installed platforms), read once per board:
#        Mcu = build.mcu, Memory = build.arduino.memory_type or build.memory_type, Extra = build.extra_flags, Variant = build.variant
function Get-PioBoardJson([string]$BoardId, [string]$ProjectDir) {
  if (-not $BoardId) { return $null }
  if ($null -eq $script:PioBoardJson) { $script:PioBoardJson = @{} }
  if ($script:PioBoardJson.ContainsKey($BoardId)) { return $script:PioBoardJson[$BoardId] }
  $info = $null
  $dirs = @([System.IO.Path]::Combine($ProjectDir, "boards"))
  $plat = [System.IO.Path]::Combine((Get-PioCoreDir), "platforms")
  if (Test-Path -LiteralPath $plat) { $dirs += @(Get-OrdinalSorted @(Get-ChildItem -LiteralPath $plat -Directory) { $_.Name } | ForEach-Object { [System.IO.Path]::Combine($_.FullName, "boards") }) }
  foreach ($d in $dirs) {
    $f = [System.IO.Path]::Combine($d, $BoardId + ".json")
    Add-BoardCacheInput $f
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    try {
      $bj = [System.IO.File]::ReadAllText($f) | ConvertFrom-Json
      if (-not "$($bj.build.mcu)") { continue }
      $memType = ""; if ($bj.build.arduino) { $memType = "$($bj.build.arduino.memory_type)" }
      if (-not $memType) { $memType = "$($bj.build.memory_type)" }
      $info = @{ Mcu = "$($bj.build.mcu)"; Memory = $memType; Extra = "$(@($bj.build.extra_flags) -join ' ')"; Variant = "$($bj.build.variant)" }
      break
    } catch { continue }
  }
  $script:PioBoardJson[$BoardId] = $info
  return $info
}
# @brief Short MCU name of an env (feature line): board_build.mcu, else build.mcu of the board manifest; "" when unknown
function Get-PioMcuName([string]$BoardId, [string]$Mcu, [string]$ProjectDir) {
  if (-not $Mcu -and $BoardId) {
    $bj = Get-PioBoardJson $BoardId $ProjectDir
    if ($bj) { $Mcu = $bj.Mcu }
    else {
      if ($null -eq $script:PioMcuWarned) { $script:PioMcuWarned = @{} }
      if (-not $script:PioMcuWarned.ContainsKey($BoardId)) {
        $script:PioMcuWarned[$BoardId] = $true
        Write-Warn (T "PlatformIO board {0}: no board manifest with build.mcu found - no MCU: default preprocessor, no framework defines" $BoardId)
      }
    }
  }
  if (-not $Mcu) { return "" }
  $map = @{ rp2040 = "RP2040"; rp2350 = "RP2350"; esp32 = "ESP32"; esp32s2 = "ESP32-S2"; esp32s3 = "ESP32-S3"; esp32c3 = "ESP32-C3"
            esp32c5 = "ESP32-C5"; esp32c6 = "ESP32-C6"; esp32h2 = "ESP32-H2"; esp32p4 = "ESP32-P4" }
  $k = $Mcu.ToLowerInvariant()
  if ($map.ContainsKey($k)) { return $map[$k] }
  return $Mcu.ToUpperInvariant()
}
# @brief Sections [name, items] of "pio project config --json-output", independent of the PowerShell version:
# Windows PowerShell 5.1 passes the top-level array on as one object, pwsh 7 enumerates it (one section: [name, items])
function ConvertTo-PioSections($Parsed) {
  if ($null -eq $Parsed) { return , @() }
  if ($Parsed -is [array] -and $Parsed.Count -eq 2 -and $Parsed[0] -is [string]) { return , @(, $Parsed) }
  return , @($Parsed)
}
# @brief Path of the PlatformIO command (PATH, else the virtual environment of PlatformIO IDE); stops without one
function Get-PioCommand {
  if ($script:PioCommand) { return $script:PioCommand }
  $pio = Get-Command "pio" -ErrorAction SilentlyContinue
  if (-not $pio) { $pio = Get-Command "platformio" -ErrorAction SilentlyContinue }
  if (-not $pio) {
    # PlatformIO IDE installs pio into its own virtual environment, often not in PATH
    foreach ($cand in @("Scripts\pio.exe", "bin/pio")) {
      $pp = [System.IO.Path]::Combine((Get-PioCoreDir), "penv", $cand)
      if (Test-Path -LiteralPath $pp -PathType Leaf) { $pio = Get-Command $pp -ErrorAction SilentlyContinue; break }
    }
  }
  if (-not $pio) { Stop-WithError (T "<Boards platformio=...> needs PlatformIO: pio in PATH or in <PLATFORMIO_CORE_DIR or ~/.platformio>/penv") }
  $script:PioCommand = $pio.Source
  return $script:PioCommand
}
function Get-PlatformIOBoards($M, [string]$EnvPattern, [string]$ProjectDir, [string[]]$Exclude = @()) {
  Write-Activity (T "Read the PlatformIO envs (pio project config) ...")
  $cfg = ConvertTo-PioSections ((Get-PioProjectConfigText $ProjectDir (Get-PioCommand)) | ConvertFrom-Json)
  $result = @()
  $envTotal = @($cfg | Where-Object { ([string]$_[0]).StartsWith("env:") -and ([string]$_[0]).Substring(4) -like $EnvPattern }).Count
  $envIndex = 0
  foreach ($sec in $cfg) {
    $name = [string]$sec[0]
    if (-not $name.StartsWith("env:")) { continue }
    $envName = $name.Substring(4)
    if ($envName -notlike $EnvPattern) { continue }
    $envIndex++
    Write-Activity (T "Env {0}/{1}  {2}" $envIndex $envTotal $envName)
    $excluded = (@($Exclude | Where-Object { $envName -like $_ }).Count -gt 0)
    $defs = @()
    $pioBoard = ""; $pioMcu = ""; $pioMemory = ""; $pioMemoryArduino = ""; $pioVariant = ""; $pioExtra = $null; $flagText = ""
    foreach ($kv in $sec[1]) {
      if ([string]$kv[0] -eq "board") { $pioBoard = [string]$kv[1] }
      if ([string]$kv[0] -eq "board_build.mcu") { $pioMcu = [string]$kv[1] }
      # memory type as the espressif32 platform reads it: board_build.memory_type, else board_build.arduino.memory_type
      if ([string]$kv[0] -eq "board_build.memory_type") { $pioMemory = [string]$kv[1] }
      if ([string]$kv[0] -eq "board_build.arduino.memory_type") { $pioMemoryArduino = [string]$kv[1] }
      if ([string]$kv[0] -eq "board_build.variant") { $pioVariant = [string]$kv[1] }
      if ([string]$kv[0] -eq "board_build.extra_flags") { $pioExtra = "$(@($kv[1]) -join ' ')" }
      if ([string]$kv[0] -eq "build_flags") { $flagText += " " + "$(@($kv[1]) -join ' ')" }
      if ([string]$kv[0] -ne "build_flags") { continue }
      foreach ($fl in @($kv[1])) {
        # the function returns ONE array object; @() around the call would nest it
        try { $defs += (ConvertFrom-PioFlagLine ([string]$fl) $envName -Lenient:$excluded) }
        catch {
          # the broken line of an excluded env is ignored unless a board define may be on it
          if ($excluded) {
            $parseError = $_.Exception.Message
            if ($null -eq $script:KnownBoards) { $script:KnownBoards = @(Get-AllHardwareIdBoards) }
            # defined names of the line: "-DNAME", "-D NAME", "-D"NAME""
            $words = @([regex]::Matches([string]$fl, '-D\s*["'']?([A-Za-z_][A-Za-z0-9_]*)') | ForEach-Object { $_.Groups[1].Value })
            $otherDefs = @($defs | Where-Object { $script:KnownBoards -notcontains $_ })
            $hit = @($words | Where-Object { $script:KnownBoards -contains $_ })
            if ($hit.Count -eq 0) {
              # alias define: a board only when it resolves to a DEVICE_HW_ID
              foreach ($cd in @($words | Where-Object { $_ -match '^(DEVICE|OKNXHW)_' })) {
                try { if ($null -ne (Get-BoardIdentity $cd (@($cd) + $otherDefs)).HwId) { $hit += $cd } } catch { }
              }
            }
            if ($hit.Count -gt 0) {
              Stop-OnSkip (T "env {0}: excluded by <Boards exclude=...>, but build_flags line '{1}' cannot be parsed ({2}) and names {3}" $envName $fl $parseError ($hit -join ", "))
            }
            continue
          }
          Stop-WithError (T "env {0}: build_flags line '{1}' cannot be parsed ({2}); leaving its defines out could change a capability - fix the line or leave the env out (<Boards exclude=...>)" $envName $fl $_.Exception.Message)
        }
      }
    }
    # the board is the define of a header block with DEVICE_HW_ID (not a build flag like DEVICE_DISPLAY_MODULE);
    # an alias define is accepted when the env resolves to an ID
    if ($null -eq $script:KnownBoards) { $script:KnownBoards = @(Get-AllHardwareIdBoards) }
    $plain = @($defs | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*$' })
    $known = @($plain | Where-Object { $script:KnownBoards -contains $_ })
    if ($excluded) {
      # exclude is for envs that build no board; an excluded board is a board left out
      $exBoard = $known | Select-Object -First 1
      if (-not $exBoard) {
        $cands = @($plain | Where-Object { $_ -match '^(DEVICE|OKNXHW)_' })
        $rest = @($defs | Where-Object { $cands -notcontains $_ })
        foreach ($cd in $cands) {
          try { if ($null -ne (Get-BoardIdentity $cd (@($cd) + $rest)).HwId) { $exBoard = $cd; break } } catch { }
        }
      }
      if ($exBoard) { Stop-OnSkip (T "env {0}: excluded by <Boards exclude=...>, but it builds board {1}" $envName $exBoard) }
      continue
    }
    if ($known.Count -gt 1) { Stop-OnSkip (T "env {0}: two boards ({1})" $envName ($known -join ", ")); continue }
    $board = $known | Select-Object -First 1
    if (-not $board) {
      # alias define: test each candidate on its own with the
      # env's other defines, so a build flag like DEVICE_DISPLAY_MODULE never becomes the board
      $cands = @($plain | Where-Object { $_ -match '^(DEVICE|OKNXHW)_' })
      $rest = @($defs | Where-Object { $cands -notcontains $_ })
      $hits = @($cands | Where-Object { $null -ne (Get-BoardIdentity $_ (@($_) + $rest)).HwId })
      if ($hits.Count -gt 1) { Stop-OnSkip (T "env {0}: two boards ({1})" $envName ($hits -join ", ")); continue }
      $board = $hits | Select-Object -First 1
    }
    if (-not $board) { $script:NoBoardEnvs += $envName; if ($script:InitMode) { continue } }
    if (-not $board) { Stop-OnSkip (T "env {0}: no board with DEVICE_HW_ID among its defines; an env that builds no board (e.g. a test env) is left out with <Boards platformio=`"{1}`" exclude=`"<pattern> ...`" />" $envName $EnvPattern); continue }
    # the env as a whole must resolve to this board's own ID; another board (e.g. an alias define next to a
    # known one) would give a mix of two boards
    if ($null -eq $script:BoardIdCache) { $script:BoardIdCache = @{} }
    if (-not $script:BoardIdCache.ContainsKey($board)) { $script:BoardIdCache[$board] = (Get-BoardIdentity $board @($board)).HwId }
    $envId = (Get-BoardIdentity $board $defs).HwId
    $ownId = $script:BoardIdCache[$board]
    if ($known.Count -eq 1 -and $envId -ne $ownId) {
      Stop-OnSkip (T "env {0}: resolves to 0x{1:X4}, but its board {2} is 0x{3:X4} - a second board define?" $envName ([int]$envId) $board ([int]$ownId))
      continue
    }
    $flags = @($defs | Where-Object { $_ -ne $board } | ForEach-Object { "-D" + $_ })
    $mcuName = Get-PioMcuName $pioBoard $pioMcu $ProjectDir
    # chip GPIOs: memory type and BOARD_HAS_PSRAM of the env, else of the board manifest (board_build.extra_flags replaces its
    # flags); the manifest is read also when the env sets board_build.mcu
    $bInfo = Get-PioBoardJson $pioBoard $ProjectDir
    if (-not $pioMemory) { $pioMemory = $pioMemoryArduino }
    if (-not $pioMemory -and $bInfo) { $pioMemory = $bInfo.Memory }
    if (-not $pioVariant -and $bInfo) { $pioVariant = $bInfo.Variant }
    if ($null -eq $pioExtra) { $pioExtra = ""; if ($bInfo) { $pioExtra = $bInfo.Extra } }
    $psram = (($pioExtra + " " + $flagText) -match '-D\s*BOARD_HAS_PSRAM\b') -and -not ($flagText -match '-U\s*BOARD_HAS_PSRAM\b')
    $result += @{ Define = $board; Flags = $flags; Env = $envName; Mcu = $mcuName; Memory = $pioMemory; Psram = $psram; Variant = $pioVariant }
  }
  if ($result.Count -eq 0) { Stop-OnSkip (T "No PlatformIO env matches {0}" $EnvPattern) }
  return $result
}
# @brief Pin constants of the Arduino variant (pins_arduino.h: static const uint8_t D8 = 7;), read once per MCU and variant;
#        board headers use them (PROG_LED_PIN (D8), LED_BUILTIN), the preprocessor cannot resolve them
function Get-VariantPinConstants([string]$Mcu, [string]$Variant) {
  $consts = @{}
  if (-not $Mcu -or -not $Variant) { return $consts }
  $pkg = ""
  if ($Mcu -like "ESP32*") { $pkg = "framework-arduinoespressif32" } elseif ($Mcu -like "RP2*") { $pkg = "framework-arduinopico" }
  if (-not $pkg) { return $consts }
  if ($null -eq $script:VariantConsts) { $script:VariantConsts = @{} }
  $key = "$pkg|$Variant"
  if ($script:VariantConsts.ContainsKey($key)) { return $script:VariantConsts[$key] }
  $f = [System.IO.Path]::Combine((Get-PioCoreDir), "packages", $pkg, "variants", $Variant, "pins_arduino.h")
  Add-BoardCacheInput $f
  if (Test-Path -LiteralPath $f -PathType Leaf) {
    foreach ($l in [System.IO.File]::ReadAllLines($f)) {
      if ($l -match '^\s*static\s+const\s+(?:uint8_t|int|uint16_t|unsigned\s+int)\s+(\w+)\s*=\s*(0[xX][0-9a-fA-F]+|\d+)\s*;') {
        $consts[$Matches[1]] = $Matches[2]
      }
    }
  }
  $script:VariantConsts[$key] = $consts
  return $consts
}
# @brief A pin value that is a variant constant (D8, LED_BUILTIN, also in parentheses) -> its number; anything else unchanged
function Resolve-VariantPin([string]$Text, [hashtable]$Consts) {
  $t = $Text.Trim()
  while ($t -match '^\((.*)\)$') { $t = $Matches[1].Trim() }
  if ($Consts.ContainsKey($t)) { return $Consts[$t] }
  return $Text
}
function Resolve-Board($M, $BoardEntry) {
  # the PlatformIO toolchain and the framework defines of the env's MCU: the board header sees what the firmware sees
  $script:CompilerPath = Get-BoardCompiler "$($BoardEntry.Mcu)"
  $defines = @($BoardEntry.Define) + @($BoardEntry.Flags | ForEach-Object { $_ -replace '^-D', '' }) + @(Get-McuArchDefines "$($BoardEntry.Mcu)")
  $ident = Get-BoardIdentity $BoardEntry.Define $defines   # flags can select another variant (QuinLED WiFi/LAN)
  foreach ($e in $ident.Errors) { Stop-WithError ("{0}: {1}" -f $BoardEntry.Define, $e) }
  if ($null -eq $ident.HwId) { Stop-WithError (T "{0}: no DEVICE_HW_ID - add one to the board header (see generator/README.md)" $BoardEntry.Define) }
  if ($ident.HwId -le 0 -or $ident.HwId -ge 65535) { Stop-WithError (T "{0}: DEVICE_HW_ID out of range" $BoardEntry.Define) }

  # pass 1: macro names of this board (for scan="" pin sources)
  $macroNames = @()
  $needScan = $false
  foreach ($role in $M.Roles) { foreach ($s in $role.Sources) { if ($s.Scan -and (Test-Wildcard $s.Board $BoardEntry.Define)) { $needScan = $true } } }
  if ($needScan) {
    $macroNames = @(Invoke-Preprocessor -Source "#include `"HardwareConfig.h`"`n" -Defines $defines -MacroList |
      ForEach-Object { if ("$_" -match '^#define (\w+)\s') { $Matches[1] } })
    $macroNames = @(Get-OrdinalSorted $macroNames)
  }

  # pass 2: evaluate capabilities, values and pins with the preprocessor
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('#include "HardwareConfig.h"')
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) {
    [void]$sb.AppendLine("#if " + $M.Capabilities[$i].Expr)
    [void]$sb.AppendLine("@@ `"CAP$i`" 1")
    [void]$sb.AppendLine("#else")
    [void]$sb.AppendLine("@@ `"CAP$i`" 0")
    [void]$sb.AppendLine("#endif")
  }
  for ($i = 0; $i -lt $M.Values.Count; $i++) {
    $v = $M.Values[$i]
    if (-not $v.Expr) { [void]$sb.AppendLine("@@ `"VAL$i`" " + $v.Default); continue }
    [void]$sb.AppendLine("#if defined(" + $v.IfDef + ")")
    [void]$sb.AppendLine("@@ `"VAL$i`" " + $v.Expr)
    [void]$sb.AppendLine("#else")
    [void]$sb.AppendLine("@@ `"VAL$i`" " + $v.Default)
    [void]$sb.AppendLine("#endif")
  }
  $pinCandidates = @()
  foreach ($role in $M.Roles) {
    foreach ($s in $role.Sources) {
      if (-not (Test-Wildcard $s.Board $BoardEntry.Define)) { continue }
      if ($s.Scan) {
        foreach ($name in $macroNames) {
          if ($name -match $s.Scan) {
            $label = $s.Label
            for ($g = $Matches.Count - 1; $g -ge 0; $g--) { $label = $label.Replace('$' + $g, $Matches[$g]) }   # $10 before $1
            $pinCandidates += @{ Role = $role.Name; Label = $label; Macro = $name }
          }
        }
      }
      foreach ($p in $s.Pins) { $pinCandidates += @{ Role = $role.Name; Label = $p.Label; Macro = $p.Gpio } }
    }
  }
  for ($i = 0; $i -lt $pinCandidates.Count; $i++) {
    [void]$sb.AppendLine("@@ `"PIN$i`" " + $pinCandidates[$i].Macro)
  }
  for ($i = 0; $i -lt $M.Reserved.Count; $i++) {
    [void]$sb.AppendLine("#ifdef " + $M.Reserved[$i])
    [void]$sb.AppendLine("@@ `"RSV$i`" " + $M.Reserved[$i])
    [void]$sb.AppendLine("#endif")
  }
  [void]$sb.AppendLine("#if " + $SERIAL_LED_INDEX)
  [void]$sb.AppendLine("@@ `"SLEDIDX`" 1")
  [void]$sb.AppendLine("#endif")
  $rsvCheck = ($M.Conflicts -and $M.Conflicts.Reserved)
  if ($rsvCheck) {
    $autoMacros = @($AUTO_RESERVED) + @($TP_RESERVED)
    for ($i = 0; $i -lt $autoMacros.Count; $i++) {
      [void]$sb.AppendLine("#ifdef " + $autoMacros[$i])
      [void]$sb.AppendLine("@@ `"ARSV$i`" " + $autoMacros[$i])
      [void]$sb.AppendLine("#endif")
    }
    [void]$sb.AppendLine("#ifdef MASK_VERSION")
    [void]$sb.AppendLine("@@ `"MASKV`" MASK_VERSION")
    [void]$sb.AppendLine("#endif")
  }
  # port description of the board header: HW_PORT_COUNT, HW_PORT_<n>_GPIO, HW_PORT_<n>_LABEL
  [void]$sb.AppendLine("#ifdef HW_PORT_COUNT")
  [void]$sb.AppendLine("@@ `"PORTCOUNT`" HW_PORT_COUNT")
  [void]$sb.AppendLine("#endif")
  for ($n = 1; $n -le $MAX_PORTS; $n++) {
    [void]$sb.AppendLine(("#if defined(HW_PORT_{0}_GPIO)" -f $n))
    [void]$sb.AppendLine(("@@ `"PORTGPIO{0}`" HW_PORT_{0}_GPIO" -f $n))
    [void]$sb.AppendLine(("#ifdef HW_PORT_{0}_LABEL" -f $n))
    [void]$sb.AppendLine(("@@ `"PORTLABEL{0}`" HW_PORT_{0}_LABEL" -f $n))
    [void]$sb.AppendLine("#endif")
    [void]$sb.AppendLine("#endif")
  }

  # port description of the board header: HW_INPUT_COUNT, HW_INPUT_<n>_GPIO, HW_INPUT_<n>_LABEL
  [void]$sb.AppendLine("#ifdef HW_INPUT_COUNT")
  [void]$sb.AppendLine("@@ `"INPUTCOUNT`" HW_INPUT_COUNT")
  [void]$sb.AppendLine("#endif")
  for ($n = 1; $n -le $MAX_PORTS; $n++) {
    [void]$sb.AppendLine(("#if defined(HW_INPUT_{0}_GPIO)" -f $n))
    [void]$sb.AppendLine(("@@ `"INPUTGPIO{0}`" HW_INPUT_{0}_GPIO" -f $n))
    [void]$sb.AppendLine(("#ifdef HW_INPUT_{0}_LABEL" -f $n))
    [void]$sb.AppendLine(("@@ `"INPUTLABEL{0}`" HW_INPUT_{0}_LABEL" -f $n))
    [void]$sb.AppendLine("#endif")
    [void]$sb.AppendLine("#endif")
    foreach ($field in @("MODE", "ONLEVEL")) {
      [void]$sb.AppendLine(("#ifdef HW_INPUT_{0}_{1}" -f $n, $field))
      [void]$sb.AppendLine(("@@ `"INPUT{1}{0}`" HW_INPUT_{0}_{1}" -f $n, $field))
      [void]$sb.AppendLine("#endif")
    }
  }

  # relay description of the board header: HW_RELAY_COUNT, HW_RELAY_<n>_GPIO, HW_RELAY_<n>_LABEL (hard-wired relays)
  [void]$sb.AppendLine("#ifdef HW_RELAY_COUNT")
  [void]$sb.AppendLine("@@ `"RELAYCOUNT`" HW_RELAY_COUNT")
  [void]$sb.AppendLine("#endif")
  for ($n = 1; $n -le $MAX_RELAYS; $n++) {
    [void]$sb.AppendLine(("#if defined(HW_RELAY_{0}_GPIO)" -f $n))
    [void]$sb.AppendLine(("@@ `"RELAYGPIO{0}`" HW_RELAY_{0}_GPIO" -f $n))
    [void]$sb.AppendLine(("#ifdef HW_RELAY_{0}_LABEL" -f $n))
    [void]$sb.AppendLine(("@@ `"RELAYLABEL{0}`" HW_RELAY_{0}_LABEL" -f $n))
    [void]$sb.AppendLine("#endif")
    [void]$sb.AppendLine("#endif")
  }

  if ($M.Info) {
    [void]$sb.AppendLine("#ifdef " + $M.Info.Define)
    [void]$sb.AppendLine("@@ `"INFOURL`" " + $M.Info.Define)
    [void]$sb.AppendLine("#endif")
  }
  # board description for <Page> (HW_INFO_TEXT, second part HW_INFO_TEXT2) and the device card picture (HW_INFO_LOGO)
  [void]$sb.AppendLine("#ifdef HW_INFO_TEXT")
  [void]$sb.AppendLine("@@ `"INFOTEXT`" HW_INFO_TEXT")
  [void]$sb.AppendLine("#endif")
  [void]$sb.AppendLine("#ifdef HW_INFO_TEXT2")
  [void]$sb.AppendLine("@@ `"INFOTEXT2`" HW_INFO_TEXT2")
  [void]$sb.AppendLine("#endif")
  [void]$sb.AppendLine("#ifdef HW_INFO_LOGO")
  [void]$sb.AppendLine("@@ `"INFOLOGO`" HW_INFO_LOGO")
  [void]$sb.AppendLine("#endif")
  # <PartRows>: condition and label macro of each row; <Fix valueMacro>: the value of the macro
  foreach ($pr in @($M.PartRows)) {
    for ($j = 0; $j -lt $pr.Rows.Count; $j++) {
      $row = $pr.Rows[$j]
      [void]$sb.AppendLine("#if " + $row.Expr)
      [void]$sb.AppendLine(("@@ `"PRC{0}_{1}`" 1" -f $pr.Index, $j))
      [void]$sb.AppendLine("#else")
      [void]$sb.AppendLine(("@@ `"PRC{0}_{1}`" 0" -f $pr.Index, $j))
      [void]$sb.AppendLine("#endif")
      if ($row.Label) {
        [void]$sb.AppendLine("#ifdef " + $row.Label)
        [void]$sb.AppendLine(("@@ `"PRL{0}_{1}`" {2}" -f $pr.Index, $j, $row.Label))
        [void]$sb.AppendLine("#endif")
      }
    }
  }
  if ($M.Fixes) {
    for ($i = 0; $i -lt $M.Fixes.Items.Count; $i++) {
      $fm = $M.Fixes.Items[$i].ValueMacro
      if (-not $fm) { continue }
      [void]$sb.AppendLine("#ifdef " + $fm)
      [void]$sb.AppendLine("@@ `"FXV$i`" " + $fm)
      [void]$sb.AppendLine("#endif")
    }
  }

  $lines = Invoke-Preprocessor -Source $sb.ToString() -Defines $defines
  $res = @{}
  foreach ($l in $lines) { if ($l -match '^@@ "(\w+)" (.*)$') { $res[$Matches[1]] = $Matches[2] } }
  # reserved pin macros may name a pin constant of the Arduino variant (UP1: PROG_LED_PIN (D8))
  $vc = Get-VariantPinConstants "$($BoardEntry.Mcu)" "$($BoardEntry.Variant)"
  if ($vc.Count -gt 0) { foreach ($k in @($res.Keys | Where-Object { $_ -match '^A?RSV\d+$' })) { $res[$k] = Resolve-VariantPin $res[$k] $vc } }

  $board = @{
    Define = $BoardEntry.Define; HwId = $ident.HwId; DeviceId = $ident.Id; Name = $ident.Name
    Caps = @(); CapMask = [uint32]0; Values = @(); ValueSource = @(); Pins = @{}; Slot = -1; CapMixed = @{}; InfoText = $null
    InfoText2 = $null; LogoFile = $null
  }
  if ($res.ContainsKey("INFOTEXT")) {
    $board.InfoText = ConvertFrom-CString $res["INFOTEXT"]
    if (-not $board.InfoText) { Stop-WithError (T "{0}: HW_INFO_TEXT is not a string: {1}" $BoardEntry.Define $res["INFOTEXT"]) }
    if ($board.InfoText.Length -gt 255) { Stop-WithError (T "{0}: HW_INFO_TEXT has {1} characters, ETS shows at most 255" $BoardEntry.Define $board.InfoText.Length) }
  }
  # second part of the board text (one more text element, ETS: 255 characters per text)
  if ($res.ContainsKey("INFOTEXT2")) {
    $board.InfoText2 = ConvertFrom-CString $res["INFOTEXT2"]
    if (-not $board.InfoText2) { Stop-WithError (T "{0}: HW_INFO_TEXT2 is not a string: {1}" $BoardEntry.Define $res["INFOTEXT2"]) }
    if ($board.InfoText2.Length -gt 255) { Stop-WithError (T "{0}: HW_INFO_TEXT2 has {1} characters, ETS shows at most 255" $BoardEntry.Define $board.InfoText2.Length) }
  }
  # picture of the device card: a path relative to an include folder of the generator (<IncludePath> first, then the
  # OGM-HardwareConfig include folder), first match wins
  if ($res.ContainsKey("INFOLOGO")) {
    $rel = ConvertFrom-CString $res["INFOLOGO"]
    if (-not $rel) { Stop-WithError (T "{0}: HW_INFO_LOGO is not a string: {1}" $BoardEntry.Define $res["INFOLOGO"]) }
    foreach ($inc in @($script:IncludeDirs)) {
      $cand = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($inc, ($rel -replace '\\', '/')))
      if (Test-Path -LiteralPath $cand -PathType Leaf) { $board.LogoFile = $cand; break }
    }
    if (-not $board.LogoFile) { Stop-WithError (T "{0}: HW_INFO_LOGO {1} not found in the include folders ({2})" $BoardEntry.Define $rel (@($script:IncludeDirs) -join ", ")) }
  }
  # <PartRows>: "<part>/<row>" -> On (the board shows the row), Label (text of the label macro, "" = none)
  $board.PartRows = @{}
  foreach ($pr in @($M.PartRows)) {
    for ($j = 0; $j -lt $pr.Rows.Count; $j++) {
      $row = $pr.Rows[$j]
      $key = "{0}/{1}" -f $pr.Index, $j
      $on = ($res[("PRC{0}_{1}" -f $pr.Index, $j)] -eq "1")
      $lbl = ""
      $lk = "PRL{0}_{1}" -f $pr.Index, $j
      if ($on -and $res.ContainsKey($lk)) {
        $lbl = ConvertFrom-CString $res[$lk]
        if (-not $lbl) { Stop-WithError (T "{0}: {1} is not a string or empty: {2}" $BoardEntry.Define $row.Label $res[$lk]) }
        if ($lbl.Length -gt $PART_ROW_LABEL_MAX) { Stop-WithError (T "{0}: {1} has {2} characters, a row label has at most {3}" $BoardEntry.Define $row.Label $lbl.Length $PART_ROW_LABEL_MAX) }
        if ($lbl -match '[\x00-\x1F%]') { Stop-WithError (T "{0}: {1} contains a control character or %: {2}" $BoardEntry.Define $row.Label $res[$lk]) }
      }
      $board.PartRows[$key] = @{ On = $on; Label = $lbl }
    }
  }
  # <Fix valueMacro>: fix name -> integer value of the macro on this board (absent = the macro is not defined)
  $board.FixValues = @{}
  if ($M.Fixes) {
    for ($i = 0; $i -lt $M.Fixes.Items.Count; $i++) {
      $fx = $M.Fixes.Items[$i]
      if (-not $fx.ValueMacro -or -not $res.ContainsKey("FXV$i")) { continue }
      $fv = ConvertFrom-CInteger $res["FXV$i"]
      if ($null -eq $fv -or $fv -lt 0) { Stop-WithError (T "{0}: <Fix name=`"{1}`">: {2} does not resolve to an integer 0..2147483647: {3}" $BoardEntry.Define $fx.Name $fx.ValueMacro $res["FXV$i"]) }
      $board.FixValues[$fx.Name] = [int]$fv
    }
  }
  $board.InfoUrl = $null
  $board.InfoUrlOwn = $false   # $true: the URL comes from the board header, not the <InfoImage default> (empty = no QR code)
  if ($M.Info) {
    $board.InfoUrl = $M.Info.Default
    if ($res.ContainsKey("INFOURL")) {
      $board.InfoUrlOwn = $true
      $board.InfoUrl = ConvertFrom-CString $res["INFOURL"]
      if (-not $board.InfoUrl) { Stop-WithError (T "{0}: {1} is not a string: {2}" $BoardEntry.Define $M.Info.Define $res["INFOURL"]) }
    }
  }
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) {
    $on = ($res["CAP$i"] -eq "1")
    $board.Caps += $on
    if ($on) { $board.CapMask = $board.CapMask -bor ([uint32]1 -shl $i) }
  }
  for ($i = 0; $i -lt $M.Values.Count; $i++) {
    $n = ConvertFrom-CInteger $res["VAL$i"]
    if ($null -eq $n) { Stop-WithError (T "{0}: value {1} is not an integer: {2}" $BoardEntry.Define ($M.Values[$i].Name) $res["VAL$i"]) }
    $sets = @($M.Values[$i].Sets | Where-Object { Test-Wildcard $_.Board $BoardEntry.Define })
    if ($sets.Count -gt 0) {
      $exact = @($sets | Where-Object { -not $_.Pattern })
      if ($exact.Count -gt 0) { $sets = $exact }
      if ($sets.Count -gt 1) { Stop-WithError (T "{0}: value {1} is set by {2} <Set> entries ({3})" $BoardEntry.Define ($M.Values[$i].Name) $sets.Count (($sets | ForEach-Object { $_.Board }) -join ", ")) }
      $n = $sets[0].Value
      $board.ValueSource += ("<Set board=`"{0}`">" -f $sets[0].Board)
    }
    else { $board.ValueSource += $M.Values[$i].Expr }
    if ($n -lt 0 -or $n -gt 255) { Stop-WithError (T "{0}: value {1} = {2} does not fit one byte" $BoardEntry.Define ($M.Values[$i].Name) $n) }
    # the feature flags (_GE_n / _EQ_n) and the value lists cover 0..max only
    if ($n -gt $M.Values[$i].Max) { Stop-WithError (T "{0}: value {1} = {2} is above max=`"{3}`" of the manifest - raise max" $BoardEntry.Define ($M.Values[$i].Name) $n ($M.Values[$i].Max)) }
    $board.Values += $n
  }
  # pins the platform already uses (KNX UART, prog button/LED, ...) are never offered; the LED macros of the serial LED auto
  # config are chain indices, no GPIOs
  $ledIndex = $res.ContainsKey("SLEDIDX")
  $isLedIndex = { param([string]$Mac) return ($ledIndex -and $LED_INDEX_MACROS -ccontains $Mac) }
  $reservedGpio = @{}
  for ($i = 0; $i -lt $M.Reserved.Count; $i++) {
    if (& $isLedIndex $M.Reserved[$i]) { continue }
    if ($res.ContainsKey("RSV$i")) {
      $rg = ConvertFrom-CInteger $res["RSV$i"]
      if ($null -ne $rg -and $rg -ge 0) { $reservedGpio[$rg] = $M.Reserved[$i] }
    }
  }
  # <Conflicts reserved="true">: GPIOs the board uses itself (manifest <ReservedPins>, the automatic pins, the chip GPIOs of
  # its MCU) and the KNX UART pins with the TP state of the env (true / false; $null = no MASK_VERSION, e.g. a <Board> line)
  $board.ReservedGpios = @(); $board.TpGpios = @(); $board.TpStates = @()
  if ($rsvCheck) {
    $nonInt = @()
    for ($i = 0; $i -lt $M.Reserved.Count; $i++) { if (-not (& $isLedIndex $M.Reserved[$i]) -and $res.ContainsKey("RSV$i") -and $null -eq (ConvertFrom-CInteger $res["RSV$i"]) -and -not (Test-CNegative $res["RSV$i"])) { $nonInt += $M.Reserved[$i] } }
    # manifest pins; a KNX UART macro listed there follows the TP rule below like the automatic one
    $own = @()
    for ($i = 0; $i -lt $M.Reserved.Count; $i++) {
      if ($TP_RESERVED -contains $M.Reserved[$i] -or -not $res.ContainsKey("RSV$i") -or (& $isLedIndex $M.Reserved[$i])) { continue }
      $mg = ConvertFrom-CInteger $res["RSV$i"]
      if ($null -ne $mg -and $mg -ge 0 -and $mg -le 254) { $own += $mg }
    }
    for ($i = 0; $i -lt $autoMacros.Count; $i++) {
      if (-not $res.ContainsKey("ARSV$i") -or (& $isLedIndex $autoMacros[$i])) { continue }
      $ag = ConvertFrom-CInteger $res["ARSV$i"]
      if ($null -eq $ag) { if (-not (Test-CNegative $res["ARSV$i"])) { $nonInt += $autoMacros[$i] }; continue }
      if ($ag -lt 0 -or $ag -gt 254) { continue }
      if ($TP_RESERVED -contains $autoMacros[$i]) { $board.TpGpios += $ag } else { $own += $ag }
    }
    # the header compares (int)(MACRO): a value the generator cannot read as a number would differ between ETS and firmware
    if ($nonInt.Count -gt 0) { Stop-WithError (T "{0}: <Conflicts reserved>: the reserved pin macro(s) {1} do not resolve to an integer" $BoardEntry.Define ((Get-OrdinalSorted $nonInt -Unique) -join ", ")) }
    $chip = $null; if ($BoardEntry.Mcu -and $CHIP_RESERVED.ContainsKey("$($BoardEntry.Mcu)")) { $chip = $CHIP_RESERVED["$($BoardEntry.Mcu)"] }
    if ($chip) {
      $own += $chip.Base
      if ($BoardEntry.Psram) { $own += $chip.Cs1 }
      if ("$($BoardEntry.Memory)" -like "*_opi") { $own += $chip.Octal }
    }
    elseif ("$($BoardEntry.Mcu)" -like "ESP32*") { Write-Warn (T "{0}: <Conflicts reserved>: no flash / PSRAM GPIO table for {1} - the ETS check knows only the pin macros there" $BoardEntry.Define $BoardEntry.Mcu) }
    $board.ReservedGpios = @($own | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    $board.TpGpios = @($board.TpGpios | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    $tp = $null
    if ($res.ContainsKey("MASKV")) { $mv = ConvertFrom-CInteger $res["MASKV"]; if ($null -ne $mv) { $tp = ($TP_MASKS -contains $mv) } }
    $board.TpStates = @(, $tp)
  }
  $board.ReservedSkipped = 0
  foreach ($role in $M.Roles) { $board.Pins[$role.Name] = New-Object System.Collections.Generic.List[object] }
  for ($i = 0; $i -lt $pinCandidates.Count; $i++) {
    $c = $pinCandidates[$i]
    $gpio = ConvertFrom-CInteger $res["PIN$i"]
    if ($null -eq $gpio) { Write-Warn (T "{0}: pin {1} ({2}) does not resolve to a GPIO number: {3}" $BoardEntry.Define $c.Label $c.Macro $res["PIN$i"]); continue }
    if ($gpio -lt 0 -or $gpio -ge $PIN_UNUSED) { Write-Warn (T "{0}: pin {1} = {2} skipped (no GPIO)" $BoardEntry.Define $c.Label $gpio); continue }
    if ($reservedGpio.ContainsKey($gpio)) { $board.ReservedSkipped++; continue }
    $list = $board.Pins[$c.Role]
    if (@($list | Where-Object { $_.Gpio -eq $gpio }).Count -gt 0) { continue }
    $list.Add(@{ Gpio = $gpio; Label = $c.Label })
  }
  foreach ($role in $M.Roles) {
    $sorted = @(Get-OrdinalSorted $board.Pins[$role.Name] { [regex]::Replace($_.Label, '\d+', { param($mt) $mt.Value.PadLeft(5, '0') }) })
    $board.Pins[$role.Name] = $sorted
  }
  # ports: n = 1..HW_PORT_COUNT, only the ones with HW_PORT_<n>_GPIO, in header order
  $board.PortCount = 0
  $board.Ports = New-Object System.Collections.Generic.List[object]
  if ($res.ContainsKey("PORTCOUNT")) {
    $pc = ConvertFrom-CInteger $res["PORTCOUNT"]
    if ($null -eq $pc) { Stop-WithError (T "{0}: HW_PORT_COUNT is not an integer: {1}" $BoardEntry.Define $res["PORTCOUNT"]) }
    if ($pc -gt $MAX_PORTS) { Stop-WithError (T "{0}: HW_PORT_COUNT {1} is above the supported {2} ports (HW_PORTS_MAX, include/HardwareConfig/Helpers/HardwarePorts.h)" $BoardEntry.Define $pc $MAX_PORTS) }
    $board.PortCount = $pc
  }
  $gap = 0
  for ($n = 1; $n -le $MAX_PORTS; $n++) {
    if (-not $res.ContainsKey("PORTGPIO$n")) { if ($n -le $board.PortCount -and $gap -eq 0) { $gap = $n }; continue }
    if ($n -gt $board.PortCount) {
      Write-Warn (T "{0}: HW_PORT_{1}_GPIO is outside HW_PORT_COUNT ({2}) - not offered" $BoardEntry.Define $n $board.PortCount)
      continue
    }
    # a port value is the list position and the firmware maps value k to HW_PORT_<k+1>: no gaps
    if ($gap -gt 0) { Stop-WithError (T "{0}: HW_PORT_{1}_GPIO is missing but HW_PORT_{2}_GPIO is defined - ports must be numbered without gaps" $BoardEntry.Define $gap $n) }
    $g = ConvertFrom-CInteger $res["PORTGPIO$n"]
    if ($null -eq $g) { Stop-WithError (T "{0}: HW_PORT_{1}_GPIO does not resolve to a GPIO number: {2}" $BoardEntry.Define $n $res["PORTGPIO$n"]) }
    if ($g -lt 0 -or $g -gt 254) { Stop-WithError (T "{0}: HW_PORT_{1}_GPIO is {2}, a GPIO must be 0..254 (255 = none)" $BoardEntry.Define $n $g) }
    $label = "Port $n"
    if ($res.ContainsKey("PORTLABEL$n")) {
      $label = ConvertFrom-CString $res["PORTLABEL$n"]
      if ($null -eq $label) { Stop-WithError (T "{0}: HW_PORT_{1}_LABEL is not a string: {2}" $BoardEntry.Define $n $res["PORTLABEL$n"]) }
    }
    $board.Ports.Add(@{ N = $n; Gpio = $g; Label = $label })
  }
  if ($board.Ports.Count -gt 0 -and $board.PortCount -gt $board.Ports.Count) {
    Write-Warn (T "{0}: HW_PORT_COUNT {1}, but only ports 1..{2} are described" $BoardEntry.Define $board.PortCount $board.Ports.Count)
  }
  # ports: n = 1..HW_INPUT_COUNT, only the ones with HW_INPUT_<n>_GPIO, in header order
  $board.InputCount = 0
  $board.Inputs = New-Object System.Collections.Generic.List[object]
  if ($res.ContainsKey("INPUTCOUNT")) {
    $pc = ConvertFrom-CInteger $res["INPUTCOUNT"]
    if ($null -eq $pc) { Stop-WithError ("{0}: HW_INPUT_COUNT is not an integer: {1}" -f $BoardEntry.Define, $res["INPUTCOUNT"]) }
    if ($pc -gt $MAX_PORTS) { Stop-WithError ("{0}: HW_INPUT_COUNT {1} is above the supported {2} ports (HW_INPUTS_MAX, include/HardwareConfig/Helpers/HardwarePorts.h)" -f $BoardEntry.Define, $pc, $MAX_PORTS) }
    $board.InputCount = $pc
  }
  $gap = 0
  for ($n = 1; $n -le $MAX_PORTS; $n++) {
    if (-not $res.ContainsKey("INPUTGPIO$n")) { if ($n -le $board.InputCount -and $gap -eq 0) { $gap = $n }; continue }
    if ($n -gt $board.InputCount) {
      Write-Warn ("{0}: HW_INPUT_{1}_GPIO is outside HW_INPUT_COUNT ({2}) - not offered" -f $BoardEntry.Define, $n, $board.InputCount)
      continue
    }
    # a port value is the list position and the firmware maps value k to HW_INPUT_<k+1>: no gaps
    if ($gap -gt 0) { Stop-WithError ("{0}: HW_INPUT_{1}_GPIO is missing but HW_INPUT_{2}_GPIO is defined - ports must be numbered without gaps" -f $BoardEntry.Define, $gap, $n) }
    $g = ConvertFrom-CInteger $res["INPUTGPIO$n"]
    if ($null -eq $g) { Stop-WithError ("{0}: HW_INPUT_{1}_GPIO does not resolve to a GPIO number: {2}" -f $BoardEntry.Define, $n, $res["INPUTGPIO$n"]) }
    if ($g -lt 0 -or $g -gt 254) { Stop-WithError ("{0}: HW_INPUT_{1}_GPIO is {2}, a GPIO must be 0..254 (255 = none)" -f $BoardEntry.Define, $n, $g) }
    $label = "Port $n"
    if ($res.ContainsKey("INPUTLABEL$n")) {
      $label = ConvertFrom-CString $res["INPUTLABEL$n"]
      if ($null -eq $label) { Stop-WithError ("{0}: HW_INPUT_{1}_LABEL is not a string: {2}" -f $BoardEntry.Define, $n, $res["INPUTLABEL$n"]) }
    }
    $mode = 1; $on = 0
    if ($res.ContainsKey("INPUTMODE$n")) { $mode = ConvertFrom-CInteger $res["INPUTMODE$n"] }
    if ($res.ContainsKey("INPUTONLEVEL$n")) { $on = ConvertFrom-CInteger $res["INPUTONLEVEL$n"] }
    if ($null -eq $mode -or $mode -lt 0 -or $mode -gt 2 -or $null -eq $on -or $on -lt 0 -or $on -gt 1) { Stop-WithError "Invalid HW_INPUT electrical configuration" }
    $board.Inputs.Add(@{ N = $n; Gpio = $g; Label = $label; Mode = $mode; OnLevel = $on })
  }
  if ($board.Inputs.Count -gt 0 -and $board.InputCount -gt $board.Inputs.Count) {
    Write-Warn ("{0}: HW_INPUT_COUNT {1}, but only ports 1..{2} are described" -f $BoardEntry.Define, $board.InputCount, $board.Inputs.Count)
  }
  # relays 1..HW_RELAY_COUNT, each with HW_RELAY_<n>_GPIO ($b.Relays: N, Gpio, Label); none without HW_RELAY_COUNT
  $board.Relays = New-Object System.Collections.Generic.List[object]
  $rc = 0
  if ($res.ContainsKey("RELAYCOUNT")) {
    $rc = ConvertFrom-CInteger $res["RELAYCOUNT"]
    if ($null -eq $rc -or $rc -lt 0 -or $rc -gt $MAX_RELAYS) { Stop-WithError (T "{0}: HW_RELAY_COUNT must be 0..{1}: {2}" $BoardEntry.Define $MAX_RELAYS $res["RELAYCOUNT"]) }
  }
  for ($n = 1; $n -le $MAX_RELAYS; $n++) {
    if (-not $res.ContainsKey("RELAYGPIO$n")) {
      if ($n -le $rc) { Stop-WithError (T "{0}: HW_RELAY_COUNT {1}, but HW_RELAY_{2}_GPIO is missing" $BoardEntry.Define $rc $n) }
      continue
    }
    if ($n -gt $rc) { Stop-WithError (T "{0}: HW_RELAY_{1}_GPIO is outside HW_RELAY_COUNT ({2})" $BoardEntry.Define $n $rc) }
    $g = ConvertFrom-CInteger $res["RELAYGPIO$n"]
    if ($null -eq $g -or $g -lt 0 -or $g -ge $PIN_UNUSED) { Stop-WithError (T "{0}: HW_RELAY_{1}_GPIO does not resolve to a GPIO number: {2}" $BoardEntry.Define $n $res["RELAYGPIO$n"]) }
    $label = "Relais $n"
    if ($res.ContainsKey("RELAYLABEL$n")) {
      $label = ConvertFrom-CString $res["RELAYLABEL$n"]
      if ($null -eq $label) { Stop-WithError (T "{0}: HW_RELAY_{1}_LABEL is not a string: {2}" $BoardEntry.Define $n $res["RELAYLABEL$n"]) }
    }
    $board.Relays.Add(@{ N = $n; Gpio = $g; Label = $label })
  }
  $board.Relays = $board.Relays.ToArray()
  # <Ports use>: offer only these hardware ports; each port keeps its number N (ETS value N-1)
  $sets = @($M.PortSets | Where-Object { Test-Wildcard $_.Board $BoardEntry.Define })
  if ($sets.Count -gt 1) { Stop-WithError (T "{0}: matched by {1} <Ports> entries ({2}) - one board, one port list" $BoardEntry.Define $sets.Count (($sets | ForEach-Object { $_.Board }) -join ", ")) }
  if ($sets.Count -eq 1) {
    $sets[0].Hits++
    if ($sets[0].Max -gt 0 -and $board.Ports.Count -gt $sets[0].Max) {
      Stop-WithError (T "{0}: describes {1} ports, <Ports board=`"{2}`" max=`"{3}`"> - the product stores ports 1..{3} only" $BoardEntry.Define $board.Ports.Count $sets[0].Board $sets[0].Max)
    }
    if ($sets[0].All) { $sets[0].Use = @($board.Ports | ForEach-Object { $_.N }) }
    foreach ($n in $sets[0].Use) {
      if (@($board.Ports | Where-Object { $_.N -eq $n }).Count -eq 0) { Stop-WithError (T "{0}: <Ports board=`"{1}`"> offers port {2}, the header describes ports 1..{3}" $BoardEntry.Define $sets[0].Board $n $board.Ports.Count) }
    }
    $keep = $sets[0].Use
    $relayGpios = @($board.Relays | ForEach-Object { $_.Gpio })
    $filtered = New-Object System.Collections.Generic.List[object]
    foreach ($pt in $board.Ports) {
      if (-not ($keep -contains $pt.N)) { continue }
      # the port stays a hole: the other ports keep their numbers (ETS value N-1)
      if ($sets[0].ExcludeRelayPins -and ($relayGpios -contains $pt.Gpio)) { continue }
      $filtered.Add($pt)
    }
    $board.Ports = $filtered
  }
  # a plain array: PowerShell 7 fails on @() over a generic list of hashtables ("Argument types do not match")
  $board.Ports = $board.Ports.ToArray()
  $sets = @($M.InputSets | Where-Object { Test-Wildcard $_.Board $BoardEntry.Define })
  if ($sets.Count -gt 1) { Stop-WithError ("{0}: matched by {1} <Inputs> entries ({2}) - one board, one port list" -f $BoardEntry.Define, $sets.Count, (($sets | ForEach-Object { $_.Board }) -join ", ")) }
  if ($sets.Count -eq 1) {
    $sets[0].Hits++
    if ($sets[0].Max -gt 0 -and $board.Inputs.Count -gt $sets[0].Max) {
      Stop-WithError ("{0}: describes {1} ports, <Inputs board=`"{2}`" max=`"{3}`"> - the product stores ports 1..{3} only" -f $BoardEntry.Define, $board.Inputs.Count, $sets[0].Board, $sets[0].Max)
    }
    $keep = $sets[0].Use
    if ($sets[0].All) { $keep = @($board.Inputs | ForEach-Object { $_.N }) }
    foreach ($n in $keep) {
      if (@($board.Inputs | Where-Object { $_.N -eq $n }).Count -eq 0) { Stop-WithError ("{0}: <Inputs board=`"{1}`"> offers port {2}, the header describes ports 1..{3}" -f $BoardEntry.Define, $sets[0].Board, $n, $board.Inputs.Count) }
    }
    $relayGpios = @($board.Relays | ForEach-Object { $_.Gpio })
    $filtered = New-Object System.Collections.Generic.List[object]
    foreach ($pt in $board.Inputs) {
      if (-not ($keep -contains $pt.N)) { continue }
      # the port stays a hole: the other ports keep their numbers (ETS value N-1)
      if ($sets[0].ExcludeRelayPins -and ($relayGpios -contains $pt.Gpio)) { continue }
      $filtered.Add($pt)
    }
    $board.Inputs = $filtered
  }
  # a plain array: PowerShell 7 fails on @() over a generic list of hashtables ("Argument types do not match")
  $board.Inputs = $board.Inputs.ToArray()
  # <BoardTable>: Any / All = index -> value; one env here, merged over the envs of the board later
  if ($M.BoardTables.Count -gt 0) {
    $board.Tables = @{}
    foreach ($t in $M.BoardTables) {
      $tv = Get-BoardTableValues $t $BoardEntry.Define $defines
      $board.Tables[$t.Name] = @{ Any = $tv; All = $tv.Clone() }
    }
  }
  Set-BoardMaps $M $board
  return $board
}
# @brief Name-keyed views for templates: $b.Cap.<Name> (bool), $b.Val.<Name> (int)
function Set-BoardMaps($M, $Board) {
  $Board.Cap = @{}
  $Board.Val = @{}
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) { $Board.Cap[$M.Capabilities[$i].Name] = [bool]$Board.Caps[$i] }
  for ($i = 0; $i -lt $M.Values.Count; $i++) { $Board.Val[$M.Values[$i].Name] = $Board.Values[$i] }
}
