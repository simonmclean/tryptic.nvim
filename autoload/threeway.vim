if exists('g:autoloaded_threeway')
  finish
endif
let g:autoloaded_threeway = 1

let s:state = {
  \ 'active': {
    \ 'path': '',
    \ 'win': '',
    \ 'buf': '',
    \ 'contents': '',
  \},
  \ 'parent': {
    \ 'path': '',
    \ 'win': '',
    \ 'buf': '',
    \ 'contents': '',
  \},
  \ 'preview': {
    \ 'path': '',
    \ 'win': '',
    \ 'buf': '',
  \},
  \ 'target_tab': '',
\}

" Dictionary of path -> [buffer_handle, contents]
let s:buffers = {}

" Special text
let s:threeway_empty_dir_text = "[empty directory]"

function! threeway#Threeway(path)
  let s:state.active.path = a:path
  let s:state.target_tab = tabpagenr()
  let l:starting_file = expand('%:p')
  " let l:content = luaeval('require("threeway").readFile('. l:starting_file .')')

  tabnew
  let s:state.preview.win = nvim_get_current_win()
  vnew
  let s:state.active.win = nvim_get_current_win()
  vnew
  let s:state.parent.win = nvim_get_current_win()

  let l:windows = [s:state.parent.win, s:state.active.win, s:state.preview.win]
  for l:win in l:windows
    call nvim_win_set_option(l:win, 'conceallevel', 2)
    call nvim_win_set_option(l:win, 'concealcursor', 'n')
  endfor

  call nvim_set_current_win(s:state.active.win)
  call s:UpdateAll()

  call search(l:starting_file)
endfunction

function! s:UpdateAll()
  call s:UpdateActiveDir()
  call s:UpdateParentDir()
  call s:UpdatePreviewWindow()
endfunction

function! threeway#ToggleHidden()
  let g:threeway_show_hidden_files = !g:threeway_show_hidden_files
  call s:UpdateAll()
endfunction

function! s:GetDirContents(path)
  " First glob returns paths that would otherwise be hidden, such as dotfiles
  let hidden_files = glob(a:path . "/.[^.]*", 1, 1)
  let non_hidden_files = globpath(a:path, '*', 1, 1)
  if (g:threeway_show_hidden_files)
    return hidden_files + non_hidden_files
  else
    return non_hidden_files
  endif
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

function! threeway#HandleMoveDown()
  let current_cursor_pos = nvim_win_get_cursor(0)
  if (current_cursor_pos[0] < len(s:state.active.contents))
    call nvim_win_set_cursor(0, [current_cursor_pos[0] + 1, current_cursor_pos[1]])
    call s:UpdatePreviewWindow()
  endif
endfunction

function! threeway#HandleMoveUp()
  let current_cursor_pos = nvim_win_get_cursor(0)
  if (current_cursor_pos[0] > 1)
    call nvim_win_set_cursor(0, [current_cursor_pos[0] - 1, current_cursor_pos[1]])
    call s:UpdatePreviewWindow()
  endif
endfunction

function! threeway#HandleMoveLeft()
  if (s:state.parent.path != "/")
    let s:state.active.path = s:GetParentPath(s:state.active.path)
    call s:UpdateAll()
  endif
endfunction

function! threeway#HandleMoveRight()
  let pathUnderCursor = nvim_get_current_line()
  if (pathUnderCursor != s:threeway_empty_dir_text)
    if (isdirectory(pathUnderCursor))
      let s:state.active.path = pathUnderCursor
      call s:UpdateAll()
    else
      call s:OpenFile(pathUnderCursor)
    endif
  endif
endfunction

function! s:OpenFile(filePath)
  execute "tabclose"
  execute "normal!" . s:state.target_tab . "gT"
  execute "edit" . a:filePath
endfunction

function! s:CreateDirectoryBuffer(path)
  let buffer_handle = 0
  let dir_contents = []

  if has_key(s:buffers, a:path)
    let [buffer_handle, dir_contents] = s:buffers[a:path]
  else
    let buffer_handle = nvim_create_buf(0, 1)
    call nvim_buf_set_option(buffer_handle, 'filetype', 'threeway')
    let dir_contents = s:GetDirContents(a:path)
    let dir_contents_length = len(dir_contents)

    if (dir_contents_length > 0)
      call nvim_buf_set_lines(buffer_handle, 0, dir_contents_length, 0, dir_contents)
    else
      call nvim_buf_set_lines(buffer_handle, 0, 1, 0, [s:threeway_empty_dir_text])
    endif

    call nvim_buf_set_name(buffer_handle, a:path)
    let s:buffers[a:path] = [buffer_handle, dir_contents]
  endif

  return [buffer_handle, dir_contents]
endfunction

function! s:CreateFileBuffer(path)
  let buffer_handle = nvim_create_buf(0, 1)
  call nvim_buf_set_lines(buffer_handle, 0, 1, 0, readfile(a:path))
  return buffer_handle
endfunction

function! s:CreateBlankBuffer()
  return nvim_create_buf(0, 1)
endfunction

function! s:LockBuffer(buffer_handle)
  call nvim_buf_set_option(a:buffer_handle, 'readonly', v:true)
  call nvim_buf_set_option(a:buffer_handle, 'modifiable', v:false)
endfunction

" Assumes that s:state.active.path has been updated
" TODO: Maybe pass in and set the value, rather than assuming it's already
" been set
function! s:UpdateActiveDir()
  let [buffer_handle, dir_contents] = s:CreateDirectoryBuffer(s:state.active.path)
  let s:state.active.contents = dir_contents
  let s:state.active.buf = buffer_handle
  call nvim_win_set_buf(s:state.active.win, buffer_handle)
  call s:LockBuffer(buffer_handle)
endfunction

function! s:UpdateParentDir()
  let s:state.parent.path = s:GetParentPath(s:state.active.path)
  let [buffer_handle, dir_contents] = s:CreateDirectoryBuffer(s:state.parent.path)
  let s:state.parent.buf = buffer_handle
  let s:state.parent.contents = dir_contents
  let index_of_active_dir = index(s:state.parent.contents, s:state.active.path)
  if (index_of_active_dir > -1)
    call nvim_buf_add_highlight(buffer_handle, -1, 'Search', index_of_active_dir, 0, -1)
  endif
  call nvim_win_set_buf(s:state.parent.win, buffer_handle)
  call s:LockBuffer(buffer_handle)
endfunction

function! s:UpdatePreviewWindow()
  let path = nvim_get_current_line()
  let g:threeway_preview_path = path
  if (path == s:threeway_empty_dir_text)
    let buffer_handle = s:CreateBlankBuffer()
  elseif (isdirectory(path))
    let [buffer_handle, dir_contents] = s:CreateDirectoryBuffer(path)
  else
    let buffer_handle = s:CreateFileBuffer(path)
  endif
  call nvim_win_set_buf(s:state.preview.win, buffer_handle)
  call s:LockBuffer(buffer_handle)
endfunction
