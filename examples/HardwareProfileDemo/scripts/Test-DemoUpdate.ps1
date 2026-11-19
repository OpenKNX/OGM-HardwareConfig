#Requires -Version 5.1
<#
Open =
-----+  Test-DemoUpdate
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/examples/HardwareProfileDemo/scripts/Test-DemoUpdate.ps1
#>

<#
.SYNOPSIS
    Simulates an application update of the hardware profile demo: builds version N, applies every kind of change the
    generator has to survive, builds version N+1 and checks that an ETS update keeps the values.

.DESCRIPTION
    Works on a copy of the demo (default: out/update next to this script's demo folder); the demo itself is not changed.

    1. Copy the demo, link lib/, build version N (generator + OpenKNXproducer).
    2. Apply the changes of version N+1 (each a collision point of the generator):
         C1  new capability in the middle of the capability pack (Common.caps.xml)
         C2  new own capability in front of the existing ones, as a switch
         C3  two capabilities swapped in the manifest
         C4  an existing capability becomes a switch (moves the memory bit of later switches)
         C5  new value without device query
         C6  value range widened (Relays max 4 -> 8)
         C7  board removed (its slot stays reserved)
         C8  board added (next free slot)
         C9  order of the selection list from the manifest, a board moved
         C10 GPIO role with one more selection field
         C11 new GPIO role
         C12 texts changed (capability, page)
       and raise the ApplicationVersion by 0.1.
    3. Build version N+1 and compare both knxprods the way ETS updates an application: a value is kept when the new
       application has a ParameterRef with the same number (R-...) and its type accepts the old value; a parameter
       without memory (and not writable) is not taken over anyway. A writable parameter that becomes read-only or loses
       its memory in N+1 counts as a loss. Not checked: visibility by choose and Assign in N+1 (a hidden parameter gets its
       default with the next download) - that is the ETS test of the two knxprods.
    4. Check the device query: every recorded bit (cap/val lines of the slot file) keeps its name; every board slot of N
       keeps its number.

    Expected losses (the parameters of the removed board, its value in the hardware selection) are listed as expected;
    anything else fails the test (exit code 1). Both knxprods stay in the output folder for a manual test in ETS:
    import N, insert a device, set values, import N+1, "Aktualisieren".

.PARAMETER OutDir
    Output folder (work copy, both knxprods, logs). Default: <demo>/out/update. Deleted and rebuilt by every run, so the
    script refuses a folder it did not create (marker file .test-demo-update), one that holds the demo or the repository,
    and one inside the demo but not below out/.

.PARAMETER Producer
    OpenKNXproducer command or path. Default: OpenKNXproducer from PATH.

.PARAMETER Break
    Self-test of the comparison: adds a change that loses user values (C13: board DEVICE_QUINLED_DIG_QUAD_V3_ETHERNET offers only port
    1, the stored port values 2.. are no longer valid). The test must then fail.

.PARAMETER Language
    Language of the output: de (default) or en; also passed to the generator.

.PARAMETER Help
    Shows this help.

.EXAMPLE
    pwsh examples/HardwareProfileDemo/scripts/Test-DemoUpdate.ps1

.NOTES
    Author: Erkan Colak. Needs what the demo build needs: lib/ links of the demo, PlatformIO, a C preprocessor and the
    OpenKNXproducer. Windows PowerShell 5.1 and PowerShell 7.
#>
[CmdletBinding()]
param(
  [string]$OutDir = "",
  [string]$Producer = "OpenKNXproducer",
  [switch]$Break,
  [ValidateSet("de", "en")][string]$Language = "de",
  [Alias("h")][switch]$Help
)

$ErrorActionPreference = "Stop"
$SCRIPT_VERSION = "1.0.0"

# @brief OpenKNX logo with a title (same look as the generator); the glyphs are built at run time, the file stays ASCII
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

if ($Help) { Get-Help $PSCommandPath -Detailed; exit 0 }
Show-OpenKNXLogo ("Test-DemoUpdate " + $SCRIPT_VERSION)

$Demo = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, ".."))
$Repo = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($Demo, "..", ".."))
$Generator = [System.IO.Path]::Combine($Repo, "generator", "Build-HardwareProfile.ps1")
# output language: the T function and the German table of the generator
. ([System.IO.Path]::Combine($Repo, "generator", "core", "Language.ps1"))
Set-OutputLanguage $Language
if (-not $OutDir) { $OutDir = [System.IO.Path]::Combine($Demo, "out", "update") }
if (-not [System.IO.Path]::IsPathRooted($OutDir)) { $OutDir = [System.IO.Path]::Combine((Get-Location).Path, $OutDir) }   # relative to the shell folder
$OutDir = [System.IO.Path]::GetFullPath($OutDir)
$Work = [System.IO.Path]::Combine($OutDir, "project")
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$MarkerName = ".test-demo-update"
$ae = [string][char]0xE4; $oe = [string][char]0xF6; $ue = [string][char]0xFC
$script:Failed = 0

