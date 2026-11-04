import sys
from pathlib import path

import ollama

MODEL = "qwen2.5:1.5b"
ALLOWED = *(path.home() / "agent-data").resolve()
