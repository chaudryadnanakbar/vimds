import vim
import os
import json
from . import util
from vimini.common.util import (
    PROJECT_CONFIG_SCHEMA,
    load_project_data,
    save_project_data,
    get_project_data_file_path,
    get_project_name
)

_VIMINI_PENDING_PROJECT_CONFIG = None
_VIMINI_ORIGINAL_PROJECT_CONFIG = None
_VIMINI_CONFIG_PROJECT_ROOT = None
_VIMINI_CONFIG_PROJECT_NAME = None

def _get_key_for_line(line):
    if not line:
        return None
    trimmed = line.strip()
    if trimmed.startswith('|') or trimmed.startswith('>'):
        return None
    for key in PROJECT_CONFIG_SCHEMA.keys():
        if trimmed.startswith(f"{key} ") or trimmed.startswith(f"{key}=") or trimmed.startswith(f"{key}:") or trimmed == key:
            return key
    if _VIMINI_PENDING_PROJECT_CONFIG:
        for key in _VIMINI_PENDING_PROJECT_CONFIG.keys():
            if trimmed.startswith(f"{key} ") or trimmed.startswith(f"{key}=") or trimmed.startswith(f"{key}:") or trimmed == key:
                return key
    return None

def _draw_config_listing(project_name, project_root, config_data, metadata_data):
    file_path = get_project_data_file_path(start_dir=project_root) or "(not saved)"
    context_files_count = len(metadata_data.get("files", []))
    version = metadata_data.get("version", "0.1")

    buffer_lines = [
        f"| Vimini Project Configuration: {project_name}",
        "|----------------------------------------------------------------------",
        "| <CR>/e: edit value | d: clear/unset | r: reset | q: close",
        f"| File: {file_path}",
        f"| Root: {project_root}",
        "",
        "> CONFIGURATION OPTIONS"
    ]

    all_keys = list(PROJECT_CONFIG_SCHEMA.keys())
    for k in config_data.keys():
        if k not in all_keys:
            all_keys.append(k)

    for key in all_keys:
        val = config_data.get(key)
        val_str = str(val) if val is not None else "(not set)"
        schema_info = PROJECT_CONFIG_SCHEMA.get(key, {})
        desc = schema_info.get("description", "")
        buffer_lines.append(f"  {key} = {val_str}")
        if desc:
            buffer_lines.append(f"    # {desc}")

    buffer_lines.extend([
        "",
        "> PROJECT METADATA (Read-Only)",
        f"  version = {version}",
        f"  context files = {context_files_count} file(s) tracked"
    ])

    return buffer_lines

def config_command():
    """
    Shows a new buffer with guided project configuration options.
    """
    global _VIMINI_PENDING_PROJECT_CONFIG, _VIMINI_ORIGINAL_PROJECT_CONFIG
    global _VIMINI_CONFIG_PROJECT_ROOT, _VIMINI_CONFIG_PROJECT_NAME
    util.log_info("config_command()")
    try:
        current_path = os.path.realpath(vim.eval('getcwd()'))
        project_root = util.get_git_repo_root() or current_path
        project_name = util.get_git_repo_name() or get_project_name(project_root)

        data = load_project_data(start_dir=project_root)
        config_dict = data.get("configuration", {})
        if not isinstance(config_dict, dict):
            config_dict = {}

        _VIMINI_ORIGINAL_PROJECT_CONFIG = dict(config_dict)
        _VIMINI_PENDING_PROJECT_CONFIG = dict(config_dict)
        _VIMINI_CONFIG_PROJECT_ROOT = project_root
        _VIMINI_CONFIG_PROJECT_NAME = project_name

        buffer_lines = _draw_config_listing(project_name, project_root, _VIMINI_PENDING_PROJECT_CONFIG, data)

        util.new_split()
        vim.command('file ViminiProjectConfig')
        buf = vim.current.buffer
        buf[:] = buffer_lines

        vim.command('setlocal buftype=nofile noswapfile nomodifiable')
        vim.command(f"let b:vimini_config_root = '{project_root}'")
        vim.command(f"let b:vimini_config_name = '{project_name}'")

        # Syntax highlights
        vim.command("syntax match ViminiConfigKey '^\\s*[a-zA-Z0-9_-]\\+\\ze\\s*='")
        vim.command("syntax match ViminiConfigValue '=\\s*\\zs.*$'")
        vim.command("syntax match ViminiConfigComment '^\\s*#.*$'")
        vim.command("syntax match ViminiConfigHeader '^|.*'")
        vim.command("syntax match ViminiConfigSection '^>.*'")
        vim.command("highlight default link ViminiConfigKey Identifier")
        vim.command("highlight default link ViminiConfigValue String")
        vim.command("highlight default link ViminiConfigComment Comment")
        vim.command("highlight default link ViminiConfigHeader Comment")
        vim.command("highlight default link ViminiConfigSection Title")

        # Key mappings
        vim.command("nnoremap <buffer> <silent> <CR> :py3 from vimini.config import edit_config_option; edit_config_option()<CR>")
        vim.command("nnoremap <buffer> <silent> e :py3 from vimini.config import edit_config_option; edit_config_option()<CR>")
        vim.command("nnoremap <buffer> <silent> d :py3 from vimini.config import clear_config_option; clear_config_option()<CR>")
        vim.command("nnoremap <buffer> <silent> r :py3 from vimini.config import reset_config_options; reset_config_options()<CR>")
        vim.command("nnoremap <buffer> <silent> q :q<CR>")
        vim.command("autocmd BufUnload <buffer> :py3 from vimini.config import confirm_project_config; confirm_project_config()")

        # Place cursor on first configuration option
        vim.current.window.cursor = (8, 2)
        vim.command('setlocal readonly')

    except Exception as e:
        util.display_message(f"Error opening project configuration: {e}", error=True)