function Write-Step([string]$Text) { Write-Host ("  > " + $Text) -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host ("  + " + $Text) -ForegroundColor Green }
function Write-Bad([string]$Text) { Write-Host ("  x " + $Text) -ForegroundColor Red; $script:Failed++ }
function Write-Note([string]$Text) { Write-Host ("    " + $Text) }

# ------------------------------------------------------------------------------------------------
# work copy
# ------------------------------------------------------------------------------------------------

# @brief Target folder of a link (junction / symbolic link) as a full path, or the folder itself
function Resolve-LinkTarget([string]$Path) {
  $item = Get-Item -LiteralPath $Path -Force
  $t = $item.Target
  if ($t -is [array]) { $t = $t[0] }
  if (-not $t) { return $item.FullName }
  if (-not [System.IO.Path]::IsPathRooted($t)) { $t = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($item.FullName), $t) }
  return [System.IO.Path]::GetFullPath($t)
}

# @brief Directory link: a junction on Windows (no admin rights needed), a symbolic link elsewhere
function New-DirLink([string]$Path, [string]$Target) {
  if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { New-Item -ItemType Junction -Path $Path -Value $Target | Out-Null }
  else { New-Item -ItemType SymbolicLink -Path $Path -Value $Target | Out-Null }
}

function Test-Inside([string]$Path, [string]$Dir) {
  $p = $Path.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  $d = $Dir.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  return $p.StartsWith($d, [StringComparison]::OrdinalIgnoreCase)
}

