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
    values; order="hwid" sorts them by DEVICE_HW_ID, ids="index" numbers them by position instead of slots.
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
# Base = CLK MISO MOSI HD WP CS0; Cs1 = PSRAM chip select with CONFIG_SPIRAM and BOARD_HAS_PSRAM (esp32-hal-psram.h clears
# CONFIG_SPIRAM without it); Octal = D4..D7 DQS with CONFIG_SPIRAM_MODE_OCT / CONFIG_ESPTOOLPY_OCT_FLASH (memory type *_opi)
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

# ------------------------------------------------------------------------------------------------
# Output helpers
# ------------------------------------------------------------------------------------------------
# compact output (default of a generation run): steps and per-output lines only with -Detailed; warnings and errors
# always; an error also shows the last step as context
# @brief OpenKNX logo with a title (same look as the OpenKNX build scripts); the glyphs are built at run time, the file stays ASCII
function Show-OpenKNXLogo([string]$Text) {
  $box = [char]::ConvertFromUtf32(0x25A0)
  $line = [char]::ConvertFromUtf32(0x252C) + ([string][char]::ConvertFromUtf32(0x2500) * 4) + [char]::ConvertFromUtf32(0x2534)
  Write-Host ""
  Write-Host "Open " -NoNewline
  Write-Host $box -ForegroundColor Green
  Write-Host ("{0}  {1}" -f $line, $Text) -ForegroundColor Green
  Write-Host $box -NoNewline -ForegroundColor Green
  Write-Host " KNX"
  Write-Host ""
}
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
# @brief Counts a written or removed output (the compact summary names up to three)
function Add-Written([string]$Path) { $script:WrittenCount++; $script:WrittenFiles.Add([System.IO.Path]::GetFileName($Path)) }
# @brief Compact mode on a console: one self-overwriting progress line; nothing when the output is redirected
function Write-Activity([string]$Text) {
  if (-not $script:Compact -or [Console]::IsOutputRedirected) { return }
  $max = 79
  try { $max = [Math]::Min(79, [Console]::WindowWidth - 1) } catch { }
  if ($max -lt 20) { return }
  $line = "Hardware: " + $Text
  if ($line.Length -gt $max) { $line = $line.Substring(0, $max) }
  [Console]::Write("`r" + $line.PadRight($max))
  $script:ActivityWidth = $max
  $script:ActivityShown = $true
}
# @brief Progress line for one output file: action and file name
function Write-OutputActivity([string]$Action, [string]$Path) { Write-Activity ("{0}  {1}" -f $Action, [System.IO.Path]::GetFileName($Path)) }
# @brief Removes the progress line before regular output
function Clear-Activity {
  if (-not $script:ActivityShown) { return }
  [Console]::Write("`r" + (" " * $script:ActivityWidth) + "`r")
  $script:ActivityShown = $false
}
function Write-Step([string]$Text) {
  $script:LastStep = $Text
  if (-not $script:Compact) { Write-Host ("  > " + $Text) -ForegroundColor Cyan }
  else { Write-Activity $Text }
}
function Write-Ok([string]$Text) { if (-not $script:Compact) { Write-Host ("  + " + $Text) -ForegroundColor Green } }
# @brief Plain log line, only with -Detailed (or -ListIds / -Init / -DryRun)
function Write-Detail([string]$Text) { if (-not $script:Compact) { Write-Host $Text } }
function Write-Warn([string]$Text) { Clear-Activity; Write-Host ("  ! " + $Text) -ForegroundColor Yellow; $script:WarningCount++ }
function Stop-WithError([string]$Text) {
  Clear-Activity
  if ($script:Compact -and $script:LastStep) { Write-Host ("  > " + $script:LastStep) -ForegroundColor Cyan }
  Write-Host ("  x " + $Text) -ForegroundColor Red
  exit 1
}
$script:WarningCount = 0
$script:IdsIndex = $false
$script:InitMode = $false
$script:NoBoardEnvs = @()

# @brief A board or a define of a board would be left out: stops the run (both ids modes). A skipped board
# drops its HW-ID from ETS and the firmware table and is marked "removed" in the slot file; a board is dropped
# on purpose by deleting its env. -Init only lists the problem (it writes no ETS or firmware output).
function Stop-OnSkip([string]$Text) {
  if ($script:InitMode) { Write-Warn $Text; return }
  Stop-WithError ($Text + " - a left-out board drops its HW-ID from ETS and the firmware table; to drop a board on purpose, delete its env")
}

function Write-Utf8File([string]$Path, [string]$Text) {
  $dir = [System.IO.Path]::GetDirectoryName($Path)
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $Text = $Text -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

# @brief Writes an output only when its content (LF, without BOM) differs from the file on disk
# @return $true when the file was written; an unchanged file keeps its timestamp (no needless rebuild)
function Update-Utf8File([string]$Path, [string]$Text) {
  $Text = $Text -replace "`r`n", "`n"
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $old = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
    if ($old -ceq $Text) { return $false }
  }
  if ($script:CheckMode) { return $true }   # -Check: report, never write
  Write-Utf8File $Path $Text
  return $true
}

function ConvertTo-XmlText([string]$Text) {
  # a line break as character reference: a literal one in an attribute would be read back as a space
  return ([System.Security.SecurityElement]::Escape($Text) -replace "`r", '' -replace "`n", '&#10;')
}

function ConvertTo-JsString([string]$Text) {
  $t = $Text -replace '\\', '\\' -replace '"', '\"' -replace "`r", '\r' -replace "`n", '\n'
  # JScript (ETS) reads the script as UTF-8; escape non-ASCII so the file stays readable everywhere
  $sb = New-Object System.Text.StringBuilder
  foreach ($c in $t.ToCharArray()) {
    if ([int]$c -gt 126) { [void]$sb.Append(('\u{0:X4}' -f [int]$c)) } else { [void]$sb.Append($c) }
  }
  return '"' + $sb.ToString() + '"'
}

# ------------------------------------------------------------------------------------------------
# Compiler / preprocessor
# ------------------------------------------------------------------------------------------------
# @brief PlatformIO core folder: PLATFORMIO_CORE_DIR, else .platformio in the home folder
function Get-PioCoreDir {
  if ($env:PLATFORMIO_CORE_DIR) { return $env:PLATFORMIO_CORE_DIR }
  $h = $env:USERPROFILE
  if (-not $h) { $h = $env:HOME }
  return [System.IO.Path]::Combine($h, ".platformio")
}

# @brief True when the compiler preprocesses C++ from stdin; a broken installation (missing compiler frontend,
#        macOS g++ shim without Xcode tools) is reported and skipped. The board headers need no standard headers.
function Test-CppPreprocessor([string]$Path) {
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $global:LASTEXITCODE = $null
    $out = "#define OPENKNX_CPP_PROBE OPENKNX_CPP_PROBE_OK`nOPENKNX_CPP_PROBE" | & $Path -x c++ -E -P - 2>&1
    $exitCode = $LASTEXITCODE
  }
  catch {
    Write-Warn ("skipping unusable compiler {0}: {1}" -f $Path, $_)
    return $false
  }
  finally { $ErrorActionPreference = $prevEap }
  if ($exitCode -eq 0 -and (@($out | ForEach-Object { "$_".Trim() }) -contains "OPENKNX_CPP_PROBE_OK")) { return $true }
  Write-Warn ("skipping unusable compiler {0} (exit {1}): {2}" -f $Path, $exitCode, ((@($out) | Select-Object -First 3) -join " | "))
  return $false
}

# @brief g++ of the installed PlatformIO toolchains (<core>/packages/toolchain-*/bin/<prefix>-g++[.exe]): prefix -> path
function Get-PioToolchains {
  if ($null -ne $script:PioToolchains) { return $script:PioToolchains }
  $t = @{}
  $pkg = [System.IO.Path]::Combine((Get-PioCoreDir), "packages")
  if (Test-Path -LiteralPath $pkg) {
    foreach ($d in @(Get-ChildItem -LiteralPath $pkg -Directory -Filter "toolchain-*" | Sort-Object Name)) {
      $bin = [System.IO.Path]::Combine($d.FullName, "bin")
      if (-not (Test-Path -LiteralPath $bin)) { continue }
      foreach ($f in @(Get-ChildItem -LiteralPath $bin -File | Sort-Object Name)) {
        $mm = [regex]::Match($f.Name, '^(.+)-g\+\+(\.exe)?$')
        if ($mm.Success -and -not $t.ContainsKey($mm.Groups[1].Value)) { $t[$mm.Groups[1].Value] = $f.FullName }
      }
    }
  }
  $script:PioToolchains = $t
  return $t
}

# @brief PlatformIO toolchain prefixes of an MCU (name from Get-PioMcuName), preferred first
function Get-McuToolchainPrefixes([string]$Mcu) {
  if ($Mcu -match '^RP2') { return @("arm-none-eabi") }
  if ($Mcu -eq "ESP32") { return @("xtensa-esp32-elf", "xtensa-esp-elf") }
  if ($Mcu -eq "ESP32-S2") { return @("xtensa-esp32s2-elf", "xtensa-esp-elf") }
  if ($Mcu -eq "ESP32-S3") { return @("xtensa-esp32s3-elf", "xtensa-esp-elf") }
  if ($Mcu -match '^ESP32-[CHP]') { return @("riscv32-esp-elf") }
  return @()
}

# @brief Defines the Arduino framework of the MCU sets (arduino-pico ARDUINO_ARCH_RP2040, also on RP2350; arduino-esp32
#        ARDUINO_ARCH_ESP32): a board header may branch on them, the firmware sees them too
function Get-McuArchDefines([string]$Mcu) {
  if ($Mcu -match '^RP2') { return @("ARDUINO_ARCH_RP2040") }
  if ($Mcu -match '^ESP32') { return @("ARDUINO_ARCH_ESP32") }
  return @()
}

# @brief Default preprocessor (boards without MCU, -ListIds, -Init): -Compiler, else a PlatformIO toolchain (ARM first),
#        else clang++/g++/cpp in PATH (warning: not the compiler of the firmware)
function Find-Compiler {
  if ($Compiler) {
    $cmd = Get-Command $Compiler -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $path = if ($cmd) { $cmd.Source } elseif (Test-Path -LiteralPath $Compiler -PathType Leaf) { $Compiler } else { $null }
    if (-not $path) { Stop-WithError "Compiler not found: $Compiler" }
    if (-not (Test-CppPreprocessor $path)) { Stop-WithError "Compiler cannot preprocess C++: $Compiler" }
    return $path
  }
  $tc = Get-PioToolchains
  foreach ($pfx in @(@("arm-none-eabi") + @($tc.Keys | Where-Object { $_ -ne "arm-none-eabi" } | Sort-Object))) {
    if ($tc.ContainsKey($pfx) -and (Test-CppPreprocessor $tc[$pfx])) { return $tc[$pfx] }
  }
  # -CommandType Application: "cpp" is an alias of Copy-ItemProperty in Windows PowerShell 5.1
  foreach ($name in @("clang++", "g++", "cpp")) {
    foreach ($cmd in @(Get-Command $name -CommandType Application -ErrorAction SilentlyContinue)) {
      if (Test-CppPreprocessor $cmd.Source) {
        Write-Warn ("no PlatformIO toolchain in {0} - preprocessor from PATH: {1}" -f [System.IO.Path]::Combine((Get-PioCoreDir), "packages"), $cmd.Source)
        return $cmd.Source
      }
    }
  }
  Stop-WithError "No working C++ preprocessor found (PlatformIO toolchain, clang++, g++ or cpp). Install PlatformIO or use -Compiler."
}

# @brief Preprocessor of a board: -Compiler, else the PlatformIO toolchain of its MCU, else the default one (warning once per MCU)
function Get-BoardCompiler([string]$Mcu) {
  if ($Compiler -or -not $Mcu) { return $script:DefaultCompiler }
  if ($null -eq $script:McuCompiler) { $script:McuCompiler = @{} }
  if ($script:McuCompiler.ContainsKey($Mcu)) { return $script:McuCompiler[$Mcu] }
  $tc = Get-PioToolchains
  $path = $null
  foreach ($pfx in (Get-McuToolchainPrefixes $Mcu)) {
    if ($tc.ContainsKey($pfx) -and (Test-CppPreprocessor $tc[$pfx])) { $path = $tc[$pfx]; break }
  }
  if ($path) { Write-Step ("Preprocessor {0}: {1}" -f $Mcu, $path) }
  else {
    $path = $script:DefaultCompiler
    Write-Warn ("no PlatformIO toolchain for MCU {0} (pio pkg install for its platform) - preprocessor {1}" -f $Mcu, $path)
  }
  $script:McuCompiler[$Mcu] = $path
  return $path
}

$script:TempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "oknx-hwprofile-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $script:TempDir | Out-Null

# "NAME" or "NAME=VALUE" (as after -D) -> "#define NAME VALUE"; the same as -D, but no command-line quoting
function ConvertTo-DefineLine([string]$Define) {
  if ($Define -notmatch '^([A-Za-z_][A-Za-z0-9_]*)(=(.*))?$') { throw "Not a define: $Define" }
  if ($Define.EndsWith([string][char]92)) { throw "Define ends with a backslash (would continue into the next line): $Define" }
  if ($Matches[2]) { return "#define {0} {1}" -f $Matches[1], $Matches[3] }
  return "#define {0} 1" -f $Matches[1]
}

function Invoke-Preprocessor([string]$Source, [string[]]$Defines, [switch]$MacroList) {
  $file = [System.IO.Path]::Combine($script:TempDir, "probe.cpp")
  $head = @($Defines | ForEach-Object { ConvertTo-DefineLine $_ })
  Write-Utf8File $file ((($head + @($Source)) -join "`n"))
  $args1 = @("-x", "c++", "-E", "-P")
  if ($MacroList) { $args1 = @("-x", "c++", "-E", "-dM") }
  foreach ($inc in $script:IncludeDirs) { $args1 += ("-I" + $inc) }
  # the result goes to a file read as UTF-8: stdout of a native command is decoded with the console
  # code page (OEM 850 on Windows) and would garble non-ASCII names and labels
  $outFile = [System.IO.Path]::Combine($script:TempDir, "probe.out")
  if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile -Force }
  $args1 += @("-o", $outFile, $file)
  # Windows PowerShell 5.1 turns every stderr line of a native command into a terminating error under
  # "Stop"; a compiler warning must not abort the run, only the exit code counts
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $out = & $script:CompilerPath @args1 2>&1
    $exitCode = $LASTEXITCODE
  }
  finally { $ErrorActionPreference = $prevEap }
  if ($exitCode -ne 0) {
    $msg = ($out | Where-Object { "$_" -match 'error' } | Select-Object -First 3) -join " | "
    throw "Preprocessor failed for -D$($Defines -join ' -D'): $msg"
  }
  $text = [System.IO.File]::ReadAllText($outFile, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
  if ($text.EndsWith("`n")) { $text = $text.Substring(0, $text.Length - 1) }
  return $text.Split([char]10)
}

