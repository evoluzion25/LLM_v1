param(
  [string]$RunpodApiKey,
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
  [string]$HfToken = "",
  [string]$NetworkVolumeId = "",
  [string]$VolumeMountPath = "/workspace",
  [switch]$EnableSsh,
  [string]$SshPublicKey = ""
)

$ErrorActionPreference = 'Stop'

if (-not $RunpodApiKey -or [string]::IsNullOrWhiteSpace($RunpodApiKey)) {
  $RunpodApiKey = $env:RUNPOD_API_KEY
}
if (-not $RunpodApiKey) {
  throw "Missing RunPod API key. Pass -RunpodApiKey or set $env:RUNPOD_API_KEY."
}

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

$allowedCuda = @()
if ($CudaVersions) { $allowedCuda = $CudaVersions.Split(',') | ForEach-Object { $_.Trim() } }

# Defaults
$ports = @()
$env = @{}
$dockerStartCmd = @()
$imageName = ''

switch ($Preset) {
  'vllm-openai' {
    $imageName = 'vllm/vllm-openai:latest'
    $ports += '8000/http'
    if ($HfToken) { $env['HUGGING_FACE_HUB_TOKEN'] = $HfToken }
    if ($EnableSsh) {
      $ports += '22/tcp'
      if (-not $SshPublicKey) { $SshPublicKey = $env:RUNPOD_SSH_PUBKEY }
      if ($SshPublicKey) { $env['SSH_PUBKEY'] = $SshPublicKey }
      $dockerStartCmd = @(
        'bash','-lc',
        ("set -euo pipefail; " +
         "apt-get update && apt-get install -y openssh-server; " +
         "mkdir -p /var/run/sshd /root/.ssh; " +
         "if [ -n \"\${SSH_PUBKEY:-}\" ]; then echo \"\${SSH_PUBKEY}\" > /root/.ssh/authorized_keys; fi; " +
         "chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys || true; " +
         "sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config || true; " +
         "if grep -q '^PermitRootLogin' /etc/ssh/sshd_config; then sed -i 's/^PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config; else echo 'PermitRootLogin prohibit-password' >> /etc/ssh/sshd_config; fi; " +
         "/usr/sbin/sshd; " +
         "python -m vllm.entrypoints.openai.api_server --model " + ($VllmModel) + " --port 8000 --max-model-len " + ($VllmMaxContext)
        )
      )
    } else {
      $dockerStartCmd = @('python','-m','vllm.entrypoints.openai.api_server','--model', $VllmModel,'--port','8000','--max-model-len',"$VllmMaxContext")
    }
  }
  'open-webui' {
    $imageName = 'ghcr.io/open-webui/open-webui:main'
    $ports += '3000/http'
    if ($EnableSsh) {
      Write-Warning "EnableSsh is not supported for open-webui preset; use RunPod web shell/IDE or vllm-openai preset."
    }
  }
  default { throw "Unknown preset '$Preset'" }
}

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
  volumeMountPath = $VolumeMountPath
}
if ($dockerStartCmd.Count -gt 0) { $body['dockerStartCmd'] = $dockerStartCmd }
if ($allowedCuda.Count -gt 0) { $body['allowedCudaVersions'] = $allowedCuda }

if ([string]::IsNullOrWhiteSpace($NetworkVolumeId)) {
  $body['volumeInGb'] = $VolumeInGb
} else {
  $body['networkVolumeId'] = $NetworkVolumeId
}

$headers = @{ Authorization = "Bearer $RunpodApiKey"; 'Content-Type'='application/json' }
$resp = Invoke-RestMethod -Method Post -Uri 'https://rest.runpod.io/v1/pods' -Headers $headers -Body ($body | ConvertTo-Json -Depth 8)
$resp | ConvertTo-Json -Depth 8
