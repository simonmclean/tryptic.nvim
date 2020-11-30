if exists('g:autoloaded_threeway')
  finish
endif
let g:autoloaded_threeway = 1

function! s:PrintDirContents(fileList)
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

" regex description:
" - starts with /
" - any number of any chars up to last / inclusive
" - exclude / from the above if it isn't followed by any chars
syntax match PathExcludingFileName /^\/.*\/.\@=/ conceal

function! threeway#Threeway(path)
  let g:threeway_active_dir = a:path
  let g:threeway_target_tab = tabpagenr()

  tabnew
  vnew
  vnew

  call s:GoWindowRight()
  call s:UpdateActiveDir()
  call s:UpdateParentDir()
  call s:SetPreviewWindow(s:GetPathUnderCursor())
endfunction

function! s:GetDirContents(path)
  " First glob returns paths that would otherwise be hidden, such as dotfiles
  return glob(a:path . "/.[^.]*", 1, 1) + globpath(a:path, '*', 1, 1)
endfunction

function! s:GetParentPath(currentPath)
  let pathParts = split(a:currentPath, '/')
  if (len(pathParts))
    call remove(pathParts, len(pathParts) - 1)
    let parentPath = '/' . join(pathParts, '/')
    return parentPath
  else
    return 0
  endif
endfunction

function! s:GetPathUnderCursor()
  normal 0"ay$
  return @a
endfunction

function! s:GoWindowLeft()
  execute "normal! \<C-w>h"
endfunction

function! s:GoWindowRight()
  execute "normal! \<C-w>l"
endfunction

function! threeway#HandleMoveLeft()
  if (g:threeway_parent_dir != "/")
    let g:threeway_active_dir = s:GetParentPath(g:threeway_active_dir)
    call s:UpdateParentDir()
    call s:UpdateActiveDir()
    call s:SetPreviewWindow(s:GetPathUnderCursor())
  endif
endfunction

function! threeway#HandleMoveDown()
  execute "normal! j"
  let l:pathUnderCursor = s:GetPathUnderCursor()
  call s:SetPreviewWindow(l:pathUnderCursor)
endfunction

function! threeway#HandleMoveUp()
  execute "normal! k"
  let l:pathUnderCursor = s:GetPathUnderCursor()
  call s:SetPreviewWindow(l:pathUnderCursor)
endfunction

function! threeway#HandleMoveRight()
  let pathUnderCursor = s:GetPathUnderCursor()
  if (isdirectory(pathUnderCursor))
    let g:threeway_active_dir = pathUnderCursor
    call s:UpdateParentDir()
    call s:UpdateActiveDir()
    call s:SetPreviewWindow(s:GetPathUnderCursor())
  else
    execute "tabclose"
    execute "normal!" . g:threeway_target_tab . "gT"
    execute "edit" . pathUnderCursor
  endif
endfunction

" Assumes that g:threeway_active_dir has been updated, and is the focused window
function! s:UpdateActiveDir()
  call s:EnableBufferEdit()
  call s:PrintDirContents(s:GetDirContents(g:threeway_active_dir))
  call s:RenameBuffer(g:threeway_active_dir)
  call s:ConfigBuffer(1, '')
endfunction

" Assumes that g:threeway_active_dir has been updated, and is the focused window
function! s:UpdateParentDir()
  let g:threeway_parent_dir = s:GetParentPath(g:threeway_active_dir)
  call s:GoWindowLeft()
  call s:EnableBufferEdit()
  let dirContents = s:GetDirContents(g:threeway_parent_dir)
  if (g:threeway_parent_dir != "/")
    call s:PrintDirContents(s:GetDirContents(g:threeway_parent_dir))
  else
    execute 'normal! ggdG'
    call setline('.', "/")
  endif
  call s:RenameBuffer(g:threeway_parent_dir)
  if (g:threeway_parent_dir != "/")
    let highlightedStr = split(g:threeway_active_dir, "/")[-1] . "/"
    call s:ConfigBuffer(1, highlightedStr)
  else
    call s:ConfigBuffer(1, '')
  endif
  call s:GoWindowRight()
endfunction

" Assumes that g:threeway_active_dir has been updated, and is the focused window
function! s:SetPreviewWindow(path)
  call s:GoWindowRight()
  call s:EnableBufferEdit()
  let isDir = isdirectory(a:path)
  if (isDir)
    let dirContents = s:GetDirContents(a:path)
    if (len(dirContents) > 0)
      call s:PrintDirContents(dirContents)
    else
      execute 'normal! ggdG'
      call setline('.', "empty directory")
    endif
  else
    execute 'normal! ggdG'
    " execute 'edit' . a:path
    execute 'read' a:path
    execute 'normal! ggdd'
    setlocal syntax=off
  endif
  call s:ConfigBuffer(0, '')
  call s:GoWindowLeft()
endfunction

function! s:ConfigBuffer(isDir, highlightedStr)
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
      execute "syntax match HighlightedDir '" . a:highlightedStr . "'"
      highlight link HighlightedDir Search
    endif
  endif
endfunction

" IDEA: Just open the directory instead of faffing about with naming!!!
function! s:RenameBuffer(name)
  " execute "0file!"
  " execute "file!" . a:name
endfunction

function! s:EnableBufferEdit()
  setlocal noreadonly
  setlocal modifiable
endfunction
