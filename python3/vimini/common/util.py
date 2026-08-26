# Vimini Agent Package
# Common utility module for vimini without vim dependency.
import os
import json
import subprocess

PROJECTS_DIR = os.path.expanduser("~/.var/vimini/projects")
CURRENT_PROJECT_DATA_VERSION = "0.1"

PROJECT_CONFIG_SCHEMA = {
    "build-command": {
        "label": "Build Command",
        "description": "Shell command to compile or build the project",
        "default": None,
        "type": "string"
    },
    "test-command": {
        "label": "Test Command",
        "description": "Shell command to run the project test suite",
        "default": None,
        "type": "string"
    }
}

def get_git_repo_root(start_dir=None):
    """
    Finds the root directory of the git repository starting from start_dir or current working directory.
    Does not require vim.
    """
    if start_dir is None:
        start_dir = os.getcwd()
    try:
        res = subprocess.run(
            ['git', '-C', start_dir, 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            check=False
        )
        if res.returncode == 0 and res.stdout.strip():
            return os.path.realpath(res.stdout.strip())
    except Exception:
        pass
    return None

def get_project_root(start_dir=None):
    """
    Returns the repository root path if inside a git repo, otherwise the absolute path of start_dir or cwd.
    """
    if start_dir is None:
        start_dir = os.getcwd()
    repo_root = get_git_repo_root(start_dir)
    if repo_root:
        return repo_root
    return os.path.realpath(start_dir)

def get_project_name(start_dir=None):
    """
    Returns the project name based on the git repository directory name or current working directory.
    """
    if start_dir is None:
        start_dir = os.getcwd()
    repo_root = get_git_repo_root(start_dir)
    if repo_root:
        return os.path.basename(repo_root)
    name = os.path.basename(os.path.realpath(start_dir))
    return name if name else "temp"

def get_project_data_file_path(project_name=None, start_dir=None):
    """
    Returns the path to the project data JSON file in ~/.var/vimini/projects.
    """
    if not project_name:
        project_name = get_project_name(start_dir)
    if not project_name or project_name == "temp":
        return None
    return os.path.join(PROJECTS_DIR, project_name)

def create_default_project_data():
    """
    Returns a new default project data dictionary.
    """
    config = {k: v.get("default") for k, v in PROJECT_CONFIG_SCHEMA.items()}
    return {
        "version": CURRENT_PROJECT_DATA_VERSION,
        "configuration": config,
        "files": []
    }

def _parse_version(v):
    if not isinstance(v, str):
        return (0,)
    try:
        return tuple(int(x) for x in v.strip().split('.'))
    except Exception:
        return (0,)

def upgrade_project_data(raw_data):
    """
    Upgrades project data to the current format ("0.1").
    Migrates legacy list-based context file lists to the 'files' section.
    If raw_data is a dict with a version higher than CURRENT_PROJECT_DATA_VERSION,
    raises a ValueError.
    """
    default = create_default_project_data()
    if isinstance(raw_data, list):
        default["files"] = raw_data
        return default
    elif isinstance(raw_data, dict):
        version = raw_data.get("version", CURRENT_PROJECT_DATA_VERSION)
        if _parse_version(version) > _parse_version(CURRENT_PROJECT_DATA_VERSION):
            raise ValueError(f"Project configuration version '{version}' is higher than supported version '{CURRENT_PROJECT_DATA_VERSION}'.")

        config = raw_data.get("configuration", {})
        if not isinstance(config, dict):
            config = {}
        for k, schema_item in PROJECT_CONFIG_SCHEMA.items():
            if k not in config:
                config[k] = schema_item.get("default")
        files = raw_data.get("files", [])
        if not isinstance(files, list):
            files = []
        return {
            "version": CURRENT_PROJECT_DATA_VERSION,
            "configuration": config,
            "files": files
        }
    return default

def load_project_data(project_name=None, start_dir=None):
    file_path = get_project_data_file_path(project_name, start_dir)
    if not file_path or not os.path.exists(file_path):
        return create_default_project_data()
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            raw_data = json.load(f)
        data = upgrade_project_data(raw_data)
        # Save if format was upgraded
        if isinstance(raw_data, list) or (isinstance(raw_data, dict) and raw_data.get("version") != CURRENT_PROJECT_DATA_VERSION):
            save_project_data(data, project_name, start_dir)
        return data
    except ValueError:
        raise
    except Exception:
        return create_default_project_data()

def save_project_data(data, project_name=None, start_dir=None):
    file_path = get_project_data_file_path(project_name, start_dir)
    if not file_path:
        return False
    try:
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        return True
    except Exception:
        return False

def get_project_config(key, project_name=None, start_dir=None, default=None):
    try:
        data = load_project_data(project_name, start_dir)
    except ValueError:
        return default
    config = data.get("configuration", {})
    if isinstance(config, dict):
        return config.get(key, default)
    return default

def set_project_config(key, value, project_name=None, start_dir=None):
    data = load_project_data(project_name, start_dir)
    data["configuration"][key] = value
    return save_project_data(data, project_name, start_dir)

def get_relative_path(file_path, repo_name=None, git_root=None):
    """
    Computes a path for a file relative to its git repository root,
    or to the user's home directory as a fallback.
    Prepends the capitalized git repo name or 'HOME' to the path.
    """
    if not file_path:
        return ""

    abs_path = os.path.realpath(file_path)

    if git_root and abs_path.startswith(git_root):
        relative_path = os.path.relpath(abs_path, git_root)
        if not repo_name:
            repo_name = os.path.basename(git_root)
        if repo_name:
            return f"{repo_name.upper()}:{relative_path}"
        return relative_path

    home_dir = os.path.expanduser('~')
    # Check if the path is inside the home directory.
    if abs_path.startswith(home_dir):
        try:
            relative_path = os.path.relpath(abs_path, home_dir)
            return f"HOME:{relative_path}"
        except ValueError:
            # This can happen on Windows if home_dir and abs_path are on different drives,
            # even with startswith check if symlinks are involved. Fallback is safe.
            pass

    # Fallback for files not in git repo or home, or on different drives on Windows.
    return os.path.basename(abs_path)
