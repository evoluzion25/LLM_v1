param(
  [string]$Path = "./scripts/runpod.env"
)
if (-not (Test-Path $Path)) { throw "Env file not found: $Path" }
Get-Content -Path $Path | ForEach-Object {
  $line = $_.Trim()
  if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { return }
  $kv = $line -split '=',2
  if ($kv.Count -eq 2) {
    $key = $kv[0].Trim()
    $val = $kv[1]
    $env:$key = $val
  }
}
Write-Host "Environment variables loaded from $Path" -ForegroundColor Green
