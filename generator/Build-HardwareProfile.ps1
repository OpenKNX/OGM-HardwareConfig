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

.PARAMETER SelfTest
    Run the self-test (tests/Test-HardwareProfile.ps1): the generator on small test manifests, what it must do and refuse.
    Exit code 1 when a test fails. For the slow demo update test call the test script with -Full.

.PARAMETER Detailed
    Full log (manifest, boards with capabilities and values, every output). Default: one line per board
    ("OK 0x1321  <name>", by HW-ID) and a summary line; warnings and errors are always shown.

.PARAMETER Language
    Language of the console output: de (default) or en. The generated files do not depend on it.

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
  [switch]$Detailed,
  [switch]$SelfTest,
  [ValidateSet("de", "en")][string]$Language = "de"
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
                        "Conflicts", "Fixes", "Header", "Init", "Generate", "Language")) {
  . ([System.IO.Path]::Combine($PSScriptRoot, "core", $corePart + ".ps1"))
}
Remove-Variable corePart
$script:WarningCount = 0
Set-OutputLanguage $Language
# @brief Help in the layout of the OpenKNX build scripts; Get-Help shows the full description
function Show-Help {
  Show-OpenKNXLogo ("Build-HardwareProfile " + $SCRIPT_VERSION)
  Write-Host (T "USAGE:") -ForegroundColor Yellow
  Write-Host "  pwsh lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 [-Manifest <file>] [-Check] [-Detailed] [-DryRun] [-Language de|en]"
  Write-Host "  pwsh lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 -ListIds [-Markdown] | -NextId <group> | -Init"
  Write-Host ""
  Write-Host (T "OPTIONS:") -ForegroundColor Yellow
  Write-Host (T "  -Manifest <file>    Manifest of the application (default: HardwareProfile.xml in the current folder)")
  Write-Host (T "  -Check              Compare every output with the file on disk, write nothing; exit 1 when one is out of date (CI)")
  Write-Host (T "  -Detailed           Full log: manifest, boards with capabilities and values, every output (default: summary)")
  Write-Host (T "  -DryRun             Evaluate and print, write no file")
  Write-Host (T "  -ListIds            Every DEVICE_HW_ID of OGM-HardwareConfig; stops on a duplicate ID (no manifest needed)")
  Write-Host (T "  -Markdown           With -ListIds: print a Markdown table")
  Write-Host (T "  -NextId <group>     Next free DEVICE_HW_ID of a group (0x21 = 0x2100..0x21FF, 0x213 = 0x2130..0x213F)")
  Write-Host (T "  -Init               Create the manifest for an application without one (boards of the release_* envs)")
  Write-Host (T "  -Compiler <path>    C++ compiler used as preprocessor (default: PlatformIO toolchain of the board MCU)")
  Write-Host (T "  -HardwareConfigInclude <dir>  Include folder of OGM-HardwareConfig (default: next to this script)")
  Write-Host (T "  -SelfTest           Run the self-test (tests/Test-HardwareProfile.ps1); exit 1 when a test fails")
  Write-Host (T "  -Language de|en     Language of the console output (default: de)")
  Write-Host (T "  -Help, -h, --help   Show this help (Get-Help Build-HardwareProfile.ps1 -Detailed: full description)")
  Write-Host ""
  Write-Host (T "EXAMPLES:") -ForegroundColor Yellow
  $examples = @(
    @("Build-HardwareProfile.ps1", (T "reads ./HardwareProfile.xml and writes the files named in it")),
    @("Build-HardwareProfile.ps1 -Check", (T "CI: exit 1 when a generated file is out of date")),
    @("Build-HardwareProfile.ps1 -Detailed", (T "full log")),
    @("Build-HardwareProfile.ps1 -ListIds -Markdown", (T "hardware ID table of all boards")),
    @("Build-HardwareProfile.ps1 -NextId 0x25", (T "next free DEVICE_HW_ID in 0x2500..0x25FF"))
  )
  $width = ($examples | ForEach-Object { $_[0].Length } | Measure-Object -Maximum).Maximum
  foreach ($e in $examples) {
    Write-Host ("  " + $e[0].PadRight($width)) -NoNewline -ForegroundColor White
    Write-Host ("  # " + $e[1]) -ForegroundColor DarkGray
  }
  Write-Host ""
}
# help: -Help, -? (PowerShell) and the usual --help / -h / /? (they arrive as the positional Manifest)
if ($SelfTest) {
  & ([System.IO.Path]::Combine($PSScriptRoot, "tests", "Test-HardwareProfile.ps1")) -Language $Language
  exit $LASTEXITCODE
}
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
    Stop-WithError (T "HardwareConfig.h not found in {0}" $HardwareConfigInclude)
  }
  $script:HwInclude = $HardwareConfigInclude
  # the firmware maps port values with include/HardwareConfig/Helpers/HardwarePorts.h: read the same port limit
  $portsHeader = [System.IO.Path]::Combine($HardwareConfigInclude, "HardwareConfig", "Helpers", "HardwarePorts.h")
  if (-not (Test-Path -LiteralPath $portsHeader)) { Stop-WithError (T "HardwareConfig/Helpers/HardwarePorts.h not found in {0}" $HardwareConfigInclude) }
  else {
    $pm = [regex]::Match([System.IO.File]::ReadAllText($portsHeader), '(?m)^[ \t]*#define[ \t]+HW_PORTS_MAX\b(.*)$')
    if ($pm.Success) {
      $pv = [regex]::Match($pm.Groups[1].Value, '^\s*\(?\s*(\d+)\s*\)?\s*(//.*)?\s*$')
      if (-not $pv.Success) { Stop-WithError (T "HardwareConfig/Helpers/HardwarePorts.h: HW_PORTS_MAX must be a number: {0}" ($pm.Groups[1].Value.Trim())) }
      $MAX_PORTS = [int]$pv.Groups[1].Value
    }
  }
  $script:IncludeDirs = @($HardwareConfigInclude)
  $script:DefaultCompiler = Find-Compiler
  $script:CompilerPath = $script:DefaultCompiler
  Write-Step (T "Preprocessor: {0}" $script:CompilerPath)

  # -Check compares the outputs of a regular run; the other modes write or list something else
  if ($script:CheckMode -and ($ListIds -or $NextId -or $Init -or $DryRun)) { Stop-WithError (T "-Check cannot be combined with -ListIds, -NextId, -Init or -DryRun") }
  if ($ListIds) { Invoke-ListIds }
  if ($NextId) { Invoke-NextId }
  if ($Init) { Invoke-Init }

  Start-Phase (T "Read the manifest")
  $m = Read-Manifest $Manifest
  $script:IncludeDirs = @($m.IncludeDirs) + @($HardwareConfigInclude)
  Write-Step (T "Manifest: {0} board(s), {1} capabilities, {2} values, {3} GPIO role(s), unselected={4}" $m.Boards.Count $m.Capabilities.Count $m.Values.Count $m.Roles.Count $m.Unselected)
  Complete-Phase (T "{0} capabilities, {1} values" $m.Capabilities.Count $m.Values.Count)
  Start-Phase (T "Find the boards (PlatformIO, board headers)")
  $found = Get-ProductBoards $m
  $boards = $found.Boards; $envCount = $found.EnvCount
  if ($envCount -gt 0) { Complete-Phase (T "{0} Envs, {1} Boards" $envCount $boards.Count) } else { Complete-Phase (T "{0} Boards" $boards.Count) }
  Start-Phase (T "Slot file, port values, conflict check")
  $slotFile = Update-SlotsAndPorts $m $boards
  Complete-Phase
  Start-Phase (T "Pictures of the device card")
  $images = (New-CardImages $m $boards).Images
  Complete-Phase (T "{0} picture(s)" (@($images).Count))
  Start-Phase (T "Build the application and the firmware header")
  $out = New-ProductOutputs $m $boards
  $rendered = $out.Rendered; $ownOutputs = $out.OwnOutputs
  Complete-Phase (T "{0} file(s)" $rendered.Count)
  Start-Phase (T "Product XML and version guard")
  $guard = Test-ProductAndGuard $m $slotFile $rendered $images
  $rendered = $guard.Rendered; $products = $guard.Products
  Complete-Phase (T "{0} product XML(s)" (@($products).Count))
  if ($script:CheckMode) { Start-Phase (T "Check the files") } elseif ($DryRun) { Start-Phase (T "Show the files (-DryRun)") } else { Start-Phase (T "Write the files") }
  $phaseState = Write-ProductOutputs $m $rendered $images $ownOutputs
  Complete-Phase $phaseState
  Write-RunSummary $m $boards $envCount
}
catch {
  # an unexpected error (not Stop-WithError): the running step gets its cross line, the error goes on as before
  if ($script:PhaseWatch) { Write-PhaseLine (Get-PhaseMark "fail") "Red" ""; $script:PhaseWatch = $null }
  throw
}
finally {
  Clear-Activity
  if (Test-Path $script:TempDir) { Remove-Item -Recurse -Force $script:TempDir -ErrorAction SilentlyContinue }
}
