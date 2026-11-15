#Requires -Version 5.1
<#
Open =
-----+  Build-HardwareProfile
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/Build-HardwareProfile.ps1
#>

<#
.SYNOPSIS
    Generates the ETS hardware profile (hardware selection, capabilities, GPIO roles) of an OpenKNX
    application from the board headers of OGM-HardwareConfig.

.DESCRIPTION
    One ETS product, many hardware variants: the product shows only what the selected (or the
    connected) device can do.

    Input:
      - The board headers of OGM-HardwareConfig (DEVICE_HW_ID, DEVICE_NAME, pins, feature defines).
      - A manifest of the application (default: HardwareProfile.xml in the repository root). It names
        the boards, imports capability packs and declares GPIO roles.

    Every capability is a C preprocessor expression. The script evaluates it with the C preprocessor
    for each board, and the generated firmware header evaluates the same expression at compile time.
    ETS and firmware therefore use one definition.

    Output (paths from the manifest):
      - conf   : op:config feature flags for the application XML, e.g. %HWP_CAP_Wifi% = "4896 8480"
      - share  : ETS module (hardware selection, profile overview, detect button, GPIO roles)
      - script : ETS JavaScript (device query via function property, capability check)
      - header : firmware header (own HW-ID, capability bits, values, function property layout; with portManualValue /
                 portNoneValue also signalGpio() / relaySignalGpio() for the port selection)
      - <Conflicts output=...> : ETS parts file of the GPIO conflict check (flags, calculation, Conflict_<name> blocks)

    Every output is optional. <Generate template=... output=...> writes further whole files from templates
    ("Bausteine", helpers/TemplateEngine.ps1; standard ones in generator/templates): ETS XML parts for op:include,
    the ETS script, C headers. Boards carry their ports (HW_PORT_* of the board header), capabilities and
    values; order="hwid" sorts them by DEVICE_HW_ID; the slot file next to the manifest keeps the board numbers.
    <BoardTable name=... header=... scan=...> adds var <Prefix>_table_<name> to the script: per board the integer macros of an
    OAM header (index = group 1 of scan) with the env flags, merged over the envs (any = OR, all = AND).

    -ListIds prints every DEVICE_HW_ID of OGM-HardwareConfig and stops on a duplicate ID. -NextId prints the next free
    DEVICE_HW_ID of a group and a board block to start from.

.PARAMETER Manifest
    Path of the manifest. Default: HardwareProfile.xml in the current folder.

.PARAMETER ListIds
    List all hardware IDs found in OGM-HardwareConfig (no manifest needed) and check for duplicates.

.PARAMETER Markdown
    With -ListIds: print the list as a Markdown table.

.PARAMETER Help
    Show this help (also --help, -h, -?).

.PARAMETER Check
    Render every output and compare it with the file on disk; write nothing. Exit code 1 when an output is out of date
    (e.g. a board header changed and the generator did not run), 0 when all are current. For CI.

.PARAMETER NextId
    Group prefix in hex, 2 or 3 digits (0x21 = 0x2100..0x21FF, 0x213 = 0x2130..0x213F): print the ID after the highest
    one used in that range (an ID is never reused, so gaps stay free) and a board block with it. No manifest needed.

.PARAMETER HardwareConfigInclude
    Include folder of OGM-HardwareConfig. Default: the include folder next to this script.

.PARAMETER Compiler
    C++ compiler used as preprocessor (clang++, g++, arm-none-eabi-g++, xtensa-...-g++).
    Default: per board the PlatformIO toolchain of its MCU; otherwise the first PlatformIO toolchain (ARM first),
    then the first one in PATH (clang++, g++, cpp) that preprocesses C++.

.PARAMETER Init
    Create the manifest (path -Manifest, next to platformio.ini) for an OAM without one: boards of the release_*
    envs, free ModuleType and prefix, standard outputs. Stops if the manifest exists. Run once, review, commit.

.PARAMETER DryRun
    Evaluate and print, write no file.

.PARAMETER Detailed
    Full log (manifest, boards with capabilities and values, every output). Default: one line per board
    ("OK 0x1321  <name>", by HW-ID) and a summary line; warnings and errors are always shown.

.EXAMPLE
    pwsh lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1
    # reads ./HardwareProfile.xml and writes the files named in it

.EXAMPLE
    pwsh lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 -ListIds -Markdown
    # prints the hardware ID table of all boards

.EXAMPLE
    pwsh lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 -NextId 0x25
    # next free DEVICE_HW_ID in 0x2500..0x25FF

.NOTES
    AUTHOR : Erkan Colak
    Requires a C++ compiler for the preprocessor run (PlatformIO brings one).
    Exit code 0 = success, 1 = error.
#>

param(
  [string]$Manifest = "HardwareProfile.xml",
  [switch]$ListIds,
  [string]$NextId = "",
  [switch]$Init,
  [switch]$Markdown,
  [string]$HardwareConfigInclude = "",
  [string]$Compiler = "",
  [switch]$DryRun,
  [switch]$Check,
  [Alias("h")][switch]$Help,
  [switch]$Detailed
)

$ErrorActionPreference = "Stop"
$SCRIPT_VERSION = "0.1"

