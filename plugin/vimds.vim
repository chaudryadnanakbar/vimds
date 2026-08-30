" VimDS: DeepSeek Integration for Vim
" Derived from simo5/vimini
" Maintainer: Adnan Akbar <chaudry.adnan.akbar@gmail.com>
" Version: 1.0.0

"=============================================================================
" Initialization & Guard
"=============================================================================

if exists('g:loaded_vimds')
  finish
endif
let g:loaded_vimds = 1

"=============================================================================
" Configuration Defaults
"=============================================================================

" API Key file path (default: ~/.config/vimds.token)
let s:api_key_file = expand('~/.config/vimds.token')

" Model name - Using FREE model by default
let g:vimds_model = get(g:, 'vimds_model', 'deepseek/deepseek-r1:free')

" Temperature for generation (0.0 to 2.0, default: null)
let g:vimds_temperature = get(g:, 'vimds_temperature', v:null)

" Max tokens for responses (reasonable default to save credits)
let g:vimds_max_tokens = get(g:, 'vimds_max_tokens', 500)

" Split method for new windows ('vertical' or 'horizontal')
let g:vimds_split_method = get(g:, 'vimds_split_method', 'vertical')

" Log file path
let g:vimds_log_file = get(g:, 'vimds_log_file', expand('~/.vim/vimds_debug.log'))

" Logging state ('on' or 'off')
let g:vimds_logging = get(g:, 'vimds_logging', 'on')

" Default path for saved reviews
let g:vimds_review_path = get(g:, 'vimds_review_path', '')

" Thinking state ('on' or 'off')
let g:vimds_thinking = get(g:, 'vimds_thinking', 'off')

" Autocomplete state ('on' or 'off') - DISABLED by default
let g:vimds_autocomplete = get(g:, 'vimds_autocomplete', 'off')

" Project root for Git operations
let g:vimds_project_root = get(g:, 'vimds_project_root', '')

" Timeout for API calls
let g:vimds_timeout = get(g:, 'vimds_timeout', 30)

" Window direction for splits
let g:vimds_window_direction = get(g:, 'vimds_window_direction', 'vertical')
let g:vimds_window_size = get(g:, 'vimds_window_size', 50)

" Active attachment URI (internal)
let g:vimds_active_attachment_uri = get(g:, 'vimds_active_attachment_uri', '')
let g:vimds_active_attachment_mime = get(g:, 'vimds_active_attachment_mime', '')
let g:vimds_active_attachment_name = get(g:, 'vimds_active_attachment_name', '')

" Agent Channel (internal)
let g:vimds_channel = get(g:, 'vimds_channel', v:null)

" API URL for OpenRouter
let g:vimds_base_url = get(g:, 'vimds_base_url', 'https://openrouter.ai/api/v1')

" Chat state
let g:vimds_chat_open = 0

" Disable debug mode
set debug=

"=============================================================================
" Plugin Setup
"=============================================================================

let s:plugin_root_dir = fnamemodify(resolve(expand('<sfile>:p')), ':h')
let s:socket_path = ''

"=============================================================================
" Python Integration
"=============================================================================

function! VimdsChannelCallback(channel, msg)
  py3 << EOF
try:
    import json
    from vimds import main
    
    msg = vim.eval('a:msg')
    
    # Try to parse the response
    if isinstance(msg, str):
        try:
            data = json.loads(msg)
        except:
            data = msg
    else:
        data = msg
    
    # Handle the response
    if isinstance(data, dict):
        if 'response' in data:
            # Add AI response to chat buffer
            response = data['response'].replace("'", "''")
            response = response.replace('"', '&quot;')
            try:
                vim.command("call cursor(line('$')-2, 1)")
                vim.command("delete")
                vim.command("call cursor(line('$')-1, 1)")
                vim.command("delete")
                vim.command(f"call append(line('$'), 'AI: {response}')")
                vim.command("call append(line('$'), '')")
                vim.command("call cursor(line('$'), 1)")
            except Exception as e:
                print(f"Error adding response: {e}")
        elif 'error' in data:
            error = data['error'].replace("'", "''")
            vim.command(f"echoerr '[VimDS] Error: {error}'")
    else:
        pass
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Channel callback error: {error_message}'")
EOF
endfunction

