# python3/vimds/__init__.py
"""
VimDS - DeepSeek Integration for Vim
Python backend for the VimDS plugin
"""

from .main import (
    initialize, start_agent, stop_agent, chat, submit, code, review,
    commit, show_diff, files_command, context_files_command,
    config_command, autocomplete, cancel_autocomplete,
    list_models, send_setup, handle_channel_message, status_command,
    reload_vimds, help, ripgrep_command, ripgrep_apply, set_logging
)

__version__ = "1.0.0"
__all__ = [
    'initialize', 'start_agent', 'stop_agent', 'chat', 'submit', 'code', 'review',
    'commit', 'show_diff', 'files_command', 'context_files_command',
    'config_command', 'autocomplete', 'cancel_autocomplete',
    'list_models', 'send_setup', 'handle_channel_message', 'status_command',
    'reload_vimds', 'help', 'ripgrep_command', 'ripgrep_apply', 'set_logging'
]
