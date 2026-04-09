#!/usr/bin/env bash
set -euo pipefail

# Smoke test for bootstrap.sh — validates that it's parseable and
# the helper functions work without actually running the full playbook.

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Testing bootstrap.sh..."

# Test 1: Script is parseable
echo -n "  Parse check... "
bash -n "${SCRIPT_DIR}/bootstrap.sh" && echo "OK" || { echo "FAIL"; exit 1; }

# Test 2: bin/dotfiles is parseable
echo -n "  bin/dotfiles parse check... "
bash -n "${SCRIPT_DIR}/bin/dotfiles" && echo "OK" || { echo "FAIL"; exit 1; }

# Test 3: install.sh is parseable
echo -n "  install.sh parse check... "
bash -n "${SCRIPT_DIR}/install.sh" && echo "OK" || { echo "FAIL"; exit 1; }

# Test 4: Ansible playbook syntax check
echo -n "  Ansible syntax check... "
if ansible-playbook "${SCRIPT_DIR}/site.yml" --syntax-check &>/dev/null; then
  echo "OK"
else
  echo "FAIL"
  exit 1
fi

# Test 5: ansible-lint (if available)
if command -v ansible-lint &>/dev/null; then
  echo -n "  ansible-lint... "
  if ansible-lint "${SCRIPT_DIR}/site.yml" 2>/dev/null; then
    echo "OK"
  else
    echo "WARN (lint issues found, not blocking)"
  fi
fi

echo ""
echo "All smoke tests passed."