" Initialize Python environment and start agent
py3 << EOF
from os.path import normpath, join
import vim
try:
    import sys
    import os
    plugin_root_dir = vim.eval('s:plugin_root_dir')
    python_root_dir = normpath(join(plugin_root_dir, '..', 'python3'))
    sys.path.insert(0, python_root_dir)

    from vimds import main
    api_key_file = vim.eval('s:api_key_file')
    model = vim.eval('g:vimds_model')
    log_file = vim.eval('g:vimds_log_file') if vim.eval('g:vimds_logging') == 'on' else None
    max_tokens = int(vim.eval('g:vimds_max_tokens'))
    main.initialize(api_key_file=api_key_file, model=model, logfile=log_file, max_tokens=max_tokens)
    socket_path = main.start_agent()
    if socket_path:
        vim.command(f"let s:socket_path = '{socket_path}'")
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF

" Open channel to agent
if !empty(s:socket_path)
  let g:vimds_channel = ch_open('unix:' . s:socket_path, {'callback': "VimdsChannelCallback"})
endif

" Send setup message
py3 << EOF
import vim
try:
    main.send_setup()
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF

"=============================================================================
" Async Job Timer Management
"=============================================================================

let s:job_timer = -1

function! VimdsInternalProcessJobQueue(timer)
  py3 << EOF
try:
    from vimds import util
    util.process_queue()
except Exception:
    pass
EOF
endfunction

function! VimdsInternalStartJobTimer()
  if s:job_timer != -1
    call timer_stop(s:job_timer)
  endif
  let s:job_timer = timer_start(50, 'VimdsInternalProcessJobQueue', {'repeat': -1})
endfunction

function! VimdsInternalStopJobTimer()
  if s:job_timer != -1
    call timer_stop(s:job_timer)
    let s:job_timer = -1
  endif
endfunction

" Start job timer
call VimdsInternalStartJobTimer()

"=============================================================================
" Status Monitor
"=============================================================================

let s:status_timer = -1

function! VimdsInternalUpdateStatus(timer)
  py3 << EOF
try:
    from vimds import util
    util.update_status_buffer()
except Exception:
    pass
EOF
endfunction

function! VimdsInternalStartStatusTimer()
  if s:status_timer == -1
    let s:status_timer = timer_start(1000, 'VimdsInternalUpdateStatus', {'repeat': -1})
  endif
endfunction

function! VimdsInternalStopStatusTimer()
  if s:status_timer != -1
    call timer_stop(s:status_timer)
    let s:status_timer = -1
  endif
endfunction

" Start status timer
call VimdsInternalStartStatusTimer()

"=============================================================================
" Chat Window Functions
"=============================================================================

" Function to open chat window
function! VimdsChat()
  " Check if chat window already exists
  let l:bufname = 'VimDS-Chat'
  let l:bufnr = bufnr(l:bufname)
  
  if l:bufnr != -1 && buflisted(l:bufnr)
    " Switch to existing chat buffer
    execute 'buffer' l:bufnr
    let g:vimds_chat_open = 1
    return
  endif
  
  " Create new chat buffer
  execute 'new ' . l:bufname
  
  " Set buffer options
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal filetype=vimds
  setlocal modifiable
  setlocal wrap
  setlocal linebreak
  
  " Add header
  call setline(1, '╔═══════════════════════════════════════════════════════════╗')
  call setline(2, '║  VimDS - DeepSeek Chat (FREE Model)                    ║')
  call setline(3, '║  Type your message below and press Enter                ║')
  call setline(4, '║  Press Esc or q to close                               ║')
  call setline(5, '╚═══════════════════════════════════════════════════════════╝')
  call setline(6, '')
  call setline(7, '')
  
  " Move cursor to the end
  call cursor(line('$'), 1)
  
  " Set up key mappings for this buffer
  nnoremap <buffer> <CR> :call <SID>VimdsChatSubmit()<CR>
  nnoremap <buffer> <Esc> :call <SID>VimdsChatClose()<CR>
  nnoremap <buffer> q :call <SID>VimdsChatClose()<CR>
  
  " Set up insert mode mapping
  inoremap <buffer> <CR> <Esc>:call <SID>VimdsChatSubmit()<CR>
  
  let g:vimds_chat_open = 1
  echo "[VimDS] Chat opened. Type your message and press Enter."
endfunction

" Function to close chat window
function! s:VimdsChatClose()
  let g:vimds_chat_open = 0
  bdelete
  echo "[VimDS] Chat closed"
endfunction

