import sys
from pathlib import Path

import ollama

MODEL = "qwen2.5:3b"
ALLOWED = (Path.home() / "agent-data").resolve()


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
        raise ValueError("access denied: outside the allowed folder")
    return path.read_text()[:4000]


TOOLS = {"list_files": list_files, "read_file": read_file}
messages = [
        {"role": "system", "content": "Use list_files to see which files exist. Use read_file(name=...) to read one. Never guess file names or contents. If a tool returns an error, report that exact error."},
    {"role": "user", "content": sys.argv[1]}
 ]

for _ in range(5):
    response = ollama.chat(model=MODEL, messages=messages, tools=list(TOOLS.values()))
    messages.append(response.message)

    if not response.message.tool_calls:
        print(response.message.content)
        break
    for call in response.message.tool_calls:
        name = call.function.name
        print(f"[tool] {name} {dict(call.function.arguments)}")
        try:
            result = TOOLS[name](**call.function.arguments)
        except Exception as e:
            result = f"Error: {e}"
        print(f"[result] {str(result)[:200]}")    
        messages.append({"role": "tool", "tool_name": name, "content": str(result)})

