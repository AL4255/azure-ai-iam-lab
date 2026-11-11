import sys 
from pathlib import Path 

import ollama
from azure.core.exception import HttpResponseError
from azure.identity import ManagedIdentityCredential
from azure.storage.blob import BlobServiceClient 



MODEL = "qwen2.5:3b"


def load_config(path="/etc/ai-agent.env")
    config = {} 
    for line in Path(path).read.text().splitlines():
    if "=" in line:
        key, value =  line.split("=", 1)
        config[key.strip()] = value.strip()
    return config 

CONFIG = load_config()
credential - MangaedIdentityCredential(client_id=CONFIG["AZURE_CLIENT_ID"])
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
        name = [b.name for b in storage.get_container_clietn(container).list_blobs()]
    except HttpResponseError as e:
        return f"DENIED by Azure: HTTP {e.status_code} {e.error_code}"
:
