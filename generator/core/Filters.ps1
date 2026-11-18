#Requires -Version 5.1
<#
Open =
-----+  Filters
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Filters.ps1

.SYNOPSIS
    Selection lists filtered per board (<Filters>): an existing dropdown offers only the values the selected board allows.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    ETS cannot hide single items of a list, so every value set gets its own ParameterType and a parameter without memory
    that copies the chosen value into the existing parameter (the carrier, <Assign> source): only the carrier holds memory,
    a choose on it, a calculation on it, the conflict check and the firmware keep reading it (measured in ETS6: a value set by
    <Assign> runs the calculations of the carrier). Boards that allow every value show the carrier.
    The carrier may sit in a channel template or a part: its id may hold producer tokens (%TT%, %CC%, %PPP+n%); the generated
    parameters take the same prefix and the number from <Filter number> (digits or a token like %PPP+19%), so the product
    includes them into the same template or part.
    Functions: Split-FilterRef, ConvertFrom-FilterValueList, Get-FilterNumber, Get-FilterTokenStride, Get-FilterIdBody,
    Get-FilterOwnId, Read-FilterSource, Get-FilterValues, Get-FilterKey, Get-FilterBoardChoice, Test-FilterConflictIds,
    Add-FilterChoose, New-FiltersXml.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

# @brief A ParameterRef id split into kind (UP/P), prefix (module and channel: digits or tokens), parameter number (digits or
#        a token like %PPP+0%) and ref suffix; $null when the id has no such form. Leading tokens are prefix; digits after a
#        token are the number; an id of digits only has a two-digit module prefix.
function Split-FilterRef([string]$Ref) {
  if ($Ref -cnotmatch '^%AID%_(UP|P)-(.+)_R-(.+)$') { return $null }
  $kind = $Matches[1]; $body = $Matches[2]; $rb = $Matches[3]
  if (-not $rb.StartsWith($body) -or $rb.Length -ne $body.Length + 2 -or $rb.Substring($body.Length) -notmatch '^\d{2}$') { return $null }
  $suffix = $rb.Substring($body.Length)
  $mt = [regex]::Match($body, '^((?:%[A-Za-z_][A-Za-z0-9_]*%)*)(.*)$')
  $prefix = $mt.Groups[1].Value; $rest = $mt.Groups[2].Value
  if ($rest -cmatch '^%([A-Za-z_][A-Za-z0-9_]*)(\+(\d+))?%$') {
    return @{ Kind = $kind; Prefix = $prefix; Number = $rest; Token = $Matches[1]; Base = [int]("0" + $Matches[3]); Width = 0; Suffix = $suffix; Param = "%AID%_$kind-$body" }
  }
  if ($rest -notmatch '^\d+$') { return $null }
  if (-not $prefix) { if ($rest.Length -lt 4) { return $null }; $prefix = $rest.Substring(0, 2); $rest = $rest.Substring(2) }
  return @{ Kind = $kind; Prefix = $prefix; Number = $rest; Token = $null; Base = [int]$rest; Width = $rest.Length; Suffix = $suffix; Param = "%AID%_$kind-$body" }
}

# @brief Value list of <Allow values|except>: numbers and ranges a-b separated by blanks or line breaks; "@file" reads them from
#        a file relative to the manifest ("#" starts a comment there)
function ConvertFrom-FilterValueList([string]$Text, [string]$BaseDir, [string]$Where) {
  $t = $Text.Trim()
  if ($t.StartsWith("@")) {
    $path = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($BaseDir, $t.Substring(1)))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Stop-WithError (T "{0}: value file not found: {1}" $Where $path) }
    $t = (@([System.IO.File]::ReadAllLines($path) | ForEach-Object { ($_ -replace '#.*$', '') }) -join " ")
  }
  $vals = @()
  foreach ($tok in ($t -split '\s+' | Where-Object { $_ })) {
    if ($tok -match '^(\d+)-(\d+)$' -and [int]$Matches[1] -le [int]$Matches[2]) { $vals += @([int]$Matches[1]..[int]$Matches[2]) }
    elseif ($tok -match '^\d+$') { $vals += [int]$tok }
    else { Stop-WithError (T "{0}: values must be numbers or ranges a-b separated by blanks, got '{1}'" $Where $tok) }
  }
  return , @($vals)
}

# @brief Parameter number of the value set in slot Slot: digits padded to the width of the carrier number, or the token with
#        its offset raised by the slot (%PPP+19% + 1 = %PPP+20%)
function Get-FilterNumber($Item, [int]$Slot) {
  if ($Item.Num.Token) {
    $o = $Item.Num.Base + $Slot
    if ($o -eq 0) { return "%{0}%" -f $Item.Num.Token }
    return "%{0}+{1}%" -f $Item.Num.Token, $o
  }
  return ([string]($Item.Num.Base + $Slot)).PadLeft($Item.Id.Width, '0')
}

# @brief Id step of the part token of a filter number: the increment of <op:param name="%TOKEN%"> in every op:part that includes
#        one of the source files (XML files in the folders of the sources, not *.debug.xml); the smallest of several; 0 = none
function Get-FilterTokenStride($Item) {
  $names = @($Item.Sources | ForEach-Object { [System.IO.Path]::GetFileName($_.Full) })
  $stride = 0
  foreach ($dir in @(Get-OrdinalSorted @($Item.Sources | ForEach-Object { [System.IO.Path]::GetDirectoryName($_.Full) }) -Unique)) {
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter "*.xml" -File)) {
      if ($f.Name -like "*.debug.xml") { continue }
      $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
      if (-not $text.Contains("op:part")) { continue }
      $x = New-Object System.Xml.XmlDocument
      try { $x.LoadXml($text) } catch { continue }
      foreach ($p in $x.SelectNodes("//*[local-name()='part']")) {
        if ($names -notcontains [System.IO.Path]::GetFileName($p.GetAttribute("href"))) { continue }
        foreach ($q in $p.SelectNodes("*[local-name()='param']")) {
          if ($q.GetAttribute("name") -cne ("%" + $Item.Num.Token + "%")) { continue }
          $inc = 0
          if ([int]::TryParse($q.GetAttribute("increment"), [ref]$inc) -and $inc -gt 0 -and ($stride -eq 0 -or $inc -lt $stride)) { $stride = $inc }
        }
      }
    }
  }
  return $stride
}

# @brief Id body for comparisons: without %AID%_ and kind (UP-/P-), token offsets as numbers (%X+019% = %X+19%, %X+0% = %X%)
function Get-FilterIdBody([string]$Id) {
  $b = $Id -replace '^%AID%_(UP|P)-', ''
  return [regex]::Replace($b, '%([A-Za-z_][A-Za-z0-9_]*)\+(\d+)%', [System.Text.RegularExpressions.MatchEvaluator] {
    param($m) $o = [int]$m.Groups[2].Value; if ($o -eq 0) { "%" + $m.Groups[1].Value + "%" } else { "%{0}+{1}%" -f $m.Groups[1].Value, $o } })
}

# @brief Id of the generated parameter of slot Slot (no memory: kind P) for a prefix (the carrier's or a row's)
function Get-FilterOwnId($Item, [int]$Slot, [string]$Prefix) { return "%AID%_P-{0}{1}" -f $Prefix, (Get-FilterNumber $Item $Slot) }

