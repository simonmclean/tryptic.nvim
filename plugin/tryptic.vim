if exists('g:tryptic_loaded')
  finish
endif
let g:tryptic_loaded = 1

let g:tryptic_show_hidden_files = 0

augroup tryptic
  autocmd!

  command! Tryptic :call tryptic#Tryptic(expand('%:p:h'))<CR>

  " Remove netrw and NERDTree directory handlers.
  " TODO: Either remove divish handlers, or add a note to the readme
  autocmd VimEnter * if exists('#FileExplorer') | exe 'au! FileExplorer *' | endif
  autocmd VimEnter * if exists('#NERDTreeHijackNetrw') | exe 'au! NERDTreeHijackNetrw *' | endif
augroup END
