param(
  [Parameter(Mandatory=$true)][string]$RunpodApiKey,
  [string]$Preset = "vllm-openai", # or "open-webui"
  [string]$Name = "legal-vllm",
  [string]$GpuQuery = "H100",
  [int]$GpuCount = 1,
  [ValidateSet('SECURE','COMMUNITY')][string]$CloudType = 'SECURE',
  [bool]$Interruptible = $false,
  [int]$VolumeInGb = 100,
  [int]$ContainerDiskInGb = 50,
  [string]$CudaVersions = "",
  [string]$VllmModel = "mistralai/Mistral-7B-Instruct-v0.3",
  [int]$VllmMaxContext = 32768,
  [string]$HfToken = ""
)

$ErrorActionPreference = 'Stop'

function Invoke-RunpodGraphQL {
  param([string]$ApiKey,[string]$Query)
  $resp = Invoke-RestMethod -Method Post -Uri ("https://api.runpod.io/graphql?api_key={0}" -f $ApiKey) -Headers @{ 'content-type'='application/json' } -Body (@{ query = $Query } | ConvertTo-Json -Depth 6)
  if ($resp.errors) { throw ($resp.errors | ConvertTo-Json -Depth 6) }
  return $resp.data
}

function Get-GpuTypeId {
  param([string]$ApiKey,[string]$Query)
  $q = @"
query GpuTypes { gpuTypes { id displayName memoryInGb } }
"@
  $data = Invoke-RunpodGraphQL -ApiKey $ApiKey -Query $q
  $match = $data.gpuTypes | Where-Object { $_.id -like "*${Query}*" -or $_.displayName -like "*${Query}*" } | Select-Object -First 1
  if (-not $match) { throw "No GPU type matched query '$Query'" }
  return $match.id
}

$gpuTypeId = Get-GpuTypeId -ApiKey $RunpodApiKey -Query $GpuQuery

# Presets
switch ($Preset) {
  'vllm-openai' {
    $imageName = 'vllm/vllm-openai:latest'
    $ports = @('8000/http')
    $dockerStartCmd = @('python','-m','vllm.entrypoints.openai.api_server','--model', $VllmModel,'--port','8000','--max-model-len',"$VllmMaxContext")
    $env = @{}
    if ($HfToken) { $env['HUGGING_FACE_HUB_TOKEN'] = $HfToken }
  }
  'open-webui' {
    $imageName = 'ghcr.io/open-webui/open-webui:main'
    $ports = @('3000/http')
    $dockerStartCmd = @()
    $env = @{}
  }
  default { throw "Unknown preset '$Preset'" }
}

$allowedCuda = @()
if ($CudaVersions) { $allowedCuda = $CudaVersions.Split(',') | ForEach-Object { $_.Trim() } }

$body = [ordered]@{
  cloudType = $CloudType
  computeType = 'GPU'
  containerDiskInGb = $ContainerDiskInGb
  env = $env
  gpuCount = $GpuCount
  gpuTypeIds = @($gpuTypeId)
  imageName = $imageName
  interruptible = [bool]$Interruptible
  name = $Name
  ports = $ports
  volumeInGb = $VolumeInGb
  volumeMountPath = '/workspace'
}
if ($dockerStartCmd.Count -gt 0) { $body['dockerStartCmd'] = $dockerStartCmd }
if ($allowedCuda.Count -gt 0) { $body['allowedCudaVersions'] = $allowedCuda }

$headers = @{ Authorization = "Bearer $RunpodApiKey"; 'Content-Type'='application/json' }
$resp = Invoke-RestMethod -Method Post -Uri 'https://rest.runpod.io/v1/pods' -Headers $headers -Body ($body | ConvertTo-Json -Depth 8)
$resp | ConvertTo-Json -Depth 8
