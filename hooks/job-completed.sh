#!/usr/bin/env bash
set -Eeuo pipefail
echo "Running ARC Job Completed Hooks"

for hook in /etc/arc/hooks/job-completed.d/*; do
  echo "Running hook: $hook"
  "$hook" "$@"
done
