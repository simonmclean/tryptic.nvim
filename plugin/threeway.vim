let g:threewayActiveDir = ''
let g:threewayParentDir = ''
let g:threewayPreviewPath = ''

command! Threeway :call threeway#Threeway(expand('%:p:h'))<CR>

augroup threeway
  autocmd!
  autocmd FileType threeway nnoremap <silent> <buffer> h :call threeway#HandleMoveLeft()<cr>
  autocmd FileType threeway nnoremap <silent> <buffer> j :call threeway#HandleMoveDown()<cr>
  autocmd FileType threeway nnoremap <silent> <buffer> k :call threeway#HandleMoveUp()<cr>
  autocmd FileType threeway nnoremap <silent> <buffer> l :call threeway#HandleMoveRight()<cr>
augroup END