# ------------------------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------------------------
$NEVER_MATCH = "65535"          # ETS <when test> needs at least one value; no hardware uses 0xFFFF
$PIN_UNUSED = 255               # GPIO role value "not used"
$FP_OBJECT_INDEX = 158          # function property object (OpenKNX common object)
$FP_PROPERTY_ID = 4             # function property id of the hardware profile query
$MAX_CAPABILITIES = 32          # capability bits in the query response
$MAX_VALUES = 4                 # answer 1 status + 2 HW-ID + 4 caps + 4 values = 11 bytes; a TP standard frame carries up to 12
                                # (values with query="false" are ETS only and not part of the answer)
$MAX_PORTS = 64                 # HW_PORT_<n>_GPIO read per board (n = 1..64); HW_PORTS_MAX of include/HardwareConfig/Helpers/HardwarePorts.h wins
$MAX_RELAYS = 8                 # HW_RELAY_<n>_GPIO read per board (n = 1..8)
$MAX_SWITCHES = 8               # on/off parameters of switch="true" capabilities, one bit each in one byte
# <Conflicts reserved="true">: GPIOs every board reserves without a manifest entry, in ETS and in HardwareProfile::isReservedGpio.
# Pins OGM-Common drives itself when the macro is defined (Hardware.cpp, Common.cpp, Led/Manager.cpp, TimerInterrupt.cpp):
$AUTO_RESERVED = @("PROG_BUTTON_PIN", "PROG_LED_PIN", "INFO_LED_PIN", "INFO1_LED_PIN", "INFO2_LED_PIN", "INFO3_LED_PIN",
                   "OPENKNX_SERIALLED_PIN", "FUNC1_BUTTON_PIN", "FUNC2_BUTTON_PIN", "FUNC3_BUTTON_PIN", "SAVE_INTERRUPT_PIN")
# the KNX UART only in a TP build: OGM-Common Hardware.cpp uses it under KNX_HAS_TP, knx config.h sets USE_TP for these masks
$TP_RESERVED = @("KNX_UART_RX_PIN", "KNX_UART_TX_PIN")
$TP_MASKS = @(0x07B0, 0x091A, 0x2920)
# flash / PSRAM bus of the chip (framework-arduinoespressif32-libs 5.5.5, soc/spi_pins.h MSPI_IOMUX_PIN_NUM_*, sdkconfig.h):
# Base = CLK MISO MOSI HD WP CS0; Cs1 = PSRAM chip select, here with BOARD_HAS_PSRAM in the build flags (the firmware header
# counts it with CONFIG_SPIRAM, which the Arduino libs always set; esp32-hal-psram.h clears it only in the lib builder); Octal = D4..D7 DQS with CONFIG_SPIRAM_MODE_OCT / CONFIG_ESPTOOLPY_OCT_FLASH (memory type *_opi)
$CHIP_RESERVED = @{
  "ESP32"    = @{ Base = @(6, 7, 8, 9, 10, 11); Cs1 = @(); Octal = @() }
  "ESP32-S3" = @{ Base = @(27, 28, 29, 30, 31, 32); Cs1 = @(26); Octal = @(33, 34, 35, 36, 37) }
  "ESP32-C3" = @{ Base = @(12, 13, 14, 15, 16, 17); Cs1 = @(); Octal = @() }
  "ESP32-C5" = @{ Base = @(16, 17, 18, 20, 21, 22); Cs1 = @(15); Octal = @() }
  "ESP32-C6" = @{ Base = @(24, 25, 26, 28, 29, 30); Cs1 = @(); Octal = @() }
}

# helpers (dot-sourced): template engine, QR code encoder, PNG reader/writer
. ([System.IO.Path]::Combine($PSScriptRoot, "helpers", "TemplateEngine.ps1"))
. ([System.IO.Path]::Combine($PSScriptRoot, "helpers", "QrCode.ps1"))
. ([System.IO.Path]::Combine($PSScriptRoot, "helpers", "PngImage.ps1"))