# "abc" "def" -> abc def ; returns $null when a bare identifier is left (undefined macro)
function ConvertFrom-CString([string]$Text) {
  $t = $Text.Trim()
  if ($t -notmatch '^(\s*"([^"\\]|\\.)*"\s*)+$') { return $null }
  $parts = [regex]::Matches($t, '"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\' }
  return ($parts -join "")
}

# 0x2120 / (16) / 4u / (uint8_t)16 -> int ; $null when not a plain integer
# @brief true for a negative integer literal such as (-1): a pin macro that marks "not present"
function Test-CNegative([string]$Text) {
  $t = $Text.Trim()
  while ($t -match '^\((.*)\)$') { $t = $Matches[1].Trim() }
  return ($t -match '^-\s*(0[xX][0-9a-fA-F]+|\d+)[uUlL]*$')
}

function ConvertFrom-CInteger([string]$Text) {
  $t = $Text.Trim()
  $t = $t -replace '^\(\s*(u?int\d+_t|unsigned|int|uint8_t)\s*\)', ''
  while ($t -match '^\((.*)\)$') { $t = $Matches[1].Trim() }
  if ($t -match '^(0[xX][0-9a-fA-F]+|\d+)[uUlL]*$') {
    $v = $Matches[1]
    try {
      if ($v -match '^0[xX]') { return [Convert]::ToInt32($v.Substring(2), 16) }
      if ($v -match '^0[0-7]+$') { return [Convert]::ToInt32($v, 8) }   # C octal, as the firmware reads it
      if ($v -match '^0\d') { return $null }                             # 08/09: not a valid C literal
      return [int]$v
    }
    catch { return $null }                                              # out of Int32 range: not a pin/value
  }
  return $null
}

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

# ------------------------------------------------------------------------------------------------
# Manifest
# ------------------------------------------------------------------------------------------------
# "-DA -D B=1 C" -> "-DA", "-DB=1", "-DC" (platformio.ini writes "-D NAME" with a space)
function ConvertTo-FlagList([string]$Text) {
  $tokens = @($Text -split '\s+' | Where-Object { $_ })
  $list = @()
  for ($i = 0; $i -lt $tokens.Count; $i++) {
    $t = $tokens[$i]
    if ($t -eq "-D") {
      if ($i + 1 -ge $tokens.Count) { Stop-WithError "flags: '-D' without a macro name" }
      $i++
      $t = "-D" + $tokens[$i]
    }
    elseif ($t -notmatch '^-D') { $t = "-D" + $t }
    # only -DNAME or -DNAME=VALUE without spaces or quotes: anything else would be split or misread
    if ($t -notmatch '^-D[A-Za-z_][A-Za-z0-9_]*(=[^\s"'']*)?$') { Stop-WithError "flags: '$t' is not -DNAME or -DNAME=VALUE (no spaces, no quotes, no other options)" }
    $list += $t
  }
  return ,$list
}
function Read-Manifest([string]$Path) {
  if (-not (Test-Path $Path)) { Stop-WithError "Manifest not found: $Path" }
  $full = (Resolve-Path $Path).Path
  $baseDir = [System.IO.Path]::GetDirectoryName($full)
  [xml]$doc = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
  $root = $doc.HardwareProfile
  if (-not $root) { Stop-WithError "Manifest root element must be <HardwareProfile>" }

  $m = @{
    ManifestPath = $full
    BaseDir      = $baseDir
    Prefix       = "$($root.prefix)"
    ModuleType   = [int]"$($root.moduleType)"
    Text         = "$($root.text)"
    Outputs      = @{}
    IncludeDirs  = @()
    Boards       = New-Object System.Collections.Generic.List[object]
    Capabilities = New-Object System.Collections.Generic.List[object]
    Values       = New-Object System.Collections.Generic.List[object]
    Roles        = New-Object System.Collections.Generic.List[object]
    Reserved     = @()
  }
  if (-not $m.Prefix) { $m.Prefix = "HWP" }
  if (-not $m.Text) { $m.Text = "Hardware" }
  # unselected = what "not selected" (0) means for the feature flags:
  #   showAll (default) - 0 counts as every capability: an OAM that wraps existing pages in feature flags keeps them
  #                       visible after the app update; ETS writes the default of every INVISIBLE parameter
  #                       on download, so hiding them before the user picks a hardware would reset his values
  #   hide              - 0 shows nothing hardware dependent (new products without existing projects)
  $m.Unselected = "$($root.unselected)"
  if (-not $m.Unselected) { $m.Unselected = "showAll" }
  if ($m.Unselected -ne "showAll" -and $m.Unselected -ne "hide") { Stop-WithError "unselected must be showAll or hide" }
  # value of "not selected" in the hardware selection (feature flags with unselected=showAll, generated module)
  $m.UnselectedValue = 0
  if ("$($root.unselectedValue)") { $m.UnselectedValue = [int]"$($root.unselectedValue)" }
  if ($m.UnselectedValue -lt 0 -or $m.UnselectedValue -ge 65535) { Stop-WithError "unselectedValue must be 0..65534 (65535 marks an empty test list)" }
  # port value encoding of the application's port selections (one declaration for the ETS conflict check and the firmware
  # header): 0..n-1 = port n of the board, portManualValue = manual GPIO, portNoneValue = no port, any other value = no GPIO
  $m.PortManual = $null; $m.PortNone = $null
  foreach ($a in @(@("portManualValue", "PortManual", 254), @("portNoneValue", "PortNone", 255))) {
    if (-not $root.HasAttribute($a[0])) { continue }
    $t = "$($root.GetAttribute($a[0]))".Trim()
    if ($t -notmatch '^\d+$' -or [int64]$t -gt $a[2]) { Stop-WithError ("{0} must be a number 0..{1}" -f $a[0], $a[2]) }
    $m[$a[1]] = [int]$t
  }
  if (($null -eq $m.PortManual) -ne ($null -eq $m.PortNone)) { Stop-WithError "portManualValue and portNoneValue go together" }
  if ($null -ne $m.PortManual -and $m.PortManual -eq $m.PortNone) { Stop-WithError "portManualValue and portNoneValue must differ" }

  # board order: manifest (default, order of the entries) or hwid (ascending DEVICE_HW_ID)
  $m.Order = "$($root.order)"
  if (-not $m.Order) { $m.Order = "manifest" }
  if ($m.Order -ne "manifest" -and $m.Order -ne "hwid") { Stop-WithError "order must be manifest or hwid" }
  # board number ($b.Slot) in IDs: slot (default, slot file, stable over the product life) or index (position)
  $m.Ids = "$($root.ids)"
  if (-not $m.Ids) { $m.Ids = "slot" }
  if ($m.Ids -ne "slot" -and $m.Ids -ne "index") { Stop-WithError "ids must be slot or index" }

  # every output is optional; share (the ETS module) needs script and moduleType
  foreach ($o in @("conf", "share", "script", "header")) {
    $p = ""
    if ($root.Output) { $p = "$($root.Output.GetAttribute($o))" }
    if ($p) { $m.Outputs[$o] = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $p)) }
  }
  if ($m.Outputs.ContainsKey("share") -and -not $m.Outputs.ContainsKey("script")) { Stop-WithError "<Output share=...> needs script=..." }
  if ($m.Outputs.ContainsKey("share") -and ($m.ModuleType -lt 1 -or $m.ModuleType -gt 99)) { Stop-WithError "moduleType must be 1..99 (it is the %TT% of the ETS module)" }

  # <Generate template="..." output="..." [finalNewline="false"]><Param name="..." value="..."/></Generate>
  $m.Generates = New-Object System.Collections.Generic.List[object]
  foreach ($g in $root.SelectNodes("Generate")) {
    $tp = "$($g.template)"; $op = "$($g.output)"
    if (-not $tp -or -not $op) { Stop-WithError "<Generate> needs template=... and output=..." }
    if ($tp.StartsWith("@hw/")) { $tFull = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "templates", $tp.Substring(4))) }
    else { $tFull = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $tp)) }
    $params = @{}
    foreach ($pn in $g.SelectNodes("Param")) { $params["$($pn.name)"] = "$($pn.value)" }
    $m.Generates.Add(@{ Template = $tFull; Output = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $op)); Params = $params; FinalNewline = ("$($g.finalNewline)" -ne "false") })
  }
  foreach ($inc in $root.SelectNodes("IncludePath")) {
    $m.IncludeDirs += [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $inc.InnerText.Trim()))
  }

  # capability packs first, then the manifest's own entries (same name = override)
  $sources = @()
  foreach ($imp in $root.SelectNodes("Import")) {
    $ip = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $imp.href))
    if (-not (Test-Path $ip)) { Stop-WithError "Import not found: $ip" }
    [xml]$pack = [System.IO.File]::ReadAllText($ip, [System.Text.Encoding]::UTF8)
    $sources += $pack.DocumentElement
  }
  $sources += $root

  $capIndex = @{}; $valIndex = @{}
  # built in: ThirdParty = the board header defines DEVICE_THIRD_PARTY (board identity, like DEVICE_HW_ID); always bit 0 of
  # the device query; the device card (badge) and <Notice when="ThirdParty"> rely on it
  $m.Capabilities.Add(@{ Name = "ThirdParty"; Text = "Hardware eines Drittanbieters"; Expr = "defined(DEVICE_THIRD_PARTY)"; Merge = "any"; Switch = $false
    FixedBy = ""; ReportedBy = ""; Feature = ""; FeatureOn = ""; FeatureOff = ""; FeatureInvert = $false; FeatureNote = ""; FeatureNoteWhen = "" })
  $capIndex["ThirdParty"] = 0
  foreach ($src in $sources) {
    foreach ($c in $src.SelectNodes("Capability")) {
      if ("$($c.name)" -eq "ThirdParty") { Stop-WithError "Capability ThirdParty is built into the generator (DEVICE_THIRD_PARTY) - remove this <Capability>" }
      # merge = how the envs of one board combine: any (default, union) or all (every env has it)
      $entry = @{ Name = $c.name; Text = $c.text; Expr = $c.expr; Merge = "$($c.merge)"; Switch = $false; FixedBy = "$($c.fixedBy)"; ReportedBy = "$($c.reportedBy)" }
      # <Page features> (developer view): feature = row label (default text), featureOn / featureOff = value when the board
      # has / lacks it (default ja / nein), featureInvert = the board has the feature when the capability is false,
      # featureNote = appended to "has" on boards that also have capability featureNoteWhen
      $entry.Feature = "$($c.feature)"; $entry.FeatureOn = "$($c.featureOn)"; $entry.FeatureOff = "$($c.featureOff)"
      $entry.FeatureInvert = ("$($c.featureInvert)" -eq "true"); $entry.FeatureNote = "$($c.featureNote)"; $entry.FeatureNoteWhen = "$($c.featureNoteWhen)"
      if (($entry.FeatureNote -and -not $entry.FeatureNoteWhen) -or ($entry.FeatureNoteWhen -and -not $entry.FeatureNote)) { Stop-WithError "Capability $($entry.Name): featureNote and featureNoteWhen go together" }
      if (-not $entry.Merge) { $entry.Merge = "any" }
      # switch="true": on/off parameter with device memory (default on); fixedBy: boards that also have that capability
      # show "always on" instead; reportedBy: query bit that says whether the firmware has it (default: own bit)
      $sw = "$($c.switch)"
      if ($sw -and $sw -ne "true" -and $sw -ne "false") { Stop-WithError "Capability $($entry.Name): switch must be true or false" }
      if ($sw -eq "true") { $entry.Switch = $true }
      if (-not $entry.Switch -and ($entry.FixedBy -or $entry.ReportedBy)) { Stop-WithError "Capability $($entry.Name): fixedBy/reportedBy need switch=`"true`"" }
      if ($entry.Merge -ne "any" -and $entry.Merge -ne "all") { Stop-WithError "Capability $($entry.Name): merge must be any or all" }
      # runtime="true": the board has the place for it (expr), the firmware detects the part at run time and reports it
      # through answerQuery(runtimeCaps); its bit is not part of OWN_CAPS
      $rt = "$($c.runtime)"
      if ($rt -and $rt -ne "true" -and $rt -ne "false") { Stop-WithError "Capability $($entry.Name): runtime must be true or false" }
      $entry.Runtime = ($rt -eq "true")
      if ($entry.Name -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError "Capability name must be alphanumeric: $($entry.Name)" }
      if ($capIndex.ContainsKey($entry.Name)) { $m.Capabilities[$capIndex[$entry.Name]] = $entry }
      else { $capIndex[$entry.Name] = $m.Capabilities.Count; $m.Capabilities.Add($entry) }
    }
    foreach ($v in $src.SelectNodes("Value")) {
      $entry = @{ Name = $v.name; Text = $v.text; Expr = "$($v.expr)"; IfDef = "$($v.ifdef)"; Default = [int]"$($v.default)"; Max = [int]"$($v.max)"; Unit = "$($v.unit)"; Sets = @(); Query = $true }
      # relays="true": the value counts relays; the first HW_RELAY_COUNT are the board's hard-wired relays, every further one
      # takes a port (developer view row of <Page features>)
      $rl = "$($v.relays)"
      if ($rl -and $rl -ne "true" -and $rl -ne "false") { Stop-WithError "Value $($entry.Name): relays must be true or false" }
      $entry.Relays = ($rl -eq "true")
      # names="a b c": display name of value 0, 1, 2, ... (developer view)
      $entry.Names = @("$($v.names)" -split '\s+' | Where-Object { $_ })
      # query="false": the value exists only in ETS (feature flags, capability page); the device query and the firmware
      # header leave it out, so a <Set> value can coexist with <Output header>
      $q = "$($v.query)"
      if ($q -and $q -ne "true" -and $q -ne "false") { Stop-WithError "Value $($entry.Name): query must be true or false" }
      if ($q -eq "false") { $entry.Query = $false }
      # <Set board="pattern" value="n"/>: value of the matching boards (ETS only); a define without * or ? wins
      # over a pattern, two matching entries of the same kind stop the run
      foreach ($st in $v.SelectNodes("Set")) {
        $sv = ConvertFrom-CInteger "$($st.value)"
        if (-not "$($st.board)" -or $null -eq $sv) { Stop-WithError "Value $($entry.Name): <Set> needs board=... and a number value=..." }
        $entry.Sets += @{ Board = "$($st.board)"; Value = [int]$sv; Pattern = ("$($st.board)" -match '[\*\?]') }
      }
      if ($entry.Expr) {
        if (-not $entry.IfDef -and $entry.Expr -match '^[A-Za-z_][A-Za-z0-9_]*$') { $entry.IfDef = $entry.Expr }
        if (-not $entry.IfDef) { Stop-WithError "Value $($entry.Name): expr is not a macro name - set ifdef=`"<macro that must exist>`"" }
      }
      elseif ($entry.Sets.Count -eq 0) { Stop-WithError "Value $($entry.Name): needs expr=... or <Set> entries" }
      if ($entry.Name -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError "Value name must be alphanumeric: $($entry.Name)" }
      if ($entry.Max -lt 1 -or $entry.Max -gt 255) { Stop-WithError "Value $($entry.Name): max must be 1..255" }
      if ($valIndex.ContainsKey($entry.Name)) { $m.Values[$valIndex[$entry.Name]] = $entry }
      else { $valIndex[$entry.Name] = $m.Values.Count; $m.Values.Add($entry) }
    }
    foreach ($rp in $src.SelectNodes("ReservedPins")) {
      foreach ($mac in ("$($rp.macros)" -split '\s+')) { if ($mac -and -not ($m.Reserved -contains $mac)) { $m.Reserved += $mac } }
    }
  }
  if ($m.Capabilities.Count -gt $MAX_CAPABILITIES) { Stop-WithError "At most $MAX_CAPABILITIES capabilities fit the device query" }
  $switchCount = 0
  foreach ($c in $m.Capabilities) {
    if (-not $c.Switch) { continue }
    $switchCount++
    foreach ($ref in @($c.FixedBy, $c.ReportedBy)) {
      if ($ref -and -not $capIndex.ContainsKey($ref)) { Stop-WithError "Capability $($c.Name): unknown capability $ref" }
    }
    if ($c.FixedBy -eq $c.Name) { Stop-WithError "Capability $($c.Name): fixedBy must name another capability" }
    # a runtime part is detected by the firmware: it cannot fix a switch on, and its own state is its own bit
    if ($c.FixedBy -and $m.Capabilities[$capIndex[$c.FixedBy]].Runtime) { Stop-WithError "Capability $($c.Name): fixedBy=`"$($c.FixedBy)`" is a runtime capability (only a build-time capability can fix a switch on)" }
    if ($c.Runtime -and $c.ReportedBy -and $c.ReportedBy -ne $c.Name) { Stop-WithError "Capability $($c.Name): runtime=`"true`" reports its own bit - remove reportedBy" }
  }
  if ($switchCount -gt $MAX_SWITCHES) { Stop-WithError "At most $MAX_SWITCHES capabilities with switch=`"true`" (one byte)" }
  foreach ($c in $m.Capabilities) {
    if ($c.FeatureNoteWhen -and -not $capIndex.ContainsKey($c.FeatureNoteWhen)) { Stop-WithError "Capability $($c.Name): featureNoteWhen names an unknown capability $($c.FeatureNoteWhen)" }
  }
  if (@($m.Values | Where-Object { $_.Query }).Count -gt $MAX_VALUES) { Stop-WithError "At most $MAX_VALUES values fit the device query (query=`"false`" leaves a value out)" }

  foreach ($b in $root.SelectNodes("Board")) { $m.Boards.Add(@{ Define = $b.define; Flags = (ConvertTo-FlagList "$($b.flags)") }) }
  # <Boards platformio="release_*" [project="."]/>: the envs of the PlatformIO project (default: the manifest's folder)
  $m.EnvPatterns = @($root.SelectNodes("Boards") | Where-Object { "$($_.platformio)" } | ForEach-Object {
      $proj = "$($_.project)"
      if (-not $proj) { $proj = "." }
      # exclude = env name patterns that are not boards (test or tool envs), separated by blanks
      $ex = @("$($_.exclude)" -split '\s+' | Where-Object { $_ })
      @{ Pattern = "$($_.platformio)"; Exclude = $ex; Project = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $proj)) }
    })
  if ($m.Boards.Count -lt 1 -and $m.EnvPatterns.Count -lt 1) { Stop-WithError "No <Board> or <Boards platformio=...> entry" }

  # <Ports board="pattern" use="1 3 5-8"/>: the hardware port numbers offered on the matching boards
  $m.PortSets = New-Object System.Collections.Generic.List[object]
  foreach ($ps in $root.SelectNodes("Ports")) {
    $pat = "$($ps.board)"; $use = "$($ps.use)"
    # excludeRelayPins="true": a port whose GPIO is a relay of the board (HW_RELAY_<n>_GPIO) is not offered
    $xr = "$($ps.excludeRelayPins)"
    if ($xr -and $xr -ne "true" -and $xr -ne "false") { Stop-WithError ("<Ports board=`"{0}`">: excludeRelayPins must be true or false" -f $pat) }
    # max="n": the highest port number the product can store (its value layout); a board with more ports stops the run
    $mx = "$($ps.max)"
    if ($mx -and ($mx -notmatch '^\d+$' -or [int]$mx -lt 1 -or [int]$mx -gt $MAX_PORTS)) { Stop-WithError ("<Ports board=`"{0}`">: max must be 1..{1}" -f $pat, $MAX_PORTS) }
    if (-not $pat -or (-not $use -and $xr -ne "true" -and -not $mx)) { Stop-WithError "<Ports> needs board=... and use=... (or excludeRelayPins=`"true`" or max=...)" }
    $nums = @()
    foreach ($tok in @($use -split '\s+' | Where-Object { $_ })) {
      if ($tok -match '^(\d+)-(\d+)$') { $from = [int]$Matches[1]; $to = [int]$Matches[2] }
      elseif ($tok -match '^\d+$') { $from = [int]$tok; $to = $from }
      else { Stop-WithError ("<Ports board=`"{0}`">: use `"{1}`" - expected port numbers or ranges like 1 3 5-8" -f $pat, $tok) }
      if ($from -lt 1 -or $to -gt $MAX_PORTS -or $to -lt $from) { Stop-WithError ("<Ports board=`"{0}`">: {1} is not within 1..{2}" -f $pat, $tok, $MAX_PORTS) }
      foreach ($n in ($from..$to)) {
        if ($nums -contains $n) { Stop-WithError ("<Ports board=`"{0}`">: port {1} is listed twice" -f $pat, $n) }
        $nums += $n
      }
    }
    if ($mx -and @($nums | Where-Object { $_ -gt [int]$mx }).Count -gt 0) { Stop-WithError ("<Ports board=`"{0}`">: use lists a port above max {1}" -f $pat, $mx) }
    $m.PortSets.Add(@{ Board = $pat; Use = @($nums | Sort-Object); All = (-not $use); ExcludeRelayPins = ($xr -eq "true"); Max = $(if ($mx) { [int]$mx } else { 0 }); Hits = 0 })
  }

  # number = part of the ETS parameter ID: fixed in the manifest, so reordering roles moves nothing
  $usedNumbers = @{}
  foreach ($r in $root.SelectNodes("GpioRole")) {
    $role = @{ Name = $r.name; Text = $r.text; Count = [int]"$($r.count)"; Number = [int]"$($r.number)"; Sources = @() }
    if ($role.Name -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError "GpioRole name must be alphanumeric: $($role.Name)" }
    if ($role.Number -lt 1 -or $role.Number -gt 9) { Stop-WithError "GpioRole $($role.Name): number=`"1..9`" is required (part of the parameter ID, never change it)" }
    if ($usedNumbers.ContainsKey($role.Number)) { Stop-WithError "GpioRole $($role.Name): number $($role.Number) is used twice" }
    if (@($m.Roles | Where-Object { $_.Name -eq $role.Name }).Count -gt 0) { Stop-WithError "GpioRole name $($role.Name) is used twice" }
    $usedNumbers[$role.Number] = $true
    if ($role.Count -lt 1 -or $role.Count -gt 9) { Stop-WithError "GpioRole $($role.Name): count must be 1..9" }
    foreach ($p in $r.SelectNodes("Pins")) {
      $label = "$($p.label)"
      if (-not $label) { $label = '$0' }   # default: the macro name
      $src = @{ Board = $p.board; Scan = $p.scan; Label = $label; Pins = @() }
      foreach ($pin in $p.SelectNodes("Pin")) {
        $pl = "$($pin.label)"
        if (-not $pl) { $pl = "$($pin.gpio)" }   # default: the macro name
        $src.Pins += @{ Gpio = $pin.gpio; Label = $pl }
      }
      $role.Sources += $src
    }
    $m.Roles.Add($role)
  }
  if ($m.Roles.Count -gt 9) { Stop-WithError "At most 9 GPIO roles" }

  # <Page text icon help title label intro queryTitle query button queryHelp queryImage unselectedTitle infoDefault unselectedInfo
  # unselectedText updateInfo features dev/>: the hardware page as an OpenKNX page (the OAM includes ParameterBlock Profile into a
  # channel of its choice): page text and icon (assets/icons/<icon>.png is copied next to the share as Baggages/Icons/<icon>.png),
  # the page texts (an attribute that is absent takes the default below, an empty one leaves the text out; &#10; = line break;
  # {page} = page text, {button} = button text): title = headline, label = text of the selection, intro under the headline;
  # queryTitle, query, the query button, queryHelp, queryImage and the unselected* / updateInfo texts only while no board is
  # selected; unselectedTitle = page text in the tree while no board is selected (empty = always the page text); infoDefault =
  # board text of boards without HW_INFO_TEXT. features = capability and value names of the developer view section "Module und
  # Funktionen"; dev = file of the developer view module (own op:define, only in the OAM's development product); help =
  # HelpContext of the page (the OAM ships Help_<lang>/<help>.md)
  $m.Page = $null
  $pg = $root.SelectSingleNode("Page")
  if ($pg) {
    $pageText = {
      param([string]$Attr, [string]$Default)
      # a literal line break in an attribute is a space (XML attribute normalization), &#10; stays a line break
      if ($pg.HasAttribute($Attr)) { return (("$($pg.GetAttribute($Attr))" -replace "`r", '' -replace '[ \t]+', ' ' -replace ' ?\n ?', "`n").Trim()) }
      return [regex]::Unescape($Default)
    }
    foreach ($a in @("more", "summary", "portsText", "portsTextOne")) {
      if ($pg.HasAttribute($a)) { Stop-WithError "<Page>: attribute $a is no longer used (the device card shows name and board text) - remove it" }
    }
    $introDefault = 'Diese Applikation gilt f\u00FCr mehrere Ger\u00E4te. W\u00E4hlen Sie das Ger\u00E4t aus, das verbaut ist. Erst dann sind seine Anschl\u00FCsse und Einstellungen sichtbar.'
    if ($m.Unselected -eq "showAll") { $introDefault = 'Diese Applikation gilt f\u00FCr mehrere Ger\u00E4te. W\u00E4hlen Sie das Ger\u00E4t aus, das verbaut ist. Danach sind nur seine Anschl\u00FCsse und Einstellungen sichtbar.' }
    $m.Page = @{ Text = "$($pg.text)"; Icon = "$($pg.icon)"; Help = "$($pg.help)"; Features = @("$($pg.features)" -split '\s+' | Where-Object { $_ }); Dev = $null; IconFile = $null
      Title           = (& $pageText "title" 'Ger\u00E4t ausw\u00E4hlen')
      Label           = (& $pageText "label" 'Ger\u00E4tetyp')
      Intro           = (& $pageText "intro" $introDefault)
      QueryTitle      = (& $pageText "queryTitle" 'Oder automatisch erkennen')
      Query           = (& $pageText "query" '')
      Button          = (& $pageText "button" 'Vom Ger\u00E4t lesen')
      QueryHelp       = (& $pageText "queryHelp" '\u201E{button}\u201C ist grau/inaktiv?\n1. Physikalische Adresse programmieren (wenn n\u00F6tig: Programmiertaste dr\u00FCcken).\n2. Links eine andere Seite anklicken, dann zur\u00FCck auf diese Seite.\n3. Button klicken: Ger\u00E4tetyp wird ausgelesen und eingestellt.')
      UnselectedTitle = (& $pageText "unselectedTitle" '{page} (nicht gew\u00E4hlt)')
      InfoDefault     = (& $pageText "infoDefault" 'Die Einstellungen dieser Applikation sind auf diese Hardware abgestimmt.')
      UnselectedInfo  = (& $pageText "unselectedInfo" '')
      UnselectedText  = (& $pageText "unselectedText" '')
      UpdateInfo      = (& $pageText "updateInfo" '')
      ChangeInfo      = (& $pageText "changeInfo" '')
      Firmware        = (& $pageText "firmware" '')
      ImageFile       = $null
    }
    if (-not $m.Page.Text) { $m.Page.Text = $m.Text }
    # with unselectedTitle the tree text is "{{0:<text>}}", 6 characters more
    $textMax = 255; if ($m.Page.UnselectedTitle) { $textMax = 249 }
    if ($m.Page.Text.Length -gt $textMax) { Stop-WithError ("<Page>: text has {0} characters, at most {1} (ETS shows 255; unselectedTitle adds {{{{0:...}}}})" -f $m.Page.Text.Length, $textMax) }
    # one-line texts (tree, headlines, selection, button): a line break there is an error, not a layout
    foreach ($k in @("Text", "Title", "Label", "QueryTitle", "Button", "UnselectedTitle")) {
      if ($m.Page[$k] -match "[`r`n]") { Stop-WithError ("<Page>: {0} must be one line (no &#10;)" -f ($k.Substring(0, 1).ToLower() + $k.Substring(1))) }
    }
    if (-not $m.Page.Button) { Stop-WithError "<Page>: button must not be empty (text of the query button)" }
    if (-not $m.Page.Label) { Stop-WithError "<Page>: label must not be empty (text of the selection)" }
    foreach ($k in @("Title", "Label", "Intro", "QueryTitle", "Query", "Button", "QueryHelp", "UnselectedTitle", "InfoDefault", "UnselectedInfo", "UnselectedText", "UpdateInfo", "ChangeInfo")) {
      $m.Page[$k] = $m.Page[$k].Replace("{button}", $m.Page.Button).Replace("{page}", $m.Page.Text)
      if ($k -eq "QueryHelp") { continue }
      if ($m.Page[$k].Length -gt 255) { Stop-WithError ("<Page>: {0} has {1} characters, ETS shows at most 255" -f ($k.Substring(0, 1).ToLower() + $k.Substring(1)), $m.Page[$k].Length) }
    }
    # queryHelp: one information box per part of at most 255 characters, split at line breaks (ETS: 255 characters per text)
    $m.Page.QueryHelpParts = @()
    $cur = ""
    foreach ($line in ($m.Page.QueryHelp -split "`n")) {
      if ($line.Length -gt 255) { Stop-WithError ("<Page>: a line of queryHelp has {0} characters, ETS shows at most 255: {1}" -f $line.Length, $line) }
      if ($cur -and ($cur.Length + 1 + $line.Length) -gt 255) { $m.Page.QueryHelpParts += $cur; $cur = "" }
      if ($cur) { $cur = $cur + "`n" + $line } else { $cur = $line }
    }
    if ($cur) { $m.Page.QueryHelpParts += $cur }
    # queryImage: picture under queryHelp (one-column grid); absent = the generator's steps picture, empty = none
    $imgAttr = [System.IO.Path]::Combine($PSScriptRoot, "assets", "query-steps.png")
    if ($pg.HasAttribute("queryImage")) { $imgAttr = "$($pg.queryImage)"; if ($imgAttr) { $imgAttr = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $imgAttr)) } }
    if ($imgAttr) {
      if (-not (Test-Path -LiteralPath $imgAttr -PathType Leaf)) { Stop-WithError ("<Page>: queryImage file not found: {0}" -f $imgAttr) }
      $m.Page.ImageFile = $imgAttr
    }
    if (-not $m.Page.Icon) { $m.Page.Icon = "cog-outline" }
    if ($m.Page.Icon -notmatch '^[a-z0-9][a-z0-9-]*$') { Stop-WithError "<Page>: icon must be an icon name (a-z, 0-9, -)" }
    if ($m.Page.Help -and $m.Page.Help -notmatch '^[A-Za-z0-9_-]+$') { Stop-WithError "<Page>: help must be a help context name (A-Z, a-z, 0-9, _, -)" }
    $own = [System.IO.Path]::Combine($PSScriptRoot, "assets", "icons", $m.Page.Icon + ".png")
    if (Test-Path -LiteralPath $own) { $m.Page.IconFile = $own }
    if ("$($pg.dev)") { $m.Page.Dev = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, "$($pg.dev)")) }
    if (-not $m.Outputs.ContainsKey("share")) { Stop-WithError "<Page> needs <Output share=...>" }
    foreach ($f in $m.Page.Features) {
      if ($f -eq "Ports") { Stop-WithError "<Page features>: Ports has its own section in the developer view - remove it from the list" }
      if (-not $capIndex.ContainsKey($f) -and -not $valIndex.ContainsKey($f)) { Stop-WithError "<Page features>: $f is neither a capability nor a value" }
    }
  }
  # <Notice when="Capability" title="...">text</Notice>: information on the page for boards with that capability; <Text>
  # children are the parts, else the text is split at sentence ends (ETS limits a text to 255 characters)
  $m.Notices = @()
  foreach ($nt in $root.SelectNodes("Notice")) {
    $nn = @{ When = "$($nt.when)"; Title = ("$($nt.title)" -replace '\s+', ' ').Trim(); Parts = @() }
    if (-not $nn.When -or -not $nn.Title) { Stop-WithError "<Notice> needs when=... and title=..." }
    if (-not $capIndex.ContainsKey($nn.When)) { Stop-WithError "<Notice when=`"$($nn.When)`">: unknown capability" }
    if ($nn.Title.Length -gt 255) { Stop-WithError "<Notice when=`"$($nn.When)`">: title is longer than 255 characters (ETS limit)" }
    $tn = @($nt.SelectNodes("Text"))
    if ($tn.Count -gt 0) { $nn.Parts = @($tn | ForEach-Object { ("$($_.InnerText)" -replace '\s+', ' ').Trim() } | Where-Object { $_ }) }
    else {
      # the function returns its array as one object: assign it directly (@() would nest it into one part)
      try { $nn.Parts = [string[]](Split-SentenceText (("$($nt.InnerText)" -replace '\s+', ' ').Trim()) 255) }
      catch { Stop-WithError ("<Notice when=`"{0}`">: {1}" -f $nn.When, $_.Exception.Message) }
    }
    foreach ($part in $nn.Parts) {
      if ($part.Length -gt 255) { Stop-WithError ("<Notice when=`"{0}`">: a <Text> has {1} characters, ETS shows at most 255" -f $nn.When, $part.Length) }
    }
    $m.Notices += $nn
  }

  # <InfoImage define="HW_INFO_URL" default="" module="2" version="3" width="150" urlFont="NotoSans-Regular-44" supersample="4"
  #   urlColor="#0067C0" logo="..." badge="..." thirdPartyWhen="ThirdParty"/>: device card on the <Page> (ETS elements, no text in
  #   pictures except the link): OpenKNX logo, or the third-party badge on boards with capability thirdPartyWhen; DEVICE_NAME as
  #   headline; board text (HW_INFO_TEXT, else <Page infoDefault>); with an info URL (define in the board header, else default;
  #   empty default = no QR code) a grid: board text | picture "QR code + link" (width px, QR v<version> EC M,
  #   <module> px per module, white quiet zone, link without scheme in one line, glyph atlas urlFont = supersample x the size).
  #   logo / badge: PNG paths relative to the manifest (default: generator assets card-badge.png / third-party-badge.png)
  $m.Info = $null
  $ii = $root.SelectSingleNode("InfoImage")
  if ($ii) {
    if (-not $m.Page) { Stop-WithError "<InfoImage> needs <Page> (the device card is part of the hardware page)" }
    if (-not $m.Outputs.ContainsKey("share")) { Stop-WithError "<InfoImage> needs <Output share=...> (the images are baggages of the ETS module)" }
    $allowed = @("define", "default", "style", "module", "version", "width", "urlFont", "supersample", "urlColor", "logo", "badge", "thirdPartyWhen")
    foreach ($at in $ii.Attributes) {
      if ($allowed -cnotcontains $at.Name) { Stop-WithError ("<InfoImage>: attribute {0} is not supported (allowed: {1})" -f $at.Name, ($allowed -join ", ")) }
    }
    if ($ii.HasAttribute("style") -and "$($ii.style)" -ne "card") { Stop-WithError "<InfoImage>: style must be card (or absent)" }
    $assets = [System.IO.Path]::Combine($PSScriptRoot, "assets")
    $m.Info = @{ Define = "$($ii.define)"; Default = "$($ii.default)"; Module = 2; Version = 3; Width = 150; UrlFont = "NotoSans-Regular-44"; Supersample = 4
      UrlRgb = [byte[]](0x00, 0x67, 0xC0); Logo = [System.IO.Path]::Combine($assets, "card-badge.png"); Badge = [System.IO.Path]::Combine($assets, "third-party-badge.png")
      ThirdWhen = "ThirdParty" }
    if (-not $m.Info.Define) { $m.Info.Define = "HW_INFO_URL" }
    if ($m.Info.Define -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { Stop-WithError "<InfoImage>: define must be a macro name" }
    foreach ($a in @(@("module", "Module", 1, 10), @("version", "Version", 1, 40), @("width", "Width", 40, 400), @("supersample", "Supersample", 1, 8))) {
      if (-not $ii.HasAttribute($a[0])) { continue }
      $v = ConvertFrom-CInteger "$($ii.GetAttribute($a[0]))"
      if ($null -eq $v -or $v -lt $a[2] -or $v -gt $a[3]) { Stop-WithError ("<InfoImage>: {0} must be {1}..{2}" -f $a[0], $a[2], $a[3]) }
      $m.Info[$a[1]] = [int]$v
    }
    if ($ii.HasAttribute("urlFont")) { $m.Info.UrlFont = "$($ii.urlFont)" }
    if ($m.Info.UrlFont -notmatch '^[A-Za-z0-9.-]+$') { Stop-WithError "<InfoImage>: urlFont must be an atlas name of assets/fonts" }
    if ($ii.HasAttribute("urlColor")) {
      $hex = "$($ii.urlColor)"
      if ($hex -notmatch '^#[0-9A-Fa-f]{6}$') { Stop-WithError "<InfoImage>: urlColor must be #RRGGBB" }
      $m.Info.UrlRgb = [byte[]]([Convert]::ToByte($hex.Substring(1, 2), 16), [Convert]::ToByte($hex.Substring(3, 2), 16), [Convert]::ToByte($hex.Substring(5, 2), 16))
    }
    # logo / badge: picture of the OpenKNX / third-party boards; an empty attribute = no picture
    foreach ($a in @(@("logo", "Logo"), @("badge", "Badge"))) {
      if ($ii.HasAttribute($a[0])) {
        $f = "$($ii.GetAttribute($a[0]))"
        if ($f) { $m.Info[$a[1]] = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $f)) } else { $m.Info[$a[1]] = "" }
      }
      if ($m.Info[$a[1]] -and -not (Test-Path -LiteralPath $m.Info[$a[1]] -PathType Leaf)) { Stop-WithError ("<InfoImage>: {0} file not found: {1}" -f $a[0], $m.Info[$a[1]]) }
    }
    # <Logo board="pattern" file="path"/>: picture of the matching boards instead of logo / badge, file="" = none; a define
    # without * or ? wins over a pattern, two matching entries of the same kind stop the run
    $m.Info.Logos = @()
    foreach ($lg in $ii.SelectNodes("Logo")) {
      if (-not "$($lg.board)" -or -not $lg.HasAttribute("file")) { Stop-WithError "<InfoImage><Logo> needs board=... and file=... (empty file = no picture)" }
      $f = "$($lg.file)"
      if ($f) {
        $f = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $f))
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { Stop-WithError ("<InfoImage><Logo board=`"{0}`">: file not found: {1}" -f $lg.board, $f) }
      }
      $m.Info.Logos += @{ Board = "$($lg.board)"; File = $f; Pattern = ("$($lg.board)" -match '[\*\?]') }
    }
    if ($ii.HasAttribute("thirdPartyWhen")) {
      $m.Info.ThirdWhen = "$($ii.thirdPartyWhen)"
      if ($m.Info.ThirdWhen -and -not $capIndex.ContainsKey($m.Info.ThirdWhen)) { Stop-WithError "<InfoImage>: thirdPartyWhen names an unknown capability $($m.Info.ThirdWhen)" }
    }
    elseif (-not $capIndex.ContainsKey($m.Info.ThirdWhen)) { $m.Info.ThirdWhen = "" }
  }
  # <Conflicts>: optional GPIO conflict check (one ParameterCalculation); absent = no output changes
  $m.Conflicts = $null
  $cfNodes = @($root.SelectNodes("Conflicts"))
  if ($cfNodes.Count -gt 1) { Stop-WithError "<Conflicts> may appear only once" }
  if ($cfNodes.Count -eq 1) { $m.Conflicts = Read-ConflictsNode $m $cfNodes[0] $baseDir }
  # <BoardTable name header scan>: integer macros of an OAM header per board (index = group 1 of scan); absent = no output changes
  $m.BoardTables = @()
  foreach ($bt in $root.SelectNodes("BoardTable")) {
    foreach ($at in $bt.Attributes) {
      if (@("name", "header", "scan") -cnotcontains $at.Name) { Stop-WithError ("<BoardTable>: attribute {0} is not supported (allowed: name, header, scan)" -f $at.Name) }
    }
    $t = @{ Name = "$($bt.name)"; HeaderAttr = "$($bt.header)"; Scan = "$($bt.scan)"; Found = $false }
    if ($t.Name -notmatch '^[A-Za-z0-9]+$') { Stop-WithError ("<BoardTable name=`"{0}`">: name must be letters and digits" -f $t.Name) }
    if (@($m.BoardTables | Where-Object { $_.Name -eq $t.Name }).Count -gt 0) { Stop-WithError ("<BoardTable name=`"{0}`">: name used twice" -f $t.Name) }
    if (-not $t.HeaderAttr) { Stop-WithError ("<BoardTable name=`"{0}`">: header=... is missing" -f $t.Name) }
    $t.Header = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($baseDir, $t.HeaderAttr))
    if (-not (Test-Path -LiteralPath $t.Header -PathType Leaf)) { Stop-WithError ("<BoardTable name=`"{0}`">: header not found: {1}" -f $t.Name, $t.Header) }
    try { $rx = New-Object System.Text.RegularExpressions.Regex($t.Scan) }
    catch { Stop-WithError ("<BoardTable name=`"{0}`">: scan is no regular expression: {1}" -f $t.Name, $t.Scan) }
    # exactly one numbered group: a named group (?<i>...) is not read as group 1
    $named = @($rx.GetGroupNames() | Where-Object { $_ -notmatch '^\d+$' })
    if (-not $t.Scan -or $rx.GetGroupNumbers().Count -ne 2 -or $named.Count -gt 0) { Stop-WithError ("<BoardTable name=`"{0}`">: scan needs exactly one unnamed group (the index), e.g. ^NAME_(\d+)`$: {1}" -f $t.Name, $t.Scan) }
    $m.BoardTables += $t
  }
  if ($m.BoardTables.Count -gt 0 -and -not $m.Outputs.ContainsKey("script")) { Stop-WithError "<BoardTable> needs <Output script=...> (the table is part of the ETS script)" }
  return $m
}

# @brief Preprocessor run of a <BoardTable>: on a failure stop with the table name, the header and the first compiler error
function Invoke-BoardTablePreprocessor($Table, [string]$Define, [string]$Source, [string[]]$Defines, [switch]$MacroList) {
  try { return (Invoke-Preprocessor -Source $Source -Defines $Defines -MacroList:$MacroList) }
  catch {
    $err = "$($_.Exception.Message)"
    $first = [regex]::Match($err, '\S*:\d+:\d+:\s*(fatal\s+)?error:[^|]*')
    if ($first.Success) { $err = $first.Value.Trim() }
    Stop-WithError ("{0}: <BoardTable name=`"{1}`">: preprocessing {2} failed: {3}" -f $Define, $Table.Name, $Table.HeaderAttr, $err)
  }
}

# @brief <BoardTable> values of one env/board: macros of HardwareConfig.h + the table header whose name matches scan,
#        index = group 1, value = the expanded integer; returns index -> value
function Get-BoardTableValues($Table, [string]$Define, [string[]]$Defines) {
  $src = "#include `"HardwareConfig.h`"`n#include `"" + ($Table.Header -replace '\\', '/') + "`"`n"
  $names = @(Invoke-BoardTablePreprocessor $Table $Define $src $Defines -MacroList |
    ForEach-Object { if ("$_" -match '^#define (\w+)') { $Matches[1] } } | Where-Object { $_ -cmatch $Table.Scan } | Sort-Object -CaseSensitive -Unique)
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
    if ($null -eq $idx -or $idx -gt 1023) { Stop-WithError ("{0}: <BoardTable name=`"{1}`">: {2} - group 1 of scan must be an index 0..1023, is '{3}'" -f $Define, $Table.Name, $names[$i], $grp) }
    if ($vals.ContainsKey($idx)) { Stop-WithError ("{0}: <BoardTable name=`"{1}`">: two macros for index {2} ({3}, {4})" -f $Define, $Table.Name, $idx, $seen[$idx], $names[$i]) }
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
        if ($ct -eq 'char') { Stop-WithError ("{0}: {1}: {2} = '{3}': a plain (char) cast depends on the target, use int8_t or uint8_t" -f $Define, $Table.HeaderAttr, $names[$i], $res["BT$i"]) }
        $casts.Add($ct)
        $lim = @{ 'uint8_t' = 255; 'unsigned char' = 255; 'int8_t' = 127; 'signed char' = 127; 'uint16_t' = 65535; 'unsigned short' = 65535; 'int16_t' = 32767; 'short' = 32767 }
        if ($lim.ContainsKey($ct) -and $lim[$ct] -lt $max) { $max = [long]$lim[$ct] }
        continue
      }
      if ($vt -match '^\((.*)\)$') { $vt = $Matches[1].Trim(); continue }
      break
    }
    $v = ConvertFrom-CInteger $vt
    if ($null -eq $v -or $v -lt 0) { Stop-WithError ("{0}: {1}: {2} = '{3}' does not resolve to an integer 0..2147483647" -f $Define, $Table.HeaderAttr, $names[$i], $res["BT$i"]) }
    if ($v -gt $max) { Stop-WithError ("{0}: {1}: {2} = '{3}': {4} is outside the range of the cast ({5}, 0..{6})" -f $Define, $Table.HeaderAttr, $names[$i], $res["BT$i"], $v, ($casts -join ', '), $max) }
    $vals[[int]$idx] = [long]$v
  }
  return $vals
}

# @brief Integer attribute of a <Conflicts>/<Use> element: $null when absent, stop when not a number in Min..Max
function Get-ConflictInt($Node, [string]$Attr, [int]$Min, [int]$Max, [string]$Where) {
  if (-not $Node.HasAttribute($Attr)) { return $null }
  $t = "$($Node.GetAttribute($Attr))".Trim()
  if ($t -notmatch '^\d+$' -or [int64]$t -lt $Min -or [int64]$t -gt $Max) { Stop-WithError ("{0}: {1} must be a number {2}..{3}" -f $Where, $Attr, $Min, $Max) }
  return [int]$t
}

# @brief Condition text -> list of OR groups, each a list of AND terms @{ Param; Op; Values }
#        Syntax: "<Param> <op> <n>" with op == != < <= > >=, or "<Param> in <n> <n> ..."; terms joined by "and" / "or"
#        ("and" binds tighter, no parentheses); and / or / in are lower case, numbers are 32-bit integers
function ConvertFrom-ConflictCondition([string]$Text, [hashtable]$Params, [string]$Where) {
  $t = ($Text -replace '\s+', ' ').Trim()
  if (-not $t) { Stop-WithError ("{0}: empty condition" -f $Where) }
  $ops = @{ "==" = "eq"; "!=" = "ne"; "<" = "lt"; "<=" = "le"; ">" = "gt"; ">=" = "ge" }
  $groups = @()
  foreach ($g in ($t -csplit ' or ')) {
    $terms = @()
    foreach ($term in ($g -csplit ' and ')) {
      $term = $term.Trim()
      $tm = $null; $nums = @()
      if ($term -cmatch '^([A-Za-z][A-Za-z0-9]*) ?(==|!=|<=|>=|<|>) ?(-?\d+)$') { $tm = @{ Param = $Matches[1]; Op = $ops[$Matches[2]] }; $nums = @($Matches[3]) }
      elseif ($term -cmatch '^([A-Za-z][A-Za-z0-9]*) in ((-?\d+)( -?\d+)*)$') { $tm = @{ Param = $Matches[1]; Op = "in" }; $nums = @($Matches[2].Split(' ')) }
      if ($tm) {
        $vals = @()
        foreach ($nt in $nums) {
          $iv = 0
          if (-not [int]::TryParse($nt, [ref]$iv)) { Stop-WithError ("{0}: condition '{1}' - {2} is not a 32-bit integer" -f $Where, $term, $nt) }
          $vals += $iv
        }
        $tm.Values = $vals
      }
      else { Stop-WithError ("{0}: condition '{1}' - expected '<Param> <op> <number>' (op == != < <= > >=, in XML &lt; for <) or '<Param> in <number> ...', joined by and / or" -f $Where, $term) }
      if (-not $Params.ContainsKey($tm.Param)) { Stop-WithError ("{0}: condition names {1}, which is no <Param name> of <Conflicts>" -f $Where, $tm.Param) }
      $terms += , $tm
    }
    $groups += , $terms
  }
  return , $groups
}

# @brief Reads <Conflicts output number value manual none error><Param name ref/><Use name text when port value manual none
#        wiredRelay error><Manual ref when/></Use></Conflicts>; board-dependent checks follow in Resolve-Conflicts
function Read-ConflictsNode($M, $Node, [string]$BaseDir) {
  $w = "<Conflicts>"
  $allowed = @("output", "number", "value", "error", "reserved", "reservedError", "tpError")
  foreach ($at in $Node.Attributes) { if ($allowed -cnotcontains $at.Name) { Stop-WithError ("{0}: attribute {1} is not supported (allowed: {2})" -f $w, $at.Name, ($allowed -join ", ")) } }
  if (-not $M.Outputs.ContainsKey("share") -or -not $M.Outputs.ContainsKey("script")) { Stop-WithError "<Conflicts> needs <Output share=... script=...> (the check function is part of the generated script)" }
  $out = "$($Node.GetAttribute('output'))"
  if (-not $out) { Stop-WithError "<Conflicts> needs output=... (file with the parts the application includes)" }
  $num = Get-ConflictInt $Node "number" 1 99999 $w
  if ($null -eq $num) { Stop-WithError "<Conflicts> needs number=... (first parameter number of the conflict flags in the including module, also the calculation number)" }
  $cf = @{ Output = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($BaseDir, $out)); Number = $num; Params = New-Object System.Collections.Generic.List[object]; Uses = New-Object System.Collections.Generic.List[object] }
  $cf.Value = "$($Node.GetAttribute('value'))"; if (-not $cf.Value) { $cf.Value = "port" }
  if ($cf.Value -ne "port" -and $cf.Value -ne "gpio") { Stop-WithError "<Conflicts>: value must be port or gpio" }
  $cf.Error = "$($Node.GetAttribute('error'))"
  if (-not $cf.Error) { $cf.Error = "GPIO-Konflikt: {text} nutzt denselben GPIO wie ein anderer Anschluss, ein fest verdrahtetes Relais oder ein manueller GPIO." }
  # reserved="true": a use on a GPIO the selected board uses itself gets flag 2 (reservedError); on a KNX UART pin of a board
  # that has TP and IP firmware variants flag 3 (tpError, Information)
  $rv = $Node.GetAttribute("reserved")
  if ($rv -and $rv -ne "true" -and $rv -ne "false") { Stop-WithError "<Conflicts>: reserved must be true or false" }
  $cf.Reserved = ($rv -eq "true")
  $cf.ReservedError = $Node.GetAttribute("reservedError")
  $cf.TpError = $Node.GetAttribute("tpError")
  if (($cf.ReservedError -or $cf.TpError) -and -not $cf.Reserved) { Stop-WithError "<Conflicts>: reservedError / tpError need reserved=`"true`"" }
  if (-not $cf.ReservedError) { $cf.ReservedError = [regex]::Unescape('GPIO-Konflikt: {text} nutzt einen GPIO, den die gew\u00E4hlte Hardware selbst belegt (KNX, Taster, LED, Flash-Speicher oder Ethernet).') }
  if (-not $cf.TpError) { $cf.TpError = [regex]::Unescape('Hinweis: {text} nutzt den GPIO der KNX-TP-Schnittstelle dieser Hardware. Eine TP-Firmware lehnt ihn ab, mit einer IP-Firmware ist er frei.') }
  $params = @{}
  foreach ($pn in $Node.SelectNodes("Param")) {
    $pName = $pn.GetAttribute("name"); $pRef = $pn.GetAttribute("ref")
    $pw = "<Conflicts><Param name=`"$pName`">"
    if ($pName -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError ("{0}: name=... is required, alphanumeric" -f $pw) }
    # calculation alias P_<name>: ETS allows 50 characters (String50_t)
    if ($pName.Length -gt 48) { Stop-WithError ("{0}: name has {1} characters, at most 48 (alias P_<name>, ETS limit 50)" -f $pw, $pName.Length) }
    if ($params.ContainsKey($pName)) { Stop-WithError ("{0}: name is used twice" -f $pw) }
    if (-not $pRef -or $pRef.Contains("{{")) { Stop-WithError ("{0}: needs ref=... (a ParamRefId, no board expression)" -f $pw) }
    foreach ($q in $cf.Params) { if ($q.Ref -ceq $pRef) { Stop-WithError ("{0}: ref is also <Param name=`"{1}`">" -f $pw, $q.Name) } }
    $params[$pName] = $true
    $cf.Params.Add(@{ Name = $pName; Ref = $pRef })
  }
  $useNames = @{}
  foreach ($un in $Node.SelectNodes("Use")) {
    $uName = $un.GetAttribute("name")
    $uw = "<Conflicts><Use name=`"$uName`">"
    $uAllowed = @("name", "text", "when", "port", "value", "wiredRelay", "error")
    foreach ($at in $un.Attributes) { if ($uAllowed -cnotcontains $at.Name) { Stop-WithError ("{0}: attribute {1} is not supported (allowed: {2})" -f $uw, $at.Name, ($uAllowed -join ", ")) } }
    if ($uName -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError ("{0}: name=... is required, alphanumeric" -f $uw) }
    # output alias F_<name>: ETS allows 50 characters (String50_t)
    if ($uName.Length -gt 48) { Stop-WithError ("{0}: name has {1} characters, at most 48 (alias F_<name>, ETS limit 50)" -f $uw, $uName.Length) }
    if ($useNames.ContainsKey($uName)) { Stop-WithError ("{0}: name is used twice" -f $uw) }
    $useNames[$uName] = $true
    $u = @{ Name = $uName; Text = ($un.GetAttribute("text") -replace '\s+', ' ').Trim(); Port = $un.GetAttribute("port"); When = $null; Manuals = @(); Index = $cf.Uses.Count }
    if (-not $u.Text) { $u.Text = $uName }
    $u.Value = "$($un.GetAttribute('value'))"; if (-not $u.Value) { $u.Value = $cf.Value }
    if ($u.Value -ne "port" -and $u.Value -ne "gpio") { Stop-WithError ("{0}: value must be port or gpio" -f $uw) }
    # manual / none: the port value encoding of the root (portManualValue / portNoneValue); a GPIO value has none (10 is GPIO 10)
    $u.Manual = $null; $u.None = $null
    if ($u.Value -eq "port") { $u.Manual = $M.PortManual; $u.None = $M.PortNone }
    $u.Wired = Get-ConflictInt $un "wiredRelay" 1 $MAX_RELAYS $uw; if ($null -eq $u.Wired) { $u.Wired = 0 }
    if (-not $u.Port -and $u.Wired -eq 0) { Stop-WithError ("{0}: needs port=... (selection parameter) or wiredRelay=... (hard-wired relay)" -f $uw) }
    if ($un.HasAttribute("when")) {
      if (-not $u.Port) { Stop-WithError ("{0}: when=... needs port=... (a hard-wired relay pin is always occupied)" -f $uw) }
      $u.When = ConvertFrom-ConflictCondition $un.GetAttribute("when") $params $uw
    }
    $u.Error = "$($un.GetAttribute('error'))"; if (-not $u.Error) { $u.Error = $cf.Error }
    $u.ErrorText = $u.Error.Replace("{text}", $u.Text)
    if ($u.ErrorText.Length -gt 255) { Stop-WithError ("{0}: the error text has {1} characters, ETS shows at most 255" -f $uw, $u.ErrorText.Length) }
    $u.ReservedText = $cf.ReservedError.Replace("{text}", $u.Text)
    $u.TpText = $cf.TpError.Replace("{text}", $u.Text)
    if ($cf.Reserved -and $u.ReservedText.Length -gt 255) { Stop-WithError ("{0}: the reservedError text has {1} characters, ETS shows at most 255" -f $uw, $u.ReservedText.Length) }
    if ($cf.Reserved -and $u.TpText.Length -gt 255) { Stop-WithError ("{0}: the tpError text has {1} characters, ETS shows at most 255" -f $uw, $u.TpText.Length) }
    $defaultSeen = $false
    foreach ($mn in $un.SelectNodes("Manual")) {
      $mw = "$uw <Manual>"
      if ($defaultSeen) { Stop-WithError ("{0}: follows a <Manual> without when=... and is never used" -f $mw) }
      $mRef = $mn.GetAttribute("ref")
      if (-not $mRef -or $mRef.Contains("{{")) { Stop-WithError ("{0}: needs ref=... (ParamRefId of the manual GPIO, no board expression)" -f $mw) }
      $mWhen = $null
      if ($mn.HasAttribute("when")) { $mWhen = ConvertFrom-ConflictCondition $mn.GetAttribute("when") $params $mw } else { $defaultSeen = $true }
      $u.Manuals += , @{ Ref = $mRef; When = $mWhen }
    }
    if ($u.Manuals.Count -gt 0 -and $u.Value -ne "port") { Stop-WithError ("{0}: <Manual> needs value=`"port`" (a GPIO value has no manual entry)" -f $uw) }
    if ($u.Manuals.Count -gt 0 -and $null -eq $u.Manual) { Stop-WithError ("{0}: <Manual> needs portManualValue=... on <HardwareProfile> (the port value of the manual GPIO)" -f $uw) }
    if (-not $u.Port -and ($u.Manuals.Count -gt 0)) { Stop-WithError ("{0}: <Manual> needs port=..." -f $uw) }
    $cf.Uses.Add($u)
  }
  if ($cf.Uses.Count -lt 2) { Stop-WithError "<Conflicts> needs at least two <Use> entries" }
  # <ChannelBlock name text uses>: one UI block for a channel template of the OpenKNXproducer (%C% = channel 1..9): the n-th
  # use of "uses" is channel n; its flag number ends in n, so the block names the flag of its channel through %C%
  # (the producer substitutes %C% in the included content, not in an op:include xpath)
  $cf.Channels = New-Object System.Collections.Generic.List[object]
  foreach ($cn in $Node.SelectNodes("ChannelBlock")) {
    $cName = $cn.GetAttribute("name")
    $cw = "<Conflicts><ChannelBlock name=`"$cName`">"
    if ($cName -notmatch '^[A-Za-z][A-Za-z0-9]*$') { Stop-WithError ("{0}: name=... is required, alphanumeric" -f $cw) }
    if (@($cf.Channels | Where-Object { $_.Name -eq $cName }).Count -gt 0) { Stop-WithError ("{0}: name is used twice" -f $cw) }
    $cText = ($cn.GetAttribute("text") -replace '\s+', ' ').Trim()
    if (-not $cText) { Stop-WithError ("{0}: needs text=... (e.g. with %C%)" -f $cw) }
    $names = @($cn.GetAttribute("uses") -split '\s+' | Where-Object { $_ })
    if ($names.Count -lt 1 -or $names.Count -gt 9) { Stop-WithError ("{0}: uses must name 1..9 <Use> entries (channel 1..9, %C% is one digit)" -f $cw) }
    $ch = @{ Name = $cName; Text = $cText; Index = $cf.Channels.Count + 1; Uses = @() }
    for ($n = 0; $n -lt $names.Count; $n++) {
      $hit = @($cf.Uses | Where-Object { $_.Name -eq $names[$n] })
      if ($hit.Count -eq 0) { Stop-WithError ("{0}: {1} is no <Use name>" -f $cw, $names[$n]) }
      if ($hit[0].ContainsKey("Channel")) { Stop-WithError ("{0}: {1} is already channel {2} of {3}" -f $cw, $names[$n], $hit[0].Channel.N, $hit[0].Channel.Block) }
      $hit[0].Channel = @{ Block = $cName; Group = $ch.Index; N = $n + 1 }
      $ch.Uses += $hit[0]
    }
    # one block, one text: the uses of a block share their error template (error=... of <Use>, else of <Conflicts>)
    $templates = @($ch.Uses | ForEach-Object { $_.Error } | Sort-Object -Unique -CaseSensitive)
    if ($templates.Count -gt 1) { Stop-WithError ("{0}: its uses have different error=... texts - give them one text (the block shows one message per channel)" -f $cw) }
    $ch.ErrorText = $templates[0].Replace("{text}", $cText)
    if ($ch.ErrorText.Length -gt 255) { Stop-WithError ("{0}: the error text has {1} characters, ETS shows at most 255" -f $cw, $ch.ErrorText.Length) }
    $ch.ReservedText = $cf.ReservedError.Replace("{text}", $cText)
    $ch.TpText = $cf.TpError.Replace("{text}", $cText)
    if ($cf.Reserved -and $ch.ReservedText.Length -gt 255) { Stop-WithError ("{0}: the reservedError text has {1} characters, ETS shows at most 255" -f $cw, $ch.ReservedText.Length) }
    if ($cf.Reserved -and $ch.TpText.Length -gt 255) { Stop-WithError ("{0}: the tpError text has {1} characters, ETS shows at most 255" -f $cw, $ch.TpText.Length) }
    $cf.Channels.Add($ch)
  }
  if ($cf.Channels.Count -gt 0) {
    # flag numbers: uses outside a channel block number + 0..9, channel block k use n number + 10 k + n
    if ($cf.Number % 10 -ne 0) { Stop-WithError ("<Conflicts>: number must be a multiple of 10 with <ChannelBlock> (flag number of channel n ends in n), not {0}" -f $cf.Number) }
    $free = @($cf.Uses | Where-Object { -not $_.ContainsKey("Channel") }).Count
    if ($free -gt 10) { Stop-WithError ("<Conflicts>: with <ChannelBlock> at most 10 <Use> entries outside a channel block (number + 0..9), not {0}" -f $free) }
    if ($cf.Channels.Count -gt 9 -or $cf.Number + 10 * $cf.Channels.Count + 9 -gt 99999) { Stop-WithError "<Conflicts>: at most 9 <ChannelBlock> entries, and number + 10 x blocks + 9 must stay within 99999" }
  }
  if ($cf.Channels.Count -eq 0 -and $cf.Number + $cf.Uses.Count - 1 -gt 99999) { Stop-WithError ("<Conflicts>: number {0} + {1} flags exceeds 99999" -f $cf.Number, $cf.Uses.Count) }
  return $cf
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
  if ($quote -ne [char]0) { throw "unbalanced quote in build flag: $Line" }
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
        Stop-WithError ("env {0}: build flag {1} ends with a backslash and cannot be evaluated; leaving it out could change a capability (e.g. a feature flag) - change the flag or leave the env out (<Boards exclude=...>)" -f $EnvName, $t)
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
  if (Test-Path -LiteralPath $plat) { $dirs += @(Get-ChildItem -LiteralPath $plat -Directory | Sort-Object Name | ForEach-Object { [System.IO.Path]::Combine($_.FullName, "boards") }) }
  foreach ($d in $dirs) {
    $f = [System.IO.Path]::Combine($d, $BoardId + ".json")
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
        Write-Warn ("PlatformIO board {0}: no board manifest with build.mcu found - no MCU: default preprocessor, no framework defines" -f $BoardId)
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
function Get-PlatformIOBoards($M, [string]$EnvPattern, [string]$ProjectDir, [string[]]$Exclude = @()) {
  $pio = Get-Command "pio" -ErrorAction SilentlyContinue
  if (-not $pio) { $pio = Get-Command "platformio" -ErrorAction SilentlyContinue }
  if (-not $pio) {
    # PlatformIO IDE installs pio into its own virtual environment, often not in PATH
    foreach ($cand in @("Scripts\pio.exe", "bin/pio")) {
      $pp = [System.IO.Path]::Combine((Get-PioCoreDir), "penv", $cand)
      if (Test-Path -LiteralPath $pp -PathType Leaf) { $pio = Get-Command $pp -ErrorAction SilentlyContinue; break }
    }
  }
  if (-not $pio) { Stop-WithError "<Boards platformio=...> needs PlatformIO: pio in PATH or in <PLATFORMIO_CORE_DIR or ~/.platformio>/penv" }
  Write-Activity "PlatformIO-Envs lesen (pio project config) ..."
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  # the JSON is ASCII (json.dumps escapes every other character), so the console code page does not matter
  try {
    $raw = @(& $pio.Source project config --json-output -d $ProjectDir 2>&1)
    $exitCode = $LASTEXITCODE
  }
  finally { $ErrorActionPreference = $prevEap }
  $json = @($raw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
  if ($exitCode -ne 0) {
    $why = (@($raw | ForEach-Object { "$_" }) | Where-Object { $_ } | Select-Object -Last 3) -join " | "
    Stop-WithError ("pio project config failed in {0}: {1}" -f $ProjectDir, $why)
  }
  $cfg = ConvertTo-PioSections ((@($json) -join "`n") | ConvertFrom-Json)
  $result = @()
  $envTotal = @($cfg | Where-Object { ([string]$_[0]).StartsWith("env:") -and ([string]$_[0]).Substring(4) -like $EnvPattern }).Count
  $envIndex = 0
  foreach ($sec in $cfg) {
    $name = [string]$sec[0]
    if (-not $name.StartsWith("env:")) { continue }
    $envName = $name.Substring(4)
    if ($envName -notlike $EnvPattern) { continue }
    $envIndex++
    Write-Activity ("Env {0}/{1}  {2}" -f $envIndex, $envTotal, $envName)
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
              # alias define (e.g. DEVICE_QUINLED_DIG_QUAD_V3): a board only when it resolves to a DEVICE_HW_ID
              foreach ($cd in @($words | Where-Object { $_ -match '^(DEVICE|OKNXHW)_' })) {
                try { if ($null -ne (Get-BoardIdentity $cd (@($cd) + $otherDefs)).HwId) { $hit += $cd } } catch { }
              }
            }
            if ($hit.Count -gt 0) {
              Stop-OnSkip ("env {0}: excluded by <Boards exclude=...>, but build_flags line '{1}' cannot be parsed ({2}) and names {3}" -f $envName, $fl, $parseError, ($hit -join ", "))
            }
            continue
          }
          Stop-WithError ("env {0}: build_flags line '{1}' cannot be parsed ({2}); leaving its defines out could change a capability - fix the line or leave the env out (<Boards exclude=...>)" -f $envName, $fl, $_.Exception.Message)
        }
      }
    }
    # the board is the define of a header block with DEVICE_HW_ID (not a build flag like DEVICE_DISPLAY_MODULE);
    # an alias define (e.g. DEVICE_QUINLED_DIG_QUAD_V3 + KNX_IP_LAN) is accepted when the env resolves to an ID
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
      if ($exBoard) { Stop-OnSkip ("env {0}: excluded by <Boards exclude=...>, but it builds board {1}" -f $envName, $exBoard) }
      continue
    }
    if ($known.Count -gt 1) { Stop-OnSkip ("env {0}: two boards ({1})" -f $envName, ($known -join ", ")); continue }
    $board = $known | Select-Object -First 1
    if (-not $board) {
      # alias define (e.g. DEVICE_QUINLED_DIG_QUAD_V3 + KNX_IP_LAN): test each candidate on its own with the
      # env's other defines, so a build flag like DEVICE_DISPLAY_MODULE never becomes the board
      $cands = @($plain | Where-Object { $_ -match '^(DEVICE|OKNXHW)_' })
      $rest = @($defs | Where-Object { $cands -notcontains $_ })
      $hits = @($cands | Where-Object { $null -ne (Get-BoardIdentity $_ (@($_) + $rest)).HwId })
      if ($hits.Count -gt 1) { Stop-OnSkip ("env {0}: two boards ({1})" -f $envName, ($hits -join ", ")); continue }
      $board = $hits | Select-Object -First 1
    }
    if (-not $board) { $script:NoBoardEnvs += $envName; if ($script:InitMode) { continue } }
    if (-not $board) { Stop-OnSkip ("env {0}: no board with DEVICE_HW_ID among its defines; an env that builds no board (e.g. a test env) is left out with <Boards platformio=`"{1}`" exclude=`"<pattern> ...`" />" -f $envName, $EnvPattern); continue }
    # the env as a whole must resolve to this board's own ID; another board (e.g. an alias define next to a
    # known one) would give a mix of two boards
    if ($null -eq $script:BoardIdCache) { $script:BoardIdCache = @{} }
    if (-not $script:BoardIdCache.ContainsKey($board)) { $script:BoardIdCache[$board] = (Get-BoardIdentity $board @($board)).HwId }
    $envId = (Get-BoardIdentity $board $defs).HwId
    $ownId = $script:BoardIdCache[$board]
    if ($known.Count -eq 1 -and $envId -ne $ownId) {
      Stop-OnSkip ("env {0}: resolves to 0x{1:X4}, but its board {2} is 0x{3:X4} - a second board define?" -f $envName, [int]$envId, $board, [int]$ownId)
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
  if ($result.Count -eq 0) { Stop-OnSkip ("No PlatformIO env matches {0}" -f $EnvPattern) }
  return $result
}

# ------------------------------------------------------------------------------------------------
# Board evaluation
# ------------------------------------------------------------------------------------------------
function Test-Wildcard([string]$Pattern, [string]$Text) {
  return ($Text -like $Pattern)
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
  if ($null -eq $ident.HwId) { Stop-WithError "$($BoardEntry.Define): no DEVICE_HW_ID - add one to the board header (see generator/README.md)" }
  if ($ident.HwId -le 0 -or $ident.HwId -ge 65535) { Stop-WithError "$($BoardEntry.Define): DEVICE_HW_ID out of range" }

  # pass 1: macro names of this board (for scan="" pin sources)
  $macroNames = @()
  $needScan = $false
  foreach ($role in $M.Roles) { foreach ($s in $role.Sources) { if ($s.Scan -and (Test-Wildcard $s.Board $BoardEntry.Define)) { $needScan = $true } } }
  if ($needScan) {
    $macroNames = Invoke-Preprocessor -Source "#include `"HardwareConfig.h`"`n" -Defines $defines -MacroList |
      ForEach-Object { if ("$_" -match '^#define (\w+)\s') { $Matches[1] } } | Sort-Object
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
  # board description for <Page> (HW_INFO_TEXT of the board block)
  [void]$sb.AppendLine("#ifdef HW_INFO_TEXT")
  [void]$sb.AppendLine("@@ `"INFOTEXT`" HW_INFO_TEXT")
  [void]$sb.AppendLine("#endif")

  $lines = Invoke-Preprocessor -Source $sb.ToString() -Defines $defines
  $res = @{}
  foreach ($l in $lines) { if ($l -match '^@@ "(\w+)" (.*)$') { $res[$Matches[1]] = $Matches[2] } }
  # reserved pin macros may name a pin constant of the Arduino variant (UP1: PROG_LED_PIN (D8))
  $vc = Get-VariantPinConstants "$($BoardEntry.Mcu)" "$($BoardEntry.Variant)"
  if ($vc.Count -gt 0) { foreach ($k in @($res.Keys | Where-Object { $_ -match '^A?RSV\d+$' })) { $res[$k] = Resolve-VariantPin $res[$k] $vc } }

  $board = @{
    Define = $BoardEntry.Define; HwId = $ident.HwId; DeviceId = $ident.Id; Name = $ident.Name
    Caps = @(); CapMask = [uint32]0; Values = @(); ValueSource = @(); Pins = @{}; Slot = -1; CapMixed = @{}; InfoText = $null
  }
  if ($res.ContainsKey("INFOTEXT")) {
    $board.InfoText = ConvertFrom-CString $res["INFOTEXT"]
    if (-not $board.InfoText) { Stop-WithError ("{0}: HW_INFO_TEXT is not a string: {1}" -f $BoardEntry.Define, $res["INFOTEXT"]) }
    if ($board.InfoText.Length -gt 255) { Stop-WithError ("{0}: HW_INFO_TEXT has {1} characters, ETS shows at most 255" -f $BoardEntry.Define, $board.InfoText.Length) }
  }
  if (-not $board.Name) { $board.Name = $ident.Id }
  if (-not $board.Name) { $board.Name = $BoardEntry.Define }
  $board.InfoUrl = $null
  $board.InfoUrlOwn = $false   # $true: the URL comes from the board header, not the <InfoImage default> (empty = no QR code)
  if ($M.Info) {
    $board.InfoUrl = $M.Info.Default
    if ($res.ContainsKey("INFOURL")) {
      $board.InfoUrlOwn = $true
      $board.InfoUrl = ConvertFrom-CString $res["INFOURL"]
      if (-not $board.InfoUrl) { Stop-WithError ("{0}: {1} is not a string: {2}" -f $BoardEntry.Define, $M.Info.Define, $res["INFOURL"]) }
    }
  }
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) {
    $on = ($res["CAP$i"] -eq "1")
    $board.Caps += $on
    if ($on) { $board.CapMask = $board.CapMask -bor ([uint32]1 -shl $i) }
  }
  for ($i = 0; $i -lt $M.Values.Count; $i++) {
    $n = ConvertFrom-CInteger $res["VAL$i"]
    if ($null -eq $n) { Stop-WithError ("{0}: value {1} is not an integer: {2}" -f $BoardEntry.Define, $M.Values[$i].Name, $res["VAL$i"]) }
    $sets = @($M.Values[$i].Sets | Where-Object { Test-Wildcard $_.Board $BoardEntry.Define })
    if ($sets.Count -gt 0) {
      $exact = @($sets | Where-Object { -not $_.Pattern })
      if ($exact.Count -gt 0) { $sets = $exact }
      if ($sets.Count -gt 1) { Stop-WithError ("{0}: value {1} is set by {2} <Set> entries ({3})" -f $BoardEntry.Define, $M.Values[$i].Name, $sets.Count, (($sets | ForEach-Object { $_.Board }) -join ", ")) }
      $n = $sets[0].Value
      $board.ValueSource += ("<Set board=`"{0}`">" -f $sets[0].Board)
    }
    else { $board.ValueSource += $M.Values[$i].Expr }
    if ($n -lt 0 -or $n -gt 255) { Stop-WithError ("{0}: value {1} = {2} does not fit one byte" -f $BoardEntry.Define, $M.Values[$i].Name, $n) }
    # the feature flags (_GE_n / _EQ_n) and the value lists cover 0..max only
    if ($n -gt $M.Values[$i].Max) { Stop-WithError ("{0}: value {1} = {2} is above max=`"{3}`" of the manifest - raise max" -f $BoardEntry.Define, $M.Values[$i].Name, $n, $M.Values[$i].Max) }
    $board.Values += $n
  }
  # pins the platform already uses (KNX UART, prog button/LED, ...) are never offered
  $reservedGpio = @{}
  for ($i = 0; $i -lt $M.Reserved.Count; $i++) {
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
    for ($i = 0; $i -lt $M.Reserved.Count; $i++) { if ($res.ContainsKey("RSV$i") -and $null -eq (ConvertFrom-CInteger $res["RSV$i"]) -and -not (Test-CNegative $res["RSV$i"])) { $nonInt += $M.Reserved[$i] } }
    # manifest pins; a KNX UART macro listed there follows the TP rule below like the automatic one
    $own = @()
    for ($i = 0; $i -lt $M.Reserved.Count; $i++) {
      if ($TP_RESERVED -contains $M.Reserved[$i] -or -not $res.ContainsKey("RSV$i")) { continue }
      $mg = ConvertFrom-CInteger $res["RSV$i"]
      if ($null -ne $mg -and $mg -ge 0 -and $mg -le 254) { $own += $mg }
    }
    for ($i = 0; $i -lt $autoMacros.Count; $i++) {
      if (-not $res.ContainsKey("ARSV$i")) { continue }
      $ag = ConvertFrom-CInteger $res["ARSV$i"]
      if ($null -eq $ag) { if (-not (Test-CNegative $res["ARSV$i"])) { $nonInt += $autoMacros[$i] }; continue }
      if ($ag -lt 0 -or $ag -gt 254) { continue }
      if ($TP_RESERVED -contains $autoMacros[$i]) { $board.TpGpios += $ag } else { $own += $ag }
    }
    # the header compares (int)(MACRO): a value the generator cannot read as a number would differ between ETS and firmware
    if ($nonInt.Count -gt 0) { Stop-WithError ("{0}: <Conflicts reserved>: the reserved pin macro(s) {1} do not resolve to an integer" -f $BoardEntry.Define, (($nonInt | Sort-Object -Unique) -join ", ")) }
    $chip = $null; if ($BoardEntry.Mcu -and $CHIP_RESERVED.ContainsKey("$($BoardEntry.Mcu)")) { $chip = $CHIP_RESERVED["$($BoardEntry.Mcu)"] }
    if ($chip) {
      $own += $chip.Base
      if ($BoardEntry.Psram) { $own += $chip.Cs1 }
      if ("$($BoardEntry.Memory)" -like "*_opi") { $own += $chip.Octal }
    }
    elseif ("$($BoardEntry.Mcu)" -like "ESP32*") { Write-Warn ("{0}: <Conflicts reserved>: no flash / PSRAM GPIO table for {1} - the ETS check knows only the pin macros there" -f $BoardEntry.Define, $BoardEntry.Mcu) }
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
    if ($null -eq $gpio) { Write-Warn ("{0}: pin {1} ({2}) does not resolve to a GPIO number: {3}" -f $BoardEntry.Define, $c.Label, $c.Macro, $res["PIN$i"]); continue }
    if ($gpio -lt 0 -or $gpio -ge $PIN_UNUSED) { Write-Warn ("{0}: pin {1} = {2} skipped (no GPIO)" -f $BoardEntry.Define, $c.Label, $gpio); continue }
    if ($reservedGpio.ContainsKey($gpio)) { $board.ReservedSkipped++; continue }
    $list = $board.Pins[$c.Role]
    if (@($list | Where-Object { $_.Gpio -eq $gpio }).Count -gt 0) { continue }
    $list.Add(@{ Gpio = $gpio; Label = $c.Label })
  }
  foreach ($role in $M.Roles) {
    $sorted = @($board.Pins[$role.Name] | Sort-Object @{ Expression = { [regex]::Replace($_.Label, '\d+', { param($mt) $mt.Value.PadLeft(5, '0') }) } })
    $board.Pins[$role.Name] = $sorted
  }
  # ports: n = 1..HW_PORT_COUNT, only the ones with HW_PORT_<n>_GPIO, in header order
  $board.PortCount = 0
  $board.Ports = New-Object System.Collections.Generic.List[object]
  if ($res.ContainsKey("PORTCOUNT")) {
    $pc = ConvertFrom-CInteger $res["PORTCOUNT"]
    if ($null -eq $pc) { Stop-WithError ("{0}: HW_PORT_COUNT is not an integer: {1}" -f $BoardEntry.Define, $res["PORTCOUNT"]) }
    if ($pc -gt $MAX_PORTS) { Stop-WithError ("{0}: HW_PORT_COUNT {1} is above the supported {2} ports (HW_PORTS_MAX, include/HardwareConfig/Helpers/HardwarePorts.h)" -f $BoardEntry.Define, $pc, $MAX_PORTS) }
    $board.PortCount = $pc
  }
  $gap = 0
  for ($n = 1; $n -le $MAX_PORTS; $n++) {
    if (-not $res.ContainsKey("PORTGPIO$n")) { if ($n -le $board.PortCount -and $gap -eq 0) { $gap = $n }; continue }
    if ($n -gt $board.PortCount) {
      Write-Warn ("{0}: HW_PORT_{1}_GPIO is outside HW_PORT_COUNT ({2}) - not offered" -f $BoardEntry.Define, $n, $board.PortCount)
      continue
    }
    # a port value is the list position and the firmware maps value k to HW_PORT_<k+1>: no gaps
    if ($gap -gt 0) { Stop-WithError ("{0}: HW_PORT_{1}_GPIO is missing but HW_PORT_{2}_GPIO is defined - ports must be numbered without gaps" -f $BoardEntry.Define, $gap, $n) }
    $g = ConvertFrom-CInteger $res["PORTGPIO$n"]
    if ($null -eq $g) { Stop-WithError ("{0}: HW_PORT_{1}_GPIO does not resolve to a GPIO number: {2}" -f $BoardEntry.Define, $n, $res["PORTGPIO$n"]) }
    if ($g -lt 0 -or $g -gt 254) { Stop-WithError ("{0}: HW_PORT_{1}_GPIO is {2}, a GPIO must be 0..254 (255 = none)" -f $BoardEntry.Define, $n, $g) }
    $label = "Port $n"
    if ($res.ContainsKey("PORTLABEL$n")) {
      $label = ConvertFrom-CString $res["PORTLABEL$n"]
      if ($null -eq $label) { Stop-WithError ("{0}: HW_PORT_{1}_LABEL is not a string: {2}" -f $BoardEntry.Define, $n, $res["PORTLABEL$n"]) }
    }
    $board.Ports.Add(@{ N = $n; Gpio = $g; Label = $label })
  }
  if ($board.Ports.Count -gt 0 -and $board.PortCount -gt $board.Ports.Count) {
    Write-Warn ("{0}: HW_PORT_COUNT {1}, but only ports 1..{2} are described" -f $BoardEntry.Define, $board.PortCount, $board.Ports.Count)
  }
  # relays 1..HW_RELAY_COUNT, each with HW_RELAY_<n>_GPIO ($b.Relays: N, Gpio, Label); none without HW_RELAY_COUNT
  $board.Relays = New-Object System.Collections.Generic.List[object]
  $rc = 0
  if ($res.ContainsKey("RELAYCOUNT")) {
    $rc = ConvertFrom-CInteger $res["RELAYCOUNT"]
    if ($null -eq $rc -or $rc -lt 0 -or $rc -gt $MAX_RELAYS) { Stop-WithError ("{0}: HW_RELAY_COUNT must be 0..{1}: {2}" -f $BoardEntry.Define, $MAX_RELAYS, $res["RELAYCOUNT"]) }
  }
  for ($n = 1; $n -le $MAX_RELAYS; $n++) {
    if (-not $res.ContainsKey("RELAYGPIO$n")) {
      if ($n -le $rc) { Stop-WithError ("{0}: HW_RELAY_COUNT {1}, but HW_RELAY_{2}_GPIO is missing" -f $BoardEntry.Define, $rc, $n) }
      continue
    }
    if ($n -gt $rc) { Stop-WithError ("{0}: HW_RELAY_{1}_GPIO is outside HW_RELAY_COUNT ({2})" -f $BoardEntry.Define, $n, $rc) }
    $g = ConvertFrom-CInteger $res["RELAYGPIO$n"]
    if ($null -eq $g -or $g -lt 0 -or $g -ge $PIN_UNUSED) { Stop-WithError ("{0}: HW_RELAY_{1}_GPIO does not resolve to a GPIO number: {2}" -f $BoardEntry.Define, $n, $res["RELAYGPIO$n"]) }
    $label = "Relais $n"
    if ($res.ContainsKey("RELAYLABEL$n")) {
      $label = ConvertFrom-CString $res["RELAYLABEL$n"]
      if ($null -eq $label) { Stop-WithError ("{0}: HW_RELAY_{1}_LABEL is not a string: {2}" -f $BoardEntry.Define, $n, $res["RELAYLABEL$n"]) }
    }
    $board.Relays.Add(@{ N = $n; Gpio = $g; Label = $label })
  }
  $board.Relays = $board.Relays.ToArray()
  # <Ports use>: offer only these hardware ports; each port keeps its number N (ETS value N-1)
  $sets = @($M.PortSets | Where-Object { Test-Wildcard $_.Board $BoardEntry.Define })
  if ($sets.Count -gt 1) { Stop-WithError ("{0}: matched by {1} <Ports> entries ({2}) - one board, one port list" -f $BoardEntry.Define, $sets.Count, (($sets | ForEach-Object { $_.Board }) -join ", ")) }
  if ($sets.Count -eq 1) {
    $sets[0].Hits++
    if ($sets[0].Max -gt 0 -and $board.Ports.Count -gt $sets[0].Max) {
      Stop-WithError ("{0}: describes {1} ports, <Ports board=`"{2}`" max=`"{3}`"> - the product stores ports 1..{3} only" -f $BoardEntry.Define, $board.Ports.Count, $sets[0].Board, $sets[0].Max)
    }
    if ($sets[0].All) { $sets[0].Use = @($board.Ports | ForEach-Object { $_.N }) }
    foreach ($n in $sets[0].Use) {
      if (@($board.Ports | Where-Object { $_.N -eq $n }).Count -eq 0) { Stop-WithError ("{0}: <Ports board=`"{1}`"> offers port {2}, the header describes ports 1..{3}" -f $BoardEntry.Define, $sets[0].Board, $n, $board.Ports.Count) }
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

# ------------------------------------------------------------------------------------------------
# Generators
# ------------------------------------------------------------------------------------------------
# feature flag ID list for "has it": with unselected=showAll the value 0 (not selected) is part of every list
function Get-FlagIdList($M, $Boards) {
  $ids = @($Boards | ForEach-Object { [string]$_.HwId })
  if ($M.Unselected -eq "showAll") { $ids = @("$($M.UnselectedValue)") + $ids }
  if ($ids.Count -eq 0) { return $NEVER_MATCH }
  return ($ids -join " ")
}

function Get-IdList($Boards) {
  $ids = @($Boards | ForEach-Object { [string]$_.HwId })
  if ($ids.Count -eq 0) { return $NEVER_MATCH }
  return ($ids -join " ")
}

function Get-ParamRefIds($M) {
  $tt = "{0:D2}" -f $M.ModuleType
  return @{
    Select    = "%AID%_UP-${tt}00001_R-${tt}0000101"
    SelectTT  = "%AID%_UP-%TT%00001_R-%TT%0000101"
    # <Page unselectedTitle>: page text of the tree (memoryless text, set by a calculation from the selection)
    Title     = "%AID%_P-${tt}${script:PageTitleParamNum}_R-${tt}${script:PageTitleParamNum}01"
    TitleTT   = "%AID%_P-%TT%${script:PageTitleParamNum}_R-%TT%${script:PageTitleParamNum}01"
  }
}

# @brief Capabilities with switch="true" and their parameter numbers (on: 100 + bit, firmware state: 200 + bit)
function Get-Switches($M) {
  $list = @()
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) {
    $c = $M.Capabilities[$i]
    if (-not $c.Switch) { continue }
    $fixedIdx = -1; $repIdx = $i
    for ($j = 0; $j -lt $M.Capabilities.Count; $j++) {
      if ($c.FixedBy -and $M.Capabilities[$j].Name -eq $c.FixedBy) { $fixedIdx = $j }
      if ($c.ReportedBy -and $M.Capabilities[$j].Name -eq $c.ReportedBy) { $repIdx = $j }
    }
    $list += @{ Cap = $c; Index = $i; FixedIdx = $fixedIdx; ReportIdx = $repIdx; Bit = $list.Count; OnNum = ("{0:D5}" -f (100 + $i)); FwNum = ("{0:D5}" -f (200 + $i)) }
  }
  return ,$list
}

function Get-PinParamNumber($RoleNumber, $Slot, $BoardSlot) {
  # 5 digits R S BBB -> role 1..9, slot 1..9, board slot 0..999 (from the slot file, never reused);
  # 11000..99999, never 00001 (hardware selection)
  return ($RoleNumber * 10000) + ($Slot * 1000) + $BoardSlot
}

# Board slots: DEVICE_HW_ID -> number, kept in <manifest>.slots next to the manifest. New boards get
# the next free number, removed boards keep theirs. The GPIO role parameter IDs are built from the
# slot, so adding or reordering boards never moves the parameter of an existing board (an ETS app
# update migrates values by parameter ID).
function Update-BoardSlots($M, $Boards) {
  $path = [System.IO.Path]::ChangeExtension($M.ManifestPath, ".slots")
  $slots = @{}
  $removed = @{}
  # bit order of the device query: "cap <n> = <Name>" / "val <n> = <Name>" (an old firmware reads the bits by position)
  $bitRec = @{ cap = @{}; val = @{} }
  $lines = @()
  if (Test-Path $path) { $lines = [System.IO.File]::ReadAllLines($path) }
  else {
    Write-Warn ("No slot file {0}: fine for a new product. If this product was released before, restore the file from git - new slots would move every GPIO parameter ID" -f $path)
  }
  for ($ln = 0; $ln -lt $lines.Count; $ln++) {
    $l = $lines[$ln]
    if ($l -match '^\s*(#.*)?$') { continue }
    if ($l -match '^\s*(cap|val)\s+(\d+)\s*=\s*([A-Za-z][A-Za-z0-9]*)\s*$') {
      $kind = $Matches[1]; $bi = [int]$Matches[2]
      if ($bitRec[$kind].ContainsKey($bi) -and $bitRec[$kind][$bi] -cne $Matches[3]) { Stop-WithError ("Slot file {0}, line {1}: {2} {3} is listed twice" -f $path, ($ln + 1), $kind, $bi) }
      $bitRec[$kind][$bi] = $Matches[3]
      continue
    }
    if ($l -match '^\s*0x([0-9A-Fa-f]{4})\s*=\s*(\d+)(\s+removed)?\s*$') {
      $id = [Convert]::ToInt32($Matches[1], 16)
      if ($slots.ContainsKey($id) -and $slots[$id] -ne [int]$Matches[2]) {
        Stop-WithError ("Slot file {0}: 0x{1:X4} has two slots ({2} and {3}) - keep the one that was released" -f $path, $id, $slots[$id], [int]$Matches[2])
      }
      $isRemovedLine = [bool]$Matches[3]
      if ($slots.ContainsKey($id)) {
        # identical duplicate line: a line without the mark wins over one with it
        if (-not $isRemovedLine) { $removed.Remove($id) }
        continue
      }
      $slots[$id] = [int]$Matches[2]
      if ($isRemovedLine) { $removed[$id] = $true }
    }
    else {
      # a line that does not parse would give its board a new slot (all its IDs move)
      Stop-WithError ("Slot file {0}, line {1}: '{2}' is no slot line (0x<HW-ID> = <slot> [removed], cap <n> = <Name>, val <n> = <Name>)" -f $path, ($ln + 1), $l)
    }
  }
  # a merge of two branches can give two boards the same slot -> two parameters with one ID
  foreach ($g in ($slots.Keys | Group-Object { $slots[$_] } | Where-Object { $_.Count -gt 1 })) {
    Stop-WithError ("Slot file {0}: slot {1} is used by {2} - give the newer board the next free slot" -f $path, $g.Name, (($g.Group | ForEach-Object { "0x{0:X4}" -f $_ }) -join ", "))
  }
  $next = 0
  foreach ($v in $slots.Values) { if ($v -ge $next) { $next = $v + 1 } }
  $added = @(); $back = @(); $gone = @()
  $current = @{}
  foreach ($b in $Boards) {
    $current[$b.HwId] = $true
    if (-not $slots.ContainsKey($b.HwId)) { $slots[$b.HwId] = $next; $next++; $added += $b.HwId }
    elseif ($removed.ContainsKey($b.HwId)) { $removed.Remove($b.HwId); $back += $b.HwId }
    $b.Slot = $slots[$b.HwId]
  }
  foreach ($k in @($slots.Keys)) {
    if (-not $current.ContainsKey($k) -and -not $removed.ContainsKey($k)) { $removed[$k] = $true; $gone += $k }
  }
  if ($next -gt 1000) { Stop-WithError "Slot file $path holds more than 1000 boards (3-digit slot in the parameter IDs)" }
  # bit order: a recorded bit keeps its name; new capabilities / values are appended (a firmware in the field reads
  # the query answer by position, an inserted or removed entry would shift every later bit)
  $cur = @{ cap = @($M.Capabilities | ForEach-Object { $_.Name }); val = @($M.Values | Where-Object { $_.Query } | ForEach-Object { $_.Name }) }
  $bitsAdded = @()
  foreach ($kind in @("cap", "val")) {
    $label = @{ cap = "capability"; val = "value" }[$kind]
    $recCount = 0; foreach ($k in $bitRec[$kind].Keys) { if ($k + 1 -gt $recCount) { $recCount = $k + 1 } }
    for ($i = 0; $i -lt $recCount; $i++) {
      if (-not $bitRec[$kind].ContainsKey($i)) { Stop-WithError ("Slot file {0}: {1} {2} is missing (the recorded bits must be 0..{3} without a gap)" -f $path, $kind, $i, ($recCount - 1)) }
      $was = $bitRec[$kind][$i]
      if ($i -ge $cur[$kind].Count) { Stop-WithError ("Device query: {0} {1} '{2}' is gone from the manifest - a firmware in the field still sends it at this position; keep it (it may never be true)" -f $label, $i, $was) }
      if ($cur[$kind][$i] -cne $was) { Stop-WithError ("Device query: {0} {1} was '{2}', now '{3}' - append new entries at the end of the manifest (packs first, then own entries); a pure rename: change the line in {4}" -f $label, $i, $was, $cur[$kind][$i], $path) }
    }
    for ($i = $recCount; $i -lt $cur[$kind].Count; $i++) { $bitRec[$kind][$i] = $cur[$kind][$i]; $bitsAdded += ("{0} {1} = {2}" -f $kind, $i, $cur[$kind][$i]) }
  }
  if (($added.Count + $back.Count + $gone.Count + $bitsAdded.Count) -eq 0) { return }
  # the board list of the ETS product changed (a pattern can do that without a manifest change)
  $hex = { param($list) ($list | ForEach-Object { "0x{0:X4}" -f $_ }) -join ", " }
  if ($added.Count -gt 0) { Write-Warn ("Board(s) added: {0}" -f (& $hex $added)) }
  if ($back.Count -gt 0) { Write-Warn ("Board(s) back: {0}" -f (& $hex $back)) }
  if ($gone.Count -gt 0) { Write-Warn ("Board(s) removed, slot kept: {0}" -f (& $hex $gone)) }
  if ($bitsAdded.Count -gt 0 -and $bitsAdded.Count -lt ($cur.cap.Count + $cur.val.Count)) { Write-Warn ("Device query bit(s) added: {0}" -f ($bitsAdded -join ", ")) }
  if (($added.Count + $back.Count + $gone.Count) -gt 0 -or ($bitsAdded.Count -gt 0 -and $bitsAdded.Count -lt ($cur.cap.Count + $cur.val.Count))) {
    Write-Warn "The ETS content changed: raise the ApplicationVersion (ReplacesVersionsDownTo), or ETS treats it as the same version"
  }
  $out = New-Object System.Text.StringBuilder
  [void]$out.AppendLine("# Board slots of the GPIO role parameters (Build-HardwareProfile.ps1). Commit this file.")
  [void]$out.AppendLine("# Never edit or reuse a number: it is part of the ETS parameter ID of every GPIO role.")
  foreach ($k in ($slots.Keys | Sort-Object { $slots[$_] })) {
    $mark = ""
    if ($removed.ContainsKey($k)) { $mark = " removed" }
    [void]$out.AppendLine(("0x{0:X4} = {1}{2}" -f $k, $slots[$k], $mark))
  }
  [void]$out.AppendLine("# Bit order of the device query (firmware in the field reads by position): append only, never insert or remove.")
  foreach ($kind in @("cap", "val")) {
    foreach ($i in @($bitRec[$kind].Keys | Sort-Object)) { [void]$out.AppendLine(("{0} {1} = {2}" -f $kind, $i, $bitRec[$kind][$i])) }
  }
  # written with the other outputs, after all of them rendered (an error before that leaves the old slot file)
  return @{ Output = $path; Text = $out.ToString() }
}

function New-ConfXml($M, $Boards) {
  $p = $M.Prefix
  $refs = Get-ParamRefIds $M
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
  [void]$sb.AppendLine('<KNX xmlns="http://knx.org/xml/project/20" xmlns:op="http://github.com/OpenKNX/OpenKNXproducer">')
  [void]$sb.AppendLine("  <!-- Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 - do not edit -->")
  if ($M.Outputs.ContainsKey("share")) { [void]$sb.AppendLine("  <!-- Use in any module: <choose ParamRefId=`"%${p}_SelectRef%`"><when test=`"%${p}_CAP_Wifi%`"> ... -->") }
  else { [void]$sb.AppendLine("  <!-- Use in any module: <when test=`"%${p}_CAP_<Capability>%`"> (hardware IDs with the capability) -->") }
  [void]$sb.AppendLine("  <!-- a module uses only the feature flags it needs; the rest is expected to stay unused -->")
  [void]$sb.AppendLine(("  <op:nowarn id=`"1`" regex=`"%{0}_`" />" -f $p))
  [void]$sb.AppendLine(("  <op:nowarn id=`"3`" regex=`"{0}_hex4`" />" -f $p))
  # <Conflicts>: helpers of the check, called only from {prefix}_conflictCheck
  if ($M.Conflicts) { [void]$sb.AppendLine(("  <op:nowarn id=`"3`" regex=`"{0}_conflict(Int|When|Gpio|Flags)`" />" -f $p)) }
  [void]$sb.AppendLine("  <!-- GPIO roles: the per-board parameters of one slot share one byte on purpose (ETS union) -->")
  [void]$sb.AppendLine(("  <op:nowarn id=`"10`" regex=`"{0}_.*B\d+`" />" -f $p))
  # the hardware selection of the generated module; an OAM without that module has its own
  if ($M.Outputs.ContainsKey("share")) { [void]$sb.AppendLine(("  <op:config name=`"%{0}_SelectRef%`" value=`"{1}`" />" -f $p, $refs.Select)) }
  [void]$sb.AppendLine(("  <op:config name=`"%{0}_ALL%`" value=`"{1}`" />" -f $p, (Get-IdList $Boards)))
  # <Page>: text, icon and help context of the page, for an OAM that composes the page block in its product XML
  if ($M.Page) {
    [void]$sb.AppendLine(("  <op:config name=`"%{0}_PageText%`" value=`"{1}`" />" -f $p, (ConvertTo-XmlText $M.Page.Text)))
    [void]$sb.AppendLine(("  <op:config name=`"%{0}_PageIcon%`" value=`"{1}`" />" -f $p, $M.Page.Icon))
    if ($M.Page.Help) { [void]$sb.AppendLine(("  <op:config name=`"%{0}_PageHelp%`" value=`"{1}`" />" -f $p, $M.Page.Help)) }
    # tree text "<page> (nicht gewaehlt)" while no board is selected: the OAM's page block takes
    # Text="{{0:%<prefix>_PageText%}}" TextParameterRefId="%<prefix>_PageTextRef%"
    if ($M.Page.UnselectedTitle) { [void]$sb.AppendLine(("  <op:config name=`"%{0}_PageTextRef%`" value=`"{1}`" />" -f $p, $refs.Title)) }
  }
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) {
    $c = $M.Capabilities[$i]
    $with = @($Boards | Where-Object { $_.Caps[$i] })
    $without = @($Boards | Where-Object { -not $_.Caps[$i] })
    [void]$sb.AppendLine(("  <op:config name=`"%{0}_CAP_{1}%`" value=`"{2}`" />" -f $p, $c.Name, (Get-FlagIdList $M $with)))
    [void]$sb.AppendLine(("  <op:config name=`"%{0}_NOCAP_{1}%`" value=`"{2}`" />" -f $p, $c.Name, (Get-IdList $without)))
    # with the unselected value in any mode: settings that must stay visible (and keep their values) until a board is selected
    $withNone = @("$($M.UnselectedValue)") + @($with | ForEach-Object { [string]$_.HwId })
    [void]$sb.AppendLine(("  <op:config name=`"%{0}_CAP_{1}_OR_NONE%`" value=`"{2}`" />" -f $p, $c.Name, ($withNone -join " ")))
  }
  for ($i = 0; $i -lt $M.Values.Count; $i++) {
    $v = $M.Values[$i]
    for ($n = 1; $n -le $v.Max; $n++) {
      $ge = @($Boards | Where-Object { $_.Values[$i] -ge $n })
      [void]$sb.AppendLine(("  <op:config name=`"%{0}_VAL_{1}_GE_{2}%`" value=`"{3}`" />" -f $p, $v.Name, $n, (Get-FlagIdList $M $ge)))
    }
    # exactly n (e.g. the list 0..n of the selected board); with unselected=showAll "not selected" joins the largest n
    # any board has, so the longest list shows before a selection
    $top = 0; foreach ($b in $Boards) { if ([int]$b.Values[$i] -gt $top) { $top = [int]$b.Values[$i] } }
    for ($n = 0; $n -le $v.Max; $n++) {
      $eq = @($Boards | Where-Object { [int]$_.Values[$i] -eq $n } | ForEach-Object { [string]$_.HwId })
      if ($n -eq $top -and $M.Unselected -eq "showAll") { $eq = @("$($M.UnselectedValue)") + $eq }
      $eqText = $NEVER_MATCH; if ($eq.Count -gt 0) { $eqText = $eq -join " " }
      [void]$sb.AppendLine(("  <op:config name=`"%{0}_VAL_{1}_EQ_{2}%`" value=`"{3}`" />" -f $p, $v.Name, $n, $eqText))
    }
  }
  [void]$sb.AppendLine('</KNX>')
  return $sb.ToString()
}

# usable page width of ETS5 in picture px (measured: a wider picture is cut at about 525 px); sets the grid column of the QR picture
$script:EtsPageWidth = 520
# widest picture of a one-column grid row: the page width follows the window (ETS5: ~525 px cut on 2026-11-13, 532 px shown
# uncut and an information box ~538 px wide on 2026-11-15; ETS6: 532 px), so a picture of this row has a transparent
# background and its content left of 525 px
$script:EtsPictureMaxWidth = 532
# parameter numbers of the device card pictures without memory: OpenKNX logo, third-party badge; QR pictures 1000 + board slot
$script:LogoParamNum = "00900"
# <Page>: steps picture of the device query (queryImage) and the page text of the tree (unselectedTitle); calculation PC-<same number>
$script:StepsParamNum = "00902"
$script:PageTitleParamNum = "00903"
$script:BadgeParamNum = "00901"

# @brief QR pictures of the device card: boards with an info URL grouped by URL; Num = smallest board slot of the group
#        (parameter 1000 + Num, file Info<Num>.png). Boards without URL (no define, empty <InfoImage default>) get none.
function Get-InfoGroups($M, $Boards) {
  $groups = New-Object System.Collections.Generic.List[object]
  if (-not $M.Info) { return ,$groups.ToArray() }
  foreach ($b in $Boards) {
    if (-not $b.InfoUrl) { continue }
    $g = @($groups | Where-Object { $_.Url -ceq $b.InfoUrl }) | Select-Object -First 1
    if (-not $g) { $g = @{ Url = $b.InfoUrl; Boards = @(); Num = $b.Slot }; $groups.Add($g) }
    $g.Boards += $b
    if ($b.Slot -lt $g.Num) { $g.Num = $b.Slot }
  }
  foreach ($g in $groups) { $g.File = "Info{0}.png" -f $g.Num; $g.ParamNum = "{0:D5}" -f (1000 + $g.Num) }
  return ,$groups.ToArray()
}

# @brief $true for a board with the capability <InfoImage thirdPartyWhen> (badge instead of the OpenKNX logo)
function Test-ThirdPartyBoard($M, $Board) {
  return [bool]($M.Info -and $M.Info.ThirdWhen -and $Board.Cap[$M.Info.ThirdWhen])
}

# @brief Pictures above the device card name: per board the file of a matching <InfoImage><Logo>, else the badge (third-party
#        board) or the logo; boards grouped by file. Logo 00900, Badge 00901, own files Logo1..Logo10 = 00910..00919.
#        A board without picture ("" file) is in no group.
# @brief Content of a picture file as comparison key (the files are a few kB; no hash API, which FIPS policy can block)
function Get-FileContentHash([string]$Path) {
  return [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
}

function Get-CardMarks($M, $Boards) {
  $marks = New-Object System.Collections.Generic.List[object]
  if (-not $M.Info) { return ,$marks.ToArray() }
  $own = 0
  $used = @{}
  foreach ($b in $Boards) {
    $hits = @($M.Info.Logos | Where-Object { Test-Wildcard $_.Board $b.Define })
    foreach ($h in $hits) { $used[$h.Board] = $true }
    if ($hits.Count -gt 0) {
      $exact = @($hits | Where-Object { -not $_.Pattern })
      if ($exact.Count -gt 0) { $hits = $exact }
      if ($hits.Count -gt 1) { Stop-WithError ("{0}: {1} <InfoImage><Logo> entries match ({2})" -f $b.Define, $hits.Count, (($hits | ForEach-Object { $_.Board }) -join ", ")) }
      $file = $hits[0].File
    }
    elseif (Test-ThirdPartyBoard $M $b) { $file = $M.Info.Badge }
    else { $file = $M.Info.Logo }
    if (-not $file) { continue }
    # same picture = same file content (a path through another folder or link is the same picture)
    $hash = Get-FileContentHash $file
    $g = @($marks | Where-Object { $_.Hash -eq $hash }) | Select-Object -First 1
    if (-not $g) {
      if ($M.Info.Logo -and $hash -eq (Get-FileContentHash $M.Info.Logo)) { $name = "Logo"; $num = $script:LogoParamNum }
      elseif ($M.Info.Badge -and $hash -eq (Get-FileContentHash $M.Info.Badge)) { $name = "Badge"; $num = $script:BadgeParamNum }
      else {
        $own++
        if ($own -gt 10) { Stop-WithError "<InfoImage><Logo>: at most 10 own pictures" }
        $name = "Logo$own"; $num = "{0:D5}" -f (909 + $own)
      }
      $g = @{ Name = $name; File = $file; Num = $num; Hash = $hash; Boards = @() }
      $marks.Add($g)
    }
    $g.Boards += $b
  }
  foreach ($lg in $M.Info.Logos) { if (-not $used.ContainsKey($lg.Board)) { Write-Warn ("<InfoImage><Logo board=`"{0}`">: matches no board" -f $lg.Board) } }
  return ,$marks.ToArray()
}

# @brief Board text: HW_INFO_TEXT, else <Page infoDefault> (empty = none)
function Get-BoardText($M, $Board) {
  if ($Board.InfoText) { return $Board.InfoText }
  return $M.Page.InfoDefault
}

# @brief Text split into parts of at most MaxLen characters at sentence ends (ETS: 255 characters per text)
function Split-SentenceText([string]$Text, [int]$MaxLen = 255) {
  $parts = New-Object System.Collections.Generic.List[string]
  $cur = ""
  foreach ($sent in ($Text -split '(?<=[.!?])\s+')) {
    if (-not $sent) { continue }
    if ($sent.Length -gt $MaxLen) { throw "a sentence is longer than $MaxLen characters: $sent" }
    if ($cur -and ($cur.Length + 1 + $sent.Length) -gt $MaxLen) { $parts.Add($cur); $cur = "" }
    if ($cur) { $cur = $cur + " " + $sent } else { $cur = $sent }
  }
  if ($cur) { $parts.Add($cur) }
  return ,$parts.ToArray()
}

# @brief Board view of <Page> (a board is selected). With <InfoImage>: OpenKNX logo or third-party badge (picture in a
#        one-column grid, the pattern of the OGM-Common logo: a plain picture row sits in the value column), DEVICE_NAME as
#        headline, board text; with an info URL board text and QR picture side by side (grid, right column = picture width of
#        the ETS5 page width, rounded up; one separator per cell:
#        a nested block in a cell gets a scroll bar in ETS5). Without <InfoImage>: the board text. Then switches and notices.
function New-PageInfoXml($M, $Boards, [string]$SelRef, $Switches, $InfoGroups, [string]$Ind) {
  $sb = New-Object System.Text.StringBuilder
  if ($M.Info) {
    # picture row (logo, badge or own picture); boards without picture get no row (no empty grid)
    $marks = @($M.Marks)
    $marked = @($marks | ForEach-Object { $_.Boards })
    if ($marks.Count -gt 0) {
      $mi = $Ind
      $wrap = ($marked.Count -lt @($Boards).Count)
      if ($wrap) { [void]$sb.AppendLine(("$Ind<choose ParamRefId=`"$SelRef`"><when test=`"{0}`">" -f (Get-IdList $marked))); $mi = "$Ind  " }
      [void]$sb.AppendLine("$mi<ParameterBlock Id=`"%AID%_PB-nnn`" Name=`"ProfileMark`" Inline=`"true`" Layout=`"Grid`">")
      [void]$sb.AppendLine("$mi  <Rows><Row Id=`"%AID%_PB-nnn_R-1`" Name=`"Row1`" /></Rows>")
      [void]$sb.AppendLine("$mi  <Columns><Column Id=`"%AID%_PB-nnn_C-1`" Name=`"Col1`" Width=`"100%`" /></Columns>")
      [void]$sb.AppendLine("$mi  <choose ParamRefId=`"$SelRef`">")
      foreach ($k in $marks) { [void]$sb.AppendLine(("$mi    <when test=`"{0}`"><ParameterRefRef RefId=`"%AID%_P-%TT%{1}_R-%TT%{1}01`" Cell=`"1,1`" /></when>" -f (Get-IdList $k.Boards), $k.Num)) }
      [void]$sb.AppendLine("$mi  </choose>")
      [void]$sb.AppendLine("$mi</ParameterBlock>")
      if ($wrap) { [void]$sb.AppendLine("$Ind</when></choose>") }
    }
    $qrPct = [int][Math]::Ceiling($M.Info.Width * 100.0 / $script:EtsPageWidth)
    # name, board text and QR picture: boards grouped by these three
    $cards = New-Object System.Collections.Generic.List[object]
    foreach ($b in $Boards) {
      $t = Get-BoardText $M $b
      $qr = @($InfoGroups | Where-Object { $_.Url -ceq $b.InfoUrl }) | Select-Object -First 1
      $qrNum = ""; if ($qr) { $qrNum = $qr.ParamNum }
      $key = "{0}|{1}|{2}" -f $b.Name, $t, $qrNum
      $g = @($cards | Where-Object { $_.Key -ceq $key }) | Select-Object -First 1
      if (-not $g) { $g = @{ Key = $key; Name = $b.Name; Text = $t; QrNum = $qrNum; Boards = @() }; $cards.Add($g) }
      $g.Boards += $b
    }
    [void]$sb.AppendLine("$Ind<choose ParamRefId=`"$SelRef`">")
    foreach ($g in $cards) {
      [void]$sb.AppendLine(("$Ind  <when test=`"{0}`">" -f (Get-IdList $g.Boards)))
      [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Headline`" />" -f (ConvertTo-XmlText $g.Name)))
      if ($g.QrNum) {
        [void]$sb.AppendLine("$Ind    <ParameterBlock Id=`"%AID%_PB-nnn`" Name=`"ProfileCard`" Inline=`"true`" Layout=`"Grid`">")
        [void]$sb.AppendLine("$Ind      <Rows><Row Id=`"%AID%_PB-nnn_R-1`" Name=`"Row1`" /></Rows>")
        [void]$sb.AppendLine(("$Ind      <Columns><Column Id=`"%AID%_PB-nnn_C-1`" Name=`"Col1`" Width=`"{0}%`" /><Column Id=`"%AID%_PB-nnn_C-2`" Name=`"Col2`" Width=`"{1}%`" /></Columns>" -f (100 - $qrPct), $qrPct))
        [void]$sb.AppendLine(("$Ind      <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" Cell=`"1,1`" />" -f (ConvertTo-XmlText $g.Text)))
        [void]$sb.AppendLine(("$Ind      <ParameterRefRef RefId=`"%AID%_P-%TT%{0}_R-%TT%{0}01`" Cell=`"1,2`" />" -f $g.QrNum))
        [void]$sb.AppendLine("$Ind    </ParameterBlock>")
      }
      elseif ($g.Text) { [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" />" -f (ConvertTo-XmlText $g.Text))) }
      [void]$sb.AppendLine("$Ind  </when>")
    }
    [void]$sb.AppendLine("$Ind</choose>")
  }
  else {
    # board text, boards grouped by text
    $texts = New-Object System.Collections.Generic.List[object]
    foreach ($b in $Boards) {
      $t = Get-BoardText $M $b
      if (-not $t) { continue }
      $g = @($texts | Where-Object { $_.Text -ceq $t }) | Select-Object -First 1
      if (-not $g) { $g = @{ Text = $t; Boards = @() }; $texts.Add($g) }
      $g.Boards += $b
    }
    if ($texts.Count -gt 0) {
      [void]$sb.AppendLine("$Ind<choose ParamRefId=`"$SelRef`">")
      foreach ($g in $texts) {
        [void]$sb.AppendLine(("$Ind  <when test=`"{0}`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{1}`" /></when>" -f (Get-IdList $g.Boards), (ConvertTo-XmlText $g.Text)))
      }
      [void]$sb.AppendLine("$Ind</choose>")
    }
  }
  # optional: firmware of the board (<Page firmware="Firmware: {env}">, the release env(s) of the board)
  if ($M.Page.Firmware) {
    $fw = New-Object System.Collections.Generic.List[object]
    foreach ($b in $Boards) {
      if (@($b.Envs).Count -eq 0) { continue }
      $t = $M.Page.Firmware -replace '\{env\}', (@($b.Envs) -join ", ")
      if ($t.Length -gt 255) { Stop-WithError ("<Page firmware>: the text of 0x{0:X4} has {1} characters, ETS shows at most 255" -f [int]$b.HwId, $t.Length) }
      $g = @($fw | Where-Object { $_.Text -ceq $t }) | Select-Object -First 1
      if (-not $g) { $g = @{ Text = $t; Boards = @() }; $fw.Add($g) }
      $g.Boards += $b
    }
    if ($fw.Count -gt 0) {
      [void]$sb.AppendLine("$Ind<choose ParamRefId=`"$SelRef`">")
      foreach ($g in $fw) { [void]$sb.AppendLine(("$Ind  <when test=`"{0}`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{1}`" /></when>" -f (Get-IdList $g.Boards), (ConvertTo-XmlText $g.Text))) }
      [void]$sb.AppendLine("$Ind</choose>")
    }
  }
  # optional: hint after a change of the hardware (<Page changeInfo>), shown with every board
  if ($M.Page.ChangeInfo) { [void]$sb.AppendLine(("$Ind<ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Information`" />" -f (ConvertTo-XmlText $M.Page.ChangeInfo))) }
  # switches: on/off parameter where the board has the capability and not the fixedBy one
  foreach ($s in $Switches) {
    $shown = @($Boards | Where-Object { $_.Caps[$s.Index] -and -not ($s.FixedIdx -ge 0 -and $_.Caps[$s.FixedIdx]) })
    if ($shown.Count -eq 0) { continue }
    [void]$sb.AppendLine("$Ind<choose ParamRefId=`"$SelRef`">")
    [void]$sb.AppendLine(("$Ind  <when test=`"{0}`">" -f (Get-IdList $shown)))
    [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" />" -f (ConvertTo-XmlText $s.Cap.Text)))
    [void]$sb.AppendLine(("$Ind    <ParameterRefRef RefId=`"%AID%_P-%TT%{0}_R-%TT%{0}01`" IndentLevel=`"1`" />" -f $s.OnNum))
    [void]$sb.AppendLine("$Ind  </when>")
    [void]$sb.AppendLine("$Ind</choose>")
  }
  # notices: title as information box, then its parts as text
  foreach ($nt in $M.Notices) {
    $ci = 0; for ($i = 0; $i -lt $M.Capabilities.Count; $i++) { if ($M.Capabilities[$i].Name -eq $nt.When) { $ci = $i } }
    $with = @($Boards | Where-Object { $_.Caps[$ci] })
    if ($with.Count -eq 0) { continue }
    [void]$sb.AppendLine("$Ind<choose ParamRefId=`"$SelRef`">")
    [void]$sb.AppendLine(("$Ind  <when test=`"{0}`">" -f (Get-IdList $with)))
    [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Information`" />" -f (ConvertTo-XmlText $nt.Title)))
    foreach ($part in $nt.Parts) {
      [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" />" -f (ConvertTo-XmlText $part)))
    }
    [void]$sb.AppendLine("$Ind  </when>")
    [void]$sb.AppendLine("$Ind</choose>")
  }
  return $sb.ToString()
}

# @brief <Page> below the hardware selection. No board selected: separator line, headline queryTitle, query text, the query
#        button, queryHelp (information box), the queryImage picture (one-column grid, the full page width), then the
#        unselected* / updateInfo texts. A board selected: New-PageInfoXml (device card, switches, notices). The query button
#        exists only in the first case: a selected board needs no query (back to "Nicht gewaehlt").
function New-PageBodyXml($M, $Boards, [string]$SelRef, $Switches, $InfoGroups, [string]$Ind) {
  $sb = New-Object System.Text.StringBuilder
  $p = $M.Prefix
  [void]$sb.AppendLine("$Ind<choose ParamRefId=`"$SelRef`">")
  [void]$sb.AppendLine("$Ind  <when test=`"$($M.UnselectedValue)`">")
  [void]$sb.AppendLine("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"`" UIHint=`"HorizontalRuler`" />")
  if ($M.Page.QueryTitle) { [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Headline`" />" -f (ConvertTo-XmlText $M.Page.QueryTitle))) }
  if ($M.Page.Query) { [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" />" -f (ConvertTo-XmlText $M.Page.Query))) }
  [void]$sb.AppendLine(("$Ind    <Button Id=`"%AID%_B-%TT%00001`" Text=`"{0}`" EventHandler=`"{1}_detectHardware`" EventHandlerOnline=`"ConnectionOriented`" />" -f (ConvertTo-XmlText $M.Page.Button), $p))
  foreach ($part in $M.Page.QueryHelpParts) { [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Information`" />" -f (ConvertTo-XmlText $part))) }
  if ($M.Page.ImageFile) {
    # one-column grid: the picture takes the page width instead of the value column (the pattern of the OGM-Common logo)
    [void]$sb.AppendLine("$Ind    <ParameterBlock Id=`"%AID%_PB-nnn`" Name=`"ProfileSteps`" Inline=`"true`" Layout=`"Grid`">")
    [void]$sb.AppendLine("$Ind      <Rows><Row Id=`"%AID%_PB-nnn_R-1`" Name=`"Row1`" /></Rows>")
    [void]$sb.AppendLine("$Ind      <Columns><Column Id=`"%AID%_PB-nnn_C-1`" Name=`"Col1`" Width=`"100%`" /></Columns>")
    [void]$sb.AppendLine(("$Ind      <ParameterRefRef RefId=`"%AID%_P-%TT%{0}_R-%TT%{0}01`" Cell=`"1,1`" />" -f $script:StepsParamNum))
    [void]$sb.AppendLine("$Ind    </ParameterBlock>")
  }
  $more = @($M.Page.UnselectedInfo, $M.Page.UnselectedText, $M.Page.UpdateInfo | Where-Object { $_ })
  # blank line between the button block and the texts below (the OGM-Common pattern after its module sync buttons)
  if ($more.Count -gt 0) { [void]$sb.AppendLine("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"&#10;`" />") }
  if ($M.Page.UnselectedInfo) { [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Information`" />" -f (ConvertTo-XmlText $M.Page.UnselectedInfo))) }
  if ($M.Page.UnselectedText) { [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" />" -f (ConvertTo-XmlText $M.Page.UnselectedText))) }
  if ($M.Page.UpdateInfo) { [void]$sb.AppendLine(("$Ind    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Information`" />" -f (ConvertTo-XmlText $M.Page.UpdateInfo))) }
  [void]$sb.AppendLine("$Ind  </when>")
  $left = New-PageInfoXml $M $Boards $SelRef $Switches $InfoGroups "$Ind    "
  if ($left) {
    [void]$sb.AppendLine("$Ind  <when default=`"true`">")
    [void]$sb.Append($left)
    [void]$sb.AppendLine("$Ind  </when>")
  }
  [void]$sb.AppendLine("$Ind</choose>")
  return $sb.ToString()
}

function New-ShareXml($M, $Boards) {
  $p = $M.Prefix
  $refs = Get-ParamRefIds $M
  $selRef = $refs.SelectTT
  $check = [System.Char]::ConvertFromUtf32(0x2714)
  $dash = [System.Char]::ConvertFromUtf32(0x2013)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
  [void]$sb.AppendLine('<?xml-model href="../../Organization/knxprod-support/knx_project_20/knx-editor.xsd" type="application/xml" schematypens="http://www.w3.org/2001/XMLSchema"?>')
  [void]$sb.AppendLine('<KNX xmlns:op="http://github.com/OpenKNX/OpenKNXproducer" xmlns="http://knx.org/xml/project/20" CreatedBy="KNX MT" ToolVersion="5.1.255.16695">')
  [void]$sb.AppendLine("  <!-- Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 - do not edit -->")
  [void]$sb.AppendLine('  <ManufacturerData><Manufacturer><ApplicationPrograms><ApplicationProgram>')
  [void]$sb.AppendLine('    <Static>')
  [void]$sb.AppendLine('      <ParameterTypes>')
  [void]$sb.AppendLine("        <ParameterType Id=`"%AID%_PT-${p}HardwareSelect`" Name=`"${p}HardwareSelect`">")
  [void]$sb.AppendLine('          <TypeRestriction Base="Value" SizeInBit="16">')
  [void]$sb.AppendLine(("            <Enumeration Text=`"{0}`" Value=`"{1}`" Id=`"%ENID%`" />" -f "Nicht gew$([System.Char]::ConvertFromUtf32(0xE4))hlt", $($M.UnselectedValue)))
  foreach ($b in $Boards) {
    [void]$sb.AppendLine(("            <Enumeration Text=`"{0}`" Value=`"{1}`" Id=`"%ENID%`" />" -f (ConvertTo-XmlText $b.Name), $b.HwId))
  }
  [void]$sb.AppendLine('          </TypeRestriction>')
  [void]$sb.AppendLine('        </ParameterType>')
  $switches = Get-Switches $M
  if ($switches.Count -gt 0) {
    [void]$sb.AppendLine("        <ParameterType Id=`"%AID%_PT-${p}OnOff`" Name=`"${p}OnOff`">")
    [void]$sb.AppendLine('          <TypeRestriction Base="Value" SizeInBit="1">')
    [void]$sb.AppendLine('            <Enumeration Text="aus" Value="0" Id="%ENID%" />')
    [void]$sb.AppendLine('            <Enumeration Text="ein" Value="1" Id="%ENID%" />')
    [void]$sb.AppendLine('          </TypeRestriction>')
    [void]$sb.AppendLine('        </ParameterType>')
    [void]$sb.AppendLine("        <ParameterType Id=`"%AID%_PT-${p}Reported`" Name=`"${p}Reported`">")
    [void]$sb.AppendLine('          <TypeRestriction Base="Value" SizeInBit="2">')
    [void]$sb.AppendLine('            <Enumeration Text="nicht abgefragt" Value="0" Id="%ENID%" />')
    [void]$sb.AppendLine('            <Enumeration Text="vorhanden" Value="1" Id="%ENID%" />')
    [void]$sb.AppendLine('            <Enumeration Text="nicht vorhanden" Value="2" Id="%ENID%" />')
    [void]$sb.AppendLine('          </TypeRestriction>')
    [void]$sb.AppendLine('        </ParameterType>')
  }
  $infoGroups = @($M.InfoGroups)
  # device card pictures: logo and badge left-aligned (full-width row), QR + link right-aligned in its grid cell
  $marks = @($M.Marks)
  foreach ($k in $marks) {
    [void]$sb.AppendLine(("        <ParameterType Id=`"%AID%_PT-{0}{1}`" Name=`"{0}{1}`"><TypePicture RefId=`"%FILE-{0}{1}%`" HorizontalAlignment=`"Left`" /></ParameterType>" -f $p, $k.Name))
  }
  foreach ($g in $infoGroups) {
    [void]$sb.AppendLine(("        <ParameterType Id=`"%AID%_PT-{0}Info{1}`" Name=`"{0}Info{1}`"><TypePicture RefId=`"%FILE-{0}Info{1}%`" HorizontalAlignment=`"Right`" /></ParameterType>" -f $p, $g.Num))
  }
  $steps = [bool]($M.Page -and $M.Page.ImageFile)
  $treeTitle = [bool]($M.Page -and $M.Page.UnselectedTitle)
  if ($steps) { [void]$sb.AppendLine(("        <ParameterType Id=`"%AID%_PT-{0}Steps`" Name=`"{0}Steps`"><TypePicture RefId=`"%FILE-{0}Steps%`" HorizontalAlignment=`"Left`" /></ParameterType>" -f $p)) }
  if ($treeTitle) { [void]$sb.AppendLine(("        <ParameterType Id=`"%AID%_PT-{0}PageTitle`" Name=`"{0}PageTitle`"><TypeText SizeInBit=`"2040`" /></ParameterType>" -f $p)) }
  for ($bi = 0; $bi -lt $Boards.Count; $bi++) {
    $b = $Boards[$bi]
    foreach ($role in $M.Roles) {
      [void]$sb.AppendLine(("        <ParameterType Id=`"%AID%_PT-{0}Pin{1}B{2}`" Name=`"{0}Pin{1}B{2}`">" -f $p, $role.Number, $b.Slot))
      [void]$sb.AppendLine('          <TypeRestriction Base="Value" SizeInBit="8">')
      [void]$sb.AppendLine(("            <Enumeration Text=`"nicht verwendet`" Value=`"{0}`" Id=`"%ENID%`" />" -f $PIN_UNUSED))
      foreach ($pin in $b.Pins[$role.Name]) {
        [void]$sb.AppendLine(("            <Enumeration Text=`"{0} (GPIO {1})`" Value=`"{1}`" Id=`"%ENID%`" />" -f (ConvertTo-XmlText $pin.Label), $pin.Gpio))
      }
      [void]$sb.AppendLine('          </TypeRestriction>')
      [void]$sb.AppendLine('        </ParameterType>')
    }
  }
  [void]$sb.AppendLine('      </ParameterTypes>')
  [void]$sb.AppendLine('      <Parameters>')
  $selLabel = "Hardware"; if ($M.Page) { $selLabel = ConvertTo-XmlText $M.Page.Label }
  [void]$sb.AppendLine("        <Union SizeInBit=`"16`">")
  [void]$sb.AppendLine('          <Memory CodeSegment="%MID%" Offset="0" BitOffset="0" />')
  [void]$sb.AppendLine("          <Parameter Id=`"%AID%_UP-%TT%00001`" Name=`"HardwareSelect`" ParameterType=`"%AID%_PT-${p}HardwareSelect`" Offset=`"0`" BitOffset=`"0`" Text=`"$selLabel`" Value=`"$($M.UnselectedValue)`" />")
  [void]$sb.AppendLine('        </Union>')
  $offset = 2
  foreach ($role in $M.Roles) {
    for ($slot = 1; $slot -le $role.Count; $slot++) {
      [void]$sb.AppendLine('        <Union SizeInBit="8">')
      [void]$sb.AppendLine(("          <Memory CodeSegment=`"%MID%`" Offset=`"{0}`" BitOffset=`"0`" />" -f $offset))
      for ($bi = 0; $bi -lt $Boards.Count; $bi++) {
        $num = Get-PinParamNumber $role.Number $slot $Boards[$bi].Slot
        $text = ConvertTo-XmlText ("{0} {1}" -f $role.Text, $slot)
        [void]$sb.AppendLine(("          <Parameter Id=`"%AID%_UP-%TT%{0:D5}`" Name=`"{1}{2}B{3}`" ParameterType=`"%AID%_PT-{4}Pin{5}B{3}`" Offset=`"0`" BitOffset=`"0`" Text=`"{6}`" Value=`"{7}`" />" -f $num, $role.Name, $slot, $Boards[$bi].Slot, $p, $role.Number, $text, $PIN_UNUSED))
      }
      [void]$sb.AppendLine('        </Union>')
      $offset++
    }
  }
  # switches: one byte after the GPIO roles (end of the module memory, no other parameter moves); plain
  # parameters, so a hidden switch downloads its default (on); the firmware state has no memory (ETS only)
  foreach ($s in $switches) {
    [void]$sb.AppendLine(("        <Parameter Id=`"%AID%_P-%TT%{0}`" Name=`"{1}On`" ParameterType=`"%AID%_PT-{2}OnOff`" Text=`"aktiv`" Value=`"1`">" -f $s.OnNum, $s.Cap.Name, $p))
    [void]$sb.AppendLine(("          <Memory CodeSegment=`"%MID%`" Offset=`"{0}`" BitOffset=`"{1}`" />" -f $offset, $s.Bit))
    [void]$sb.AppendLine('        </Parameter>')
    [void]$sb.AppendLine(("        <Parameter Id=`"%AID%_P-%TT%{0}`" Name=`"{1}Fw`" ParameterType=`"%AID%_PT-{2}Reported`" Text=`"Firmware`" Value=`"0`" />" -f $s.FwNum, $s.Cap.Name, $p))
  }
  # device card pictures without memory
  foreach ($k in $marks) {
    [void]$sb.AppendLine(("        <Parameter Id=`"%AID%_P-%TT%{0}`" Name=`"{1}`" ParameterType=`"%AID%_PT-{2}{1}`" Text=`"`" Access=`"Read`" Value=`"`" />" -f $k.Num, $k.Name, $p))
  }
  foreach ($g in $infoGroups) {
    [void]$sb.AppendLine(("        <Parameter Id=`"%AID%_P-%TT%{0}`" Name=`"Info{1}`" ParameterType=`"%AID%_PT-{2}Info{1}`" Text=`"`" Access=`"Read`" Value=`"`" />" -f $g.ParamNum, $g.Num, $p))
  }
  if ($steps) { [void]$sb.AppendLine(("        <Parameter Id=`"%AID%_P-%TT%{0}`" Name=`"Steps`" ParameterType=`"%AID%_PT-{1}Steps`" Text=`"`" Access=`"Read`" Value=`"`" />" -f $script:StepsParamNum, $p)) }
  # page text of the tree: no memory, Access None; the calculation sets it from the selection, the default fits "not selected"
  if ($treeTitle) { [void]$sb.AppendLine(("        <Parameter Id=`"%AID%_P-%TT%{0}`" Name=`"PageTitle`" ParameterType=`"%AID%_PT-{1}PageTitle`" Text=`"`" Access=`"None`" Value=`"{2}`" />" -f $script:PageTitleParamNum, $p, (ConvertTo-XmlText $M.Page.UnselectedTitle))) }
  [void]$sb.AppendLine('      </Parameters>')
  [void]$sb.AppendLine('      <ParameterRefs>')
  [void]$sb.AppendLine("        <ParameterRef Id=`"$selRef`" RefId=`"%AID%_UP-%TT%00001`" />")
  foreach ($role in $M.Roles) {
    for ($slot = 1; $slot -le $role.Count; $slot++) {
      for ($bi = 0; $bi -lt $Boards.Count; $bi++) {
        $num = "{0:D5}" -f (Get-PinParamNumber $role.Number $slot $Boards[$bi].Slot)
        [void]$sb.AppendLine("        <ParameterRef Id=`"%AID%_UP-%TT%${num}_R-%TT%${num}01`" RefId=`"%AID%_UP-%TT%${num}`" />")
      }
    }
  }
  foreach ($s in $switches) {
    [void]$sb.AppendLine(("        <ParameterRef Id=`"%AID%_P-%TT%{0}_R-%TT%{0}01`" RefId=`"%AID%_P-%TT%{0}`" />" -f $s.OnNum))
    [void]$sb.AppendLine(("        <ParameterRef Id=`"%AID%_P-%TT%{0}_R-%TT%{0}01`" RefId=`"%AID%_P-%TT%{0}`" Access=`"Read`" />" -f $s.FwNum))
  }
  foreach ($k in $marks) {
    [void]$sb.AppendLine(("        <ParameterRef Id=`"%AID%_P-%TT%{0}_R-%TT%{0}01`" RefId=`"%AID%_P-%TT%{0}`" />" -f $k.Num))
  }
  foreach ($g in $infoGroups) {
    [void]$sb.AppendLine(("        <ParameterRef Id=`"%AID%_P-%TT%{0}_R-%TT%{0}01`" RefId=`"%AID%_P-%TT%{0}`" />" -f $g.ParamNum))
  }
  if ($steps) { [void]$sb.AppendLine(("        <ParameterRef Id=`"%AID%_P-%TT%{0}_R-%TT%{0}01`" RefId=`"%AID%_P-%TT%{0}`" />" -f $script:StepsParamNum)) }
  if ($treeTitle) { [void]$sb.AppendLine(("        <ParameterRef Id=`"{0}`" RefId=`"%AID%_P-%TT%{1}`" />" -f $refs.TitleTT, $script:PageTitleParamNum)) }
  [void]$sb.AppendLine('      </ParameterRefs>')
  if ($treeTitle) {
    # tree text: <page> while a board is selected, unselectedTitle while not (runs on every change of the selection)
    [void]$sb.AppendLine('      <ParameterCalculations>')
    [void]$sb.AppendLine(("        <ParameterCalculation Id=`"%AID%_PC-%TT%{0}`" Language=`"JavaScript`" Name=`"{1}PageTitle`" LRTransformationFunc=`"{1}_pageTitle`" RLTransformationFunc=`"{1}_pageTitleNone`">" -f $script:PageTitleParamNum, $p))
    [void]$sb.AppendLine(("          <LParameters><ParameterRefRef RefId=`"{0}`" AliasName=`"Select`" /></LParameters>" -f $selRef))
    [void]$sb.AppendLine(("          <RParameters><ParameterRefRef RefId=`"{0}`" AliasName=`"Title`" /></RParameters>" -f $refs.TitleTT))
    [void]$sb.AppendLine('        </ParameterCalculation>')
    [void]$sb.AppendLine('      </ParameterCalculations>')
  }
  [void]$sb.AppendLine('      <Script>')
  [void]$sb.AppendLine(("        <op:include href=`"{0}`" type=`"script`" />" -f [System.IO.Path]::GetFileName($M.Outputs.script)))
  [void]$sb.AppendLine('      </Script>')
  [void]$sb.AppendLine('    </Static>')
  [void]$sb.AppendLine('    <Dynamic>')
  [void]$sb.AppendLine(("      <Channel Id=`"%AID%_CH-%PREFIX%`" Number=`"%PREFIX%`" Name=`"HardwareProfile`" Text=`"{0}`" Icon=`"cog-outline`">" -f (ConvertTo-XmlText $M.Text)))
  if ($M.Page) {
    $helpAttr = ""
    if ($M.Page.Help) { $helpAttr = " HelpContext=`"$($M.Page.Help)`"" }
    $blockText = ConvertTo-XmlText $M.Page.Text
    # unselectedTitle: the tree shows the memoryless page text the calculation sets ({{0:...}} = text until it is set)
    if ($treeTitle) { $blockText = "{{0:" + $blockText + "}}"; $helpAttr += " TextParameterRefId=`"$($refs.TitleTT)`"" }
    [void]$sb.AppendLine(("        <ParameterBlock Id=`"%AID%_PB-nnn`" Name=`"Profile`" Text=`"{0}`" Icon=`"{1}`"{2}>" -f $blockText, $M.Page.Icon, $helpAttr))
  }
  else { [void]$sb.AppendLine("        <ParameterBlock Id=`"%AID%_PB-nnn`" Name=`"Profile`" Text=`"Ger$([System.Char]::ConvertFromUtf32(0xE4))teprofil`" Icon=`"cog-outline`">") }
  $headline = "Hardware"; if ($M.Page) { $headline = ConvertTo-XmlText $M.Page.Title }
  if ($headline) { [void]$sb.AppendLine("          <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"$headline`" UIHint=`"Headline`" />") }
  if ($M.Page -and $M.Page.Intro) { [void]$sb.AppendLine(("          <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" />" -f (ConvertTo-XmlText $M.Page.Intro))) }
  [void]$sb.AppendLine("          <ParameterRefRef RefId=`"$selRef`" IndentLevel=`"1`" />")
  if ($M.Page) { [void]$sb.Append((New-PageBodyXml $M $Boards $selRef $switches $infoGroups "          ")) }
  else {
    [void]$sb.AppendLine("          <Button Id=`"%AID%_B-%TT%00001`" Text=`"Hardware vom Ger$([System.Char]::ConvertFromUtf32(0xE4))t abfragen`" EventHandler=`"${p}_detectHardware`" EventHandlerOnline=`"ConnectionOriented`" />")
    [void]$sb.AppendLine("          <choose ParamRefId=`"$selRef`">")
    [void]$sb.AppendLine("            <when test=`"$($M.UnselectedValue)`">")
    $ae = [System.Char]::ConvertFromUtf32(0xE4)
    $unselText = "Bitte die Hardware w${ae}hlen oder vom Ger${ae}t abfragen. Ohne Auswahl blendet die Applikation alle hardwareabh${ae}ngigen Einstellungen aus."
    if ($M.Unselected -eq "showAll") { $unselText = "Bitte die Hardware w${ae}hlen oder vom Ger${ae}t abfragen. Ohne Auswahl zeigt die Applikation alle Einstellungen, auch solche, die das Ger${ae}t nicht hat." }
    [void]$sb.AppendLine(("              <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Information`" />" -f $unselText))
    [void]$sb.AppendLine("            </when>")
    [void]$sb.AppendLine("            <when default=`"true`">")
    [void]$sb.AppendLine("              <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"F$([System.Char]::ConvertFromUtf32(0xE4))higkeiten dieser Hardware`" UIHint=`"Headline`" />")
    for ($i = 0; $i -lt $M.Capabilities.Count; $i++) {
      $c = $M.Capabilities[$i]
      $with = @($Boards | Where-Object { $_.Caps[$i] })
      $s = @($switches | Where-Object { $_.Index -eq $i }) | Select-Object -First 1
      [void]$sb.AppendLine("              <choose ParamRefId=`"$selRef`">")
      if ($s) {
        # switch: fixed boards show "always on", the others the firmware state of the last query and the switch
        $fixed = @($with | Where-Object { $s.FixedIdx -ge 0 -and $_.Caps[$s.FixedIdx] })
        $switchable = @($with | Where-Object { -not ($s.FixedIdx -ge 0 -and $_.Caps[$s.FixedIdx]) })
        $fwRef = "%AID%_P-%TT%{0}_R-%TT%{0}01" -f $s.FwNum
        $onRef = "%AID%_P-%TT%{0}_R-%TT%{0}01" -f $s.OnNum
        if ($fixed.Count -gt 0) {
          [void]$sb.AppendLine(("                <when test=`"{0}`">" -f (Get-IdList $fixed)))
          [void]$sb.AppendLine(("                  <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}  {1}: immer ein ({2})`" />" -f $check, (ConvertTo-XmlText $c.Text), (ConvertTo-XmlText $M.Capabilities[$s.FixedIdx].Text)))
          [void]$sb.AppendLine("                  <ParameterRefRef RefId=`"$fwRef`" IndentLevel=`"1`" />")
          [void]$sb.AppendLine("                </when>")
        }
        if ($switchable.Count -gt 0) {
          [void]$sb.AppendLine(("                <when test=`"{0}`">" -f (Get-IdList $switchable)))
          [void]$sb.AppendLine(("                  <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}  {1}`" />" -f $check, (ConvertTo-XmlText $c.Text)))
          [void]$sb.AppendLine("                  <ParameterRefRef RefId=`"$fwRef`" IndentLevel=`"1`" />")
          [void]$sb.AppendLine("                  <ParameterRefRef RefId=`"$onRef`" IndentLevel=`"1`" />")
          [void]$sb.AppendLine("                </when>")
        }
      }
      else {
        [void]$sb.AppendLine(("                <when test=`"{0}`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{1}  {2}`" /></when>" -f (Get-IdList $with), $check, (ConvertTo-XmlText $c.Text)))
      }
      [void]$sb.AppendLine(("                <when default=`"true`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}  {1}: nicht vorhanden`" /></when>" -f $dash, (ConvertTo-XmlText $c.Text)))
      [void]$sb.AppendLine("              </choose>")
    }
    for ($i = 0; $i -lt $M.Values.Count; $i++) {
      $v = $M.Values[$i]
      $groups = $Boards | Group-Object { $_.Values[$i] } | Sort-Object { [int]$_.Name }
      [void]$sb.AppendLine("              <choose ParamRefId=`"$selRef`">")
      foreach ($g in $groups) {
        $valText = "{0}" -f $g.Name
        if ([int]$g.Name -eq 0) { $valText = $dash }
        elseif ($v.Unit) { $valText = "{0} {1}" -f $g.Name, $v.Unit }
        [void]$sb.AppendLine(("                <when test=`"{0}`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{1}: {2}`" /></when>" -f (Get-IdList $g.Group), (ConvertTo-XmlText $v.Text), (ConvertTo-XmlText $valText)))
      }
      [void]$sb.AppendLine("              </choose>")
    }
    [void]$sb.AppendLine("            </when>")
    [void]$sb.AppendLine("          </choose>")
  }
  foreach ($role in $M.Roles) {
    $withPins = @($Boards | Where-Object { @($_.Pins[$role.Name]).Count -gt 0 })
    if ($withPins.Count -eq 0) { continue }   # a <choose> needs at least one <when> (knx.xsd ChannelChoose_t)
    [void]$sb.AppendLine("          <choose ParamRefId=`"$selRef`">")
    [void]$sb.AppendLine(("            <when test=`"{0}`">" -f (Get-IdList $withPins)))
    [void]$sb.AppendLine(("              <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Headline`" />" -f (ConvertTo-XmlText $role.Text)))
    [void]$sb.AppendLine("            </when>")
    [void]$sb.AppendLine("          </choose>")
    for ($slot = 1; $slot -le $role.Count; $slot++) {
      [void]$sb.AppendLine("          <choose ParamRefId=`"$selRef`">")
      for ($bi = 0; $bi -lt $Boards.Count; $bi++) {
        if (@($Boards[$bi].Pins[$role.Name]).Count -eq 0) { continue }
        $num = "{0:D5}" -f (Get-PinParamNumber $role.Number $slot $Boards[$bi].Slot)
        [void]$sb.AppendLine(("            <when test=`"{0}`"><ParameterRefRef RefId=`"%AID%_UP-%TT%{1}_R-%TT%{1}01`" IndentLevel=`"1`" /></when>" -f $Boards[$bi].HwId, $num))
      }
      [void]$sb.AppendLine("          </choose>")
    }
  }
  [void]$sb.AppendLine('        </ParameterBlock>')
  [void]$sb.AppendLine('      </Channel>')
  [void]$sb.AppendLine('    </Dynamic>')
  if ($infoGroups.Count -gt 0 -or $marks.Count -gt 0 -or $steps) {
    # baggages: Baggages/<prefix>Info/Logo.png, Badge.png, Info<n>.png, Steps.png next to this file (written by the generator)
    [void]$sb.AppendLine('  </ApplicationProgram></ApplicationPrograms>')
    [void]$sb.AppendLine('  <Baggages>')
    foreach ($k in $marks) {
      [void]$sb.AppendLine(("    <Baggage TargetPath=`"{0}Info`" Name=`"{1}.png`" Id=`"%FILE-{0}{1}%`"><FileInfo TimeInfo=`"%DATETIME%`" /></Baggage>" -f $p, $k.Name))
    }
    foreach ($g in $infoGroups) {
      [void]$sb.AppendLine(("    <Baggage TargetPath=`"{0}Info`" Name=`"{1}`" Id=`"%FILE-{0}Info{2}%`"><FileInfo TimeInfo=`"%DATETIME%`" /></Baggage>" -f $p, $g.File, $g.Num))
    }
    if ($steps) { [void]$sb.AppendLine(("    <Baggage TargetPath=`"{0}Info`" Name=`"Steps.png`" Id=`"%FILE-{0}Steps%`"><FileInfo TimeInfo=`"%DATETIME%`" /></Baggage>" -f $p)) }
    [void]$sb.AppendLine('  </Baggages>')
    [void]$sb.AppendLine('  </Manufacturer></ManufacturerData>')
  }
  else { [void]$sb.AppendLine('  </ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData>') }
  [void]$sb.AppendLine('</KNX>')
  return $sb.ToString()
}

# @brief Developer view module (<Page dev>): a memoryless checkbox (default off) and per board the sections Board (HW-ID,
#        board number, define, info URL, values outside <Page features> with their names), Module und Funktionen (<Page
#        features>), Ports (table), Fest verdrahtete Relais; firmware state of the last query of switches. Own op:define
#        (own ModuleType) in the development product only; references to the hardware module use its ModuleType literally.
function New-DevShareXml($M, $Boards) {
  $p = $M.Prefix
  $refs = Get-ParamRefIds $M
  $selRef = $refs.Select
  $tt = "{0:D2}" -f $M.ModuleType
  $devRef = "%AID%_P-%TT%09001_R-%TT%0900101"
  $switches = Get-Switches $M
  $sb = New-Object System.Text.StringBuilder
  $sep = {
    param($t, $extra)
    if ($t.Length -gt 255) { Stop-WithError ("developer view: text longer than 255 characters (ETS limit): {0}" -f $t) }
    [void]$sb.AppendLine(("                  <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`"{1} />" -f (ConvertTo-XmlText $t), $extra))
  }
  [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
  [void]$sb.AppendLine('<KNX xmlns:op="http://github.com/OpenKNX/OpenKNXproducer" xmlns="http://knx.org/xml/project/20" CreatedBy="KNX MT" ToolVersion="5.1.255.16695">')
  [void]$sb.AppendLine("  <!-- Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 - do not edit -->")
  [void]$sb.AppendLine('  <ManufacturerData><Manufacturer><ApplicationPrograms><ApplicationProgram>')
  [void]$sb.AppendLine('    <Static>')
  [void]$sb.AppendLine('      <ParameterTypes>')
  [void]$sb.AppendLine("        <ParameterType Id=`"%AID%_PT-${p}DevCheck`" Name=`"${p}DevCheck`">")
  [void]$sb.AppendLine('          <TypeNumber SizeInBit="1" Type="unsignedInt" minInclusive="0" maxInclusive="1" UIHint="CheckBox" />')
  [void]$sb.AppendLine('        </ParameterType>')
  [void]$sb.AppendLine('      </ParameterTypes>')
  [void]$sb.AppendLine('      <Parameters>')
  [void]$sb.AppendLine("        <Parameter Id=`"%AID%_P-%TT%09001`" Name=`"DevView`" ParameterType=`"%AID%_PT-${p}DevCheck`" Text=`"Entwickleransicht`" Value=`"0`" />")
  [void]$sb.AppendLine('      </Parameters>')
  [void]$sb.AppendLine('      <ParameterRefs>')
  [void]$sb.AppendLine("        <ParameterRef Id=`"$devRef`" RefId=`"%AID%_P-%TT%09001`" />")
  [void]$sb.AppendLine('      </ParameterRefs>')
  [void]$sb.AppendLine('    </Static>')
  [void]$sb.AppendLine('    <Dynamic>')
  [void]$sb.AppendLine("      <Channel Id=`"%AID%_CH-%PREFIX%`" Number=`"%PREFIX%`" Name=`"DevView`" Text=`"Entwickleransicht`">")
  [void]$sb.AppendLine("        <ParameterBlock Id=`"%AID%_PB-nnn`" Name=`"DevView`" Text=`"Entwickleransicht`">")
  [void]$sb.AppendLine("          <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"`" UIHint=`"HorizontalRuler`" />")
  [void]$sb.AppendLine("          <ParameterRefRef RefId=`"$devRef`" />")
  [void]$sb.AppendLine("          <choose ParamRefId=`"$devRef`">")
  [void]$sb.AppendLine("            <when test=`"1`">")
  [void]$sb.AppendLine("              <choose ParamRefId=`"$selRef`">")
  foreach ($b in $Boards) {
    [void]$sb.AppendLine(("                <when test=`"{0}`">" -f $b.HwId))
    & $sep "Board" ' UIHint="Headline"'
    & $sep ("HW-ID: 0x{0:X4}" -f [int]$b.HwId) ""
    & $sep ("Board-Nummer: {0}" -f $b.Slot) ""
    & $sep ("Board-Define: {0}" -f $b.Define) ""
    if ($M.Info) {
      if ($b.InfoUrlOwn) { & $sep ("Info-URL: {0}" -f $b.InfoUrl) "" }
      elseif ($b.InfoUrl) { & $sep ("Info-URL: (keine, Standard {0})" -f $b.InfoUrl) "" }
      else { & $sep "Info-URL: (keine, kein QR-Code)" "" }
    }
    # values outside <Page features> (e.g. level shifter): name of the value (names="..."), else the number
    for ($i = 0; $i -lt $M.Values.Count; $i++) {
      $v = $M.Values[$i]
      if ($M.Page.Features -contains $v.Name) { continue }
      $n = [int]$b.Values[$i]
      $vt = [string]$n
      if ($n -lt $v.Names.Count) { $vt = $v.Names[$n] }
      & $sep ("{0}: {1}" -f $v.Text, $vt) ""
    }
    & $sep "Module und Funktionen" ' UIHint="Headline"'
    foreach ($f in $M.Page.Features) {
      $ci = -1; for ($i = 0; $i -lt $M.Capabilities.Count; $i++) { if ($M.Capabilities[$i].Name -eq $f) { $ci = $i } }
      if ($ci -ge 0) {
        $c = $M.Capabilities[$ci]
        $label = $c.Feature; if (-not $label) { $label = $c.Text }
        $on = $c.FeatureOn; if (-not $on) { $on = "ja" }
        $off = $c.FeatureOff; if (-not $off) { $off = "nein" }
        $has = [bool]$b.Caps[$ci]
        if ($c.FeatureInvert) { $has = -not $has }
        if ($b.CapMixed[$ci]) {
          $state = "je nach Firmware-Variante"
          if ($c.FeatureOn -or $c.FeatureOff) { $state = "{0} oder {1} (je nach Firmware-Variante)" -f $off, $on }
        }
        elseif ($has) {
          $state = $on
          if ($c.FeatureNoteWhen) {
            $wi = 0; for ($i = 0; $i -lt $M.Capabilities.Count; $i++) { if ($M.Capabilities[$i].Name -eq $c.FeatureNoteWhen) { $wi = $i } }
            if ($b.Caps[$wi]) { $state = "{0} ({1})" -f $on, $c.FeatureNote }
          }
        }
        else { $state = $off }
        & $sep ("{0}: {1}" -f $label, $state) ""
      }
      else {
        $vi = 0; for ($i = 0; $i -lt $M.Values.Count; $i++) { if ($M.Values[$i].Name -eq $f) { $vi = $i } }
        $v = $M.Values[$vi]
        $n = [int]$b.Values[$vi]
        $state = "nein"
        if ($n -gt 0 -and $v.Relays) {
          # relays: the first HW_RELAY_COUNT are hard-wired, every further one takes a port
          $count = "bis {0}" -f $n; if ($n -eq 1) { $count = "1" }
          $wired = [Math]::Min($n, @($b.Relays).Count); $free = $n - $wired
          if ($wired -eq 0) { $state = "{0}, Port w{1}hlbar" -f $count, [System.Char]::ConvertFromUtf32(0xE4) }
          elseif ($free -eq 0) { $state = "{0}, fest verdrahtet" -f $count }
          else { $state = "{0}, {1} fest verdrahtet, {2} Port w{3}hlbar" -f $count, $wired, $free, [System.Char]::ConvertFromUtf32(0xE4) }
        }
        elseif ($n -gt 0) {
          $state = [string]$n
          if ($v.Unit) { $state = "{0} {1}" -f $n, $v.Unit }
        }
        & $sep ("{0}: {1}" -f $v.Text, $state) ""
      }
    }
    & $sep "Ports" ' UIHint="Headline"'
    if ($b.Ports.Count -eq 0) { & $sep "keine" "" }
    else {
      # table: number, label, GPIO, ETS value (port number - 1)
      [void]$sb.AppendLine("                  <ParameterBlock Id=`"%AID%_PB-nnn`" Name=`"DevPorts`" Inline=`"true`" Layout=`"Grid`">")
      [void]$sb.Append("                    <Rows>")
      for ($r = 1; $r -le $b.Ports.Count + 1; $r++) { [void]$sb.Append(("<Row Id=`"%AID%_PB-nnn_R-{0}`" Name=`"Row{0}`" />" -f $r)) }
      [void]$sb.AppendLine("</Rows>")
      [void]$sb.AppendLine("                    <Columns><Column Id=`"%AID%_PB-nnn_C-1`" Name=`"Col1`" Width=`"10%`" /><Column Id=`"%AID%_PB-nnn_C-2`" Name=`"Col2`" Width=`"40%`" /><Column Id=`"%AID%_PB-nnn_C-3`" Name=`"Col3`" Width=`"15%`" /><Column Id=`"%AID%_PB-nnn_C-4`" Name=`"Col4`" Width=`"15%`" /></Columns>")
      $col = 1
      foreach ($h in @("Nr.", "Beschriftung", "GPIO", "ETS")) {
        [void]$sb.AppendLine(("                    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" Cell=`"1,{1}`" UIHint=`"Headline`" />" -f $h, $col)); $col++
      }
      $row = 2
      foreach ($pt in $b.Ports) {
        $cells = @([string]$pt.N, [string]$pt.Label, [string]$pt.Gpio, [string]($pt.N - 1))
        for ($k = 0; $k -lt 4; $k++) {
          if ($cells[$k].Length -gt 255) { Stop-WithError ("developer view: text longer than 255 characters (ETS limit): {0}" -f $cells[$k]) }
          [void]$sb.AppendLine(("                    <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" Cell=`"{1},{2}`" />" -f (ConvertTo-XmlText $cells[$k]), $row, ($k + 1)))
        }
        $row++
      }
      [void]$sb.AppendLine("                  </ParameterBlock>")
    }
    & $sep "Fest verdrahtete Relais" ' UIHint="Headline"'
    if ($b.Relays.Count -eq 0) { & $sep "keine" "" }
    foreach ($r in $b.Relays) { & $sep ("Relais {0}: {1} - GPIO {2}" -f $r.N, $r.Label, $r.Gpio) "" }
    [void]$sb.AppendLine("                </when>")
  }
  [void]$sb.AppendLine("              </choose>")
  if ($switches.Count -gt 0) {
    [void]$sb.AppendLine("              <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"Firmware (letzte Abfrage)`" UIHint=`"Headline`" />")
    foreach ($sw in $switches) {
      [void]$sb.AppendLine(("              <ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" />" -f (ConvertTo-XmlText $sw.Cap.Text)))
      [void]$sb.AppendLine(("              <ParameterRefRef RefId=`"%AID%_P-{1}{0}_R-{1}{0}01`" IndentLevel=`"1`" />" -f $sw.FwNum, $tt))
    }
  }
  [void]$sb.AppendLine("            </when>")
  [void]$sb.AppendLine("          </choose>")
  [void]$sb.AppendLine('        </ParameterBlock>')
  [void]$sb.AppendLine('      </Channel>')
  [void]$sb.AppendLine('    </Dynamic>')
  [void]$sb.AppendLine('  </ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData>')
  [void]$sb.AppendLine('</KNX>')
  return $sb.ToString()
}

function New-ScriptJs($M, $Boards) {
  $p = $M.Prefix
  $JSAE = [string][char]92 + "u00E4"   # JScript escape for a-umlaut, keeps this file ASCII
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("// Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 - do not edit")
  [void]$sb.AppendLine("// ETS runs Windows JScript (ES3): no let/const, no arrow functions, no JSON object.")
  [void]$sb.AppendLine("")
  if ($M.Page -and $M.Page.UnselectedTitle) {
    # <Page unselectedTitle>: ParameterCalculation PageTitle (selection -> page text of the tree)
    [void]$sb.AppendLine("// page text of the tree: <Page unselectedTitle> while no board is selected, else the page text")
    [void]$sb.AppendLine("function ${p}_pageTitle(input, output, context) {")
    [void]$sb.AppendLine(("    output.Title = (Number(input.Select) == {0}) ? {1} : {2};" -f $M.UnselectedValue, (ConvertTo-JsString $M.Page.UnselectedTitle), (ConvertTo-JsString $M.Page.Text)))
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("function ${p}_pageTitleNone(input, output, context) {")
    [void]$sb.AppendLine("}")
    [void]$sb.AppendLine("")
  }
  [void]$sb.AppendLine("// capability names in bit order of the device query")
  $capNames = @($M.Capabilities | ForEach-Object { ConvertTo-JsString $_.Text })
  [void]$sb.AppendLine("var ${p}_capNames = [" + ($capNames -join ", ") + "];")
  [void]$sb.AppendLine(("// capability bits the firmware detects at run time (runtime=`"true`"): no build difference when they differ`nvar {0}_runtimeCaps = {1};" -f $p, (Get-RuntimeCapMask $M)))
  # the device query answers the values without query="false", in manifest order
  $qIdx = @(for ($i = 0; $i -lt $M.Values.Count; $i++) { if ($M.Values[$i].Query) { $i } })
  $valNames = @($qIdx | ForEach-Object { ConvertTo-JsString $M.Values[$_].Text })
  [void]$sb.AppendLine("var ${p}_valueNames = [" + ($valNames -join ", ") + "];")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("// DEVICE_HW_ID -> expected profile (capability mask, values)")
  [void]$sb.AppendLine("var ${p}_boards = {")
  $rows = @()
  foreach ($b in $Boards) {
    # vary: capabilities in which the firmware variants (envs) of the board differ - either state is a valid build
    [uint32]$vary = 0
    foreach ($ci in @($b.CapMixed.Keys)) { if ($b.CapMixed[$ci]) { $vary = $vary -bor ([uint32]1 -shl [int]$ci) } }
    $rows += ("    {0}: {{ name: {1}, caps: {2}, vary: {3}, values: [{4}] }}" -f $b.HwId, (ConvertTo-JsString $b.Name), $b.CapMask, $vary, (@($qIdx | ForEach-Object { $b.Values[$_] }) -join ", "))
  }
  [void]$sb.AppendLine(($rows -join ",`n"))
  [void]$sb.AppendLine("};")
  # switch="true" capabilities; without one the script stays as before
  $swRows = @()
  foreach ($s in (Get-Switches $M)) {
    $swRows += ("    {{ text: {0}, on: `"{1}_{2}On`", fw: `"{1}_{2}Fw`", capBit: {3}, bit: {4}, fixedBit: {5} }}" -f (ConvertTo-JsString $s.Cap.Text), $p, $s.Cap.Name, $s.Index, $s.ReportIdx, $s.FixedIdx)
  }
  if ($swRows.Count -gt 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("// switch=`"true`" capabilities: on/off parameter, firmware state parameter, own bit, query bit, fixed-by bit (-1: none)")
    [void]$sb.AppendLine("var ${p}_switches = [`n" + ($swRows -join ",`n") + "`n];")
  }
  # <BoardTable>: one table per element; without one the script stays as before
  foreach ($t in $M.BoardTables) {
    $len = 0
    foreach ($b in $Boards) { foreach ($ix in @($b.Tables[$t.Name].Any.Keys) + @($b.Tables[$t.Name].All.Keys)) { if ($ix + 1 -gt $len) { $len = $ix + 1 } } }
    $tRows = @()
    foreach ($b in $Boards) {
      $tab = $b.Tables[$t.Name]
      $any = @(for ($ix = 0; $ix -lt $len; $ix++) { if ($tab.Any.ContainsKey($ix)) { $tab.Any[$ix] } else { 0 } })
      $all = @(for ($ix = 0; $ix -lt $len; $ix++) { if ($tab.All.ContainsKey($ix)) { $tab.All[$ix] } else { 0 } })
      $tRows += ("    {0}: {{ any: [{1}], all: [{2}] }}" -f $b.HwId, ($any -join ", "), ($all -join ", "))
    }
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine(("// <BoardTable name=`"{0}`">: DEVICE_HW_ID -> {1} per index (group 1 of {2}); any = OR, all = AND over the envs, missing = 0" -f $t.Name, $t.HeaderAttr, $t.Scan))
    [void]$sb.AppendLine("var ${p}_table_$($t.Name) = {`n" + ($tRows -join ",`n") + "`n};")
  }
  $swLoop = ""
  $swDone = @"
    if (diff.length > 0)
        progress.setText("Hardware: " + known.name + " erkannt. Abweichend gebaut: " + diff.join(", "));
    else
        progress.setText("Hardware: " + known.name + " (" + ${p}_hex4(hwId) + ") erkannt.");
"@.TrimEnd()
  if ($swRows.Count -gt 0) {
    $swLoop = @"

    // switches: store what the firmware reported; switch off what it does not have, only where the board shows
    // the switch (has the capability, not fixed on, e.g. the KNX link); a switch the firmware has keeps its value,
    // except a runtime part (plug-in module): its switch follows the device and goes on when the part is found
    var switchedOff = [];
    var notFound = [];
    var found = [];
    for (var k = 0; k < ${p}_switches.length; k++) {
        var sw = ${p}_switches[k];
        var has = (caps >>> sw.bit) & 1;
        device.getParameterByName(sw.fw).value = has ? 1 : 2;
        var shown = ((known.caps >>> sw.capBit) & 1) && !(sw.fixedBit >= 0 && ((known.caps >>> sw.fixedBit) & 1));
        if (!has && shown && device.getParameterByName(sw.on).value != 0) {
            device.getParameterByName(sw.on).value = 0;
            if ((${p}_runtimeCaps >>> sw.bit) & 1) notFound.push(sw.text);
            else switchedOff.push(sw.text);
        }
        else if (has && shown && ((${p}_runtimeCaps >>> sw.bit) & 1) && device.getParameterByName(sw.on).value == 0) {
            device.getParameterByName(sw.on).value = 1;
            found.push(sw.text);
        }
    }

"@
    $swDone = @"
    var off = switchedOff.length > 0 ? " Ausgeschaltet (Firmware ohne): " + switchedOff.join(", ") + "." : "";
    if (notFound.length > 0) off += " Ausgeschaltet (nicht gefunden): " + notFound.join(", ") + ".";
    if (found.length > 0) off += " Eingeschaltet (gefunden): " + found.join(", ") + ".";
    if (diff.length > 0)
        progress.setText("Hardware: " + known.name + " erkannt. Abweichend gebaut: " + diff.join(", ") + "." + off);
    else
        progress.setText("Hardware: " + known.name + " (" + ${p}_hex4(hwId) + ") erkannt." + off);
"@.TrimEnd()
  }
  [void]$sb.AppendLine(@"

function ${p}_hex4(value) {
    var s = value.toString(16).toUpperCase();
    while (s.length < 4) s = "0" + s;
    return "0x" + s;
}

// Query button (<Page button>, default "Vom Geraet lesen"; without <Page> "Hardware vom Geraet abfragen"): reads DEVICE_HW_ID, capability bits and values from the
// device (function property $FP_OBJECT_INDEX/$FP_PROPERTY_ID) and sets the hardware selection.
function ${p}_detectHardware(device, online, progress, context) {
    progress.setText("Hardware: frage Ger${JSAE}t ab ...");
    progress.setProgress(10);
    online.connect();
    var resp;
    try {
        resp = online.invokeFunctionProperty($FP_OBJECT_INDEX, $FP_PROPERTY_ID, [0]);
    } finally {
        online.disconnect();
    }
    progress.setProgress(60);
    if (!resp || resp.length < 1)
        throw new Error("Hardware: keine Antwort vom Ger${JSAE}t (leere Antwort)");
    if (resp[0] != 0)
        throw new Error("Hardware: Ger${JSAE}t meldet Fehler " + resp[0]);
    if (resp.length < 7)
        throw new Error("Hardware: Antwort zu kurz (" + resp.length + " Byte)");

    var hwId = (resp[1] << 8) | resp[2];
    var caps = (resp[3] | (resp[4] << 8) | (resp[5] << 16) | (resp[6] << 24)) >>> 0;
    var known = ${p}_boards[hwId];
    if (!known)
        throw new Error("Hardware " + ${p}_hex4(hwId) + " ist dieser Applikation unbekannt. Applikation aktualisieren.");

    device.getParameterByName("${p}_HardwareSelect").value = hwId;
$swLoop
    // the firmware evaluates the same expressions as the generator; a difference means build flags
    // (e.g. WiFi instead of LAN) changed the device - the device is right, the list is not. Not counted: bits the
    // firmware detects at run time and bits in which the firmware variants of this board differ (known.vary)
    var diff = [];
    for (var i = 0; i < ${p}_capNames.length; i++) {
        if ((${p}_runtimeCaps >>> i) & 1) continue;
        if ((known.vary >>> i) & 1) continue;
        var expected = (known.caps >>> i) & 1;
        var actual = (caps >>> i) & 1;
        if (expected != actual) diff.push(${p}_capNames[i] + (actual ? " (Ger${JSAE}t: ja)" : " (Ger${JSAE}t: nein)"));
    }
    for (var v = 0; v < ${p}_valueNames.length && 7 + v < resp.length; v++) {
        if (resp[7 + v] != known.values[v]) diff.push(${p}_valueNames[v] + " (Ger${JSAE}t: " + resp[7 + v] + ")");
    }
    progress.setProgress(100);
$swDone
}
"@)
  if ($M.Conflicts) { [void]$sb.Append((New-ConflictsJs $M $Boards)) }
  return $sb.ToString()
}

# ------------------------------------------------------------------------------------------------
# GPIO conflict check (<Conflicts>)
# ------------------------------------------------------------------------------------------------
# @brief Board-dependent part of <Conflicts>: port parameter of every use per board (port="..." with {{ }} expressions,
#        $b = board, $tt = ModuleType of the hardware module, two digits), the aliases of the calculation inputs and the checks that need the boards
# @brief Reserved GPIOs of a board for <Conflicts reserved="true">: Rsv (flag 2) = own pins, plus the KNX UART pins when every env
#        is a TP build; Tp (flag 3) = the KNX UART pins when the envs differ or one has no MASK_VERSION; no TP env: UART pins free
function Get-BoardReservedSets($Board) {
  $states = @($Board.TpStates)
  $allTp = ($states.Count -gt 0 -and @($states | Where-Object { $_ -ne $true }).Count -eq 0)
  $someTp = (@($states | Where-Object { $_ -ne $false }).Count -gt 0)
  $rsv = @($Board.ReservedGpios)
  $tp = @()
  if ($allTp) { $rsv = @(@($rsv) + @($Board.TpGpios) | ForEach-Object { [int]$_ } | Sort-Object -Unique) }
  elseif ($someTp) { $tp = @($Board.TpGpios | Where-Object { $rsv -notcontains $_ }) }
  return @{ Rsv = $rsv; Tp = $tp }
}

function Resolve-Conflicts($M, $Boards) {
  $cf = $M.Conflicts
  $refs = Get-ParamRefIds $M
  $node = @{ Path = $M.ManifestPath; Line = 0 }
  # calculation inputs in order: selection, <Param>, manual GPIO parameters, port parameters; one alias per RefId
  $inputs = New-Object System.Collections.Generic.List[object]
  $byRef = @{}
  $inputs.Add(@{ Ref = $refs.Select; Alias = "Sel" }); $byRef[$refs.Select] = "Sel"
  foreach ($pr in $cf.Params) {
    if ($byRef.ContainsKey($pr.Ref)) { Stop-WithError ("<Conflicts><Param name=`"{0}`">: ref is the hardware selection" -f $pr.Name) }
    $pr.Alias = "P_" + $pr.Name
    $inputs.Add(@{ Ref = $pr.Ref; Alias = $pr.Alias }); $byRef[$pr.Ref] = $pr.Alias
  }
  foreach ($u in $cf.Uses) {
    for ($k = 0; $k -lt $u.Manuals.Count; $k++) {
      $mr = $u.Manuals[$k]
      if ($mr.Ref -ceq $refs.Select) { Stop-WithError ("<Conflicts><Use name=`"{0}`"> <Manual>: ref is the hardware selection" -f $u.Name) }
      if (-not $byRef.ContainsKey($mr.Ref)) { $byRef[$mr.Ref] = ("M{0}_{1}" -f $u.Index, $k); $inputs.Add(@{ Ref = $mr.Ref; Alias = $byRef[$mr.Ref] }) }
      $mr.Alias = $byRef[$mr.Ref]
    }
  }
  $maxWired = 0
  foreach ($u in $cf.Uses) { if ($u.Wired -gt $maxWired) { $maxWired = $u.Wired } }
  $portRefs = @{}
  foreach ($u in $cf.Uses) {
    $uw = "<Conflicts><Use name=`"$($u.Name)`">"
    $u.Mode = 0   # 0 = no port parameter, 1 = one per board (alias U<i>B<slot>), 2 = one for all boards (alias U<i>)
    $u.BoardRefs = @{}
    if (-not $u.Port) { continue }
    foreach ($b in $Boards) {
      # a hard-wired relay of the board has no port parameter
      if ($u.Wired -gt 0 -and @($b.Relays).Count -ge $u.Wired) { continue }
      try { $r = Expand-TplLine $u.Port @{ b = $b; tt = ("{0:D2}" -f $M.ModuleType); Boards = $Boards; M = $M } $node }
      catch { Stop-WithError ("{0}: port: {1}" -f $uw, $_.Exception.Message) }
      if ($r -notmatch '^%AID%_\S+_R-\S+$' -and $r -notmatch '^%[A-Za-z0-9_]+%$') { Stop-WithError ("{0}: port gives '{1}' for {2}, not a ParamRefId (%AID%_..._R-...)" -f $uw, $r, $b.Define) }
      $u.BoardRefs[$b.Slot] = $r
    }
    $distinct = @($u.BoardRefs.Values | Sort-Object -Unique -CaseSensitive)
    if ($distinct.Count -eq 0) { continue }
    # one parameter for every board that has one (also a per-board pattern that leaves a single board): input U<i>
    $u.Mode = 1
    if ($distinct.Count -eq 1) { $u.Mode = 2 }
    foreach ($slot in @($u.BoardRefs.Keys | Sort-Object)) {
      $r = $u.BoardRefs[$slot]
      if ($byRef.ContainsKey($r)) { Stop-WithError ("{0}: port parameter {1} is also the hardware selection, a <Param> or a <Manual>" -f $uw, $r) }
      if ($u.Mode -eq 1 -and $portRefs.ContainsKey($r)) { Stop-WithError ("{0}: port parameter {1} is also used by {2} - one selection parameter per use and board" -f $uw, $r, $portRefs[$r]) }
      if ($u.Mode -eq 2 -and $portRefs.ContainsKey($r) -and $portRefs[$r] -ne $u.Name) { Stop-WithError ("{0}: port parameter {1} is also used by {2}" -f $uw, $r, $portRefs[$r]) }
      $portRefs[$r] = $u.Name
    }
    if ($u.Mode -eq 2) { $inputs.Add(@{ Ref = $distinct[0]; Alias = "U$($u.Index)" }) }
    else { foreach ($slot in @($u.BoardRefs.Keys | Sort-Object)) { $inputs.Add(@{ Ref = $u.BoardRefs[$slot]; Alias = ("U{0}B{1}" -f $u.Index, $slot) }) } }
  }
  if ($cf.Reserved) {
    foreach ($b in $Boards) {
      if (-not $b.Mcu) { Write-Detail ("  <Conflicts reserved>: {0} has no MCU (no env) - no flash / PSRAM GPIOs, only the pin macros" -f $b.Define) }
      $sets = Get-BoardReservedSets $b
      foreach ($pt in @($b.Ports)) {
        if (@($sets.Rsv) -contains $pt.Gpio) { Write-Warn ("<Conflicts reserved>: {0} offers port {1} on GPIO {2}, which the board reserves" -f $b.Define, $pt.N, $pt.Gpio) }
        elseif (@($sets.Tp) -contains $pt.Gpio) { Write-Warn ("<Conflicts reserved>: {0} offers port {1} on GPIO {2}, the KNX UART of its TP firmware" -f $b.Define, $pt.N, $pt.Gpio) }
      }
    }
  }
  if ($maxWired -gt 0) {
    foreach ($b in $Boards) {
      if (@($b.Relays).Count -gt $maxWired) { Write-Warn ("<Conflicts>: {0} has {1} hard-wired relays, the conflict check knows relays 1..{2} (wiredRelay)" -f $b.Define, @($b.Relays).Count, $maxWired) }
    }
  }
  $cf.Inputs = $inputs.ToArray()
  $free = 0
  for ($i = 0; $i -lt $cf.Uses.Count; $i++) {
    $u = $cf.Uses[$i]
    if ($cf.Channels.Count -eq 0) { $u.FlagNum = "{0:D5}" -f ($cf.Number + $i) }
    elseif ($u.ContainsKey("Channel")) { $u.FlagNum = "{0:D5}" -f ($cf.Number + 10 * $u.Channel.Group + $u.Channel.N) }
    else { $u.FlagNum = "{0:D5}" -f ($cf.Number + $free); $free++ }
    $u.FlagRef = "%AID%_P-%TT%{0}_R-%TT%{0}01" -f $u.FlagNum
  }
}

# @brief Condition as a JavaScript table: [[[alias, op, [values]], ...AND], ...OR]; null = always
function ConvertTo-ConflictJsCondition($When, $Cf) {
  if ($null -eq $When) { return "null" }
  $alias = @{}
  foreach ($pr in $Cf.Params) { $alias[$pr.Name] = $pr.Alias }
  $groups = @()
  foreach ($g in $When) {
    $terms = @()
    foreach ($t in $g) { $terms += ("[`"{0}`", `"{1}`", [{2}]]" -f $alias[$t.Param], $t.Op, (@($t.Values) -join ", ")) }
    $groups += ("[" + ($terms -join ", ") + "]")
  }
  return ("[" + ($groups -join ", ") + "]")
}

# @brief JavaScript of the conflict check: use table, board table, generic check, output writer (one line per flag)
function New-ConflictsJs($M, $Boards) {
  $p = $M.Prefix
  $cf = $M.Conflicts
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("// GPIO conflict check (<Conflicts>): ${p}_conflictCheck is the LR function of one ParameterCalculation. Every active")
  [void]$sb.AppendLine("// use resolves to a GPIO of the selected board; two uses with the same GPIO both get their flag. No board: all 0.")
  [void]$sb.AppendLine("// n: name; w: condition (OR of AND terms [input, op, values]), null = always; g: 1 = value is the GPIO, 0 = port index;")
  [void]$sb.AppendLine("// m / x: value for manual / none (-1: none); man: [condition, input of the manual GPIO], first match wins;")
  [void]$sb.AppendLine("// r: hard-wired relay number (pin always occupied on boards with that relay); p: 0 no port parameter, 1 one per board")
  [void]$sb.AppendLine("// (input U<i>B<board number>), 2 one for all boards (input U<i>)")
  [void]$sb.AppendLine("var ${p}_conflictUses = [")
  $rows = @()
  foreach ($u in $cf.Uses) {
    $man = @($u.Manuals | ForEach-Object { "[{0}, `"{1}`"]" -f (ConvertTo-ConflictJsCondition $_.When $cf), $_.Alias })
    $mv = -1; if ($null -ne $u.Manual) { $mv = $u.Manual }
    $xv = -1; if ($null -ne $u.None) { $xv = $u.None }
    $gv = 0; if ($u.Value -eq "gpio") { $gv = 1 }
    $rows += ("    {{ n: {0}, w: {1}, g: {2}, m: {3}, x: {4}, man: [{5}], r: {6}, p: {7} }}" -f (ConvertTo-JsString $u.Name), (ConvertTo-ConflictJsCondition $u.When $cf), $gv, $mv, $xv, ($man -join ", "), $u.Wired, $u.Mode)
  }
  [void]$sb.AppendLine(($rows -join ",`n"))
  [void]$sb.AppendLine("];")
  [void]$sb.AppendLine("// DEVICE_HW_ID -> s: board number, ports: GPIO per port value (null: port not offered), relays: GPIO of the hard-wired relays")
  if ($cf.Reserved) { [void]$sb.AppendLine("// rsv: GPIOs the board reserves (flag 2); tp: KNX UART GPIOs of a board with TP and IP firmware variants (flag 3)") }
  [void]$sb.AppendLine("var ${p}_conflictBoards = {")
  $rows = @()
  foreach ($b in $Boards) {
    $maxN = 0; foreach ($pt in @($b.Ports)) { if ($pt.N -gt $maxN) { $maxN = $pt.N } }
    $ports = @()
    for ($n = 1; $n -le $maxN; $n++) {
      $pt = @($b.Ports | Where-Object { $_.N -eq $n })
      if ($pt.Count -gt 0) { $ports += [string]$pt[0].Gpio } else { $ports += "null" }
    }
    $relays = @($b.Relays | ForEach-Object { [string]$_.Gpio })
    if ($cf.Reserved) {
      $sets = Get-BoardReservedSets $b
      $rows += ("    {0}: {{ s: {1}, ports: [{2}], relays: [{3}], rsv: [{4}], tp: [{5}] }}" -f $b.HwId, $b.Slot, ($ports -join ", "), ($relays -join ", "), (@($sets.Rsv) -join ", "), (@($sets.Tp) -join ", "))
    }
    else { $rows += ("    {0}: {{ s: {1}, ports: [{2}], relays: [{3}] }}" -f $b.HwId, $b.Slot, ($ports -join ", "), ($relays -join ", ")) }
  }
  [void]$sb.AppendLine(($rows -join ",`n"))
  [void]$sb.AppendLine("};")
  $flagNote = "// conflict flag per use (0/1), all 0 while no or an unknown board is selected"
  $rsvLoop = ""
  if ($cf.Reserved) {
    $flagNote = "// conflict flag per use (0/1; 2 = reserved GPIO, 3 = KNX UART of a TP firmware), all 0 while no or an unknown board is selected"
    $rsvLoop = @"

    for (i = 0; i < uses.length; i++) {
        if (gpio[i] < 0) continue;
        for (var k = 0; k < board.rsv.length; k++) if (board.rsv[k] == gpio[i]) flags[i] = 2;
        for (k = 0; k < board.tp.length; k++) if (board.tp[k] == gpio[i] && flags[i] == 0) flags[i] = 3;
    }
"@.TrimEnd()
  }
  [void]$sb.AppendLine(@"

function ${p}_conflictInt(value, fallback) {
    if (typeof value == "number") return value;
    var n = parseInt(value, 10);
    return isNaN(n) ? fallback : n;
}

// condition of a use or a manual GPIO: OR over groups, AND within a group
function ${p}_conflictWhen(input, when) {
    if (!when) return true;
    for (var g = 0; g < when.length; g++) {
        var ok = true;
        for (var t = 0; t < when[g].length && ok; t++) {
            var v = ${p}_conflictInt(input[when[g][t][0]], 0);
            var op = when[g][t][1];
            var vals = when[g][t][2];
            if (op == "in") {
                ok = false;
                for (var k = 0; k < vals.length; k++) if (v == vals[k]) ok = true;
            }
            else if (op == "eq") ok = (v == vals[0]);
            else if (op == "ne") ok = (v != vals[0]);
            else if (op == "lt") ok = (v < vals[0]);
            else if (op == "le") ok = (v <= vals[0]);
            else if (op == "gt") ok = (v > vals[0]);
            else ok = (v >= vals[0]);
        }
        if (ok) return true;
    }
    return false;
}

// GPIO of use u (index i) on the board, -1 when it takes no GPIO
function ${p}_conflictGpio(input, u, i, board) {
    if (u.r > 0 && u.r <= board.relays.length) return board.relays[u.r - 1];
    if (u.p == 0 || !${p}_conflictWhen(input, u.w)) return -1;
    var v = ${p}_conflictInt(input[u.p == 2 ? "U" + i : "U" + i + "B" + board.s], -1);
    if (u.m >= 0 && v == u.m) {
        for (var k = 0; k < u.man.length; k++) {
            if (!${p}_conflictWhen(input, u.man[k][0])) continue;
            var gpio = ${p}_conflictInt(input[u.man[k][1]], -1);
            return (gpio >= 0 && gpio < 255) ? gpio : -1;
        }
        return -1;
    }
    if (u.x >= 0 && v == u.x) return -1;
    if (u.g) return (v >= 0 && v < 255) ? v : -1;
    if (v >= 0 && v < board.ports.length && board.ports[v] !== null) return board.ports[v];
    return -1;
}

$flagNote
function ${p}_conflictFlags(input) {
    var uses = ${p}_conflictUses;
    var flags = [];
    var gpio = [];
    var i;
    for (i = 0; i < uses.length; i++) { flags.push(0); gpio.push(-1); }
    var board = ${p}_conflictBoards[${p}_conflictInt(input.Sel, -1)];
    if (!board) return flags;
    for (i = 0; i < uses.length; i++) gpio[i] = ${p}_conflictGpio(input, uses[i], i, board);
    for (i = 0; i < uses.length; i++) {
        if (gpio[i] < 0) continue;
        for (var j = i + 1; j < uses.length; j++) {
            if (gpio[j] == gpio[i]) { flags[i] = 1; flags[j] = 1; }
        }
    }$rsvLoop
    return flags;
}

// LR function of the conflict calculation; the flags are written with dot names (the output aliases)
function ${p}_conflictCheck(input, output, context) {
    var f = ${p}_conflictFlags(input);
"@.TrimEnd())
  for ($i = 0; $i -lt $cf.Uses.Count; $i++) { [void]$sb.AppendLine(("    output.F_{0} = f[{1}];" -f $cf.Uses[$i].Name, $i)) }
  [void]$sb.AppendLine("}")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("// RL function of the conflict calculation: the flags are outputs only")
  [void]$sb.AppendLine("function ${p}_conflictNone(input, output, context) {")
  [void]$sb.AppendLine("}")
  return $sb.ToString()
}

# @brief Parts file of <Conflicts output>: ParameterType, flag Parameters (no memory) and ParameterRefs, the calculation,
#        one UI block Conflict_<Name> per use; the application includes each part into its own module (%TT%)
function New-ConflictsXml($M, $Boards) {
  $p = $M.Prefix
  $cf = $M.Conflicts
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
  [void]$sb.AppendLine('<KNX xmlns="http://knx.org/xml/project/20" xmlns:op="http://github.com/OpenKNX/OpenKNXproducer">')
  [void]$sb.AppendLine("  <!-- Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 (<Conflicts>) - do not edit -->")
  [void]$sb.AppendLine("  <!-- include into one module: ParameterType (xpath //ApplicationProgram/Static/ParameterTypes/ParameterType), blocks Parameters,")
  [void]$sb.AppendLine("       ParameterRefs, Calculation (into ParameterCalculations), Conflict_<Name> (error while the use is in conflict, any page) -->")
  [void]$sb.AppendLine('  <ManufacturerData><Manufacturer><ApplicationPrograms><ApplicationProgram><Static><ParameterTypes>')
  [void]$sb.AppendLine(("    <ParameterType Id=`"%AID%_PT-{0}ConflictFlag`" Name=`"{0}ConflictFlag`">" -f $p))
  if ($cf.Reserved) { [void]$sb.AppendLine('      <TypeNumber SizeInBit="2" Type="unsignedInt" minInclusive="0" maxInclusive="3" />') }
  else { [void]$sb.AppendLine('      <TypeNumber SizeInBit="1" Type="unsignedInt" minInclusive="0" maxInclusive="1" />') }
  [void]$sb.AppendLine('    </ParameterType>')
  [void]$sb.AppendLine('  </ParameterTypes></Static></ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData>')
  [void]$sb.AppendLine('  <Block name="Parameters">')
  foreach ($u in $cf.Uses) {
    [void]$sb.AppendLine(("    <Parameter Id=`"%AID%_P-%TT%{0}`" Name=`"Conflict{1}`" ParameterType=`"%AID%_PT-{2}ConflictFlag`" Text=`"{3}`" Value=`"0`" Access=`"None`" />" -f $u.FlagNum, $u.Name, $p, (ConvertTo-XmlText ("Konflikt " + $u.Text))))
  }
  [void]$sb.AppendLine('  </Block>')
  [void]$sb.AppendLine('  <Block name="ParameterRefs">')
  foreach ($u in $cf.Uses) { [void]$sb.AppendLine(("    <ParameterRef Id=`"{0}`" RefId=`"%AID%_P-%TT%{1}`" />" -f $u.FlagRef, $u.FlagNum)) }
  [void]$sb.AppendLine('  </Block>')
  [void]$sb.AppendLine('  <Block name="Calculation">')
  [void]$sb.AppendLine(("    <ParameterCalculation Id=`"%AID%_PC-%TT%{0:D5}`" Language=`"JavaScript`" Name=`"{1}GpioConflicts`" LRTransformationFunc=`"{1}_conflictCheck`" RLTransformationFunc=`"{1}_conflictNone`">" -f $cf.Number, $p))
  [void]$sb.AppendLine('      <LParameters>')
  foreach ($in in $cf.Inputs) { [void]$sb.AppendLine(("        <ParameterRefRef RefId=`"{0}`" AliasName=`"{1}`" />" -f (ConvertTo-XmlText $in.Ref), $in.Alias)) }
  [void]$sb.AppendLine('      </LParameters>')
  [void]$sb.AppendLine('      <RParameters>')
  foreach ($u in $cf.Uses) { [void]$sb.AppendLine(("        <ParameterRefRef RefId=`"{0}`" AliasName=`"F_{1}`" />" -f $u.FlagRef, $u.Name)) }
  [void]$sb.AppendLine('      </RParameters>')
  [void]$sb.AppendLine('    </ParameterCalculation>')
  [void]$sb.AppendLine('  </Block>')
  foreach ($u in $cf.Uses) {
    # the flag is referenced (Access None, invisible): a choose is active only while its parameter is active
    [void]$sb.AppendLine(("  <Block name=`"Conflict_{0}`">" -f $u.Name))
    [void]$sb.AppendLine(("    <ParameterRefRef RefId=`"{0}`" />" -f $u.FlagRef))
    [void]$sb.AppendLine(("    <choose ParamRefId=`"{0}`">" -f $u.FlagRef))
    [void]$sb.AppendLine(("      <when test=`"1`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Error`" /></when>" -f (ConvertTo-XmlText $u.ErrorText)))
    if ($cf.Reserved) {
      [void]$sb.AppendLine(("      <when test=`"2`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Error`" /></when>" -f (ConvertTo-XmlText $u.ReservedText)))
      [void]$sb.AppendLine(("      <when test=`"3`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Information`" /></when>" -f (ConvertTo-XmlText $u.TpText)))
    }
    [void]$sb.AppendLine('    </choose>')
    [void]$sb.AppendLine('  </Block>')
  }
  foreach ($ch in $cf.Channels) {
    # in a channel template: %C% (channel n) completes the flag number of the n-th use (number + 10 k + n)
    $ref = "%AID%_P-%TT%{0:D4}%C%_R-%TT%{0:D4}%C%01" -f [int](($cf.Number + 10 * $ch.Index) / 10)
    [void]$sb.AppendLine(("  <Block name=`"ConflictChannel_{0}`">" -f $ch.Name))
    [void]$sb.AppendLine(("    <ParameterRefRef RefId=`"{0}`" />" -f $ref))
    [void]$sb.AppendLine(("    <choose ParamRefId=`"{0}`">" -f $ref))
    [void]$sb.AppendLine(("      <when test=`"1`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Error`" /></when>" -f (ConvertTo-XmlText $ch.ErrorText)))
    if ($cf.Reserved) {
      [void]$sb.AppendLine(("      <when test=`"2`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Error`" /></when>" -f (ConvertTo-XmlText $ch.ReservedText)))
      [void]$sb.AppendLine(("      <when test=`"3`"><ParameterSeparator Id=`"%AID%_PS-nnn`" Text=`"{0}`" UIHint=`"Information`" /></when>" -f (ConvertTo-XmlText $ch.TpText)))
    }
    [void]$sb.AppendLine('    </choose>')
    [void]$sb.AppendLine('  </Block>')
  }
  [void]$sb.AppendLine('</KNX>')
  return $sb.ToString()
}

# @brief Parts files of <Conflicts> the generator wrote earlier (marker line) in the folders of this run's outputs, other than
#        the current one: left over when <Conflicts> or its output changed. Reported, never deleted (a warning; -Check counts
#        them as not current)
function Get-StaleConflictFiles($M, [string[]]$Outputs) {
  $marker = "<!-- Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 (<Conflicts>) - do not edit -->"
  $current = ""
  if ($M.Conflicts) { $current = $M.Conflicts.Output }
  $stale = @()
  foreach ($dir in @($Outputs | ForEach-Object { [System.IO.Path]::GetDirectoryName($_) } | Sort-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter "*.xml" -File)) {
      if ($f.FullName -eq $current) { continue }
      $head = @(Get-Content -LiteralPath $f.FullName -TotalCount 3 -Encoding UTF8)
      if ($head -contains ("  " + $marker)) { $stale += $f.FullName }
    }
  }
  return ,$stale
}

# @brief Flag and calculation numbers of <Conflicts> against the IDs of the XML files next to its output (the module that
#        includes the parts usually sits there): a hit is a warning naming the file. A hint only: %TT% (the module) is not
#        compared, IDs built with %C% or {{ }} and files in other folders are not seen; files this run writes and parts
#        files of earlier runs (marker line) are not searched. The application keeps the numbers free in its module.
function Test-ConflictNumbers($M, [string[]]$Outputs) {
  $cf = $M.Conflicts
  $flags = @{}
  foreach ($u in $cf.Uses) { $flags[$u.FlagNum] = $u.Name }
  $calc = "{0:D5}" -f $cf.Number
  $dir = [System.IO.Path]::GetDirectoryName($cf.Output)
  if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return }
  $marker = "  <!-- Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 (<Conflicts>) - do not edit -->"
  foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter "*.xml" -File)) {
    if ($Outputs -contains $f.FullName -or $f.Name -like "*.debug.xml") { continue }
    if (@(Get-Content -LiteralPath $f.FullName -TotalCount 3 -Encoding UTF8) -contains $marker) { continue }
    $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $hits = @{}
    foreach ($mt in [regex]::Matches($text, '_(U?P|PC)-%TT%(\d{5})["_]')) {
      $kind = $mt.Groups[1].Value; $num = $mt.Groups[2].Value
      if ($kind -ne "PC" -and $flags.ContainsKey($num)) { $hits["P-%TT%" + $num + " (flag of " + $flags[$num] + ")"] = $true }
      if ($kind -eq "PC" -and $num -eq $calc) { $hits["PC-%TT%" + $num + " (calculation)"] = $true }
    }
    if ($hits.Count -gt 0) {
      Write-Warn ("<Conflicts number={0}>: {1} uses {2} - if that file is the module that includes the parts, choose another number" -f $cf.Number, $f.Name, ((@($hits.Keys) | Sort-Object) -join ", "))
    }
  }
}

# @brief Bit mask of the runtime="true" capabilities
function Get-RuntimeCapMask($M) {
  [uint32]$mask = 0
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) { if ($M.Capabilities[$i].Runtime) { $mask = $mask -bor ([uint32]1 -shl $i) } }
  return $mask
}
function New-Header($M, $Boards) {
  $p = $M.Prefix
  # the header evaluates expr per build; a <Set> value exists only in ETS and would differ (query="false" leaves it out)
  $qv = @($M.Values | Where-Object { $_.Query })
  foreach ($v in $qv) { if ($v.Sets.Count -gt 0) { Stop-WithError ("Value {0}: <Set> values are ETS only - the header output needs expr or query=`"false`"" -f $v.Name) } }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("#pragma once")
  [void]$sb.AppendLine("/**")
  [void]$sb.AppendLine(" * @file $([System.IO.Path]::GetFileName($M.Outputs.header))")
  [void]$sb.AppendLine(" * @brief Hardware profile of this firmware (generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1)")
  [void]$sb.AppendLine(" * @note Do not edit. The capability expressions are the ones the ETS profile was generated from.")
  [void]$sb.AppendLine(" */")
  [void]$sb.AppendLine("#include <cstdint>")
  [void]$sb.AppendLine('#include "HardwareConfig.h"')
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("namespace HardwareProfile")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("constexpr uint8_t FP_OBJECT_INDEX = $FP_OBJECT_INDEX;")
  [void]$sb.AppendLine("constexpr uint8_t FP_PROPERTY_ID = $FP_PROPERTY_ID;")
  [void]$sb.AppendLine("constexpr uint16_t NOT_SELECTED = $($M.UnselectedValue);")
  [void]$sb.AppendLine("constexpr uint8_t PIN_UNUSED = $PIN_UNUSED;")
  [void]$sb.AppendLine("constexpr uint8_t CAPABILITY_COUNT = $($M.Capabilities.Count);")
  [void]$sb.AppendLine("constexpr uint8_t VALUE_COUNT = $($qv.Count);")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("/// @brief Capability bits, same order as the ETS script")
  [void]$sb.AppendLine("enum Capability : uint8_t")
  [void]$sb.AppendLine("{")
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) { [void]$sb.AppendLine(("    Cap{0} = {1}," -f $M.Capabilities[$i].Name, $i)) }
  [void]$sb.AppendLine("};")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("/// @brief Value slots, same order as the ETS script")
  [void]$sb.AppendLine("enum Value : uint8_t")
  [void]$sb.AppendLine("{")
  for ($i = 0; $i -lt $qv.Count; $i++) { [void]$sb.AppendLine(("    Val{0} = {1}," -f $qv[$i].Name, $i)) }
  [void]$sb.AppendLine("};")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("constexpr const char* CAPABILITY_NAMES[] = {")
  foreach ($c in $M.Capabilities) { [void]$sb.AppendLine(("    `"{0}`"," -f $c.Name)) }
  [void]$sb.AppendLine("};")
  if ($qv.Count -gt 0) {
    [void]$sb.AppendLine("constexpr const char* VALUE_NAMES[] = {")
    foreach ($v in $qv) { [void]$sb.AppendLine(("    `"{0}`"," -f $v.Name)) }
    [void]$sb.AppendLine("};")
  }
  # no queried value: a zero-length array is not C++; a null pointer keeps "for (i < VALUE_COUNT) VALUE_NAMES[i]" valid
  else { [void]$sb.AppendLine("constexpr const char* const* VALUE_NAMES = nullptr; // no queried value") }
  [void]$sb.AppendLine("} // namespace HardwareProfile")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("// ---- own profile, evaluated by the compiler for the board this firmware is built for ----")
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) {
    [void]$sb.AppendLine(("#if {0}" -f $M.Capabilities[$i].Expr))
    [void]$sb.AppendLine(("    #define {0}_CAP_BIT_{1} 1u" -f $p, $i))
    [void]$sb.AppendLine("#else")
    [void]$sb.AppendLine(("    #define {0}_CAP_BIT_{1} 0u" -f $p, $i))
    [void]$sb.AppendLine("#endif")
  }
  for ($i = 0; $i -lt $qv.Count; $i++) {
    $v = $qv[$i]
    [void]$sb.AppendLine(("#if defined({0})" -f $v.IfDef))
    [void]$sb.AppendLine(("    #define {0}_VAL_{1} ({2})" -f $p, $i, $v.Expr))
    [void]$sb.AppendLine("#else")
    [void]$sb.AppendLine(("    #define {0}_VAL_{1} ({2})" -f $p, $i, $v.Default))
    [void]$sb.AppendLine("#endif")
  }
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("namespace HardwareProfile")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("#ifdef DEVICE_HW_ID")
  [void]$sb.AppendLine("constexpr uint16_t OWN_HW_ID = DEVICE_HW_ID;")
  [void]$sb.AppendLine("#else")
  [void]$sb.AppendLine("constexpr uint16_t OWN_HW_ID = 0; // board header without DEVICE_HW_ID")
  [void]$sb.AppendLine("#endif")
  $bits = @()
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) { if (-not $M.Capabilities[$i].Runtime) { $bits += ("({0}_CAP_BIT_{1} << {1})" -f $p, $i) } }
  if ($bits.Count -eq 0) { $bits = @("0u") }
  [void]$sb.AppendLine("constexpr uint32_t OWN_CAPS = " + ($bits -join " | ") + ";")
  # runtime bits of this board only (its expr, e.g. the slot, is true): answerQuery ignores any other bit
  $rtBits = @()
  for ($i = 0; $i -lt $M.Capabilities.Count; $i++) { if ($M.Capabilities[$i].Runtime) { $rtBits += ("({0}_CAP_BIT_{1} << {1})" -f $p, $i) } }
  if ($rtBits.Count -eq 0) { $rtBits = @("0u") }
  [void]$sb.AppendLine("/// runtime=`"true`" capabilities this board has the place for: only these bits of answerQuery(runtimeCaps) count")
  [void]$sb.AppendLine("constexpr uint32_t RUNTIME_CAPS = " + ($rtBits -join " | ") + ";")
  $vals = @()
  for ($i = 0; $i -lt $qv.Count; $i++) { $vals += ("{0}_VAL_{1}" -f $p, $i) }
  if ($vals.Count -gt 0) {
    [void]$sb.AppendLine("constexpr uint8_t OWN_VALUES[VALUE_COUNT] = {" + ($vals -join ", ") + "};")
    for ($i = 0; $i -lt $qv.Count; $i++) {
      [void]$sb.AppendLine(("static_assert(({0}_VAL_{1}) >= 0 && ({0}_VAL_{1}) <= 255, `"value {2} does not fit one byte`");" -f $p, $i, $qv[$i].Name))
    }
  }
  else { [void]$sb.AppendLine("constexpr const uint8_t* OWN_VALUES = nullptr; // no queried value (VALUE_COUNT 0)") }
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("/// @brief Hardware IDs known to the ETS application")
  [void]$sb.AppendLine("constexpr uint16_t KNOWN_HW_IDS[] = {" + (($Boards | ForEach-Object { "0x{0:X4}" -f $_.HwId }) -join ", ") + "};")
  [void]$sb.AppendLine("constexpr uint16_t KNOWN_HW_ID_COUNT = $($Boards.Count);")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("constexpr bool isKnown(uint16_t hwId, uint16_t i = 0)")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("    return i < KNOWN_HW_ID_COUNT && (KNOWN_HW_IDS[i] == hwId || isKnown(hwId, i + 1));")
  [void]$sb.AppendLine("}")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("/// @brief State of the ETS hardware selection against this firmware: read hardware dependent parameters only on Match")
  [void]$sb.AppendLine("enum class Selection : uint8_t")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("    NotSelected, ///< ETS: no hardware selected")
  [void]$sb.AppendLine("    Match,       ///< ETS selection = OWN_HW_ID")
  [void]$sb.AppendLine("    Other,       ///< ETS selection is another board: wrong firmware or wrong selection (optional: log, KO, info LED)")
  [void]$sb.AppendLine("};")
  [void]$sb.AppendLine("static inline Selection checkSelection(uint16_t selected)")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("    return selected == NOT_SELECTED ? Selection::NotSelected : (selected == OWN_HW_ID ? Selection::Match : Selection::Other);")
  [void]$sb.AppendLine("}")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("/// @brief Device query (ETS query button, <Page button>, function property FP_OBJECT_INDEX / FP_PROPERTY_ID):")
  [void]$sb.AppendLine("///        [0] status 0, [1..2] OWN_HW_ID big endian, [3..6] OWN_CAPS | (runtimeCaps & RUNTIME_CAPS) little endian, [7..] OWN_VALUES.")
  [void]$sb.AppendLine("/// @param runtimeCaps bits of the runtime=`"true`" capabilities the firmware found (e.g. a plug-in sensor module), other bits are ignored")
  [void]$sb.AppendLine("/// @return true when objectIndex / propertyId are the device query (answer written), false otherwise.")
  [void]$sb.AppendLine("/// @note In Module::processFunctionProperty: if (HardwareProfile::answerQuery(objectIndex, propertyId, resultData, resultLength)) return true;")
  [void]$sb.AppendLine("static inline bool answerQuery(uint8_t objectIndex, uint8_t propertyId, uint8_t* resultData, uint8_t& resultLength, uint32_t runtimeCaps = 0)")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("    if (objectIndex != FP_OBJECT_INDEX || propertyId != FP_PROPERTY_ID) return false;")
  [void]$sb.AppendLine("    constexpr uint8_t answerLength = 7 + VALUE_COUNT;")
  [void]$sb.AppendLine("    static_assert(answerLength <= 11, `"hardware profile answer does not fit a TP standard frame`");")
  [void]$sb.AppendLine("    const uint32_t caps = OWN_CAPS | (runtimeCaps & RUNTIME_CAPS);")
  [void]$sb.AppendLine("    resultData[0] = 0;")
  [void]$sb.AppendLine("    resultData[1] = OWN_HW_ID >> 8;")
  [void]$sb.AppendLine("    resultData[2] = OWN_HW_ID & 0xFF;")
  [void]$sb.AppendLine("    resultData[3] = caps & 0xFF;")
  [void]$sb.AppendLine("    resultData[4] = (caps >> 8) & 0xFF;")
  [void]$sb.AppendLine("    resultData[5] = (caps >> 16) & 0xFF;")
  [void]$sb.AppendLine("    resultData[6] = (caps >> 24) & 0xFF;")
  [void]$sb.AppendLine("    for (uint8_t i = 0; i < VALUE_COUNT; i++) resultData[7 + i] = OWN_VALUES[i];")
  [void]$sb.AppendLine("    resultLength = answerLength;")
  [void]$sb.AppendLine("    return true;")
  [void]$sb.AppendLine("}")
  [void]$sb.AppendLine("} // namespace HardwareProfile")
  if ($M.Roles.Count -gt 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("// GPIO roles: the per-board parameters of one slot share one byte (ETS union), so any of them")
    [void]$sb.AppendLine("// reads the value of the selected board. Use after knxprod.h. Value $PIN_UNUSED = not used.")
    [void]$sb.AppendLine("// ETS writes the byte only while a parameter of the union is visible: read it ONLY when")
    [void]$sb.AppendLine("// Param${p}_HardwareSelect == OWN_HW_ID and ROLE_<name>_ON_OWN_BOARD; otherwise it holds no value.")
    [void]$sb.AppendLine("namespace HardwareProfile")
    [void]$sb.AppendLine("{")
    [void]$sb.AppendLine("constexpr bool contains(const uint16_t* ids, uint16_t count, uint16_t id, uint16_t i = 0)")
    [void]$sb.AppendLine("{")
    [void]$sb.AppendLine("    return i < count && (ids[i] == id || contains(ids, count, id, i + 1));")
    [void]$sb.AppendLine("}")
    foreach ($role in $M.Roles) {
      $ids = @($Boards | Where-Object { @($_.Pins[$role.Name]).Count -gt 0 } | ForEach-Object { "0x{0:X4}" -f $_.HwId })
      $count = $ids.Count
      if ($count -eq 0) { $ids = @("0") }
      [void]$sb.AppendLine(("constexpr uint16_t ROLE_{0}_HW_IDS[] = {{{1}}};" -f $role.Name, ($ids -join ", ")))
      [void]$sb.AppendLine(("constexpr bool ROLE_{0}_ON_OWN_BOARD = contains(ROLE_{0}_HW_IDS, {1}, OWN_HW_ID);" -f $role.Name, $count))
    }
    [void]$sb.AppendLine("} // namespace HardwareProfile")
    $first = $Boards[0].Slot
    foreach ($role in $M.Roles) {
      for ($slot = 1; $slot -le $role.Count; $slot++) {
        [void]$sb.AppendLine(("#define {0}_ROLE_{1}_{2} Param{0}_{1}{2}B{3}" -f $p, $role.Name, $slot, $first))
      }
    }
  }
  if ($null -ne $M.PortManual) { [void]$sb.Append((New-PortValuesHeader $M)) }
  if ($M.Conflicts -and $M.Conflicts.Reserved) { [void]$sb.Append((New-ReservedGpioHeader $M)) }
  return $sb.ToString()
}

# @brief Firmware part of <Conflicts reserved="true">: HardwareProfile::isReservedGpio(gpio) of the own board, the pins of the ETS
#        check: the automatic pin macros, the KNX UART in a TP build (MASK_VERSION as knx config.h), the manifest <ReservedPins>
#        (each #ifdef, value 0..255) and the flash / PSRAM bus of an ESP32 chip from the ESP-IDF headers
function New-ReservedGpioHeader($M) {
  $term = { param([string]$Mac) return ("#ifdef {0}`n        || ((int)({0}) >= 0 && (int)({0}) <= 254 && gpio == (uint8_t)({0}))`n#endif`n" -f $Mac) }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("// GPIOs the board uses itself: the set of the ETS conflict check (<Conflicts reserved=`"true`">). Flash / PSRAM pins from the")
  [void]$sb.AppendLine("// ESP-IDF headers; CS1 needs CONFIG_SPIRAM and BOARD_HAS_PSRAM (esp32-hal-psram.h clears CONFIG_SPIRAM without it).")
  [void]$sb.AppendLine("#if defined(ARDUINO_ARCH_ESP32) && defined(__has_include)")
  [void]$sb.AppendLine("#if __has_include(<soc/spi_pins.h>)")
  [void]$sb.AppendLine("#include <soc/spi_pins.h>")
  [void]$sb.AppendLine("#endif")
  [void]$sb.AppendLine("#if __has_include(<sdkconfig.h>)")
  [void]$sb.AppendLine("#include <sdkconfig.h>")
  [void]$sb.AppendLine("#endif")
  [void]$sb.AppendLine("#endif")
  [void]$sb.AppendLine("namespace HardwareProfile")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("/// @brief true when the own board uses the GPIO itself; a pin macro outside 0..254 (not present, IO expander) is no GPIO")
  [void]$sb.AppendLine("constexpr bool isReservedGpio(uint8_t gpio)")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("    // (void)gpio: a board without any of the pins leaves the parameter unused")
  [void]$sb.AppendLine("    return (void)gpio, false")
  [void]$sb.AppendLine("    // pins OGM-Common drives itself (Hardware.cpp, Common.cpp, Led/Manager.cpp, TimerInterrupt.cpp)")
  foreach ($mac in $AUTO_RESERVED) { [void]$sb.Append((& $term $mac)) }
  [void]$sb.AppendLine("    // KNX UART: used with KNX_HAS_TP only, set by knx config.h for these mask versions (USE_TP)")
  [void]$sb.AppendLine("#if defined(MASK_VERSION) && (MASK_VERSION == 0x07B0 || MASK_VERSION == 0x091A || MASK_VERSION == 0x2920)")
  foreach ($mac in $TP_RESERVED) { [void]$sb.Append((& $term $mac)) }
  [void]$sb.AppendLine("#endif")
  $own = @($M.Reserved | Where-Object { $AUTO_RESERVED -notcontains $_ -and $TP_RESERVED -notcontains $_ })
  if ($own.Count -gt 0) {
    [void]$sb.AppendLine("    // <ReservedPins> of the manifest")
    foreach ($mac in $own) { [void]$sb.Append((& $term $mac)) }
  }
  [void]$sb.AppendLine("#if defined(MSPI_IOMUX_PIN_NUM_CLK)")
  [void]$sb.AppendLine("        || gpio == MSPI_IOMUX_PIN_NUM_CLK || gpio == MSPI_IOMUX_PIN_NUM_MISO || gpio == MSPI_IOMUX_PIN_NUM_MOSI")
  [void]$sb.AppendLine("        || gpio == MSPI_IOMUX_PIN_NUM_HD || gpio == MSPI_IOMUX_PIN_NUM_WP || gpio == MSPI_IOMUX_PIN_NUM_CS0")
  [void]$sb.AppendLine("#endif")
  [void]$sb.AppendLine("#if defined(MSPI_IOMUX_PIN_NUM_CS1) && defined(CONFIG_SPIRAM) && (defined(BOARD_HAS_PSRAM) || !defined(ESP32_ARDUINO_LIB_BUILDER))")
  [void]$sb.AppendLine("        || gpio == MSPI_IOMUX_PIN_NUM_CS1")
  [void]$sb.AppendLine("#endif")
  [void]$sb.AppendLine("#if defined(MSPI_IOMUX_PIN_NUM_D4) && (defined(CONFIG_SPIRAM_MODE_OCT) || defined(CONFIG_ESPTOOLPY_OCT_FLASH))")
  [void]$sb.AppendLine("        || gpio == MSPI_IOMUX_PIN_NUM_D4 || gpio == MSPI_IOMUX_PIN_NUM_D5 || gpio == MSPI_IOMUX_PIN_NUM_D6")
  [void]$sb.AppendLine("        || gpio == MSPI_IOMUX_PIN_NUM_D7 || gpio == MSPI_IOMUX_PIN_NUM_DQS")
  [void]$sb.AppendLine("#endif")
  [void]$sb.AppendLine("        ;")
  [void]$sb.AppendLine("}")
  [void]$sb.AppendLine("} // namespace HardwareProfile")
  return $sb.ToString()
}

# @brief Firmware part of the port value encoding (root portManualValue / portNoneValue): constants and the resolution of a
#        port selection to a GPIO with the helpers of include/HardwareConfig/Helpers/HardwarePorts.h. The selection guard is
#        a parameter: a port byte holds a value for this board only while the ETS hardware selection is this board.
function New-PortValuesHeader($M) {
  $p = $M.Prefix
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("// Port selections (HardwareProfile.xml portManualValue / portNoneValue, the same values as the ETS conflict check):")
  [void]$sb.AppendLine("// 0..n-1 = port n of the board (hwPortGpio), PORT_MANUAL = the manual GPIO parameter, PORT_NONE and every value that")
  [void]$sb.AppendLine("// is no port of the board = no GPIO; PORT_MANUAL and PORT_NONE are tested first, a described port on one of them is")
  [void]$sb.AppendLine("// never used (the generator stops when ETS offers such a port). Pass Param${p}_HardwareSelect as 'selected': another")
  [void]$sb.AppendLine("// or no board gives GPIO_NONE")
  [void]$sb.AppendLine("// (ETS writes the port bytes for the selected board only; an unwritten byte reads 0 = port 1).")
  [void]$sb.AppendLine('#include "HardwareConfig/Helpers/HardwarePorts.h"')
  [void]$sb.AppendLine("namespace HardwareProfile")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("constexpr uint8_t PORT_MANUAL = $($M.PortManual);")
  [void]$sb.AppendLine("constexpr uint8_t PORT_NONE = $($M.PortNone);")
  [void]$sb.AppendLine("constexpr uint8_t GPIO_NONE = 255;")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("/// @brief true when the ETS hardware selection is this board (never while nothing is selected)")
  [void]$sb.AppendLine("constexpr bool selectionIsOwn(uint16_t selected)")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("    return selected != NOT_SELECTED && selected == OWN_HW_ID;")
  [void]$sb.AppendLine("}")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("/// @brief GPIO of a signal from its port selection: PORT_MANUAL -> manualGpio, a port of the board -> hwPortGpio(), else GPIO_NONE")
  [void]$sb.AppendLine("/// @param selected ETS hardware selection (Param${p}_HardwareSelect); not this board -> GPIO_NONE")
  [void]$sb.AppendLine("constexpr uint8_t signalGpio(uint16_t selected, uint8_t portValue, uint8_t manualGpio)")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("    return !selectionIsOwn(selected) ? GPIO_NONE")
  [void]$sb.AppendLine("         : portValue == PORT_MANUAL ? manualGpio")
  [void]$sb.AppendLine("         : portValue == PORT_NONE ? GPIO_NONE")
  [void]$sb.AppendLine("         : hwPortGpio(portValue);")
  [void]$sb.AppendLine("}")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("/// @brief GPIO of relay relayIndex (0-based): a hard-wired relay (relayIndex < hwRelayCount()) -> hwRelayGpio(), its port byte")
  [void]$sb.AppendLine("///        is ignored; every further relay -> signalGpio(). Not this board -> GPIO_NONE, also for a hard-wired relay.")
  [void]$sb.AppendLine("constexpr uint8_t relaySignalGpio(uint16_t selected, uint8_t relayIndex, uint8_t portValue, uint8_t manualGpio)")
  [void]$sb.AppendLine("{")
  [void]$sb.AppendLine("    return !selectionIsOwn(selected) ? GPIO_NONE")
  [void]$sb.AppendLine("         : relayIndex < hwRelayCount() ? hwRelayGpio(relayIndex)")
  [void]$sb.AppendLine("         : signalGpio(selected, portValue, manualGpio);")
  [void]$sb.AppendLine("}")
  [void]$sb.AppendLine("} // namespace HardwareProfile")
  return $sb.ToString()
}

# ------------------------------------------------------------------------------------------------
# Mode: -Init (one-time manifest for an OAM without one)
# ------------------------------------------------------------------------------------------------
# @brief Path of $Target relative to the folder $FromDir, with "/" (.NET Framework has no GetRelativePath)
function Get-RelativePath([string]$FromDir, [string]$Target) {
  $from = New-Object System.Uri(($FromDir.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar))
  $to = New-Object System.Uri($Target)
  return [System.Uri]::UnescapeDataString($from.MakeRelativeUri($to).ToString())
}

# @brief XML comment text: "--" is not allowed inside a comment
function ConvertTo-XmlComment([string]$Text) { return ($Text -replace '-(?=-)', '- ') }

function Invoke-Init {
  $target = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location).Path, $Manifest))
  $project = [System.IO.Path]::GetDirectoryName($target)
  if (Test-Path -LiteralPath $target) { Stop-WithError "Manifest exists: $target - -Init only creates a new one; edit the existing manifest instead" }
  if (-not (Test-Path -LiteralPath ([System.IO.Path]::Combine($project, "platformio.ini")))) { Stop-WithError "No platformio.ini in $project (the manifest is written next to it)" }
  Write-Step "Init: $target"

  # standard outputs; an existing file must be a generator output
  $outputs = [ordered]@{ conf = "src/HardwareProfile.conf.xml"; share = "src/HardwareProfile.share.xml"; script = "src/HardwareProfile.script.js"; header = "include/HardwareProfileData.h" }
  foreach ($k in $outputs.Keys) {
    $p = [System.IO.Path]::Combine($project, $outputs[$k])
    if ((Test-Path -LiteralPath $p) -and -not ([System.IO.File]::ReadAllText($p).Contains("Build-HardwareProfile.ps1"))) {
      Stop-WithError ("{0} exists and is not a generator output - the generator would overwrite it" -f $p)
    }
  }
  $caps = "lib/OGM-HardwareConfig/generator/capabilities/Common.caps.xml"
  if (-not (Test-Path -LiteralPath ([System.IO.Path]::Combine($project, $caps)))) { Stop-WithError "Not found: $caps (relative to $project)" }

  # product XML(s): src/*.xml with <op:ETS (Dev and Release variants); module types and prefixes in use
  $products = @(Get-ChildItem -Path ([System.IO.Path]::Combine($project, "src")) -Filter "*.xml" -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -notlike "*.debug.xml" } | Sort-Object Name |
      Where-Object { [System.IO.File]::ReadAllText($_.FullName).Contains("<op:ETS") })
  if ($products.Count -eq 0) { Stop-WithError "No product XML (src/*.xml with <op:ETS) in $project" }
  $usedTypes = @{}; $usedPrefixes = @{}
  foreach ($f in $products) {
    $text = [System.IO.File]::ReadAllText($f.FullName)
    # op:define in comments does not count; CDATA and comments in one left-to-right pass, so a "<!--"
    # inside CDATA (script) does not swallow the defines after it; attribute values in either quote style
    $text = [regex]::Replace($text, '(?s)<!\[CDATA\[.*?\]\]>|<!--.*?-->', '')
    foreach ($d in [regex]::Matches($text, '<op:define\b[^>]*>')) {
      if ($d.Value -match '\bModuleType\s*=\s*["'']\s*(\d+)\s*["'']') { $usedTypes[[int]$Matches[1]] = $true }
      if ($d.Value -match '\bprefix\s*=\s*["'']([^"'']+)["'']') { $usedPrefixes[$Matches[1]] = $true }
    }
  }
  $moduleType = 0
  foreach ($c in @(45..99) + @(44..1)) { if (-not $usedTypes.ContainsKey($c)) { $moduleType = $c; break } }
  if ($moduleType -eq 0) { Stop-WithError "No free ModuleType 1..99" }
  $prefix = "HWP"; $n = 2
  while ($usedPrefixes.ContainsKey($prefix)) { $prefix = "HWP$n"; $n++ }
  Write-Step ("Product XML: {0}" -f (($products | ForEach-Object { $_.Name }) -join ", "))
  Write-Step ("ModuleTypes in use: {0} -> moduleType {1}; prefixes in use: {2} -> prefix {3}" -f (($usedTypes.Keys | Sort-Object) -join ", "), $moduleType, (($usedPrefixes.Keys | Sort-Object) -join ", "), $prefix)

  # boards of the release_* envs; envs without a board go to exclude
  $script:InitMode = $true
  $script:NoBoardEnvs = @()
  $found = @(Get-PlatformIOBoards @{} "release_*" $project @())
  $rows = @{}
  foreach ($eb in $found) {
    $ident = Get-BoardIdentity $eb.Define (@($eb.Define) + @($eb.Flags | ForEach-Object { $_ -replace '^-D', '' }))
    if ($null -eq $ident.HwId) { continue }
    if (-not $rows.ContainsKey($ident.HwId)) { $rows[$ident.HwId] = @{ HwId = $ident.HwId; Define = $eb.Define; Name = $ident.Name; Envs = @() } }
    $rows[$ident.HwId].Envs += $eb.Env
  }
  $boards = @($rows.Values | Sort-Object { [int]$_.HwId })
  $noBoard = @($script:NoBoardEnvs | Sort-Object -Unique)
  foreach ($b in $boards) { Write-Ok ("0x{0:X4}  {1}  {2}  [{3}]" -f $b.HwId, $b.Define, $b.Name, ($b.Envs -join ", ")) }
  foreach ($e in $noBoard) { Write-Warn ("env {0} builds no board - written to exclude" -f $e) }
  if ($boards.Count -eq 0) { Stop-WithError "No release_* env builds a board with DEVICE_HW_ID - no manifest written" }
  if ($boards.Count -eq 1) { Stop-WithError "Only one release_* env builds a board: a hardware selection needs at least two boards - no manifest written" }

  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
  [void]$sb.AppendLine('<!--')
  [void]$sb.AppendLine('  Hardware profile manifest, created by lib/OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 -Init.')
  [void]$sb.AppendLine('  Review and commit it; the generator reads it on every build. Boards found in the release_* envs:')
  foreach ($b in $boards) { [void]$sb.AppendLine((ConvertTo-XmlComment ("    0x{0:X4}  {1}  {2}" -f $b.HwId, $b.Define, $b.Name))) }
  [void]$sb.AppendLine('-->')
  [void]$sb.AppendLine(('<HardwareProfile prefix="{0}" moduleType="{1}" text="Hardware" unselected="showAll" ids="slot">' -f $prefix, $moduleType))
  [void]$sb.AppendLine('  <!-- showAll: in an existing product the ETS download writes the default of every invisible parameter; hide only for new products -->')
  [void]$sb.AppendLine(('  <Output conf="{0}" share="{1}" script="{2}" header="{3}" />' -f $outputs.conf, $outputs.share, $outputs.script, $outputs.header))
  [void]$sb.AppendLine(('  <Import href="{0}" />' -f $caps))
  if ($noBoard.Count -gt 0) {
    [void]$sb.AppendLine('  <!-- release_* envs that build no board -->')
    [void]$sb.AppendLine(('  <Boards platformio="release_*" exclude="{0}" />' -f ($noBoard -join " ")))
  }
  else { [void]$sb.AppendLine('  <Boards platformio="release_*" />') }
  [void]$sb.AppendLine('</HardwareProfile>')
  Write-Utf8File $target $sb.ToString()
  Write-Ok "wrote $target"

  # lines for the product XML, paths relative to it
  $pdir = $products[0].DirectoryName
  $rel = @{}
  foreach ($k in @("conf", "share")) { $rel[$k] = Get-RelativePath $pdir ([System.IO.Path]::GetFullPath([System.IO.Path]::Combine($project, $outputs[$k]))) }
  Write-Host ""
  Write-Host ("  Add to {0}:" -f (($products | ForEach-Object { $_.Name }) -join " and "))
  Write-Host ("    <op:config href=`"{0}`" />" -f $rel.conf)
  Write-Host ("    <op:define prefix=`"{0}`" ModuleType=`"{1}`" configTransferName=`"Hardware`" share=`"{2}`" />" -f $prefix, $moduleType, $rel.share)
  Write-Host "  and inside <generate><Dynamic>:"
  Write-Host ("    <op:include href=`"{0}`" xpath=`"//ApplicationProgram/Dynamic/*`" prefix=`"{1}`" />" -f $rel.share, $prefix)
  if (-not $usedPrefixes.ContainsKey("UCT")) { Write-Warn "No ConfigTransfer (UCT) module: a product with a module list needs OFM-ConfigTransfer" }
  Write-Warn "The ETS application content changes: raise the ApplicationVersion with ReplacesVersionsDownTo"
  Write-Host ""
  Write-Host "  Then run this script without -Init (it writes the outputs and the slot file)." -ForegroundColor Green
  exit 0
}

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
  $script:IdsIndex = ($m.Ids -eq "index")
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
        $names = @($allBoards | Where-Object { $_ -like $be.Define } | Sort-Object)
        if ($names.Count -eq 0) { Stop-OnSkip ("No board with DEVICE_HW_ID matches {0}" -f $be.Define) }
      }
      foreach ($n in $names) {
        $prev = @($expanded | Where-Object { $_.Define -eq $n })
        if ($prev.Count -eq 0) { $expanded.Add(@{ Define = $n; Flags = $be.Flags; Explicit = (-not $isPattern) }); continue }
        $norm = { param($f) (@($f | ForEach-Object { $_ -replace '^-D', '' }) | Sort-Object) -join " " }
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
      if ($relA -ne $relB) { Stop-WithError ("0x{0:X4}: env {1} has other relays than env {2}" -f [int]$first.HwId, $o.Env, $first.Env) }
      if ($o.InfoUrl -ne $first.InfoUrl) { Stop-WithError ("0x{0:X4}: env {1} has another info URL than env {2}" -f [int]$first.HwId, $o.Env, $first.Env) }
      if ($o.InfoText -cne $first.InfoText) { Stop-WithError ("0x{0:X4}: env {1} has another HW_INFO_TEXT than env {2}" -f [int]$first.HwId, $o.Env, $first.Env) }
      if ($o.Mcu -cne $first.Mcu) { Stop-WithError ("0x{0:X4}: env {1} builds for MCU '{2}', env {3} for '{4}'" -f [int]$first.HwId, $o.Env, $o.Mcu, $first.Env, $first.Mcu) }
      if ($portsA -ne $portsB -or $first.PortCount -ne $o.PortCount) { Write-Warn ("0x{0:X4}: env {1} has other ports than env {2} - the ports of {2} are used" -f [int]$first.HwId, $o.Env, $first.Env) }
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
        $first.Pins[$rn] = @($merged | Sort-Object @{ Expression = { [regex]::Replace($_.Label, '\d+', { param($mt) $mt.Value.PadLeft(5, '0') }) } })
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
  if ($clash) { Stop-WithError ("unselectedValue {0} is the DEVICE_HW_ID of {1}" -f $m.UnselectedValue, $clash.Define) }
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
  # ids="index": the board number in IDs is the list position (no slot file); else the slot file
  if ($m.Ids -eq "index") { foreach ($b in $boards) { $b.Slot = $b.Index } }
  $slotFile = $null
  if ($m.Ids -ne "index") { $slotFile = Update-BoardSlots $m $boards }
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
  if ($null -ne $slotFile) { $rendered += $slotFile }
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
