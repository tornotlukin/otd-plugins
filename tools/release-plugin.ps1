<#
Packages a plugin release and writes its catalog manifest.

  pwsh tools/release-plugin.ps1 -PluginRepo H:\_DEV\otd-penopticon

Reads the plugin repo's metadata.json and .csproj <Version>, builds it, stages the
DLL + metadata.json + README.md + LICENSE + CHANGELOG.md, zips them to
<PluginRepo>\<Name>-<version>.zip, and writes
Repository\<SupportedDriverVersion>\<Owner>\<Name>\<Name>.json in this catalog with the
release download URL and the ZIP's SHA256.

The ZIP uploaded to the GitHub release must be byte-for-byte the one this script
produced, or OpenTabletDriver will refuse to install it (SHA256 mismatch). Run
tools/verify-catalog.ps1 after uploading and before pushing the catalog.
#>
param(
    [Parameter(Mandatory)][string]$PluginRepo
)

$ErrorActionPreference = 'Stop'
$catalogRoot = Split-Path -Parent $PSScriptRoot
$PluginRepo  = (Resolve-Path $PluginRepo).Path

$meta    = Get-Content (Join-Path $PluginRepo 'metadata.json') -Raw | ConvertFrom-Json
$csproj  = Get-ChildItem $PluginRepo -Filter *.csproj | Select-Object -First 1
if (-not $csproj) { throw "No .csproj in $PluginRepo" }
$project = [xml](Get-Content $csproj.FullName -Raw)
$version = @($project.Project.PropertyGroup | ForEach-Object { $_.Version } | Where-Object { $_ })[0]
$asmName = @($project.Project.PropertyGroup | ForEach-Object { $_.AssemblyName } | Where-Object { $_ })[0]
if (-not $asmName) { $asmName = $csproj.BaseName }
if (-not $version) { throw "No <Version> in $($csproj.Name)" }

if ($meta.PluginVersion -ne "$version.0") {
    throw "metadata.json PluginVersion '$($meta.PluginVersion)' does not match $($csproj.Name) Version '$version' (expected '$version.0')"
}
$changelog = Join-Path $PluginRepo 'CHANGELOG.md'
if ((Test-Path $changelog) -and -not (Select-String -Path $changelog -Pattern "^## $([regex]::Escape($version))\b" -Quiet)) {
    throw "CHANGELOG.md has no '## $version' entry"
}

$tag         = "v$version"
$zipName     = "$($meta.Name)-$version.zip"
$downloadUrl = "$($meta.RepositoryUrl)/releases/download/$tag/$zipName"

dotnet build $csproj.FullName -c Release -nologo -v quiet
if ($LASTEXITCODE -ne 0) { throw "Build failed" }
$dll = Get-ChildItem (Join-Path $PluginRepo 'bin\Release') -Recurse -Filter "$asmName.dll" | Select-Object -First 1
if (-not $dll) { throw "Built $asmName.dll not found" }

$staging = Join-Path $PluginRepo 'release-staging'
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging | Out-Null
Copy-Item $dll.FullName $staging
foreach ($doc in 'README.md', 'LICENSE', 'CHANGELOG.md') {
    $p = Join-Path $PluginRepo $doc
    if (Test-Path $p) { Copy-Item $p $staging }
}
$shipped = $meta | ConvertTo-Json -Depth 5 | ConvertFrom-Json
$shipped.DownloadUrl = $downloadUrl
$shipped.SHA256 = ''
$shipped | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $staging 'metadata.json') -Encoding UTF8

$zip = Join-Path $PluginRepo $zipName
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip
$sha = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()

$manifest = $meta | ConvertTo-Json -Depth 5 | ConvertFrom-Json
$manifest.DownloadUrl = $downloadUrl
$manifest.SHA256 = $sha
$manifestDir = Join-Path $catalogRoot "Repository\$($meta.SupportedDriverVersion)\$($meta.Owner)\$($meta.Name)"
New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
$manifestPath = Join-Path $manifestDir "$($meta.Name).json"
$manifest | ConvertTo-Json -Depth 5 | Set-Content $manifestPath -Encoding UTF8

Write-Host ""
Write-Host "Packaged $zipName"
Write-Host "  ZIP:      $zip"
Write-Host "  SHA256:   $sha"
Write-Host "  Manifest: $manifestPath"
Write-Host ""
Write-Host "Next:"
Write-Host "  1. Commit and push the plugin repo, then tag it: git tag $tag && git push origin $tag"
Write-Host "  2. GitHub -> $($meta.RepositoryUrl)/releases/new -> tag $tag -> attach $zipName (this exact file) -> Publish"
Write-Host "  3. pwsh tools/verify-catalog.ps1"
Write-Host "  4. Commit and push this catalog"
