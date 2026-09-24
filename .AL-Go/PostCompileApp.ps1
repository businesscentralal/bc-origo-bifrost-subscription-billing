Param(
    [string] $appType,
    [ref] $compilationParams
)

# Restores the app.json that PreCompileApp.ps1 rewrote for a release build (see there).
if ($appType -ne 'app') {
    return
}

$appJsonPath = Join-Path $compilationParams.Value.appProjectFolder 'app.json'
$backupPath = "$appJsonPath.precompile.bak"
if (Test-Path -LiteralPath $backupPath) {
    Move-Item -LiteralPath $backupPath -Destination $appJsonPath -Force
    Write-Host "PostCompileApp: restored $appJsonPath."
}
