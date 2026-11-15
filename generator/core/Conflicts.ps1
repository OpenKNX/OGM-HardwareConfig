#Requires -Version 5.1
<#
Open =
-----+  Conflicts
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/core/Conflicts.ps1

.SYNOPSIS
    GPIO conflict check (<Conflicts>): reserved pins, ETS calculation, parts file.

.DESCRIPTION
    Part of Build-HardwareProfile.ps1, dot-sourced into its script scope (uses its constants and $script: state).
    Functions: Get-BoardReservedSets, Resolve-Conflicts, ConvertTo-ConflictJsCondition, New-ConflictsJs, New-ConflictsXml, Get-StaleConflictFiles, Test-ConflictNumbers.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

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
    $distinct = @(Get-OrdinalSorted @($u.BoardRefs.Values) -Unique)
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
  foreach ($dir in @(Get-OrdinalSorted @($Outputs | ForEach-Object { [System.IO.Path]::GetDirectoryName($_) }) -Unique)) {
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
      Write-Warn ("<Conflicts number={0}>: {1} uses {2} - if that file is the module that includes the parts, choose another number" -f $cf.Number, $f.Name, ((Get-OrdinalSorted @($hits.Keys)) -join ", "))
    }
  }
}