# the generator itself, one file per area (dot-sourced: same script scope, constants and $script: state above)
$script:GeneratorDir = $PSScriptRoot
foreach ($corePart in @("Console", "Text", "Toolchain", "BoardIds", "Manifest", "Boards", "Slots", "AppModule", "AppScript",
                        "Conflicts", "Fixes", "Header", "Init")) {
  . ([System.IO.Path]::Combine($PSScriptRoot, "core", $corePart + ".ps1"))
}
Remove-Variable corePart
# @brief Help in the layout of the OpenKNX build scripts; Get-Help shows the full description
function Show-Help {
  Show-OpenKNXLogo ("Build-HardwareProfile " + $SCRIPT_VERSION)
  Write-Host "USAGE:" -ForegroundColor Yellow
  Write-Host "  pwsh lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 [-Manifest <file>] [-Check] [-Detailed] [-DryRun]"
  Write-Host "  pwsh lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 -ListIds [-Markdown] | -NextId <group> | -Init"
  Write-Host ""
  Write-Host "OPTIONS:" -ForegroundColor Yellow
  Write-Host "  -Manifest <file>    Manifest of the application (default: HardwareProfile.xml in the current folder)"
  Write-Host "  -Check              Compare every output with the file on disk, write nothing; exit 1 when one is out of date (CI)"
  Write-Host "  -Detailed           Full log: manifest, boards with capabilities and values, every output (default: summary)"
  Write-Host "  -DryRun             Evaluate and print, write no file"
  Write-Host "  -ListIds            Every DEVICE_HW_ID of OGM-HardwareConfig; stops on a duplicate ID (no manifest needed)"
  Write-Host "  -Markdown           With -ListIds: print a Markdown table"
  Write-Host "  -NextId <group>     Next free DEVICE_HW_ID of a group (0x21 = 0x2100..0x21FF, 0x213 = 0x2130..0x213F)"
  Write-Host "  -Init               Create the manifest for an application without one (boards of the release_* envs)"
  Write-Host "  -Compiler <path>    C++ compiler used as preprocessor (default: PlatformIO toolchain of the board MCU)"
  Write-Host "  -HardwareConfigInclude <dir>  Include folder of OGM-HardwareConfig (default: next to this script)"
  Write-Host "  -Help, -h, --help   Show this help (Get-Help Build-HardwareProfile.ps1 -Detailed: full description)"
  Write-Host ""
  Write-Host "EXAMPLES:" -ForegroundColor Yellow
  $examples = @(
    @("Build-HardwareProfile.ps1", "reads ./HardwareProfile.xml and writes the files named in it"),
    @("Build-HardwareProfile.ps1 -Check", "CI: exit 1 when a generated file is out of date"),
    @("Build-HardwareProfile.ps1 -Detailed", "full log"),
    @("Build-HardwareProfile.ps1 -ListIds -Markdown", "hardware ID table of all boards"),
    @("Build-HardwareProfile.ps1 -NextId 0x25", "next free DEVICE_HW_ID in 0x2500..0x25FF")
  )
  $width = ($examples | ForEach-Object { $_[0].Length } | Measure-Object -Maximum).Maximum
  foreach ($e in $examples) {
    Write-Host ("  " + $e[0].PadRight($width)) -NoNewline -ForegroundColor White
    Write-Host ("  # " + $e[1]) -ForegroundColor DarkGray
  }
  Write-Host ""
}
# help: -Help, -? (PowerShell) and the usual --help / -h / /? (they arrive as the positional Manifest)
if ($Help -or @("--help", "-help", "-h", "/?", "/h", "help", "?") -contains $Manifest) {
  Show-Help
  exit 0
}
$script:Compact = -not ($Detailed -or $ListIds -or $NextId -or $Init -or $DryRun)
$script:CheckMode = [bool]$Check
$script:LastStep = ""
$script:WrittenCount = 0
$script:ActivityShown = $false
$script:ActivityWidth = 79
$script:WrittenFiles = New-Object System.Collections.Generic.List[string]
$script:WarningCount = 0
$script:InitMode = $false
$script:NoBoardEnvs = @()

$script:TempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "oknx-hwprofile-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $script:TempDir | Out-Null

# ------------------------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------------------------
Write-Detail ""
if (-not $script:Compact) { Show-OpenKNXLogo ("Build-HardwareProfile " + $SCRIPT_VERSION) }
Write-Detail ""

