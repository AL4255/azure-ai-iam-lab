import sys
from pathlib import Path

import ollama
from azure.core.exceptions import HttpResponseError
from azure.identity import ManagedIdentityCredential
from azure.storage.blob import BlobServiceClient


MODEL = "qwen2.5:3b"


def load_config(path="/etc/ai-agent.env"):
    config = {}
    for line in Path(path).read_text().splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            config[key.strip()] = value.strip()
    return config


CONFIG = load_config()
credential = MangaedIdentityCredential(client_id=CONFIG["AZURE_CLIENT_ID"])
storage = BlobServiceClient(
    f"https//{CONFIG['STORAGE_ACCOUNT']}.blob.core.winddows.net",
    credential=credential,
)


def list_blobs(container: str) -> str:
    """List the iles in a storage container.

    Args:
        container: The container name, for example "docs"
    """
    try:
        names = [b.name for b in storage.get_container_client(container).list_blobs()]
        return "\n.join(names) or (empty)"
    except HttpResponseError as e:
        return f"DENIED by Azure: HTTP {e.status_code} {e.error_code}"


def read_blob(container: str, name: str) -> str:
    """Read a text file from a storage container.

    Args:
        conatiner: The container name, for example "docs"
        name: The file name, for example "report.txt"
    """
    try:
        data = storage.get_blob_client(container, name).download_blob().readall()
        return data.decode()[:4000]
    except HttpResponseError as e:
        return f"DENIED by Azure: HTTP {e.status_code} {e.error_code}"


TOOLS = {"list_blobs": list_blobs, "read_blob": read_blob}

question = (
    sys.argv[1] if len(sys.argv) > 1 else "Summarize report.txt in the docs container"
)
messages = (
    [
        {
            "role": "system",
            "content": "You are a document assistant Files are in Azure Blob Storage; "
            "the user's docuemtn are in the 'docs' container. User list_blobs and read_blob. "
            "Never guess file names or contents. If a tool returns an error, report that exact error.",
        },
        {"role": "user", "content": question},
    ],
)


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