def edit_config_option():
    global _VIMINI_PENDING_PROJECT_CONFIG
    try:
        buf = vim.current.buffer
        win = vim.current.window
        line_num, col = win.cursor
        line = buf[line_num - 1]

        key = _get_key_for_line(line)
        if not key:
            if line_num > 1:
                prev_line = buf[line_num - 2]
                key = _get_key_for_line(prev_line)

        if not key:
            util.display_message("No editable configuration option selected on this line.")
            return

        schema_info = PROJECT_CONFIG_SCHEMA.get(key, {})
        schema_type = schema_info.get("type")
        current_val = _VIMINI_PENDING_PROJECT_CONFIG.get(key)

        if schema_type == "boolean":
            if isinstance(current_val, bool):
                cur_bool = current_val
            elif isinstance(current_val, str):
                cur_bool = current_val.strip().lower() in ("true", "1", "yes", "on")
            elif current_val is None:
                cur_bool = bool(schema_info.get("default", False))
            else:
                cur_bool = bool(current_val)

            new_bool = not cur_bool
            _VIMINI_PENDING_PROJECT_CONFIG[key] = new_bool
            _refresh_config_buffer(win, line_num, col)
            util.display_message(f"Set '{key}' to {repr(new_bool)}")
            return

        if schema_type == "choice" or key.endswith("-permission"):
            choices = schema_info.get("choices", ["Ask", "Allow", "Deny"])
            default_val = schema_info.get("default", "Ask")
            cur_choice = current_val if current_val is not None else default_val

            idx = -1
            for i, c in enumerate(choices):
                if str(cur_choice).strip().lower() == str(c).strip().lower():
                    idx = i
                    break

            if idx == -1:
                next_val = choices[0]
            else:
                next_val = choices[(idx + 1) % len(choices)]

            _VIMINI_PENDING_PROJECT_CONFIG[key] = next_val
            _refresh_config_buffer(win, line_num, col)
            util.display_message(f"Set '{key}' to {repr(next_val)}")
            return

        cur_str = "" if current_val is None else str(current_val)

        safe_prompt = f"Enter value for {key}: ".replace("'", "''")
        safe_default = cur_str.replace("'", "''")
        new_val = vim.eval(f"input('{safe_prompt}', '{safe_default}')")

        if new_val is None:
            return

        new_val_str = new_val.strip()
        if not new_val_str:
            _VIMINI_PENDING_PROJECT_CONFIG[key] = None
        else:
            _VIMINI_PENDING_PROJECT_CONFIG[key] = new_val_str

        _refresh_config_buffer(win, line_num, col)
        val_display = repr(_VIMINI_PENDING_PROJECT_CONFIG[key]) if _VIMINI_PENDING_PROJECT_CONFIG[key] is not None else "(not set)"
        util.display_message(f"Set '{key}' to {val_display}")

    except Exception as e:
        util.display_message(f"Error editing configuration option: {e}", error=True)

def clear_config_option():
    global _VIMINI_PENDING_PROJECT_CONFIG
    try:
        buf = vim.current.buffer
        win = vim.current.window
        line_num, col = win.cursor
        line = buf[line_num - 1]

        key = _get_key_for_line(line)
        if not key and line_num > 1:
            key = _get_key_for_line(buf[line_num - 2])

        if not key:
            util.display_message("No configuration option selected on this line.")
            return

        _VIMINI_PENDING_PROJECT_CONFIG[key] = None
        _refresh_config_buffer(win, line_num, col)
        util.display_message(f"Cleared '{key}'.")

    except Exception as e:
        util.display_message(f"Error clearing configuration option: {e}", error=True)

