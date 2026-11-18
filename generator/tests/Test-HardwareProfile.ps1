#Requires -Version 5.1
<#
Open =
-----+  Test-HardwareProfile
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/tests/Test-HardwareProfile.ps1
#>

<#
.SYNOPSIS
    Self-test of the hardware profile generator: runs it on small test manifests and checks what it must do and must refuse.

.DESCRIPTION
    Every test works in its own throw-away folder (system temp); the repository is not touched. A small manifest with three
    boards of the OGM-HardwareConfig headers (no PlatformIO) is generated once and copied for each test.

      Outputs        a second run changes nothing (-Check)
      Bit order      a capability inserted before others keeps every recorded bit; a removed name and a bit listed twice stop
      Version guard  a comment in the product XML does not warn, an attribute does, a new version records it, a second ets
                     line stops
      Manifest       unknown attribute warns; invalid prefix and ids="index" stop
      Fixes          parts file with both Assigns and the read-only ParameterRef; wrong case and a ref fixed twice stop; value from
                     a board macro per board (show="assign"), a macro on no board leaves the normal row
      PartRows       rows of a part per board with label groups, a board without the condition has no row; a selection with no
                     row, two rows or outside an inline block stops
      Reserved       LED macros of the serial LED auto config are no GPIOs (ETS script and firmware header, compiled with a
                     g++ / clang++); with LED_INIT and as GPIO LEDs they stay reserved, an expander pin is no GPIO
      -Init          refuses a product XML that already includes a hardware module
      Language       every T text of the code is in core/Messages.de.psd1 with the same placeholders; German by default
      Helpers        ordinal sort (also of a generic List); PNG written and read back gives the same pixels
      Header         HardwarePorts.h relay checks with -Wall -Wextra -Werror (needs a g++ / clang++; else SKIP)
      Demo           -Check of examples/HardwareProfileDemo (needs PlatformIO and the demo lib/ links; else SKIP)
      Demo update    Test-DemoUpdate.ps1 normal and -Break (only with -Full; needs the OpenKNXproducer)

    Output: one line per test (PASS / FAIL / SKIP, time), the reason of a failure below it, a summary at the end.
    Exit code 0 when no test failed, 1 otherwise.

.PARAMETER Only
    Run only the tests whose id or name matches this wildcard, e.g. "fixes*".

.PARAMETER Full
    Also run the slow demo update test (about two minutes).

.PARAMETER KeepWork
    Keep the work folder (its path is printed) to look at the files of a failed test.

.PARAMETER Language
    Language of the output: de (default) or en. The generator under test always runs in English (the checks match its
    texts); one test runs it in German.

.PARAMETER Help
    Shows this help.

.EXAMPLE
    pwsh generator/tests/Test-HardwareProfile.ps1
    pwsh generator/Build-HardwareProfile.ps1 -SelfTest

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>
[CmdletBinding()]
param(
  [string]$Only = "",
  [switch]$Full,
  [switch]$KeepWork,
  [Alias("h")][switch]$Help,
  [ValidateSet("de", "en")][string]$Language = "de"
)

$ErrorActionPreference = "Stop"
if ($Help) { Get-Help $PSCommandPath -Detailed; exit 0 }

$GeneratorDir = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, ".."))
$RepoDir = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($GeneratorDir, ".."))
$Generator = [System.IO.Path]::Combine($GeneratorDir, "Build-HardwareProfile.ps1")
$PwshExe = (Get-Process -Id $PID).Path
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$ae = [string][char]0xE4
$Work = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "oknx-hwtest-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
[void][System.IO.Directory]::CreateDirectory($Work)

# console helpers of the generator (logo) and the text helpers under test
. ([System.IO.Path]::Combine($GeneratorDir, "core", "Console.ps1"))
. ([System.IO.Path]::Combine($GeneratorDir, "core", "Language.ps1"))
Set-OutputLanguage $Language
. ([System.IO.Path]::Combine($GeneratorDir, "core", "Text.ps1"))
. ([System.IO.Path]::Combine($GeneratorDir, "helpers", "PngImage.ps1"))
$script:CheckMode = $false

# ------------------------------------------------------------------------------------------------
# tools
# ------------------------------------------------------------------------------------------------

# @brief Runs the generator in its own process; returns exit code and the whole output as one string
function Invoke-Generator([string]$Dir, [string[]]$Arguments, [string]$Manifest = "HardwareProfile.xml") {
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  Push-Location $Dir
  try {
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Generator, "-Manifest", [System.IO.Path]::Combine($Dir, $Manifest)) + @($Arguments)
    if (@($Arguments) -notcontains "-Language") { $argList += @("-Language", "en") }
    $out = (& $PwshExe @argList 2>&1 | Out-String)
    $code = $LASTEXITCODE
  }
  finally { Pop-Location; $ErrorActionPreference = $prev }
  return @{ Exit = $code; Out = $out }
}

function Read-Text([string]$Path) { return [System.IO.File]::ReadAllText($Path) }
function Write-Text([string]$Path, [string]$Text) { [System.IO.File]::WriteAllText($Path, $Text, $Utf8) }

# @brief Replaces one exact occurrence in a file (a test that edits the wrong place fails here, not later)
function Edit-File([string]$Path, [string]$Old, [string]$New) {
  $t = Read-Text $Path
  $n = ([regex]::Matches($t, [regex]::Escape($Old))).Count
  if ($n -ne 1) { throw (T "test setup: '{0}' found {1} times in {2}" $Old $n ([System.IO.Path]::GetFileName($Path))) }
  Write-Text $Path $t.Replace($Old, $New)
}

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Exit($Result, [int]$Code) {
  if ($Result.Exit -ne $Code) { throw (T "exit code {0}, expected {1}`n{2}" $Result.Exit $Code (Get-Tail $Result.Out)) }
}
function Assert-Out($Result, [string]$Pattern, [string]$What) {
  if ($Result.Out -notmatch $Pattern) { throw (T "{0}: output does not match '{1}'`n{2}" $What $Pattern (Get-Tail $Result.Out)) }
}
function Assert-NoOut($Result, [string]$Pattern, [string]$What) {
  if ($Result.Out -match $Pattern) { throw (T "{0}: output matches '{1}'`n{2}" $What $Pattern (Get-Tail $Result.Out)) }
}
function Get-Tail([string]$Text) { return ((@($Text -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 6) -join "`n") }

# @brief Base project: manifest with three boards (REG1 LAN+TP, REG1 LAN, UP1 Taster), product XML, first run done
function New-BaseProject {
  $dir = [System.IO.Path]::Combine($Work, "base")
  [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($dir, "src"))
  [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($dir, "include"))
  $caps = [System.IO.Path]::Combine($GeneratorDir, "capabilities", "Common.caps.xml") -replace '\\', '/'
  Write-Text ([System.IO.Path]::Combine($dir, "HardwareProfile.xml")) (@(
    '<?xml version="1.0" encoding="utf-8"?>'
    ('<HardwareProfile prefix="TST" moduleType="45" text="Ger' + $ae + 't">')
    '  <Output conf="src/T.conf.xml" share="src/T.share.xml" script="src/T.script.js" header="include/T.h" />'
    ('  <Import href="' + $caps + '" />')
    '  <Capability name="OwnA" text="Own A" expr="defined(TST_NEVER_A)" />'
    '  <Board define="DEVICE_REG1_LAN_TP_BASE" />'
    '  <Board define="DEVICE_REG1_LAN_BASE" />'
    '  <Board define="DEVICE_UP1_TAS_4X" />'
    '</HardwareProfile>'
  ) -join "`n")
  Write-Text ([System.IO.Path]::Combine($dir, "src", "T.xml")) (@(
    '<?xml version="1.0" encoding="utf-8"?>'
    '<KNX xmlns:op="http://github.com/OpenKNX/OpenKNXproducer" xmlns="http://knx.org/xml/project/20">'
    '  <op:ETS OpenKnxId="0xAD" ApplicationNumber="250" ApplicationVersion="1.0" ReplacesVersionsDownTo="0.1" ProductName="Selftest" />'
    '  <op:define prefix="TST" ModuleType="45" share="T.share.xml" />'
    '</KNX>'
  ) -join "`n")
  $r = Invoke-Generator $dir @()
  if ($r.Exit -ne 0) { throw (T "base project: generator failed`n{0}" (Get-Tail $r.Out)) }
  return $dir
}

# @brief Fresh copy of the base project for one test
function Copy-Base([string]$Name) {
  $dir = [System.IO.Path]::Combine($Work, $Name)
  Copy-Item -LiteralPath $script:Base -Destination $dir -Recurse
  return $dir
}

# @brief Deletes a folder tree; a link (junction, symbolic link) is removed as a link, its target stays untouched
function Remove-Tree([string]$Dir) {
  if (-not [System.IO.Directory]::Exists($Dir)) { return }
  foreach ($sub in [System.IO.Directory]::GetDirectories($Dir)) {
    if (([System.IO.File]::GetAttributes($sub) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { [System.IO.Directory]::Delete($sub, $false) }
    else { Remove-Tree $sub }
  }
  foreach ($f in [System.IO.Directory]::GetFiles($Dir)) { [System.IO.File]::SetAttributes($f, [System.IO.FileAttributes]::Normal); [System.IO.File]::Delete($f) }
  [System.IO.Directory]::Delete($Dir, $false)
}

function Find-CppCompiler {
  foreach ($c in @("g++", "clang++")) { $cmd = Get-Command $c -ErrorAction SilentlyContinue; if ($cmd) { return $cmd.Source } }
  $home2 = $env:PLATFORMIO_CORE_DIR; if (-not $home2) { $home2 = [System.IO.Path]::Combine([Environment]::GetFolderPath("UserProfile"), ".platformio") }
  $pkg = [System.IO.Path]::Combine($home2, "packages")
  if (Test-Path -LiteralPath $pkg) {
    foreach ($f in @(Get-ChildItem -LiteralPath $pkg -Recurse -File -Filter "*-g++*" -ErrorAction SilentlyContinue)) {
      if ($f.Name -match '-g\+\+(\.exe)?$') { return $f.FullName }
    }
  }
  return $null
}

# @brief A C++ compiler whose standard library has <cstdint> (the generated firmware header includes it): g++ / clang++ in
#        PATH, else a PlatformIO toolchain; $null when none compiles the probe
function Find-CppCompilerStd {
  if ($script:CxxStdChecked) { return $script:CxxStd }
  $script:CxxStdChecked = $true; $script:CxxStd = $null
  $cands = @(@("g++", "clang++") | ForEach-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Where-Object { $_ } | ForEach-Object { $_.Source })
  $home2 = $env:PLATFORMIO_CORE_DIR; if (-not $home2) { $home2 = [System.IO.Path]::Combine([Environment]::GetFolderPath("UserProfile"), ".platformio") }
  $pkg = [System.IO.Path]::Combine($home2, "packages")
  if (Test-Path -LiteralPath $pkg) {
    $cands += @(Get-ChildItem -LiteralPath $pkg -Recurse -File -Filter "*-g++*" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '-g\+\+(\.exe)?$' } | ForEach-Object { $_.FullName })
  }
  $probe = [System.IO.Path]::Combine($Work, "cxxstd-probe.cpp")
  Write-Text $probe "#include <cstdint>`nstatic_assert(sizeof(uint8_t) == 1, `"probe`");`n"
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    foreach ($c in $cands) {
      & $c -std=gnu++17 -fsyntax-only $probe 2>&1 | Out-Null
      if ($LASTEXITCODE -eq 0) { $script:CxxStd = $c; break }
    }
  }
  finally { $ErrorActionPreference = $prev }
  return $script:CxxStd
}

# @brief Directory link without admin rights: junction on Windows, symbolic link elsewhere
function New-DirLink([string]$Path, [string]$Target) {
  if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { New-Item -ItemType Junction -Path $Path -Value $Target | Out-Null }
  else { New-Item -ItemType SymbolicLink -Path $Path -Value $Target | Out-Null }
}

# ------------------------------------------------------------------------------------------------
# tests
# ------------------------------------------------------------------------------------------------

$Tests = New-Object System.Collections.Generic.List[object]
function Add-Test([string]$Id, [string]$Name, [scriptblock]$Run, [string]$Need = "") {
  $Tests.Add(@{ Id = $Id; Name = $Name; Run = $Run; Need = $Need })
}

Add-Test "outputs-stable" (T "Outputs: a second run changes nothing (-Check)") {
  $d = Copy-Base "outputs-stable"
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
}

Add-Test "outputs-stale" (T "Outputs: -Check reports a changed file") {
  $d = Copy-Base "outputs-stale"; $conf = [System.IO.Path]::Combine($d, "src", "T.conf.xml")
  Write-Text $conf ((Read-Text $conf) + "<!-- edited -->`n")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 1; Assert-Out $r 'out of date: T\.conf\.xml' "-Check"
  Assert-True ((Read-Text $conf).EndsWith("<!-- edited -->`n")) (T "-Check wrote the file")
}

Add-Test "bits-insert" (T "Bit order: new capability in front, every bit stays") {
  $d = Copy-Base "bits-insert"; $slots = [System.IO.Path]::Combine($d, "HardwareProfile.slots")
  $before = @((Read-Text $slots) -split "`n" | Where-Object { $_ -match '^(cap|val) ' })
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '  <Capability name="OwnA"' "  <Capability name=`"NewMid`" text=`"New`" expr=`"defined(TST_NEVER_B)`" />`n  <Capability name=`"OwnA`""
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $after = @((Read-Text $slots) -split "`n" | Where-Object { $_ -match '^(cap|val) ' })
  foreach ($l in $before) { Assert-True ($after -contains $l) (T "recorded line lost or moved: {0}" $l) }
  $capCount = @($before | Where-Object { $_ -match '^cap ' }).Count
  Assert-True ($after -contains ("cap {0} = NewMid" -f $capCount)) (T "NewMid did not get the next free bit {0}" $capCount)
}

Add-Test "bits-removed" (T "Bit order: a removed capability stops") {
  $d = Copy-Base "bits-removed"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) "  <Capability name=`"OwnA`" text=`"Own A`" expr=`"defined(TST_NEVER_A)`" />`n" ""
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r "OwnA' is gone from the manifest" (T "stop message")
}

