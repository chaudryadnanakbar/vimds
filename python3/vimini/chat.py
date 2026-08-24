import vim
import json
import os
from vimini import util, context
from vimini.code import _DIFF_SEPARATOR, _process_x_diff_chunks

WAITING_MSG = "Waiting for prompt (CTRL-W q to exit)"
WELCOME_MSG = "Welcome to Vimini! Waiting for prompt (CTRL-W q to exit)"
HINT_MSG = "Press Enter twice to submit prompt"

Q_prefix = "Q: "
A_prefix = "A: "

def _to_str(val):
    if isinstance(val, bytes):
        return val.decode('utf-8', errors='replace')
    return str(val) if val is not None else ""

def _get_buffer(buf_num):
    buffer = None
    if vim.current.buffer.number == buf_num:
        buffer = vim.current.buffer
    else:
        for b in vim.buffers:
            if b.number == buf_num:
                buffer = b
                break
    return buffer

def _find_chat_buffer(req_id):
    if not req_id:
        return None
    try:
        for b in vim.buffers:
            job_id = b.vars.get("vimini_job_id")
            if job_id is not None and _to_str(job_id) == str(req_id):
                return b
    except Exception:
        pass
    return None

def _prompt_window_exists(req_id=None):
    for w in vim.windows:
        try:
            if w.buffer.name and os.path.basename(w.buffer.name) == "Prompt":
                if req_id is not None:
                    p_req = _to_str(w.buffer.vars.get("vimini_prompt_req_id", ""))
                    if not p_req or p_req == str(req_id):
                        return True
                else:
                    return True
        except Exception:
            pass
    return False

def _check_prompt_buffer(buf_num):
    try:
        prompt_buf = _get_buffer(buf_num)
        if prompt_buf is None:
            return

        if bool(prompt_buf.vars.get("vimini_submitting", False)):
            return

        lines = list(prompt_buf[:])
        if lines and lines[0].strip() == HINT_MSG:
            lines = lines[1:]

        has_text = False
        for i, line in enumerate(lines):
            if line.strip():
                has_text = True
            elif has_text:
                if i < len(lines) - 1:
                    prompt_text = "\n".join(lines[:i]).strip()
                    if prompt_text:
                        prompt_buf.vars["vimini_submitting"] = True
                        submit_prompt(buf_num, prompt_text=prompt_text)
                    return
    except Exception as e:
        util.log_info(f"Error in _check_prompt_buffer: {e}")

def _open_prompt_window(req_id):
    try:
        chat_buf = _find_chat_buffer(req_id)
        if not chat_buf:
            return

        if vim.current.buffer.number != chat_buf.number:
            return

        for b in vim.buffers:
            if b.name and os.path.basename(b.name) == "Prompt":
                try:
                    vim.command(f"bwipeout! {b.number}")
                except Exception:
                    pass

        vim.command("belowright 5new")
        prompt_buf = vim.current.buffer
        prompt_buf_num = prompt_buf.number

        vim.command("silent! file Prompt")
        prompt_buf.options["buftype"] = "nofile"
        prompt_buf.options["bufhidden"] = "wipe"
        prompt_buf.options["swapfile"] = False
        prompt_buf.options["modifiable"] = True

        prompt_buf.vars["vimini_prompt_req_id"] = req_id
        prompt_buf.vars["vimini_submitting"] = False

        if chat_buf:
            chat_buf.vars["vimini_prompt_buf_num"] = prompt_buf_num

        prompt_buf[:] = [HINT_MSG, ""]

        vim.command("highlight default ViminiPromptHint ctermfg=Green guifg=Green cterm=italic gui=italic")
        vim.command("syntax match ViminiPromptHint '^Press Enter twice to submit prompt$'")

        vim.command(f"autocmd TextChanged,TextChangedI,TextChangedP,InsertLeave <buffer> py3 from vimini.chat import _check_prompt_buffer; _check_prompt_buffer({prompt_buf_num})")

        vim.current.window.cursor = (2, 0)
        vim.command("startinsert")
    except Exception as e:
        util.log_info(f"Error opening prompt window: {e}")

def _on_chat_buf_enter(buf_num):
    try:
        buffer = _get_buffer(buf_num)
        if buffer is None:
            return
        if vim.current.buffer.number != buffer.number:
            return
        is_waiting = bool(buffer.vars.get("vimini_waiting", False))
        if is_waiting:
            return
        req_id = _to_str(buffer.vars.get("vimini_job_id", ""))
        if not req_id:
            return
        if not _prompt_window_exists(req_id):
            _open_prompt_window(req_id)
    except Exception as e:
        util.log_info(f"Error in _on_chat_buf_enter: {e}")

