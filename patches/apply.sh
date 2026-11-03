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
# cpptraj's bundled helPME sizes its cache blocks with sysconf(_SC_PAGESIZE),
# which MinGW's unistd.h does not provide (run 41558870520: "'_SC_PAGESIZE' was
# not declared"). Use the x86-64 Windows page size there; it only tunes blocking.
H=$SRC/cpptraj/src/helpme_standalone.h
if ! grep -q HELPME_PAGESIZE "$H"; then
  n=$(grep -c 'sysconf(_SC_PAGESIZE)' "$H")
  test "$n" -eq 1
  sed -i 's/sysconf(_SC_PAGESIZE)/HELPME_PAGESIZE/' "$H"
  sed -i '0,/#include <unistd.h>/s//#include <unistd.h>\n#if defined(_WIN32) \&\& !defined(_SC_PAGESIZE)\n#define HELPME_PAGESIZE 4096L  \/\* x86-64 Windows page size; MinGW has no sysconf \*\/\n#else\n#define HELPME_PAGESIZE sysconf(_SC_PAGESIZE)\n#endif/' "$H"
  grep -n -A5 '#include <unistd.h>' "$H" | head -7
  test "$(grep -c HELPME_PAGESIZE "$H")" -eq 3
fi

echo "patches applied"
