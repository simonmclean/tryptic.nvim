if exists('g:threeway_loaded')
  finish
endif
let g:threeway_loaded = 1

augroup threeway
  autocmd!

  command! Threeway :call threeway#Threeway(expand('%:p:h'))<CR>

  " Remove netrw and NERDTree directory handlers.
  " TODO: Either remove divish handlers, or add a note to the readme
  autocmd VimEnter * if exists('#FileExplorer') | exe 'au! FileExplorer *' | endif
  autocmd VimEnter * if exists('#NERDTreeHijackNetrw') | exe 'au! NERDTreeHijackNetrw *' | endif

  autocmd FileType threeway nnoremap <silent> <buffer> h :call threeway#HandleMoveLeft()<cr>
  autocmd FileType threeway nnoremap <silent> <buffer> j :call threeway#HandleMoveDown()<cr>
  autocmd FileType threeway nnoremap <silent> <buffer> k :call threeway#HandleMoveUp()<cr>
  autocmd FileType threeway nnoremap <silent> <buffer> l :call threeway#HandleMoveRight()<cr>
  autocmd FileType threeway nnoremap <silent> <buffer> <leader>. :call threeway#ToggleHidden()<cr>
augroup END