def submit_prompt(prompt_buf_num=None, prompt_text=None):
    try:
        util.log_info(f"Submit prompt {prompt_buf_num}")
        if prompt_buf_num is None:
            prompt_buf = vim.current.buffer
        else:
            prompt_buf = _get_buffer(prompt_buf_num)

        if prompt_buf is None:
            return

        req_id = _to_str(prompt_buf.vars.get("vimini_prompt_req_id", ""))
        chat_buf = _find_chat_buffer(req_id)

        if prompt_text is not None:
            prompt = prompt_text.strip()
        else:
            content = "\n".join(prompt_buf[:])
            lines = [l for l in content.split('\n') if l.strip() != HINT_MSG]
            prompt = "\n".join(lines).strip()

        vim.command("stopinsert")
        try:
            vim.command(f"bwipeout! {prompt_buf.number}")
        except Exception as e:
            util.log_info(f"Error closing prompt buffer: {e}")

        if not prompt:
            if chat_buf:
                _open_prompt_window(req_id)
            return

        if chat_buf:
            _send_prompt(prompt, chat_buf)
    except Exception as e:
        util.log_info(f"Error submitting prompt: {e}")

def send_agent_approval(approved, req_id):
    req = {
        "jsonrpc": "2.0",
        "id": req_id,
        "method": "chat",
        "params": {
            "approved": bool(approved)
        }
    }
    util.send_channel_request(req, True)

def send_chat_termination(req_id):
    req = {
        "jsonrpc": "2.0",
        "id": req_id,
        "method": "chat",
        "params": {
            "terminate": True
        }
    }
    util.send_channel_request(req, True)

def _on_chat_buffer_closed(buf_num):
    try:
        buffer = _get_buffer(buf_num)
        req_id = ""
        prompt_buf_num = None
        if buffer is not None:
            buffer.vars["vimini_waiting"] = False
            req_id = _to_str(buffer.vars.get("vimini_job_id", ""))
            prompt_buf_num = buffer.vars.get("vimini_prompt_buf_num")

        prompt_buffers = []
        if prompt_buf_num:
            prompt_buffers.append(prompt_buf_num)

        for b in vim.buffers:
            try:
                if b.name and os.path.basename(b.name) == "Prompt":
                    p_req = _to_str(b.vars.get("vimini_prompt_req_id", ""))
                    if not req_id or p_req == req_id:
                        prompt_buffers.append(b.number)
            except Exception:
                pass

        for p_num in set(prompt_buffers):
            try:
                vim.command(f"bwipeout! {p_num}")
            except Exception:
                pass

        if req_id:
            send_chat_termination(req_id)
        util.display_message("Chat session has been terminated.", history=True)
    except Exception as e:
        util.log_info(f"Error in _on_chat_buffer_closed: {e}")

def _on_patch_buffer_closed(req_id):
    try:
        handled = int(vim.eval("get(b:, 'vimini_patch_handled', 0)"))
        if handled:
            return
        vim.command("let b:vimini_patch_handled = 1")
        util.display_message("Patch buffer closed without applying. Canceling operation...", history=True)
        send_agent_approval(False, req_id)
    except Exception as e:
        util.log_info(f"Error in _on_patch_buffer_closed: {e}")

