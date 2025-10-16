param(
  [string]$RunpodApiKey,
  [Parameter(Mandatory=$true)][string]$Name,
  [Parameter(Mandatory=$true)][int]$SizeInGb,
  [string]$DataCenterId
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RunpodApiKey)) { $RunpodApiKey = $env:RUNPOD_API_KEY }
if ([string]::IsNullOrWhiteSpace($RunpodApiKey)) { $RunpodApiKey = [Environment]::GetEnvironmentVariable('RUNPOD_API_KEY','User') }
if ([string]::IsNullOrWhiteSpace($RunpodApiKey)) { throw 'RUNPOD_API_KEY not found.' }

$vars = @{ name = $Name; sizeInGb = $SizeInGb }
if ($DataCenterId) { $vars.dataCenterId = $DataCenterId }

$headers = @{ Authorization = 'Bearer ' + $RunpodApiKey; 'Content-Type' = 'application/json' }
$uri = 'https://api.runpod.io/graphql'
function Invoke-Gql([string]$query, $variables) { $bodyObj = @{ query=$query; variables=$variables }; $body=$bodyObj|ConvertTo-Json -Depth 10; Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $body }

$tries = @(
  @{ name='createNetworkVolume'; q='mutation($name:String!,$sizeInGb:Int!,$dataCenterId:String){ createNetworkVolume(input:{ name:$name, sizeInGb:$sizeInGb, dataCenterId:$dataCenterId }) { id name sizeInGb } }' },
  @{ name='networkVolumeCreate'; q='mutation($name:String!,$sizeInGb:Int!,$dataCenterId:String){ networkVolumeCreate(input:{ name:$name, sizeInGb:$sizeInGb, dataCenterId:$dataCenterId }) { id name sizeInGb } }' },
  @{ name='volumeCreate'; q='mutation($name:String!,$sizeInGb:Int!,$dataCenterId:String){ volumeCreate(input:{ name:$name, sizeInGb:$sizeInGb, dataCenterId:$dataCenterId }) { id name sizeInGb } }' }
)

$created=$null
foreach($t in $tries){
  try{
    Write-Host "Attempting mutation: $($t.name)"
    $resp = Invoke-Gql -query $t.q -variables $vars
    if ($resp.errors){ throw ($resp.errors|ConvertTo-Json -Depth 10) }
    $data = $resp.data[$t.name]
    if($data){ $created=$data; break }
  }catch{ Write-Warning "Mutation $($t.name) failed: $($_.Exception.Message)" }
}

if($created){
  Write-Host 'NETWORK_VOLUME_CREATED_BEGIN'
  $created | ConvertTo-Json -Depth 10
  Write-Host 'NETWORK_VOLUME_CREATED_END'
  exit 0
}

Write-Warning 'Could not create network volume via known mutations.'
Write-Host 'Fallback: In RunPod console → Storage → Network Volumes → Create. Then copy the ID here and set:'
Write-Host '$env:RUNPOD_NETWORK_VOLUME_ID = "<ID>"'
exit 1
