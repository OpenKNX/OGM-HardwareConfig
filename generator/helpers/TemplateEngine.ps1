#Requires -Version 5.1
<#
Open =
-----+  TemplateEngine
= KNX   2026 OpenKNX - Erkan Colak

FILEPATH: OGM-HardwareConfig/generator/helpers/TemplateEngine.ps1

.SYNOPSIS
    Text template engine of the hardware profile generator ("Bausteine").

.DESCRIPTION
    Dot-sourced by Build-HardwareProfile.ps1. Expands a template (XML, JavaScript, C or any text)
    line by line. Expressions are PowerShell expressions; the variables of the current scope
    ($Boards, $M, $P, loop variables) are visible to them.

    Directive lines (the whole line, leading blanks allowed; they produce no output):
      @@# comment
      @@for $v in <expr>        loop; also sets $index (0-based), $first, $last
      @@if <expr> / @@elseif <expr> / @@else / @@end
      @@set $name = <expr>
      @@params A! B C           parameters of a Baustein ("!" = required); others are an error
      @@default Name = <expr>   sets $P.Name when the caller did not pass it
      @@use <file> [<expr>]     expands a Baustein; <expr> is a hashtable of parameters ($P).
                                @hw/<file> is a file in generator/templates, any other path is
                                relative to the current template.
      @@param Name ... @@endparam   (directly after @@use) multi-line text parameter; then @@enduse
      @@expand <expr>           expands the template text <expr> here (e.g. a text parameter)
    Inline: {{ <expr> }} anywhere in a text line. A literal "{{" is written as {{ '{{' }}.

    Helper functions for expressions: D3, D5, X4, Xml, JsSq, CStr, Expand, IdList, Range,
    MaxOf, Select-TBoards.

.NOTES
    AUTHOR : Erkan Colak
    Windows PowerShell 5.1 compatible, pure ASCII.
#>

$script:TplSbCache = @{}
$script:TplFileCache = @{}
$script:TplHwDir = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, "..", "templates"))

# ------------------------------------------------------------------------------------------------
# Helpers visible to template expressions
# ------------------------------------------------------------------------------------------------
function D3($n) { return ("{0:D3}" -f [int]$n) }
function D5($n) { return ("{0:D5}" -f [int]$n) }
function X4($n) { return ("{0:X4}" -f [int]$n) }

# @brief Text for an XML attribute value
function Xml([string]$s) { return [System.Security.SecurityElement]::Escape($s) }

# @brief Text for a single-quoted JavaScript string
function JsSq([string]$s) { return ($s -replace '\\', '\\' -replace "'", "\'") }

# @brief Text for a C string literal
function CStr([string]$s) { return ($s -replace '\\', '\\' -replace '"', '\"') }

# @brief Integers from..to, empty when to < from (PowerShell 1..0 counts down)
function Range([int]$__from, [int]$__to) {
  if ($__to -lt $__from) { return , @() }
  return , @($__from..$__to)
}

# @brief Items of a value as an array: $null -> empty, an array stays, anything else -> one item
function ConvertTo-TplArray($__v) {
  if ($null -eq $__v) { return , @() }
  if ($__v -is [System.Array]) { return , $__v }
  if ($__v -is [System.Collections.IList]) {
    $__a = New-Object System.Collections.ArrayList
    foreach ($__x in $__v) { [void]$__a.Add($__x) }
    return , $__a.ToArray()
  }
  return , @($__v)
}

# @brief Largest value of the selector ($_ = item) over the items, $default for no item
function MaxOf($__items, [scriptblock]$__sel, $__default = 0) {
  $__max = $null
  foreach ($__it in (ConvertTo-TplArray $__items)) {
    $__v = $__it | ForEach-Object -Process $__sel
    if ($null -ne $__v -and ($null -eq $__max -or $__v -gt $__max)) { $__max = $__v }
  }
  if ($null -eq $__max) { return $__default }
  return $__max
}

