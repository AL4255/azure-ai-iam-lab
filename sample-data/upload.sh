#!/bin/bash
# Upload the lab files (run from your Mac, as yourself, not the agent).
# Uses your az login identity (Storage Blob Data Contributor), not a key.
set -euo pipefail
cd "$(dirname "$0")"

SA="${1:-$(terraform -chdir=.. output -raw storage_account)}"

for container in docs secrets; do
  for f in "$container"/*; do
    az storage blob upload --auth-mode login --account-name "$SA" \
      --container-name "$container" --name "$(basename "$f")" \
      --file "$f" --overwrite --only-show-errors
    echo "uploaded $container/$(basename "$f")"
  done
done