Add-Test "bits-twice" (T "Bit order: a bit listed twice in the slot file stops") {
  $d = Copy-Base "bits-twice"; $slots = [System.IO.Path]::Combine($d, "HardwareProfile.slots")
  Write-Text $slots ((Read-Text $slots) + "cap 0 = Other`n")
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'listed twice' (T "stop message")
}

Add-Test "guard-comment" (T "Version guard: a comment in the product XML does not warn") {
  $d = Copy-Base "guard-comment"
  Edit-File ([System.IO.Path]::Combine($d, "src", "T.xml")) '  <op:define' "  <!-- only a comment -->`n  <op:define"
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-NoOut $r 'ETS content changed' (T "comment only")
}

Add-Test "guard-attribute" (T "Version guard: an attribute warns, a new version records it") {
  $d = Copy-Base "guard-attribute"; $prod = [System.IO.Path]::Combine($d, "src", "T.xml")
  Edit-File $prod 'ProductName="Selftest"' 'ProductName="Selftest 2"'
  $r = Invoke-Generator $d @("-Check"); Assert-Out $r 'ETS content changed since T\.xml ApplicationVersion 1\.0' (T "same version")
  Edit-File $prod 'ApplicationVersion="1.0"' 'ApplicationVersion="1.1"'
  $r = Invoke-Generator $d @(); Assert-Exit $r 0; Assert-NoOut $r 'ETS content changed' (T "new version")
  Assert-True ((Read-Text ([System.IO.Path]::Combine($d, "HardwareProfile.slots"))) -match '(?m)^ets "T\.xml" 1\.1 [0-9A-F]{16}$') (T "slot file has no ets line for 1.1")
}