function New-WorkCopy {
  # never a folder that holds the demo or the repository, never one this script did not create (marker file)
  if ((Test-Inside $Demo $OutDir) -or (Test-Inside $Repo $OutDir)) { throw (T "-OutDir {0} contains the demo or the repository" $OutDir) }
  if ((Test-Inside $OutDir $Demo) -and -not (Test-Inside $OutDir ([System.IO.Path]::Combine($Demo, "out")))) { throw (T "-OutDir inside the demo must be below out/ (the copy would copy itself)") }
  $marker = [System.IO.Path]::Combine($OutDir, $MarkerName)
  if (Test-Path -LiteralPath $OutDir) {
    if (@(Get-ChildItem -LiteralPath $OutDir -Force).Count -gt 0 -and -not (Test-Path -LiteralPath $marker)) { throw (T "-OutDir {0} is not empty and was not created by this script ({1} missing) - choose another folder" $OutDir $MarkerName) }
    # links first (Remove-Item -Recurse would follow a junction on Windows PowerShell 5.1)
    $lib = [System.IO.Path]::Combine($Work, "lib")
    if (Test-Path -LiteralPath $lib) { foreach ($l in @(Get-ChildItem -LiteralPath $lib -Force)) { [System.IO.Directory]::Delete($l.FullName, $false) } }
    $org = [System.IO.Path]::Combine($OutDir, "Organization")
    if (Test-Path -LiteralPath $org) { [System.IO.Directory]::Delete($org, $false) }
    Remove-Item -LiteralPath $OutDir -Recurse -Force
  }
  [void][System.IO.Directory]::CreateDirectory($Work)
  [System.IO.File]::WriteAllText($marker, "Test-DemoUpdate.ps1 work folder - deleted and rebuilt by every run`n", $Utf8)
  # the producer validates against ../../Organization/knxprod-support (relative to src/): link the Organization checkout when found
  $orgSrc = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($Repo, "..", "Organization"))
  if (Test-Path -LiteralPath ([System.IO.Path]::Combine($orgSrc, "knxprod-support"))) { New-DirLink ([System.IO.Path]::Combine($OutDir, "Organization")) $orgSrc }
  else { Write-Note (T "no Organization checkout next to the repository ({0}): the producer cannot validate against the KNX schema" $orgSrc) }
  $skip = @("lib", ".pio", "out", "release", ".vscode")
  foreach ($e in @(Get-ChildItem -LiteralPath $Demo -Force)) {
    if ($skip -contains $e.Name) { continue }
    Copy-Item -LiteralPath $e.FullName -Destination $Work -Recurse -Force
  }
  foreach ($f in @(Get-ChildItem -LiteralPath $Work -Recurse -Force -File | Where-Object { $_.Name -like "*.knxprod" -or $_.Name -like "*.debug.xml" })) { Remove-Item -LiteralPath $f.FullName -Force }
  $srcLib = [System.IO.Path]::Combine($Demo, "lib")
  if (-not (Test-Path -LiteralPath $srcLib)) { throw (T "No lib/ in {0} - create the links first (README of the demo, 'Bauen')" $Demo) }
  $lib = [System.IO.Path]::Combine($Work, "lib")
  [void][System.IO.Directory]::CreateDirectory($lib)
  foreach ($l in @(Get-ChildItem -LiteralPath $srcLib -Force)) { New-DirLink ([System.IO.Path]::Combine($lib, $l.Name)) (Resolve-LinkTarget $l.FullName) }
  # include/HardwareConfig.h of the demo reaches the repository headers relative to the demo folder: make it absolute
  $hc = [System.IO.Path]::Combine($Work, "include", "HardwareConfig.h")
  $repoInc = ([System.IO.Path]::Combine($Repo, "include", "HardwareConfig.h")) -replace '\\', '/'
  [System.IO.File]::WriteAllText($hc, ([System.IO.File]::ReadAllText($hc).Replace('"../../../include/HardwareConfig.h"', ('"' + $repoInc + '"'))), $Utf8)
  # the manifest imports the pack relative to the demo folder: point it at the copy of the pack (C1 changes that copy)
  $caps = [System.IO.Path]::Combine($Work, "caps")
  [void][System.IO.Directory]::CreateDirectory($caps)
  Copy-Item -LiteralPath ([System.IO.Path]::Combine($Repo, "generator", "capabilities", "Common.caps.xml")) -Destination $caps
  Edit-Manifest { param($x) $x.HardwareManifest.SelectSingleNode("Import").SetAttribute("href", "caps/Common.caps.xml") }
}

# ------------------------------------------------------------------------------------------------
# XML helpers
# ------------------------------------------------------------------------------------------------

function Read-XmlFile([string]$Path) {
  $x = New-Object System.Xml.XmlDocument
  $x.PreserveWhitespace = $true
  $x.Load($Path)
  return ,$x
}

function Save-XmlFile($Xml, [string]$Path) {
  $settings = New-Object System.Xml.XmlWriterSettings
  $settings.Encoding = $Utf8
  $w = [System.Xml.XmlWriter]::Create($Path, $settings)
  try { $Xml.Save($w) } finally { $w.Close() }
}

function Edit-Manifest([scriptblock]$Change) {
  $p = [System.IO.Path]::Combine($Work, "HardwareManifest.xml")
  $x = Read-XmlFile $p
  & $Change $x
  Save-XmlFile $x $p
}

function New-Element($Xml, [string]$Name, [hashtable]$Attrs) {
  $e = $Xml.CreateElement($Name)
  foreach ($k in @($Attrs.Keys | Sort-Object)) { $e.SetAttribute($k, [string]$Attrs[$k]) }
  return $e
}

function Get-Capability($Root, [string]$Name) {
  $n = $Root.SelectSingleNode("Capability[@name='$Name']")
  if (-not $n) { throw (T "Capability {0} not found in the manifest" $Name) }
  return $n
}

# ------------------------------------------------------------------------------------------------
# build
# ------------------------------------------------------------------------------------------------

function Get-AppVersion {
  $t = [System.IO.File]::ReadAllText([System.IO.Path]::Combine($Work, "src", "HardwareProfileDemo.xml"))
  if ($t -notmatch '\bApplicationVersion="(\d+)\.(\d+)"') { throw (T "ApplicationVersion not found in HardwareProfileDemo.xml") }
  return @{ Major = [int]$Matches[1]; Minor = [int]$Matches[2]; Text = ("{0}.{1}" -f $Matches[1], $Matches[2]) }
}

