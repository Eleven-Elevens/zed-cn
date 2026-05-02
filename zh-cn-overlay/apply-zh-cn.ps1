param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function ConvertTo-RustStringContent {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    return $Value.
        Replace('\', '\\').
        Replace('"', '\"').
        Replace("`r", '\r').
        Replace("`n", '\n').
        Replace("`t", '\t')
}

function Resolve-PathUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Translation file path must be relative: $RelativePath"
    }

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootFull $RelativePath))
    $rootWithSeparator = $rootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    if (-not $candidate.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Translation file path escapes repository root: $RelativePath"
    }

    return $candidate
}

function Test-MatchInRustComment {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory = $true)][int]$Index
    )

    $lineStart = $Content.LastIndexOf("`n", [Math]::Max($Index - 1, 0))
    if ($lineStart -eq -1) {
        $lineStart = 0
    } else {
        $lineStart += 1
    }

    $linePrefix = $Content.Substring($lineStart, $Index - $lineStart)
    if ($linePrefix.IndexOf('//', [System.StringComparison]::Ordinal) -ge 0) {
        return $true
    }

    return $false
}

function Get-RustCodeLiteralMatchIndexes {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Literal
    )

    $indexes = New-Object System.Collections.Generic.List[int]
    $offset = 0

    while ($true) {
        $index = $Content.IndexOf($Literal, $offset, [System.StringComparison]::Ordinal)
        if ($index -lt 0) {
            break
        }

        if (-not (Test-MatchInRustComment -Content $Content -Index $index)) {
            $indexes.Add($index)
        }

        $offset = $index + $Literal.Length
    }

    return $indexes.ToArray()
}

function Replace-RustCodeLiterals {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$FromLiteral,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ToLiteral
    )

    $indexes = @(Get-RustCodeLiteralMatchIndexes -Content $Content -Literal $FromLiteral)
    if ($indexes.Count -eq 0) {
        return $Content
    }

    $builder = New-Object System.Text.StringBuilder
    $position = 0

    foreach ($index in $indexes) {
        [void]$builder.Append($Content.Substring($position, $index - $position))
        [void]$builder.Append($ToLiteral)
        $position = $index + $FromLiteral.Length
    }

    [void]$builder.Append($Content.Substring($position))
    return $builder.ToString()
}

function Get-PreviousToValues {
    param([Parameter(Mandatory = $true)]$Entry)

    if (-not $Entry.PSObject.Properties.Name.Contains('previous_to')) {
        return @()
    }

    return @($Entry.previous_to) |
        Where-Object { -not [string]::IsNullOrEmpty([string]$_) } |
        ForEach-Object { [string]$_ }
}

$repoRootFull = [System.IO.Path]::GetFullPath((Resolve-Path $RepoRoot).Path)
$translationsPath = Join-Path $PSScriptRoot 'translations.json'

if (-not (Test-Path $translationsPath)) {
    throw "Missing translations file: $translationsPath"
}

