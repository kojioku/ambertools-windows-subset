#!/usr/bin/env bash
# Smoke test for the AmberTools subset: tleap builds a capped peptide with
# ff14SB + TIP3P, antechamber/sqm types and AM1-BCC-charges a small molecule,
# parmchk2 fills its missing parameters. The outputs are kept so they can be
# compared with the same steps on Linux.
set -euxo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-smoke-out}"
mkdir -p "$OUT"
cd "$OUT"

if [[ -x "$AMBERHOME/bin/teLeap.exe" || -x "$AMBERHOME/bin/teLeap" ]]; then
  LEAP=("$AMBERHOME/bin/teLeap" -I"$AMBERHOME/dat/leap/prep" -I"$AMBERHOME/dat/leap/lib"
        -I"$AMBERHOME/dat/leap/parm" -I"$AMBERHOME/dat/leap/cmd")
else
  LEAP=(tleap)
fi

cat > peptide.in <<'EOF'
source leaprc.protein.ff14SB
source leaprc.water.tip3p
m = sequence { ACE ALA HIE LYS GLU NME }
saveamberparm m peptide.prmtop peptide.inpcrd
solvatebox m TIP3PBOX 8.0
addions m Cl- 0
addions m Na+ 0
saveamberparm m peptide_solv.prmtop peptide_solv.inpcrd
quit
EOF
"${LEAP[@]}" -f peptide.in > peptide.leap.log 2>&1
grep -E "Total unperturbed charge|Exiting" peptide.leap.log || true
test -s peptide.prmtop
test -s peptide_solv.prmtop

# cpptraj: what moldeck asks of it, in small -- strip the solvent and write a
# PDB (mmgbsa's complex slice), and a distance between two atoms (grest pmf).
if [[ -x "$AMBERHOME/bin/cpptraj.exe" || -x "$AMBERHOME/bin/cpptraj" ]]; then
  CPPTRAJ="$AMBERHOME/bin/cpptraj"
else
  CPPTRAJ=cpptraj
fi
"$CPPTRAJ" --version
printf '%s\n' \
  'parm peptide_solv.prmtop' \
  'trajin peptide_solv.inpcrd' \
  'strip :WAT,Na+,Cl-' \
  'distance d1 :2@CA :5@CA out dist.dat' \
  'trajout peptide_dry.pdb pdb' \
  'go' 'quit' > dry.cpptraj
"$CPPTRAJ" -i dry.cpptraj > cpptraj.log 2>&1
test -s peptide_dry.pdb
test -s dist.dat
echo "cpptraj: $(grep -c '^ATOM' peptide_dry.pdb) atoms after strip; $(tail -1 dist.dat)"

# On Windows antechamber and parmchk2 are .bat wrappers around
# bin/wrapped_progs/*.exe, which bash cannot run; call the programs directly.
if [[ -x "$AMBERHOME/bin/wrapped_progs/antechamber.exe" ]]; then
  antechamber() { "$AMBERHOME/bin/wrapped_progs/antechamber.exe" "$@"; }
  parmchk2() { "$AMBERHOME/bin/wrapped_progs/parmchk2.exe" "$@"; }
fi

cp "$HERE/benzoic_acid.sdf" .
antechamber -i benzoic_acid.sdf -fi mdl -o lig.mol2 -fo mol2 -c bcc -at gaff2 -nc 0 -s 2 > antechamber.log 2>&1
parmchk2 -i lig.mol2 -f mol2 -o lig.frcmod -s gaff2 > parmchk2.log 2>&1
test -s lig.mol2
test -s lig.frcmod
awk '/@<TRIPOS>ATOM/{f=1;next}/@<TRIPOS>/{f=0}f{q+=$9} END{printf "total charge %.4f\n", q}' lig.mol2

cat > lig.in <<'EOF'
source leaprc.gaff2
loadamberparams lig.frcmod
L = loadmol2 lig.mol2
saveamberparm L lig.prmtop lig.inpcrd
quit
EOF
"${LEAP[@]}" -f lig.in > lig.leap.log 2>&1
test -s lig.prmtop
echo "smoke OK"
