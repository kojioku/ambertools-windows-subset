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
    done < <(PATH="$B:/ucrt64/bin:/usr/bin:/c/Windows/System32" ldd "$f" | awk '$3 ~ /^\/ucrt64\// {print $3}')
  done
  [[ $new = 0 ]] && break
done
# ldd only lists what it could load, so a DLL AmberTools itself built into lib/
# (not bin/) never shows up as missing there, and cpptraj.exe then fails to start
# on a clean machine (0xC0000135, run 41568190157). Walk the PE import tables with
# objdump instead, copy what bin/ lacks from lib/ or the MSYS2 prefix, and stop if
# anything outside Windows itself is still missing.
L="$(dirname "$B")/lib"
sysdir=/c/Windows/System32
for pass in 1 2 3 4 5; do
  new=0
  for f in "$B"/*.exe "$B"/*.dll "$B"/wrapped_progs/*.exe; do
    while read -r name; do
      lower=$(echo "$name" | tr 'A-Z' 'a-z')
      [[ $lower == api-ms-win-* || $lower == ext-ms-* ]] && continue
      ls "$B" | tr 'A-Z' 'a-z' | grep -qxF "$lower" && continue
      ls "$sysdir" 2>/dev/null | tr 'A-Z' 'a-z' | grep -qxF "$lower" && continue
      for src in "$L/$name" /ucrt64/bin/"$name"; do
        if [[ -e "$src" ]]; then cp "$src" "$B/"; echo "bundled $name (from $(dirname "$src"), by import table)"; new=1; break; fi
      done
    done < <(objdump -p "$f" 2>/dev/null | sed -n 's/^\s*DLL Name: //p')
  done
  [[ $new = 0 ]] && break
done
missing=0
for f in "$B"/*.exe "$B"/*.dll "$B"/wrapped_progs/*.exe; do
  while read -r name; do
    lower=$(echo "$name" | tr 'A-Z' 'a-z')
    [[ $lower == api-ms-win-* || $lower == ext-ms-* ]] && continue
    ls "$B" | tr 'A-Z' 'a-z' | grep -qxF "$lower" && continue
    ls "$sysdir" 2>/dev/null | tr 'A-Z' 'a-z' | grep -qxF "$lower" && continue
    echo "MISSING: $(basename "$f") imports $name, found neither in bin/ nor in Windows"; missing=1
  done < <(objdump -p "$f" 2>/dev/null | sed -n 's/^\s*DLL Name: //p')
done
[[ $missing = 0 ]] || exit 1
ls "$B"/*.dll | wc -l | xargs echo "DLLs in bin:"

# The licences of every MinGW DLL in bin/, from the MSYS2 package that owns
# it, so the archive carries them next to AmberTools' own (licenses/).
L="$(dirname "$B")/licenses/mingw"
mkdir -p "$L"
{
  echo "MinGW-w64 / MSYS2 DLLs bundled in bin/, and the MSYS2 package each one"
  echo "comes from. Package sources: https://github.com/msys2/MINGW-packages"
  echo
  printf '%-28s %-44s %s\n' "DLL" "package" "licence (pacman)"
} > "$L/DLLS.txt"
for dll in "$B"/*.dll; do
  name=$(basename "$dll")
  [[ -e "/ucrt64/bin/$name" ]] || continue
  pkg=$(pacman -Qqo "/ucrt64/bin/$name")
  lic=$(pacman -Qi "$pkg" | sed -n 's/^Licenses *: //p')
  ver=$(pacman -Q "$pkg" | cut -d' ' -f2)
  printf '%-28s %-44s %s\n' "$name" "$pkg $ver" "$lic" >> "$L/DLLS.txt"
  if [[ -d "/ucrt64/share/licenses/${pkg#mingw-w64-ucrt-x86_64-}" ]]; then
    cp -r "/ucrt64/share/licenses/${pkg#mingw-w64-ucrt-x86_64-}" "$L/"
  fi
done
cat "$L/DLLS.txt"