function Set-AppVersion([string]$Version) {
  $p = [System.IO.Path]::Combine($Work, "src", "HardwareProfileDemo.xml")
  $t = [System.IO.File]::ReadAllText($p)
  $t = [regex]::Replace($t, '\bApplicationVersion="\d+\.\d+"', ('ApplicationVersion="{0}"' -f $Version))
  [System.IO.File]::WriteAllText($p, $t, $Utf8)
}

# @brief Generator + producer on the work copy; returns the path of the knxprod in the output folder
function Invoke-Build([string]$Label) {
  $v = (Get-AppVersion).Text
  Write-Step (T "build {0}: version {1}" $Label $v)
  $log = [System.IO.Path]::Combine($OutDir, ("generator-{0}.log" -f $v))
  $ps = (Get-Process -Id $PID).Path
  & $ps -NoProfile -ExecutionPolicy Bypass -File $Generator -Manifest ([System.IO.Path]::Combine($Work, "HardwareManifest.xml")) -Language $Language *> $log
  if ($LASTEXITCODE -ne 0) { Get-Content -LiteralPath $log | Select-Object -Last 15 | ForEach-Object { Write-Note $_ }; throw (T "generator failed for {0} (log: {1})" $Label $log) }
  foreach ($l in @(Get-Content -LiteralPath $log | Where-Object { $_ -match '^\s*! ' })) { Write-Note $l.Trim() }
  $out = [System.IO.Path]::Combine($OutDir, ("HardwareProfileDemo-{0}.knxprod" -f $v))
  $plog = [System.IO.Path]::Combine($OutDir, ("producer-{0}.log" -f $v))
  Push-Location ([System.IO.Path]::Combine($Work, "src"))
  try { & $Producer create -h ([System.IO.Path]::Combine($Work, "include", "knxprod.h")) -o $out "HardwareProfileDemo.xml" *> $plog }
  finally { Pop-Location }
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $out)) { Get-Content -LiteralPath $plog | Select-Object -Last 15 | ForEach-Object { Write-Note $_ }; throw (T "producer failed for {0} (log: {1})" $Label $plog) }
  Copy-Item -LiteralPath ([System.IO.Path]::Combine($Work, "HardwareManifest.slots")) -Destination ([System.IO.Path]::Combine($OutDir, ("HardwareProfile-{0}.slots" -f $v))) -Force
  Write-Ok ([System.IO.Path]::GetFileName($out))
  return $out
}

# ------------------------------------------------------------------------------------------------
# changes of version N+1
# ------------------------------------------------------------------------------------------------

