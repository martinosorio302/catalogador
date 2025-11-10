Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd \"$PSScriptRoot/../backend\"; dotnet run"
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd \"$PSScriptRoot/../frontend\"; npm run dev"
Write-Host "API en http://localhost:5000 (Swagger) y FE en http://localhost:5173" -ForegroundColor Green
