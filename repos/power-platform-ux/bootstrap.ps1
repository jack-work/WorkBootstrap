param(
  [string]$CloneDirectory
)

$popCount = 0
try
{
  # Change to the specified directory
  $cloneSrc = Join-Path $CloneDirectory
  Push-Location -Path $cloneSrc
  $popCount++
  Write-Output "Changed to directory: $cloneSrc"

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
