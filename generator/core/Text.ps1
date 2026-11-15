#Requires -Version 5.1
<#
Open =
-----+  Text
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Text.ps1

.SYNOPSIS
    Text, file and path helpers (UTF-8 files, XML/JS escaping, ordinal sort, wildcards).

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Get-OrdinalSorted, Write-Utf8File, Update-Utf8File, ConvertTo-XmlText, ConvertTo-JsString, Get-LineNumber, Get-RelativeOutputPath, Get-RelativePath, ConvertTo-XmlComment, Test-Wildcard, Split-SentenceText, Get-FileContentHash.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# @brief Ordinal, stable sort (same order on PowerShell 5.1 and 7 in every culture); -Unique drops equal keys (case-sensitive)
function Get-OrdinalSorted($Items, [scriptblock]$Key = $null, [switch]$Unique) {
  $arr = @(foreach ($x in $Items) { $x })   # foreach, not @($Items): @() on a generic List throws on PowerShell 7.6
  if ($arr.Count -eq 0) { return }
  $keys = New-Object 'string[]' $arr.Count
  $comp = New-Object 'string[]' $arr.Count
  $idx = New-Object 'int[]' $arr.Count
  for ($i = 0; $i -lt $arr.Count; $i++) {
    if ($Key) { $keys[$i] = [string](ForEach-Object -InputObject $arr[$i] -Process $Key) } else { $keys[$i] = [string]$arr[$i] }
    $comp[$i] = $keys[$i] + [char]0 + $i.ToString("D8"); $idx[$i] = $i
  }
  [Array]::Sort($comp, $idx, [StringComparer]::Ordinal)
  $last = $null
  for ($k = 0; $k -lt $idx.Count; $k++) {
    $i = $idx[$k]
    if ($Unique -and $k -gt 0 -and [string]::Equals($keys[$i], $last, [StringComparison]::Ordinal)) { continue }
    $last = $keys[$i]
    $arr[$i]
  }
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
# Board evaluation
# ------------------------------------------------------------------------------------------------
function Test-Wildcard([string]$Pattern, [string]$Text) {
  return ($Text -like $Pattern)
}
function Get-LineNumber([string]$Text, [int]$Index) { return ([regex]::Matches($Text.Substring(0, $Index), "`n")).Count + 1 }
# @brief Path of $Path relative to $BaseDir with / separators ("../" when outside), independent of the checkout location
function Get-RelativeOutputPath([string]$BaseDir, [string]$Path) {
  $b = @([System.IO.Path]::GetFullPath($BaseDir).TrimEnd('\', '/') -split '[\\/]')
  $p = @([System.IO.Path]::GetFullPath($Path) -split '[\\/]')
  $i = 0
  while ($i -lt $b.Count -and $i -lt $p.Count -and [string]::Equals($b[$i], $p[$i], [StringComparison]::OrdinalIgnoreCase)) { $i++ }
  $parts = @()
  for ($k = $i; $k -lt $b.Count; $k++) { $parts += ".." }
  for ($k = $i; $k -lt $p.Count; $k++) { $parts += $p[$k] }
  return ($parts -join "/")
}
# @brief Pictures above the device card name: per board the file of a matching <InfoImage><Logo>, else the badge (third-party
#        board) or the logo; boards grouped by file. Logo 00900, Badge 00901, own files Logo1..Logo10 = 00910..00919.
#        A board without picture ("" file) is in no group.
# @brief Content of a picture file as comparison key (the files are a few kB; no hash API, which FIPS policy can block)
function Get-FileContentHash([string]$Path) {
  return [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))
}
# @brief Text split into parts of at most MaxLen characters at sentence ends (ETS: 255 characters per text)
function Split-SentenceText([string]$Text, [int]$MaxLen = 255) {
  $parts = New-Object System.Collections.Generic.List[string]
  $cur = ""
  foreach ($sent in ($Text -split '(?<=[.!?])\s+')) {
    if (-not $sent) { continue }
    if ($sent.Length -gt $MaxLen) { throw (T "a sentence is longer than {0} characters: {1}" $MaxLen $sent) }
    if ($cur -and ($cur.Length + 1 + $sent.Length) -gt $MaxLen) { $parts.Add($cur); $cur = "" }
    if ($cur) { $cur = $cur + " " + $sent } else { $cur = $sent }
  }
  if ($cur) { $parts.Add($cur) }
  return ,$parts.ToArray()
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
