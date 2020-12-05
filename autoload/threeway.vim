if exists('g:autoloaded_threeway')
  finish
endif
let g:autoloaded_threeway = 1

" Paths
let s:threeway_active_dir = ''
let s:threeway_parent_dir = ''
let s:threeway_preview_path = ''

" Window handles
let s:threeway_active_win = ''
let s:threeway_parent_win = ''
let s:threeway_preview_win = ''

" Text
let s:threeway_empty_dir_text = "[empty directory]"

" Directory contents
let s:threeway_active_dir_contents = []
let s:threeway_parent_dir_contents = []

" Tab where Threeway was called from
let s:threeway_target_tab = ''

function! threeway#Threeway(path)
  let s:threeway_active_dir = a:path
  let s:threeway_target_tab = tabpagenr()
  let starting_file = expand('%')

  tabnew
  let s:threeway_preview_win = nvim_get_current_win()
  vnew
  let s:threeway_active_win = nvim_get_current_win()
  vnew
  let s:threeway_parent_win = nvim_get_current_win()

  call nvim_set_current_win(s:threeway_active_win)
  call s:UpdateActiveDir()
  call s:UpdateParentDir()
  call s:UpdatePreviewWindow()

  if (starting_file)
    call search(starting_file)
  endif
endfunction

function! threeway#ToggleHidden()
  let g:threeway_show_hidden_files = !g:threeway_show_hidden_files
  call s:UpdateActiveDir()
  call s:UpdateParentDir()
  call s:UpdatePreviewWindow()
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
  if (current_cursor_pos[0] < len(s:threeway_active_dir_contents))
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
  if (s:threeway_parent_dir != "/")
    let s:threeway_active_dir = s:GetParentPath(s:threeway_active_dir)
    call s:UpdateParentDir()
    call s:UpdateActiveDir()
    call s:UpdatePreviewWindow()
  endif
endfunction

function! threeway#HandleMoveRight()
  let pathUnderCursor = nvim_get_current_line()
  if (pathUnderCursor != s:threeway_empty_dir_text)
    if (isdirectory(pathUnderCursor))
      let s:threeway_active_dir = pathUnderCursor
      call s:UpdateParentDir()
      call s:UpdateActiveDir()
      call s:UpdatePreviewWindow()
    else
      call s:OpenFile(pathUnderCursor)
    endif
  endif
endfunction

function! s:OpenFile(filePath)
  execute "tabclose"
  execute "normal!" . s:threeway_target_tab . "gT"
  execute "edit" . a:filePath
endfunction

function! s:CreateDirectoryBuffer(path)
  let buffer_handle = nvim_create_buf(0, 1)
  call nvim_buf_set_option(buffer_handle, 'filetype', 'threeway')
  let dir_contents = s:GetDirContents(a:path)
  let dir_contents_length = len(dir_contents)
  if (dir_contents_length > 0)
    call nvim_buf_set_lines(buffer_handle, 0, dir_contents_length, 0, dir_contents)
  else
    call nvim_buf_set_lines(buffer_handle, 0, 1, 0, [s:threeway_empty_dir_text])
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

" Assumes that s:threeway_active_dir has been updated
" TODO: Maybe pass in and set the value, rather than assuming it's already
" been set
function! s:UpdateActiveDir()
  let [buffer_handle, dir_contents] = s:CreateDirectoryBuffer(s:threeway_active_dir)
  let s:threeway_active_dir_contents = dir_contents
  call s:LockBuffer(buffer_handle)
  call nvim_win_set_buf(s:threeway_active_win, buffer_handle)
endfunction

function! s:UpdateParentDir()
  let s:threeway_parent_dir = s:GetParentPath(s:threeway_active_dir)
  let [buffer_handle, dir_contents] = s:CreateDirectoryBuffer(s:threeway_parent_dir)
  let s:threeway_parent_dir_contents = dir_contents
  let index_of_active_dir = index(s:threeway_parent_dir_contents, s:threeway_active_dir)
  if (index_of_active_dir > -1)
    call nvim_buf_add_highlight(buffer_handle, -1, 'Search', index_of_active_dir, 0, -1)
  endif
  call s:LockBuffer(buffer_handle)
  call nvim_win_set_buf(s:threeway_parent_win, buffer_handle)
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
  call s:LockBuffer(buffer_handle)
  call nvim_win_set_buf(s:threeway_preview_win, buffer_handle)
endfunction