# @brief Boards for which the filter ($_ = board) is true; all boards without a filter
function Select-TBoards($__boards, $__where) {
  $__all = ConvertTo-TplArray $__boards
  if (-not $__where) { return , $__all }
  return , @($__all | Where-Object $__where)
}

# @brief Decimal DEVICE_HW_IDs joined by $sep; $empty when there is none
function IdList($__boards, [string]$__sep = " ", [string]$__empty = "65535") {
  $__ids = @((ConvertTo-TplArray $__boards) | ForEach-Object { [string]$_.HwId })
  if ($__ids.Count -eq 0) { return $__empty }
  return ($__ids -join $__sep)
}

# @brief Path and line offset of a text: the @@param body it came from, else the current template
function Get-TplTextOrigin([hashtable]$Ctx, [string]$Text, [string]$Path) {
  $origins = $Ctx["__textorigin"]
  if ($null -ne $origins) {
    foreach ($o in $origins.Values) { if ($o.Text -ceq $Text) { return $o } }
  }
  return @{ Path = $Path; Offset = 0 }
}

# @brief Expands a template text in the scope of the calling expression; $vars adds or overrides variables
function Expand([string]$__text, [hashtable]$__vars) {
  if (-not $__text) { return "" }
  $__ctx = Copy-TplCtx $__tplctx
  if ($__vars) { foreach ($__k in $__vars.Keys) { $__ctx[$__k] = $__vars[$__k] } }
  $__o = Get-TplTextOrigin $__ctx $__text $__ctx.__path
  $__tpl = ConvertTo-TplNodes -Text $__text -Path $__o.Path -LineOffset $__o.Offset
  $__out = New-Object System.Collections.Generic.List[string]
  Invoke-TplNodes -Nodes $__tpl.Nodes -Ctx $__ctx -Out $__out
  return ($__out -join "`n")
}

# ------------------------------------------------------------------------------------------------
# Parser
# ------------------------------------------------------------------------------------------------
# @brief Template text -> node tree; Path is used for relative @@use paths and messages
$script:TplLineOffset = 0

# @brief Template text -> node tree; LineOffset = line of the text in its file minus 1 (text parameters)
function ConvertTo-TplNodes([string]$Text, [string]$Path, [int]$LineOffset = 0) {
  $t = $Text -replace "`r`n", "`n"
  $endsWithNewline = $t.EndsWith("`n")
  if ($endsWithNewline) { $t = $t.Substring(0, $t.Length - 1) }
  $lines = $t.Split([char]10)
  $pos = 0
  $script:TplLineOffset = $LineOffset
  try { $root = Read-TplBlock -Lines $lines -Pos ([ref]$pos) -Path $Path -Closers @() }
  finally { $script:TplLineOffset = 0 }
  if ($pos -lt $lines.Length) { throw (T "{0}:{1}: unexpected '{2}'" $Path ($pos + 1 + $LineOffset) $lines[$pos].Trim()) }
  # @@params / @@default at the top level declare the parameters of a template (name -> required)
  $declared = $null
  foreach ($nd in $root.Nodes) {
    if ($nd.T -eq "params") {
      if ($null -eq $declared) { $declared = @{} }
      foreach ($nm in $nd.Names) { if ($nm.EndsWith("!")) { $declared[$nm.TrimEnd("!")] = $true } else { $declared[$nm] = $false } }
    }
  }
  if ($null -ne $declared) { foreach ($nd in $root.Nodes) { if ($nd.T -eq "default" -and -not $declared.ContainsKey($nd.Name)) { $declared[$nd.Name] = $false } } }
  return @{ Nodes = $root.Nodes; EndsWithNewline = $endsWithNewline; Declared = $declared }
}

function Get-TplDirective([string]$line) {
  if ($line -match '^\s*@@#') { return @{ Kw = "#"; Arg = "" } }
  if ($line -match '^\s*@@([a-z]+)\b\s*(.*?)\s*$') { return @{ Kw = $Matches[1]; Arg = $Matches[2] } }
  return $null
}

# @brief Reads nodes until one of the closer keywords; returns the nodes and the closer met
function Read-TplBlock($Lines, [ref]$Pos, [string]$Path, [string[]]$Closers) {
  $nodes = New-Object System.Collections.Generic.List[object]
  while ($Pos.Value -lt $Lines.Length) {
    $lineNo = $Pos.Value + 1 + $script:TplLineOffset
    $line = $Lines[$Pos.Value]
    $d = Get-TplDirective $line
    if ($null -eq $d) { $nodes.Add(@{ T = "text"; Text = $line; Line = $lineNo; Path = $Path }); $Pos.Value++; continue }
    if ($Closers -contains $d.Kw) { return @{ Nodes = $nodes; Closer = $d; Line = $lineNo } }
    $Pos.Value++
    switch ($d.Kw) {
      "#" { }
      "for" {
        if ($d.Arg -notmatch '^\$([A-Za-z_][A-Za-z0-9_]*)\s+in\s+(.+)$') { throw (T "{0}:{1}: @@for needs '`$var in <expr>'" $Path $lineNo) }
        $var = $Matches[1]; $expr = $Matches[2]
        $body = Read-TplBlock -Lines $Lines -Pos $Pos -Path $Path -Closers @("end")
        if (-not $body.Closer) { throw (T "{0}:{1}: @@for without @@end" $Path $lineNo) }
        $Pos.Value++
        $nodes.Add(@{ T = "for"; Var = $var; Expr = $expr; Body = $body.Nodes; Line = $lineNo; Path = $Path })
      }
      "if" {
        if (-not $d.Arg) { throw (T "{0}:{1}: @@if needs an expression" $Path $lineNo) }
        $branches = New-Object System.Collections.Generic.List[object]
        $cond = $d.Arg
        $elseNodes = $null
        while ($true) {
          $part = Read-TplBlock -Lines $Lines -Pos $Pos -Path $Path -Closers @("elseif", "else", "end")
          if (-not $part.Closer) { throw (T "{0}:{1}: @@if without @@end" $Path $lineNo) }
          $Pos.Value++
          if ($null -ne $cond) { $branches.Add(@{ Expr = $cond; Body = $part.Nodes }) } else { $elseNodes = $part.Nodes }
          if ($part.Closer.Kw -eq "else" -and $part.Closer.Arg) { throw (T "{0}:{1}: @@else takes no expression (@@elseif?)" $Path $part.Line) }
          if ($part.Closer.Kw -eq "elseif" -and -not $part.Closer.Arg) { throw (T "{0}:{1}: @@elseif needs an expression" $Path $part.Line) }
          if ($part.Closer.Kw -eq "end") { break }
          if ($null -eq $cond) { throw (T "{0}:{1}: nothing may follow @@else but @@end" $Path $part.Line) }
          if ($part.Closer.Kw -eq "elseif") { $cond = $part.Closer.Arg } else { $cond = $null }
        }
        $nodes.Add(@{ T = "if"; Branches = $branches; Else = $elseNodes; Line = $lineNo; Path = $Path })
      }
      "set" {
        if ($d.Arg -notmatch '^\$([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') { throw (T "{0}:{1}: @@set needs '`$name = <expr>'" $Path $lineNo) }
        $nodes.Add(@{ T = "set"; Var = $Matches[1]; Expr = $Matches[2]; Line = $lineNo; Path = $Path })
      }
      "default" {
        if ($d.Arg -notmatch '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') { throw (T "{0}:{1}: @@default needs 'Name = <expr>'" $Path $lineNo) }
        $nodes.Add(@{ T = "default"; Name = $Matches[1]; Expr = $Matches[2]; Line = $lineNo; Path = $Path })
      }
      "expand" { $nodes.Add(@{ T = "expand"; Expr = $d.Arg; Line = $lineNo; Path = $Path }) }
      "params" {
        $names = @($d.Arg -split '\s+' | Where-Object { $_ })
        foreach ($nm in $names) { if ($nm -notmatch '^[A-Za-z_][A-Za-z0-9_]*!?$') { throw (T "{0}:{1}: @@params takes names, 'Name!' = required" $Path $lineNo) } }
        $nodes.Add(@{ T = "params"; Names = $names; Line = $lineNo; Path = $Path })
      }
      "use" {
        if ($d.Arg -notmatch '^(\S+)\s*(.*)$') { throw (T "{0}:{1}: @@use needs a file" $Path $lineNo) }
        $node = @{ T = "use"; File = $Matches[1]; Expr = $Matches[2]; TextParams = @{}; TextOrigins = @{}; Line = $lineNo; Path = $Path }
        # text parameters follow directly; @@enduse closes them
        $next = $null
        if ($Pos.Value -lt $Lines.Length) { $next = Get-TplDirective $Lines[$Pos.Value] }
        if ($null -ne $next -and $next.Kw -eq "param") {
          while ($true) {
            if ($Pos.Value -ge $Lines.Length) { throw (T "{0}:{1}: @@use without @@enduse" $Path $lineNo) }
            $pd = Get-TplDirective $Lines[$Pos.Value]
            if ($null -ne $pd -and $pd.Kw -eq "enduse") { $Pos.Value++; break }
            if ($null -eq $pd -or $pd.Kw -ne "param") { throw (T "{0}:{1}: only @@param blocks may stand between @@use and @@enduse" $Path ($Pos.Value + 1)) }
            $pname = $pd.Arg
            # file line of the @@param directive: the body starts on the next line
            $node.TextOrigins[$pname] = @{ Path = $Path; Offset = $Pos.Value + 1 + $script:TplLineOffset }
            $Pos.Value++
            $raw = New-Object System.Collections.Generic.List[string]
            $depth = 0
            while ($true) {
              if ($Pos.Value -ge $Lines.Length) { throw (T "{0}:{1}: @@param without @@endparam" $Path $lineNo) }
              $l = $Lines[$Pos.Value]
              $ld = Get-TplDirective $l
              $Pos.Value++
              if ($null -ne $ld -and $ld.Kw -eq "param") { $depth++ }
              if ($null -ne $ld -and $ld.Kw -eq "endparam") {
                if ($depth -eq 0) { break }
                $depth--
              }
              $raw.Add($l)
            }
            $node.TextParams[$pname] = ($raw -join "`n")
          }
        }
        $nodes.Add($node)
      }
      default { throw (T "{0}:{1}: unknown or misplaced directive @@{2}" $Path $lineNo $d.Kw) }
    }
  }
  return @{ Nodes = $nodes; Closer = $null }
}

