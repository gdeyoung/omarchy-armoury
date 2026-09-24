#!/usr/bin/env bash
# armoury.sh — stateless probe for gdeyoung.armoury.
# Prints exactly one JSON line describing the ASUS control surface:
# firmware attributes (asus-armoury), battery charge threshold, fan, temps,
# platform profile, pending-reboot flag, BIOS/model identity.
# Read-only. No arguments. Fails soft: missing pieces become null.
set -u

# --- helpers ---------------------------------------------------------------
fw_root=/sys/class/firmware-attributes/asus-armoury/attributes
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

attr_json() { # $1 = attribute dir (or file)
  local a="$1" n cur pos dsp typ
  n=$(basename "$a")
  if [ -d "$a" ]; then
    cur=$(cat "$a/current_value" 2>/dev/null)
    pos=$(cat "$a/possible_values" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')
    dsp=$(cat "$a/display_name" 2>/dev/null)
    typ=$(cat "$a/type" 2>/dev/null)
  else # plain-file attribute (e.g. pending_reboot)
    cur=$(cat "$a" 2>/dev/null)
    pos=""
    dsp="$n"
    typ="integer"
  fi
  printf '{"name":"%s","display":"%s","current":"%s","possible":"%s","type":"%s"}' \
    "$(esc "$n")" "$(esc "$dsp")" "$(esc "$cur")" "$(esc "$pos")" "$(esc "$typ")"
}

hwmon_by_name() { # $1 = hwmon name -> hwmon dir or empty
  local d
  for d in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$d/name" 2>/dev/null)" = "$1" ] && { printf '%s' "$d"; return; }
  done
}

temp_of() { # $1 = hwmon dir, $2 = temp input suffix (temp1_input etc.)
  local v
  v=$(cat "$1/$2" 2>/dev/null)
  [ -n "$v" ] && printf '%s.%.1s' "$((v / 1000))" "$(( (v % 1000) / 100 ))" || printf 'null'
}

# --- firmware attributes ----------------------------------------------------
attrs=""
if [ -d "$fw_root" ]; then
  first=1
  for a in "$fw_root"/*; do
    [ -e "$a" ] || continue
    [ -n "$first" ] || attrs="$attrs,"
    first=""
    attrs="$attrs$(attr_json "$a")"
  done
fi
[ -n "$attrs" ] || attrs='null'

# --- battery / charge -------------------------------------------------------
# Glob BAT*: this board is BAT1, others BAT0. First match wins.
BAT=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
th=$(cat "$BAT/charge_control_end_threshold" 2>/dev/null)
bstat=$(cat "$BAT/status" 2>/dev/null)
bcap=$(cat "$BAT/capacity" 2>/dev/null)
bcyc=$(cat "$BAT/cycle_count" 2>/dev/null)
bnow=$(cat "$BAT/charge_now" 2>/dev/null || cat "$BAT/energy_now" 2>/dev/null)
bfull=$(cat "$BAT/charge_full" 2>/dev/null || cat "$BAT/energy_full" 2>/dev/null)
bdes=$(cat "$BAT/charge_full_design" 2>/dev/null || cat "$BAT/energy_full_design" 2>/dev/null)
bvol=$(cat "$BAT/voltage_now" 2>/dev/null)
bcur=$(cat "$BAT/current_now" 2>/dev/null)

# --- fan (asus ec) ----------------------------------------------------------
fan_h=$(hwmon_by_name asus)
fan=$( [ -n "$fan_h" ] && cat "$fan_h/fan1_input" 2>/dev/null )

# --- temps: k10temp (CPU), amdgpu edge, nvme composite ----------------------
k10_h=$(hwmon_by_name k10temp); amd_h=$(hwmon_by_name amdgpu); nvme_h=$(hwmon_by_name nvme)
cpu_t=$( [ -n "$k10_h" ] && temp_of "$k10_h" temp1_input ); [ -n "$cpu_t" ] || cpu_t=null
gpu_t=$( [ -n "$amd_h" ] && temp_of "$amd_h" temp1_input ); [ -n "$gpu_t" ] || gpu_t=null
nvme_t=$( [ -n "$nvme_h" ] && temp_of "$nvme_h" temp1_input ); [ -n "$nvme_t" ] || nvme_t=null

# --- platform profile -------------------------------------------------------
prof=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null)
prof_c=$(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')

# --- epp (first policy) -----------------------------------------------------
epp=$(cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference 2>/dev/null)

# --- identity ---------------------------------------------------------------
bios=$(cat /sys/class/dmi/id/bios_version 2>/dev/null)
board=$(cat /sys/class/dmi/id/board_name 2>/dev/null)
fam=$(cat /sys/class/dmi/id/product_family 2>/dev/null)

printf '{"attrs":[%s],"battery":{"status":"%s","capacity":"%s","cycles":"%s","now":"%s","full":"%s","design":"%s","vol":"%s","cur":"%s","threshold":"%s"},"fan":"%s","temps":{"cpu":%s,"gpu":%s,"nvme":%s},"profile":"%s","profiles":"%s","epp":"%s","bios":"%s","board":"%s","family":"%s"}\n' \
  "$attrs" "$(esc "${bstat:-}")" "$(esc "${bcap:-}")" "$(esc "${bcyc:-}")" "$(esc "${bnow:-}")" "$(esc "${bfull:-}")" "$(esc "${bdes:-}")" "$(esc "${bvol:-}")" "$(esc "${bcur:-}")" "$(esc "${th:-}")" "$(esc "${fan:-}")" \
  "$cpu_t" "$gpu_t" "$nvme_t" "$(esc "${prof:-}")" "$(esc "${prof_c:-}")" "$(esc "${epp:-}")" \
  "$(esc "${bios:-}")" "$(esc "${board:-}")" "$(esc "${fam:-}")"
