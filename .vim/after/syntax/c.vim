syn keyword	cOperator	likely unlikely
syn match ErrorLeadSpace /^ \+/         " highlight any leading spaces
syn match ErrorTailSpace / \+$/         " highlight any trailing spaces
syn match ErrorTailTab /\t\+$/        " highlight any trailing tabs
"syn match Error80                 /.\%>80v/  " highlight anything past 80 in red

if has("gui_running")
"			hi  Error80       gui=NONE   guifg=#ffffff   guibg=#6e2e2e
            hi ErrorLeadSpace gui=NONE   guifg=#ffffff   guibg=#6e2e2e
            hi ErrorTailSpace gui=NONE   guifg=#ffffff   guibg=#6e2e2e
			hi ErrorTailTab   gui=NONE   guifg=#ffffff   guibg=#6e2e2e
else
"			hi Error80        cterm=NONE   ctermfg=white   ctermbg=red
			hi ErrorLeadSpace cterm=NONE   ctermfg=white   ctermbg=red
  			hi ErrorTailSpace cterm=NONE   ctermfg=white   ctermbg=red
			hi ErrorTailTab   cterm=NONE   ctermfg=white   ctermbg=red
endif
