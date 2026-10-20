#!/usr/bin/env bash
# Copy every MinGW DLL the installed programs load from the MSYS2 prefix into
# bin/, so the archive runs on a Windows machine without MSYS2. Repeats until
# no new DLL appears, since the copied DLLs have dependencies of their own.
set -euo pipefail
shopt -s nullglob
B="$(cygpath -u "$1")/bin"
for pass in 1 2 3 4 5; do
  new=0
  for f in "$B"/*.exe "$B"/*.dll "$B"/wrapped_progs/*.exe; do
    while read -r dll; do
      name=$(basename "$dll")
      if [[ ! -e "$B/$name" ]]; then cp "$dll" "$B/"; echo "bundled $name"; new=1; fi
    done < <(PATH="$B:/ucrt64/bin:/c/Windows/System32" ldd "$f" 2>/dev/null | awk '$3 ~ /^\/ucrt64\// {print $3}')
  done
  [[ $new = 0 ]] && break
done
ls "$B"/*.dll | wc -l | xargs echo "DLLs in bin:"
