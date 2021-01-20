if exists('g:autoloaded_tryptic')
  finish
endif
let g:autoloaded_tryptic = 1

let s:state = {
  \ 'active': {
    \ 'path': '',
    \ 'previous_path': '',
    \ 'win': '',
    \ 'buf': '',
    \ 'line_number': 0,
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
  \ 'arglist': []
\}

" Dictionary of path -> [buffer_handle, contents]
let s:buffers = {}

" Used to highlight the active directory in the parent window
let s:parent_highlight_namespace = nvim_create_namespace('parent_highlight')

" Special text
let s:tryptic_empty_dir_text = "[empty directory]"

function! tryptic#Tryptic(path)
  let s:state.active.path = a:path
  let s:state.target_tab = tabpagenr()
  let l:starting_file = expand('%:p')

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

  arglocal!
  call nvim_set_current_win(s:state.active.win)
  call s:UpdateAll(0)

  call search(l:starting_file)
endfunction

function! s:UpdateAll(force_refresh)
  " The order matters
  call s:UpdateActiveDir(a:force_refresh)
  call s:UpdateParentDir(a:force_refresh)
  call s:UpdatePreviewWindow(a:force_refresh)
  " TODO: This can result in the autocmd being attached to the same buffer
  " multiple times. Not a big deal in practice, but should be fixed.
  autocmd CursorMoved <buffer> call tryptic#HandleCursorMoved()
endfunction

function! tryptic#Refresh()
  call s:UpdateAll(1)
endfunction

function! tryptic#ToggleArglist()
  let path = nvim_get_current_line()
  let index_in_arglist = index(s:state.arglist, path)
  if (index_in_arglist < 0)
    call insert(s:state.arglist, path)
  else
    call remove(s:state.arglist, index_in_arglist)
  endif
  echo s:state.arglist
  for arg in s:state.arglist
    execute 'argadd' . fnameescape(arg)
  endfor
endfunction

function! tryptic#ToggleHidden()
  let g:tryptic_show_hidden_files = !g:tryptic_show_hidden_files
  call s:UpdateAll(1)
endfunction

function! s:GetDirContents(path)
  " First glob returns paths that would otherwise be hidden, such as dotfiles
  let hidden_files = glob(a:path . "/.[^.]*", 1, 1)
  let non_hidden_files = globpath(a:path, '*', 1, 1)
  if (g:tryptic_show_hidden_files)
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

function tryptic#HandleCursorMoved()
  let current_buf = nvim_get_current_buf()
  if (current_buf == s:state.active.buf)
    let current_line = line('.')
    if (current_line != s:state.active.line_number)
      let s:state.active.line_number = current_line
      call s:ThrottledUpdatePreviewWindow.call()
    endif
  endif
endfunction

function! tryptic#HandleMoveLeft()
  if (s:state.parent.path != "/")
    let s:state.active.previous_path = s:state.active.path
    let s:state.active.path = s:GetParentPath(s:state.active.path)
    call s:UpdateAll(0)
  endif
endfunction

function! tryptic#HandleMoveRight()
  let pathUnderCursor = nvim_get_current_line()
  let pathExists = s:PathExists(pathUnderCursor)
  if (pathExists)
    if (isdirectory(pathUnderCursor))
      let s:state.active.previous_path = s:state.active.path
      let s:state.active.path = pathUnderCursor
      call s:UpdateAll(0)
    else
      call s:OpenFile(pathUnderCursor)
    endif
  else
    echo("Path does not exist: " . pathUnderCursor)
  endif
endfunction

function! s:PathExists(path)
  return !empty(glob(a:path))
endfunction

function! s:OpenFile(filePath)
  execute "tabclose"
  execute "normal!" . s:state.target_tab . "gT"
  execute "edit" . a:filePath
endfunction

function! s:CreateDirectoryBuffer(path, force_refresh)
  let buffer_handle = 0
  let dir_contents = []
  let buffer_exists = has_key(s:buffers, a:path)
  let refreshing = buffer_exists && a:force_refresh

  if buffer_exists && !refreshing
    let [buffer_handle, dir_contents] = s:buffers[a:path]
  else
    if refreshing
      let buffer_handle = s:buffers[a:path][0]
      call nvim_buf_set_option(buffer_handle, 'readonly', v:false)
      call nvim_buf_set_option(buffer_handle, 'modifiable', v:true)
      call nvim_buf_set_lines(buffer_handle, 0, -1, 0, [])
    else
      let buffer_handle = nvim_create_buf(0, 1)
    endif

    call nvim_buf_set_option(buffer_handle, 'filetype', 'tryptic')
    let dir_contents = s:GetDirContents(a:path)
    let dir_contents_length = len(dir_contents)

    if (dir_contents_length > 0)
      call nvim_buf_set_lines(buffer_handle, 0, dir_contents_length, 0, dir_contents)
    else
      call nvim_buf_set_lines(buffer_handle, 0, 1, 0, [s:tryptic_empty_dir_text])
    endif

    if !refreshing
      call nvim_buf_set_name(buffer_handle, a:path)
    endif

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
function! s:UpdateActiveDir(force_refresh)
  let [buffer_handle, dir_contents] = s:CreateDirectoryBuffer(s:state.active.path, a:force_refresh)
  if a:force_refresh
    " Restore current line
    execute s:state.active.line_number
    " Save new line number as it might not be same
    let s:state.active.line_number
  endif
  let s:state.active.contents = dir_contents
  let s:state.active.buf = buffer_handle
  call nvim_buf_clear_namespace(buffer_handle, s:parent_highlight_namespace, 0, -1)
  call nvim_win_set_buf(s:state.active.win, buffer_handle)
  if s:state.active.previous_path != ''
    let index_of_prev_path = index(s:state.active.contents, s:state.active.previous_path)
    if index_of_prev_path > -1
      let line_number = index_of_prev_path + 1
      execute (line_number)
      let s:state.active.line_number = line_number
    endif
  endif
  call s:LockBuffer(buffer_handle)
endfunction

function! s:UpdateParentDir(force_refresh)
  let s:state.parent.path = s:GetParentPath(s:state.active.path)
  let [buffer_handle, dir_contents] = s:CreateDirectoryBuffer(s:state.parent.path, a:force_refresh)
  let s:state.parent.buf = buffer_handle
  let s:state.parent.contents = dir_contents
  let index_of_active_dir = index(s:state.parent.contents, s:state.active.path)
  if (index_of_active_dir > -1)
    call nvim_buf_add_highlight(buffer_handle, s:parent_highlight_namespace, 'Search', index_of_active_dir, 0, -1)
  endif
  call nvim_win_set_buf(s:state.parent.win, buffer_handle)
  call s:LockBuffer(buffer_handle)
endfunction

function! s:UpdatePreviewWindow(force_refresh)
  let path = nvim_get_current_line()
  let s:state.preview.path = path
  if (!s:PathExists(path))
    echo("Path does not exist: " . path)
    let buffer_handle = s:CreateBlankBuffer()
  elseif (isdirectory(path))
    let [buffer_handle, dir_contents] = s:CreateDirectoryBuffer(path, a:force_refresh)
  else
    let buffer_handle = s:CreateFileBuffer(path)
  endif
  call nvim_win_set_buf(s:state.preview.win, buffer_handle)
  call s:LockBuffer(buffer_handle)
endfunction

" Credit to https://github.com/dsummersl/vus for this throttle function
function! s:Throttle(fn, wait, ...) abort
  let l:leading = 1
  if exists('a:1')
    let l:leading = a:1
  end

  let l:result = {
        \'data': {
        \'leading': l:leading,
        \'lastcall': 0,
        \'lastresult': 0,
        \'lastargs': 0,
        \'timer_id': 0,
        \'wait': a:wait},
        \'fn': a:fn
        \}

  function l:result.wrap_call_fn(...) dict
    let self.data.lastcall = reltime()
    let self.data.lastresult = call(self.fn, self.data.lastargs)
    let self.data.timer_id = 0
    return self.data.lastresult
  endfunction

  function l:result.lastresult() dict
    return self.data.lastresult
  endfunction

  function l:result.call(...) dict
    if self.data.leading
      let l:lastcall = self.data.lastcall
      let l:elapsed = reltimefloat(reltime(l:lastcall))
      if type(l:lastcall) == 0 || l:elapsed > self.data.wait / 1000.0
        let self.data.lastargs = a:000
        return self.wrap_call_fn()
      endif
    elseif self.data.timer_id == 0
      let self.data.lastargs = a:000
      let self.data.timer_id = timer_start(self.data.wait, self.wrap_call_fn)
      return '<throttled>'
    else
      return '<throttled>'
    endif
    return self.data.lastresult
  endfunction
  return l:result
endfunction

let s:ThrottledUpdatePreviewWindow = s:Throttle(funcref('s:UpdatePreviewWindow', [0]), 100, 0)