" Function to handle chat submission
function! s:VimdsChatSubmit()
  " Get the current line content
  let l:line = getline('.')
  
  " If line is empty or is a separator, do nothing
  if l:line == '' || l:line =~ '^---' || l:line =~ '^AI:' || l:line =~ '^You:'
    return
  endif
  
  " Save the user message
  let l:user_msg = l:line
  
  " Clear the current line
  call setline('.', '')
  
  " Add user message with separator
  call append(line('.'), '--- You: ' . l:user_msg)
  call append(line('.') + 1, '')
  
  " Move cursor to the end
  call cursor(line('$'), 1)
  
  " Add a waiting message
  call append(line('$'), 'AI: Thinking...')
  call append(line('$'), '')
  call cursor(line('$') - 1, 1)
  
  " Send to Python backend via the channel
  if exists('g:vimds_channel') && type(g:vimds_channel) == v:t_channel && ch_status(g:vimds_channel) ==# 'open'
    let l:request = {'command': 'submit', 'message': l:user_msg}
    call ch_sendexpr(g:vimds_channel, l:request)
  else
    " Fallback: Direct Python call
    py3 << EOF
try:
    import json
    from vimds import main
    
    msg = vim.eval('l:user_msg')
    
    # Process the message
    data = {'command': 'submit', 'message': msg}
    result = main._process_message(json.dumps(data))
    
    if result and isinstance(result, dict):
        if 'response' in result:
            # Remove the "Thinking..." line
            vim.command("call cursor(line('$')-2, 1)")
            vim.command("delete")
            vim.command("call cursor(line('$')-1, 1)")
            vim.command("delete")
            # Add the response
            response = result['response'].replace("'", "''")
            vim.command(f"call append(line('$'), 'AI: {response}')")
            vim.command("call append(line('$'), '')")
            vim.command("call cursor(line('$'), 1)")
        elif 'error' in result:
            vim.command(f"echoerr '[VimDS] Error: {result['error']}'")
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
  endif
endfunction

"=============================================================================
" Command Definitions
"=============================================================================

" List available models
function! VimdsListModels()
  if !exists('g:vimds_channel') || type(g:vimds_channel) != v:t_channel || ch_status(g:vimds_channel) !=# 'open'
    echoerr '[VimDS] Error: Agent server channel is not open.'
    return
  endif
  echo '[VimDS] Fetching models...'
  try
    let l:req = py3eval('main.list_models()')
    call ch_sendexpr(g:vimds_channel, l:req)
  catch
    let l:error_message = substitute(v:exception, "'", "''", 'g')
    echoerr '[VimDS] Error: ' . l:error_message
  endtry
endfunction

command! VimdsListModels call VimdsListModels()

" Chat with DeepSeek
command! VimdsChat call VimdsChat()

" Close chat
command! VimdsChatClose call s:VimdsChatClose()

" Submit message in chat
command! VimdsSubmit call s:VimdsChatSubmit()

" Toggle thinking on/off
function! VimdsThinking(...)
  let l:option = get(a:, 1, '')

  if !empty(l:option)
    if l:option ==# 'on' || l:option ==# 'off'
      let g:vimds_thinking = l:option
    else
      echoerr "[VimDS] Invalid argument for VimdsThinking. Use 'on' or 'off'."
      return
    endif
  else
    let g:vimds_thinking = g:vimds_thinking ==# 'on' ? 'off' : 'on'
  endif

  echo "[VimDS] Thinking is now " . g:vimds_thinking
endfunction

command! -nargs=? VimdsThinking call VimdsThinking(<f-args>)

" Toggle logging on/off
function! VimdsToggleLogging(...)
  let l:option = get(a:, 1, '')

  if !empty(l:option)
    if l:option ==# 'on' || l:option ==# 'off'
      let g:vimds_logging = l:option
    else
      echoerr "[VimDS] Invalid argument for VimdsToggleLogging. Use 'on' or 'off'."
      return
    endif
  else
    let g:vimds_logging = g:vimds_logging ==# 'on' ? 'off' : 'on'
  endif

  py3 << EOF
try:
    from vimds import main
    log_state = vim.eval('g:vimds_logging')
    if log_state == 'on':
        log_file = vim.eval('g:vimds_log_file')
        main.set_logging(log_file)
    else:
        main.set_logging()
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error setting log state: {error_message}'")
EOF

  echo "[VimDS] Logging is now " . g:vimds_logging
