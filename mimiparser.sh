#!/usr/bin/env bash
#
# mkatz_extract_v3p.sh  ──  DOMAIN\user : <NTLM-hash | password>
#
#   ./mkatz_extract_v3p.sh mimikatz.txt  > creds.txt
#
#   • Skips machine accounts (user$)
#   • Adds the domain
#   • Emits unique, sorted lines (shell handles the sort)

set -euo pipefail

if [[ $# -ne 1 || ! -f $1 ]]; then
  echo "Usage: $0 <mimikatz_output.txt>" >&2
  exit 1
fi

awk '
function trim(s) { sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s }

BEGIN { user=""; dom="" }

# ---- Domain ----
/^[[:space:]]*\*[[:space:]]*Domain[[:space:]]*:/ {
    sub(/^[[:space:]]*\*[[:space:]]*Domain[[:space:]]*:[[:space:]]*/, "", $0)
    d = trim($0)
    dom = (d != "" && d != "(null)") ? d : ""
    next
}

# ---- Username ----
/^[[:space:]]*\*[[:space:]]*Username[[:space:]]*:/ {
    sub(/^[[:space:]]*\*[[:space:]]*Username[[:space:]]*:[[:space:]]*/, "", $0)
    u = trim($0)
    # ignore empty / (null) / machine accounts
    if (u != "" && u != "(null)" && u !~ /\$$/)
        user = u
    else
        user = ""
    next
}

# ---- NTLM ----
/^[[:space:]]*\*[[:space:]]*NTLM[[:space:]]*:/ {
    if (user == "" || dom == "") next
    sub(/^[[:space:]]*\*[[:space:]]*NTLM[[:space:]]*:[[:space:]]*/, "", $0)
    h = tolower(trim($0)); gsub(/[[:space:]]/, "", h)
    if (h ~ /^[0-9a-f]{32}$/)
        creds[dom "\\" user ":" h] = 1
    next
}

# ---- Password ----
/^[[:space:]]*\*[[:space:]]*Password[[:space:]]*:/ {
    if (user == "" || dom == "") next
    sub(/^[[:space:]]*\*[[:space:]]*Password[[:space:]]*:[[:space:]]*/, "", $0)
    p = trim($0)
    if (p != "" && p != "(null)")
        creds[dom "\\" user ":" p] = 1
    next
}

END {
    for (k in creds) print k   # unsorted
}
' "$1" | sort -u          # sort & uniquify with coreutils
