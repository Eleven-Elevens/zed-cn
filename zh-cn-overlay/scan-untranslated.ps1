param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Output = (Join-Path $PSScriptRoot 'untranslated-report.json')
)

$ErrorActionPreference = 'Stop'

function ConvertFrom-RustStringContent {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    return $Value.
        Replace('\"', '"').
        Replace('\n', "`n").
        Replace('\r', "`r").
        Replace('\t', "`t").
        Replace('\\', '\')
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
        throw "Path escapes repository root: $RelativePath"
    }

    return $candidate
}

function Test-MatchInRustLineComment {
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
    return $linePrefix.IndexOf('//', [System.StringComparison]::Ordinal) -ge 0
}

function Test-ProbablyUiText {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    if ($Text -match '^(https?://|zed://|[a-z0-9_.-]+::[A-Za-z]|[a-z0-9_.-]+/[a-z0-9_.-]+)$') {
        return $false
    }

    if ($Text -cmatch '^[a-z0-9_.:-]+$') {
        return $false
    }

    if ($Text -match '[\u3400-\u9fff]') {
        return $false
    }

    if ($Text -notmatch '[A-Za-z]') {
        return $false
    }

    if ($Text -cmatch '^[A-Z]$') {
        return $false
    }

    return $true
}

function Test-ShouldIgnoreCandidate {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
    )

    $ignoredExact = @(
        '\u{2022}',
        'Visual Test Model',
        'Fake',
        'MySymbol',
        'Claude',
        'Gemini',
        'Pro',
        'GitHub Copilot',
        'Test Author',
        'John Doe',
        'static str',
        'String',
        'LM Studio',
        'Ollama',
        'OpenAI',
        'AI',
        'Vim',
        'LSP',
        'LspLogView',
        'LspViewSelector',
        'TestLang',
        'Test Family',
        'Zed',
        'Zed Agent',
        'Zed Twitter',
        'Git Commit',
        'WSL:',
        'Placeholder tool to satisfy Bedrock API requirements when conversation history contains tool usage',
        'zed-cloud, zed, edit-prediction-bench, zed.dev',
        'https://zed.dev',
        'simulated error',
        'prompt is too long: 1234953 tokens',
        'not a prompt length error',
        'prompt is too long: 12345 tokens',
        'prompt is too long: invalid tokens',
        'Failed to blame "file.txt": failed to get blame for "file.txt"',
        'unused function',
        'initial commit',
        'initial stash',
        'updated stash',
        'too many requests',
        'use of moved value `a`',
        'ENV=Zed ~/bin/program --option',
        'AIzaSy...',
        "Your local changes to the following files would be overwritten by merge`n",
        "cannot borrow ``self.d`` as mutable`n``self`` is a ``&`` reference",
        'Unrecognized method `{}`',
        'missing semicolon'
        'LICENSES'
    )

    if ($ignoredExact -contains $Text) {
        return $true
    }

    if ($Text -match '^(Accept|Accept-Encoding|Authorization|Connection|Content-Encoding|Content-Type|Editor-Version|HTTP-Referer|OpenAI-Intent|User-Agent|WWW-Authenticate|X-Api-Key|X-GitHub-Api-Version|X-Initiator|X-Interaction-Type|X-Snowflake-Authorization-Token-Type|X-Title)$') {
        return $true
    }

    if ($Text -match '^[A-Z][A-Za-z0-9]*(-[A-Z]?[A-Za-z0-9]+)+$') {
        return $true
    }

    if ($Text -cmatch '^[a-z][A-Za-z0-9_.-]*$' -and $Text -notmatch '\s') {
        return $true
    }

    if ($Text -match '^<.*>$') {
        return $true
    }

    if ($Text -match '^(LANG|Mercury)$') {
        return $true
    }

    if ($Text -match '^(Rust|TypeScript|JavaScript|Markdown|HTML|Python|TOML|JSON|TSX|Ruby|C\+\+|C|ERB|HEEx|HTML\+ERB|Elixir|Dockerfile|Json)$') {
        return $true
    }

    if ($Text -match '^(refs/|zed/|~/)') {
        return $true
    }

    if ($Text -match '^(lms|ollama) ') {
        return $true
    }

    if ($Text -match '^(ssh |zed://|\+?\\u\{|[vV]\{\}|[+\u2212\u2012-]\\s*\\u\{|[{}.:#0-9,\s]+ms$)' -or
        $Text -match '^\+\{[A-Za-z_][A-Za-z0-9_]*\}$' -or
        $Text -match '^\(\{[A-Za-z_][A-Za-z0-9_]*\}\)$') {
        return $true
    }

    if ($Text -match '^(fn |type |extern crate|const |hello\(|one\.two\.|two\.Three|await\.|pub fn |len:|inner_value:|println!|vec!|if let |for item |Particles \{)') {
        return $true
    }

    if ($Text -match '[;<>]') {
        return $true
    }

    if ($Text -match '^\{.*\}$') {
        return $true
    }

    if ($RelativePath -match '^crates/gpui/src/' -or $RelativePath -match '^crates/picker/src/picker.rs$') {
        return $true
    }

    return $false
}

