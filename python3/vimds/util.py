"""
VimDS Utility Functions
"""

import os
import sys
import subprocess
from typing import List, Optional, Dict, Any

def get_git_root() -> Optional[str]:
    """Get the root directory of the current git repository"""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return None

def get_git_diff(staged: bool = False) -> str:
    """Get git diff output"""
    try:
        cmd = ['git', 'diff']
        if staged:
            cmd.append('--staged')
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0:
            return result.stdout
    except Exception:
        pass
    return ""

def get_git_status() -> str:
    """Get git status output"""
    try:
        result = subprocess.run(
            ['git', 'status', '-s'],
            capture_output=True,
            text=True,
            check=False
        )
        if result.returncode == 0:
            return result.stdout
    except Exception:
        pass
    return ""

def process_queue():
    """Process the queue of pending jobs"""
    # This would be called by the Vim timer
    pass

def update_status_buffer():
    """Update the status buffer with current information"""
    # This would be called by the Vim timer
    pass

def read_file_content(file_path: str) -> Optional[str]:
    """Read the content of a file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception:
        return None

def write_file_content(file_path: str, content: str) -> bool:
    """Write content to a file"""
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    except Exception:
        return False

def get_selected_text() -> Optional[str]:
    """Get the currently selected text in Vim"""
    # This would be called from Vim
    pass

def execute_command(cmd: List[str]) -> Dict[str, Any]:
    """Execute a command and return the result"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False
        )
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }
        
