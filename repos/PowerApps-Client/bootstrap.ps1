param(
  [string]$CloneDirectory
)

$popCount = 0
try
{
  $azModules = Get-InstalledModule Az
  if (0 -eq $azModules.Length)
  {
    Write-Host "Az module not installed.  Handling that now."
    Install-Module -Name Az -Force -AllowClobber -Scope CurrentUser
  } else
  {
    Write-Host "Az module found probably boss.  Check out Get-InstalledModule Az for more details."
  }

  Import-Module Az.KeyVault

  # Check if directory exists
  if (-not (Test-Path -Path $CloneDirectory -PathType Container))
  {
    throw "Directory '$CloneDirectory' does not exist."
  }

  # Change to the specified directory
  $cloneSrc = Join-Path $CloneDirectory "src"
  Push-Location -Path $cloneSrc
  $popCount++
  Write-Output "Changed to directory: $cloneSrc"

  & .\SetupDevEnvironment.ps1 -RefreshCerts
    
} catch
{
  Write-Error "Error occurred: $_"
  exit 1
} finally
{
  # Ensure we return to the original directory even if an error occurs
  foreach ($i in 0..$popCount)
  {
    Pop-Location
  }
}
