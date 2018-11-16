New-NAVAppJson -SetupParameters $SetupParameters

$LaunchJsonPath = Join-Path $SetupParameters.VSCodePath ".vscode\launch.json"
if (!(Test-Path -Path (Split-Path (Split-Path $LaunchJsonPath -Parent) -Parent))) {
    New-Item -Path (Split-Path $LaunchJsonPath -Parent) -ItemType Directory | Out-Null
}
if (!(Test-Path -Path (Split-Path $LaunchJsonPath -Parent))) {
    New-Item -Path (Split-Path $LaunchJsonPath -Parent) -ItemType Directory | Out-Null
}

Update-NAVLaunchJson -SetupParameters $SetupParameters -BranchSettings $BranchSettings -LaunchJsonPath $LaunchJsonPath

$ALTestPath = "$($SetupParameters.VSCodePath)$(Split-Path $SetupParameters.testObjectsPath -Leaf)"
if (Test-Path -Path $ALTestPath) {
    $LaunchJsonPath = Join-Path $ALTestPath ".vscode\launch.json"
    if (!(Test-Path -Path (Split-Path (Split-Path $LaunchJsonPath -Parent) -Parent))) {
    New-Item -Path (Split-Path $LaunchJsonPath -Parent) -ItemType Directory | Out-Null
    }
    if (!(Test-Path -Path (Split-Path $LaunchJsonPath -Parent))) {
        New-Item -Path (Split-Path $LaunchJsonPath -Parent) -ItemType Directory | Out-Null
    }

    Update-NAVLaunchJson -SetupParameters $SetupParameters -BranchSettings $BranchSettings -LaunchJsonPath $LaunchJsonPath
}
