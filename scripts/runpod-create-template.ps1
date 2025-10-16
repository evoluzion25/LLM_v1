param(
  [string]$RunpodApiKey,
  [Parameter(Mandatory=$true)][string]$Name,
  [ValidateSet('vllm-openai','open-webui')][string]$Preset='vllm-openai',
  [string]$Image,
  [string]$Command,
  [int]$ContainerDiskInGb=50,
  [int]$VolumeInGb=100,
  [int]$GpuCount=1,
  [string]$CudaVersions='12.0,12.1',
  [string]$Readme=''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RunpodApiKey)) {
  $RunpodApiKey = $env:RUNPOD_API_KEY
}
if ([string]::IsNullOrWhiteSpace($RunpodApiKey)) {
  $RunpodApiKey = [Environment]::GetEnvironmentVariable('RUNPOD_API_KEY', 'User')
}
if ([string]::IsNullOrWhiteSpace($RunpodApiKey)) {
  throw 'RUNPOD_API_KEY not found. Set it via $env:RUNPOD_API_KEY or pass -RunpodApiKey.'
}

# Reasonable defaults for presets
switch ($Preset) {
  'vllm-openai' {
    if (-not $Image) { $Image = 'vllm/vllm-openai:latest' }
    if (-not $Command) { $Command = 'python -m vllm.entrypoints.openai.api_server --host 0.0.0.0 --port 8000 --model mistralai/Mistral-7B-Instruct-v0.3' }
    $ports = @(@{ containerPort = 8000; protocol = 'TCP' })
  }
  'open-webui' {
    if (-not $Image) { $Image = 'ghcr.io/open-webui/open-webui:main' }
    if (-not $Command) { $Command = '' }
    $ports = @(@{ containerPort = 3000; protocol = 'TCP' })
  }
}

$input = @{
  name = $Name
  description = "Template created via script for preset '$Preset'"
  readme = $Readme
  container = @{
    image = $Image
    command = $Command
    ports = $ports
    env = @()
  }
  resources = @{
    gpuCount = $GpuCount
    containerDiskInGb = $ContainerDiskInGb
    volumeInGb = $VolumeInGb
    cudaVersions = ($CudaVersions -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  }
}

$headers = @{ Authorization = 'Bearer ' + $RunpodApiKey; 'Content-Type' = 'application/json' }
$uri = 'https://api.runpod.io/graphql'

function Invoke-Gql($query, $variables) {
  $bodyObj = @{ query = $query; variables = $variables }
  $body = $bodyObj | ConvertTo-Json -Depth 10
  $resp = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $body
  return $resp
}

# Try common mutation names if schema varies
$tries = @(
  @{ name = 'createTemplate'; q = 'mutation($input: CreateTemplateInput!) { createTemplate(input: $input) { id name } }' },
  @{ name = 'templateCreate'; q = 'mutation($input: TemplateCreateInput!) { templateCreate(input: $input) { id name } }' },
  @{ name = 'upsertTemplate'; q = 'mutation($input: UpsertTemplateInput!) { upsertTemplate(input: $input) { id name } }' }
)

$created = $null
$lastErr = $null
foreach ($t in $tries) {
  try {
    Write-Host "Attempting mutation: $($t.name)"
    $resp = Invoke-Gql -query $t.q -variables @{ input = $input }
    if ($resp.errors) { throw ($resp.errors | ConvertTo-Json -Depth 10) }
    $data = $resp.data[$t.name]
    if ($null -ne $data) { $created = $data; break }
  }
  catch {
    $lastErr = $_
    Write-Warning "Mutation $($t.name) failed: $($_.Exception.Message)"
  }
}

if ($null -ne $created) {
  Write-Host 'TEMPLATE_CREATED_BEGIN'
  $created | ConvertTo-Json -Depth 10 | Write-Output
  Write-Host 'TEMPLATE_CREATED_END'
  exit 0
}

Write-Warning 'Could not create template via known mutations.'
Write-Host 'Attempting to introspect schema for diagnostics...'
$q = '{ __schema { mutationType { name fields { name } } } }'
$diag = Invoke-Gql -query $q -variables @{}
$diag | ConvertTo-Json -Depth 10 | Write-Output

Write-Error 'Creation failed. If API names differ, please share the mutation field list above and I will update the script. As a fallback, create a Pod with scripts/runpod-create-pod.ps1 and click "Save as Template" in the RunPod UI.'
