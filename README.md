# AmberTools subset for native Windows

Builds the part of [AmberTools](https://ambermd.org/AmberTools.php) that is needed to
prepare protein–ligand systems — **tleap (teLeap), antechamber, parmchk2 and sqm**, plus
the force-field files under `dat/` — natively for 64-bit Windows, with MSYS2 / MinGW-w64
on GitHub Actions. No WSL, no Cygwin and no administrator rights are needed to run the
result.

conda-forge does not ship AmberTools for Windows (the feedstock skips `win`), and the
upstream CMake build supports MinGW; this repository only pins that build to a
minimal set of tools and tests it.

## What is built

- Source: `ambertools26_rc7.tar.bz2` from ambermd.org, the same tarball and SHA-256 as the
  conda-forge feedstock (see `.github/workflows/build.yml`)
- Tools: everything in `disable_tools.txt` is switched off; what remains is antechamber,
  sqm, leap and the libraries they need (sander, pbsa, sff, rism, quick, cew, libdlfind,
  emil, sebomd, cifparse, lib, etc)
- NetCDF: the copy bundled with AmberTools (netcdf-c 4.6.1, netcdf-fortran 4.4.4), not
  MSYS2's. MSYS2's netcdf pulls in HDF5, curl and the AWS SDK (about 40 DLLs), and
  teLeap then failed to start with a missing entry point (0xC0000139)
- Compiler: MSYS2 UCRT64 gcc / gfortran. `smoke/bundle_dlls.sh` copies every MinGW DLL
  the programs load into `bin/`, and `smoke/probe.ps1` starts them with only `bin\` and
  System32 on PATH, as on a machine without MSYS2

## Smoke test

`smoke/run.sh` builds a capped peptide with ff14SB / TIP3P in tleap, types and
AM1-BCC-charges benzoic acid with antechamber + sqm, fills its parameters with parmchk2,
and loads it back into tleap. The outputs are uploaded as the `smoke-out` artifact so they
can be compared with the same script run on Linux.

Checked on 2026-10-21 (run 39470825489) against the same AmberTools source built on
Linux: `peptide.prmtop`, `peptide_solv.prmtop`, both `.inpcrd`, `lig.mol2` (AM1-BCC
charges, total 0.0030), `lig.frcmod` and `lig.prmtop` are identical once line endings
(Windows writes CRLF) and the `%VERSION` date line are set aside.

## Running it

Unzip anywhere. Call `bin\teLeap.exe` directly with the four `-I` paths that
`bin\tleap.bat` adds (`tleap.bat` does not quote `%AMBERHOME%`, so it breaks on paths
with spaces). antechamber, parmchk2 and the other antechamber tools live in
`bin\wrapped_progs\`; the `.bat` files in `bin\` set `AMBERHOME` and put `bin\` on
PATH before calling them, and a caller that runs the `.exe` directly has to do the same,
because their DLLs are in `bin\`.

## Source changes

`patches/apply.sh` makes two changes before configuring:

- kmmd: force-includes a `getline()` for MinGW, which lacks it
- leap: opens the OFF library database in binary mode. `database.c` stores entry offsets
  with `ftell` and seeks back to them, which does not round-trip on a Windows text-mode
  stream over LF-only files; without this teLeap reads `amino12.lib` from the wrong place
  and crashes

## License

AmberTools is distributed by its authors, mostly under the GNU GPL v3 (see
`LICENSE-AmberTools.txt` in the built archive, taken from the source, and `licenses/`):
libsander / libpbsa and the BLEND code are LGPL v3, arpack and ucpp are BSD-style, netcdf
carries UCAR's notice, and the force-field files in `dat/leap` are in the public domain.
pmemd, which is under the Amber proprietary licence, is **not** built.

The archive also carries MinGW-w64 / MSYS2 runtime and library DLLs in `bin/`; which
package each comes from, its version and licence are listed in
`licenses/mingw/DLLS.txt`, with the package's licence files beside it.

Corresponding source: the AmberTools tarball named above (URL and SHA-256 in
`.github/workflows/build.yml`), plus the two changes in `patches/` of this repository,
applied by `patches/apply.sh`; the MSYS2 packages' sources are at
https://github.com/msys2/MINGW-packages. This repository is not affiliated with the
Amber developers.
