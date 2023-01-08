#!/usr/bin/env bash
set -Eeuo pipefail
echo "Running ARC Job Started Hooks"

for hook in /etc/arc/hooks/job-started.d/*; do
  echo "Running hook: $hook"
  "$hook" "$@"
done
