"""
VimDS Main Module - DeepSeek Integration for Vim (via OpenRouter)
"""

import os
import sys
import json
import socket
import tempfile
import threading
import queue
import time
import logging
import re
from typing import Optional, Dict, Any, List
from pathlib import Path

# Try to import requests for API calls
try:
    import requests
except ImportError:
    print("Warning: requests module not found. Please install: pip install requests")
    requests = None

# Try to import python-dotenv for environment variables
try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None

#==============================================================================
# Configuration
#==============================================================================

class Config:
    """Configuration manager for VimDS"""
    
    def __init__(self):
        self.api_key = None
        # Use deepseek-r1:free which is confirmed to work
        self.model = "deepseek/deepseek-r1:free"
        self.base_url = "https://openrouter.ai/api/v1"
        self.log_file = None
        self.logging_enabled = False
        self.timeout = 60  # Increased timeout for reasoning model
        self.temperature = 0.7
        self.max_tokens = 500  # Reasonable default to save credits
        self._logger = None
        
    def set_logger(self, logger):
        """Set the logger instance"""
        self._logger = logger
        
    def load_api_key(self, api_key_file: str) -> str:
        """Load API key from file"""
        try:
            with open(api_key_file, 'r') as f:
                api_key = f.read().strip()
                if not api_key:
                    raise ValueError("API key file is empty")
                # Check if it's an OpenRouter key (starts with sk-or-)
                if api_key.startswith('sk-or-'):
                    if self._logger:
                        self._logger.log("OpenRouter API key detected", 'info')
                self.api_key = api_key
                return api_key
        except Exception as e:
            raise Exception(f"Failed to load API key from {api_key_file}: {e}")

#==============================================================================
# Logger
#==============================================================================

class VimDSLogger:
    """Logger for VimDS"""
    
    def __init__(self):
        self._logger = None
        self.handler = None
        self.enabled = False
        
    def setup(self, log_file: Optional[str] = None):
        """Setup logging"""
        if not log_file:
            return
            
        self.enabled = True
        self._logger = logging.getLogger('vimds')
        self._logger.setLevel(logging.DEBUG)
        
        # Remove existing handlers to avoid duplicates
        if self._logger.handlers:
            self._logger.handlers.clear()
            
        # Create log directory if it doesn't exist
        log_dir = os.path.dirname(log_file)
        if log_dir:
            os.makedirs(log_dir, exist_ok=True)
            
        self.handler = logging.FileHandler(log_file)
        self.handler.setLevel(logging.DEBUG)
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.handler.setFormatter(formatter)
        self._logger.addHandler(self.handler)
        
    def log(self, message: str, level: str = 'info'):
        """Log a message"""
        if not self.enabled or self._logger is None:
            return
            
        if level == 'debug':
            self._logger.debug(message)
        elif level == 'info':
            self._logger.info(message)
        elif level == 'warning':
            self._logger.warning(message)
        elif level == 'error':
            self._logger.error(message)
        else:
            self._logger.info(message)
            
    def close(self):
        """Close the logger"""
        if self.handler:
            self.handler.close()
            if self._logger and self.handler in self._logger.handlers:
                self._logger.removeHandler(self.handler)
            self.handler = None
        self.enabled = False

#==============================================================================
# OpenRouter API Client
#==============================================================================

