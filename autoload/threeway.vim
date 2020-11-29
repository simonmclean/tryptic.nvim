function! ListFiles(fileList)
  execute "normal! ggdG"

  for file in a:fileList
    let name = file
    if (isdirectory(file))
      let name = name . '/'
    endif
    put =name
  endfor

  execute "normal! ggdd"
endfunction

" starts with /
" any number of any chars up to / inclusive
" if the / is followed by any chars
" let concealPattern = /^\/.*\/.\@=/
syntax match PathExcludingFileName /^\/.*\/.\@=/ conceal
" highlight link PathExcludingFileName ErrorMsg

function! threeway#Threeway(path)

  " prevent buffers from being added to buffer list
  set nobuflisted

  let g:threewayActiveDir = a:path

  tabnew
  vnew
  vnew

  call GoWindowRight()
  call UpdateActiveDir()
  call UpdateParentDir()
  call SetPreviewWindow(GetPathUnderCursor())
endfunction

function! GetDirContents(path)
  " First glob returns paths that would otherwise be hidden, such as dotfiles
  return glob(a:path . "/.[^.]*", 1, 1) + globpath(a:path, '*', 1, 1)
endfunction

function! GetParentPath(currentPath)
  let pathParts = split(a:currentPath, '/')
  if (len(pathParts))
    call remove(pathParts, len(pathParts) - 1)
    let parentPath = '/' . join(pathParts, '/')
    return parentPath
  else
    return 0
  endif
endfunction

function! GetPathUnderCursor()
  normal 0"ay$
  return @a
endfunction

function! GoWindowLeft()
  execute "normal! \<C-w>h"
endfunction

function! GoWindowRight()
  execute "normal! \<C-w>l"
endfunction

function! threeway#HandleMoveLeft()
  if (g:threewayParentDir != "/")
    let g:threewayActiveDir = GetParentPath(g:threewayActiveDir)
    call UpdateActiveDir()
    call UpdateParentDir()
    call SetPreviewWindow(GetPathUnderCursor())
  endif
endfunction

function! threeway#HandleMoveDown()
  execute "normal! j"
  let l:pathUnderCursor = GetPathUnderCursor()
  call SetPreviewWindow(l:pathUnderCursor)
endfunction

function! threeway#HandleMoveUp()
  execute "normal! k"
  let l:pathUnderCursor = GetPathUnderCursor()
  call SetPreviewWindow(l:pathUnderCursor)
endfunction

function! threeway#HandleMoveRight()
  let pathUnderCursor = GetPathUnderCursor()
  if (isdirectory(pathUnderCursor))
    let g:threewayActiveDir = pathUnderCursor
    call UpdateActiveDir()
    call UpdateParentDir()
    call SetPreviewWindow(GetPathUnderCursor())
  else
    echo "OPEN!"
  endif
endfunction

" Assumes that g:threewayActiveDir has been updated, and is the focused window
function! UpdateActiveDir()
  call EnableBufferEdit()
  call ListFiles(GetDirContents(g:threewayActiveDir))
  call ConfigBuffer(1, '')
endfunction

" Assumes that g:threewayActiveDir has been updated, and is the focused window
function! UpdateParentDir()
  let g:threewayParentDir = GetParentPath(g:threewayActiveDir)
  call GoWindowLeft()
  call EnableBufferEdit()
  let dirContents = GetDirContents(g:threewayParentDir)
  if (g:threewayParentDir != "/")
    call ListFiles(GetDirContents(g:threewayParentDir))
  else
    execute 'normal! ggdG'
    call setline('.', "/")
  endif
  if (g:threewayParentDir != "/")
    let highlightedStr = split(g:threewayActiveDir, "/")[-1] . "/"
    echo("CURRENT " . highlightedStr)
    call ConfigBuffer(1, highlightedStr)
  else
    call ConfigBuffer(1, '')
  endif
  call GoWindowRight()
endfunction

" Assumes that g:threewayActiveDir has been updated, and is the focused window
function! SetPreviewWindow(path)
  call GoWindowRight()
  call EnableBufferEdit()
  if (isdirectory(a:path))
    let dirContents = GetDirContents(a:path)
    if (len(dirContents) > 0)
      call ListFiles(dirContents)
    else
      execute 'normal! ggdG'
      call setline('.', "empty directory")
    endif
  else
    execute 'normal! ggdG'
    execute 'read' a:path
    execute 'normal! ggdd'
  endif
  call ConfigBuffer(0, '')
  setlocal syntax=off
  call GoWindowLeft()
endfunction

function! ConfigBuffer(isDir, highlightedStr)
  setlocal readonly
  setlocal nomodifiable
  setlocal nobuflisted
  setlocal buftype=nowrite
  setlocal bufhidden=delete
  setlocal noswapfile

  if (a:isDir)
    setlocal filetype=threeway
    syntax match PathExcludingFileName /^\/.*\/.\@=/ conceal

    if (len(a:highlightedStr) > 0)
      echo("HI " . a:highlightedStr)
      execute "syntax match HighlightedDir '" . a:highlightedStr . "'"
      highlight link HighlightedDir Search
    endif
  endif
endfunction

function! EnableBufferEdit()
  setlocal noreadonly
  setlocal modifiable
endfunction
