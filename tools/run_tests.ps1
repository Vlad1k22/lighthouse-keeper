param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$projectPath = Split-Path -Parent $PSScriptRoot
$testNames = @("first_shift_test", "fishing_test", "provisions_test", "spawn_safety_test", "dock_access_test", "expedition_test", "northern_access_test", "ship_asset_test", "cabin_asset_test", "radio_asset_test", "campaign_test")
foreach ($testName in $testNames) {
    Write-Output ("TEST: " + $testName)
    & $Godot --headless --path $projectPath --script ("res://tests/" + $testName + ".gd")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
Write-Output "All Godot integration checks passed."
