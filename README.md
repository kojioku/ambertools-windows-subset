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
- Compiler: MSYS2 UCRT64 gcc / gfortran; the MinGW runtime DLLs are bundled by the
  upstream CMake scripts

## Smoke test

`smoke/run.sh` builds a capped peptide with ff14SB / TIP3P in tleap, types and
AM1-BCC-charges benzoic acid with antechamber + sqm, fills its parameters with parmchk2,
and loads it back into tleap. The outputs are uploaded as the `smoke-out` artifact so they
can be compared with the same script run on Linux.

## License

AmberTools is distributed by its authors, mostly under the GNU GPL v3 (see
`LICENSE-AmberTools.txt` in the built archive, taken from the source). The force-field
files in `dat/leap` are in the public domain. The corresponding source is the tarball
named above. This repository is not affiliated with the Amber developers.
