import os
import logging
from google import genai

logger = logging.getLogger('vimini_agent')

def load_api_key(config=None, api_key_file=None):
    """
    Loads API key from config dict or file path.
    """
    if isinstance(config, dict):
        if config.get("api_key"):
            return config.get("api_key")
        if not api_key_file:
            api_key_file = config.get("api_key_file")

    if api_key_file:
        expanded_path = os.path.expanduser(api_key_file)
        if os.path.exists(expanded_path):
            try:
                with open(expanded_path, 'r', encoding='utf-8') as f:
                    return f.read().strip()
            except Exception as e:
                logger.error(f"Error reading API key file '{expanded_path}': {e}")
                raise RuntimeError(f"Error reading API key file '{expanded_path}': {e}")
    return None

def get_client(api_key=None, api_key_file=None, config=None):
    """
    Initializes and returns a genai.Client instance.
    """
    if not api_key:
        api_key = load_api_key(config=config, api_key_file=api_key_file)
    if api_key:
        return genai.Client(api_key=api_key)
    return genai.Client()
