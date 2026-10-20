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

# leap's OFF library reader (database.c) records entry offsets with ftell and
# jumps back with fseek. On Windows a text-mode stream over LF-only files gives
# offsets that do not round-trip, so amino12.lib is read from the wrong place
# (box values of 1e-312) and teLeap crashes. Open the database in binary mode,
# which is what POSIX does anyway.
DB=ambertools26_src/AmberTools/src/leap/src/leap/database.c
sed -i -E 's/(FOPEN(NO)?COMPLAIN\( *[a-zA-Z>.-]+, *)"(r|w)(\+?)"/\1"\3\4b"/' "$DB"
n=$(grep -cE 'FOPEN(NO)?COMPLAIN\(.*"(r|w)\+?b"' "$DB")
echo "database.c: $n fopen calls switched to binary mode"
test "$n" -eq 9
echo "patches applied"
