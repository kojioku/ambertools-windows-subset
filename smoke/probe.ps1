# Start each program with only bin\ and System32 on PATH, the way it would run on
# a machine without MSYS2, and print the Windows exit code in hex: 0xC0000135 is
# a missing DLL, 0xC0000139 a missing entry point.
param([string]$AmberHome)
$bin = Join-Path $AmberHome 'bin'
$env:PATH = "$bin;C:\Windows\System32;C:\Windows"
$env:AMBERHOME = $AmberHome
Set-Content -Path q.in -Value 'quit'
$progs = @(
  @{ exe = Join-Path $bin 'teLeap.exe'; args = '-f q.in' },
  @{ exe = Join-Path $bin 'sqm.exe'; args = '-h' },
  @{ exe = Join-Path $bin 'wrapped_progs\antechamber.exe'; args = '-h' },
  @{ exe = Join-Path $bin 'wrapped_progs\parmchk2.exe'; args = '-h' }
)
foreach ($p in $progs) {
  $r = Start-Process -FilePath $p.exe -ArgumentList $p.args -NoNewWindow -Wait -PassThru `
         -RedirectStandardOutput probe.out -RedirectStandardError probe.err
  '{0}: exit 0x{1:X8}' -f (Split-Path $p.exe -Leaf), $r.ExitCode
}
