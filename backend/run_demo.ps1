param([int]$Port = 8000)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $pythonPath)) { throw 'Create backend/.venv and install requirements.txt first.' }
$env:DEBUG = 'false'
$env:ENVIRONMENT = 'development'
$env:ENABLE_DEMO_WORKSPACE = 'true'
# Explicit local demo database; PostgreSQL remains the normal backend default.
$databasePath = (Join-Path $PSScriptRoot 'demo.db').Replace('\', '/')
$env:DATABASE_URL = "sqlite+aiosqlite:///$databasePath"
if (-not $env:WORKSPACE_DEMO_TOKEN) { $env:WORKSPACE_DEMO_TOKEN = & $pythonPath -c 'import secrets; print(secrets.token_urlsafe(24))' }
if (-not $env:ADMIN_ACCESS_TOKEN) { $env:ADMIN_ACCESS_TOKEN = & $pythonPath -c 'import secrets; print(secrets.token_urlsafe(32))' }
Write-Host 'Shared demo server. No money is transferred. Keep the admin token private.'
Write-Host "Mobile workspace token: $env:WORKSPACE_DEMO_TOKEN"
Write-Host "Admin access token: $env:ADMIN_ACCESS_TOKEN"
Write-Host "Admin dashboard: http://localhost:$Port/api/v1/workspace/admin"
& $pythonPath -m uvicorn main:app --host 0.0.0.0 --port $Port
