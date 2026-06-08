# run.ps1 — Launch Habo with Supabase cloud sync enabled.
# Reads credentials from dart_defines.json (gitignored) via --dart-define-from-file.
# Usage: .\run.ps1                        (debug, default device)
#        .\run.ps1 --release              (release build)
#        .\run.ps1 -d emulator-5554       (specific device)

param(
    [string]$d = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$definesFile = Join-Path $PSScriptRoot "dart_defines.json"

if (-not (Test-Path $definesFile)) {
    Write-Error "dart_defines.json not found. Create it with SUPABASE_URL and SUPABASE_ANON_KEY."
    exit 1
}

$deviceArgs = if ($d) { @("-d", $d) } else { @() }

Write-Host "dart-define-from-file: $definesFile" -ForegroundColor Cyan

& flutter run @deviceArgs "--dart-define-from-file=$definesFile" @ExtraArgs