Add-Test "guard-duplicate" (T "Version guard: a second ets line stops") {
  $d = Copy-Base "guard-duplicate"; $slots = [System.IO.Path]::Combine($d, "HardwareProfile.slots")
  Write-Text $slots ((Read-Text $slots) + "ets `"T.xml`" 0.9 0123456789ABCDEF`n")
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'second ets line' (T "stop message")
}

Add-Test "manifest-unknown" (T "Manifest: an unknown attribute warns") {
  $d = Copy-Base "manifest-unknown"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '<Capability name="OwnA"' '<Capability foo="1" name="OwnA"'
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'attribute foo is unknown' (T "warning")
}

Add-Test "manifest-prefix" (T "Manifest: an invalid prefix stops") {
  $d = Copy-Base "manifest-prefix"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'prefix="TST"' 'prefix="T-1"'
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'must be letters and digits' (T "stop message")
}

Add-Test "manifest-ids" (T "Manifest: the removed ids=`"index`" stops") {
  $d = Copy-Base "manifest-ids"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'prefix="TST"' 'prefix="TST" ids="index"'
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'was removed' (T "stop message")
}

$FixLine = '<Fix name="W" capability="Lan" ref="%AID%_P-1401001_R-140100100" value="1" />'
Add-Test "fixes-parts" (T "Fixes: parts file with both Assigns and the read-only row") {
  $d = Copy-Base "fixes-parts"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ("  <Fixes output=`"src/T.fixes.gen.xml`">$FixLine</Fixes>`n</HardwareProfile>")
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.fixes.gen.xml"))
  Assert-True ($f.Contains('<ParameterRef Id="%AID%_P-1401001_R-140100199" RefId="%AID%_P-1401001" Access="Read" />')) (T "read-only ParameterRef missing")
  Assert-True ($f.Contains('<Assign TargetParamRefRef="%AID%_P-1401001_R-140100100" Value="1" />')) (T "Assign of the setting missing")
  Assert-True ($f.Contains('<Assign TargetParamRefRef="%AID%_P-1401001_R-140100199" Value="1" />')) (T "Assign of the read-only row missing")
  Assert-True ($f.Contains('<when test="4129 4130">')) (T "board list is not the two REG1 LAN boards")
}

Add-Test "fixes-case" (T "Fixes: wrong upper/lower case stops") {
  $d = Copy-Base "fixes-case"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ("  <Fixes output=`"src/T.fixes.gen.xml`">" + $FixLine.Replace('"Lan"', '"lan"') + "</Fixes>`n</HardwareProfile>")
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'case-sensitive' (T "stop message")
}

Add-Test "fixes-twice" (T "Fixes: the same ref twice stops") {
  $d = Copy-Base "fixes-twice"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ("  <Fixes output=`"src/T.fixes.gen.xml`">" + $FixLine + $FixLine.Replace('name="W"', 'name="W2"') + "</Fixes>`n</HardwareProfile>")
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'already fixed' (T "stop message")
}

Add-Test "fixes-notcap" (T "Fixes: capability=`"!Name`" fixes the boards without the capability (e.g. hide a module)") {
  $d = Copy-Base "fixes-notcap"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ("  <Fixes output=`"src/T.fixes.gen.xml`"><Fix name=`"NoLan`" capability=`"!Lan`" ref=`"%AID%_UP-1099825_R-109982501`" value=`"0`" show=`"assign`" /></Fixes>`n</HardwareProfile>")
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.fixes.gen.xml"))
  Assert-True ($f -match '<when test="4611">\s*<Assign TargetParamRefRef="%AID%_UP-1099825_R-109982501" Value="0" />') (T "!Lan: only board 4611 (no LAN) must get the value")
  Assert-True (-not $f.Contains('4129') -and -not $f.Contains('4130')) (T "!Lan: the LAN boards 4129 and 4130 must not get the value")
}

Add-Test "page-cardfeatures" (T "Page: cardFeatures lists the features of the selected board under the card, boards with the same lines share a when") {
  $d = Copy-Base "page-cardfeatures"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' "  <Page features=`"Lan`" cardFeatures=`"true`" />`n</HardwareProfile>"
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $x = New-Object System.Xml.XmlDocument; $x.LoadXml((Read-Text ([System.IO.Path]::Combine($d, "src", "T.share.xml"))))
  $ns = New-Object System.Xml.XmlNamespaceManager($x.NameTable); $ns.AddNamespace("k", "http://knx.org/xml/project/20")
  $hl = [regex]::Unescape('Funktionen des Ger\u00E4ts')
  $ch = @($x.SelectNodes("//k:choose[k:when/k:ParameterSeparator[@Text='$hl']]", $ns))
  Assert-True ($ch.Count -eq 1) (T "card features: one choose with the headline expected, found {0}" $ch.Count)
  $w = @($ch[0].SelectNodes("k:when", $ns))
  $lan = @($w | Where-Object { $_.GetAttribute("test") -ceq "4129 4130" })
  $up1 = @($w | Where-Object { $_.GetAttribute("test") -ceq "4611" })
  Assert-True ($lan.Count -eq 1 -and $null -ne $lan[0].SelectSingleNode("k:ParameterSeparator[@Text='LAN: ja']", $ns)) (T "card features: 4129 and 4130 share one when with LAN: ja")
  Assert-True ($up1.Count -eq 1 -and $null -ne $up1[0].SelectSingleNode("k:ParameterSeparator[@Text='LAN: nein']", $ns) -and $up1[0].SelectNodes("k:ParameterSeparator", $ns).Count -eq 2) (T "card features: 4611 with the headline and LAN: nein only")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
  $d = Copy-Base "page-cardfeatures-none"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' "  <Page cardFeatures=`"true`" />`n</HardwareProfile>"
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'cardFeatures needs features' (T "stop message")
}

Add-Test "fixes-tokens" (T "Fixes: ref with tokens of a channel template or part gets its own ParameterRefs block, module digits stay in the shared block") {
  $d = Copy-Base "fixes-tokens"
  $tok = '<Fix name="Ch" capability="Lan" ref="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05701" value="2" />' +
         '<Fix name="Sc" capability="Lan" ref="%AID%_UP-%TT%%CC%%PPP+3%_R-%TT%%CC%%PPP+3%01" value="5" />'
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ("  <Fixes output=`"src/T.fixes.gen.xml`">$FixLine$tok</Fixes>`n</HardwareProfile>")
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.fixes.gen.xml"))
  $shared = $f.Substring($f.IndexOf('<Block name="ParameterRefs">')); $shared = $shared.Substring(0, $shared.IndexOf('</Block>'))
  Assert-True ($shared.Contains('%AID%_P-1401001_R-140100199') -and -not $shared.Contains('%CC%')) (T "shared block: only the read-only ref with module digits")
  Assert-True ($f -match '<Block name="Fix_Ch_ParameterRefs">\s*<ParameterRef Id="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05799" RefId="%AID%_UP-%TT%%CC%057" Access="Read" />\s*</Block>') (T "template fix: own ParameterRefs block with the read-only ref 99 missing")
  Assert-True ($f -match '<Block name="Fix_Sc_ParameterRefs">\s*<ParameterRef Id="%AID%_UP-%TT%%CC%%PPP\+3%_R-%TT%%CC%%PPP\+3%99" RefId="%AID%_UP-%TT%%CC%%PPP\+3%" Access="Read" />') (T "part fix: own ParameterRefs block with the read-only ref 99 missing")
  Assert-True ($f.Contains('<Assign TargetParamRefRef="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05701" Value="2" />') -and $f.Contains('<Assign TargetParamRefRef="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05799" Value="2" />')) (T "template fix: Assigns of the setting and the read-only row missing")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
  $d = Copy-Base "fixes-badref"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ("  <Fixes output=`"src/T.fixes.gen.xml`">" + $FixLine.Replace('_R-140100100', '_R-140200100') + "</Fixes>`n</HardwareProfile>")
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'or producer tokens' (T "stop message")
}

# @brief <PartRows> / <Fix valueMacro> test project: base copy with a board header on top of the real ones (labels and values per
#        board: REG1 LAN+TP 0x1021 = 4129, REG1 LAN 0x1022 = 4130, UP1 Taster 0x1203 = 4611) and a small part file
function Copy-BaseWithBoardMacros([string]$Name, [string]$ManifestLines) {
  $d = Copy-Base $Name
  $real = [System.IO.Path]::Combine($RepoDir, "include", "HardwareConfig.h") -replace '\\', '/'
  Write-Text ([System.IO.Path]::Combine($d, "include", "HardwareConfig.h")) (@(
    '#pragma once'
    ('#include "' + $real + '"')
    '#ifdef DEVICE_REG1_LAN_TP_BASE'
    '#define TST_LBL "gruen"'
    '#define TST_LBL2 "rot"'
    '#define TST_FIXV 3'
    '#endif'
    '#ifdef DEVICE_REG1_LAN_BASE'
    '#define TST_LBL "blau"'
    '#define TST_LBL2 "rot"'
    '#endif'
    '#ifdef DEVICE_UP1_TAS_4X'
    '#define TST_LBL "gelb"'
    '#define TST_FIXV 7'
    '#endif'
  ) -join "`n")
  $row = { param($ref, $text) @(
    '        <ParameterBlock Id="%AID%_PB-nnn" Inline="true" Layout="Grid">'
    ('          <ParameterSeparator Id="%AID%_PS-nnn" Text="' + $text + '" Cell="1,1" />')
    ('          <ParameterRefRef RefId="' + $ref + '" Cell="1,2" />')
    '        </ParameterBlock>') }
  Write-Text ([System.IO.Path]::Combine($d, "src", "P.part.xml")) (@(
    '<?xml version="1.0" encoding="utf-8"?>'
    '<KNX xmlns:op="http://github.com/OpenKNX/OpenKNXproducer" xmlns="http://knx.org/xml/project/20">'
    '  <ManufacturerData><Manufacturer RefId="M-00FA"><ApplicationPrograms><ApplicationProgram><Dynamic><ChannelIndependentBlock>'
    '      <ParameterBlock Id="%AID%_PB-nnn" Name="Page" Text="Page">'
    ) + (& $row '%AID%_UP-%TT%00020_R-%TT%0002001' 'Row A%TST_X%') + (& $row '%AID%_UP-%TT%00021_R-%TT%0002101' 'Row B') +
    (& $row '%AID%_UP-%TT%00022_R-%TT%0002201' 'Row C') + (& $row '%AID%_P-%TT%00030_R-%TT%0003001' 'Dup 1') +
    (& $row '%AID%_P-%TT%00030_R-%TT%0003001' 'Dup 2') + @(
    '        <ParameterRefRef RefId="%AID%_P-%TT%00040_R-%TT%0004001" />'
    '      </ParameterBlock>'
    '  </ChannelIndependentBlock></Dynamic></ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData>'
    '</KNX>'
  ) -join "`n")
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ("  <IncludePath>include</IncludePath>`n" + $ManifestLines + "`n</HardwareProfile>")
  return $d
}
$RowsSrc = '<PartRows source="src/P.part.xml" output="src/T.rows.gen.xml">'
$RowA = '<Row ref="%AID%_UP-%TT%00020_R-%TT%0002001" expr="defined(DEVICE_REG1_LAN_TP_BASE) || defined(DEVICE_REG1_LAN_BASE)" label="TST_LBL" />'

Add-Test "partrows-rows" (T "PartRows: rows per board, label groups, board without the condition has no row") {
  $d = Copy-BaseWithBoardMacros "partrows-rows" ($RowsSrc + $RowA +
    '<Row ref="%AID%_UP-%TT%00021_R-%TT%0002101" expr="defined(DEVICE_UP1_TAS_4X)" />' +
    '<Row ref="%AID%_UP-%TT%00022_R-%TT%0002201" expr="defined(DEVICE_REG1_LAN_TP_BASE) || defined(DEVICE_REG1_LAN_BASE)" label="TST_LBL2" /></PartRows>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.rows.gen.xml"))
  # one choose per row on the selection of the hardware module (ModuleType 45, explicit digits)
  $parts = @($f -split '<choose ParamRefId="%AID%_UP-4500001_R-450000101">')
  Assert-True ($parts.Count -eq 4) (T "expected 3 choose on the hardware selection, found {0}" ($parts.Count - 1))
  $a = $parts[1].Substring(0, $parts[1].IndexOf('</choose>')); $b = $parts[2].Substring(0, $parts[2].IndexOf('</choose>')); $c = $parts[3].Substring(0, $parts[3].IndexOf('</choose>'))
  Assert-True ($a.Contains('<when test="0">') -and $a.Contains('Text="Row A%TST_X%"')) (T "row A: original row for not selected missing")
  Assert-True ($a.Contains('<when test="4129">') -and $a.Contains('Text="Row A (gruen)%TST_X%"')) (T "row A: label group gruen (4129) missing")
  Assert-True ($a.Contains('<when test="4130">') -and $a.Contains('Text="Row A (blau)%TST_X%"')) (T "row A: label group blau (4130) missing")
  Assert-True (-not $a.Contains('4611') -and -not $a.Contains('gelb')) (T "row A: board 4611 fails the condition and must have no row")
  Assert-True ($b.Contains('<when test="4611">') -and ([regex]::Matches($b, 'Text="Row B"')).Count -eq 2 -and -not $b.Contains('4129')) (T "row B: only 4611, original text")
  Assert-True ($c.Contains('<when test="4129 4130">') -and $c.Contains('Text="Row C (rot)"')) (T "row C: one group for the same label")
  Assert-True ($f.Contains('Text="Dup 1"') -and $f.Contains('<ParameterRefRef RefId="%AID%_P-%TT%00040_R-%TT%0004001" />')) (T "rows not selected changed")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
}

Add-Test "partrows-nohit" (T "PartRows: a selection without a row stops") {
  $d = Copy-BaseWithBoardMacros "partrows-nohit" ($RowsSrc + '<Row ref="%AID%_UP-%TT%00099_R-%TT%0009901" expr="1" /></PartRows>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'has no ParameterRefRef with this RefId' (T "stop message")
  Assert-True (-not (Test-Path -LiteralPath ([System.IO.Path]::Combine($d, "src", "T.rows.gen.xml")))) (T "a parts file was written")
}

# @brief <ValueNotices>: table header with off macros per board; -Envs: the boards come from a platformio.ini, REG1 LAN has a
#        second env (flag TST_V2) that adds index 3
function Copy-BaseWithValueNotices([string]$Name, [string]$Lines, [switch]$Envs) {
  $d = Copy-Base $Name
  Write-Text ([System.IO.Path]::Combine($d, "include", "Off.h")) (@(
    '#pragma once'
    '#ifdef DEVICE_REG1_LAN_TP_BASE'
    '#define TST_OFF_2 1'
    '#define TST_OFF_5 (1)'
    '#endif'
    '#ifdef DEVICE_REG1_LAN_BASE'
    '#define TST_OFF_2 1'
    '#define TST_OFF_4 0'
    '#ifdef TST_V2'
    '#define TST_OFF_3 1'
    '#endif'
    '#endif'
  ) -join "`n")
  if ($Envs) {
    $mf = [System.IO.Path]::Combine($d, "HardwareProfile.xml")
    Write-Text $mf ((Read-Text $mf) -replace '  <Board define="[A-Z0-9_]+" />\r?\n', '')
    Edit-File $mf '</HardwareProfile>' ('  <Boards platformio="tst_*" />' + "`n</HardwareProfile>")
    Write-Text ([System.IO.Path]::Combine($d, "platformio.ini")) (@(
      '[env:tst_tp]', 'build_flags = -D DEVICE_REG1_LAN_TP_BASE'
      '[env:tst_lan]', 'build_flags = -D DEVICE_REG1_LAN_BASE'
      '[env:tst_lan_v2]', 'build_flags = -D DEVICE_REG1_LAN_BASE -D TST_V2'
      '[env:tst_tas]', 'build_flags = -D DEVICE_UP1_TAS_4X'
    ) -join "`n")
  }
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ('  <BoardTable name="Off" header="include/Off.h" scan="^TST_OFF_(\d+)$" />' + "`n" + $Lines + "`n</HardwareProfile>")
  return $d
}
$VnRef = '%AID%_UP-%TT%%CC%057_R-%TT%%CC%05701'

Add-Test "valuenotices" (T "ValueNotices: one block per notice, boards grouped by values, all = Error, any = Information, board without value has no when") {
  $d = Copy-BaseWithValueNotices "valuenotices" ('<ValueNotices output="src/T.notices.gen.xml">' +
    '<ValueNotice name="Fx" ref="' + $VnRef + '" table="Off" all="Fehlt &amp; l' + $ae + 'uft nicht" any="Fehlt teils" />' +
    '<ValueNotice name="OnlyAny" ref="%AID%_UP-%TT%00010_R-%TT%0001001" table="Off" any="Fehlt teils" />' +
    '<ValueNotice name="OnlyAll" ref="%AID%_UP-%TT%00011_R-%TT%0001101" table="Off" all="Fehlt" /></ValueNotices>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.notices.gen.xml"))
  $x = New-Object System.Xml.XmlDocument; $x.LoadXml($f)
  $blocks = @($f -split '<Block name="')
  Assert-True ($blocks.Count -eq 4) (T "expected 3 blocks, found {0}" ($blocks.Count - 1))
  $fx = $blocks[1]; $oa = $blocks[2]; $ol = $blocks[3]
  Assert-True ($fx.StartsWith('ValueNotice_Fx"') -and $fx.Contains('<choose ParamRefId="%AID%_UP-4500001_R-450000101">')) (T "Fx: choose on the hardware selection (module digits) missing")
  Assert-True ($fx.Contains('<choose ParamRefId="' + $VnRef + '">')) (T "Fx: inner choose keeps the tokens of ref")
  # 4129: 2 5; 4130: 2, 4 = 0 is no value; 4611: none; one env per board, so no "any" value
  Assert-True ($fx.Contains('<when test="4129">') -and $fx.Contains('<when test="2 5"><ParameterSeparator Id="%AID%_PS-nnn" Text="Fehlt &amp; l' + $ae + 'uft nicht" UIHint="Error" /></when>')) (T "Fx: 4129 with 2 5 as Error missing")
  Assert-True ($fx.Contains('<when test="4130">') -and $fx.Contains('<when test="2"><ParameterSeparator') -and -not $fx.Contains('UIHint="Information"')) (T "Fx: 4130 with 2 as Error missing")
  Assert-True (-not $fx.Contains('4611') -and -not $fx.Contains('<when test="0">') -and -not $f.Contains('"4"') -and -not $f.Contains(' 4"')) (T "Fx: board without value, not selected or value 0 got a when")
  Assert-True ($oa.Trim() -ceq 'ValueNotice_OnlyAny">' + "`n  </Block>") (T "OnlyAny: no board has an any value, the block must be empty")
  Assert-True ($ol.Contains('<when test="4129">') -and $ol.Contains('<when test="4130">') -and -not $ol.Contains('UIHint="Information"')) (T "OnlyAll: two groups, no Information")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
}

Add-Test "valuenotices-envs" (T "ValueNotices: a value of only one env of a board gives the any text, values of every env the all text") {
  $d = Copy-BaseWithValueNotices "valuenotices-envs" ('<ValueNotices output="src/T.notices.gen.xml">' +
    '<ValueNotice name="Fx" ref="' + $VnRef + '" table="Off" all="Fehlt" any="Fehlt teils" />' +
    '<ValueNotice name="OnlyAll" ref="%AID%_UP-%TT%00011_R-%TT%0001101" table="Off" all="Fehlt" /></ValueNotices>') -Envs
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.notices.gen.xml"))
  $blocks = @($f -split '<Block name="'); $fx = $blocks[1]; $ol = $blocks[2]
  $b4130 = $fx.Substring($fx.IndexOf('<when test="4130">'))
  Assert-True ($b4130.Contains('<when test="2"><ParameterSeparator Id="%AID%_PS-nnn" Text="Fehlt" UIHint="Error" />') -and $b4130.Contains('<when test="3"><ParameterSeparator Id="%AID%_PS-nnn" Text="Fehlt teils" UIHint="Information" />')) (T "Fx: 4130 with 2 Error and 3 Information missing")
  Assert-True ($fx.Contains('<when test="2 5"><ParameterSeparator Id="%AID%_PS-nnn" Text="Fehlt" UIHint="Error" />') -and -not $fx.Contains('4611')) (T "Fx: 4129 with 2 5 as Error missing")
  Assert-True (-not $ol.Contains('"3"') -and -not $ol.Contains('UIHint="Information"')) (T "OnlyAll: the any value 3 must give no notice")
} "pio"

Add-Test "valuenotices-errors" (T "ValueNotices: unknown table, bad ref, no text, twice the same name, too long a text stop") {
  $cases = @(
    @{ L = '<ValueNotice name="A" ref="' + $VnRef + '" table="off" all="x" />'; P = 'is no <BoardTable>' }
    @{ L = '<ValueNotice name="A" ref="UP-1_R-1" table="Off" all="x" />'; P = 'ref must be the ParameterRef' }
    @{ L = '<ValueNotice name="A" ref="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05801" table="Off" all="x" />'; P = 'ref must be the ParameterRef' }
    @{ L = '<ValueNotice name="A" ref="' + $VnRef + '" table="Off" />'; P = 'needs all=' }
    @{ L = '<ValueNotice name="A" ref="' + $VnRef + '" table="Off" all="x" /><ValueNotice name="A" ref="' + $VnRef + '" table="Off" all="y" />'; P = 'is listed twice' }
    @{ L = '<ValueNotice name="A_1" ref="' + $VnRef + '" table="Off" all="x" />'; P = 'name must be letters and digits' }
    @{ L = '<ValueNotice name="A" ref="' + $VnRef + '" table="Off" all="' + ("x" * 256) + '" />'; P = 'ETS shows at most 255' }
  )
  $i = 0
  foreach ($c in $cases) {
    $i++
    $d = Copy-BaseWithValueNotices ("valuenotices-err" + $i) ('<ValueNotices output="src/T.notices.gen.xml">' + $c.L + '</ValueNotices>')
    $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r ([regex]::Escape($c.P)) (T "case {0}" $i)
    Assert-True (-not (Test-Path -LiteralPath ([System.IO.Path]::Combine($d, "src", "T.notices.gen.xml")))) (T "case {0}: a parts file was written" $i)
  }
}

# @brief <PartRows> with <Fix>/<Filter> blocks: a foreign module file in lib/X/src (href to a sibling file), a Fix target in a grid
#        cell that is also a selected row, a Filter target with IndentLevel; manifest lines go after the board macros
function Copy-BaseWithForeignPart([string]$Name, [string]$Lines) {
  $items = @(0..4 | ForEach-Object { '            <Enumeration Text="E{0}" Value="{0}" Id="%ENID%" />' -f $_ })
  $d = Copy-BaseWithBoardMacros $Name $Lines
  $dir = [System.IO.Path]::Combine($d, "lib", "X", "src")
  [void][System.IO.Directory]::CreateDirectory($dir)
  Write-Text ([System.IO.Path]::Combine($dir, "M.part.xml")) ((@(
    '<?xml version="1.0" encoding="utf-8"?>'
    '<KNX xmlns:op="http://github.com/OpenKNX/OpenKNXproducer" xmlns="http://knx.org/xml/project/20">'
    '  <ManufacturerData><Manufacturer RefId="M-00FA"><ApplicationPrograms><ApplicationProgram>'
    '    <Static>'
    '      <ParameterTypes>'
    '        <ParameterType Id="%AID%_PT-MMode" Name="MMode">'
    '          <TypeRestriction Base="Value" SizeInBit="8" UIHint="DropDown">') + $items + @(
    '          </TypeRestriction>'
    '        </ParameterType>'
    '      </ParameterTypes>'
    '      <Parameters>'
    '        <Union SizeInBit="16">'
    '          <Memory CodeSegment="%AID%_RS-04-00000" Offset="0" BitOffset="0" />'
    '          <Parameter Id="%AID%_UP-%TT%00050" Name="MMode" ParameterType="%AID%_PT-MMode" Offset="0" BitOffset="0" Text="Modus" Value="1" />'
    '          <Parameter Id="%AID%_UP-%TT%00051" Name="MSet" ParameterType="%AID%_PT-MMode" Offset="1" BitOffset="0" Text="Wert" Value="0" />'
    '        </Union>'
    '      </Parameters>'
    '      <ParameterRefs>'
    '        <ParameterRef Id="%AID%_UP-%TT%00050_R-%TT%0005001" RefId="%AID%_UP-%TT%00050" />'
    '        <ParameterRef Id="%AID%_UP-%TT%00051_R-%TT%0005101" RefId="%AID%_UP-%TT%00051" />'
    '      </ParameterRefs>'
    '      <ParameterCalculations><ParameterCalculation Id="%AID%_PC-%TT%00001" Language="JavaScript" Name="C" LRTransformationFunc="f" RLTransformationFunc="g">'
    '        <LParameters><ParameterRefRef RefId="%AID%_UP-%TT%00051_R-%TT%0005101" AliasName="S" /></LParameters><RParameters /></ParameterCalculation></ParameterCalculations>'
    '    </Static>'
    '    <Dynamic><ChannelIndependentBlock>'
    '      <ParameterBlock Id="%AID%_PB-nnn" Name="Page" Text="Page">'
    '        <op:include href="Other.part.xml" xpath="//Block[@name=''X'']/*" />'
    '        <ParameterBlock Id="%AID%_PB-nnn" Inline="true" Layout="Grid">'
    '          <ParameterSeparator Id="%AID%_PS-nnn" Text="Wert" Cell="1,1" />'
    '          <ParameterRefRef RefId="%AID%_UP-%TT%00051_R-%TT%0005101" Cell="1,2" />'
    '        </ParameterBlock>'
    '        <ParameterRefRef RefId="%AID%_UP-%TT%00050_R-%TT%0005001" IndentLevel="2" />'
    '      </ParameterBlock>'
    '    </ChannelIndependentBlock></Dynamic>'
    '  </ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData>'
    '</KNX>')) -join "`n")
  return $d
}
$ForeignFix = '<Fixes output="src/T.fixes.gen.xml"><Fix name="MSet" capability="Lan" ref="%AID%_UP-%TT%00051_R-%TT%0005101" value="3" indent="1" /></Fixes>'
$ForeignFilter = '<Filters output="src/T.filters.gen.xml"><Filter name="MMode" ref="%AID%_UP-%TT%00050_R-%TT%0005001" source="lib/X/src/M.part.xml" number="700"><Allow board="DEVICE_UP1_TAS_4X" values="0 1" /></Filter></Filters>'

Add-Test "partrows-blocks" (T "PartRows: <Fix> and <Filter> blocks in a copy of a foreign file, also inside a selected row, layout of the source kept, hrefs rewritten") {
  $d = Copy-BaseWithForeignPart "partrows-blocks" ($ForeignFix + $ForeignFilter +
    '<PartRows source="lib/X/src/M.part.xml" output="src/M.copy.gen.xml"><Row ref="%AID%_UP-%TT%00051_R-%TT%0005101" expr="defined(DEVICE_REG1_LAN_TP_BASE) || defined(DEVICE_UP1_TAS_4X)" /><Fix name="MSet" /><Filter name="MMode" /></PartRows>' +
    '<PartRows source="lib/X/src/S.share.xml" output="src/S.copy.gen.xml" />')
  # a share of the same module that includes M.part.xml: its plain copy must include the copy of M.part.xml
  Write-Text ([System.IO.Path]::Combine($d, "lib", "X", "src", "S.share.xml")) ('<KNX xmlns:op="http://github.com/OpenKNX/OpenKNXproducer" xmlns="http://knx.org/xml/project/20"><Dynamic>' +
    '<op:include href="M.part.xml" xpath="//Dynamic/*" type="template" /><op:include href="Other.part.xml" xpath="//X/*" /></Dynamic></KNX>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $sc = Read-Text ([System.IO.Path]::Combine($d, "src", "S.copy.gen.xml"))
  Assert-True ($sc.Contains('<op:include href="M.copy.gen.xml"') -and $sc.Contains('<op:include href="../lib/X/src/Other.part.xml"')) (T "a copy that includes the source of another <PartRows> must point to its copy")
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "M.copy.gen.xml"))
  Assert-True ($f.Contains('<op:include href="../lib/X/src/Other.part.xml"')) (T "href of the copy not rewritten to ../lib/X/src/Other.part.xml")
  $x = New-Object System.Xml.XmlDocument; $x.LoadXml($f)
  $ns = New-Object System.Xml.XmlNamespaceManager($x.NameTable); $ns.AddNamespace("k", "http://knx.org/xml/project/20")
  $sel = "%AID%_UP-4500001_R-450000101"
  # the row: not selected + one group (4129 4611); in each, the Fix block: 4129 4130 fixed read-only, else the normal cell
  $row = $x.SelectSingleNode("//k:choose[@ParamRefId='$sel'][k:when/k:ParameterBlock[@Layout='Grid']]", $ns)
  Assert-True ($null -ne $row) (T "choose of the selected row missing")
  $rowWhens = @($row.SelectNodes("k:when", $ns))
  Assert-True ($rowWhens.Count -eq 2 -and $rowWhens[0].GetAttribute("test") -ceq "0" -and $rowWhens[1].GetAttribute("test") -ceq "4129 4611") (T "row whens: expected 0 and 4129 4611")
  foreach ($w in $rowWhens) {
    $fix = $w.SelectSingleNode("k:ParameterBlock/k:choose[@ParamRefId='$sel']", $ns)
    Assert-True ($null -ne $fix) (T "row when {0}: the Fix block is missing" $w.GetAttribute("test"))
    $fw = $fix.SelectSingleNode("k:when[@test='4129 4130']", $ns)
    Assert-True ($null -ne $fw -and $null -ne $fw.SelectSingleNode("k:Assign[@TargetParamRefRef='%AID%_UP-%TT%00051_R-%TT%0005101'][@Value='3']", $ns) -and $null -ne $fw.SelectSingleNode("k:ParameterRefRef[@RefId='%AID%_UP-%TT%00051_R-%TT%0005199'][@Cell='1,2']", $ns)) (T "Fix block: Assign 3 and the read-only cell 1,2 missing")
    Assert-True ($null -ne $fix.SelectSingleNode("k:when[@default='true']/k:ParameterRefRef[@RefId='%AID%_UP-%TT%00051_R-%TT%0005101'][@Cell='1,2']", $ns)) (T "Fix block: the normal cell 1,2 for the other boards missing")
  }
  Assert-True ($x.SelectNodes("//k:ParameterBlock[@Layout='Grid']/k:ParameterRefRef[@RefId='%AID%_UP-%TT%00051_R-%TT%0005101']", $ns).Count -eq 0) (T "the replaced ParameterRefRef is still there")
  Assert-True ($null -ne $x.SelectSingleNode("//k:LParameters/k:ParameterRefRef[@RefId='%AID%_UP-%TT%00051_R-%TT%0005101'][@AliasName='S']", $ns) -and $x.SelectNodes("//k:LParameters//k:choose", $ns).Count -eq 0) (T "the ParameterRefRef of a calculation must stay untouched")
  Assert-True ($x.SelectNodes("//k:ParameterBlock[@Layout='Grid']//k:ParameterRefRef[@IndentLevel]", $ns).Count -eq 0) (T "a grid cell without IndentLevel must not get the indent of the Fix")
  # the Filter: carrier for not selected and the full-list boards, own list for 4611, IndentLevel 2 of the source
  $flt = @($x.SelectNodes("//k:choose[@ParamRefId='$sel'][k:when/k:ParameterRefRef[@RefId='%AID%_UP-%TT%00050_R-%TT%0005001']]", $ns))
  Assert-True ($flt.Count -eq 1) (T "Filter block missing in place of the carrier")
  Assert-True ($null -ne $flt[0].SelectSingleNode("k:when[@test='4611']/k:ParameterRefRef[@RefId='%AID%_P-%TT%00700_R-%TT%0070001'][@IndentLevel='2']", $ns)) (T "Filter block: own list of 4611 with IndentLevel 2 missing")
  Assert-True ($null -ne $flt[0].SelectSingleNode("k:when[@test='4611']/k:Assign[@TargetParamRefRef='%AID%_UP-%TT%00050_R-%TT%0005001']", $ns)) (T "Filter block: copy into the carrier missing")
  # Static of the copy: the read-only ref of the Fix and the own list of the Filter with its ref, once each
  Assert-True ($x.SelectNodes("//k:Static/k:ParameterRefs/k:ParameterRef[@Id='%AID%_UP-%TT%00051_R-%TT%0005199'][@Access='Read']", $ns).Count -eq 1) (T "Static: read-only ref of the Fix missing or twice")
  Assert-True ($x.SelectNodes("//k:Static/k:Parameters/k:Parameter[@Id='%AID%_P-%TT%00700']", $ns).Count -eq 1 -and $x.SelectNodes("//k:Static/k:ParameterRefs/k:ParameterRef[@Id='%AID%_P-%TT%00700_R-%TT%0070001']", $ns).Count -eq 1) (T "Static: own list of the Filter or its ref missing or twice")
  Assert-True ($x.SelectNodes("//k:ParameterType", $ns).Count -eq 1) (T "Static: the copy must not take the filter types (the product includes them once)")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
  # the source takes the parameters of the Filter itself: the copy must not insert them a second time
  $d = Copy-BaseWithForeignPart "partrows-blocks-incl" ($ForeignFix + $ForeignFilter + '<PartRows source="lib/X/src/M.part.xml" output="src/M.copy.gen.xml"><Filter name="MMode" /></PartRows>')
  Edit-File ([System.IO.Path]::Combine($d, "lib", "X", "src", "M.part.xml")) '      <Parameters>' "      <Parameters>`n        <op:include href=`"../../../src/T.filters.gen.xml`" xpath='//Block[@name=`"Filter_MMode_Parameters`"]/*' />"
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "M.copy.gen.xml"))
  Assert-True (-not $f.Contains('<Parameter Id="%AID%_P-%TT%00700"') -and $f.Contains('<ParameterRef Id="%AID%_P-%TT%00700_R-%TT%0070001"')) (T "a block the source includes itself must not be inserted again (the other one must)")
  $d = Copy-BaseWithForeignPart "partrows-blocks-twice" ($ForeignFix + '<PartRows source="lib/X/src/M.part.xml" output="src/M.copy.gen.xml"><Fix name="MSet" /></PartRows><PartRows source="lib/X/src/M.part.xml" output="src/M2.copy.gen.xml" />')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'is used twice - put all rows' (T "stop message")
  # errors: unknown name, show="assign", a ref the source does not have
  $d = Copy-BaseWithForeignPart "partrows-blocks-name" ($ForeignFix + '<PartRows source="lib/X/src/M.part.xml" output="src/M.copy.gen.xml"><Fix name="Nope" /></PartRows>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'no <Fix> with this name' (T "stop message")
  $d = Copy-BaseWithForeignPart "partrows-blocks-assign" ($ForeignFix.Replace('value="3" indent="1" />', 'value="3" indent="1" show="assign" />') + '<PartRows source="lib/X/src/M.part.xml" output="src/M.copy.gen.xml"><Fix name="MSet" /></PartRows>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'no row to replace' (T "stop message")
  $d = Copy-BaseWithForeignPart "partrows-blocks-noref" ($ForeignFix.Replace('00051_R-%TT%0005101', '00052_R-%TT%0005201') + '<PartRows source="lib/X/src/M.part.xml" output="src/M.copy.gen.xml"><Fix name="MSet" /></PartRows>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'the source has no ParameterRefRef' (T "stop message")
}

Add-Test "partrows-channelcount" (T "PartRows: %N% of a copy comes from the NumChannels of the op:define that names the source, none stops") {
  $d = Copy-BaseWithForeignPart "partrows-n" '<PartRows source="lib/X/src/S.share.xml" output="src/S.copy.gen.xml" />'
  Write-Text ([System.IO.Path]::Combine($d, "lib", "X", "src", "S.share.xml")) ('<KNX xmlns:op="http://github.com/OpenKNX/OpenKNXproducer" xmlns="http://knx.org/xml/project/20"><Dynamic>' +
    '<choose ParamRefId="%AID%_UP-%TT%00001_R-%TT%0000101"><when test="&lt;%N%"><ParameterSeparator Id="%AID%_PS-nnn" Text="%N-1% von %N%" /></when></choose></Dynamic></KNX>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'no op:define of a product XML names this file' (T "stop message")
  Edit-File ([System.IO.Path]::Combine($d, "src", "T.xml")) '</KNX>' '  <op:define prefix="X" ModuleType="47" share="../lib/X/src/S.share.xml" NumChannels="6" />
</KNX>'
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "S.copy.gen.xml"))
  Assert-True ($f.Contains('test="&lt;6"') -and $f.Contains('Text="5 von 6"') -and -not $f.Contains('%N')) (T "%N% and %N-1% of the copy must be 6 and 5")
  # a second product XML (Release next to Dev): same NumChannels is fine, another one stops
  $second = '<?xml version="1.0" encoding="utf-8"?><KNX xmlns:op="http://github.com/OpenKNX/OpenKNXproducer" xmlns="http://knx.org/xml/project/20"><op:ETS OpenKnxId="0xAD" ApplicationNumber="251" ApplicationVersion="1.0" ReplacesVersionsDownTo="0.1" ProductName="Selftest 2" /><op:define prefix="TST" ModuleType="45" share="T.share.xml" /><op:define prefix="X" ModuleType="47" share="../lib/X/src/S.share.xml" NumChannels="{0}" /></KNX>'
  Write-Text ([System.IO.Path]::Combine($d, "src", "T2.xml")) ($second -f 6)
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  Write-Text ([System.IO.Path]::Combine($d, "src", "T2.xml")) ($second -f 8)
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'give different NumChannels \(6, 8\)' (T "stop message")
  # the copy itself is the template of a define: the producer replaces %N% there, the copy keeps it
  Write-Text ([System.IO.Path]::Combine($d, "src", "T2.xml")) ($second -f 6).Replace('share="../lib/X/src/S.share.xml" NumChannels="6"', 'template="S.copy.gen.xml" NumChannels="4"')
  Edit-File ([System.IO.Path]::Combine($d, "src", "T.xml")) '  <op:define prefix="X" ModuleType="47" share="../lib/X/src/S.share.xml" NumChannels="6" />' ''
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "S.copy.gen.xml"))
  Assert-True ($f.Contains('test="&lt;%N%"') -and $f.Contains('Text="%N-1% von %N%"')) (T "a copy that is itself a template must keep %N% for the producer")
  # the same with the copy as share=
  Write-Text ([System.IO.Path]::Combine($d, "src", "T2.xml")) ($second -f 6).Replace('share="../lib/X/src/S.share.xml" NumChannels="6"', 'share="S.copy.gen.xml" NumChannels="4"')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  Assert-True ((Read-Text ([System.IO.Path]::Combine($d, "src", "S.copy.gen.xml"))).Contains('test="&lt;%N%"')) (T "a copy that is itself a share must keep %N% for the producer")
}

Add-Test "partrows-count" (T "PartRows: <Row count> shows channel n only while the value of the board is at least n, count parameter in the hardware module") {
  $d = Copy-BaseWithBoardMacros "partrows-count" ($RowsSrc + '<Row ref="%AID%_UP-%TT%00020_R-%TT%0002001" count="BinaryInputs" />' +
    '<Row ref="%AID%_UP-%TT%00021_R-%TT%0002101" expr="defined(DEVICE_UP1_TAS_4X)" count="BinaryInputs" /></PartRows>')
  # %C% exists only in a channel template: without an op:define that takes the source or the copy as template= it stops
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'needs a channel template' (T "stop message")
  Edit-File ([System.IO.Path]::Combine($d, "src", "T.xml")) '</KNX>' '  <op:define prefix="P" ModuleType="47" share="T.share.xml" template="T.rows.gen.xml" NumChannels="3" />
</KNX>'
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $sh = Read-Text ([System.IO.Path]::Combine($d, "src", "T.share.xml"))
  $mt = [regex]::Match($sh, '<Parameter Id="%AID%_P-%TT%(003\d\d)" Name="BinaryInputsCount" ParameterType="%AID%_PT-TSTCount" Text="BinaryInputs" Access="None" Value="255" />')
  Assert-True $mt.Success (T "count parameter BinaryInputsCount (number 300 + value index, Access None, 255) missing")
  $num = $mt.Groups[1].Value
  $cref = "%AID%_P-%TT%{0}_R-%TT%{0}01" -f $num
  $x = New-Object System.Xml.XmlDocument; $x.LoadXml($sh)
  $ns = New-Object System.Xml.XmlNamespaceManager($x.NameTable); $ns.AddNamespace("k", "http://knx.org/xml/project/20")
  $ch = $x.SelectSingleNode("//k:choose[k:when/k:Assign[@TargetParamRefRef='$cref']]", $ns)
  Assert-True ($null -ne $ch -and $null -ne $ch.SelectSingleNode("k:when[@test='0']/k:Assign[@Value='255']", $ns)) (T "count parameter: not selected must assign 255")
  foreach ($id in @(4129, 4130, 4611)) {
    $hits = @($ch.SelectNodes("k:when", $ns) | Where-Object { @($_.GetAttribute("test") -split ' ') -contains [string]$id })
    Assert-True ($hits.Count -eq 1) (T "count parameter: board {0} must be in exactly one when, found {1}" $id $hits.Count)
  }
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.rows.gen.xml"))
  $y = New-Object System.Xml.XmlDocument; $y.LoadXml($f)
  $ns2 = New-Object System.Xml.XmlNamespaceManager($y.NameTable); $ns2.AddNamespace("k", "http://knx.org/xml/project/20")
  $dref = "%AID%_P-45{0}_R-45{0}01" -f $num
  $cc = @($y.SelectNodes("//k:choose[@ParamRefId='$dref']", $ns2))
  Assert-True ($cc.Count -eq 2) (T "copy: expected 2 chooses on the count parameter (module digits), found {0}" $cc.Count)
  Assert-True ($null -ne $cc[0].SelectSingleNode("k:when[@test='>=%C%']/k:ParameterBlock[k:ParameterRefRef[@RefId='%AID%_UP-%TT%00020_R-%TT%0002001']]", $ns2)) (T "copy: row A (count only) must sit directly in when >=%C%")
  Assert-True ($null -ne $cc[1].SelectSingleNode("k:when[@test='>=%C%']/k:choose[@ParamRefId='%AID%_UP-4500001_R-450000101']/k:when[@test='4611']", $ns2)) (T "copy: row B (expr and count) must keep its choose on the selection inside when >=%C%")
  Assert-True ($f.Contains('test="&gt;=%C%"')) (T "copy: the test must be written as &gt;=%C%")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
  $d = Copy-BaseWithBoardMacros "partrows-count-bad" ($RowsSrc + '<Row ref="%AID%_UP-%TT%00020_R-%TT%0002001" count="Nope" /></PartRows>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'is no <Value> of the manifest' (T "stop message")
}

Add-Test "partrows-tokens" (T "PartRows: a row with tokens of a channel template and a part") {
  $tr = '%AID%_UP-%TT%%CC%%PPP+2%_R-%TT%%CC%%PPP+2%01'
  $d = Copy-BaseWithBoardMacros "partrows-tokens" ($RowsSrc + '<Row ref="' + $tr + '" expr="defined(DEVICE_UP1_TAS_4X)" /></PartRows>')
  Edit-File ([System.IO.Path]::Combine($d, "src", "P.part.xml")) '%AID%_UP-%TT%00021_R-%TT%0002101' $tr
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.rows.gen.xml"))
  Assert-True ($f -match '<when test="4611">\s*<ParameterBlock[^>]*>\s*<ParameterSeparator[^>]*Text="Row B"[^>]*/>\s*<ParameterRefRef RefId="%AID%_UP-%TT%%CC%%PPP\+2%_R-%TT%%CC%%PPP\+2%01"') (T "row with tokens: board 4611 row missing")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
}

Add-Test "partrows-twohits" (T "PartRows: a selection with two rows stops") {
  $d = Copy-BaseWithBoardMacros "partrows-twohits" ($RowsSrc + '<Row ref="%AID%_P-%TT%00030_R-%TT%0003001" expr="1" /></PartRows>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'has 2 ParameterRefRef with this RefId' (T "stop message")
}

Add-Test "partrows-notrow" (T "PartRows: a ParameterRefRef outside an inline block stops") {
  $d = Copy-BaseWithBoardMacros "partrows-notrow" ($RowsSrc + '<Row ref="%AID%_P-%TT%00040_R-%TT%0004001" expr="1" /></PartRows>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'not a direct child of an inline ParameterBlock' (T "stop message")
}

Add-Test "fixes-macro" (T "Fixes: value from a board macro, board without the macro has no fix") {
  $d = Copy-BaseWithBoardMacros "fixes-macro" ('<Fixes output="src/T.fixes.gen.xml">' +
    '<Fix name="M" ref="%AID%_UP-1000020_R-100002001" valueMacro="TST_FIXV" show="assign" />' +
    '<Fix name="N" ref="%AID%_UP-1000021_R-100002101" valueMacro="TST_NONE" show="editable" /></Fixes>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.fixes.gen.xml"))
  $m = $f.Substring($f.IndexOf('<Block name="Fix_M">')); $m = $m.Substring(0, $m.IndexOf('</Block>'))
  $n = $f.Substring($f.IndexOf('<Block name="Fix_N">')); $n = $n.Substring(0, $n.IndexOf('</Block>'))
  Assert-True ($m -match '<when test="4129">\s*<Assign TargetParamRefRef="%AID%_UP-1000020_R-100002001" Value="3" />\s*</when>') (T "value 3 of board 4129 missing")
  Assert-True ($m -match '<when test="4611">\s*<Assign TargetParamRefRef="%AID%_UP-1000020_R-100002001" Value="7" />\s*</when>') (T "value 7 of board 4611 missing")
  Assert-True (-not $m.Contains('4130') -and -not $m.Contains('default') -and -not $m.Contains('ParameterRefRef')) (T "Fix_M: board 4130 without the macro, a default or a row in the block")
  Assert-True ($n -match '^<Block name="Fix_N">\s*<ParameterRefRef RefId="%AID%_UP-1000021_R-100002101" />\s*$') (T "Fix_N: a macro on no board must leave the normal row only")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
}

# @brief <Filters> test project: a dropdown 0..6 (carrier UP-%TT%00060 in a union of src/F.share.xml) and the given <Filters>
function Copy-BaseWithFilter([string]$Name, [string]$Filters, [switch]$NoUnion) {
  $d = Copy-Base $Name
  $items = @(0..6 | ForEach-Object { '          <Enumeration Text="M{0}" Value="{0}" Id="%ENID%" />' -f $_ })
  $par = '<Parameter Id="%AID%_UP-%TT%00060" Name="Mode" ParameterType="%AID%_PT-Mode" Offset="0" BitOffset="0" Text="Modus" Value="4" />'
  if ($NoUnion) { $mem = @(('      ' + $par)) } else { $mem = @('      <Union SizeInBit="8">', '        <Memory CodeSegment="%AID%_RS-04-00000" Offset="0" BitOffset="0" />', ('        ' + $par), '      </Union>') }
  # a second parameter of the same type and a parameter without memory (P-%TT%00070) of another type
  $mem += @('      <Parameter Id="%AID%_P-%TT%00061" Name="Mode2" ParameterType="%AID%_PT-Mode" Text="Modus 2" Value="0" />',
            '      <Parameter Id="%AID%_P-%TT%00070" Name="Other" ParameterType="%AID%_PT-Other" Text="Andere" Value="0" />')
  $items += @('        </TypeRestriction>', '      </ParameterType>', '      <ParameterType Id="%AID%_PT-Other" Name="Other">', '        <TypeRestriction Base="Value" SizeInBit="8">',
              '          <Enumeration Text="O0" Value="0" Id="%ENID%" />', '          <Enumeration Text="O1" Value="1" Id="%ENID%" />', '          <Enumeration Text="O2" Value="2" Id="%ENID%" />')
  Write-Text ([System.IO.Path]::Combine($d, "src", "F.share.xml")) ((@(
    '<?xml version="1.0" encoding="utf-8"?>'
    '<KNX xmlns="http://knx.org/xml/project/20"><ManufacturerData><Manufacturer><ApplicationPrograms><ApplicationProgram><Static>'
    '  <ParameterTypes>'
    '    <ParameterType Id="%AID%_PT-Mode" Name="Mode">'
    '      <TypeRestriction Base="Value" SizeInBit="8" UIHint="DropDown">') + $items + @(
    '      </TypeRestriction>'
    '    </ParameterType>'
    '  </ParameterTypes>'
    '  <Parameters>') + $mem + @(
    '  </Parameters>'
    '  <ParameterRefs>'
    '    <ParameterRef Id="%AID%_UP-%TT%00060_R-%TT%0006001" RefId="%AID%_UP-%TT%00060" />'
    '    <ParameterRef Id="%AID%_P-%TT%00061_R-%TT%0006101" RefId="%AID%_P-%TT%00061" />'
    '    <ParameterRef Id="%AID%_P-%TT%00070_R-%TT%0007001" RefId="%AID%_P-%TT%00070" />'
    '  </ParameterRefs>'
    '</Static></ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData></KNX>')) -join "`n")
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ($Filters + "`n</HardwareProfile>")
  return $d
}

# @brief <Filters> on a channel template: carrier %AID%_UP-%TT%%CC%057 (two ParameterRefs, 02 read-only) in src/C.templ.xml,
#        its type in src/C.share.xml, the 2D values in src/two.values; a part parameter %AID%_UP-%TT%%CC%%PPP+0% as second filter
function Copy-BaseWithTemplFilter([string]$Name, [string]$Filters) {
  $d = Copy-Base $Name
  $items = @(0..5 | ForEach-Object { '        <Enumeration Text="E{0}" Value="{0}" Id="%ENID%" />' -f $_ })
  $items2 = @(0..5 | ForEach-Object { '        <Enumeration Text="S{0}" Value="{0}" Id="%ENID%" />' -f $_ }) + @('        <Enumeration Text="EM" Value="200" Id="%ENID%" />')
  Write-Text ([System.IO.Path]::Combine($d, "src", "C.share.xml")) ((@(
    '<?xml version="1.0" encoding="utf-8"?>'
    '<KNX xmlns="http://knx.org/xml/project/20"><ManufacturerData><Manufacturer><ApplicationPrograms><ApplicationProgram><Static><ParameterTypes>'
    '    <ParameterType Id="%AID%_PT-Fx" Name="Fx">'
    '      <TypeRestriction Base="Value" SizeInBit="8" UIHint="DropDown">') + $items + @(
    '      </TypeRestriction>'
    '    </ParameterType>'
    '    <ParameterType Id="%AID%_PT-SceneFx" Name="SceneFx">'
    '      <TypeRestriction Base="Value" SizeInBit="8">') + $items2 + @(
    '      </TypeRestriction>'
    '    </ParameterType>'
    '</ParameterTypes></Static></ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData></KNX>')) -join "`n")
  Write-Text ([System.IO.Path]::Combine($d, "src", "C.templ.xml")) ((@(
    '<?xml version="1.0" encoding="utf-8"?>'
    '<KNX xmlns="http://knx.org/xml/project/20"><ManufacturerData><Manufacturer><ApplicationPrograms><ApplicationProgram><Static>'
    '  <Parameters>'
    '    <Parameter Id="%AID%_UP-%TT%%CC%057" Offset="11" BitOffset="0" Name="CH%C%Fx" ParameterType="%AID%_PT-Fx" Text="Effekt" Value="2" />'
    '    <Parameter Id="%AID%_UP-%TT%%CC%%PPP+0%" Offset="%MO%" BitOffset="0" Name="CH%C%Scene%SN%Fx" ParameterType="%AID%_PT-SceneFx" Text="Effekt" Value="0" />'
    '  </Parameters>'
    '  <ParameterRefs>'
    '    <ParameterRef Id="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05701" RefId="%AID%_UP-%TT%%CC%057" />'
    '    <ParameterRef Id="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05702" RefId="%AID%_UP-%TT%%CC%057" Access="Read" />'
    '    <ParameterRef Id="%AID%_UP-%TT%%CC%%PPP+0%_R-%TT%%CC%%PPP+0%01" RefId="%AID%_UP-%TT%%CC%%PPP+0%" />'
    '  </ParameterRefs>'
    '</Static></ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData></KNX>')) -join "`n")
  Write-Text ([System.IO.Path]::Combine($d, "src", "two.values")) "# 2D effects`n3`n4-5`n"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' ($Filters + "`n</HardwareProfile>")
  return $d
}

Add-Test "filters-template" (T "Filters: carrier in a channel template and a part (tokens), mirrored refs, a row of a concrete channel, except from a file") {
  $d = Copy-BaseWithTemplFilter "filters-template" ('<Filters output="src/T.filters.gen.xml">' +
    '<Filter name="Fx" ref="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05701" source="src/C.templ.xml src/C.share.xml" number="058" help="FX-Help">' +
    '<Allow board="DEVICE_UP1_TAS_4X" except="@src/two.values" /><Row name="Ov1" ref="%AID%_UP-%TT%01057_R-%TT%0105702" cell="2,4" /></Filter>' +
    '<Filter name="SceneFx" ref="%AID%_UP-%TT%%CC%%PPP+0%_R-%TT%%CC%%PPP+0%01" source="src/C.templ.xml src/C.share.xml" number="%PPP+19%">' +
    '<Allow board="DEVICE_UP1_TAS_4X" except="@src/two.values" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.filters.gen.xml"))
  Assert-True ($f.Contains('<Parameter Id="%AID%_P-%TT%%CC%058" Name="CH%C%FxF0" ParameterType="%AID%_PT-FxF0" Text="Effekt" Value="2" />')) (T "template parameter %CC%058 (tokens kept, default 2 of the carrier) missing")
  Assert-True ($f.Contains('<ParameterRef Id="%AID%_P-%TT%%CC%058_R-%TT%%CC%05801" RefId="%AID%_P-%TT%%CC%058" />') -and $f.Contains('<ParameterRef Id="%AID%_P-%TT%%CC%058_R-%TT%%CC%05802" RefId="%AID%_P-%TT%%CC%058" Access="Read" />')) (T "both ParameterRefs of the carrier (01, 02 read-only) must be mirrored")
  $t0 = $f.Substring($f.IndexOf('<ParameterType Id="%AID%_PT-FxF0"')); $t0 = $t0.Substring(0, $t0.IndexOf('</ParameterType>'))
  Assert-True (([regex]::Matches($t0, '<Enumeration ')).Count -eq 3 -and -not $t0.Contains('Value="3"') -and -not $t0.Contains('Value="4"') -and -not $t0.Contains('Value="5"')) (T "except from the file: values 3 4 5 must be left out")
  Assert-True ($f -match '<when test="4611">\s*<ParameterRefRef RefId="%AID%_P-%TT%%CC%058_R-%TT%%CC%05801" IndentLevel="1" HelpContext="FX-Help" />\s*<Assign TargetParamRefRef="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05701" SourceParamRefRef="%AID%_P-%TT%%CC%058_R-%TT%%CC%05801" />') (T "main row: own list with help and copy into the carrier missing")
  $ov = $f.Substring($f.IndexOf('<Block name="Filter_Fx_Ov1">')); $ov = $ov.Substring(0, $ov.IndexOf('</Block>'))
  Assert-True ($ov.Contains('<ParameterRefRef RefId="%AID%_UP-%TT%01057_R-%TT%0105702" Cell="2,4" />') -and $ov.Contains('<ParameterRefRef RefId="%AID%_P-%TT%01058_R-%TT%0105802" Cell="2,4" />')) (T "row Ov1: carrier and own list of channel 01 with the read-only suffix 02 missing")
  Assert-True ($ov.Contains('<Assign TargetParamRefRef="%AID%_P-%TT%01058_R-%TT%0105802" SourceParamRefRef="%AID%_P-%TT%01058_R-%TT%0105801" />') -and $ov.Contains('<Assign TargetParamRefRef="%AID%_UP-%TT%01057_R-%TT%0105701" SourceParamRefRef="%AID%_P-%TT%01058_R-%TT%0105801" />')) (T "row Ov1: the read-only ref and the carrier must follow the list")
  Assert-True ($f.Contains('<Parameter Id="%AID%_P-%TT%%CC%%PPP+19%" Name="CH%C%Scene%SN%FxF0"') -and $f.Contains('<ParameterRef Id="%AID%_P-%TT%%CC%%PPP+19%_R-%TT%%CC%%PPP+19%01" RefId="%AID%_P-%TT%%CC%%PPP+19%" />')) (T "part parameter %PPP+19% missing")
  $s0 = $f.Substring($f.IndexOf('<ParameterType Id="%AID%_PT-SceneFxF0"')); $s0 = $s0.Substring(0, $s0.IndexOf('</ParameterType>'))
  Assert-True ($s0.Contains('Value="200"') -and -not $s0.Contains('Value="4"')) (T "part list: 200 must stay, the 2D values must go")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
  $d = Copy-BaseWithTemplFilter "filters-badrow" ('<Filters output="src/T.filters.gen.xml">' +
    '<Filter name="Fx" ref="%AID%_UP-%TT%%CC%057_R-%TT%%CC%05701" source="src/C.templ.xml src/C.share.xml" number="058">' +
    '<Allow board="DEVICE_UP1_TAS_4X" values="0 1" /><Row name="Ov1" ref="%AID%_UP-%TT%01057_R-%TT%0105703" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'is no ParameterRef of the filtered parameter' (T "stop message")
  $d = Copy-BaseWithTemplFilter "filters-slots" ('<Filters output="src/T.filters.gen.xml">' +
    '<Filter name="SceneFx" ref="%AID%_UP-%TT%%CC%%PPP+0%_R-%TT%%CC%%PPP+0%01" source="src/C.templ.xml src/C.share.xml" number="%PPP+19%">' +
    '<Allow board="DEVICE_UP1_TAS_4X" values="0 1" /><Allow board="DEVICE_REG1_LAN_BASE" values="0 2" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'leaves room for 1 list' (T "stop message")
  $d = Copy-BaseWithTemplFilter "filters-badnum" ('<Filters output="src/T.filters.gen.xml">' +
    '<Filter name="SceneFx" ref="%AID%_UP-%TT%%CC%%PPP+0%_R-%TT%%CC%%PPP+0%01" source="src/C.templ.xml src/C.share.xml" number="900">' +
    '<Allow board="DEVICE_UP1_TAS_4X" values="0 1" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'must be a token too' (T "stop message")
}
$FilterRef = '<Filter name="Mode" ref="%AID%_UP-%TT%00060_R-%TT%0006001" source="src/F.share.xml" number="700">'

Add-Test "filters-sets" (T "Filters: value set per board (first matching define, pattern, capability), item texts, carrier, stable slots") {
  $d = Copy-BaseWithFilter "filters-sets" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef +
    '<Allow board="DEVICE_REG1_LAN_TP_BASE" values="2 4" /><Allow board="DEVICE_REG1_LAN_*" values="1 5-6" /><Allow capability="Tp" values="0-6" /><Allow board="*" values="3" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.filters.gen.xml"))
  $t0 = $f.Substring($f.IndexOf('<ParameterType Id="%AID%_PT-ModeF0"')); $t0 = $t0.Substring(0, $t0.IndexOf('</ParameterType>'))
  $t1 = $f.Substring($f.IndexOf('<ParameterType Id="%AID%_PT-ModeF1"')); $t1 = $t1.Substring(0, $t1.IndexOf('</ParameterType>'))
  Assert-True (([regex]::Matches($t0, '<Enumeration ')).Count -eq 2 -and $t0.Contains('Text="M2" Value="2"') -and $t0.Contains('Text="M4" Value="4"')) (T "set 2 4 of board 4129 (exact define) missing")
  Assert-True (([regex]::Matches($t1, '<Enumeration ')).Count -eq 3 -and $t1.Contains('Text="M1"') -and $t1.Contains('Text="M5"') -and $t1.Contains('Text="M6"')) (T "set 1 5 6 of board 4130 (pattern) missing")
  Assert-True (-not $f.Contains('PT-ModeF2')) (T "board 4611 (capability, every value) must show the carrier, not an own list")
  Assert-True ($f.Contains('<Parameter Id="%AID%_P-%TT%00700" Name="ModeF0" ParameterType="%AID%_PT-ModeF0" Text="Modus" Value="4" />')) (T "parameter of slot 0 (number 700, no memory, carrier default 4) missing")
  Assert-True ($f.Contains('<Parameter Id="%AID%_P-%TT%00701" Name="ModeF1" ParameterType="%AID%_PT-ModeF1" Text="Modus" Value="1" />')) (T "parameter of slot 1 must default to its first value 1")
  Assert-True ($f -match '<when test="0 4611">\s*<ParameterRefRef RefId="%AID%_UP-%TT%00060_R-%TT%0006001" IndentLevel="1" />') (T "not selected and board 4611: the carrier row missing")
  Assert-True ($f -match '<when test="4129">\s*<ParameterRefRef RefId="%AID%_P-%TT%00700_R-%TT%0070001" IndentLevel="1" />\s*<Assign TargetParamRefRef="%AID%_UP-%TT%00060_R-%TT%0006001" SourceParamRefRef="%AID%_P-%TT%00700_R-%TT%0070001" />') (T "board 4129: own list with copy into the carrier missing")
  $slots = Read-Text ([System.IO.Path]::Combine($d, "HardwareProfile.slots"))
  Assert-True ($slots.Contains("filter Mode board:DEVICE_REG1_LAN_TP_BASE = 0") -and $slots.Contains("filter Mode board:DEVICE_REG1_LAN_* = 1")) (T "slot lines of the rules missing")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
  # another list for the same rule keeps its slot and id; a new rule takes the next slot
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'values="1 5-6"' 'values="1 5"'
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '<Allow capability="Tp"' '<Allow board="DEVICE_UP1_TAS_4X" values="0 6" /><Allow capability="Tp"'
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $slots = Read-Text ([System.IO.Path]::Combine($d, "HardwareProfile.slots"))
  Assert-True ($slots.Contains("filter Mode board:DEVICE_REG1_LAN_TP_BASE = 0") -and $slots.Contains("filter Mode board:DEVICE_REG1_LAN_* = 1") -and $slots.Contains("filter Mode board:DEVICE_UP1_TAS_4X = 2")) (T "a changed list must keep the slot of its rule, a new rule must take the next slot")
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.filters.gen.xml"))
  $t1 = $f.Substring($f.IndexOf('<ParameterType Id="%AID%_PT-ModeF1"')); $t1 = $t1.Substring(0, $t1.IndexOf('</ParameterType>'))
  Assert-True ($f.Contains('%AID%_P-%TT%00702"') -and $f.Contains('%AID%_P-%TT%00701"') -and ([regex]::Matches($t1, '<Enumeration ')).Count -eq 2) (T "parameter numbers must follow the slots of the rules (701 keeps its id with the new list 1 5, 702 new)")
}

Add-Test "filters-single" (T "Filters: a set with one value is read-only and assigned") {
  $d = Copy-BaseWithFilter "filters-single" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef + '<Allow board="DEVICE_UP1_TAS_4X" values="3" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.filters.gen.xml"))
  Assert-True ($f.Contains('<ParameterRef Id="%AID%_P-%TT%00700_R-%TT%0070001" RefId="%AID%_P-%TT%00700" Access="Read" />')) (T "the one-value list must be read-only")
  Assert-True ($f -match '<when test="4611">\s*<ParameterRefRef RefId="%AID%_P-%TT%00700_R-%TT%0070001" IndentLevel="1" />\s*<Assign TargetParamRefRef="%AID%_P-%TT%00700_R-%TT%0070001" Value="3" />\s*<Assign TargetParamRefRef="%AID%_UP-%TT%00060_R-%TT%0006001" SourceParamRefRef="%AID%_P-%TT%00700_R-%TT%0070001" />') (T "board 4611: value 3 assigned and copied into the carrier")
}

Add-Test "filters-ids" (T "Filters: same type, overlapping numbers, a number of the source or a name twice stops") {
  $two = '<Filter name="Mode2" ref="%AID%_P-%TT%00061_R-%TT%0006101" source="src/F.share.xml" number="701"><Allow board="DEVICE_UP1_TAS_4X" values="1" /></Filter>'
  $d = Copy-BaseWithFilter "filters-sametype" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef + '<Allow board="DEVICE_UP1_TAS_4X" values="2" /></Filter>' + $two + '</Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'give each filtered parameter its own ParameterType' (T "stop message")
  $other = '<Filter name="Other" ref="%AID%_P-%TT%00070_R-%TT%0007001" source="src/F.share.xml" number="701"><Allow board="DEVICE_UP1_TAS_4X" values="1" /></Filter>'
  $d = Copy-BaseWithFilter "filters-overlap" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef + '<Allow board="DEVICE_UP1_TAS_4X" values="2" /><Allow board="DEVICE_REG1_LAN_BASE" values="3" /></Filter>' + $other + '</Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'move number so the ranges do not overlap' (T "stop message")
  $d = Copy-BaseWithFilter "filters-srcid" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef.Replace('number="700"', 'number="70"') + '<Allow board="DEVICE_UP1_TAS_4X" values="2" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'choose a free number' (T "stop message")
  $d = Copy-BaseWithFilter "filters-case" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef + '<Allow board="DEVICE_UP1_TAS_4X" values="2" /></Filter>' + $other.Replace('name="Other"', 'name="mode"') + '</Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'is listed twice' (T "stop message")
}

Add-Test "filters-errors" (T "Filters: a value outside the list or a ref without parameter in the source stops") {
  $d = Copy-BaseWithFilter "filters-badvalue" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef + '<Allow board="DEVICE_UP1_TAS_4X" values="2 9" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'names value 9' (T "stop message")
  $d = Copy-BaseWithFilter "filters-noparam" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef.Replace('00060', '00061') + '<Allow board="DEVICE_UP1_TAS_4X" values="2" /></Filter></Filters>') -NoUnion
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'has 0 Parameter with Id' (T "stop message")
}

Add-Test "filters-rules" (T "Filters: rule keys ignore case, an orphan rule warns, a blank in a pattern, an old slot line, slots on a token number, %X% = %X+0%, a conflict flag id stop") {
  # a rule written in other case keeps its slot and its boards
  $d = Copy-BaseWithFilter "filters-rulecase" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef + '<Allow board="DEVICE_UP1_TAS_4X" values="2" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'board="DEVICE_UP1_TAS_4X"' 'board="Device_Up1_Tas_4x"'
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.filters.gen.xml"))
  Assert-True ($f -match '<when test="4611">\s*<ParameterRefRef RefId="%AID%_P-%TT%00700_R-%TT%0070001" IndentLevel="1" />') (T "a rule in other case must keep its slot and its boards")
  # a rule that now gives the full list still matches its boards: no orphan warning, the slot stays
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'values="2"' 'values="0-6"'
  $r = Invoke-Generator $d @(); Assert-Exit $r 0; Assert-NoOut $r 'match no board' (T "a rule with the full list is no orphan")
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'values="0-6"' 'values="2"'
  # an edited rule: the old line matches no board (warning); a digit number has room for the new slot
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'board="Device_Up1_Tas_4x"' 'board="DEVICE_REG1_LAN_BASE"'
  $r = Invoke-Generator $d @(); Assert-Exit $r 0; Assert-Out $r 'match no board' (T "warning on an orphan rule")
  $slots = Read-Text ([System.IO.Path]::Combine($d, "HardwareProfile.slots"))
  Assert-True ($slots.Contains("filter Mode board:DEVICE_UP1_TAS_4X = 0") -and $slots.Contains("filter Mode board:DEVICE_REG1_LAN_BASE = 1")) (T "the orphan rule keeps slot 0, the new rule takes slot 1")
  # an old slot line (value set instead of rule) stops
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.slots")) 'filter Mode board:DEVICE_UP1_TAS_4X = 0' 'filter Mode 0,1 = 0'
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'is no slot line' (T "stop message")
  # a blank in a board pattern stops (the slot line could not be read back)
  $d = Copy-BaseWithFilter "filters-blank" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef + '<Allow board="DEVICE_UP1 *" values="2" /></Filter></Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'has no blanks' (T "stop message")
  # a token number: slots > 1 stops; an edited rule stops on the full capacity until its key is written into the old line
  $tf = '<Filter name="SceneFx" ref="%AID%_UP-%TT%%CC%%PPP+0%_R-%TT%%CC%%PPP+0%01" source="src/C.templ.xml src/C.share.xml" number="%PPP+19%"{0}><Allow board="{1}" values="0 1" /></Filter>'
  $d = Copy-BaseWithTemplFilter "filters-tokslots" ('<Filters output="src/T.filters.gen.xml">' + ($tf -f ' slots="2"', 'DEVICE_UP1_TAS_4X') + '</Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'one list per filter' (T "stop message")
  # with an op:part of the source (increment 20): two lists fit at offsets 18 and 19, offsets 19 and 20 reach the next instance
  $part = '<KNX xmlns:op="http://github.com/OpenKNX/OpenKNXproducer"><op:part href="C.templ.xml" name="S" instances="3"><op:param name="%PPP%" value="320" increment="20" /></op:part></KNX>'
  $two = ('<Filter name="SceneFx" ref="%AID%_UP-%TT%%CC%%PPP+0%_R-%TT%%CC%%PPP+0%01" source="src/C.templ.xml src/C.share.xml" number="{0}" slots="2">' +
    '<Allow board="DEVICE_UP1_TAS_4X" values="0 1" /><Allow board="DEVICE_REG1_LAN_BASE" values="0 2" /></Filter>')
  $d = Copy-BaseWithTemplFilter "filters-tokstride" ('<Filters output="src/T.filters.gen.xml">' + ($two -f '%PPP+18%') + '</Filters>')
  Write-Text ([System.IO.Path]::Combine($d, "src", "U.templ.xml")) $part
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.filters.gen.xml"))
  Assert-True ($f.Contains('<Parameter Id="%AID%_P-%TT%%CC%%PPP+18%"') -and $f.Contains('<Parameter Id="%AID%_P-%TT%%CC%%PPP+19%"')) (T "two lists of a token number at offsets 18 and 19 expected")
  $d = Copy-BaseWithTemplFilter "filters-tokreach" ('<Filters output="src/T.filters.gen.xml">' + ($two -f '%PPP+19%') + '</Filters>')
  Write-Text ([System.IO.Path]::Combine($d, "src", "U.templ.xml")) $part
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'reach the next instance \(increment 20\)' (T "stop message")
  $d = Copy-BaseWithTemplFilter "filters-tokrule" ('<Filters output="src/T.filters.gen.xml">' + ($tf -f '', 'DEVICE_UP1_TAS_4X') + '</Filters>')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'board="DEVICE_UP1_TAS_4X"' 'board="DEVICE_REG1_LAN_BASE"'
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'write its key into that rule' (T "stop message")
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.slots")) 'filter SceneFx board:DEVICE_UP1_TAS_4X = 0' 'filter SceneFx board:DEVICE_REG1_LAN_BASE = 0'
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.filters.gen.xml"))
  Assert-True ($f -match '<when test="4130">\s*<ParameterRefRef RefId="%AID%_P-%TT%%CC%%PPP\+19%_R-%TT%%CC%%PPP\+19%01"') (T "the edited rule must keep the id %PPP+19%")
  # %PPP+0% as number is the carrier's own number (written %PPP% for slot 0)
  foreach ($zero in @('%PPP+0%', '%PPP+00%')) {
    $d = Copy-BaseWithTemplFilter ("filters-tokzero" + $zero.Length) ('<Filters output="src/T.filters.gen.xml">' + ($tf -f '', 'DEVICE_UP1_TAS_4X').Replace('number="%PPP+19%"', ('number="' + $zero + '"')) + '</Filters>')
    $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'choose a free number' (T "stop message")
  }
  # an own id equal to a conflict flag of a <Conflicts> file the source includes
  $d = Copy-BaseWithFilter "filters-conflict" ('<Filters output="src/T.filters.gen.xml">' + $FilterRef + '<Allow board="DEVICE_UP1_TAS_4X" values="2" /></Filter></Filters>' +
    '<Conflicts output="src/T.conflicts.gen.xml" number="700"><Use name="A" value="gpio" port="%AID%_P-%TT%00050_R-%TT%0005001" /><Use name="B" value="gpio" port="%AID%_P-%TT%00051_R-%TT%0005101" /></Conflicts>')
  Edit-File ([System.IO.Path]::Combine($d, "src", "F.share.xml")) '  <Parameters>' '  <Parameters><op:include xmlns:op="http://github.com/OpenKNX/OpenKNXproducer" href="T.conflicts.gen.xml" xpath="//Block[@name=''Parameters'']/*" />'
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'is also a conflict flag' (T "stop message")
  # an include of another block (no parameters of this module) is no clash
  Edit-File ([System.IO.Path]::Combine($d, "src", "F.share.xml")) "xpath=`"//Block[@name='Parameters']/*`"" "xpath=`"//Block[@name='Conflict_A']/*`""
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
}

# @brief <Conflicts reserved="true"> test project: three boards of a test header (0x3F70 = 16240 serial LED auto config: PROG/INFO
#        are chain indices; 0x3F71 = 16241 serial LED with LED_INIT: PROG/INFO stay GPIOs; 0x3F72 = 16242 GPIO LEDs, INFO1 on an
#        IO expander pin), the LED macros also in <ReservedPins>
function Copy-BaseWithLedBoards([string]$Name) {
  $d = Copy-Base $Name
  $real = [System.IO.Path]::Combine($RepoDir, "include", "HardwareConfig.h") -replace '\\', '/'
  $board = { param($def, $id, $lines) @(('#ifdef ' + $def), ('#define DEVICE_HW_ID ' + $id), ('#define DEVICE_ID "' + $def + '"'), ('#define DEVICE_NAME "' + $def + '"')) + $lines + @('#endif') }
  Write-Text ([System.IO.Path]::Combine($d, "include", "HardwareConfig.h")) ((@('#pragma once', ('#include "' + $real + '"')) +
    (& $board 'TST_SLED_AUTO' '0x3F70' @('#define OPENKNX_SERIALLED_ENABLE', '#define OPENKNX_SERIALLED_PIN 16', '#define PROG_LED_PIN 0', '#define INFO1_LED_PIN 1', '#define INFO3_LED_PIN 3')) +
    (& $board 'TST_SLED_INIT' '0x3F71' @('#define OPENKNX_SERIALLED_ENABLE', '#define OPENKNX_SERIALLED_PIN 17', '#define LED_INIT() do { } while (0)', '#define PROG_LED_PIN 5', '#define INFO1_LED_PIN 6')) +
    (& $board 'TST_GPIO_LED' '0x3F72' @('#define PROG_LED_PIN 7', '#define INFO1_LED_PIN 0x101', '#define INFO2_LED_PIN 2', '#define SAVE_POWER_PIN 9'))) -join "`n")
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '</HardwareProfile>' (@(
    '  <IncludePath>include</IncludePath>'
    '  <Board define="TST_SLED_AUTO" />'
    '  <Board define="TST_SLED_INIT" />'
    '  <Board define="TST_GPIO_LED" />'
    '  <ReservedPins macros="PROG_LED_PIN INFO1_LED_PIN" />'
    '  <Conflicts output="src/T.conflicts.gen.xml" number="900" reserved="true">'
    '    <Use name="A" value="gpio" port="%AID%_P-%TT%00050_R-%TT%0005001" />'
    '    <Use name="B" value="gpio" port="%AID%_P-%TT%00051_R-%TT%0005101" />'
    '  </Conflicts>'
    '</HardwareProfile>') -join "`n")
  return $d
}

Add-Test "reserved-serialled" (T "Reserved: serial LED indices are no GPIOs, LED_INIT and expander pins as before") {
  $d = Copy-BaseWithLedBoards "reserved-serialled"
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $js = Read-Text ([System.IO.Path]::Combine($d, "src", "T.script.js"))
  $rsv = { param($id) $mt = [regex]::Match($js, '(?m)^\s*' + $id + ': \{[^}]*rsv: \[([^\]]*)\]'); if (-not $mt.Success) { throw (T "board {0} not in the script" $id) }; $mt.Groups[1].Value }
  Assert-True ((& $rsv 16240) -eq "16") (T "board {0}: rsv [{1}], expected [{2}]" 16240 (& $rsv 16240) "16")
  Assert-True ((& $rsv 16241) -eq "5, 6, 17") (T "board {0}: rsv [{1}], expected [{2}]" 16241 (& $rsv 16241) "5, 6, 17")
  Assert-True ((& $rsv 16242) -eq "2, 7, 9") (T "board {0}: rsv [{1}], expected [{2}]" 16242 (& $rsv 16242) "2, 7, 9")
  $h = Read-Text ([System.IO.Path]::Combine($d, "include", "T.h"))
  Assert-True ($h -match '#if !\(defined\(OPENKNX_SERIALLED_ENABLE\) && !defined\(LED_INIT\) && !defined\(OPENKNX_LED_NO_AUTOCONF\)\)\s*#ifdef PROG_LED_PIN') (T "firmware header: LED pins without the serial LED guard")
  $r = Invoke-Generator $d @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
}

Add-Test "reserved-serialled-header" (T "Reserved: isReservedGpio of the firmware header per board (compiled)") {
  $cxx = Find-CppCompilerStd
  $d = Copy-BaseWithLedBoards "reserved-serialled-header"
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $src = [System.IO.Path]::Combine($d, "t.cpp")
  Write-Text $src (@(
    '#include "T.h"'
    'using HardwareProfile::isReservedGpio;'
    '#if defined(TST_SLED_AUTO)'
    'static_assert(!isReservedGpio(0) && !isReservedGpio(1) && !isReservedGpio(3) && isReservedGpio(16), "auto");'
    '#elif defined(TST_SLED_INIT)'
    'static_assert(isReservedGpio(5) && isReservedGpio(6) && isReservedGpio(17), "init");'
    '#else'
    'static_assert(isReservedGpio(7) && isReservedGpio(2) && isReservedGpio(9) && !isReservedGpio(1), "gpio");'
    '#endif') -join "`n")
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    foreach ($def in @("TST_SLED_AUTO", "TST_SLED_INIT", "TST_GPIO_LED")) {
      $o = (& $cxx -std=gnu++17 -fsyntax-only ("-D" + $def) ("-I" + [System.IO.Path]::Combine($d, "include")) ("-I" + [System.IO.Path]::Combine($RepoDir, "include")) $src 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) { throw (T "{0}: compile failed`n{1}" $def (Get-Tail $o)) }
    }
  }
  finally { $ErrorActionPreference = $prev }
} "cxxstd"

Add-Test "conflicts-channeltoken" (T "Conflicts: <ChannelBlock> with channelToken %C% (default) and %CC% (flag numbers, template ref), wrong token or number stops") {
  $cb = '    <ChannelBlock name="Ch" text="Kanal {0}" uses="A B" />' + "`n  </Conflicts>"
  $d = Copy-BaseWithLedBoards "conflicts-ctok1"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '  </Conflicts>' ($cb -f '%C%')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.conflicts.gen.xml"))
  Assert-True ($f.Contains('<Parameter Id="%AID%_P-%TT%00911"') -and $f.Contains('<Parameter Id="%AID%_P-%TT%00912"') -and $f.Contains('<ParameterRefRef RefId="%AID%_P-%TT%0091%C%_R-%TT%0091%C%01" />')) (T "%C%: flags 911/912 and template ref %TT%0091%C% expected")
  $d = Copy-BaseWithLedBoards "conflicts-ctok2"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'number="900" reserved="true">' 'number="900" reserved="true" channelToken="%CC%">'
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '  </Conflicts>' ($cb -f '%CC%')
  $r = Invoke-Generator $d @(); Assert-Exit $r 0
  $f = Read-Text ([System.IO.Path]::Combine($d, "src", "T.conflicts.gen.xml"))
  Assert-True ($f.Contains('<Parameter Id="%AID%_P-%TT%01001"') -and $f.Contains('<Parameter Id="%AID%_P-%TT%01002"') -and $f.Contains('<ParameterRefRef RefId="%AID%_P-%TT%010%CC%_R-%TT%010%CC%01" />')) (T "%CC%: flags 1001/1002 and template ref %TT%010%CC% expected")
  $d = Copy-BaseWithLedBoards "conflicts-ctok3"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'number="900" reserved="true">' 'number="950" reserved="true" channelToken="%CC%">'
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) '  </Conflicts>' ($cb -f '%CC%')
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'must be a multiple of 100' (T "stop message")
  $d = Copy-BaseWithLedBoards "conflicts-ctok4"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'number="900" reserved="true">' 'number="900" reserved="true" channelToken="%N%">'
  $r = Invoke-Generator $d @(); Assert-Exit $r 1; Assert-Out $r 'channelToken must be' (T "stop message")
  # a channel template next to the output: %TT%%CC%001 of channel 1 is the 5-digit number 01001 = flag B of number 1000
  $d = Copy-BaseWithLedBoards "conflicts-ctok5"
  Edit-File ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) 'number="900" reserved="true">' 'number="1000" reserved="true">'
  Write-Text ([System.IO.Path]::Combine($d, "src", "X.templ.xml")) '<KNX><Parameter Id="%AID%_UP-%TT%%CC%001" Name="Ch%C%A" /></KNX>'
  $r = Invoke-Generator $d @(); Assert-Exit $r 0; Assert-Out $r 'channel 1 = flag 01001 of B' (T "warning on a template id")
}

Add-Test "init-second" (T "-Init: a second hardware module is refused") {
  $d = [System.IO.Path]::Combine($Work, "init-second")
  [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($d, "src"))
  [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($d, "lib"))
  New-DirLink ([System.IO.Path]::Combine($d, "lib", "OGM-HardwareConfig")) $RepoDir
  Write-Text ([System.IO.Path]::Combine($d, "platformio.ini")) "[platformio]`n"
  Copy-Item -LiteralPath ([System.IO.Path]::Combine($script:Base, "src", "T.share.xml")) -Destination ([System.IO.Path]::Combine($d, "src", "T.share.xml"))
  Copy-Item -LiteralPath ([System.IO.Path]::Combine($script:Base, "src", "T.xml")) -Destination ([System.IO.Path]::Combine($d, "src", "P.xml"))
  $r = Invoke-Generator $d @("-Init") "New.xml"
  Assert-Exit $r 1; Assert-Out $r 'already includes a hardware module' (T "stop message")
  Assert-NoOut $r 'ModuleTypes in use' (T "-Init went on after the refusal")
  Assert-True (-not (Test-Path -LiteralPath ([System.IO.Path]::Combine($d, "New.xml")))) (T "-Init wrote a manifest")
}

Add-Test "language-table" (T "Language: German table complete, placeholders match") {
  # T "<English text>" in every script of the generator and the demo; the table must hold each one, and nothing else
  $files = @(Get-ChildItem -LiteralPath $GeneratorDir -Recurse -Filter "*.ps1" | ForEach-Object { $_.FullName }) +
           @(Get-ChildItem -LiteralPath ([System.IO.Path]::Combine($RepoDir, "examples", "HardwareProfileDemo", "scripts")) -Filter "*.ps1" | ForEach-Object { $_.FullName })
  $used = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::Ordinal)
  $problems = New-Object System.Collections.Generic.List[string]
  foreach ($f in $files) {
    $tok = $null; $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tok, [ref]$err)
    foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -ceq "T" }, $true)) {
      $a = $c.CommandElements[1]
      if ($a -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
          ($a -is [System.Management.Automation.Language.ExpandableStringExpressionAst] -and $a.NestedExpressions.Count -eq 0)) {
        [void]$used.Add($a.Value)
        # one argument per {n} (a missing one throws, a surplus one is a lost placeholder); without arguments the text is
        # printed as it is, so no {n} and no {{ }}
        $argCount = $c.CommandElements.Count - 2
        $top = -1; foreach ($mt in [regex]::Matches(($a.Value -replace '\{\{', '' -replace '\}\}', ''), '\{(\d+)')) { $top = [Math]::Max($top, [int]$mt.Groups[1].Value) }
        if ($argCount -ne $top + 1 -or ($argCount -eq 0 -and $a.Value -match '\{\{|\}\}')) {
          $problems.Add((T "{0}:{1}: {2} argument(s) for the placeholders of '{3}'" ([System.IO.Path]::GetFileName($f)) $c.Extent.StartLineNumber $argCount $a.Value))
        }
      }
      else { $problems.Add((T "{0}:{1}: T needs a constant text" ([System.IO.Path]::GetFileName($f)) $c.Extent.StartLineNumber)) }
    }
  }
  $tablePath = [System.IO.Path]::Combine($GeneratorDir, "core", "Messages.de.psd1")
  # without the UTF-8 BOM Windows PowerShell 5.1 reads the file as ANSI and every umlaut comes out wrong
  $head = [System.IO.File]::ReadAllBytes($tablePath)
  if ($head.Length -lt 3 -or $head[0] -ne 0xEF -or $head[1] -ne 0xBB -or $head[2] -ne 0xBF) { $problems.Add((T "{0} has no UTF-8 BOM" $tablePath)) }
  $table = Read-MessageTable $tablePath
  $holes = { param($s) (@([regex]::Matches(($s -replace '\{\{', '' -replace '\}\}', ''), '\{\d+[^}]*\}') | ForEach-Object { $_.Value } | Sort-Object) -join " ") }
  foreach ($k in $used) {
    if (-not $table.ContainsKey($k)) { $problems.Add((T "missing in the table: {0}" $k)); continue }
    if ((& $holes $k) -cne (& $holes $table[$k])) { $problems.Add((T "placeholders differ: {0}" $k)) }
  }
  foreach ($k in $table.Keys) { if (-not $used.Contains($k)) { $problems.Add((T "in the table, not in the code: {0}" $k)) } }
  if ($problems.Count) { throw (($problems | Select-Object -First 10) -join "`n") }
}

Add-Test "language-de" (T "Language: German by default") {
  $d = Copy-Base "language-de"
  $r = Invoke-Generator $d @("-Check", "-Language", "en"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { $o = (& $PwshExe -NoProfile -ExecutionPolicy Bypass -File $Generator -Manifest ([System.IO.Path]::Combine($d, "HardwareProfile.xml")) -Check 2>&1 | Out-String) }
  finally { $ErrorActionPreference = $prev }
  if ($o -notmatch 'Check: aktuell') { throw (T "default language is not German`n{0}" (Get-Tail $o)) }
}

Add-Test "helper-sort" (T "Helpers: ordinal, stable sort (also of a List)") {
  $l = New-Object System.Collections.Generic.List[object]
  foreach ($x in @("b", "B", "a", "ab", "a", "Z")) { $l.Add($x) }
  Assert-True ((@(Get-OrdinalSorted $l) -join ",") -eq "B,Z,a,a,ab,b") (T "sort order")
  Assert-True ((@(Get-OrdinalSorted $l -Unique) -join ",") -eq "B,Z,a,ab,b") (T "-Unique")
  $h = @(@{ K = "x"; N = 1 }, @{ K = "a"; N = 2 }, @{ K = "x"; N = 3 })
  Assert-True (((@(Get-OrdinalSorted $h { $_.K }) | ForEach-Object { $_.N }) -join ",") -eq "2,1,3") (T "stable by key")
  Assert-True (@(Get-OrdinalSorted @()).Count -eq 0) (T "empty input")
}

Add-Test "helper-png" (T "Helpers: PNG written and read back, same pixels") {
  $p = [System.IO.Path]::Combine($Work, "png-test.png")
  $w = 7; $h = 5; $px = New-Object byte[] ($w * $h * 4)
  for ($i = 0; $i -lt $px.Length; $i++) { $px[$i] = [byte](($i * 37 + 11) % 256) }
  Assert-True (Update-PngRgba $p $w $h $px) (T "first write")
  $img = Read-PngRgba $p
  Assert-True ($img.Width -eq $w -and $img.Height -eq $h) (T "size")
  Assert-True ([System.Convert]::ToBase64String($img.Pixels) -ceq [System.Convert]::ToBase64String($px)) (T "pixels")
  Assert-True (-not (Update-PngRgba $p $w $h $px)) (T "unchanged picture was written again")
}

Add-Test "header-relays" (T "Header: HardwarePorts.h with -Wall -Wextra -Werror") {
  $cxx = Find-CppCompiler
  $d = [System.IO.Path]::Combine($Work, "header"); [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($d, "fake"))
  Write-Text ([System.IO.Path]::Combine($d, "fake", "HardwareConfig.h")) ""
  $src = [System.IO.Path]::Combine($d, "t.cpp")
  Write-Text $src ("#include `"HardwareConfig/Helpers/HardwarePorts.h`"`n#ifdef T_TWO`nstatic_assert(hwRelayCount() == 2 && hwRelayGpio(1) == 12 && hwRelayGpio(2) == 255 && isHwRelayGpio(13), `"two`");`n" +
    "#else`nstatic_assert(hwRelayCount() == 0 && hwRelayGpio(0) == 255 && !isHwRelayGpio(13), `"none`");`n#endif`nunsigned use(unsigned char i) { return hwRelayGpio(i) + (i < hwRelayCount()); }`n")
  $inc = [System.IO.Path]::Combine($RepoDir, "include")
  # the error cases include the header only: the message must come from the header itself
  $neg = [System.IO.Path]::Combine($d, "neg.cpp")
  Write-Text $neg "#include `"HardwareConfig/Helpers/HardwarePorts.h`"`nunsigned use(unsigned char i) { return hwRelayGpio(i); }`n"
  $cases = @(
    @{ Name = "no relays"; Src = $src; Defs = @(); Expect = "" },
    @{ Name = "two relays"; Src = $src; Defs = @("-DT_TWO", "-DHW_RELAY_COUNT=2", "-DHW_RELAY_1_GPIO=13", "-DHW_RELAY_2_GPIO=12"); Expect = "" },
    @{ Name = "nine relays"; Src = $neg; Defs = @("-DHW_RELAY_COUNT=9", "-DHW_RELAY_1_GPIO=1", "-DHW_RELAY_2_GPIO=2", "-DHW_RELAY_3_GPIO=3", "-DHW_RELAY_4_GPIO=4", "-DHW_RELAY_5_GPIO=5", "-DHW_RELAY_6_GPIO=6", "-DHW_RELAY_7_GPIO=7", "-DHW_RELAY_8_GPIO=8"); Expect = "above 8" },
    @{ Name = "missing GPIO"; Src = $neg; Defs = @("-DHW_RELAY_COUNT=2", "-DHW_RELAY_1_GPIO=13"); Expect = "HW_RELAY_2_GPIO is missing" },
    @{ Name = "GPIO 300"; Src = $neg; Defs = @("-DHW_RELAY_COUNT=1", "-DHW_RELAY_1_GPIO=300"); Expect = "must be a GPIO 0..254" }
  )
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    foreach ($c in $cases) {
      $o = (& $cxx -std=gnu++11 -Wall -Wextra -Werror -fsyntax-only ("-I" + [System.IO.Path]::Combine($d, "fake")) ("-I" + $inc) @($c.Defs) $c.Src 2>&1 | Out-String)
      $ok = ($LASTEXITCODE -eq 0)
      if (-not $c.Expect -and -not $ok) { throw (T "{0}: compile failed`n{1}" $c.Name (Get-Tail $o)) }
      if ($c.Expect -and ($ok -or $o -notmatch [regex]::Escape($c.Expect))) { throw (T "{0}: expected the header error '{1}'`n{2}" $c.Name $c.Expect (Get-Tail $o)) }
    }
  }
  finally { $ErrorActionPreference = $prev }
} "cxx"

Add-Test "demo-check" (T "Demo: HardwareProfileDemo is up to date (-Check)") {
  $demo = [System.IO.Path]::Combine($RepoDir, "examples", "HardwareProfileDemo")
  $r = Invoke-Generator $demo @("-Check"); Assert-Exit $r 0; Assert-Out $r 'Check: up to date' "-Check"
} "pio"

Add-Test "demo-update" (T "Demo update: N to N+1 keeps the values, -Break fails") {
  $script = [System.IO.Path]::Combine($RepoDir, "examples", "HardwareProfileDemo", "scripts", "Test-DemoUpdate.ps1")
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try {
    $o1 = (& $PwshExe -NoProfile -ExecutionPolicy Bypass -File $script -OutDir ([System.IO.Path]::Combine($Work, "update")) 2>&1 | Out-String); $e1 = $LASTEXITCODE
    $o2 = (& $PwshExe -NoProfile -ExecutionPolicy Bypass -File $script -Break -OutDir ([System.IO.Path]::Combine($Work, "update-break")) 2>&1 | Out-String); $e2 = $LASTEXITCODE
  }
  finally { $ErrorActionPreference = $prev }
  if ($e1 -ne 0) { throw (T "update test failed`n{0}" (Get-Tail $o1)) }
  if ($e2 -ne 1) { throw (T "-Break did not fail`n{0}" (Get-Tail $o2)) }
} "full"

# ------------------------------------------------------------------------------------------------
# runner
# ------------------------------------------------------------------------------------------------

function Test-Need([string]$Need) {
  switch ($Need) {
    "" { return $null }
    "cxx" { if (Find-CppCompiler) { return $null } return (T "no g++ / clang++ found") }
    "cxxstd" { if (Find-CppCompilerStd) { return $null } return (T "no C++ compiler with <cstdint> found") }
    "pio" {
      $demoLib = [System.IO.Path]::Combine($RepoDir, "examples", "HardwareProfileDemo", "lib", "OGM-Common")
      if (-not (Test-Path -LiteralPath $demoLib)) { return (T "the lib/ links of the demo are missing (examples/HardwareProfileDemo/README.md)") }
      if (-not (Get-Command pio -ErrorAction SilentlyContinue) -and -not (Test-Path ([System.IO.Path]::Combine([Environment]::GetFolderPath("UserProfile"), ".platformio", "penv")))) { return (T "PlatformIO not found") }
      return $null
    }
    "full" {
      if (-not $Full) { return (T "only with -Full") }
      if (-not (Get-Command OpenKNXproducer -ErrorAction SilentlyContinue)) { return (T "OpenKNXproducer not found") }
      return (Test-Need "pio")
    }
  }
  return $null
}

Show-OpenKNXLogo "Test-HardwareProfile"
try {
$selected = @($Tests | Where-Object { -not $Only -or $_.Id -like $Only -or $_.Name -like $Only })
$total = [System.Diagnostics.Stopwatch]::StartNew()
$pass = 0; $fail = 0; $skip = 0; $failed = @()
Write-Host (T "  work folder: {0}" $Work) -ForegroundColor DarkGray
Write-Host (T "  create the base project ...") -ForegroundColor Cyan
$script:Base = New-BaseProject
Write-Host ""
# one line per test: "[n/N] <spinner> name" while it runs (console only), then "[n/N] <mark> name  <time>"; the reason of a
# failure below it
$n = 0
foreach ($t in $selected) {
  $n++
  $num = "  [{0,2}/{1}] " -f $n, $selected.Count
  Start-ProgressLine $num $t.Name
  $why = Test-Need $t.Need
  if ($why) { Complete-ProgressLine "skip" $why -NoTime; $skip++; continue }
  try {
    & $t.Run
    Complete-ProgressLine "ok"
    $pass++
  }
  catch {
    $msg = "$($_.Exception.Message)"
    Complete-ProgressLine "fail"
    foreach ($l in ($msg -split "`n")) { Write-Host ("        " + $l) -ForegroundColor Red }
    $fail++; $failed += $t.Id
  }
}
Stop-ProgressSpinner

Write-Host ""
$color = "Green"; if ($fail -gt 0) { $color = "Red" }
Write-Host (T "  Self-test: {0} passed, {1} failed, {2} skipped - {3:N1} s" $pass $fail $skip $total.Elapsed.TotalSeconds) -ForegroundColor $color
if ($fail -gt 0) { Write-Host (T "  failed: {0}" ($failed -join ", ")) -ForegroundColor Red }

}
finally {
  Stop-ProgressSpinner
  # links as links only (Test-DemoUpdate and init-second leave junctions / symbolic links to the repositories)
  if ($KeepWork) { Write-Host (T "  work folder kept: {0}" $Work) -ForegroundColor DarkGray }
  else { Remove-Tree $Work }
}
if ($fail -gt 0) { exit 1 }
exit 0
