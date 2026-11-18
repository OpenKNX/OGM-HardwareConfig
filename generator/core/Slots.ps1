#Requires -Version 5.1
<#
Open =
-----+  Slots
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Slots.ps1

.SYNOPSIS
    Slot file (board numbers, bit order of the device query), product XML check and ETS fingerprint (version guard).

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Set-RecordedBitOrder, Get-PinParamNumber, Update-BoardSlots, Get-ProductXmls, Test-ProductXmls, Add-EtsFingerprint.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# @brief Device query bit order from the slot file (cap / val lines): the recorded names take their recorded bits, every other
#        capability / queried value follows in manifest order. Reorders $M.Capabilities and the queried entries of $M.Values
#        in place (a value with query="false" keeps its place). A recorded name the manifest no longer has stops the run.
function Set-RecordedBitOrder($M) {
  $path = [System.IO.Path]::ChangeExtension($M.ManifestPath, ".slots")
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
  $rec = @{ cap = @{}; val = @{} }
  foreach ($l in [System.IO.File]::ReadAllLines($path)) {
    if ($l -match '^\s*(cap|val)\s+(\d+)\s*=\s*([A-Za-z][A-Za-z0-9]*)\s*$') {
      $kind = $Matches[1]; $bi = [int]$Matches[2]
      if ($rec[$kind].ContainsKey($bi) -and $rec[$kind][$bi] -cne $Matches[3]) { Stop-WithError (T "Slot file {0}: {1} {2} is listed twice ('{3}' and '{4}')" $path $kind $bi ($rec[$kind][$bi]) $Matches[3]) }
      $rec[$kind][$bi] = $Matches[3]
    }
  }
  foreach ($kind in @("cap", "val")) {
    $label = @{ cap = (T "capability"); val = (T "value") }[$kind]
    if ($kind -eq "cap") { $list = $M.Capabilities } else { $list = $M.Values }
    $pos = @(); for ($j = 0; $j -lt $list.Count; $j++) { if ($kind -eq "cap" -or $list[$j].Query) { $pos += $j } }
    $byName = @{}; foreach ($j in $pos) { $byName[$list[$j].Name] = $list[$j] }
    $ordered = @(); $used = @{}
    foreach ($i in @($rec[$kind].Keys | Sort-Object)) {
      $n = $rec[$kind][$i]
      if ($used.ContainsKey($n)) { Stop-WithError (T "Slot file {0}: {1} '{2}' has two bits" $path $kind $n) }
      if (-not $byName.ContainsKey($n)) {
        $why = T "is gone from the manifest"
        $same = @($list | Where-Object { $_.Name -ceq $n })
        $case = @($list | Where-Object { $_.Name -ieq $n -and $_.Name -cne $n })
        if ($same.Count -gt 0) { $why = T "is query=`"false`" now" }
        elseif ($case.Count -gt 0) { $why = T "is spelled '{0}' now" $case[0].Name; if (-not $case[0].Query -and $kind -eq "val") { $why += (T " and query=`"false`"") } }
        Stop-WithError (T "Device query: {0} {1} '{2}' {3} - a firmware in the field still sends it at this position; keep it in the query (it may never be true); a pure rename: change the line in {4}" $label $i $n $why $path)
      }
      $ordered += $byName[$n]; $used[$n] = $true
    }
    foreach ($j in $pos) { if (-not $used.ContainsKey($list[$j].Name)) { $ordered += $list[$j] } }
    for ($k = 0; $k -lt $pos.Count; $k++) { $list[$pos[$k]] = $ordered[$k] }
  }
  if ($M.Capabilities[0].Name -cne "ThirdParty") { Stop-WithError (T "Slot file {0}: cap 0 must be ThirdParty" $path) }
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
  $etsRec = @{}
  # value sets of <Filters>: "filter <name> <v,v,...> = <slot>" (the slot is part of the ETS parameter ID of that list)
  $filterRec = @{}
  $lines = @()
  if (Test-Path $path) { $lines = [System.IO.File]::ReadAllLines($path) }
  else {
    Write-Warn (T "No slot file {0}: fine for a new product. If this product was released before, restore the file from git - new slots would move every GPIO parameter ID" $path)
  }
  for ($ln = 0; $ln -lt $lines.Count; $ln++) {
    $l = $lines[$ln]
    if ($l -match '^\s*(#.*)?$') { continue }
    if ($l -match '^\s*(cap|val)\s+(\d+)\s*=\s*([A-Za-z][A-Za-z0-9]*)\s*$') {
      $kind = $Matches[1]; $bi = [int]$Matches[2]
      if ($bitRec[$kind].ContainsKey($bi) -and $bitRec[$kind][$bi] -cne $Matches[3]) { Stop-WithError (T "Slot file {0}, line {1}: {2} {3} is listed twice" $path ($ln + 1) $kind $bi) }
      $bitRec[$kind][$bi] = $Matches[3]
      continue
    }
    if ($l -match '^\s*filter\s+([A-Za-z][A-Za-z0-9]*)\s+((?:board|capability|value):\S+)\s*=\s*(\d+)\s*$') {
      $fName = $Matches[1]; $fKey = $Matches[2]; $fSlot = [int]$Matches[3]
      if (-not $filterRec.ContainsKey($fName)) { $filterRec[$fName] = @{} }
      if ($filterRec[$fName].ContainsKey($fKey) -and $filterRec[$fName][$fKey] -ne $fSlot) { Stop-WithError (T "Slot file {0}, line {1}: filter {2} rule {3} has two slots" $path ($ln + 1) $fName $fKey) }
      if (@($filterRec[$fName].Keys | Where-Object { $_ -ne $fKey -and $filterRec[$fName][$_] -eq $fSlot }).Count -gt 0) { Stop-WithError (T "Slot file {0}, line {1}: filter {2} slot {3} is used by two rules - give the newer one the next free slot" $path ($ln + 1) $fName $fSlot) }
      $filterRec[$fName][$fKey] = $fSlot
      continue
    }
    # 'ets "<product xml>" <ApplicationVersion> <fingerprint>': content of the ETS outputs recorded for that version
    if ($l -match '^\s*ets\s+"([^"]+)"\s+(\S+)\s+([0-9A-Fa-f]{16})\s*$') {
      if ($etsRec.ContainsKey($Matches[1])) { Stop-WithError (T "Slot file {0}, line {1}: a second ets line for {2} (merge?) - keep the one of the released version" $path ($ln + 1) $Matches[1]) }
      $etsRec[$Matches[1]] = @{ Version = $Matches[2]; Hash = $Matches[3].ToUpperInvariant() }
      continue
    }
    if ($l -match '^\s*0x([0-9A-Fa-f]{4})\s*=\s*(\d+)(\s+removed)?\s*$') {
      $id = [Convert]::ToInt32($Matches[1], 16)
      if ($slots.ContainsKey($id) -and $slots[$id] -ne [int]$Matches[2]) {
        Stop-WithError (T "Slot file {0}: 0x{1:X4} has two slots ({2} and {3}) - keep the one that was released" $path $id $slots[$id] ([int]$Matches[2]))
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
      Stop-WithError (T "Slot file {0}, line {1}: '{2}' is no slot line (0x<HW-ID> = <slot> [removed], cap <n> = <Name>, val <n> = <Name>, filter <Name> <rule> = <slot>, ets `"<product xml>`" <version> <fingerprint>)" $path ($ln + 1) $l)
    }
  }
  # a merge of two branches can give two boards the same slot -> two parameters with one ID
  foreach ($g in ($slots.Keys | Group-Object { $slots[$_] } | Where-Object { $_.Count -gt 1 })) {
    Stop-WithError (T "Slot file {0}: slot {1} is used by {2} - give the newer board the next free slot" $path $g.Name (($g.Group | ForEach-Object { "0x{0:X4}" -f $_ }) -join ", "))
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
  if ($next -gt 1000) { Stop-WithError (T "Slot file {0} holds more than 1000 boards (3-digit slot in the parameter IDs)" $path) }
  # bit order: a recorded bit keeps its name; new capabilities / values are appended (a firmware in the field reads
  # the query answer by position, an inserted or removed entry would shift every later bit)
  $cur = @{ cap = @($M.Capabilities | ForEach-Object { $_.Name }); val = @($M.Values | Where-Object { $_.Query } | ForEach-Object { $_.Name }) }
  $bitsAdded = @()
  foreach ($kind in @("cap", "val")) {
    $label = @{ cap = (T "capability"); val = (T "value") }[$kind]
    $recCount = 0; foreach ($k in $bitRec[$kind].Keys) { if ($k + 1 -gt $recCount) { $recCount = $k + 1 } }
    for ($i = 0; $i -lt $recCount; $i++) {
      if (-not $bitRec[$kind].ContainsKey($i)) { Stop-WithError (T "Slot file {0}: {1} {2} is missing (the recorded bits must be 0..{3} without a gap)" $path $kind $i ($recCount - 1)) }
      $was = $bitRec[$kind][$i]
      if ($i -ge $cur[$kind].Count) { Stop-WithError (T "Device query: {0} {1} '{2}' is gone from the manifest - a firmware in the field still sends it at this position; keep it (it may never be true)" $label $i $was) }
      if ($cur[$kind][$i] -cne $was) { Stop-WithError (T "Device query: {0} {1} was '{2}', now '{3}' - the slot file and the manifest disagree; a pure rename: change the line in {4}" $label $i $was ($cur[$kind][$i]) $path) }
    }
    for ($i = $recCount; $i -lt $cur[$kind].Count; $i++) { $bitRec[$kind][$i] = $cur[$kind][$i]; $bitsAdded += ("{0} {1} = {2}" -f $kind, $i, $cur[$kind][$i]) }
  }
  # <Filters>: the rule of every board (the <Allow> that matched, or value:<n>); a rule whose list is not the full one keeps its
  # recorded slot, a new rule takes the next free; the list of a rule may change (an item added) without moving its id
  $filtersAdded = @()
  if ($M.Filters) {
    foreach ($f in $M.Filters.Items) {
      if (-not $filterRec.ContainsKey($f.Name)) { $filterRec[$f.Name] = @{} }
      $rec = $filterRec[$f.Name]
      $f.KeySets = @{}; $hitRules = @{}
      $fNext = 0; foreach ($v in $rec.Values) { if ($v -ge $fNext) { $fNext = $v + 1 } }
      foreach ($b in $Boards) {
        if (-not $b.ContainsKey("FilterKeys")) { $b.FilterKeys = @{} }
        $ch = Get-FilterBoardChoice $f $b
        $b.FilterKeys[$f.Name] = $ch.Key
        if ($ch.Rule) { $hitRules[$ch.Rule] = $true }
        if (-not $ch.Key) { continue }
        $f.KeySets[$ch.Key] = $ch.Set
        if (-not $rec.ContainsKey($ch.Key)) { $rec[$ch.Key] = $fNext; $fNext++; $filtersAdded += ("filter {0} {1}" -f $f.Name, $ch.Key) }
      }
      foreach ($k in $rec.Keys) {
        if (-not $f.Num.Token -and ([string]($f.Num.Base + $rec[$k])).Length -gt $f.Id.Width) { Stop-WithError (T "<Filter name=`"{0}`">: number {1} + slot {2} has more digits than the parameter number of ref ({3})" $f.Name $f.Num.Base $rec[$k] $f.Id.Width) }
        if ($f.Slots -gt 0 -and $rec[$k] -ge $f.Slots) { Stop-WithError (T "<Filter name=`"{0}`">: rule {1} needs slot {2}, slots=`"{3}`" leaves room for {3} list(s) - when it replaces a rule no board uses any more, write its key into that rule's line of the slot file (the id stays); raise slots only where the ids have room (never for a token number)" $f.Name $k $rec[$k] $f.Slots) }
      }
      $f.SetSlots = $rec
      $orphans = @($rec.Keys | Where-Object { -not $hitRules.ContainsKey($_) } | Sort-Object { $rec[$_] } | ForEach-Object { "{0} = {1}" -f $_, $rec[$_] })
      if ($orphans.Count -gt 0) { Write-Warn (T "<Filter name=`"{0}`">: rule(s) {1} in the slot file match no board - an edited rule: write its new key into that line (the id stays), else the slot stays reserved" $f.Name ($orphans -join ", ")) }
    }
    # every recorded slot (also of a set no board uses now) owns its parameter id: no overlap with another filter or the source
    $idOwner = @{}
    foreach ($f in $M.Filters.Items) {
      foreach ($k in $f.SetSlots.Keys) {
        $fpid = Get-FilterOwnId $f $f.SetSlots[$k] $f.Id.Prefix
        $fbody = Get-FilterIdBody $fpid
        if ($idOwner.ContainsKey($fbody)) { Stop-WithError (T "<Filter name=`"{0}`">: parameter {1} (number + slot {2}) is also used by <Filter name=`"{3}`"> - move number so the ranges do not overlap" $f.Name $fpid $f.SetSlots[$k] $idOwner[$fbody]) }
        if ($f.SourceBodies.ContainsKey((Get-FilterIdBody $fpid))) { Stop-WithError (T "<Filter name=`"{0}`">: parameter {1} (number + slot {2}) already exists in {3} - choose a free number" $f.Name $fpid $f.SetSlots[$k] $f.SourceAttr) }
        $idOwner[$fbody] = $f.Name
      }
    }
    # a filter name in the slot file that the manifest no longer has: renamed or removed - its ids may come back under the new name
    $gone = @($filterRec.Keys | Where-Object { $n = $_; @($M.Filters.Items | Where-Object { $_.Name -ceq $n }).Count -eq 0 })
    if ($gone.Count -gt 0) { Write-Warn (T "Slot file {0}: filter(s) {1} are not in the manifest - a renamed filter starts again at slot 0; keep the old name or give it a number range of its own" $path ($gone -join ", ")) }
  }
  if ($filtersAdded.Count -gt 0) { Write-Warn (T "Filter rule(s) with an own list added: {0}" ($filtersAdded -join ", ")) }
  # the board list of the ETS product changed (a pattern can do that without a manifest change)
  $hex = { param($list) ($list | ForEach-Object { "0x{0:X4}" -f $_ }) -join ", " }
  if ($added.Count -gt 0) { Write-Warn (T "Board(s) added: {0}" (& $hex $added)) }
  if ($back.Count -gt 0) { Write-Warn (T "Board(s) back: {0}" (& $hex $back)) }
  if ($gone.Count -gt 0) { Write-Warn (T "Board(s) removed, slot kept: {0} - the selection loses them: a device in a project with that board falls back to not selected after the app update; to keep a board selectable without its env, add <Board define=`"<its board define>`" flags=`"...`" />" (& $hex $gone)) }
  if ($bitsAdded.Count -gt 0 -and $bitsAdded.Count -lt ($cur.cap.Count + $cur.val.Count)) { Write-Warn (T "Device query bit(s) added: {0}" ($bitsAdded -join ", ")) }
  # a board or bit change: Add-EtsFingerprint reminds of the version (per product, or here when no product XML is found)
  $listChanged = (($added.Count + $back.Count + $gone.Count) -gt 0 -or ($bitsAdded.Count -gt 0 -and $bitsAdded.Count -lt ($cur.cap.Count + $cur.val.Count)))
  $out = New-Object System.Text.StringBuilder
  [void]$out.AppendLine("# Board slots of the GPIO role parameters (Build-HardwareProfile.ps1). Commit this file.")
  [void]$out.AppendLine("# Never edit or reuse a number: it is part of the ETS parameter ID of every GPIO role.")
  foreach ($k in ($slots.Keys | Sort-Object { $slots[$_] })) {
    $mark = ""
    if ($removed.ContainsKey($k)) { $mark = " removed" }
    [void]$out.AppendLine(("0x{0:X4} = {1}{2}" -f $k, $slots[$k], $mark))
  }
  [void]$out.AppendLine("# Bit order of the device query (firmware in the field reads by position): a name keeps its bit, new names are appended; never remove a line.")
  foreach ($kind in @("cap", "val")) {
    foreach ($i in @($bitRec[$kind].Keys | Sort-Object)) { [void]$out.AppendLine(("{0} {1} = {2}" -f $kind, $i, $bitRec[$kind][$i])) }
  }
  if ($filterRec.Count -gt 0) {
    [void]$out.AppendLine("# Rules of <Filters> with an own list: the slot is part of the ETS parameter ID of that list; never change, reuse or remove a slot (an edited rule: write its new key into its line).")
    foreach ($fName in @($filterRec.Keys | Sort-Object)) {
      foreach ($k in @($filterRec[$fName].Keys | Sort-Object { $filterRec[$fName][$_] })) { [void]$out.AppendLine(("filter {0} {1} = {2}" -f $fName, $k, $filterRec[$fName][$k])) }
    }
  }
  # written with the other outputs, after all of them rendered (an error before that leaves the old slot file);
  # the ets line is added there (Add-EtsFingerprint), it needs the rendered outputs
  return @{ Output = $path; Text = $out.ToString(); Ets = $etsRec; ListChanged = $listChanged }
}
# @brief Product XMLs of the OAM: *.xml with an <op:ETS element (not *.debug.xml) in the folder of the generated share (else
#        <manifest dir>/src); comments and CDATA blanked with the line breaks kept, so positions still give the line number
function Get-ProductXmls($M) {
  $dirs = @()
  if ($M.Outputs.ContainsKey("share")) { $dirs += [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($M.Outputs["share"])) }
  $dirs += [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($M.ManifestPath), "src")
  foreach ($dir in $dirs) {
    $list = @()
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
    [string[]]$files = @(Get-ChildItem -LiteralPath $dir -Filter "*.xml" -File | Where-Object { $_.Name -notlike "*.debug.xml" } | ForEach-Object { $_.FullName })
    [Array]::Sort($files, [StringComparer]::Ordinal)
    foreach ($f in $files) {
      $raw = [System.IO.File]::ReadAllText($f)
      if (-not $raw.Contains("<op:ETS")) { continue }
      $text = [regex]::Replace($raw, '(?s)<!\[CDATA\[.*?\]\]>|<!--.*?-->', { param($x) [regex]::Replace($x.Value, '[^\n]', ' ') })
      $ets = [regex]::Match($text, '<op:ETS\b' + $script:XmlAttrs + '>')
      if (-not $ets.Success) { continue }   # <op:ETS only inside a comment: no product
      $ver = $null
      if ($ets.Value -match '\bApplicationVersion\s*=\s*["'']([^"'']*)["'']') { $ver = $Matches[1].Trim() }
      # content for the version check: without comments (CDATA = scripts stays), white space runs as one blank
      $content = [regex]::Replace($raw, '(?s)(<!\[CDATA\[.*?\]\]>)|<!--.*?-->', { param($x) if ($x.Groups[1].Success) { $x.Value } else { "" } })
      $content = [regex]::Replace($content, '\s+', ' ').Trim()
      $list += @{ Path = $f; Name = [System.IO.Path]::GetFileName($f); Text = $text; Version = $ver; Content = $content }
    }
    if ($list.Count -gt 0) { return ,$list }
  }
  return ,@()
}
# attributes of a start tag: quoted values may hold ">" (valid XML)
$script:XmlAttrs = '(?:[^>"'']|"[^"]*"|''[^'']*'')*'
# @brief Warns when a product XML does not include the hardware module as the manifest describes it: op:define of the share
#        with prefix and ModuleType, and a page block of the application (include of the Profile block children) without
#        the tree text of <Page unselectedTitle>. Warnings only: an OAM may compose the page in its own way.
function Test-ProductXmls($M, $Products) {
  if (-not $M.Outputs.ContainsKey("share") -or $Products.Count -eq 0) { return }
  $share = [System.IO.Path]::GetFullPath($M.Outputs["share"])
  $p = [regex]::Escape($M.Prefix)
  foreach ($x in $Products) {
    $dir = [System.IO.Path]::GetDirectoryName($x.Path)
    $isShare = { param($href) [string]::Equals([System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dir, ($href -replace '\\', '/'))), $share, [StringComparison]::OrdinalIgnoreCase) }
    $def = $null
    foreach ($d in [regex]::Matches($x.Text, '<op:define\b' + $script:XmlAttrs + '>')) {
      if ($d.Value -match '\bshare\s*=\s*["'']([^"'']+)["'']' -and (& $isShare $Matches[1])) { $def = $d; break }
    }
    if (-not $def) { Write-Warn (T "{0}: no <op:define share=...> of the hardware module {1}" $x.Name ([System.IO.Path]::GetFileName($share))); continue }
    $at = "{0}:{1}" -f $x.Name, (Get-LineNumber $x.Text $def.Index)
    if ($def.Value -cnotmatch ('\bprefix\s*=\s*["'']' + $p + '["'']')) { Write-Warn (T "{0}: op:define of the hardware module has another prefix than the manifest ({1})" $at $M.Prefix) }
    if ($def.Value -notmatch '\bModuleType\s*=\s*["'']\s*(\d+)\s*["'']' -or [int]$Matches[1] -ne $M.ModuleType) { Write-Warn (T "{0}: op:define of the hardware module has another ModuleType than the manifest ({1})" $at $M.ModuleType) }
    foreach ($inc in [regex]::Matches($x.Text, '<op:include\b' + $script:XmlAttrs + '>')) {
      # xpath ...ParameterBlock[@Name='Profile']/* (quote ' or &quot;, blanks allowed)
      if ($inc.Value -notmatch "ParameterBlock\[\s*@Name\s*=\s*('|&quot;|`")Profile('|&quot;|`")\s*\]/\*") { continue }
      if ($inc.Value -notmatch '\bhref\s*=\s*["'']([^"'']+)["'']' -or -not (& $isShare $Matches[1])) { continue }
      # the enclosing block: the ParameterBlock still open at the include (stack over open / self-closing / close tags)
      $stack = New-Object System.Collections.Generic.List[object]
      foreach ($t in [regex]::Matches($x.Text.Substring(0, $inc.Index), ('<ParameterBlock\b' + $script:XmlAttrs + '>|</ParameterBlock\s*>'))) {
        if ($t.Value.StartsWith("</")) { if ($stack.Count -gt 0) { $stack.RemoveAt($stack.Count - 1) } }
        elseif (-not $t.Value.EndsWith("/>")) { $stack.Add($t) }
      }
      if ($stack.Count -eq 0) { continue }
      $blk = $stack[$stack.Count - 1]
      $bat = "{0}:{1}" -f $x.Name, (Get-LineNumber $x.Text $blk.Index)
      $hasRef = $blk.Value -cmatch ('\bTextParameterRefId\s*=\s*["'']%' + $p + '_PageTextRef%["'']')
      $hasText = $blk.Value -cmatch ('\bText\s*=\s*["'']\{\{0:%' + $p + '_PageText%\}\}["'']')
      if ($M.Page -and $M.Page.UnselectedTitle) {
        if (-not ($hasRef -and $hasText)) {
          Write-Warn (T "{0}: page block without Text=`"{{{{0:%{1}_PageText%}}}}`" TextParameterRefId=`"%{1}_PageTextRef%`" - the tree shows no `"{2}`" (README, Applikations-XML)" $bat $M.Prefix $M.Page.UnselectedTitle)
        }
      }
      elseif ($hasRef) { Write-Warn (T "{0}: page block uses %{1}_PageTextRef%, but <Page unselectedTitle> is off (no such config)" $bat $M.Prefix) }
    }
  }
}
# @brief Appends the ets lines to the slot file text: per product XML its ApplicationVersion and a fingerprint of the ETS
#        outputs it gets (all rendered outputs except C/C++ files, the pictures and the page icon; the developer view only
#        for the product that includes it) and of the product XML itself (without comments; included lib files do not
#        count). The line follows the product's version: a new version records the current
#        content; under the recorded version a content change warns on every run until the version is raised.
function Add-EtsFingerprint($M, $SlotFile, $Rendered, $Images, $Products) {
  $base = [System.IO.Path]::GetDirectoryName($M.ManifestPath)
  $rec = $SlotFile.Ets
  $devFull = $null
  if ($M.Page -and $M.Page.Dev) { $devFull = [System.IO.Path]::GetFullPath($M.Page.Dev) }
  $hashes = @{}
  try {
    $items = @{}; $devKey = $null
    foreach ($r in $Rendered) {
      if (@(".h", ".hpp", ".c", ".cpp") -contains [System.IO.Path]::GetExtension($r.Output).ToLowerInvariant()) { continue }
      $key = Get-RelativeOutputPath $base $r.Output
      if ($devFull -and [string]::Equals([System.IO.Path]::GetFullPath($r.Output), $devFull, [StringComparison]::OrdinalIgnoreCase)) { $devKey = $key }
      $items[$key] = @{ Head = ""; Bytes = [System.Text.Encoding]::UTF8.GetBytes(($r.Text -replace "`r`n", "`n")) }
    }
    foreach ($r in $Images) { $items[(Get-RelativeOutputPath $base $r.Output)] = @{ Head = ("{0}x{1}" -f $r.Image.Width, $r.Image.Height); Bytes = $r.Image.Pixels } }
    if ($M.Page -and $M.Page.IconFile) {
      $iconOut = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($M.Outputs["share"]), "Baggages", "Icons", $M.Page.Icon + ".png")
      $items[(Get-RelativeOutputPath $base $iconOut)] = @{ Head = "file"; Bytes = [System.IO.File]::ReadAllBytes($M.Page.IconFile) }
    }
    foreach ($x in $Products) {
      if (-not $x.Version) { continue }
      $withDev = $devKey -and $x.Text.Contains([System.IO.Path]::GetFileName($devFull))
      [string[]]$names = @($items.Keys | Where-Object { $withDev -or $_ -ne $devKey })
      [Array]::Sort($names, [StringComparer]::Ordinal)
      $ms = New-Object System.IO.MemoryStream
      foreach ($n in $names) {
        $it = $items[$n]
        $nb = [System.Text.Encoding]::UTF8.GetBytes(("{0}`n{1} {2}`n" -f $n, $it.Head, $it.Bytes.Length))
        $ms.Write($nb, 0, $nb.Length); $ms.Write($it.Bytes, 0, $it.Bytes.Length)
      }
      # the product XML itself (e.g. an Assign or a configTransferName there): its own content counts for its own line
      $pb = [System.Text.Encoding]::UTF8.GetBytes($x.Content)
      $nb = [System.Text.Encoding]::UTF8.GetBytes(("product:{0}`nfile {1}`n" -f $x.Name, $pb.Length))
      $ms.Write($nb, 0, $nb.Length); $ms.Write($pb, 0, $pb.Length)
      $hashes[$x.Name] = (Get-PngSha256 $ms.ToArray()).Replace("-", "").Substring(0, 16).ToUpperInvariant()
    }
  }
  catch {
    # e.g. a FIPS policy that blocks the hash: no check, the recorded lines stay
    Write-Warn (T "ETS fingerprint not available ({0}): the version check is skipped" $_.Exception.Message)
    $hashes = $null
  }
  $next = @{}
  $versioned = @($Products | Where-Object { $_.Version })
  if ($null -eq $hashes -or ($versioned.Count -eq 0 -and $rec.Count -gt 0)) {
    # no fingerprint, or no product XML found: keep what was recorded
    if ($null -ne $hashes) { Write-Warn (T "No product XML with <op:ETS ApplicationVersion> found (folder of the share, <manifest>/src): the version check is skipped, the ets lines stay") }
    foreach ($k in $rec.Keys) { $next[$k] = $rec[$k] }
  }
  else {
    foreach ($x in $versioned) {
      $h = $hashes[$x.Name]
      $old = $rec[$x.Name]
      # a new version (or a product seen for the first time) takes the current content; under the recorded version the
      # recorded content stays and a change warns on every run until the version is raised
      if (-not $old -or $old.Version -cne $x.Version) { $next[$x.Name] = @{ Version = $x.Version; Hash = $h } }
      else {
        $next[$x.Name] = $old
        if ($old.Hash -cne $h) {
          Write-Warn (T "The ETS content changed since {0} ApplicationVersion {1} was recorded: raise the version (ReplacesVersionsDownTo) before this content ships, or ETS gets other content under the same version (repeats until then)" $x.Name $x.Version)
        }
      }
    }
  }
  if ($SlotFile.ListChanged -and ($versioned.Count -eq 0 -or $null -eq $hashes)) {
    Write-Warn (T "The ETS content changed: raise the ApplicationVersion (ReplacesVersionsDownTo), or ETS treats it as the same version")
  }
  [string[]]$keys = @($next.Keys)
  [Array]::Sort($keys, [StringComparer]::Ordinal)
  if ($keys.Count -eq 0) { return }
  $SlotFile.Text += "# ETS content per product XML: ets `"<file>`" <ApplicationVersion> <fingerprint>; kept until the version changes`n"
  foreach ($k in $keys) { $SlotFile.Text += ("ets `"{0}`" {1} {2}`n" -f $k, $next[$k].Version, $next[$k].Hash) }
}
