Write-Host "== Backend ==" -ForegroundColor Cyan
Push-Location backend
 dotnet restore
Pop-Location

Write-Host "== Frontend ==" -ForegroundColor Cyan
Push-Location frontend
 npm install
Pop-Location
Write-Host "Listo." -ForegroundColor Green