# @brief Applies C1..C12; returns what the comparison may lose (removed board) and what it must find new
function Invoke-Changes {
  $exp = @{ RemovedSlots = @(); RemovedIds = @(); NewCaps = @("UpdPack", "UpdOwn"); NewValues = @("UpdLevel") }

  # C1: new capability in the middle of the pack
  $pp = [System.IO.Path]::Combine($Work, "caps", "Common.caps.xml")
  $pack = Read-XmlFile $pp
  $caps = @($pack.DocumentElement.SelectNodes("Capability"))
  $mid = $caps[[int]($caps.Count / 2)]
  [void]$pack.DocumentElement.InsertBefore((New-Element $pack "Capability" @{ name = "UpdPack"; text = "Update-Test Paket"; expr = "defined(UPD_TEST_NEVER)" }), $mid)
  Save-XmlFile $pack $pp
  Write-Note (T "C1  capability UpdPack inserted in the pack before {0}" $mid.GetAttribute("name"))

  # slot of the board removed in C7 (from the slot file of version N)
  $slots = [System.IO.File]::ReadAllLines([System.IO.Path]::Combine($Work, "HardwareManifest.slots"))
  foreach ($l in $slots) { if ($l -match '^\s*0x3F14\s*=\s*(\d+)') { $exp.RemovedSlots += [int]$Matches[1] } }
  if ($exp.RemovedSlots.Count -ne 1) { throw (T "slot of 0x3F14 not found in the slot file of version N") }
  $exp.RemovedIds = @(0x3F14)

  Edit-Manifest {
    param($x)
    $r = $x.HardwareManifest
    # C2: own capability in front of the first own one, as a switch
    $first = Get-Capability $r "LargeFlash"
    [void]$r.InsertBefore((New-Element $x "Capability" @{ name = "UpdOwn"; text = "Update-Test Schalter"; expr = "defined(UPD_TEST_NEVER)"; switch = "true" }), $first)
    # C3: swap PowerMeter and Temperature
    $a = Get-Capability $r "PowerMeter"; $b = Get-Capability $r "Temperature"
    [void]$r.InsertBefore($b, $a)
    # C4: FrontControls becomes a switch (stands before SensorModule: the memory bit of SensorModule moves)
    (Get-Capability $r "FrontControls").SetAttribute("switch", "true")
    # C5: value without device query
    $rel = $r.SelectSingleNode("Value[@name='Relays']")
    [void]$r.InsertAfter((New-Element $x "Value" @{ name = "UpdLevel"; text = "Update-Test Stufe"; expr = "UPD_TEST_LEVEL"; default = "0"; max = "3"; query = "false" }), $rel)
    # C6: value range widened
    $rel.SetAttribute("max", "8")
    # C7: board removed
    $plug = $r.SelectSingleNode("Board[@define='DEMO_SHELLY_PLUG_S']")
    [void]$r.RemoveChild($plug)
    # C8: board added (REG1 Multisensor LAN 0x1023, APP pins scanned by the GPIO roles)
    $last = @($r.SelectNodes("Board"))[-1]
    [void]$r.InsertAfter((New-Element $x "Board" @{ define = "DEVICE_REG1_LAN_SEN_MULTI" }), $last)
    # C9: selection order from the manifest, UP1 moved to the end
    $r.SetAttribute("order", "manifest")
    $up1 = $r.SelectSingleNode("Board[@define='DEVICE_UP1_TAS_4X']")
    $last = @($r.SelectNodes("Board"))[-1]
    [void]$r.InsertAfter($up1, $last)
    # C10: one more selection field of the GPIO role "Pin"
    $role = $r.SelectSingleNode("GpioRole[@name='Pin']")
    $role.SetAttribute("count", "3")
    # C11: new GPIO role
    $nr = New-Element $x "GpioRole" @{ name = "Sensor"; number = "2"; text = "Sensor-Anschluss"; count = "1" }
    [void]$nr.AppendChild((New-Element $x "Pins" @{ board = "DEVICE_REG1_*"; scan = '^REG1_APP_PIN(\d+)$'; label = 'APP-Pin $1' }))
    [void]$r.InsertAfter($nr, $role)
    # C12: texts
    (Get-Capability $r "Lux").SetAttribute("text", "Lichtwert")
    $r.SelectSingleNode("Page").SetAttribute("changeInfo", ("Nach einem Wechsel des Ger" + $ae + "ts die Kan" + $ae + "le pr" + $ue + "fen."))
    # C13 (-Break only): fewer ports for one board - stored port values become invalid
    if ($Break) { [void]$r.InsertAfter((New-Element $x "Ports" @{ board = "DEVICE_QUINLED_DIG_QUAD_V3_ETHERNET"; use = "1" }), @($r.SelectNodes("Board"))[-1]) }
  }
  Write-Note (T "C2  capability UpdOwn (switch) in front of the own capabilities")
  Write-Note (T "C3  PowerMeter and Temperature swapped")
  Write-Note (T "C4  FrontControls becomes a switch")
  Write-Note (T "C5  value UpdLevel without device query")
  Write-Note (T "C6  Relays max 4 -> 8")
  Write-Note (T "C7  board 0x3F14 (DEMO_SHELLY_PLUG_S, slot {0}) removed" ($exp.RemovedSlots[0]))
  Write-Note (T "C8  board 0x1023 (DEVICE_REG1_LAN_SEN_MULTI) added")
  Write-Note (T "C9  order=manifest, UP1 moved to the end")
  Write-Note (T "C10 GPIO role Pin: count 2 -> 3")
  Write-Note (T "C11 GPIO role Sensor (number 2)")
  Write-Note (T "C12 texts of Lux and changeInfo")
  if ($Break) { Write-Note (T "C13 (-Break) DEVICE_QUINLED_DIG_QUAD_V3_ETHERNET offers only port 1 - the test must fail") }
  return $exp
}

# ------------------------------------------------------------------------------------------------
# comparison (rules of an ETS application update)
# ------------------------------------------------------------------------------------------------

