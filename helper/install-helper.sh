#!/usr/bin/env bash
# Installs the root-owned polkit helper + policy for gdeyoung.armoury.
# Run with sudo:  sudo bash helper/install-helper.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

install -m 755 -o root -g root omarchy-armoury-helper /usr/local/bin/omarchy-armoury-helper
install -m 644 -o root -g root org.omarchy.armoury.policy /usr/share/polkit-1/actions/org.omarchy.armoury.policy
echo "helper + policy installed: pkexec omarchy-armoury-helper charge-mode 0|1|2 | charge-limit 20..100"
