#!/bin/bash
# Upload the lab files (run from your Mac, as yourself, not the agent).
# Uses your az login identity (Storage Blob Data Contributor), not a key.
set -euo pipefail
cd "$(dirname "$0")"

SA="${1:-$(terraform -chdir=.. output -raw storage_account 2>/dev/null)}"

# terraform prints a warning to stdout (exit 0) when nothing is deployed,
# so check it's a real storage account name before using it.
if [[ ! "$SA" =~ ^[a-z0-9]{3,24}$ ]]; then
  echo "No storage account found. Run 'terraform apply' first." >&2
  exit 1
fi

for container in docs secrets; do
  for f in "$container"/*; do
    az storage blob upload --auth-mode login --account-name "$SA" \
      --container-name "$container" --name "$(basename "$f")" \
      --file "$f" --overwrite --only-show-errors
    echo "uploaded $container/$(basename "$f")"
  done
done