# ------------------------------------------------------------------------------------------------
# Evaluation
# ------------------------------------------------------------------------------------------------
$script:TplHashMembers = @("Count", "Keys", "Values", "Comparer", "IsFixedSize", "IsReadOnly", "IsSynchronized", "SyncRoot")
$script:TplAutoVars = @("_", "PSItem", "true", "false", "null", "args", "this", "input", "Matches")

# @brief Compiled expression: the script block plus the variables it reads that it does not define itself.
# A plain expression is compiled as ,(expr) so an array (also an empty one) keeps its shape.
function Get-TplCompiled([string]$Expr, $Node) {
  if ($script:TplSbCache.ContainsKey($Expr)) { return $script:TplSbCache[$Expr] }
  $tokens = $null; $errs = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseInput($Expr, [ref]$tokens, [ref]$errs)
  if ($errs.Count -gt 0) { throw (T "{0}:{1}: {2} in '{3}'" $Node.Path $Node.Line $errs[0].Message $Expr) }
  $defined = @{}
  foreach ($a in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.ParameterAst] }, $true)) { $defined[$a.Name.VariablePath.UserPath] = $true }
  foreach ($a in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.ForEachStatementAst] }, $true)) { $defined[$a.Variable.VariablePath.UserPath] = $true }
  foreach ($a in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {
    if ($a.Left -is [System.Management.Automation.Language.VariableExpressionAst]) { $defined[$a.Left.VariablePath.UserPath] = $true }
  }
  $reads = @{}
  foreach ($v in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
    $path = $v.VariablePath
    if ($path.DriveName -eq "env") { continue }
    if (-not $path.IsUnqualified) { throw (T "{0}:{1}: only template variables may be used, not '`${2}' in '{3}'" $Node.Path $Node.Line $path.UserPath $Expr) }
    $name = $path.UserPath
    if ($defined.ContainsKey($name) -or $script:TplAutoVars -contains $name) { continue }
    $reads[$name] = $true
  }
  # one pipeline is compiled as ,(expr); statements (if, foreach, ...) are compiled as they are
  $stmts = @()
  if ($ast.EndBlock) { $stmts = @($ast.EndBlock.Statements) }
  $text = $Expr
  if ($stmts.Count -eq 1 -and $stmts[0] -is [System.Management.Automation.Language.PipelineAst]) { $text = ",(" + $Expr + "`n)" }
  try { $sb = [scriptblock]::Create($text) }
  catch { throw (T "{0}:{1}: {2} in '{3}'" $Node.Path $Node.Line $_.Exception.Message $Expr) }
  # parameter reads: $P.Name and $P['Name'] / $P["Name"]; method calls and the hashtable's own members are no reads
  $pReads = @{}
  foreach ($mx in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.MemberExpressionAst] }, $true)) {
    if ($mx -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) { continue }
    if ($mx.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and $mx.Expression.VariablePath.UserPath -eq "P" -and
        $mx.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
        $script:TplHashMembers -notcontains $mx.Member.Value) { $pReads[$mx.Member.Value] = $true }
  }
  foreach ($ix in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.IndexExpressionAst] }, $true)) {
    if ($ix.Target -is [System.Management.Automation.Language.VariableExpressionAst] -and $ix.Target.VariablePath.UserPath -eq "P" -and
        $ix.Index -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $pReads[$ix.Index.Value] = $true }
  }
  $c = @{ Sb = $sb; Reads = @($reads.Keys); PReads = @($pReads.Keys) }
  $script:TplSbCache[$Expr] = $c
  return $c
}

