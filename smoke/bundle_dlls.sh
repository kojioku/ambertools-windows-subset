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
