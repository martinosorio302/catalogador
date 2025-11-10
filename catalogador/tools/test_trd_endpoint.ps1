param()

Write-Host "Running TRD endpoint smoke test against http://127.0.0.1:8000/trd/classify"

$url = 'http://127.0.0.1:8000/trd/classify'
$body = @{ serie = 'Correspondencia'; subserie = 'Cartas emitidas'; tipo = 'Carta' } | ConvertTo-Json

try {
    $resp = Invoke-RestMethod -Method Post -Uri $url -ContentType 'application/json' -Body $body -TimeoutSec 10
    Write-Host "Response:`n" ($resp | ConvertTo-Json -Depth 5)
    if($resp -and ($resp.plazoConservacionAnios -ne $null -or $resp.temporalidad -ne $null)){
        Write-Host "SMOKE TEST: OK" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "SMOKE TEST: FAILED - Missing expected fields (temporalidad/plazoConservacionAnios)" -ForegroundColor Red
        exit 2
    }
} catch {
    Write-Host ("SMOKE TEST: ERROR - {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 3
}
