#Requires -Version 5.1
<#
Open =
-----+  BoardCache
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/BoardCache.ps1

.SYNOPSIS
    Cache of the board step (PlatformIO envs and board headers): reused while none of its inputs changed.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Get-PioProjectConfigText, Get-BoardCachePath, Get-FileStamp, Add-BoardCacheInput, Get-BoardCacheKey,
    Read-BoardCache, Save-BoardCache, ConvertFrom-CachedValue.
    The key lists every input of the step: manifest, slot file, imports, generator and include files, board table
    headers (path, size, write time each), the output of "pio project config", the PlatformIO packages and platforms,
    the switches, the preprocessor found. Files the step reads outside these folders (board manifests and Arduino variant
    pins of PlatformIO) are recorded while it runs and checked again on a hit. Not seen: a change that keeps size and
    write time of a file (cp -p, unpacking) and headers a board table header includes from another folder (-NoCache).
    No hash function (a FIPS policy can block them on Windows): the key text itself is compared.
    The cache lives in <project>/.pio/hw-profiler (only when the project has a .pio folder); -Check, -Detailed and
    -NoCache always run the step.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

$script:BoardCacheVersion = "2"

# @brief Output of "pio project config --json-output" for a project folder, once per run (the board step and the cache key)
function Get-PioProjectConfigText([string]$ProjectDir, $Pio) {
  if ($null -eq $script:PioConfigText) { $script:PioConfigText = @{} }
  $k = [System.IO.Path]::GetFullPath($ProjectDir)
  if ($script:PioConfigText.ContainsKey($k)) { return $script:PioConfigText[$k] }
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  # the JSON is ASCII (json.dumps escapes every other character), so the console code page does not matter
  try {
    $raw = @(& $Pio project config --json-output -d $ProjectDir 2>&1)
    $exitCode = $LASTEXITCODE
  }
  finally { $ErrorActionPreference = $prevEap }
  $json = @($raw | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
  if ($exitCode -ne 0) {
    $why = (@($raw | ForEach-Object { "$_" }) | Where-Object { $_ } | Select-Object -Last 3) -join " | "
    Stop-WithError (T "pio project config failed in {0}: {1}" $ProjectDir $why)
  }
  $text = @($json) -join "`n"
  $script:PioConfigText[$k] = $text
  return $text
}

# @brief "file <path> <size> <write time>" or "none <path>": the stamp of one input file
function Get-FileStamp([string]$Path) {
  if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
    $fi = New-Object System.IO.FileInfo $Path
    return ("file {0} {1} {2}" -f $fi.FullName, $fi.Length, $fi.LastWriteTimeUtc.Ticks)
  }
  return ("none " + $Path)
}
# @brief Records the stamp of a file the board step reads (also one it looked for and did not find) at the time it reads it,
#        so a file replaced while the step runs does not get stamped onto the older result
function Add-BoardCacheInput([string]$Path) {
  if ($null -eq $script:BoardCacheInputs -or -not $Path) { return }
  $st = Get-FileStamp $Path
  if (-not $script:BoardCacheInputs.Contains($st)) { [void]$script:BoardCacheInputs.Add($st) }
}

# @brief Cache file of a manifest: <project>/.pio/hw-profiler/<manifest name>.boards.xml; $null without a .pio folder
function Get-BoardCachePath([string]$ManifestPath) {
  $dir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($ManifestPath))
  if ([System.IO.Path]::GetFileName($dir) -ceq "src") { $dir = [System.IO.Path]::GetDirectoryName($dir) }
  $pioDir = [System.IO.Path]::Combine($dir, ".pio")
  if (-not (Test-Path -LiteralPath $pioDir -PathType Container)) { return $null }
  return [System.IO.Path]::Combine($pioDir, "hw-profiler", ([System.IO.Path]::GetFileNameWithoutExtension($ManifestPath) + ".boards.xml"))
}