endfunction

command! -nargs=? VimdsToggleLogging call VimdsToggleLogging(<f-args>)

" Generate code
function! VimdsCode(prompt)
  py3 << EOF
try:
    from vimds import main
    prompt = vim.eval('a:prompt')
    verbose = vim.eval('g:vimds_thinking') == 'on'
    temperature = vim.eval("get(g:, 'vimds_temperature', v:null)")
    main.code(prompt, verbose=verbose, temperature=temperature)
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=* VimdsCode call VimdsCode(string(<q-args>))

" Apply generated code
function! VimdsApply(...)
  let l:job_id = a:0 > 0 ? a:1 : v:null

  py3 << EOF
try:
    from vimds import main
    job_id_arg = vim.eval('l:job_id')
    job_id = int(job_id_arg) if job_id_arg is not None else None
    main.apply_code(job_id=job_id)
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=* VimdsApply call VimdsApply(<f-args>)

" Review git diffs
function! VimdsReview(args)
  let l:git_objects_arg = v:null
  let l:prompt_arg = ''
  let l:security_focus = 0
  let l:save_review = 0
  let l:save_path = ''
  let l:args = a:args

  " Parse --save=path
  let l:idx = 0
  while l:idx < len(l:args)
    if l:args[l:idx] =~# '^--save='
      let l:save_path = substitute(l:args[l:idx], '^--save=', '', '')
      call remove(l:args, l:idx)
      let l:save_review = 1
      continue
    endif
    let l:idx += 1
  endwhile

  " Parse -c for git objects
  let l:c_idx = index(l:args, '-c')
  if l:c_idx != -1
    if l:c_idx + 1 < len(l:args)
      let l:git_objects_arg = l:args[l:c_idx + 1]
      call remove(l:args, l:c_idx, l:c_idx + 1)
    else
      echoerr "[VimDS] Error: -c option requires an argument."
      return
    endif
  endif

  " Parse --security flag
  let l:s_idx = index(l:args, '--security')
  if l:s_idx != -1
    let l:security_focus = 1
    call remove(l:args, l:s_idx)
  endif

  " Parse --save flag
  let l:save_idx = index(l:args, '--save')
  if l:save_idx != -1
    let l:save_review = 1
    call remove(l:args, l:save_idx)
  endif

  let l:prompt_arg = join(l:args, ' ')

  py3 << EOF
try:
    from vimds import main
    prompt = vim.eval('l:prompt_arg')
    git_objects = vim.eval('l:git_objects_arg')
    security_focus = bool(int(vim.eval('l:security_focus')))
    save_review = bool(int(vim.eval('l:save_review')))
    save_path = vim.eval('l:save_path')
    verbose = vim.eval('g:vimds_thinking') == 'on'
    temperature = vim.eval("get(g:, 'vimds_temperature', v:null)")
    main.review(prompt, git_objects=git_objects, security_focus=security_focus, 
                verbose=verbose, temperature=temperature, save=save_review, 
                save_path=save_path)
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=* VimdsReview call VimdsReview([<f-args>])

" Show git diff
function! VimdsDiff()
  py3 << EOF
try:
    from vimds import main
    main.show_diff()
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! VimdsDiff call VimdsDiff()

" Generate and execute git commit
function! VimdsCommit(q_args)
  let l:assistant = 1
  let l:regenerate = 0
  let l:amend = 0
  let l:other_args = []
  let l:args = split(a:q_args)
  
  for l:arg in l:args
    if l:arg ==# '-n'
      let l:assistant = 0
    elseif l:arg ==# '-r'
      let l:regenerate = 1
    elseif l:arg ==# '-a'
      let l:amend = 1
    else
      call add(l:other_args, l:arg)
    endif
  endfor
  
  let l:prompt_refinement = join(l:other_args, ' ')

  py3 << EOF
try:
    from vimds import main
    assistant = bool(int(vim.eval('l:assistant')))
    regenerate = bool(int(vim.eval('l:regenerate')))
    amend = bool(int(vim.eval('l:amend')))
    refinement = vim.eval('l:prompt_refinement')
    temperature = vim.eval("get(g:, 'vimds_temperature', v:null)")
    main.commit(assistant=assistant, temperature=temperature, regenerate=regenerate, 
                amend=amend, refinement=refinement)
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=* VimdsCommit call VimdsCommit(<q-args>)

" Manage uploaded files
function! VimdsFiles()
  py3 << EOF
