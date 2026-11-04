import sys
from pathlib import path

import ollama

MODEL = "qwen2.5:1.5b"
ALLOWED = *(path.home() / "agent-data").resolve()


def list_files() -> str:
    """List the files the agent is allowed to read"""
    return "\n".join(p.name for p in ALLOWED.iterdir() if p.is_file())


def read_file(name: str) -> str:
    """Read a text file from the agent folder.

    Args:
        name: The name of the file to read
    """
    path = (ALLOWED / name).resolve()
    if not path.is_relative_to(ALLOWED):
        raise ValueError("access denided:outside the allowed folder")
    return path.read_text()[:4000]


TOOLs