# @brief Evaluates one PowerShell expression with the context variables defined; a variable that is not
# in the context is an error (no fallback to a variable of the engine or the generator)
function Invoke-TplExpr([string]$__expr, [hashtable]$__tplctx, $__node) {
  $__c = Get-TplCompiled $__expr $__node
  foreach ($__n in $__c.Reads) {
    if (-not $__tplctx.ContainsKey($__n)) { throw (T "{0}:{1}: unknown variable `${2} in '{3}'" $__node.Path $__node.Line $__n $__expr) }
  }
  $__decl = $__tplctx["__declared"]
  if ($null -ne $__decl) {
    foreach ($__n in $__c.PReads) {
      if (-not $__decl.ContainsKey($__n)) { throw (T "{0}:{1}: parameter {2} is not declared by @@params in '{3}'" $__node.Path $__node.Line $__n $__expr) }
    }
  }
  foreach ($__k in $__tplctx.Keys) {
    if ($__k.StartsWith("__")) { continue }
    Set-Variable -Name $__k -Value $__tplctx[$__k]
  }
  try { $__r = & $__c.Sb }
  catch { throw (T "{0}:{1}: {2} in '{3}'" $__node.Path $__node.Line $_.Exception.Message $__expr) }
  return , $__r
}

function ConvertTo-TplString($v) {
  if ($null -eq $v) { return "" }
  if ($v -is [string]) { return $v }
  if ($v -is [System.Collections.IEnumerable] -and -not ($v -is [hashtable])) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($x in $v) { [void]$sb.Append((ConvertTo-TplString $x)) }
    return $sb.ToString()
  }
  if ($v -is [bool]) { if ($v) { return "true" } else { return "false" } }
  return [string]$v
}

