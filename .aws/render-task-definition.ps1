$ErrorActionPreference = "Stop"

# Carrega .env
$envFile = Join-Path $PSScriptRoot "..\.env"

if (-not (Test-Path $envFile)) {
    throw "Arquivo .env não encontrado em: $envFile"
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()

        [System.Environment]::SetEnvironmentVariable(
            $name,
            $value,
            "Process"
        )
    }
}

$variables = @(
    "AWS_REGION",
    "AWS_ACCOUNT_ID",
    "VPC_ID",
    "SUBNET_ID_1",
    "SUBNET_ID_2",
    "SUBNET_ID_3",
    "SG_OBSERVABILITY_ID"
)

foreach ($variable in $variables) {
    $value = [System.Environment]::GetEnvironmentVariable($variable)

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Variável obrigatória não encontrada: $variable"
    }
}

$sourceDir = Join-Path $PSScriptRoot "..\ecs"
$outputDir = Join-Path $PSScriptRoot "..\ecs\rendered"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$files = @(
    "prometheus-task-definition.json",
    "grafana-task-definition.json",
    "prometheus-service.json",
    "grafana-service.json"
)

foreach ($file in $files) {

    $source = Join-Path $sourceDir $file
    $destination = Join-Path $outputDir $file

    if (-not (Test-Path $source)) {
        Write-Warning "Arquivo não encontrado: $source"
        continue
    }

    $content = Get-Content $source -Raw

    $content = $content `
        -replace '\$\{AWS_REGION\}', $env:AWS_REGION `
        -replace '\$\{AWS_ACCOUNT_ID\}', $env:AWS_ACCOUNT_ID `
        -replace '\$\{VPC_ID\}', $env:VPC_ID `
        -replace '\$\{SUBNET_ID_1\}', $env:SUBNET_ID_1 `
        -replace '\$\{SUBNET_ID_2\}', $env:SUBNET_ID_2 `
        -replace '\$\{SUBNET_ID_3\}', $env:SUBNET_ID_3 `
        -replace '\$\{SG_OBSERVABILITY_ID\}', $env:SG_OBSERVABILITY_ID

    Set-Content `
        -Path $destination `
        -Value $content `
        -Encoding UTF8

    Write-Host "Gerado: $destination"
}

Write-Host ""
Write-Host "Task Definitions renderizadas com sucesso."