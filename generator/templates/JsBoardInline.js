@@# One line: <Prefix><item of each board, joined by Sep><Suffix>
@@# Params: Item (template with $b), Prefix, Suffix, Sep, Where (script block, $_ = board)
@@params Prefix Suffix Where
@@default Sep = ", "
@@default Item = '{{$b.HwId}}'
@@set $list = Select-TBoards $Boards $P.Where
{{$P.Prefix}}{{ (@($list | ForEach-Object { Expand $P.Item @{ b = $_ } })) -join $P.Sep }}{{$P.Suffix}}
