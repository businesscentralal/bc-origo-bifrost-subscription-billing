<#
.SYNOPSIS
    Guards against duplicate object IDs of the same type inside a single app.

.DESCRIPTION
    Scans every .al file under app/src and test/src and fails when the same
    object type and numeric ID are declared twice within one app. AL IDs are
    unique per object type, so a table and a page may share a number. App and
    test are separate apps and are never compared with each other. Reproduces
    the AL0264 "already declared" failure from PR #32 / #30, when two test
    codeunits both used 95705.

.PARAMETER SelfTest
    Checks that a table and a page may share an ID, that the same ID in app
    and test is allowed, and that two codeunits with one ID in one app fail.
#>
param(
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeclarationPattern = '(?im)^\s*(?:global\s+)?(codeunit|page|table|enum|query|report|permissionset|xmlport|dashlet|chart|interface|tableextension|pageextension|enumextension|reportextension|permissionsetextension)\s+(\d+)'

function Get-ObjectIdFailures {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $Failures = New-Object System.Collections.Generic.List[string]
    $Regex = [regex]::new($DeclarationPattern)

    foreach ($AppRoot in @('app', 'test')) {
        $SrcRoot = Join-Path $RepoRoot (Join-Path $AppRoot 'src')
        if (-not (Test-Path -LiteralPath $SrcRoot)) { continue }

        $Declarations = @{}
        $Count = 0
        Get-ChildItem -LiteralPath $SrcRoot -Recurse -Filter '*.al' | ForEach-Object {
            $FileName = $_.Name
            foreach ($Match in $Regex.Matches([System.IO.File]::ReadAllText($_.FullName))) {
                $Count++
                $Type = $Match.Groups[1].Value.ToLowerInvariant()
                $Id = $Match.Groups[2].Value
                $Key = "$Type|$Id"
                if ($Declarations.ContainsKey($Key)) {
                    $Failures.Add("$AppRoot`: duplicate $Type $Id ($FileName and $($Declarations[$Key]))")
                } else {
                    $Declarations[$Key] = $FileName
                }
            }
        }

        if ($Count -eq 0) {
            throw "$AppRoot/src: no object ID declarations found; guard input is wrong."
        }
    }

    return $Failures
}

function Invoke-SelfTest {
    $Root = Join-Path ([System.IO.Path]::GetTempPath()) ('object-ids-' + [guid]::NewGuid().ToString('n'))
    try {
        foreach ($Dir in @(
                (Join-Path $Root 'app/src'),
                (Join-Path $Root 'test/src'))) {
            New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        }

        # A table and a page may share a number. The same codeunit ID in the
        # other app is a different extension.
        Set-Content -LiteralPath (Join-Path $Root 'app/src/Customer.Table.al') -Value "table 18 `"Customer`"`n{`n}" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $Root 'app/src/Customer.Page.al') -Value "page 18 `"Customer Card`"`n{`n}" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $Root 'app/src/One.Codeunit.al') -Value "codeunit 50100 `"One`"`n{`n}" -Encoding utf8
        Set-Content -LiteralPath (Join-Path $Root 'test/src/OneTest.Codeunit.al') -Value "codeunit 50100 `"One Test`"`n{`n}" -Encoding utf8

        $Shared = @(Get-ObjectIdFailures -RepoRoot $Root)
        if ($Shared.Count -ne 0) {
            throw "SelfTest FAILED: a table and a page, and the same ID in app and test, must pass. Got: $($Shared -join '; ')"
        }

        Set-Content -LiteralPath (Join-Path $Root 'test/src/Other.Codeunit.al') -Value "codeunit 50100 `"Other`"`n{`n}" -Encoding utf8
        $Duplicate = @(Get-ObjectIdFailures -RepoRoot $Root)
        if ($Duplicate.Count -ne 1 -or $Duplicate[0] -notlike 'test: duplicate codeunit 50100*') {
            throw "SelfTest FAILED: two codeunits with one ID must fail once. Got: $($Duplicate -join '; ')"
        }

        Write-Host 'SelfTest passed.'
    } finally {
        if (Test-Path -LiteralPath $Root) {
            Remove-Item -LiteralPath $Root -Recurse -Force
        }
    }
}

if ($SelfTest) {
    Invoke-SelfTest
    exit 0
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Failures = @(Get-ObjectIdFailures -RepoRoot $RepoRoot)

if ($Failures.Count -gt 0) {
    $Failures | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    throw "Object ID uniqueness check failed with $($Failures.Count) duplicate(s)."
}

Write-Host 'Object ID uniqueness check passed: no duplicate object type and ID within any app.'
