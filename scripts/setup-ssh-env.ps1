param(
  [switch]$Persist
)
$ErrorActionPreference = 'Stop'

$sshDir = Join-Path $HOME '.ssh'
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }

$priv = Join-Path $sshDir 'id_ed25519'
$pub  = Join-Path $sshDir 'id_ed25519.pub'

if (-not (Test-Path $priv) -or -not (Test-Path $pub)) {
  Write-Host "Generating ed25519 key..." -ForegroundColor Cyan
  ssh-keygen -t ed25519 -C "runpod-access" -f $priv -N '' | Out-Null
} else {
  Write-Host "Existing SSH key found at $priv" -ForegroundColor Green
}

$pubContent = Get-Content $pub -Raw
if ($Persist) {
  [System.Environment]::SetEnvironmentVariable('RUNPOD_SSH_PUBKEY', $pubContent, 'User')
  Write-Host "Set RUNPOD_SSH_PUBKEY in User environment." -ForegroundColor Green
} else {
  $env:RUNPOD_SSH_PUBKEY = $pubContent
  Write-Host "Exported RUNPOD_SSH_PUBKEY in current session." -ForegroundColor Green
}

Write-Host "Public key:" -ForegroundColor Yellow
Write-Host $pubContent
