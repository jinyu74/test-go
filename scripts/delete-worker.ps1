Param(
  [Parameter(Mandatory = $true)]
  [string]$Name,
  [switch]$Force,
  [switch]$SkipWork
)

& "$PSScriptRoot/delete-app.ps1" -Name $Name -Force:$Force -SkipWork:$SkipWork