# @brief Key text of the board step: one line per input (file: path, size, write time; pio: the config output)
function Get-BoardCacheKey($M, [string]$ManifestPath) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("version " + $script:BoardCacheVersion + " " + $SCRIPT_VERSION)
  [void]$sb.AppendLine("ps " + $PSVersionTable.PSVersion.ToString() + " language " + $Language + " compiler " + $Compiler + " include " + $HardwareConfigInclude)
  $stamp = { param([string]$Path) [void]$sb.AppendLine((Get-FileStamp $Path)) }
  # the outputs of the generator itself (e.g. the firmware header in an include folder) are no input of the step
  $own = @{}
  foreach ($o in @($M.Outputs.Values)) { if ($o) { $own[[System.IO.Path]::GetFullPath("$o")] = $true } }
  $stampDir = {
    param([string]$Dir, [string]$Filter)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { [void]$sb.AppendLine("nodir " + $Dir); return }
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -Filter $Filter -File -Recurse | Sort-Object FullName)) {
      if ($own.ContainsKey($f.FullName)) { continue }
      [void]$sb.AppendLine(("file {0} {1} {2}" -f $f.FullName, $f.Length, $f.LastWriteTimeUtc.Ticks))
    }
  }
  $full = [System.IO.Path]::GetFullPath($ManifestPath)
  # the preprocessor found for this run (-Compiler or PATH): its file
  $cc = Get-Command $script:DefaultCompiler -ErrorAction SilentlyContinue
  if ($cc -and $cc.Source) { & $stamp $cc.Source } else { [void]$sb.AppendLine("compiler " + $script:DefaultCompiler) }
  & $stamp $full
  & $stamp ([System.IO.Path]::ChangeExtension($full, ".slots"))
  # imported capability packs
  try {
    [xml]$doc = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
    foreach ($imp in @($doc.DocumentElement.SelectNodes("Import"))) {
      & $stamp ([System.IO.Path]::GetFullPath([System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($full), $imp.GetAttribute("href"))))
    }
  } catch { [void]$sb.AppendLine("imports unreadable") }
  # generator (without the self-test) and every include folder (board headers, logos)
  foreach ($d in @("core", "helpers", "capabilities", "templates", "assets")) { & $stampDir ([System.IO.Path]::Combine($script:GeneratorDir, $d)) "*" }
  & $stamp ([System.IO.Path]::Combine($script:GeneratorDir, "Build-HardwareProfile.ps1"))
  foreach ($inc in @($script:IncludeDirs)) { & $stampDir $inc "*" }
  # board table headers: the header and every header next to it
  foreach ($t in @($M.BoardTables)) { & $stampDir ([System.IO.Path]::GetDirectoryName($t.Header)) "*.h" }
  # PlatformIO: the envs with their flags, the board folder of the project, installed packages and platforms (toolchains, board manifests)
  foreach ($pat in @($M.EnvPatterns)) {
    [void]$sb.AppendLine("pio " + $pat.Project)
    [void]$sb.AppendLine((Get-PioProjectConfigText $pat.Project (Get-PioCommand)))
    & $stampDir ([System.IO.Path]::Combine($pat.Project, "boards")) "*.json"
  }
  foreach ($sub in @("packages", "platforms")) {
    $pd = [System.IO.Path]::Combine((Get-PioCoreDir), $sub)
    if (Test-Path -LiteralPath $pd -PathType Container) {
      foreach ($e in @(Get-ChildItem -LiteralPath $pd -Directory | Sort-Object Name)) { [void]$sb.AppendLine(("pkg {0} {1}" -f $e.Name, $e.LastWriteTimeUtc.Ticks)) }
    }
  }
  return $sb.ToString()
}

# @brief Deserialized value back to the shapes the generator builds: ArrayList -> object[], nested hashtables and lists too
function ConvertFrom-CachedValue($Value) {
  if ($null -eq $Value) { return $null }
  if ($Value -is [System.Collections.Specialized.OrderedDictionary]) {
    $o = [ordered]@{}
    foreach ($k in @($Value.Keys)) { $o[$k] = ConvertFrom-CachedValue $Value[$k] }
    return $o
  }
  if ($Value -is [System.Collections.Hashtable]) {
    $h = @{}
    foreach ($k in @($Value.Keys)) { $h[$k] = ConvertFrom-CachedValue $Value[$k] }
    return $h
  }
  if ($Value -is [System.Collections.ArrayList]) {
    $a = New-Object object[] $Value.Count
    for ($i = 0; $i -lt $Value.Count; $i++) { $a[$i] = ConvertFrom-CachedValue $Value[$i] }
    # the comma keeps an array of one element (or none) an array for the caller
    return , $a
  }
  return $Value
}

# @brief Cached result of the board step for this key, else $null: @{ Boards; EnvCount; Warnings }
function Read-BoardCache([string]$Path, [string]$Key) {
  if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  try { $c = Import-Clixml -LiteralPath $Path }
  catch { return $null }
  if ($null -eq $c -or "$($c.Key)" -cne $Key) { return $null }
  # files the step read outside the key folders: every stamp as recorded
  foreach ($line in @($c.Inputs)) {
    $p = "$line" -replace '^(file|none) ', ''
    if ("$line" -match '^file ') { $p = ($p -replace ' \d+ \d+$', '') }
    if ((Get-FileStamp $p) -cne "$line") { return $null }
  }
  # ConvertFrom-CachedValue returns a list as one array object: no @() around it (that would nest it)
  $bs = ConvertFrom-CachedValue $c.Boards
  $ws = ConvertFrom-CachedValue $c.Warnings
  if ($null -eq $bs) { return $null }
  if ($null -eq $ws) { $ws = New-Object object[] 0 }
  return @{ Boards = $bs; EnvCount = [int]$c.EnvCount; Warnings = $ws }
}

# @brief Stores the result of the board step with its key (a failed write only costs the next run its time)
function Save-BoardCache([string]$Path, [string]$Key, $Found, [string[]]$Warnings, [string[]]$Inputs) {
  if (-not $Path) { return }
  # $Inputs: stamps taken while the step read the files (Add-BoardCacheInput)
  $stamps = @(@($Inputs) | Where-Object { $_ })
  try {
    $dir = [System.IO.Path]::GetDirectoryName($Path)
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    @{ Key = $Key; Boards = @($Found.Boards); EnvCount = $Found.EnvCount; Warnings = @($Warnings); Inputs = $stamps } | Export-Clixml -LiteralPath $Path -Depth 30
  }
  catch { Write-Warn (T "board cache not written ({0}): {1}" $Path $_.Exception.Message) }
}