try:
    from vimds import main
    main.files_command()
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=0 VimdsFiles call VimdsFiles()

" Manage context files
function! VimdsContextFiles()
  py3 << EOF
try:
    from vimds import main
    main.context_files_command()
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=0 VimdsContextFiles call VimdsContextFiles()

" Manage project configuration
function! VimdsConfig()
  py3 << EOF
try:
    from vimds import main
    main.config_command()
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=0 VimdsConfig call VimdsConfig()

"=============================================================================
" Autocomplete - DISABLED
"=============================================================================

" Autocomplete function (disabled to prevent errors)
function! VimdsAutocomplete()
  return
endfunction

let s:autocomplete_timer = -1

function! VimdsToggleAutocomplete(...)
  let g:vimds_autocomplete = 'off'
  echo "[VimDS] Autocomplete is disabled"
endfunction

function! s:CancelAutocomplete()
  return
endfunction

function! s:StopAutocompleteTimer()
  return
endfunction

function! s:ResetAutocompleteTimer()
  return
endfunction

function! s:TriggerAutocomplete(timer)
  return
endfunction

" Clear autocomplete autocmds
augroup vimds_autocomplete
  autocmd!
augroup END

"=============================================================================
" Ripgrep Functions
"=============================================================================

" Ripgrep search
function! s:VimdsRipGrep(q_args)
  py3 << EOF
try:
    from vimds import main
    arg_string = vim.eval('a:q_args')
    main.ripgrep_command(arg_string)
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=* VimdsRipGrep call s:VimdsRipGrep(<q-args>)

" Apply ripgrep results
function! VimdsRipGrepApply()
  py3 << EOF
try:
    from vimds import main
    main.ripgrep_apply()
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=0 VimdsRipGrepApply call VimdsRipGrepApply()

" Help
function! VimdsHelp(...)
  let l:cmd = get(a:, 1, '')
  py3 << EOF
try:
    from vimds import main
    cmd = vim.eval('l:cmd')
    main.help(cmd)
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=? -complete=command VimdsHelp call VimdsHelp(<f-args>)

" Status
function! VimdsStatus()
  py3 << EOF
try:
    from vimds import main
    main.status_command()
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! VimdsStatus call VimdsStatus()

" Reload VimDS
function! VimdsReload()
  if exists('g:vimds_channel') && type(g:vimds_channel) == v:t_channel && ch_status(g:vimds_channel) ==# 'open'
    call ch_close(g:vimds_channel)
    let g:vimds_channel = v:null
  endif

  let s:socket_path = ''

  py3 << EOF
try:
    from vimds import main
    main.stop_agent()
    main.reload_vimds()
    from vimds import main as reloaded_main
    socket_path = reloaded_main.start_agent()
    if socket_path:
        vim.command(f"let s:socket_path = '{socket_path}'")
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error reloading: {error_message}'")
EOF

  if !empty(s:socket_path)
    let g:vimds_channel = ch_open('unix:' . s:socket_path, {'callback': "VimdsChannelCallback"})
  endif

  py3 << EOF
import vim
try:
    main.send_setup()
except Exception as e:
    error_message = str(e).replace("'", "''")
    vim.command(f"echoerr '[VimDS] Error: {error_message}'")
EOF
endfunction

command! -nargs=0 VimdsReload call VimdsReload()

"=============================================================================
" User Functions for Visual Selection and File Attachment
"=============================================================================

" Function to send visually selected text to AI
function! VimdsVisualCode(prompt)
    " 1. Save the contents of the unnamed register
    let l:saved_reg = @@
    
    " 2. Yank the current visual selection into the unnamed register
    silent normal! gvy
    let l:selected_text = @@
    
    " 3. Restore the original register state
    let @@ = l:saved_reg
    
    " 4. Open the chat window
    call VimdsChat()
    
    " 5. Paste the instructions and the exact selection into the AI scratchpad
    call append(line('$'), 'Context code block:')
    call append(line('$'), split(l:selected_text, "\n"))
    call append(line('$'), '---')
    call append(line('$'), a:prompt)
    
    " 6. Move cursor to the bottom and simulate pressing Enter to trigger submission
    normal! G
    execute "normal \<CR>"
endfunction