# @brief Replaces every {{ expr }} of a text line; braces inside the expression are balanced
function Expand-TplLine([string]$Text, [hashtable]$Ctx, $Node) {
  if ($Text.IndexOf("{{", [System.StringComparison]::Ordinal) -lt 0) { return $Text }
  $sb = New-Object System.Text.StringBuilder
  $i = 0
  while ($i -lt $Text.Length) {
    $start = $Text.IndexOf("{{", $i, [System.StringComparison]::Ordinal)
    if ($start -lt 0) { [void]$sb.Append($Text.Substring($i)); break }
    while ($start + 2 -lt $Text.Length -and $Text[$start + 2] -eq '{') { $start++ }
    [void]$sb.Append($Text.Substring($i, $start - $i))
    $j = $start + 2
    $depth = 0
    $quote = [char]0
    $end = -1
    while ($j -lt $Text.Length) {
      $c = $Text[$j]
      if ($quote -ne [char]0) {
        if ($c -eq $quote) { $quote = [char]0 }
      }
      elseif ($c -eq [char]39 -or $c -eq [char]34) { $quote = $c }
      elseif ($c -eq '{') { $depth++ }
      elseif ($c -eq '}') {
        if ($depth -gt 0) { $depth-- }
        elseif ($j + 1 -lt $Text.Length -and $Text[$j + 1] -eq '}') { $end = $j; break }
      }
      $j++
    }
    if ($end -lt 0) { throw (T "{0}:{1}: '{{{{' without '}}}}'" $Node.Path $Node.Line) }
    $expr = $Text.Substring($start + 2, $end - $start - 2)
    [void]$sb.Append((ConvertTo-TplString (Invoke-TplExpr $expr $Ctx $Node)))
    $i = $end + 2
  }
  return $sb.ToString()
}

function Copy-TplCtx([hashtable]$Ctx) {
  $n = @{}
  foreach ($k in $Ctx.Keys) { $n[$k] = $Ctx[$k] }
  return $n
}

function Resolve-TplFile([string]$File, [string]$FromPath) {
  if ($File.StartsWith("@hw/")) { return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:TplHwDir, $File.Substring(4))) }
  $base = [System.IO.Path]::GetDirectoryName($FromPath)
  return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($base, $File))
}

# @brief Parsed template of a file (cached)
function Get-TplFile([string]$FullPath) {
  if (-not $script:TplFileCache.ContainsKey($FullPath)) {
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) { throw (T "Template not found: {0}" $FullPath) }
    $text = [System.IO.File]::ReadAllText($FullPath, [System.Text.Encoding]::UTF8)
    $script:TplFileCache[$FullPath] = ConvertTo-TplNodes -Text $text -Path $FullPath
  }
  return $script:TplFileCache[$FullPath]
}

