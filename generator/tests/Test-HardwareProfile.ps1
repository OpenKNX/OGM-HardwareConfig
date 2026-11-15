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
      Fixes          parts file with both Assigns and the read-only ParameterRef; wrong case and a ref fixed twice stop
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
$width = ($selected | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
$n = 0
foreach ($t in $selected) {
  $n++
  $num = "  [{0,2}/{1}] " -f $n, $selected.Count
  $why = Test-Need $t.Need
  if ($why) {
    Write-Host $num -NoNewline -ForegroundColor DarkGray; Write-Host $t.Name.PadRight($width) -NoNewline
    Write-Host (" " + (Get-PhaseMark "skip")) -ForegroundColor Yellow -NoNewline; Write-Host ("          " + $why) -ForegroundColor DarkGray; $skip++; continue
  }
  Write-Host $num -NoNewline -ForegroundColor DarkGray; Write-Host $t.Name.PadRight($width) -NoNewline
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    & $t.Run
    Write-Host (" " + (Get-PhaseMark "ok")) -ForegroundColor Green -NoNewline; Write-Host ("{0,6:N1} s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor DarkGray
    $pass++
  }
  catch {
    Write-Host (" " + (Get-PhaseMark "fail")) -ForegroundColor Red -NoNewline; Write-Host ("{0,6:N1} s" -f $sw.Elapsed.TotalSeconds) -ForegroundColor DarkGray
    foreach ($l in ("$($_.Exception.Message)" -split "`n")) { Write-Host ("        " + $l) -ForegroundColor Red }
    $fail++; $failed += $t.Id
  }
}

Write-Host ""
$color = "Green"; if ($fail -gt 0) { $color = "Red" }
Write-Host (T "  Self-test: {0} passed, {1} failed, {2} skipped - {3:N1} s" $pass $fail $skip $total.Elapsed.TotalSeconds) -ForegroundColor $color
if ($fail -gt 0) { Write-Host (T "  failed: {0}" ($failed -join ", ")) -ForegroundColor Red }

}
finally {
  # links as links only (Test-DemoUpdate and init-second leave junctions / symbolic links to the repositories)
  if ($KeepWork) { Write-Host (T "  work folder kept: {0}" $Work) -ForegroundColor DarkGray }
  else { Remove-Tree $Work }
}
if ($fail -gt 0) { exit 1 }
exit 0