# @brief Carrier of one <Filter> from its source files: the Parameter, its ParameterType (enumeration) and every ParameterRef of
#        the parameter (mirrored for the generated parameters: suffix and attributes such as Access); checks the <Row> refs;
#        stops when the parameter or its type is not found or the type is no enumeration
function Read-FilterSource($Item) {
  $where = "<Filter name=`"{0}`">" -f $Item.Name
  $pars = @(); $typeNodes = @(); $refNodes = @(); $Item.SourceIds = @{}; $Item.SourceBodies = @{}; $Item.Includes = @{}
  $docs = @()
  foreach ($sf in $Item.Sources) {
    $doc = New-Object System.Xml.XmlDocument
    try { $doc.LoadXml([System.IO.File]::ReadAllText($sf.Full, [System.Text.Encoding]::UTF8)) }
    catch { Stop-WithError (T "{0}: source {1} is not readable as XML: {2}" $where $sf.Attr $_.Exception.Message) }
    $docs += $doc
    # files whose parameters land in the module of this source (include of the Parameters block)
    foreach ($q in $doc.SelectNodes("//*[local-name()='include']")) {
      if ($q.GetAttribute("xpath") -match "@name\s*=\s*['`"]Parameters['`"]") { $Item.Includes[[System.IO.Path]::GetFileName($q.GetAttribute("href"))] = $sf.Attr }
    }
    foreach ($q in $doc.SelectNodes("//*[local-name()='Parameter']")) {
      $Item.SourceIds[$q.GetAttribute("Id")] = $true
      $Item.SourceBodies[(Get-FilterIdBody $q.GetAttribute("Id"))] = $true
      if ($q.GetAttribute("Id") -ceq $Item.Param) { $pars += $q }
    }
    foreach ($q in $doc.SelectNodes("//*[local-name()='ParameterRef']")) { if ($q.GetAttribute("RefId") -ceq $Item.Param) { $refNodes += $q } }
  }
  if ($pars.Count -ne 1) { Stop-WithError (T "{0}: source {1} has {2} Parameter with Id {3} (needs exactly one)" $where $Item.SourceAttr $pars.Count $Item.Param) }
  $p = $pars[0]
  $typeId = $p.GetAttribute("ParameterType")
  foreach ($doc in $docs) { $typeNodes += @($doc.SelectNodes("//*[local-name()='ParameterType']") | Where-Object { $_.GetAttribute("Id") -ceq $typeId }) }
  if ($typeNodes.Count -ne 1) { Stop-WithError (T "{0}: the type {1} of the parameter is not defined in {2} (the filter copies its items from there)" $where $typeId $Item.SourceAttr) }
  $tr = @($typeNodes[0].ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
  if ($tr.Count -ne 1 -or $tr[0].LocalName -cne "TypeRestriction" -or $tr[0].GetAttribute("Base") -cne "Value") {
    Stop-WithError (T "{0}: the type {1} is no enumeration (TypeRestriction Base=`"Value`")" $where $typeId)
  }
  $enums = @()
  foreach ($e in $tr[0].ChildNodes) {
    if ($e.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
    if ($e.LocalName -cne "Enumeration") { Stop-WithError (T "{0}: the type {1} holds <{2}>, only <Enumeration> can be filtered" $where $typeId $e.LocalName) }
    $iv = 0
    if (-not [int]::TryParse($e.GetAttribute("Value"), [ref]$iv)) { Stop-WithError (T "{0}: the type {1} has an item with Value `"{2}`" (needs an integer)" $where $typeId $e.GetAttribute("Value")) }
    $c = $e.CloneNode($true)
    $c.SetAttribute("Id", "%ENID%")
    # producer attributes (op:headerName, ...) belong to the carrier type only (header export), never to a copy
    foreach ($at in @($c.Attributes | Where-Object { $_.Name.Contains(":") })) { [void]$c.Attributes.Remove($at) }
    $enums += @{ Value = $iv; Xml = ($c.OuterXml -replace ' xmlns(:[A-Za-z]+)?="[^"]*"', '') }
  }
  if ($enums.Count -lt 2) { Stop-WithError (T "{0}: the type {1} has fewer than two items - nothing to filter" $where $typeId) }
  $trAttrs = ""
  foreach ($at in $tr[0].Attributes) { if ($at.Name -ne "xmlns") { $trAttrs += (" {0}=`"{1}`"" -f $at.Name, (ConvertTo-XmlText $at.Value)) } }
  $def = 0
  [void][int]::TryParse($p.GetAttribute("Value"), [ref]$def)
  $Item.Carrier = @{
    Name = $p.GetAttribute("Name"); Text = $p.GetAttribute("Text"); Default = $def
    TypeName = $typeNodes[0].GetAttribute("Name"); TrAttrs = $trAttrs; Enums = $enums
  }
  # ParameterRefs of the carrier in the source: suffix -> extra attributes (Access, ...); the ref of <Filter> must be one of them
  $Item.RefSuffixes = [ordered]@{}
  foreach ($r in $refNodes) {
    $sp = Split-FilterRef $r.GetAttribute("Id")
    if (-not $sp -or $sp.Prefix -cne $Item.Id.Prefix -or $sp.Number -cne $Item.Id.Number) { Stop-WithError (T "{0}: ParameterRef {1} of the parameter has an id of another form" $where $r.GetAttribute("Id")) }
    $extra = ""
    foreach ($at in $r.Attributes) { if (@("Id", "RefId", "xmlns") -cnotcontains $at.Name -and -not $at.Name.Contains(":")) { $extra += (" {0}=`"{1}`"" -f $at.Name, (ConvertTo-XmlText $at.Value)) } }
    $Item.RefSuffixes[$sp.Suffix] = $extra
  }
  if (-not $Item.RefSuffixes.Contains($Item.Id.Suffix)) { Stop-WithError (T "{0}: the source has no ParameterRef {1}" $where $Item.Ref) }
  # <Row>: another ParameterRef of the same parameter (other suffix and/or a concrete channel instead of the tokens)
  foreach ($row in $Item.Rows) {
    $sp = Split-FilterRef $row.Ref
    $ok = $false
    if ($sp -and $sp.Kind -ceq $Item.Id.Kind -and $Item.RefSuffixes.Contains($sp.Suffix)) {
      if ($Item.Id.Token) { $ok = ($sp.Number -ceq $Item.Id.Number -and $sp.Prefix -ceq $Item.Id.Prefix) }
      else {
        # the prefix of the carrier with each token either kept or replaced by two digits (a concrete module or channel)
        $body = $sp.Prefix + $sp.Number
        $rx = '^(' + (([regex]::Split($Item.Id.Prefix, '(%[A-Za-z_][A-Za-z0-9_]*%)') | Where-Object { $_ } | ForEach-Object {
            if ($_ -match '^%.*%$') { '(?:' + [regex]::Escape($_) + '|\d{2})' } else { [regex]::Escape($_) } }) -join '') + ')' + [regex]::Escape($Item.Id.Number) + '$'
        $mt = [regex]::Match($body, $rx)
        $ok = $mt.Success
        if ($ok) { $sp.Prefix = $mt.Groups[1].Value; $sp.Number = $Item.Id.Number }
      }
    }
    if (-not $ok) { Stop-WithError (T "{0}: <Row name=`"{1}`">: ref {2} is no ParameterRef of the filtered parameter (same number, a suffix of its ParameterRefs, the prefix may name a concrete channel)" $where $row.Name $row.Ref) }
    $row.Prefix = $sp.Prefix; $row.Suffix = $sp.Suffix
  }
  $all = @($enums | ForEach-Object { $_.Value })
  foreach ($a in $Item.Allows) {
    foreach ($v in $a.Values) { if ($all -notcontains $v) { Stop-WithError (T "{0}: <Allow board=`"{1}`"> names value {2}, the list has {3}" $where $a.Board $v ($all -join " ")) } }
  }
}

# @brief Every item value of the carrier list, in list order
function Get-FilterValues($Item) { return , @($Item.Carrier.Enums | ForEach-Object { $_.Value }) }

# @brief Key of a value set (sorted, comma separated) as written in the slot file
function Get-FilterKey($Values) { return (@($Values | Sort-Object -Unique) -join ",") }

# @brief Values one board may select and the rule that gave them: the first <Allow> in manifest order that matches the board
#        (board define or pattern, or capability; values = these items, except = every item but these; rule board:<pattern> or
#        capability:<name>), else the items up to the manifest value (rule value:<n>), else every item; Key "" = every item (the
#        carrier itself; Rule = the rule also then, "" when nothing matched and no value applies). The slot of a list belongs to
#        its rule, so a list that gains an item keeps its parameter id.
function Get-FilterBoardChoice($Item, $Board) {
  $where = "<Filter name=`"{0}`">" -f $Item.Name
  $all = Get-FilterValues $Item
  $hit = $null
  foreach ($a in $Item.Allows) {
    if ($a.Capability) { if ($Board.Caps[$a.CapIndex]) { $hit = $a; break } }
    elseif (Test-Wildcard $a.Board $Board.Define) { $hit = $a; break }
  }
  $key = ""
  if ($hit -and $hit.Except) { $set = @($all | Where-Object { $hit.Values -notcontains $_ }) }
  elseif ($hit) { $set = @($hit.Values) }
  elseif ($Item.Value) {
    $n = [int]$Board.Val[$Item.Value]
    $set = @($all | Where-Object { $_ -le $n })
  }
  else { $set = $all }
  if ($set.Count -eq 0) { Stop-WithError (T "{0}: {1} allows no item of the list" $where $Board.Define) }
  $set = @($set | Sort-Object -Unique)
  $rule = ""
  if ($hit -and $hit.Capability) { $rule = "capability:" + $hit.Capability }
  elseif ($hit) { $rule = "board:" + $hit.Board }
  elseif ($Item.Value) { $rule = "value:" + [int]$Board.Val[$Item.Value] }
  if ((Get-FilterKey $set) -cne (Get-FilterKey $all)) { $key = $rule }
  return @{ Set = $set; Key = $key; Rule = $rule }
}

# @brief Own ids of every filter whose source includes the <Conflicts> parts file against the conflict flags (P-%TT%<5 digits>):
#        the producer would stop on the doubled id; the generator names filter and number
function Test-FilterConflictIds($M) {
  $leaf = [System.IO.Path]::GetFileName($M.Conflicts.Output)
  $flags = @{}
  foreach ($u in $M.Conflicts.Uses) { $flags["%TT%" + $u.FlagNum] = $true }
  foreach ($f in $M.Filters.Items) {
    if (-not $f.Includes.ContainsKey($leaf)) { continue }
    foreach ($k in $f.SetSlots.Keys) {
      $fpid = Get-FilterOwnId $f $f.SetSlots[$k] $f.Id.Prefix
      if ($flags.ContainsKey((Get-FilterIdBody $fpid))) { Stop-WithError (T "<Filter name=`"{0}`">: parameter {1} (number + slot {2}) is also a conflict flag of <Conflicts> ({3} includes {4}) - choose a free number" $f.Name $fpid $f.SetSlots[$k] $f.Includes[$leaf] $leaf) }
    }
  }
}

# @brief One choose block on the hardware selection for a place of the dropdown (prefix and suffix of the ParameterRef used
#        there, extra attributes of the row): not selected and boards with every value = the carrier, every other value set =
#        its own parameter, which copies its value into the carrier (and into its own ref of this place, when that is not the
#        main ref: ETS keeps a value per ParameterRef)
function Add-FilterChoose($Sb, $M, $Boards, $Item, $Info, $Sets, [string]$Prefix, [string]$Suffix, [string]$Attrs) {
  $refs = Get-ParamRefIds $M
  $main = $Item.Id.Suffix
  $carrier = "{0}_R-{1}{2}{3}" -f ("%AID%_{0}-{1}{2}" -f $Item.Id.Kind, $Prefix, $Item.Id.Number), $Prefix, $Item.Id.Number, $Suffix
  $carrierMain = "{0}_R-{1}{2}{3}" -f ("%AID%_{0}-{1}{2}" -f $Item.Id.Kind, $Prefix, $Item.Id.Number), $Prefix, $Item.Id.Number, $main
  [void]$Sb.AppendLine(("    <choose ParamRefId=`"{0}`">" -f $refs.Select))
  $full = @($Boards | Where-Object { -not $_.FilterKeys[$Item.Name] })
  $ids = @([string]$M.UnselectedValue); if ($full.Count -gt 0) { $ids += (Get-IdList $full) }
  [void]$Sb.AppendLine(("      <when test=`"{0}`">" -f ($ids -join " ")))
  [void]$Sb.AppendLine(("        <ParameterRefRef RefId=`"{0}`"{1} />" -f $carrier, $Attrs))
  [void]$Sb.AppendLine("      </when>")
  foreach ($k in $Sets) {
    $s = $Info[$k]
    $own = Get-FilterOwnId $Item $s.Slot $Prefix
    $num = Get-FilterNumber $Item $s.Slot
    $ownRef = "{0}_R-{1}{2}{3}" -f $own, $Prefix, $num, $Suffix
    $ownMain = "{0}_R-{1}{2}{3}" -f $own, $Prefix, $num, $main
    $grp = @($Boards | Where-Object { $_.FilterKeys[$Item.Name] -eq $k })
    [void]$Sb.AppendLine(("      <!-- values {0} -->" -f ($s.Vals -join " ")))
    [void]$Sb.AppendLine(("      <when test=`"{0}`">" -f (Get-IdList $grp)))
    [void]$Sb.AppendLine(("        <ParameterRefRef RefId=`"{0}`"{1} />" -f $ownRef, $Attrs))
    if ($s.Fixed) { [void]$Sb.AppendLine(("        <Assign TargetParamRefRef=`"{0}`" Value=`"{1}`" />" -f $ownMain, $s.Vals[0])) }
    if ($Suffix -cne $main) { [void]$Sb.AppendLine(("        <Assign TargetParamRefRef=`"{0}`" SourceParamRefRef=`"{1}`" />" -f $ownRef, $ownMain)) }
    [void]$Sb.AppendLine(("        <Assign TargetParamRefRef=`"{0}`" SourceParamRefRef=`"{1}`" />" -f $carrierMain, $ownMain))
    [void]$Sb.AppendLine("      </when>")
  }
  [void]$Sb.AppendLine("    </choose>")
}

# @brief Parts file of <Filters>: the ParameterTypes of every filter (path //ApplicationProgram/Static/ParameterTypes, the producer
#        takes types only from there) and per <Filter> the blocks _Parameters (no memory) and _ParameterRefs (into the file
#        that holds the carrier: module, channel template or part, the ids keep its tokens), Filter_<name> in place of the row
#        of the carrier and Filter_<name>_<row> per <Row>; a value set with one value is read-only
function New-FiltersXml($M, $Boards) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
  [void]$sb.AppendLine('<KNX xmlns="http://knx.org/xml/project/20" xmlns:op="http://github.com/OpenKNX/OpenKNXproducer">')
  [void]$sb.AppendLine("  <!-- Generated by OGM-HardwareConfig/generator/Build-HardwareProfile.ps1 (<Filters>) - do not edit -->")
  [void]$sb.AppendLine("  <!-- include: //ApplicationProgram/Static/ParameterTypes/ParameterType into the ParameterTypes; per filter _Parameters (no memory) into the Parameters, _ParameterRefs into the ParameterRefs, Filter_<name> in place of the row of the carrier -->")
  $types = New-Object System.Text.StringBuilder
  $blocks = New-Object System.Text.StringBuilder
  foreach ($f in $M.Filters.Items) {
    $c = $f.Carrier
    # rules with their own list in slot order (a rule no board uses now keeps its slot but gives no output)
    $used = @{}
    foreach ($b in $Boards) { if ($b.FilterKeys[$f.Name]) { $used[$b.FilterKeys[$f.Name]] = $true } }
    $sets = @($f.SetSlots.Keys | Where-Object { $used.ContainsKey($_) } | Sort-Object { $f.SetSlots[$_] })
    $info = @{}
    foreach ($k in $sets) {
      $slot = $f.SetSlots[$k]
      $vals = @($f.KeySets[$k])
      $def = $c.Default; if ($vals -notcontains $def) { $def = $vals[0] }
      $info[$k] = @{ Slot = $slot; Vals = $vals; Default = $def
                     Type = "%AID%_PT-{0}F{1}" -f $c.TypeName, $slot; TypeName = "{0}F{1}" -f $c.TypeName, $slot
                     Name = "{0}F{1}" -f $c.Name, $slot; Fixed = ($vals.Count -eq 1) }
    }
    [void]$types.AppendLine(("<!-- <Filter name=`"{0}`"> -->" -f $f.Name))
    foreach ($k in $sets) {
      $s = $info[$k]
      [void]$types.AppendLine(("<ParameterType Id=`"{0}`" Name=`"{1}`">" -f $s.Type, $s.TypeName))
      [void]$types.AppendLine(("  <TypeRestriction{0}>" -f $c.TrAttrs))
      foreach ($e in $c.Enums) { if ($s.Vals -contains $e.Value) { [void]$types.AppendLine("    " + $e.Xml) } }
      [void]$types.AppendLine("  </TypeRestriction>")
      [void]$types.AppendLine("</ParameterType>")
    }
    [void]$blocks.AppendLine(("  <Block name=`"Filter_{0}_Parameters`">" -f $f.Name))
    foreach ($k in $sets) {
      $s = $info[$k]
      [void]$blocks.AppendLine(("    <Parameter Id=`"{0}`" Name=`"{1}`" ParameterType=`"{2}`" Text=`"{3}`" Value=`"{4}`" />" -f (Get-FilterOwnId $f $s.Slot $f.Id.Prefix), $s.Name, $s.Type, (ConvertTo-XmlText $c.Text), $s.Default))
    }
    [void]$blocks.AppendLine("  </Block>")
    [void]$blocks.AppendLine(("  <Block name=`"Filter_{0}_ParameterRefs`">" -f $f.Name))
    foreach ($k in $sets) {
      $s = $info[$k]
      $own = Get-FilterOwnId $f $s.Slot $f.Id.Prefix
      $num = Get-FilterNumber $f $s.Slot
      foreach ($suf in $f.RefSuffixes.Keys) {
        $extra = [string]$f.RefSuffixes[$suf]
        if ($s.Fixed) { $extra = ($extra -replace ' Access="[^"]*"', '') + ' Access="Read"' }
        [void]$blocks.AppendLine(("    <ParameterRef Id=`"{0}_R-{1}{2}{3}`" RefId=`"{0}`"{4} />" -f $own, $f.Id.Prefix, $num, $suf, $extra))
      }
    }
    [void]$blocks.AppendLine("  </Block>")
    $attrs = " IndentLevel=`"{0}`"" -f $f.Indent
    if ($f.Help) { $attrs += " HelpContext=`"{0}`"" -f $f.Help }
    [void]$blocks.AppendLine(("  <Block name=`"Filter_{0}`">" -f $f.Name))
    Add-FilterChoose $blocks $M $Boards $f $info $sets $f.Id.Prefix $f.Id.Suffix $attrs
    [void]$blocks.AppendLine("  </Block>")
    foreach ($row in $f.Rows) {
      $ra = ""
      if ($row.Cell) { $ra += " Cell=`"{0}`"" -f $row.Cell }
      if ($row.Indent) { $ra += " IndentLevel=`"{0}`"" -f $row.Indent }
      if ($row.Help) { $ra += " HelpContext=`"{0}`"" -f $row.Help }
      [void]$blocks.AppendLine(("  <Block name=`"Filter_{0}_{1}`">" -f $f.Name, $row.Name))
      Add-FilterChoose $blocks $M $Boards $f $info $sets $row.Prefix $row.Suffix $ra
      [void]$blocks.AppendLine("  </Block>")
    }
  }
  [void]$sb.AppendLine("  <ManufacturerData><Manufacturer><ApplicationPrograms><ApplicationProgram><Static><ParameterTypes>")
  [void]$sb.Append($types.ToString())
  [void]$sb.AppendLine("  </ParameterTypes></Static></ApplicationProgram></ApplicationPrograms></Manufacturer></ManufacturerData>")
  [void]$sb.Append($blocks.ToString())
  [void]$sb.AppendLine('</KNX>')
  return $sb.ToString()
}
