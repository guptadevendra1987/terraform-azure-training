#!/usr/bin/env bash
# Deletes resource groups created during the course (tag course=tf-azure-training).
# Usage: ./cleanup.sh [-s student] [--include-state] [--force]
set -euo pipefail

STUDENT=""; INCLUDE_STATE=0; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    -s|--student)    STUDENT="$2"; shift 2 ;;
    --include-state) INCLUDE_STATE=1; shift ;;
    --force)         FORCE=1; shift ;;
    *) echo "unknown option $1"; exit 1 ;;
  esac
done

QUERY="[?tags.course=='tf-azure-training'"
[ -n "$STUDENT" ] && QUERY="$QUERY && tags.owner=='$STUDENT'"
[ "$INCLUDE_STATE" = 0 ] && QUERY="$QUERY && tags.purpose!='tfstate'"
QUERY="$QUERY].name"

mapfile -t GROUPS_TO_DELETE < <(az group list --query "$QUERY" -o tsv)
[ ${#GROUPS_TO_DELETE[@]} -eq 0 ] && { echo "Nothing to clean up."; exit 0; }

echo "The following resource groups will be DELETED:"
printf '  - %s\n' "${GROUPS_TO_DELETE[@]}"

if [ "$FORCE" = 0 ]; then
  read -r -p "Type 'yes' to continue: " answer
  [ "$answer" = "yes" ] || { echo "Aborted."; exit 1; }
fi

for g in "${GROUPS_TO_DELETE[@]}"; do
  az group delete -n "$g" --yes --no-wait
  echo "Deletion started: $g"
done
echo; echo "Deletions run in the background. Check with: az group list -o table"