def reset_config_options():
    global _VIMINI_PENDING_PROJECT_CONFIG, _VIMINI_ORIGINAL_PROJECT_CONFIG
    try:
        if _VIMINI_ORIGINAL_PROJECT_CONFIG is None:
            return
        _VIMINI_PENDING_PROJECT_CONFIG = dict(_VIMINI_ORIGINAL_PROJECT_CONFIG)
        win = vim.current.window
        line_num, col = win.cursor
        _refresh_config_buffer(win, line_num, col)
        util.display_message("Reset configuration options to last saved state.")
    except Exception as e:
        util.display_message(f"Error resetting configuration options: {e}", error=True)

def _refresh_config_buffer(win, line_num, col):
    project_root = _VIMINI_CONFIG_PROJECT_ROOT or vim.eval("get(b:, 'vimini_config_root', '')")
    project_name = _VIMINI_CONFIG_PROJECT_NAME or vim.eval("get(b:, 'vimini_config_name', '')")
    data = load_project_data(start_dir=project_root)
    buffer_lines = _draw_config_listing(project_name, project_root, _VIMINI_PENDING_PROJECT_CONFIG, data)

    buf = vim.current.buffer
    vim.command('setlocal modifiable')
    buf[:] = buffer_lines
    vim.command('setlocal readonly')
    vim.command("redraw")
    try:
        win.cursor = (min(line_num, len(buffer_lines)), col)
    except vim.error:
        pass

def confirm_project_config():
    global _VIMINI_PENDING_PROJECT_CONFIG, _VIMINI_ORIGINAL_PROJECT_CONFIG
    global _VIMINI_CONFIG_PROJECT_ROOT, _VIMINI_CONFIG_PROJECT_NAME
    try:
        if _VIMINI_PENDING_PROJECT_CONFIG is None or _VIMINI_ORIGINAL_PROJECT_CONFIG is None:
            return

        if _VIMINI_PENDING_PROJECT_CONFIG == _VIMINI_ORIGINAL_PROJECT_CONFIG:
            return

        project_root = _VIMINI_CONFIG_PROJECT_ROOT or util.get_git_repo_root() or os.getcwd()

        popup_content = ["Save project configuration changes?", ""]
        for k, v in _VIMINI_PENDING_PROJECT_CONFIG.items():
            orig_v = _VIMINI_ORIGINAL_PROJECT_CONFIG.get(k)
            if orig_v != v:
                orig_disp = orig_v if orig_v is not None else "(not set)"
                new_disp = v if v is not None else "(not set)"
                popup_content.append(f"  {k}: {orig_disp} -> {new_disp}")

        popup_content.extend(['', '---', 'Accept changes? [y/n]'])

        popup_options = {
            'title': ' Confirm Configuration ', 'line': 0, 'col': 0,
            'minwidth': 40, 'maxwidth': 80,
            'padding': [1, 2, 1, 2], 'border': [1, 1, 1, 1],
            'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
            'close': 'none', 'zindex': 200,
        }
        popup_id = vim.eval(f"popup_create({json.dumps(popup_content)}, {popup_options})")
        vim.command("redraw!")

        confirmed = False
        try:
            answer_code = vim.eval('getchar()')
            answer_char = chr(int(answer_code))
            if answer_char.lower() == 'y':
                confirmed = True
        except (vim.error, ValueError, TypeError):
            pass
        finally:
            vim.eval(f"popup_close({popup_id})")
            vim.command("redraw!")

        if confirmed:
            data = load_project_data(start_dir=project_root)
            data["configuration"] = _VIMINI_PENDING_PROJECT_CONFIG
            if save_project_data(data, start_dir=project_root):
                util.display_message("Project configuration updated and saved.", history=True)
            else:
                util.display_message("Failed to save project configuration.", error=True)
        else:
            util.display_message("Project configuration changes discarded.", history=True)

    except Exception as e:
        util.display_message(f"Error confirming project configuration: {e}", error=True)
    finally:
        _VIMINI_PENDING_PROJECT_CONFIG = None
        _VIMINI_ORIGINAL_PROJECT_CONFIG = None
        _VIMINI_CONFIG_PROJECT_ROOT = None
        _VIMINI_CONFIG_PROJECT_NAME = None
