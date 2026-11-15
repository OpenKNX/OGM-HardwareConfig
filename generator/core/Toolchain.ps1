#Requires -Version 5.1
<#
Open =
-----+  Toolchain
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Toolchain.ps1

.SYNOPSIS
    C preprocessor of the board headers: PlatformIO toolchains, compiler choice, preprocessor runs, C values.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Get-PioCoreDir, Test-CppPreprocessor, Get-PioToolchains, Get-McuToolchainPrefixes, Get-McuArchDefines, Find-Compiler, Get-BoardCompiler, ConvertTo-DefineLine, Invoke-Preprocessor, ConvertFrom-CString, Test-CNegative, ConvertFrom-CInteger.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

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
    foreach ($d in @(Get-OrdinalSorted @(Get-ChildItem -LiteralPath $pkg -Directory -Filter "toolchain-*") { $_.Name })) {
      $bin = [System.IO.Path]::Combine($d.FullName, "bin")
      if (-not (Test-Path -LiteralPath $bin)) { continue }
      foreach ($f in @(Get-OrdinalSorted @(Get-ChildItem -LiteralPath $bin -File) { $_.Name })) {
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
  foreach ($pfx in @(@("arm-none-eabi") + @(Get-OrdinalSorted @($tc.Keys | Where-Object { $_ -ne "arm-none-eabi" })))) {
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
