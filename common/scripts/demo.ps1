# Shared EasyNav demo for Windows (PowerShell): build -> test -> run with the Dummy* plugins.
# Same steps as demo.sh. Run it from a colcon workspace root, inside an environment
# where ROS 2 is already available (pixi shell, conanrosenv.bat...).
#
#   demo.ps1 [build|test|run|all]   (default: all)
#
# NOTE: not tested on real Windows hardware yet.
param([string]$Step = "all")
$ErrorActionPreference = "Stop"

$CommonDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$Params = Join-Path $CommonDir "params\dummy.params.yaml"
$RunSeconds = if ($env:RUN_SECONDS) { [int]$env:RUN_SECONDS } else { 15 }
if (-not $env:COLCON_DEFAULTS_FILE) {
  $env:COLCON_DEFAULTS_FILE = Join-Path $CommonDir "colcon_defaults.yaml"
}

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Blue }

function Do-Build {
  Step "colcon build"
  # MSVC + symlinks need Developer Mode; --merge-install keeps PATH short on Windows
  colcon build --merge-install
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Do-Test {
  Step "colcon test"
  colcon test --merge-install --packages-select-regex "easynav.*|yaets"
  colcon test-result --verbose
  if ($LASTEXITCODE -ne 0) { Write-Warning "some tests failed (see above)" }
}

function Do-Run {
  Step "ros2 run easynav_system system_main ($RunSeconds s)"
  & install\local_setup.ps1
  ros2 daemon stop *> $null
  Step "ros2 easynav plugins"
  ros2 easynav plugins
  $proc = Start-Process -PassThru -NoNewWindow ros2 `
    -ArgumentList "run easynav_system system_main --ros-args --params-file `"$Params`""
  Start-Sleep -Seconds 5
  Step "ros2 node list"
  ros2 node list
  Step "ros2 lifecycle get /system_node"
  ros2 lifecycle get /system_node
  Step "ros2 easynav nav_state"
  ros2 easynav nav_state --duration 3
  Start-Sleep -Seconds ([Math]::Max(0, $RunSeconds - 8))
  Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
}

switch ($Step) {
  "build" { Do-Build }
  "test"  { Do-Test }
  "run"   { Do-Run }
  "all"   { Do-Build; Do-Test; Do-Run }
  default { Write-Error "usage: demo.ps1 [build|test|run|all]"; exit 1 }
}
