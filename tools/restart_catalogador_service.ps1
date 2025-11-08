# Restart the NSSM-managed Catalogador Python API service
param()

$nssm = 'C:\ProgramData\nssm\nssm.exe'
$svc = 'Catalogador-PythonAPI'

Write-Host "Stopping service $svc..."
& $nssm stop $svc 2>$null
Start-Sleep -Seconds 2
Write-Host "Starting service $svc..."
& $nssm start $svc
Write-Host "Service restart requested. Waiting 3s for the service to become ready..."
Start-Sleep -Seconds 3
Write-Host "Done. Check logs in C:\ProgramData\Catalogador\logs if there are issues."