function New-IdSuggestion {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $module = $RelativePath -replace '^crates/', '' -replace '/src/.*$', ''
    $slug = $Text.ToLowerInvariant() -replace '[^a-z0-9]+', '_' -replace '^_+|_+$', ''
    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = 'text'
    }
    return "ui.$module.$slug"
}

$repoRootFull = [System.IO.Path]::GetFullPath((Resolve-Path $RepoRoot).Path)
$translationsPath = Join-Path $PSScriptRoot 'translations.json'
$translated = New-Object 'System.Collections.Generic.HashSet[string]'

if (Test-Path $translationsPath) {
    $translations = @(Get-Content -Raw -Encoding UTF8 $translationsPath | ConvertFrom-Json)
    if ($translations.Count -eq 1 -and $translations[0] -is [System.Array]) {
        $translations = @($translations[0])
    }

    foreach ($entry in $translations) {
        [void]$translated.Add("$($entry.file)`0$($entry.from)")
        [void]$translated.Add("$($entry.file)`0$($entry.to)")
    }
}

$patterns = @(
    @{ name = 'MenuItem'; regex = 'MenuItem::(?:action|os_action|os_submenu)\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'MenuNew'; regex = 'Menu::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'MenuName'; regex = 'name:\s*"((?:\\.|[^"\\])*)"\.into\(\)' },
    @{ name = 'Button'; regex = 'Button::new\([\s\S]{0,160}?,\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ButtonLabel'; regex = '\.button_label\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ButtonLink'; regex = 'ButtonLink::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'InputFieldPlaceholder'; regex = 'InputField::new\([\s\S]{0,220}?,\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ComponentExampleGroup'; file_regex = '^crates/(ui/src/components|component_preview/src)/'; regex = 'example_group_with_title\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ComponentSingleExample'; file_regex = '^crates/(ui/src/components|component_preview/src)/'; regex = 'single_example\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ComponentDescription'; file_regex = '^crates/(ui/src/components|component_preview/src)/'; regex = 'fn\s+description\(\)\s*->[^{]+\{\s*Some\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'DropdownMenuLabel'; file_regex = '^crates/(ui/src/components|component_preview/src)/'; regex = 'DropdownMenu::new\([^,]+,\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ToggleButtonSimple'; file_regex = '^crates/(ui/src/components|component_preview/src)/'; regex = 'ToggleButtonSimple::new\([^,]+,\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SingleLineInputLabel'; regex = '\bsingle_line_input\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ChildFormat'; regex = '\.child\(\s*format!\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ContextMenuEntry'; regex = 'ContextMenuEntry::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ContextMenuEntryMethod'; regex = '\.entry\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ContextMenuSubmenu'; regex = '\.submenu(?:_with_icon)?\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ContextMenuToggleableEntry'; regex = '\.toggleable_entry\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ListBulletItem'; regex = 'ListBulletItem::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Description'; regex = '\.description\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'DescriptionFormatVar'; regex = '\blet\s+description\s*=\s*format!\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'DismissLabel'; regex = '\.dismiss_label\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Headline'; regex = 'Headline::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'HeadlineMethod'; regex = '\.headline\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Header'; regex = '\.header\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Label'; regex = 'Label::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'LabelFormat'; regex = 'Label::new\(\s*format!\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'LabelMethod'; regex = '\.label\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'LabelWithContrast'; regex = 'label_with_contrast\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'MenuAction'; regex = '\.action\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'MenuActionDisabledWhen'; regex = '\.action_disabled_when\(\s*[^,]+,\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'MessageFieldFormat'; regex = '\bmessage:\s*format!\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'MessageFieldString'; regex = '\bmessage:\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'EmptyMessage'; regex = '\.empty_message\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Placeholder'; regex = '\.placeholder\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'PathPrompt'; regex = '\bprompt:\s*Some\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SetPlaceholderText'; regex = 'set_placeholder_text\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'PrimaryAction'; regex = '\.primary_action\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'PromptButton'; regex = 'window\.prompt\([\s\S]{0,400}?,\s*&\[[^\]]*"((?:\\.|[^"\\])*)"' },
    @{ name = 'RenderLoading'; regex = 'render_loading\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SectionHeader'; regex = 'section_header\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SecondaryAction'; regex = '\.secondary_action\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Tab'; regex = 'Tab::new\([^,\r\n]+,\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'TabHelper'; regex = '\btab\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ToastNew'; regex = '(?:[\w:]+::)?Toast::new\([\s\S]{0,300}?,\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ToastFormat'; regex = '(?:[\w:]+::)?Toast::new\([\s\S]{0,300}?,\s*format!\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'StatusToastNew'; regex = 'StatusToast::new\([\s\S]{0,300}?,\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'StatusToastFirstArg'; regex = 'StatusToast::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'StatusToastFormat'; regex = 'StatusToast::new\([\s\S]{0,300}?,\s*format!\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SetStatus'; regex = 'set_status\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'ErrorMessagePrompt'; regex = 'ErrorMessagePrompt::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'LinkButton'; regex = '\.with_link_button\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'MessageNotificationFormat'; regex = 'MessageNotification::new\(\s*format!\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'PrimaryMessage'; regex = '\.primary_message\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Chip'; regex = 'Chip::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'DeferredToast'; regex = 'show_deferred_toast\([\s\S]{0,160}?,\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Tooltip'; regex = 'Tooltip::(?:text|simple|for_action_title|for_action|with_meta)\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'TooltipIn'; regex = 'Tooltip::(?:with_meta_in)\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'TooltipLabel'; regex = '\.tooltip_label\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'TooltipMeta'; regex = 'Tooltip::(?:with_meta|with_meta_in)\([\s\S]{0,260}?,\s*(?:None|Some\([^)]*\)),\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Child'; regex = '\.child\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'Title'; regex = '\.title\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'TitleFormat'; regex = '\.title\(\s*format!\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SharedStringNew'; regex = 'SharedString::new\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SharedStringFrom'; regex = 'SharedString::from\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SettingsSectionHeader'; file_regex = '^crates/settings_ui/src/'; regex = 'SettingsPageItem::SectionHeader\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SettingsFieldTitle'; file_regex = '^crates/settings_ui/src/'; regex = '\btitle:\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SettingsFieldDescription'; file_regex = '^crates/settings_ui/src/'; regex = '\bdescription:\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'SettingsPlaceholder'; file_regex = '^crates/settings_ui/src/'; regex = '\bplaceholder:\s*Some\(\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'TupleColorLabel'; regex = '\(\s*"((?:\\.|[^"\\])*)"\s*,\s*Color::' },
    @{ name = 'DapAdapterSchemaDescription'; file_regex = '^crates/dap_adapters/src/'; regex = '"description"\s*:\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'DapAdapterSchemaLabel'; file_regex = '^crates/dap_adapters/src/'; regex = '"label"\s*:\s*"((?:\\.|[^"\\])*)"' },
    @{ name = 'DapAdapterSchemaMarkdownDeprecationMessage'; file_regex = '^crates/dap_adapters/src/'; regex = '"markdownDeprecationMessage"\s*:\s*"((?:\\.|[^"\\])*)"' }
)

function Get-RepositoryRustFiles {
    param([Parameter(Mandatory = $true)][string]$Root)

    $trackedFiles = @(git -C $Root ls-files '*.rs' 2>$null)
    if ($trackedFiles.Count -gt 0) {
        return $trackedFiles
    }

    $rootUri = [System.Uri]($Root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar)

    return Get-ChildItem -Path $Root -Recurse -File -Filter '*.rs' |
        ForEach-Object {
            $fileUri = [System.Uri]$_.FullName
            [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($fileUri).ToString())
        } |
        Where-Object {
            $_ -notmatch '(^|/)(\.git|target)(/|$)'
        }
}

$files = Get-RepositoryRustFiles -Root $repoRootFull | Where-Object {
    $_ -notmatch '(^|/)(tests?|fixtures?|evals?|benches|examples)(/|$)' -and
    $_ -notmatch '(^|/)(test|tests|.*_test|.*_tests)\.rs$' -and
    $_ -notmatch '^tooling/' -and
    $_ -notmatch '^crates/gpui/examples/' -and
    $_ -notmatch '^crates/agent/src/(edit_agent|tools)/evals/'
}

$results = New-Object System.Collections.Generic.List[object]
$seen = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($relativePath in $files) {
    $fullPath = Resolve-PathUnderRoot -Root $repoRootFull -RelativePath $relativePath
    $content = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
    $testModuleIndex = $content.IndexOf("#[cfg(test)]", [System.StringComparison]::Ordinal)
    if ($testModuleIndex -ge 0) {
        $content = $content.Substring(0, $testModuleIndex)
    }

    foreach ($pattern in $patterns) {
        if ($pattern.ContainsKey('file_regex') -and $relativePath -notmatch $pattern.file_regex) {
            continue
        }

        foreach ($match in [regex]::Matches($content, $pattern.regex, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
            if (Test-MatchInRustLineComment -Content $content -Index $match.Index) {
                continue
            }

            $rawText = $match.Groups[1].Value
            $text = ConvertFrom-RustStringContent $rawText

            if (-not (Test-ProbablyUiText $text)) {
                continue
            }

            if (Test-ShouldIgnoreCandidate -RelativePath $relativePath -Text $text) {
                continue
            }

            if ($translated.Contains("$relativePath`0$text")) {
                continue
            }

            $line = 1
            if ($match.Index -gt 0) {
                $line = ([regex]::Matches($content.Substring(0, $match.Index), "`n")).Count + 1
            }

            $key = "$relativePath`0$line`0$text`0$($pattern.name)"
            if (-not $seen.Add($key)) {
                continue
            }

            $results.Add([pscustomobject]@{
                id_suggestion = New-IdSuggestion -RelativePath $relativePath -Text $text
                file = $relativePath
                line = $line
                text = $text
                pattern = $pattern.name
            })
        }
    }
}

$sortedResults = @($results | Sort-Object file, line, text)
if ($sortedResults.Count -eq 0) {
    '[]' | Set-Content -Encoding UTF8 $Output
} else {
    $sortedResults |
        ConvertTo-Json -Depth 4 |
        Set-Content -Encoding UTF8 $Output
}

Write-Host "Scan complete."
Write-Host "  candidates: $($results.Count)"
Write-Host "  output: $Output"
