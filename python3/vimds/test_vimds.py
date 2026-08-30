#!/usr/bin/env python3
"""
Test script for VimDS Python module
"""

import sys
import os

# Add the python3 directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'python3'))

try:
    from vimds import main
    print("✓ Successfully imported vimds.main")
    print(f"  Available functions: {[f for f in dir(main) if not f.startswith('_')]}")
except ImportError as e:
    print(f"✗ Failed to import vimds: {e}")
    sys.exit(1)
