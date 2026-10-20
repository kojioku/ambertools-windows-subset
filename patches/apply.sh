#!/usr/bin/env bash
# Source fixes needed for a MinGW build. Run from the directory that holds
# ambertools26_src.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC=ambertools26_src/AmberTools/src

# kmmd calls POSIX getline(), which MinGW lacks.
cp "$HERE/mingw_getline.h" "$SRC/kmmd/mingw_getline.h"
if ! grep -q mingw_getline "$SRC/kmmd/CMakeLists.txt"; then
  cat >> "$SRC/kmmd/CMakeLists.txt" <<'CMK'

if(MINGW)
	target_compile_options(kmmd PRIVATE -include ${CMAKE_CURRENT_SOURCE_DIR}/mingw_getline.h)
endif()
CMK
fi
echo "patches applied"