class OpenRouterClient:
    """Client for OpenRouter API (supports DeepSeek models)"""
    
    # Free models that should work on OpenRouter
    FREE_MODELS = [
        "deepseek/deepseek-r1:free",
        "deepseek/deepseek-chat-v3.1:free",
        "deepseek/deepseek-r1-0528:free",
    ]
    
    def __init__(self, config: Config, logger: VimDSLogger):
        self.config = config
        self.logger = logger
        self.session = requests.Session() if requests else None
        self.conversation_history = []
        
    def _get_headers(self) -> Dict[str, str]:
        """Get request headers for OpenRouter"""
        headers = {
            "Authorization": f"Bearer {self.config.api_key}",
            "Content-Type": "application/json"
        }
        
        # Optional: Add OpenRouter specific headers
        headers["HTTP-Referer"] = "https://github.com/yourusername/vimds"
        headers["X-Title"] = "VimDS"
        
        return headers
        
    def _try_model(self, messages: List[Dict[str, str]], 
                   temperature: Optional[float] = None,
                   max_tokens: Optional[int] = None,
                   stream: bool = False,
                   model: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """Try a specific model and return response if successful"""
        if not self.session:
            raise Exception("Requests module not available")
            
        url = f"{self.config.base_url}/chat/completions"
        
        # Use provided model or fallback to config
        model_to_try = model if model else self.config.model
        
        token_limit = max_tokens if max_tokens is not None else self.config.max_tokens
        
        payload = {
            "model": model_to_try,
            "messages": messages,
            "temperature": temperature if temperature is not None else self.config.temperature,
            "max_tokens": token_limit,
            "stream": stream
        }
        
        self.logger.log(f"Trying model: {model_to_try}", 'debug')
        
        try:
            self.logger.log(f"Sending request to {url}", 'debug')
            response = self.session.post(
                url,
                headers=self._get_headers(),
                json=payload,
                timeout=self.config.timeout
            )
            
            self.logger.log(f"Response status: {response.status_code}", 'debug')
            
            if response.status_code == 200:
                self.logger.log(f"Model {model_to_try} succeeded!", 'info')
                return response.json()
            else:
                self.logger.log(f"Model {model_to_try} failed: {response.status_code}", 'debug')
                self.logger.log(f"Error: {response.text[:200]}", 'debug')
                return None
        except requests.exceptions.Timeout:
            self.logger.log(f"Model {model_to_try} timed out", 'warning')
            return None
        except Exception as e:
            self.logger.log(f"Model {model_to_try} error: {e}", 'debug')
            return None
        
    def chat_completion(self, messages: List[Dict[str, str]], 
                        temperature: Optional[float] = None,
                        stream: bool = False,
                        max_tokens: Optional[int] = None) -> Dict[str, Any]:
        """Send chat completion request to OpenRouter with fallback models"""
        if not self.session:
            raise Exception("Requests module not available")
        
        # First try the configured model
        self.logger.log(f"Trying configured model: {self.config.model}", 'info')
        result = self._try_model(messages, temperature, max_tokens, stream)
        
        if result:
            return result
        
        # If that fails, try fallback free models
        self.logger.log("Configured model failed, trying fallback free models...", 'warning')
        
        for fallback_model in self.FREE_MODELS:
            if fallback_model == self.config.model:
                continue  # Skip if it's the same as configured
                
            self.logger.log(f"Trying fallback model: {fallback_model}", 'info')
            result = self._try_model(messages, temperature, max_tokens, stream, fallback_model)
            
            if result:
                # Update config to use working model for future requests
                self.config.model = fallback_model
                self.logger.log(f"Switched to working model: {fallback_model}", 'info')
                return result
        
        # If all models fail, raise an error
        raise Exception("All models failed. Please check your API key or try a different model.")
        
#==============================================================================
# VimDS Main Class
#==============================================================================

class VimDS:
    """Main VimDS class"""
    
    def __init__(self):
        self.config = Config()
        self.logger = VimDSLogger()
        # Set the logger in config
        self.config.set_logger(self.logger)
        self.client = None
        self.agent_thread = None
        self.message_queue = queue.Queue()
        self.running = False
        self.socket_path = None
        self.server_socket = None
        self.active_attachments = {}
        self.chat_buffer = []
        self.chat_window_open = False
        
    def initialize(self, api_key_file: str, model: str = 'deepseek/deepseek-r1:free', 
                   logfile: Optional[str] = None, max_tokens: int = 500):
        """Initialize VimDS"""
        try:
            # Setup logging first
            if logfile:
                self.logger.setup(logfile)
                self.config.logging_enabled = True
                self.logger.log(f"VimDS initializing...", 'info')
            
            # Load API key
            self.config.load_api_key(api_key_file)
            
            # Set model - use the provided model or default to r1:free
            if model:
                self.config.model = model
            else:
                self.config.model = "deepseek/deepseek-r1:free"
            
            # Set max tokens
            self.config.max_tokens = max_tokens
            
            self.logger.log(f"VimDS initialized with model: {self.config.model}", 'info')
            self.logger.log(f"API key loaded from: {api_key_file}", 'debug')
            self.logger.log(f"Using OpenRouter endpoint: {self.config.base_url}", 'debug')
            self.logger.log(f"Max tokens: {self.config.max_tokens}", 'debug')
            self.logger.log(f"Timeout: {self.config.timeout}s", 'debug')
            
            # Initialize client (OpenRouter)
            self.client = OpenRouterClient(self.config, self.logger)
            
            # Create socket directory
            socket_dir = Path(tempfile.gettempdir()) / 'vimds'
            socket_dir.mkdir(exist_ok=True)
            self.socket_path = str(socket_dir / 'vimds.sock')
            
            self.logger.log("VimDS initialized successfully", 'info')
            return self
            
        except Exception as e:
            if self.logger:
                self.logger.log(f"Initialization error: {e}", 'error')
            raise
        
    def start_agent(self) -> Optional[str]:
        """Start the agent server"""
        if self.running:
            self.logger.log("Agent already running", 'warning')
            return self.socket_path
            
        self.logger.log("Starting agent server...", 'info')
        
        # Start the agent thread
        self.running = True
        self.agent_thread = threading.Thread(target=self._agent_loop, daemon=True)
        self.agent_thread.start()
        
        # Wait for socket to be created
        timeout = 5
        while timeout > 0 and not os.path.exists(self.socket_path):
            time.sleep(0.1)
            timeout -= 0.1
            
        if os.path.exists(self.socket_path):
            self.logger.log(f"Agent started at: {self.socket_path}", 'info')
            return self.socket_path
        else:
            self.logger.log("Failed to start agent", 'error')
            return None
            
    def stop_agent(self):
        """Stop the agent server"""
        self.logger.log("Stopping agent...", 'info')
        self.running = False
        
        if self.agent_thread:
            self.agent_thread.join(timeout=2)
            
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
                
        if self.socket_path and os.path.exists(self.socket_path):
            try:
                os.unlink(self.socket_path)
            except:
                pass
                
        self.logger.log("Agent stopped", 'info')
        self.logger.close()
        
    def _agent_loop(self):
        """Main agent loop - handles communication with Vim"""
        try:
            # Create socket server
            self.server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.server_socket.settimeout(0.5)
            
            # Remove existing socket
            if os.path.exists(self.socket_path):
                os.unlink(self.socket_path)
                
            self.server_socket.bind(self.socket_path)
            self.server_socket.listen(1)
            
            self.logger.log(f"Agent listening on {self.socket_path}", 'info')
            
            while self.running:
                try:
                    client, addr = self.server_socket.accept()
                    threading.Thread(target=self._handle_client, args=(client,), daemon=True).start()
                except socket.timeout:
                    continue
                except Exception as e:
                    if self.running:
                        self.logger.log(f"Agent error: {e}", 'error')
                        
        except Exception as e:
            self.logger.log(f"Agent loop error: {e}", 'error')
            
    def _handle_client(self, client_socket):
        """Handle client connection"""
        try:
            data = client_socket.recv(4096)
            if data:
                message = data.decode('utf-8')
                self.logger.log(f"Received message: {message[:200]}", 'debug')
                self.message_queue.put(message)
                response = self._process_message(message)
                if response:
                    self.logger.log(f"Sending response: {str(response)[:200]}", 'debug')
                    client_socket.send(json.dumps(response).encode('utf-8'))
        except Exception as e:
            self.logger.log(f"Client handler error: {e}", 'error')
        finally:
            client_socket.close()
            
    def _process_message(self, message: str) -> Dict[str, Any]:
        """Process incoming message"""
        try:
            # Handle different message formats
            self.logger.log(f"Raw message: {message[:200]}", 'debug')
            
            # Try to parse as JSON
            if isinstance(message, str):
                try:
                    data = json.loads(message)
                except json.JSONDecodeError:
                    # Try to extract JSON from the string
                    json_match = re.search(r'\{.*\}', message)
                    if json_match:
                        try:
                            data = json.loads(json_match.group())
                        except:
                            return {'error': f'Could not parse message: {message[:100]}'}
                    else:
                        return {'error': f'Invalid message format: {message[:100]}'}
            else:
                data = message
            
            # Handle if data is a list (from channel)
            if isinstance(data, list):
                self.logger.log(f"Received list data: {data}", 'debug')
                # Try to extract the actual data from the list
                if len(data) > 1:
                    # The second element might be the actual data
                    if isinstance(data[1], str):
                        try:
                            data = json.loads(data[1])
                        except:
                            data = data[1]
                    else:
                        data = data[1]
                else:
                    return {'error': 'Invalid list format'}
            
            # Now data should be a dict
            if not isinstance(data, dict):
                return {'error': f'Expected dict, got {type(data)}'}
            
            command = data.get('command', '')
            self.logger.log(f"Processing command: {command}", 'debug')
            
            if command == 'chat':
                return self._handle_chat(data)
            elif command == 'code':
                return self._handle_code(data)
            elif command == 'review':
                return self._handle_review(data)
            elif command == 'commit':
                return self._handle_commit(data)
            elif command == 'submit':
                return self._handle_submit(data)
            else:
                return {'error': f'Unknown command: {command}'}
                
        except json.JSONDecodeError as e:
            self.logger.log(f"JSON decode error: {e}", 'error')
            return {'error': 'Invalid JSON message'}
        except Exception as e:
            self.logger.log(f"Message processing error: {e}", 'error')
            import traceback
            self.logger.log(f"Traceback: {traceback.format_exc()}", 'error')
            return {'error': str(e)}
            
    def _handle_chat(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Handle chat command - opens chat window"""
        self.logger.log("Chat command received", 'info')
        self.chat_window_open = True
        self.client.conversation_history = []  # Reset conversation
        return {'status': 'chat_opened'}
        
    def _handle_submit(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Handle submit command - sends message to AI"""
        message = data.get('message', '')
        if not message:
            return {'error': 'No message provided'}
            
        self.logger.log(f"Processing message: {message[:50]}...", 'info')
        
        try:
            # Add to conversation history
            self.client.conversation_history.append({"role": "user", "content": message})
            
            # Get response from OpenRouter with reasonable token limit
            self.logger.log("Calling OpenRouter API...", 'info')
            
            # Log configuration for debugging
            self.logger.log(f"Using model: {self.config.model}", 'debug')
            self.logger.log(f"Max tokens: {self.config.max_tokens}", 'debug')
            self.logger.log(f"Timeout: {self.config.timeout}s", 'debug')
            
            start_time = time.time()
            response = self.client.chat_completion(
                self.client.conversation_history,
                max_tokens=self.config.max_tokens
            )
            elapsed_time = time.time() - start_time
            self.logger.log(f"API call completed in {elapsed_time:.2f}s", 'info')
            
            self.logger.log(f"Raw response: {json.dumps(response)[:500]}", 'debug')
            
            # Extract the response content
            ai_response = ""
            if isinstance(response, dict):
                choices = response.get('choices', [])
                if choices and isinstance(choices, list):
                    choice = choices[0]
                    if isinstance(choice, dict):
                        message_obj = choice.get('message', {})
                        if isinstance(message_obj, dict):
                            ai_response = message_obj.get('content', '')
            
            if not ai_response:
                self.logger.log(f"Could not extract response", 'error')
                ai_response = "I'm sorry, I couldn't generate a response. Please try again."
            
            self.logger.log(f"Final AI response length: {len(ai_response)} chars", 'info')
            
            # Add to conversation history
            self.client.conversation_history.append({"role": "assistant", "content": ai_response})
            
            return {
                'response': ai_response,
                'status': 'success'
            }
        except Exception as e:
            error_msg = str(e)
            self.logger.log(f"Chat error: {error_msg}", 'error')
            import traceback
            self.logger.log(f"Traceback: {traceback.format_exc()}", 'error')
            return {
                'error': f"API Error: {error_msg}",
                'status': 'error'
            }
            
    def _handle_code(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Handle code generation command"""
        prompt = data.get('prompt', '')
        if not prompt:
            return {'error': 'No prompt provided'}
            
        try:
            messages = [
                {"role": "system", "content": "You are a helpful coding assistant. Generate clean, well-documented code."},
                {"role": "user", "content": prompt}
            ]
            response = self.client.chat_completion(messages, max_tokens=self.config.max_tokens)
            
            # Extract response
            ai_response = ""
            if isinstance(response, dict):
                choices = response.get('choices', [])
                if choices and isinstance(choices, list):
                    choice = choices[0]
                    if isinstance(choice, dict):
                        message_obj = choice.get('message', {})
                        if isinstance(message_obj, dict):
                            ai_response = message_obj.get('content', '')
            
            return {
                'code': ai_response or str(response)
            }
        except Exception as e:
            return {'error': str(e)}
            
    def _handle_review(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Handle code review command"""
        return {'response': 'Review functionality needs git integration'}
        
    def _handle_commit(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Handle commit message generation"""
        return {'response': 'Commit functionality needs git integration'}
        
    # Vim interface methods
    
    def chat(self):
        """Open chat interface in Vim"""
        self.logger.log("Chat command called", 'info')
        self.chat_window_open = True
        self.client.conversation_history = []  # Reset conversation
        
    def submit(self):
        """Submit message in chat window - called from Vim"""
        self.logger.log("Submit command called", 'info')
        
    def code(self, prompt: str, verbose: bool = False, temperature: Optional[float] = None):
        """Generate code from prompt"""
        self.logger.log(f"Code generation request: {prompt[:50]}...", 'info')
        
    def review(self, prompt: str, git_objects: Optional[str] = None,
               security_focus: bool = False, verbose: bool = False,
               temperature: Optional[float] = None, save: bool = False,
               save_path: Optional[str] = None):
        """Review git diffs"""
        self.logger.log(f"Review request: {prompt[:50]}...", 'info')
        pass
        
    def commit(self, assistant: bool = True, temperature: Optional[float] = None,
               regenerate: bool = False, amend: bool = False,
               refinement: Optional[str] = None):
        """Generate commit message"""
        self.logger.log("Commit command called", 'info')
        pass
        
    def show_diff(self):
        """Show git diff"""
        self.logger.log("Show diff command called", 'info')
        pass
        
    def files_command(self):
        """Manage uploaded files"""
        self.logger.log("Files command called", 'info')
        pass
        
    def context_files_command(self):
        """Manage context files"""
        self.logger.log("Context files command called", 'info')
        pass
        
    def config_command(self):
        """Manage configuration"""
        self.logger.log("Config command called", 'info')
        pass
        
    def autocomplete(self):
        """Trigger autocomplete"""
        self.logger.log("Autocomplete triggered", 'debug')
        pass
        
    def cancel_autocomplete(self):
        """Cancel autocomplete"""
        self.logger.log("Autocomplete cancelled", 'debug')
        pass
        
    def list_models(self):
        """List available models"""
        self.logger.log("List models called", 'info')
        return {}
        
    def send_setup(self):
        """Send setup message to Vim"""
        self.logger.log("Setup message sent", 'debug')
        pass
        
    def handle_channel_message(self, msg: str):
        """Handle channel message from Vim"""
        self.logger.log(f"Channel message received: {msg[:100]}", 'debug')
        try:
            # Handle the message format
            if isinstance(msg, str):
                try:
                    data = json.loads(msg)
                except json.JSONDecodeError:
                    json_match = re.search(r'\{.*\}', msg)
                    if json_match:
                        try:
                            data = json.loads(json_match.group())
                        except:
                            data = msg
                    else:
                        data = msg
            else:
                data = msg
            
            # If data is a list (channel format), extract the actual data
            if isinstance(data, list) and len(data) > 1:
                if isinstance(data[1], str):
                    try:
                        data = json.loads(data[1])
                    except:
                        data = data[1]
                else:
                    data = data[1]
            
            # Process the message
            if isinstance(data, dict):
                self._process_message(json.dumps(data))
            elif isinstance(data, str):
                self._process_message(data)
        except Exception as e:
            self.logger.log(f"Channel message error: {e}", 'error')
        
    def status_command(self):
        """Show status"""
        self.logger.log("Status command called", 'info')
        pass
        
    def reload_vimds(self):
        """Reload VimDS"""
        self.logger.log("Reload command called", 'info')
        pass
        
    def help(self, cmd: Optional[str] = None):
        """Show help"""
        self.logger.log(f"Help command called for: {cmd}", 'info')
        pass
        
    def ripgrep_command(self, arg_string: str):
        """Execute ripgrep search"""
        self.logger.log(f"Ripgrep command: {arg_string}", 'info')
        pass
        
    def ripgrep_apply(self):
        """Apply ripgrep results"""
        self.logger.log("Ripgrep apply called", 'info')
        pass

#==============================================================================
# Global Instance and Functions
#==============================================================================

# Global instance
_vimds_instance = None

def get_instance() -> VimDS:
    """Get or create the global VimDS instance"""
    global _vimds_instance
    if _vimds_instance is None:
        _vimds_instance = VimDS()
    return _vimds_instance

# Exported functions for Vim

def initialize(api_key_file: str, model: str = 'deepseek/deepseek-r1:free', 
               logfile: Optional[str] = None, max_tokens: int = 500):
    """Initialize VimDS"""
    instance = get_instance()
    return instance.initialize(api_key_file, model, logfile, max_tokens)

def start_agent() -> Optional[str]:
    """Start the agent server"""
    instance = get_instance()
    return instance.start_agent()

def stop_agent():
    """Stop the agent server"""
    instance = get_instance()
    return instance.stop_agent()

def chat():
    """Open chat interface"""
    instance = get_instance()
    return instance.chat()

def submit():
    """Submit message in chat window"""
    instance = get_instance()
    return instance.submit()

def code(prompt: str, verbose: bool = False, temperature: Optional[float] = None):
    """Generate code from prompt"""
    instance = get_instance()
    return instance.code(prompt, verbose, temperature)

def review(prompt: str, git_objects: Optional[str] = None,
           security_focus: bool = False, verbose: bool = False,
           temperature: Optional[float] = None, save: bool = False,
           save_path: Optional[str] = None):
    """Review git diffs"""
    instance = get_instance()
    return instance.review(prompt, git_objects, security_focus, verbose, temperature, save, save_path)

def commit(assistant: bool = True, temperature: Optional[float] = None,
           regenerate: bool = False, amend: bool = False,
           refinement: Optional[str] = None):
    """Generate commit message"""
    instance = get_instance()
    return instance.commit(assistant, temperature, regenerate, amend, refinement)

def show_diff():
    """Show git diff"""
    instance = get_instance()
    return instance.show_diff()

def files_command():
    """Manage uploaded files"""
    instance = get_instance()
    return instance.files_command()

def context_files_command():
    """Manage context files"""
    instance = get_instance()
    return instance.context_files_command()

def config_command():
    """Manage configuration"""
    instance = get_instance()
    return instance.config_command()

def autocomplete():
    """Trigger autocomplete"""
    instance = get_instance()
    return instance.autocomplete()

def cancel_autocomplete():
    """Cancel autocomplete"""
    instance = get_instance()
    return instance.cancel_autocomplete()

def list_models():
    """List available models"""
    instance = get_instance()
    return instance.list_models()

def send_setup():
    """Send setup message to Vim"""
    instance = get_instance()
    return instance.send_setup()

def handle_channel_message(msg: str):
    """Handle channel message from Vim"""
    instance = get_instance()
    return instance.handle_channel_message(msg)

def status_command():
    """Show status"""
    instance = get_instance()
    return instance.status_command()

def reload_vimds():
    """Reload VimDS"""
    instance = get_instance()
    return instance.reload_vimds()

def help(cmd: Optional[str] = None):
    """Show help"""
    instance = get_instance()
    return instance.help(cmd)

def ripgrep_command(arg_string: str):
    """Execute ripgrep search"""
    instance = get_instance()
    return instance.ripgrep_command(arg_string)

def ripgrep_apply():
    """Apply ripgrep results"""
    instance = get_instance()
    return instance.ripgrep_apply()

def set_logging(logfile: Optional[str] = None):
    """Configure logging"""
    instance = get_instance()
    if logfile:
        return instance.logger.setup(logfile)
    else:
        instance.logger.enabled = False
        return instance.logger.close()

#==============================================================================
# Module Initialization
#==============================================================================

# Configure basic logging if no log file is specified
logging.basicConfig(level=logging.WARNING)