try {
  if (-not $HardwareConfigInclude) {
    $HardwareConfigInclude = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..", "include"))
  }
  if (-not (Test-Path ([System.IO.Path]::Combine($HardwareConfigInclude, "HardwareConfig.h")))) {
    Stop-WithError "HardwareConfig.h not found in $HardwareConfigInclude"
  }
  $script:HwInclude = $HardwareConfigInclude
  # the firmware maps port values with include/HardwareConfig/Helpers/HardwarePorts.h: read the same port limit
  $portsHeader = [System.IO.Path]::Combine($HardwareConfigInclude, "HardwareConfig", "Helpers", "HardwarePorts.h")
  if (-not (Test-Path -LiteralPath $portsHeader)) { Stop-WithError "HardwareConfig/Helpers/HardwarePorts.h not found in $HardwareConfigInclude" }
  else {
    $pm = [regex]::Match([System.IO.File]::ReadAllText($portsHeader), '(?m)^[ \t]*#define[ \t]+HW_PORTS_MAX\b(.*)$')
    if ($pm.Success) {
      $pv = [regex]::Match($pm.Groups[1].Value, '^\s*\(?\s*(\d+)\s*\)?\s*(//.*)?\s*$')
      if (-not $pv.Success) { Stop-WithError ("HardwareConfig/Helpers/HardwarePorts.h: HW_PORTS_MAX must be a number: {0}" -f $pm.Groups[1].Value.Trim()) }
      $MAX_PORTS = [int]$pv.Groups[1].Value
    }
  }
  $script:IncludeDirs = @($HardwareConfigInclude)
  $script:DefaultCompiler = Find-Compiler
  $script:CompilerPath = $script:DefaultCompiler
  Write-Step "Preprocessor: $script:CompilerPath"

  # -Check compares the outputs of a regular run; the other modes write or list something else
  if ($script:CheckMode -and ($ListIds -or $NextId -or $Init -or $DryRun)) { Stop-WithError "-Check cannot be combined with -ListIds, -NextId, -Init or -DryRun" }
  if ($ListIds) { Invoke-ListIds }
  if ($NextId) { Invoke-NextId }
  if ($Init) { Invoke-Init }

  $m = Read-Manifest $Manifest
  $script:IncludeDirs = @($m.IncludeDirs) + @($HardwareConfigInclude)
  Write-Step ("Manifest: {0} board(s), {1} capabilities, {2} values, {3} GPIO role(s), unselected={4}" -f $m.Boards.Count, $m.Capabilities.Count, $m.Values.Count, $m.Roles.Count, $m.Unselected)

  # <Board define="OKNXHW_OPENKNXIAO_*"/>: every board of OGM-HardwareConfig with a DEVICE_HW_ID whose
  # define matches - a board added to the headers joins the product without touching the manifest
  # explicit entries first and they win; a pattern only adds boards nobody named; the same board with
  # two different flag sets is ambiguous and stops the run
  $expanded = New-Object System.Collections.Generic.List[object]
  $allBoards = $null
  foreach ($pass in @("explicit", "pattern")) {
    foreach ($be in $m.Boards) {
      $isPattern = ($be.Define -match '[\*\?]')
      if (($pass -eq "explicit") -eq $isPattern) { continue }
      $names = @($be.Define)
      if ($isPattern) {
        if ($null -eq $allBoards) { $allBoards = @(Get-AllHardwareIdBoards) }
        $names = @(Get-OrdinalSorted @($allBoards | Where-Object { $_ -like $be.Define }))
        if ($names.Count -eq 0) { Stop-OnSkip ("No board with DEVICE_HW_ID matches {0}" -f $be.Define) }
      }
      foreach ($n in $names) {
        $prev = @($expanded | Where-Object { $_.Define -eq $n })
        if ($prev.Count -eq 0) { $expanded.Add(@{ Define = $n; Flags = $be.Flags; Explicit = (-not $isPattern) }); continue }
        $norm = { param($f) (Get-OrdinalSorted @($f | ForEach-Object { $_ -replace '^-D', '' })) -join " " }
        $same = ((& $norm $prev[0].Flags) -eq (& $norm $be.Flags))
        if (-not $same -and (-not $isPattern -or -not $prev[0].Explicit)) {
          Stop-WithError ("Board {0} is listed twice with different flags ('{1}' / '{2}')" -f $n, ($prev[0].Flags -join " "), ($be.Flags -join " "))
        }
      }
    }
  }
  foreach ($pat in $m.EnvPatterns) {
    foreach ($eb in (Get-PlatformIOBoards $m $pat.Pattern $pat.Project $pat.Exclude)) {
      $expanded.Add(@{ Define = $eb.Define; Flags = $eb.Flags; Explicit = $false; Env = $eb.Env; Mcu = $eb.Mcu; Memory = $eb.Memory; Psram = $eb.Psram; Variant = $eb.Variant })
    }
  }
  Write-Step ("Boards: {0}" -f $expanded.Count)

  $boards = @()
  $boardIndex = 0
  foreach ($be in $expanded) {
    $boardIndex++
    $boardLabel = $be.Define
    if ($be.Env) { $boardLabel = $be.Env }
    Write-Activity ("Board {0}/{1}  {2}" -f $boardIndex, $expanded.Count, $boardLabel)
    $b = Resolve-Board $m $be
    $script:CompilerPath = $script:DefaultCompiler
    $b.Explicit = $be.Explicit
    $b.Env = $be.Env
    $b.Mcu = "$($be.Mcu)"
    $b.Envs = @()
    if ($be.Env) { $b.Envs = @($be.Env) }
    $capText = @()
    for ($i = 0; $i -lt $m.Capabilities.Count; $i++) { if ($b.Caps[$i]) { $capText += $m.Capabilities[$i].Name } }
    $valText = @()
    for ($i = 0; $i -lt $m.Values.Count; $i++) { $valText += ("{0}={1}" -f $m.Values[$i].Name, $b.Values[$i]) }
    $pinText = @()
    foreach ($role in $m.Roles) { $pinText += ("{0}:{1}" -f $role.Name, @($b.Pins[$role.Name]).Count) }
    if ($b.ReservedSkipped -gt 0) { $pinText += ("({0} reserved pin(s) left out)" -f $b.ReservedSkipped) }
    $envText = ""
    if ($be.Env) { $envText = "  [env:" + $be.Env + "]" }
    Write-Ok ("0x{0:X4} {1}{2}" -f $b.HwId, $b.Name, $envText)
    Write-Detail ("           caps: {0}" -f ($capText -join ", "))
    Write-Detail ("           {0}  {1}" -f ($valText -join " "), ($pinText -join " "))
    $boards += $b
  }

  foreach ($ps in $m.PortSets) { if ($ps.Hits -eq 0) { Write-Warn ("<Ports board=`"{0}`"> matches no board" -f $ps.Board) } }
  foreach ($t in $m.BoardTables) { if (-not $t.Found) { Write-Warn ("<BoardTable name=`"{0}`">: no macro matches {1} on any board" -f $t.Name, $t.Scan) } }

  # several envs build the same board with different flags (e.g. TP and TP+WiFi): one ETS entry with the
  # union of what the builds can do; the device query reports what one device was built with
  foreach ($g in ($boards | Where-Object { $_.Env } | Group-Object { $_.HwId } | Where-Object { $_.Count -gt 1 })) {
    $first = $g.Group[0]
    foreach ($o in @($g.Group | Select-Object -Skip 1)) {
      # one HW-ID, two different devices: a duplicate DEVICE_HW_ID, not two builds of one board
      if ($o.Name -ne $first.Name) { Stop-WithError ("Duplicate DEVICE_HW_ID 0x{0:X4}: {1} ({2}) and {3} ({4})" -f [int]$first.HwId, $first.Name, $first.Env, $o.Name, $o.Env) }
      $portsA = (@($first.Ports) | ForEach-Object { "{0}={1}/{2}" -f $_.N, $_.Gpio, $_.Label }) -join " "
      $portsB = (@($o.Ports) | ForEach-Object { "{0}={1}/{2}" -f $_.N, $_.Gpio, $_.Label }) -join " "
      $relA = (@($first.Relays) | ForEach-Object { "{0}={1}/{2}" -f $_.N, $_.Gpio, $_.Label }) -join " "
      $relB = (@($o.Relays) | ForEach-Object { "{0}={1}/{2}" -f $_.N, $_.Gpio, $_.Label }) -join " "
      if ($relA -cne $relB) { Stop-WithError ("0x{0:X4}: env {1} has other relays than env {2}" -f [int]$first.HwId, $o.Env, $first.Env) }
      if ($o.InfoUrl -ne $first.InfoUrl) { Stop-WithError ("0x{0:X4}: env {1} has another info URL than env {2}" -f [int]$first.HwId, $o.Env, $first.Env) }
      if ($o.InfoText -cne $first.InfoText) { Stop-WithError ("0x{0:X4}: env {1} has another HW_INFO_TEXT than env {2}" -f [int]$first.HwId, $o.Env, $first.Env) }
      if ($o.Mcu -cne $first.Mcu) { Stop-WithError ("0x{0:X4}: env {1} builds for MCU '{2}', env {3} for '{4}'" -f [int]$first.HwId, $o.Env, $o.Mcu, $first.Env, $first.Mcu) }
      # one port list per HW-ID: ETS offers one list for every firmware of the board
      if ($portsA -cne $portsB -or $first.PortCount -ne $o.PortCount) { Stop-WithError ("0x{0:X4}: env {1} has other ports than env {2} (HW_PORT_*) - the ports of a board must not depend on the env" -f [int]$first.HwId, $o.Env, $first.Env) }
      for ($i = 0; $i -lt $first.Caps.Count; $i++) {
        # the firmware variants of the board differ in this capability (developer view: "je nach Firmware-Variante")
        if ([bool]$first.Caps[$i] -ne [bool]$o.Caps[$i]) { $first.CapMixed[$i] = $true }
        if ($m.Capabilities[$i].Merge -eq "all") { $first.Caps[$i] = ($first.Caps[$i] -and $o.Caps[$i]) }
        elseif ($o.Caps[$i]) { $first.Caps[$i] = $true }
      }
      $first.CapMask = [uint32]0
      for ($i = 0; $i -lt $first.Caps.Count; $i++) { if ($first.Caps[$i]) { $first.CapMask = $first.CapMask -bor ([uint32]1 -shl $i) } }
      $first.Envs += $o.Env
      # GPIOs the board uses: union over its envs; the TP state per env decides about the KNX UART pins
      $first.ReservedGpios = @(@($first.ReservedGpios) + @($o.ReservedGpios) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
      $first.TpGpios = @(@($first.TpGpios) + @($o.TpGpios) | ForEach-Object { [int]$_ } | Sort-Object -Unique)
      $first.TpStates = @($first.TpStates) + @($o.TpStates)
      for ($i = 0; $i -lt $first.Values.Count; $i++) { if ($o.Values[$i] -gt $first.Values[$i]) { $first.Values[$i] = $o.Values[$i] } }
      # <BoardTable>: any = bitwise OR, all = bitwise AND per index over the envs (a missing index counts 0)
      foreach ($tn in @($m.BoardTables | ForEach-Object { $_.Name })) {
        $ta = $first.Tables[$tn]; $tb = $o.Tables[$tn]
        foreach ($ix in @(@($ta.Any.Keys) + @($tb.Any.Keys) | Sort-Object -Unique)) {
          $va = 0; if ($ta.Any.ContainsKey($ix)) { $va = $ta.Any[$ix] }
          $vb = 0; if ($tb.Any.ContainsKey($ix)) { $vb = $tb.Any[$ix] }
          $ta.Any[$ix] = [long]($va -bor $vb)
          $va = 0; if ($ta.All.ContainsKey($ix)) { $va = $ta.All[$ix] }
          $vb = 0; if ($tb.All.ContainsKey($ix)) { $vb = $tb.All[$ix] }
          $ta.All[$ix] = [long]($va -band $vb)
        }
      }
      foreach ($rn in @($o.Pins.Keys)) {
        $merged = @($first.Pins[$rn])
        foreach ($pin in $o.Pins[$rn]) { if (@($merged | Where-Object { $_.Gpio -eq $pin.Gpio }).Count -eq 0) { $merged += $pin } }
        $first.Pins[$rn] = @(Get-OrdinalSorted $merged { [regex]::Replace($_.Label, '\d+', { param($mt) $mt.Value.PadLeft(5, '0') }) })
      }
    }
    Write-Step ("0x{0:X4} built by {1} envs ({2}) - one entry (capabilities: merge any/all, values: largest)" -f [int]$g.Name, $g.Count, (($g.Group | ForEach-Object { $_.Env }) -join ", "))
    Set-BoardMaps $m $first
    $keep = $first
    # drop only the other env members; a <Board> line or pattern board of this HW-ID goes on to the priority dedup
    $boards = @($boards | Where-Object { $_.HwId -ne [int]$g.Name -or -not $_.Env -or [object]::ReferenceEquals($_, $keep) })
  }
  # the "not selected" value is one more entry of the selection: it must not be a board's HW-ID
  $clash = @($boards | Where-Object { [int]$_.HwId -eq $m.UnselectedValue }) | Select-Object -First 1
  if ($clash) { Stop-WithError ("{0} has DEVICE_HW_ID {1}, the value of not selected" -f $clash.Define, $m.UnselectedValue) }
  # an explicit entry can resolve to the same HW-ID as a pattern board (alias define + flags, e.g.
  # DEVICE_QUINLED_DIG_QUAD_V3 + -DKNX_IP_LAN = 0x2121): the explicit one wins, two explicit ones stop
  $dups = $boards | Group-Object { $_.HwId } | Where-Object { $_.Count -gt 1 }
  foreach ($d in $dups) {
    # priority: a <Board> line of the manifest > a PlatformIO env (already merged per HW-ID) > a pattern
    $rank = { param($b) if ($b.Explicit) { 3 } elseif ($b.Env) { 2 } else { 1 } }
    $top = ($d.Group | ForEach-Object { & $rank $_ } | Measure-Object -Maximum).Maximum
    $winners = @($d.Group | Where-Object { (& $rank $_) -eq $top })
    $list = ($d.Group | ForEach-Object { $_.Define }) -join ", "
    if ($winners.Count -ne 1) { Stop-WithError ("Duplicate DEVICE_HW_ID 0x{0:X4}: {1}" -f [int]$d.Name, $list) }
    $keepDup = $winners[0]
    Write-Warn ("0x{0:X4} reached twice ({1}) - {2} wins" -f [int]$d.Name, $list, $keepDup.Define)
    $boards = @($boards | Where-Object { $_.HwId -ne [int]$d.Name -or [object]::ReferenceEquals($_, $keepDup) })
  }
  # two boards with the same DEVICE_NAME would show two identical ETS entries
  foreach ($g in ($boards | Group-Object { $_.Name } | Where-Object { $_.Count -gt 1 })) {
    foreach ($b in $g.Group) { $b.Name = "{0} (0x{1:X4})" -f $b.Name, $b.HwId }
    Write-Warn ("Same DEVICE_NAME for {0} boards - the ETS list adds the HW-ID: {1}" -f $g.Count, $g.Name)
  }
  if ($boards.Count -lt 2) { Stop-WithError "A hardware selection needs at least two boards" }
  # order="hwid": ascending DEVICE_HW_ID; $b.Index = position in the final list
  if ($m.Order -eq "hwid") { $boards = @($boards | Sort-Object { [int]$_.HwId }) }
  for ($i = 0; $i -lt $boards.Count; $i++) { $boards[$i].Index = $i }
  # board number in IDs: the slot file
  $slotFile = Update-BoardSlots $m $boards
  # port value encoding: no offered port may sit on the manual or none value (it could never be selected)
  if ($null -ne $m.PortManual) {
    foreach ($b in $boards) {
      foreach ($pt in @($b.Ports)) {
        foreach ($kv in @(@("portManualValue", $m.PortManual), @("portNoneValue", $m.PortNone))) {
          if (($pt.N - 1) -eq $kv[1]) { Stop-WithError ("{0}: ETS offers port {1}, its port value {3} (port number - 1) is {2} - leave the port out with <Ports use=...> or choose other values (e.g. 254 / 255)" -f $b.Define, $pt.N, $kv[0], $kv[1]) }
        }
      }
    }
  }
  if ($m.Conflicts) { Resolve-Conflicts $m $boards }

  # device card pictures (logo, badge, QR code + link): rendered with the text outputs, written after them
  $m.InfoGroups = Get-InfoGroups $m $boards
  $m.Marks = Get-CardMarks $m $boards
  $images = @()
  if ($m.Info) {
    $infoDir = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($m.Outputs["share"]), "Baggages", ($m.Prefix + "Info"))
    try {
      $urlFont = Read-GlyphFont ([System.IO.Path]::Combine($PSScriptRoot, "assets", "fonts")) $m.Info.UrlFont
      foreach ($k in $m.Marks) {
        $img = Read-PngRgba $k.File
        $images += @{ Output = [System.IO.Path]::Combine($infoDir, $k.Name + ".png"); Image = $img }
        Write-Step ("device card {0}.png: {1}x{2} px from {3}, {4} board(s)" -f $k.Name, $img.Width, $img.Height, $k.File, @($k.Boards).Count)
      }
    }
    catch { Stop-WithError ("<InfoImage>: {0}" -f $_.Exception.Message) }
    $imageIndex = 0
    foreach ($g in $m.InfoGroups) {
      # the link without scheme (the QR code holds the full URL)
      $shown = $g.Url -replace '^[A-Za-z][A-Za-z0-9+.-]*://', ''
      $imageIndex++
      Write-Activity ("QR-Bild {0}/{1}  {2}" -f $imageIndex, @($m.InfoGroups).Count, $shown)
      try { $img = New-QrLinkImage $g.Url $shown $m.Info.Width $m.Info.Module $m.Info.Version $urlFont $m.Info.Supersample $m.Info.UrlRgb }
      catch { Stop-WithError ("device card {0} ({1}): {2}" -f $g.File, $g.Url, $_.Exception.Message) }
      $images += @{ Output = [System.IO.Path]::Combine($infoDir, $g.File); Image = $img }
      if ($img.Qr.Version -gt $m.Info.Version) { Write-Warn ("device card {0}: the URL needs QR version {1} (manifest version {2}): {3}" -f $g.File, $img.Qr.Version, $m.Info.Version, $g.Url) }
      Write-Step ("device card {0}: {1}x{2} px, QR version {3}-{4} {5} px, link {6:N1} px: {7}, {8} board(s)" -f $g.File, $img.Width, $img.Height, $img.Qr.Version, $img.Qr.Ec, $img.QrPx, $img.TextW, $shown, $g.Boards.Count)
    }
  }

  # <Page queryImage>: steps picture of the device query, copied as Baggages/<prefix>Info/Steps.png (at most the page width)
  if ($m.Page -and $m.Page.ImageFile) {
    try { $img = Read-PngRgba $m.Page.ImageFile }
    catch { Stop-WithError ("<Page> queryImage: {0}" -f $_.Exception.Message) }
    if ($img.Width -gt $script:EtsPictureMaxWidth) { Stop-WithError ("<Page> queryImage: {0} is {1} px wide, the page is {2} px wide" -f $m.Page.ImageFile, $img.Width, $script:EtsPictureMaxWidth) }
    $stepsDir = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($m.Outputs["share"]), "Baggages", ($m.Prefix + "Info"))
    $images += @{ Output = [System.IO.Path]::Combine($stepsDir, "Steps.png"); Image = $img }
    Write-Step ("query steps Steps.png: {0}x{1} px from {2}" -f $img.Width, $img.Height, $m.Page.ImageFile)
  }

  # every output is rendered before the first one is written: an error leaves no half-updated set
  $rendered = @()
  if ($m.Outputs.ContainsKey("conf")) { Write-OutputActivity "erzeugen" $m.Outputs["conf"]; $rendered += @{ Output = $m.Outputs["conf"]; Text = (New-ConfXml $m $boards) } }
  if ($m.Outputs.ContainsKey("share")) { Write-OutputActivity "erzeugen" $m.Outputs["share"]; $rendered += @{ Output = $m.Outputs["share"]; Text = (New-ShareXml $m $boards) } }
  if ($m.Page -and $m.Page.Dev) { Write-OutputActivity "erzeugen" $m.Page.Dev; $rendered += @{ Output = $m.Page.Dev; Text = (New-DevShareXml $m $boards) } }
  if ($m.Outputs.ContainsKey("script")) { Write-OutputActivity "erzeugen" $m.Outputs["script"]; $rendered += @{ Output = $m.Outputs["script"]; Text = (New-ScriptJs $m $boards) } }
  if ($m.Outputs.ContainsKey("header")) { Write-OutputActivity "erzeugen" $m.Outputs["header"]; $rendered += @{ Output = $m.Outputs["header"]; Text = (New-Header $m $boards) } }
  if ($m.Conflicts) { Write-OutputActivity "erzeugen" $m.Conflicts.Output; $rendered += @{ Output = $m.Conflicts.Output; Text = (New-ConflictsXml $m $boards) } }
  if ($m.Fixes) { Write-OutputActivity "erzeugen" $m.Fixes.Output; $rendered += @{ Output = $m.Fixes.Output; Text = (New-FixesXml $m $boards) } }

  # templates ("Bausteine"): whole generated files, never a splice into a hand-written file
  $vars = @{ Boards = $boards; M = $m }
  foreach ($g in $m.Generates) {
    Write-OutputActivity "erzeugen" $g.Output
    $vars["P"] = $g.Params
    try { $text = Invoke-TemplateFile -FullPath $g.Template -Vars $vars -FinalNewline $g.FinalNewline }
    catch { Stop-WithError ("Template {0}: {1}" -f $g.Template, $_.Exception.Message) }
    $rendered += @{ Output = $g.Output; Text = $text }
  }
  # <Conflicts>: numbers against the module files next to the parts file (hint); a parts file of an earlier run is reported
  $ownOutputs = @($rendered | ForEach-Object { [System.IO.Path]::GetFullPath($_.Output) })
  if ($m.Conflicts) { Test-ConflictNumbers $m $ownOutputs }
  # product XMLs of the OAM: inclusion of the hardware module, ApplicationVersion for the ETS fingerprint
  $products = Get-ProductXmls $m
  Test-ProductXmls $m $products
  if ($null -ne $slotFile) {
    Add-EtsFingerprint $m $slotFile $rendered $images $products
    $rendered += @{ Output = $slotFile.Output; Text = $slotFile.Text }
  }
  foreach ($f in (Get-StaleConflictFiles $m $ownOutputs)) {
    Write-Warn ("{0} is a <Conflicts> parts file of an earlier run (no <Conflicts output> names it any more) - delete it and its op:include lines" -f $f)
    if ($script:CheckMode) { Add-Written $f }
  }
  foreach ($r in $rendered) {
    Write-OutputActivity "vergleichen" $r.Output
    if ($DryRun) { Write-Step ("would write {0}" -f $r.Output) }
    elseif (Update-Utf8File $r.Output $r.Text) { Add-Written $r.Output; Write-Ok ("wrote {0}" -f $r.Output) }
    else { Write-Detail ("  = unchanged {0}" -f $r.Output) }
  }
  foreach ($r in $images) {
    if ($DryRun) { Write-Step ("would write {0}" -f $r.Output) }
    elseif (Update-PngRgba $r.Output $r.Image.Width $r.Image.Height $r.Image.Pixels) { Add-Written $r.Output; Write-Ok ("wrote {0}" -f $r.Output) }
    else { Write-Detail ("  = unchanged {0}" -f $r.Output) }
  }
  # page icon of the generator (assets/icons/<icon>.png) next to the share: Baggages/Icons/<icon>.png (producer: Icons.zip)
  if ($m.Page -and $m.Page.IconFile) {
    $iconOut = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($m.Outputs["share"]), "Baggages", "Icons", $m.Page.Icon + ".png")
    $iconBytes = [System.IO.File]::ReadAllBytes($m.Page.IconFile)
    $same = $false
    if (Test-Path -LiteralPath $iconOut -PathType Leaf) {
      $old = [System.IO.File]::ReadAllBytes($iconOut)
      $same = ($old.Length -eq $iconBytes.Length) -and ([System.Convert]::ToBase64String($old) -ceq [System.Convert]::ToBase64String($iconBytes))
    }
    if ($DryRun) { Write-Step ("would write {0}" -f $iconOut) }
    elseif ($same) { Write-Detail ("  = unchanged {0}" -f $iconOut) }
    elseif ($script:CheckMode) { Add-Written $iconOut }
    else {
      [void](New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($iconOut)))
      [System.IO.File]::WriteAllBytes($iconOut, $iconBytes)
      Add-Written $iconOut
      Write-Ok ("wrote {0}" -f $iconOut)
    }
  }
  # the generator owns the info folder: pictures it no longer writes go
  # <InfoImage> and <Page> both need <Output share>; without either the folder is not the generator's
  if ($m.Info -or $m.Page) { $infoDir = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($m.Outputs["share"]), "Baggages", ($m.Prefix + "Info")) }
  if (($m.Info -or $m.Page) -and -not $DryRun -and (Test-Path -LiteralPath $infoDir)) {
    $keep = @($images | ForEach-Object { [System.IO.Path]::GetFileName($_.Output) })
    foreach ($f in (Get-ChildItem -LiteralPath $infoDir -Filter "*.png")) {
      if ($keep -notcontains $f.Name) {
        if (-not $script:CheckMode) { Remove-Item -LiteralPath $f.FullName; Write-Ok ("removed {0}" -f $f.FullName) }
        Add-Written $f.FullName
      }
    }
  }
  if ($script:Compact) {
    Clear-Activity
    # one line per board (by HW-ID), then the summary
    foreach ($b in @($boards | Sort-Object { [int]$_.HwId })) { Write-Host ("  OK 0x{0:X4}  {1}" -f [int]$b.HwId, $b.Name) -ForegroundColor Green }
    $envCount = @($expanded | Where-Object { $_.Env }).Count
    $parts = @()
    if ($envCount -gt 0) { $parts += ("{0} Envs" -f $envCount) }
    $parts += ("{0} Boards" -f $boards.Count)
    if ($script:CheckMode) {
      if ($script:WrittenCount -eq 0) { Write-Host ("Hardware: {0}, Check: aktuell" -f ($parts -join ", ")) -ForegroundColor Green; exit 0 }
      Write-Host ("Hardware: {0}, Check: {1} Datei(en) nicht aktuell: {2} - Generator laufen lassen (veraltete <Conflicts>-Dateien von Hand l{3}schen)" -f ($parts -join ", "), $script:WrittenCount, ($script:WrittenFiles -join ", "), [char]0xF6) -ForegroundColor Red
      exit 1
    }
    if ($script:WrittenCount -eq 0) { $state = "unver" + [string][char]0xE4 + "ndert" }
    elseif ($script:WrittenCount -eq 1) { $state = "1 Datei geschrieben" }
    else { $state = "{0} Dateien geschrieben" -f $script:WrittenCount }
    if ($script:WrittenCount -gt 0 -and $script:WrittenCount -le 3) { $state += " (" + ($script:WrittenFiles -join ", ") + ")" }
    Write-Host ("Hardware: {0}, {1}" -f ($parts -join ", "), $state) -ForegroundColor Green
    if ($script:WarningCount -gt 0) { Write-Host ("  {0} warning(s)" -f $script:WarningCount) -ForegroundColor Yellow }
  }
  else {
    Write-Host ""
    if ($script:CheckMode -and $script:WrittenCount -gt 0) {
      Write-Host ("  Check: {0} file(s) not current: {1}" -f $script:WrittenCount, ($script:WrittenFiles -join ", ")) -ForegroundColor Red
      exit 1
    }
    if ($script:CheckMode) { Write-Host "  Check: current" -ForegroundColor Green }
    elseif ($script:WarningCount -gt 0) { Write-Host ("  done with {0} warning(s)" -f $script:WarningCount) -ForegroundColor Yellow }
    else { Write-Host "  done" -ForegroundColor Green }
  }
}
finally {
  Clear-Activity
  if (Test-Path $script:TempDir) { Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue }
}
