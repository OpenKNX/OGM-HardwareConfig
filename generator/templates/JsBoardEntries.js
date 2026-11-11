@@# JavaScript object entries, one line per board: <Indent><Key>: <Value>[,][  // <Comment>]
@@# Params: Key, Value, Comment (templates with $b), Indent, Where (script block, $_ = board)
@@params Value! Comment Where
@@default Indent = "  "
@@default Key = '{{$b.HwId}}'
@@set $list = Select-TBoards $Boards $P.Where
@@for $b in $list
{{$P.Indent}}{{Expand $P.Key}}: {{Expand $P.Value}}{{ if (-not $last) { ',' } }}{{ if ($P.Comment) { '  // ' + (Expand $P.Comment) } }}
@@end
