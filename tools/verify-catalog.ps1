<#
Checks every manifest in the catalog the way OpenTabletDriver's Plugin Manager will:
required fields present, download URL reachable, and the downloaded file's SHA256
equal to the manifest's. Run before pushing the catalog.

  pwsh tools/verify-catalog.ps1
#>
$ErrorActionPreference = 'Stop'
$catalogRoot = Split-Path -Parent $PSScriptRoot
$required = 'Name', 'Owner', 'PluginVersion', 'SupportedDriverVersion', 'DownloadUrl', 'CompressionFormat', 'SHA256'
$tmp = Join-Path ([IO.Path]::GetTempPath()) "otd-catalog-verify-$PID"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

$failed = 0
try {
    $manifests = Get-ChildItem (Join-Path $catalogRoot 'Repository') -Recurse -Filter *.json
    $stray = Get-ChildItem $catalogRoot -Recurse -Filter *.json |
        Where-Object { $_.FullName -notlike (Join-Path $catalogRoot 'Repository\*') -and $_.FullName -notlike '*\.git\*' }
    foreach ($s in $stray) {
        Write-Host "FAIL  $($s.FullName): OpenTabletDriver reads every .json in the repo as a manifest; keep JSON files under Repository\ only"
        $failed++
    }

    foreach ($file in $manifests) {
        $m = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $label = "$($m.Name) $($m.PluginVersion) (OTD $($m.SupportedDriverVersion))"
        $missing = $required | Where-Object { -not $m.$_ }
        if ($missing) { Write-Host "FAIL  $label - missing: $($missing -join ', ')"; $failed++; continue }

        $out = Join-Path $tmp ([IO.Path]::GetFileName($m.DownloadUrl))
        try {
            Invoke-WebRequest $m.DownloadUrl -OutFile $out -UserAgent 'OpenTabletDriver'
        } catch {
            Write-Host "FAIL  $label - download failed: $($m.DownloadUrl) ($($_.Exception.Message))"; $failed++; continue
        }
        $sha = (Get-FileHash $out -Algorithm SHA256).Hash.ToLower()
        if ($sha -ne $m.SHA256.ToLower()) {
            Write-Host "FAIL  $label - SHA256 mismatch: manifest $($m.SHA256), download $sha"; $failed++; continue
        }
        Write-Host "OK    $label"
    }
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failed) { Write-Host "`n$failed problem(s) - do not push the catalog yet."; exit 1 }
Write-Host "`nAll manifests verified."
