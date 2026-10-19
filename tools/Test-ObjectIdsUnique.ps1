<#
.SYNOPSIS
    Guards against duplicate object IDs inside a single app.

.DESCRIPTION
    Scans every .al file under app/src and test/src and asserts that no numeric
    object ID is declared twice within the same app (app vs test are separate
    apps and are never compared against each other). Reproduces the AL0264
    "already declared" test compilation failure that PR #32 / #30 exposed when
    SubBilPrvDocsSkipTakeTst and SubImpCrContrTst both declared codeunit 95705
    in the test app.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Failures = @()

foreach ($AppRoot in @('app', 'test')) {
    $SrcRoot = Join-Path $RepoRoot (Join-Path $AppRoot 'src')
    if (-not (Test-Path -LiteralPath $SrcRoot)) { continue }

    $Declarations = @{}
    Get-ChildItem -LiteralPath $SrcRoot -Recurse -Filter '*.al' | ForEach-Object {
        Select-String -LiteralPath $_.FullName -Pattern '^\s*(?:global\s+)?(?:codeunit|page|table|enum|query|report|permissionset|xmlport|dashlet|chart|interface|tableextension|pageextension|enumextension|reportextension|permissionsetextension)\s+(\d+)' |
            ForEach-Object {
                $id = $Matches[1]
                if ($Declarations.ContainsKey($id)) {
                    $Failures += "$AppRoot: duplicate object ID $id ($($_.Filename) and $($Declarations[$id]))"
                } else {
                    $Declarations[$id] = $_.Filename
                }
            }
    }

    if ($Declarations.Count -eq 0) {
        throw "$AppRoot/src: no object ID declarations found; guard input is wrong."
    }
}

if ($Failures.Count -gt 0) {
    $Failures | ForEach-Object { Write-Error $_ -Action Continue }
    throw "Object ID uniqueness check failed with $($Failures.Count) duplicate(s)."
}

Write-Host 'Object ID uniqueness check passed: no duplicate object IDs within any app.'
