param(
  [Parameter(Mandatory=$true)][string]$Path,
  [Parameter(Mandatory=$true)][string]$Bucket,
  [string]$Prefix='backup',
  [string]$Region='us-east-1',
  [string]$Endpoint,
  [string]$AccessKey=$env:AWS_ACCESS_KEY_ID,
  [string]$SecretKey=$env:AWS_SECRET_ACCESS_KEY
)

$ErrorActionPreference='Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { throw 'aws CLI not found. Install AWS CLI first.' }
if ([string]::IsNullOrWhiteSpace($AccessKey) -or [string]::IsNullOrWhiteSpace($SecretKey)) { throw 'Provide AWS credentials via params or env.' }

$env:AWS_ACCESS_KEY_ID = $AccessKey
$env:AWS_SECRET_ACCESS_KEY = $SecretKey
$env:AWS_DEFAULT_REGION = $Region

$endpointArgs = @()
if ($Endpoint) { $endpointArgs += @('--endpoint-url', $Endpoint) }

aws s3 sync $Path ("s3://{0}/{1}/" -f $Bucket, $Prefix) --delete @endpointArgs