$translations = @(Get-Content -Raw -Encoding UTF8 $translationsPath | ConvertFrom-Json)
if ($translations.Count -eq 1 -and $translations[0] -is [System.Array]) {
    $translations = @($translations[0])
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$contentsByPath = @{}
$failures = New-Object System.Collections.Generic.List[string]
$alreadyApplied = 0
$willApply = 0

foreach ($entry in $translations) {
    foreach ($field in @('id', 'file', 'from', 'to')) {
        if (-not $entry.PSObject.Properties.Name.Contains($field)) {
            $failures.Add("$($entry.id): missing field '$field'")
        }
    }

    if ($failures.Count -gt 0) {
        continue
    }

    $path = Resolve-PathUnderRoot -Root $repoRootFull -RelativePath $entry.file
    if (-not (Test-Path $path)) {
        $failures.Add("$($entry.id): missing file $($entry.file)")
        continue
    }

    if (-not $contentsByPath.ContainsKey($path)) {
        $contentsByPath[$path] = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    }

    if ($entry.PSObject.Properties.Name.Contains('from_source') -or $entry.PSObject.Properties.Name.Contains('to_source')) {
        if (-not ($entry.PSObject.Properties.Name.Contains('from_source') -and $entry.PSObject.Properties.Name.Contains('to_source'))) {
            $failures.Add("$($entry.id): from_source and to_source must be provided together")
            continue
        }

        $fromLiteral = [string]$entry.from_source
        $toLiteral = [string]$entry.to_source
    } else {
        $fromLiteral = '"' + (ConvertTo-RustStringContent $entry.from) + '"'
        $toLiteral = '"' + (ConvertTo-RustStringContent $entry.to) + '"'
    }
    $content = $contentsByPath[$path]
    $fromLiterals = New-Object System.Collections.Generic.List[string]
    [void]$fromLiterals.Add($fromLiteral)

    foreach ($previousTo in (Get-PreviousToValues -Entry $entry)) {
        if ($previousTo -ne [string]$entry.to) {
            $previousLiteral = '"' + (ConvertTo-RustStringContent $previousTo) + '"'
            if (-not $fromLiterals.Contains($previousLiteral)) {
                [void]$fromLiterals.Add($previousLiteral)
            }
        }
    }

    $fromCount = 0
    foreach ($literal in $fromLiterals) {
        $fromCount += @(Get-RustCodeLiteralMatchIndexes -Content $content -Literal $literal).Count
    }
    $toCount = @(Get-RustCodeLiteralMatchIndexes -Content $content -Literal $toLiteral).Count
    $expectedCount = 1

    if ($entry.PSObject.Properties.Name.Contains('expected_count')) {
        $expectedCount = [int]$entry.expected_count
    }

    if ($fromLiteral -eq $toLiteral) {
        $sameCount = @(Get-RustCodeLiteralMatchIndexes -Content $content -Literal $fromLiteral).Count
        if ($sameCount -ge $expectedCount) {
            $alreadyApplied += $expectedCount
            continue
        }
    }

    if ($fromCount -eq $expectedCount) {
        $willApply += $fromCount
        continue
    }

    if ($fromCount -eq 0 -and $toCount -ge $expectedCount) {
        $alreadyApplied += $expectedCount
        continue
    }

    $failures.Add("$($entry.id): expected $expectedCount match(es) for $($entry.file), found from=$fromCount, already_translated=$toCount")
}

if ($failures.Count -gt 0) {
    Write-Host 'Localization preflight failed:'
    foreach ($failure in $failures) {
        Write-Host "  - $failure"
    }
    exit 1
}

$changedPaths = New-Object System.Collections.Generic.HashSet[string]

foreach ($entry in $translations) {
    $path = Resolve-PathUnderRoot -Root $repoRootFull -RelativePath $entry.file
    if ($entry.PSObject.Properties.Name.Contains('from_source')) {
        $fromLiteral = [string]$entry.from_source
        $toLiteral = [string]$entry.to_source
    } else {
        $fromLiteral = '"' + (ConvertTo-RustStringContent $entry.from) + '"'
        $toLiteral = '"' + (ConvertTo-RustStringContent $entry.to) + '"'
    }
    $content = $contentsByPath[$path]
    if ($fromLiteral -eq $toLiteral) {
        continue
    }

    $fromLiterals = New-Object System.Collections.Generic.List[string]
    [void]$fromLiterals.Add($fromLiteral)

    foreach ($previousTo in (Get-PreviousToValues -Entry $entry)) {
        if ($previousTo -ne [string]$entry.to) {
            $previousLiteral = '"' + (ConvertTo-RustStringContent $previousTo) + '"'
            if (-not $fromLiterals.Contains($previousLiteral)) {
                [void]$fromLiterals.Add($previousLiteral)
            }
        }
    }

    $updated = $content
    foreach ($literal in $fromLiterals) {
        $updated = Replace-RustCodeLiterals -Content $updated -FromLiteral $literal -ToLiteral $toLiteral
    }

    if ($updated -ne $content) {
        $contentsByPath[$path] = $updated
        [void]$changedPaths.Add($path)
    }
}

foreach ($path in $changedPaths) {
    [System.IO.File]::WriteAllText($path, $contentsByPath[$path], $utf8NoBom)
}

Write-Host "Localization applied."
Write-Host "  entries: $($translations.Count)"
Write-Host "  replacements: $willApply"
Write-Host "  already applied: $alreadyApplied"
Write-Host "  files changed: $($changedPaths.Count)"
