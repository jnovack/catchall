#!/bin/sh
set -eu
code="${1:-}"

/usr/bin/logger "[INFO] write-code.sh running... found '$code'"

case "${code}" in
  [0-9][0-9][0-9][0-9][0-9][0-9])
    ;;
  *)
    exit 1
    ;;
esac

target=$(readlink -f /shared/code.txt 2>/dev/null || printf '%s' /shared/code.txt)
dir=$(dirname "${target}")
tmp=$(mktemp "${dir}/code.XXXXXX")
printf '%s' "${code}" > "${tmp}"
mv "${tmp}" "${target}"
chmod 644 "${target}" 2>/dev/null || true

exit 0
