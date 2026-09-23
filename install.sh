#!/usr/bin/env bash
# Armoury installer for Omarchy 4.x.
# Installs the bar widget (unprivileged) + the polkit helper (needs sudo once
# for the helper + policy only — declined or skipped, the widget still works
# read-only). Idempotent and non-destructive.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_id="gdeyoung.armoury"
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"

say() { printf '%s\n' "$*"; }

# --- 1. Widget files ---------------------------------------------------------
mkdir -p "$plugin_dir"
install -m 644 "$repo_dir/BarWidget.qml" "$plugin_dir/BarWidget.qml"
install -m 644 "$repo_dir/Panel.qml"     "$plugin_dir/Panel.qml"
install -m 644 "$repo_dir/Model.js"      "$plugin_dir/Model.js"
install -m 644 "$repo_dir/manifest.json" "$plugin_dir/manifest.json"
install -m 755 "$repo_dir/armoury.sh"    "$plugin_dir/armoury.sh"
say "installed: $plugin_dir"

# --- 2. Probe sanity check ----------------------------------------------------
if probe_out=$("$plugin_dir/armoury.sh" 2>/dev/null) && command -v python3 >/dev/null; then
  if printf '%s' "$probe_out" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' 2>/dev/null; then
    say "probe ok: $(printf '%s' "$probe_out" | head -c 120)..."
  else
    say "WARNING: probe did not emit valid JSON" >&2
  fi
fi

# --- 3. Enable + place --------------------------------------------------------
omarchy plugin enable "$plugin_id" 2>/dev/null || say "NOTE: run 'omarchy plugin enable $plugin_id' after shell restart"
omarchy bar put "$plugin_id" --section right 2>/dev/null || true

# --- 4. Polkit helper (root part; optional) ----------------------------------
# Staged so the marketplace story stays one-shot: the user runs
#   sudo bash helper/install-helper.sh
# separately if they want write support. This keeps install.sh itself
# non-interactive (no sudo inside).
if [ -d "$plugin_dir" ]; then
  install -m 755 "$repo_dir/helper/install-helper.sh" "$plugin_dir/helper-install.sh" 2>/dev/null || true
fi
say ""
say "Widget: installed. Restart the shell:  omarchy restart shell"
say "Write support (battery care mode): sudo bash $repo_dir/helper/install-helper.sh"
