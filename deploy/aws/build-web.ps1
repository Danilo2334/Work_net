param([Parameter(Mandatory=$true)][uri]$Origin)
$ErrorActionPreference = 'Stop'
if ($Origin.Scheme -ne 'https' -or $Origin.AbsolutePath -ne '/' -or $Origin.UserInfo -or $Origin.Query -or $Origin.Fragment) {
    throw 'Origin must be an HTTPS origin, without credentials, path, query or fragment.'
}
$frontendPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\frontend'))
Push-Location -LiteralPath $frontendPath
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependencies failed.' }
    & flutter build web --release --no-web-resources-cdn "--dart-define=API_BASE_URL=$($Origin.AbsoluteUri.TrimEnd('/'))/api/"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed.' }
} finally {
    Pop-Location
}