function Invoke-TplNodes($Nodes, [hashtable]$Ctx, $Out) {
  foreach ($n in $Nodes) {
    switch ($n.T) {
      "text" { $Out.Add((Expand-TplLine $n.Text $Ctx $n)) }
      "set" { $Ctx[$n.Var] = Invoke-TplExpr $n.Expr $Ctx $n }
      "params" { }
      "default" {
        $p = $Ctx["P"]
        if (-not $p.ContainsKey($n.Name)) { $p[$n.Name] = Invoke-TplExpr $n.Expr $Ctx $n }
      }
      "for" {
        $items = ConvertTo-TplArray (Invoke-TplExpr $n.Expr $Ctx $n)
        for ($k = 0; $k -lt $items.Count; $k++) {
          $c = Copy-TplCtx $Ctx
          $c[$n.Var] = $items[$k]
          $c["index"] = $k
          $c["first"] = ($k -eq 0)
          $c["last"] = ($k -eq $items.Count - 1)
          Invoke-TplNodes -Nodes $n.Body -Ctx $c -Out $Out
        }
      }
      "if" {
        $done = $false
        foreach ($br in $n.Branches) {
          $r = Invoke-TplExpr $br.Expr $Ctx $n
          if ([System.Management.Automation.LanguagePrimitives]::IsTrue($r)) {
            Invoke-TplNodes -Nodes $br.Body -Ctx $Ctx -Out $Out
            $done = $true
            break
          }
        }
        if (-not $done -and $null -ne $n.Else) { Invoke-TplNodes -Nodes $n.Else -Ctx $Ctx -Out $Out }
      }
      "expand" {
        $text = ConvertTo-TplString (Invoke-TplExpr $n.Expr $Ctx $n)
        # an empty text parameter gives no line
        if ($text.Length -gt 0) {
          $o = Get-TplTextOrigin $Ctx $text $n.Path
          $c = Copy-TplCtx $Ctx
          $c["__path"] = $o.Path
          $tpl = ConvertTo-TplNodes -Text $text -Path $o.Path -LineOffset $o.Offset
          Invoke-TplNodes -Nodes $tpl.Nodes -Ctx $c -Out $Out
        }
      }
      "use" {
        $full = Resolve-TplFile $n.File $n.Path
        $params = @{}
        if ($n.Expr) {
          $h = Invoke-TplExpr $n.Expr $Ctx $n
          if ($h -isnot [hashtable]) { throw (T "{0}:{1}: the parameters of @@use must be a hashtable" $n.Path $n.Line) }
          foreach ($k in $h.Keys) { $params[$k] = $h[$k] }
        }
        foreach ($k in $n.TextParams.Keys) { $params[$k] = $n.TextParams[$k] }
        $tpl = Get-TplFile $full
        Test-TplParams -Tpl $tpl -Params $params -Where ("{0}:{1}: @@use {2}" -f $n.Path, $n.Line, $n.File)
        $c = Copy-TplCtx $Ctx
        $c["P"] = $params
        $c["__path"] = $n.Path
        $c["__declared"] = $tpl.Declared
        $origins = @{}
        foreach ($k in $n.TextOrigins.Keys) { $origins[$k] = @{ Text = $n.TextParams[$k]; Path = $n.TextOrigins[$k].Path; Offset = $n.TextOrigins[$k].Offset } }
        $c["__textorigin"] = $origins
        Invoke-TplNodes -Nodes $tpl.Nodes -Ctx $c -Out $Out
      }
    }
  }
}

# @brief A template with @@params accepts only declared parameters and needs the required ones ("Name!")
function Test-TplParams($Tpl, [hashtable]$Params, [string]$Where) {
  if ($null -eq $Tpl.Declared) { return }
  foreach ($k in $Params.Keys) {
    if (-not $Tpl.Declared.ContainsKey($k)) { throw (T "{0}: unknown parameter '{1}' (declared: {2})" $Where $k (($Tpl.Declared.Keys | Sort-Object) -join ", ")) }
  }
  foreach ($k in $Tpl.Declared.Keys) {
    if ($Tpl.Declared[$k] -and (-not $Params.ContainsKey($k) -or $null -eq $Params[$k])) { throw (T "{0}: parameter '{1}' is required" $Where $k) }
  }
}

# @brief Expands a template file; returns the text (LF line ends)
function Invoke-TemplateFile([string]$FullPath, [hashtable]$Vars, [bool]$FinalNewline = $true) {
  $tpl = Get-TplFile $FullPath
  $ctx = Copy-TplCtx $Vars
  if (-not $ctx.ContainsKey("P")) { $ctx["P"] = @{} }
  Test-TplParams -Tpl $tpl -Params $ctx["P"] -Where $FullPath
  $ctx["__path"] = $FullPath
  $ctx["__declared"] = $tpl.Declared
  $out = New-Object System.Collections.Generic.List[string]
  Invoke-TplNodes -Nodes $tpl.Nodes -Ctx $ctx -Out $out
  $text = ($out -join "`n")
  if ($FinalNewline -and $tpl.EndsWithNewline) { $text += "`n" }
  return $text
}