" Function to attach files to the chat
function! VimdsAttachFile(file_path)
    let l:expanded_path = expand(a:file_path)
    if !filereadable(l:expanded_path)
        echoerr "[VimDS] Error: File not found at " . l:expanded_path
        return
    endif

    let l:filename = fnamemodify(l:expanded_path, ':t')
    let l:extension = tolower(fnamemodify(l:expanded_path, ':e'))

    " For text-based files, read and include content
    if l:extension == 'txt' || l:extension == 'md' || l:extension == 'py' || 
       \ l:extension == 'vim' || l:extension == 'c' || l:extension == 'h' ||
       \ l:extension == 'cpp' || l:extension == 'hpp' || l:extension == 'js' ||
       \ l:extension == 'html' || l:extension == 'css' || l:extension == 'json' ||
       \ l:extension == 'xml' || l:extension == 'yaml' || l:extension == 'toml' ||
       \ l:extension == 'sh' || l:extension == 'bash' || l:extension == 'go' ||
       \ l:extension == 'rs' || l:extension == 'java' || l:extension == 'rb'
        let l:header = ["", "### ATTACHED FILE CONTEXT: " . l:filename, "```" . l:extension]
        let l:content = readfile(l:expanded_path)
        let l:footer = ["```", ""]
        call append(line('$'), l:header + l:content + l:footer)
        echo "File attached: " . l:filename
        
    " For images and other binary files, provide a placeholder
    else
        let l:header = ["", "📎 [FILE ATTACHED]: " . l:filename, 
                       \ "Type your prompt below to reference this file.", ""]
        call append(line('$'), l:header)
        echo "File reference attached: " . l:filename
    endif

    normal! G
    echo "File attached successfully!"
endfunction

" Create a user command that autocompletes filenames as you type
command! -nargs=1 -complete=file VimdsAttach call VimdsAttachFile(<q-args>)

"=============================================================================
" Key Mappings
"=============================================================================

" Normal mode: Press \c to instantly open or jump to AI chat
nnoremap <leader>c :VimdsChat<CR>

" Visual mode: Press \a to send selected text to AI
vnoremap <leader>a :<C-u>call VimdsVisualCode(input("AI Instructions: "))<CR>

" Normal mode: Press \f to trigger file attachment picker
nnoremap <leader>f :VimdsAttach 

"=============================================================================
" Autocommands
"=============================================================================

" Inside the AI Chat Window: Press Enter on an empty line to instantly submit
augroup vimds_chat_autocmd
  autocmd!
  autocmd FileType vimds nnoremap <buffer> <CR> :VimdsSubmit<CR>
  autocmd FileType vimds nnoremap <buffer> q :VimdsChatClose<CR>
  autocmd FileType vimds nnoremap <buffer> <Esc> :VimdsChatClose<CR>
augroup END

"=============================================================================
" Shutdown
"=============================================================================

function! s:VimdsShutdown()
  if exists('g:vimds_channel') && type(g:vimds_channel) == v:t_channel && ch_status(g:vimds_channel) ==# 'open'
    call ch_close(g:vimds_channel)
    let g:vimds_channel = v:null
  endif

  call VimdsInternalStopJobTimer()
  call VimdsInternalStopStatusTimer()

  py3 << EOF
try:
    from vimds import main
    main.stop_agent()
except Exception:
    pass
EOF
endfunction

augroup vimds_shutdown
  autocmd!
  autocmd VimLeavePre * call s:VimdsShutdown()
augroup END

"=============================================================================
" Completion for Commands
"=============================================================================

" Command completion for VimDS commands
function! s:VimdsComplete(ArgLead, CmdLine, CursorPos)
  let l:commands = ['VimdsListModels', 'VimdsChat', 'VimdsChatClose', 'VimdsSubmit', 'VimdsThinking', 
                   \ 'VimdsToggleLogging', 'VimdsCode', 'VimdsApply',
                   \ 'VimdsReview', 'VimdsDiff', 'VimdsCommit',
                   \ 'VimdsFiles', 'VimdsContextFiles', 'VimdsConfig',
                   \ 'VimdsToggleAutocomplete', 'VimdsRipGrep',
                   \ 'VimdsRipGrepApply', 'VimdsHelp', 'VimdsStatus',
                   \ 'VimdsReload', 'VimdsAttach']
  return filter(l:commands, 'v:val =~# "^" . a:ArgLead')
endfunction

"=============================================================================
" End of Plugin
"=============================================================================

echo "[VimDS] Plugin loaded successfully! (Using FREE models)"
