<#
Run the project's pytest suite using the ProgramData venv when present,
or the local Python interpreter otherwise. Designed for developers to run
tests locally in a reproducible way.
#>

param(
    [switch]$VerboseMode
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$serviceVenv = 'C:\ProgramData\Catalogador\python_api\venv\Scripts\pytest.exe'

if (Test-Path $serviceVenv) {
    Write-Host "Using service venv pytest: $serviceVenv"
    & $serviceVenv -q
} else {
    Write-Host "Using system pytest (expect you have a virtualenv)."
    python -m pytest -q
}