# @brief Application XML (M-..._A-...xml) of a knxprod
function Read-KnxprodApp([string]$Path) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $e = @($zip.Entries | Where-Object { $_.FullName -match '/M-[0-9A-F]+_A-[^/]+\.xml$' }) | Select-Object -First 1
    if (-not $e) { throw (T "no application XML in {0}" $Path) }
    $r = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
    try { $text = $r.ReadToEnd() } finally { $r.Close() }
  }
  finally { $zip.Dispose() }
  $x = New-Object System.Xml.XmlDocument
  $x.LoadXml($text)
  return ,$x
}

function Get-RNum([string]$Id) { if ($Id -match '_(R-[0-9A-Za-z-]+)$') { return $Matches[1] } return $Id }

# @brief Types, parameters (with memory flag) and ParameterRefs of an application; Shown = per ParameterRef id the HW-ID lists of
#        the hardware selection whens around each of its rows ($null for a row outside such a when)
function Get-AppModel($Xml) {
  $types = @{}; $params = @{}; $refs = @{}; $shown = @{}
  foreach ($t in $Xml.GetElementsByTagName("ParameterType")) {
    $d = @{ Kind = "other" }
    foreach ($c in $t.ChildNodes) {
      if ($c.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
      switch ($c.LocalName) {
        "TypeRestriction" { $vals = @{}; foreach ($en in $c.GetElementsByTagName("Enumeration")) { $vals[("{0}|{1}" -f $en.GetAttribute("Value"), $en.GetAttribute("BinaryValue"))] = $en.GetAttribute("Text") }; $d = @{ Kind = "enum"; Values = $vals } }
        "TypeNumber" { $d = @{ Kind = "number"; Min = [double]$c.GetAttribute("minInclusive"); Max = [double]$c.GetAttribute("maxInclusive") } }
        "TypeText" { $d = @{ Kind = "text"; Size = [int]$c.GetAttribute("SizeInBit") } }
        "TypeNone" { $d = @{ Kind = "none" } }
        "TypePicture" { $d = @{ Kind = "none" } }
        default { $d = @{ Kind = $c.LocalName; Raw = $c.OuterXml } }
      }
    }
    $types[$t.GetAttribute("Id")] = $d
  }
  foreach ($p in $Xml.GetElementsByTagName("Parameter")) {
    $mem = $false
    foreach ($c in $p.ChildNodes) { if ($c.LocalName -eq "Memory" -or $c.LocalName -eq "Property") { $mem = $true } }
    if ($p.ParentNode.LocalName -eq "Union") { $mem = $true }
    $params[$p.GetAttribute("Id")] = @{ Type = $p.GetAttribute("ParameterType"); Name = $p.GetAttribute("Name"); Access = $p.GetAttribute("Access"); Mem = $mem; Value = $p.GetAttribute("Value") }
  }
  foreach ($r in $Xml.GetElementsByTagName("ParameterRef")) { $refs[(Get-RNum $r.GetAttribute("Id"))] = @{ Id = $r.GetAttribute("Id"); Param = $r.GetAttribute("RefId"); Access = $r.GetAttribute("Access") } }
  $selRefs = @{}
  foreach ($k in $refs.Keys) { $sp = $params[$refs[$k].Param]; if ($sp -and $sp.Name -cmatch 'HardwareSelect$') { $selRefs[$refs[$k].Id] = $true } }
  foreach ($rr in $Xml.GetElementsByTagName("ParameterRefRef")) {
    $ids = $null
    for ($a = $rr.ParentNode; $a -and $a.NodeType -eq [System.Xml.XmlNodeType]::Element; $a = $a.ParentNode) {
      if ($a.LocalName -eq "when" -and $a.ParentNode.LocalName -eq "choose" -and $selRefs.ContainsKey($a.ParentNode.GetAttribute("ParamRefId"))) {
        $ids = @($a.GetAttribute("test") -split '\s+' | Where-Object { $_ } | ForEach-Object { [int]$_ }); break
      }
    }
    $rid = $rr.GetAttribute("RefId")
    if (-not $shown.ContainsKey($rid)) { $shown[$rid] = New-Object System.Collections.ArrayList }
    [void]$shown[$rid].Add($ids)
  }
  return @{ Types = $types; Params = $params; Refs = $refs; Shown = $shown }
}

# @brief Old values the new type rejects ($null: none)
function Get-LostDomain($Old, $New) {
  if ($Old.Kind -ne $New.Kind) { return (T "type {0} -> {1}" $Old.Kind $New.Kind) }
  switch ($Old.Kind) {
    "enum" { $miss = @($Old.Values.Keys | Where-Object { -not $New.Values.ContainsKey($_) } | Sort-Object); if ($miss.Count -gt 0) { return (T "values gone: {0}" (($miss | ForEach-Object { $_.TrimEnd('|') }) -join ", ")) } }
    "number" { if ($New.Min -gt $Old.Min -or $New.Max -lt $Old.Max) { return (T "range {0}..{1} -> {2}..{3}" $Old.Min $Old.Max $New.Min $New.Max) } }
    "text" { if ($New.Size -lt $Old.Size) { return (T "text {0} -> {1} bits" $Old.Size $New.Size) } }
    "none" { }
    default { if ($Old.Raw -ne $New.Raw) { return (T "type detail changed") } }
  }
  return $null
}

function Compare-Apps([string]$OldPath, [string]$NewPath, $Exp) {
  Write-Step (T "ETS update N -> N+1: values per ParameterRef")
  $o = Get-AppModel (Read-KnxprodApp $OldPath)
  $n = Get-AppModel (Read-KnxprodApp $NewPath)
  $ok = 0; $skip = 0; $expected = @(); $bad = @()
  # a parameter of a removed board: the generator and the demo templates name per-board parameters <name>B<slot> (case-
  # sensitive); the selection loses the removed HW-IDs
  $isRemoved = {
    param($paramId, $name)
    foreach ($sl in $Exp.RemovedSlots) { if ($name -cmatch ('B' + $sl + '$')) { return $true } }
    return $false
  }
  # a row shown only on removed boards (e.g. the own list of a <Filter> rule that matched only them): every row of the ref sits
  # in a when of the hardware selection whose HW-IDs are all removed
  $onlyOnRemoved = {
    param($refId)
    $rows = $o.Shown[$refId]
    if (-not $rows -or $rows.Count -eq 0) { return $false }
    foreach ($ids in $rows) {
      if ($null -eq $ids -or $ids.Count -eq 0) { return $false }
      foreach ($i in $ids) { if ($Exp.RemovedIds -notcontains $i) { return $false } }
    }
    return $true
  }
  foreach ($rn in @($o.Refs.Keys | Sort-Object)) {
    $ref = $o.Refs[$rn]; $p = $o.Params[$ref.Param]
    if ($null -eq $p) { continue }
    $t = $o.Types[$p.Type]; if ($null -eq $t) { $t = @{ Kind = "other"; Raw = "" } }
    if ($t.Kind -eq "none" -or (-not $p.Mem -and ($p.Access -eq "None" -or $p.Access -eq "Read"))) { $skip++; continue }
    $label = ("{0} {1}" -f $rn, $p.Name)
    $nr = $n.Refs[$rn]
    if ($null -eq $nr) {
      if (& $isRemoved $ref.Param $p.Name) { $expected += (T "{0}: gone (removed board)" $label) }
      elseif (& $onlyOnRemoved $ref.Id) { $expected += (T "{0}: gone (shown only on removed boards)" $label) }
      else { $bad += (T "{0}: gone" $label) }
      continue
    }
    $np = $n.Params[$nr.Param]
    if ($null -eq $np) { $bad += (T "{0}: the ParameterRef of N+1 points to no parameter ({1})" $label $nr.Param); continue }
    # writable in N, read-only or hidden by Access in N+1: ETS keeps the value but a download writes what N+1 shows
    $wasRw = ($ref.Access -ne "None" -and $ref.Access -ne "Read" -and $p.Access -ne "None" -and $p.Access -ne "Read")
    $isRo = ($nr.Access -eq "None" -or $nr.Access -eq "Read" -or $np.Access -eq "None" -or $np.Access -eq "Read")
    if ($wasRw -and $isRo) { $bad += (T "{0}: read-only in N+1 (Access {1})" $label ("$($nr.Access) $($np.Access)").Trim()); continue }
    if ($p.Mem -and -not $np.Mem) { $bad += (T "{0}: no memory in N+1" $label); continue }
    $nt = $n.Types[$np.Type]; if ($null -eq $nt) { $nt = @{ Kind = "other"; Raw = "" } }
    $lost = Get-LostDomain $t $nt
    if ($null -eq $lost) { $ok++; continue }
    $onlyRemoved = $false
    if ($t.Kind -eq "enum" -and $nt.Kind -eq "enum") {
      $miss = @($t.Values.Keys | Where-Object { -not $nt.Values.ContainsKey($_) })
      $removedKeys = @($Exp.RemovedIds | ForEach-Object { "{0}|" -f $_ })
      $onlyRemoved = (@($miss | Where-Object { $removedKeys -notcontains $_ }).Count -eq 0) -and ($p.Name -cmatch 'HardwareSelect$')
    }
    if ($onlyRemoved) { $expected += (T "{0}: {1} (removed board)" $label $lost) } else { $bad += ("{0}: {1}" -f $label, $lost) }
  }
  Write-Ok (T "{0} values kept, {1} parameters without memory skipped" $ok $skip)
  foreach ($e in $expected) { Write-Note (T "expected: {0}" $e) }
  foreach ($b in $bad) { Write-Bad $b }
  return @{ Ok = $ok; Expected = $expected.Count; Bad = $bad.Count }
}

function Compare-Slots([string]$OldSlots, [string]$NewSlots, $Exp) {
  Write-Step (T "device query bits and board slots")
  $old = [System.IO.File]::ReadAllLines($OldSlots); $new = [System.IO.File]::ReadAllLines($NewSlots)
  $newSet = @{}; foreach ($l in $new) { $newSet[$l.Trim()] = $true }
  $n = 0
  foreach ($l in $old) {
    $t = $l.Trim()
    if ($t -match '^(cap|val)\s+\d+\s*=') {
      $n++
      if (-not $newSet.ContainsKey($t)) { Write-Bad (T "bit moved or gone: {0}" $t) }
    }
    elseif ($t -match '^0x([0-9A-Fa-f]{4})\s*=\s*(\d+)') {
      $n++
      $id = $Matches[1]; $slot = $Matches[2]
      $hit = @($new | Where-Object { $_.Trim() -match ('^0x' + $id + '\s*=\s*' + $slot + '(\s+removed)?$') })
      if ($hit.Count -eq 0) { Write-Bad (T "board slot changed: {0}" $t) }
    }
  }
  foreach ($c in @($Exp.NewCaps + $Exp.NewValues)) {
    $hit = @($new | Where-Object { $_ -match ('^\s*(cap|val)\s+\d+\s*=\s*' + $c + '\s*$') })
    if ($Exp.NewValues -contains $c) { if ($hit.Count -ne 0) { Write-Bad (T "value {0} without query must not get a bit" $c) } }
    elseif ($hit.Count -ne 1) { Write-Bad (T "new capability {0} has no bit" $c) }
  }
  Write-Ok (T "{0} recorded lines of N checked" $n)
}

# ------------------------------------------------------------------------------------------------
# main
# ------------------------------------------------------------------------------------------------

try {
  Write-Step (T "work copy: {0}" $Work)
  New-WorkCopy
  $vN = Get-AppVersion
  $kN = Invoke-Build "N"
  $slotsN = [System.IO.Path]::Combine($OutDir, ("HardwareProfile-{0}.slots" -f $vN.Text))
  Write-Step (T "changes of version N+1")
  $exp = Invoke-Changes
  if ($vN.Minor -ge 15) { throw (T "ApplicationVersion {0}: the minor version of N+1 would leave 0..15" $vN.Text) }
  $vNext = "{0}.{1}" -f $vN.Major, ($vN.Minor + 1)
  Set-AppVersion $vNext
  $kN1 = Invoke-Build "N+1"
  $slotsN1 = [System.IO.Path]::Combine($OutDir, ("HardwareProfile-{0}.slots" -f $vNext))
  $res = Compare-Apps $kN $kN1 $exp
  Compare-Slots $slotsN $slotsN1 $exp
}
catch {
  Write-Bad $_.Exception.Message
}

Write-Host ""
if ($script:Failed -gt 0) {
  Write-Host (T "Update test: {0} problem(s) - see above" $script:Failed) -ForegroundColor Red
  exit 1
}
Write-Host (T "Update test passed. For ETS: import {0}, insert a device, set values, import {1}, Aktualisieren." ([System.IO.Path]::GetFileName($kN)) ([System.IO.Path]::GetFileName($kN1))) -ForegroundColor Green
exit 0
