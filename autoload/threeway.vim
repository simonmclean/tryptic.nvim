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
let s:threeway_empty_file_text = "[empty file]"

" Directory contents
let s:threeway_active_dir_contents = []
let s:threeway_parent_dir_contents = []

" Tab where Threeway was called from
let s:threeway_target_tab = ''

function! threeway#Threeway(path)
  let s:threeway_active_dir = a:path
  let s:threeway_target_tab = tabpagenr()

  tabnew
  let s:threeway_preview_win = nvim_get_current_win()
  vnew
  let s:threeway_active_win = nvim_get_current_win()
  vnew
  let s:threeway_parent_win = nvim_get_current_win()

  call nvim_set_current_win(s:threeway_active_win)
  call s:UpdateActiveDir()
  call s:UpdateParentDir()
  call s:SetPreviewWindow(nvim_get_current_line())
endfunction

function! threeway#ToggleHidden()
  let g:threeway_show_hidden_files = !g:threeway_show_hidden_files
  call s:UpdateActiveDir()
  call s:UpdateParentDir()
  call s:SetPreviewWindow(nvim_get_current_line())
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
    call s:SetPreviewWindow(nvim_get_current_line())
  endif
endfunction

function! threeway#HandleMoveUp()
  let current_cursor_pos = nvim_win_get_cursor(0)
  if (current_cursor_pos[0] > 1)
    call nvim_win_set_cursor(0, [current_cursor_pos[0] - 1, current_cursor_pos[1]])
    call s:SetPreviewWindow(nvim_get_current_line())
  endif
endfunction

function! threeway#HandleMoveLeft()
  if (s:threeway_parent_dir != "/")
    let s:threeway_active_dir = s:GetParentPath(s:threeway_active_dir)
    call s:UpdateParentDir()
    call s:UpdateActiveDir()
    call s:SetPreviewWindow(nvim_get_current_line())
  endif
endfunction

function! threeway#HandleMoveRight()
  let pathUnderCursor = nvim_get_current_line()
  if (pathUnderCursor != s:threeway_empty_dir_text)
    if (isdirectory(pathUnderCursor))
      let s:threeway_active_dir = pathUnderCursor
      call s:UpdateParentDir()
      call s:UpdateActiveDir()
      call s:SetPreviewWindow(nvim_get_current_line())
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

" TODO: Break this function up. e.g. 1) create buffer 2) config directory
" 3) config file
function! s:CreateBuffer(path, type)
  let buffer_handle = nvim_create_buf(0, 1)
  let is_dir = isdirectory(a:path)

  if (is_dir)
    call nvim_buf_set_option(buffer_handle, 'filetype', 'threeway')
    let dir_contents = s:GetDirContents(a:path)
    if (a:type == 'parent')
      let s:threeway_parent_dir_contents = dir_contents
    elseif (a:type == 'active')
      let s:threeway_active_dir_contents = dir_contents
    endif
    let dir_contents_length = len(dir_contents)
    if (dir_contents_length > 0)
      call nvim_buf_set_lines(buffer_handle, 0, dir_contents_length, 0, dir_contents)
    else
      call nvim_buf_set_lines(buffer_handle, 0, 1, 0, [s:threeway_empty_dir_text])
    endif
  else
    if (a:path != s:threeway_empty_dir_text)
      call nvim_buf_set_lines(buffer_handle, 0, 1, 0, readfile(a:path))
    endif
  endif

  call nvim_buf_set_option(buffer_handle, 'readonly', v:true)
  call nvim_buf_set_option(buffer_handle, 'modifiable', v:false)

  return buffer_handle
endfunction

" Assumes that s:threeway_active_dir has been updated, and is the focused window
function! s:UpdateActiveDir()
  let buffer_handle = s:CreateBuffer(s:threeway_active_dir, 'active')
  let index_of_current = index(s:threeway_active_dir_contents, s:threeway_preview_path)
  call nvim_win_set_buf(s:threeway_active_win, buffer_handle)
endfunction

function! s:UpdateParentDir()
  let s:threeway_parent_dir = s:GetParentPath(s:threeway_active_dir)
  let buffer_handle = s:CreateBuffer(s:threeway_parent_dir, 'parent')
  let index_of_active_dir = index(s:threeway_parent_dir_contents, s:threeway_active_dir)
  if (index_of_active_dir > -1)
    call nvim_buf_add_highlight(buffer_handle, -1, 'Search', index_of_active_dir, 0, -1)
  endif
  call nvim_win_set_buf(s:threeway_parent_win, buffer_handle)
endfunction

function! s:SetPreviewWindow(path)
  let g:threeway_preview_path = a:path
  let buffer_handle = s:CreateBuffer(a:path, 'preview')
  call nvim_win_set_buf(s:threeway_preview_win, buffer_handle)
endfunction