def _open_patch_buffer(temp_file, req_id):
    if not temp_file or not os.path.exists(temp_file):
        util.display_message("Error: Patch temp file does not exist.", error=True)
        send_agent_approval(False, req_id)
        return

    diff_content = ""
    try:
        with open(temp_file, 'r', encoding='utf-8') as f:
            diff_content = f.read()
    except Exception as e:
        util.log_info(f"Error reading patch temp file: {e}")

    if not diff_content.strip():
        util.display_message("Error: Patch content is empty.", error=True)
        send_agent_approval(False, req_id)
        return

    try:
        project_root = util.get_git_repo_root()
        if not project_root:
            util.display_message("Error: Patches can only be applied to git repositories.", error=True)
            project_root = os.getcwd()

        fixed_lines = []
        raw_chunks = []
        current_chunk = []
        for line in diff_content.strip('\n').split('\n'):
            if line.startswith("diff --git ") or line.startswith("--- "):
                if current_chunk and any(l.startswith("@@ ") or l.startswith("+++ ") for l in current_chunk):
                    raw_chunks.append(current_chunk)
                    current_chunk = []
            current_chunk.append(line)
        if current_chunk:
            raw_chunks.append(current_chunk)

        for chunk in raw_chunks:
            rel_path = None
            for l in chunk:
                if l.startswith("--- "):
                    p = l[4:].strip().split('\t')[0]
                    if p != "/dev/null":
                        if p.startswith("a/"): p = p[2:]
                        rel_path = p
                        break
                elif l.startswith("+++ "):
                    p = l[4:].strip().split('\t')[0]
                    if p != "/dev/null":
                        if p.startswith("b/"): p = p[2:]
                        rel_path = p
                        break
                elif l.startswith("diff --git "):
                    parts = l.split()
                    if len(parts) >= 4:
                        p = parts[3]
                        if p.startswith("b/"): p = p[2:]
                        elif p.startswith("a/"): p = p[2:]
                        rel_path = p
                        break

            abs_path = os.path.join(project_root, rel_path) if rel_path else None
            file_exists = os.path.exists(abs_path) if abs_path else True
            chunk_str = "\n".join(chunk)
            processed = _process_x_diff_chunks(chunk_str, rel_path or "", file_exists)
            if processed:
                fixed_lines.extend(processed)
            else:
                fixed_lines.extend(chunk)

        if fixed_lines:
            diff_content = "\n".join(fixed_lines) + "\n"
    except Exception as e:
        util.log_info(f"Error processing patch temp file: {e}")

    try:
        util.new_split()
        base_buffer_name = f"[{req_id}] Vimini Code"
        safe_name = base_buffer_name.replace(" ", "\\ ")
        vim.command(f"file {safe_name}")
        buffer = vim.current.buffer
        buffer.options["buftype"] = "nofile"
        buffer.options["bufhidden"] = "wipe"
        buffer.options["swapfile"] = 0

        buffer.vars["vimini_project_root"] = project_root
        buffer.vars["vimini_chat_job_id"] = req_id
        buffer.vars["vimini_is_chat_patch"] = 1
        buffer.vars["vimini_patch_handled"] = 0

        summary_lines = [
            f"# Request Summary (Chat Patch - Req Id {req_id})",
            "",
            "## Agent Patch Request",
            "The agent requested code modifications below.",
            "Run :ViminiApply to apply these changes, or close this buffer (:q) to cancel.",
            "",
            "---",
            "",
            _DIFF_SEPARATOR
        ]
        if not diff_content.endswith('\n'):
            diff_content += '\n'

        buffer[:] = summary_lines + diff_content.splitlines()

        buffer.options["filetype"] = "diff"
        vim.command(f"autocmd BufUnload <buffer> py3 from vimini.chat import _on_patch_buffer_closed; _on_patch_buffer_closed({req_id})")

        util.display_message("Patch buffer opened. Run :ViminiApply to apply changes.", history=True)
        vim.command("redraw!")
    except Exception as e:
        util.log_info(f"Error creating patch buffer: {e}")

def handle_channel_response(req_id, result):
    status = result.get("status")
    buffer = _find_chat_buffer(req_id)

    if buffer is None:
        return

    if status == "chunk":
        text = result.get("text", "")
        if text:
            _write_to_buffer(buffer, text, append_to_last=True)

    elif status == "tool_use_requested":
        tool = result.get("tool", "")
        temp_file = result.get("temp_file")

        if tool == "apply_patch":
            req_line = f"\nAgent Requested: apply_patch({temp_file})"
        else:
            args = result.get("args", {})
            if isinstance(args, dict):
                args_str = ", ".join(f"{k}={repr(v)}" for k, v in args.items())
            else:
                args_str = str(args) if args else ""
            req_line = f"\nAgent Requested: {tool}({args_str})"

        _write_to_buffer(buffer, req_line, append_to_last=True)

        if tool in ("list_directory", "read_file"):
            send_agent_approval(True, req_id)
        elif tool == "apply_patch":
            _open_patch_buffer(temp_file, req_id)
        else:
            send_agent_approval(False, req_id)

    elif status in ("done", "ok"):
        buffer.vars["vimini_waiting"] = False
        text = result.get("text", "")
        if text:
            _write_to_buffer(buffer, text, append_to_last=True)
        _write_to_buffer(buffer, ["", WAITING_MSG])
        _open_prompt_window(req_id)

    elif status == "terminated":
        buffer.vars["vimini_waiting"] = False

    elif status == "error":
        buffer.vars["vimini_waiting"] = False
        err_msg = result.get("error", "Unknown error")
        _write_to_buffer(buffer, [f"\n[Error: {err_msg}]", "", WAITING_MSG])
        _open_prompt_window(req_id)

def _send_prompt(prompt, buffer):
    if prompt.startswith(":"):
        try:
            vim.command(prompt[1:])
        except Exception as e:
            util.display_message(f"Error: {e}", error=True)
        return

    if len(buffer) > 0 and buffer[-1] in (WAITING_MSG, WELCOME_MSG):
        buffer.options["modifiable"] = 1
        try:
            if len(buffer) == 1:
                buffer[:] = []
            else:
                del buffer[-1]
        finally:
            buffer.options["modifiable"] = 0

    last_line = buffer[-1] if len(buffer) > 0 else ""
    lines_to_add = []
    if last_line != "":
        lines_to_add.append("")

    lines_to_add.append(f"{Q_prefix}{prompt}")
    lines_to_add.append("---")
    lines_to_add.append(A_prefix)

    _write_to_buffer(buffer, lines_to_add)

    buffer.vars["vimini_waiting"] = True

    req = {
        "jsonrpc": "2.0",
        "id": _to_str(buffer.vars.get("vimini_job_id", "")),
        "method": "chat",
        "params": {
            "prompt": prompt,
        }
    }

    if not util.send_channel_request(req, False):
        buffer.vars["vimini_waiting"] = False
        _write_to_buffer(buffer, ["", "[Error: Agent channel is not open]", "", WAITING_MSG])
        _open_prompt_window(_to_str(buffer.vars.get("vimini_job_id", "")))
    else:
        util.display_message("Command has been sent and waiting for chat response")

def chat():
    req_id = str(util.reserve_next_job_id("Chat"))

    util.new_split()
    buffer = vim.current.buffer
    buf_num = buffer.number
    buffer_name = f"[{req_id}] Vimini Chat"
    vim.command(f"file {buffer_name}")
    util.log_info(f"New chat in buffer <{buffer_name}>")

    buffer.options["buftype"] = "nofile"
    buffer.options["bufhidden"] = "wipe"
    buffer.options["filetype"] = "markdown"
    buffer.options["swapfile"] = 0
    buffer.options["modifiable"] = 0
    vim.command("highlight default ViminiWaiting ctermfg=Green guifg=Green")
    vim.command("highlight default ViminiPrompt ctermfg=DarkBlue guifg=DarkBlue")
    vim.command("highlight default ViminiService ctermfg=Green guifg=Green cterm=italic gui=italic")
    vim.command("syntax match ViminiWaiting '^\\(Welcome.*\\|Waiting for prompt.*\\)'")
    vim.command("syntax match ViminiPrompt '^Q: .*'")
    vim.command("syntax match ViminiService '^Agent Requested: .*'")
    vim.command(f"autocmd BufUnload <buffer> py3 from vimini.chat import _on_chat_buffer_closed; _on_chat_buffer_closed({buf_num})")
    vim.command(f"autocmd BufEnter <buffer> py3 from vimini.chat import _on_chat_buf_enter; _on_chat_buf_enter({buf_num})")

    buffer.vars["vimini_job_id"] = req_id
    buffer.vars["vimini_waiting"] = False

    _write_to_buffer(buffer, [WELCOME_MSG], clear=True)
    _open_prompt_window(req_id)

def _write_to_buffer(buffer, content, clear=False, append_to_last=False):
    buffer.options["modifiable"] = 1
    try:
        if clear:
            buffer[:] = content if isinstance(content, list) else [content]
        else:
            if append_to_last and isinstance(content, str):
                if len(buffer) > 0 and buffer[-1].startswith("Agent Requested:"):
                    if not content.startswith('\n'):
                        content = '\n' + content
                lines = content.split('\n')
                if len(buffer) > 0:
                    buffer[-1] += lines[0]
                else:
                    buffer[:] = [lines[0]]
                if len(lines) > 1:
                    buffer.append(lines[1:])
            else:
                if isinstance(content, str):
                    content = content.split('\n')
                buffer.append(content)

        chat_win_nr = None
        curr_win_nr = None
        for w in vim.windows:
            if w.buffer.number == buffer.number:
                chat_win_nr = w.number
            if w == vim.current.window:
                curr_win_nr = w.number

        if chat_win_nr is not None:
            if curr_win_nr == chat_win_nr:
                vim.command("normal! G")
            else:
                vim.command(f"noautocmd {chat_win_nr}wincmd w")
                vim.command("normal! G")
                if curr_win_nr is not None:
                    vim.command(f"noautocmd {curr_win_nr}wincmd w")

    except Exception as e:
        util.log_info(f"Error writing to chat buffer: {e}")
    finally:
        buffer.options["modifiable"] = 0
