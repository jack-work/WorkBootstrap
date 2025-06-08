# Scoop Setup and Configuration Script
# Run this script in PowerShell with execution policy set appropriately

param(
  [string]$CloneDirectory = "$env:USERPROFILE\src",
  [switch]$SkipRepoClone = $false,
    
  # Step control parameters
  [switch]$InstallScoop = $false,
  [switch]$AddBuckets = $false,
  [switch]$InstallPackages = $false,
  [switch]$InstallLanguageServers = $false,
  [switch]$CloneRepos = $false,
  [switch]$LaunchUrls = $false,
  [switch]$All = $false,
    
  # Individual package control
  [string[]]$Packages = @(),
  [string[]]$LanguageServers = @(),
    
  # Display available options
  [switch]$ListSteps = $false,

  # Whether per-repo startup files will be run.  
  # An experimental feature.
  [switch]$RunRepoStartup = $false
)

# Global variable to store dependencies (loaded once)
$script:Dependencies = $null

# Color output functions
function Write-Success
{ param($Message) Write-Host $Message -ForegroundColor Green 
}
function Write-Info
{ param($Message) Write-Host $Message -ForegroundColor Cyan 
}
function Write-Warning
{ param($Message) Write-Host $Message -ForegroundColor Yellow 
}
function Write-Error
{ param($Message) Write-Host $Message -ForegroundColor Red 
}

# Load dependencies from JSON file (called only once)
function Initialize-Dependencies
{
  if ($script:Dependencies -ne $null)
  {
    return $script:Dependencies
  }
    
  $dependenciesFile = Join-Path $PSScriptRoot "dependencies.json"
    
  if (!(Test-Path $dependenciesFile))
  {
    Write-Error "dependencies.json not found. Please create this file with your package and repository configurations."
    return $null
  }
    
  try
  {
    $script:Dependencies = Get-Content $dependenciesFile | ConvertFrom-Json
    Write-Info "Dependencies loaded successfully from dependencies.json"
    return $script:Dependencies
  } catch
  {
    Write-Error "Failed to parse dependencies.json: $_"
    return $null
  }
}

# Get dependencies (returns cached version after first load)
function Get-Dependencies
{
  return $script:Dependencies
}

# Launch URLs for manual installation
function Start-ManualInstallation
{
  Write-Info "Launching URLs for manual installation..."
    
  $dependencies = Get-Dependencies
  if ($null -eq $dependencies)
  {
    Write-Error "Cannot launch URLs - dependencies.json not found or invalid"
    return
  }
    
  $urlsToLaunch = @()

  if ($dependencies.edgeExtensions)
  {
    $extensionUrls = $dependencies.edgeExtensions | Where-Object { $_.url } | Select-Object -ExpandProperty url
    if ($extensionUrls)
    {
      $urlsToLaunch += $extensionUrls
      Write-Info "Found $($extensionUrls.Count) Edge extension URLs"
    }
  }

  # Add any other URL collections from dependencies
  if ($dependencies.manualInstalls)
  {
    $manualUrls = $dependencies.manualInstalls | Where-Object { $_.url } | Select-Object -ExpandProperty url
    if ($manualUrls)
    {
      $urlsToLaunch += $manualUrls
      Write-Info "Found $($manualUrls.Count) manual installation URLs"
    }
  }
    
  if ($urlsToLaunch.Count -eq 0)
  {
    Write-Warning "No URLs found in dependencies.json for manual installation"
    return
  }
    
  Write-Info "Launching $($urlsToLaunch.Count) URLs for manual installation..."
  Write-Warning "Please install the required components manually. The script will continue running."
    
  foreach ($url in $urlsToLaunch)
  {
    try
    {
      Write-Info "Opening: $url"
      Start-Process $url
      Start-Sleep -Milliseconds 500  # Brief delay between launches
    } catch
    {
      Write-Warning "Could not launch URL $url`: $_"
    }
  }
    
  Write-Info "All URLs have been launched. Please complete manual installations as needed."
}

function Start-SetEnvironmentVars
{
  Write-Info "Launching URLs for manual installation..."
    
  $dependencies = Get-Dependencies
  if ($null -eq $dependencies)
  {
    Write-Error "Cannot launch URLs - dependencies.json not found or invalid"
    return
  }
  Write-Host "Please input a value for the following env vars, if you wish.  If blank, existing value will be respected." -AsSecureString
  foreach ($var in $dependencies.manualEnvVar)
  {
    $val = Read-Host " $($var):"
    if (-not [string]::IsNullOrWhiteSpace($val))
    {
      try
      {
        [Environment]::SetEnvironmentVariable($var, $val, [EnvironmentVariableTarget]::User)
        Write-Host "✓ Set environment variable: $var" -ForegroundColor Green
      } catch
      {
        Write-Error "Failed to set environment variable $var`: $_"
      }
    } else
    {
      Write-Host "Using existing value."
    }
  }
}

# Display available steps
function Show-AvailableSteps
{
  $dependencies = Get-Dependencies
  if ($null -eq $dependencies)
  {
    Write-Warning "Cannot display package lists - dependencies.json not found or invalid"
    return
  }
    
  Write-Info "Available Steps:"
  Write-Host "  -InstallScoop           Install Scoop package manager" -ForegroundColor White
  Write-Host "  -AddBuckets             Add Scoop buckets (extras, versions)" -ForegroundColor White
  Write-Host "  -InstallPackages        Install all Scoop packages" -ForegroundColor White
  Write-Host "  -InstallLanguageServers Install npm language servers" -ForegroundColor White
  Write-Host "  -CloneRepos             Clone repositories from dependencies.json" -ForegroundColor White
  Write-Host "  -LaunchUrls             Launch URLs for manual installation" -ForegroundColor White
  Write-Host "  -All                    Run all steps (except LaunchUrls)" -ForegroundColor White
  Write-Host ""
  Write-Info "Examples:"
  Write-Host "  .\setup-scoop.ps1 -InstallScoop -AddBuckets" -ForegroundColor Gray
  Write-Host "  .\setup-scoop.ps1 -InstallPackages -Packages 'git','fzf','python'" -ForegroundColor Gray
  Write-Host "  .\setup-scoop.ps1 -CloneRepos -CloneDirectory 'C:\MyProjects'" -ForegroundColor Gray
  Write-Host "  .\setup-scoop.ps1 -LaunchUrls" -ForegroundColor Gray
  Write-Host "  .\setup-scoop.ps1 -All" -ForegroundColor Gray
  Write-Host ""
    
  if ($dependencies.edgeExtensions -and $dependencies.edgeExtensions.Count -gt 0)
  {
    Write-Info "Available Edge Extensions (note that you will have to download these 'manually')"
    $extNames = $dependencies.edgeExtensions | ForEach-Object { $_.name }
    Write-Host "  $($extNames -join ', ')" -ForegroundColor Gray
    Write-Host ""
  }

  # Display available packages from dependencies.json
  if ($dependencies.scoopPackages -and $dependencies.scoopPackages.Count -gt 0)
  {
    Write-Info "Available Scoop Packages:"
    $packageNames = $dependencies.scoopPackages | ForEach-Object { $_.name }
    Write-Host "  $($packageNames -join ', ')" -ForegroundColor Gray
    Write-Host ""
  }
    
  if ($dependencies.npmPackages -and $dependencies.npmPackages.Count -gt 0)
  {
    Write-Info "Available NPM Packages:"
    $npmNames = $dependencies.npmPackages | ForEach-Object { $_.name }
    Write-Host "  $($npmNames -join ', ')" -ForegroundColor Gray
    Write-Host ""
  }
    
  if ($dependencies.repositories -and $dependencies.repositories.Count -gt 0)
  {
    Write-Info "Available Repositories:"
    $repoCount = $dependencies.repositories.Count
    Write-Host "  $repoCount repositories configured" -ForegroundColor Gray
    Write-Host ""
  }
    
  if ($dependencies.manualInstalls -and $dependencies.manualInstalls.Count -gt 0)
  {
    Write-Info "Available Manual Installations:"
    $manualCount = $dependencies.manualInstalls.Count
    Write-Host "  $manualCount manual installations configured" -ForegroundColor Gray
    Write-Host ""
  }
}

# Check if Scoop is installed
function Test-ScoopInstalled
{
  try
  {
    $null = Get-Command scoop -ErrorAction Stop
    return $true
  } catch
  {
    return $false
  }
}

# Install Scoop if not present
function Install-Scoop
{
  Write-Info "Installing Scoop..."
    
  if (Test-ScoopInstalled)
  {
    Write-Success "Scoop is already installed. Version: $(scoop --version)"
    return
  }
    
  # Set execution policy if needed
  try
  {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Success "Execution policy set to RemoteSigned for CurrentUser"
  } catch
  {
    Write-Warning "Could not set execution policy: $_"
  }
    
  # Install Scoop
  try
  {
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    Write-Success "Scoop installed successfully!"
  } catch
  {
    Write-Error "Failed to install Scoop: $_"
    exit 1
  }
}

# Add Scoop buckets
function Add-ScoopBuckets
{
  Write-Info "Adding Scoop buckets..."
    
  $dependencies = Get-Dependencies
  if ($null -eq $dependencies)
  {
    Write-Error "Cannot add buckets - dependencies not loaded"
    return
  }
    
  # Extract unique buckets from scoopPackages
  $buckets = @('extras', 'versions')  # Default buckets
  if ($dependencies.scoopPackages)
  {
    $configuredBuckets = $dependencies.scoopPackages | Where-Object { $_.bucket -and $_.bucket -ne 'main' } | Select-Object -ExpandProperty bucket -Unique
    $buckets = ($buckets + $configuredBuckets) | Select-Object -Unique
  }
    
  foreach ($bucket in $buckets)
  {
    try
    {
      # Check if bucket is already added
      $existingBuckets = scoop bucket list 2>$null
      if ($existingBuckets -and $existingBuckets -contains $bucket)
      {
        Write-Info "Bucket '$bucket' is already added"
      } else
      {
        scoop bucket add $bucket
        Write-Success "Added bucket: $bucket"
      }
    } catch
    {
      Write-Warning "Could not add bucket $bucket`: $_"
    }
  }
}

# Install packages via Scoop
function Install-ScoopPackages
{
  param([string[]]$PackageFilter = @())
    
  Write-Info "Installing Scoop packages..."
    
  $dependencies = Get-Dependencies
  if ($null -eq $dependencies -or $null -eq $dependencies.scoopPackages)
  {
    Write-Error "Cannot install packages - no scoopPackages found in dependencies"
    return
  }
    
  # Filter packages if specified
  if ($PackageFilter.Count -gt 0)
  {
    $packages = $dependencies.scoopPackages | Where-Object { $_.name -in $PackageFilter }
    if ($packages.Count -eq 0)
    {
      $availablePackages = $dependencies.scoopPackages | Select-Object -ExpandProperty name
      Write-Warning "No matching packages found. Available packages: $($availablePackages -join ', ')"
      return
    }
  } else
  {
    $packages = $dependencies.scoopPackages
  }
    
  foreach ($package in $packages)
  {
    try
    {
      $packageName = $package.name
      $bucket = if ($package.bucket -and $package.bucket -ne 'main')
      { $package.bucket 
      } else
      { $null 
      }
            
      # Create full package identifier if bucket is specified
      $fullPackageName = if ($bucket)
      { "$bucket/$packageName" 
      } else
      { $packageName 
      }
            
      # Check if already installed
      $installed = scoop list $packageName 2>$null
      if ($installed)
      {
        Write-Info "$packageName is already installed"
        scoop update $packageName
      } else
      {
        Write-Info "Installing $packageName$(if ($bucket) { " from $bucket bucket" })..."
        if ($package.description)
        {
          Write-Info "  Description: $($package.description)"
        }
        scoop install $fullPackageName
        Write-Success "Installed $packageName"
      }
            
      # Execute post-install script if exists
      $scriptPath = Join-Path $PSScriptRoot "$packageName.ps1"
      if (Test-Path $scriptPath)
      {
        try
        {
          & $scriptPath
          Write-Success "Successfully executed post-install script for $packageName"
        } catch
        {
          Write-Error "Failed to execute post-install script for $packageName`: $_"
        }
      }
    } catch
    {
      Write-Warning "Could not install $($package.name): $_"
    }
  }
}

function Install-Winget
{
  $dependencies = Get-Dependencies
  if ($null -eq $dependencies -or $null -eq $dependencies.wingetPackages)
  {
    Write-Error "Cannot install packages - no wingetPackages found in dependencies"
    return
  }
  foreach ($package in $dependencies.wingetPackages)
  {
    try
    {
      winget install $package
    } catch
    {
      Write-Warning "Could not install $($package.name): $_"
    }
  }
}

# Install additional language servers via npm (after Node.js is installed)
function Install-LanguageServers
{
  param([string[]]$LanguageServerFilter = @())
    
  Write-Info "Installing npm packages..."
    
  $dependencies = Get-Dependencies
  if ($null -eq $dependencies -or $null -eq $dependencies.npmPackages)
  {
    Write-Warning "No npmPackages found in dependencies"
    return
  }
    
  # Check if npm is available
  try
  {
    $null = Get-Command npm -ErrorAction Stop
  } catch
  {
    Write-Error "npm is not available. Please install Node.js first."
    return
  }
    
  # Filter packages if specified
  if ($LanguageServerFilter.Count -gt 0)
  {
    $npmPackages = $dependencies.npmPackages | Where-Object { $_.name -in $LanguageServerFilter }
    if ($npmPackages.Count -eq 0)
    {
      $availablePackages = $dependencies.npmPackages | Select-Object -ExpandProperty name
      Write-Warning "No matching npm packages found. Available: $($availablePackages -join ', ')"
      return
    }
  } else
  {
    $npmPackages = $dependencies.npmPackages
  }
    
  foreach ($npmPackage in $npmPackages)
  {
    try
    {
      $packageName = $npmPackage.name
      $installGlobally = if ($npmPackage.global -ne $null)
      { $npmPackage.global 
      } else
      { $true 
      }
            
      # Check if package is already installed
      if ($installGlobally)
      {
        $installedPackages = npm list -g --depth=0 --json 2>$null | ConvertFrom-Json
        $isInstalled = $installedPackages.dependencies.$packageName
        $installCommand = "npm install -g $packageName"
        $updateCommand = "npm update -g $packageName"
      } else
      {
        # For local packages, we'll assume they need to be installed each time
        $isInstalled = $false
        $installCommand = "npm install $packageName"
        $updateCommand = "npm update $packageName"
      }
            
      if ($isInstalled)
      {
        Write-Info "$packageName is already installed$(if ($installGlobally) { ' globally' })"
        Write-Info "Checking for updates to $packageName..."
        Invoke-Expression $updateCommand
      } else
      {
        Write-Info "Installing $packageName$(if ($installGlobally) { ' globally' })..."
        if ($npmPackage.description)
        {
          Write-Info "  Description: $($npmPackage.description)"
        }
        Invoke-Expression $installCommand
        Write-Success "Installed $packageName"
      }
    } catch
    {
      Write-Warning "Could not install $($npmPackage.name): $_"
    }
  }
}

# Clone GitHub repositories
function Clone-GitRepositories
{
  param(
    [string]$CloneDir,
    [bool]$RunStartup=$false
  )
    
  if ($SkipRepoClone)
  {
    Write-Info "Skipping repository cloning as requested"
    return
  }

  Write-Info "Cloning repositories..."

  $dependencies = Get-Dependencies
  if ($null -eq $dependencies -or $null -eq $dependencies.repositories)
  {
    Write-Warning "No repositories found in dependencies"
    return
  }
    
  if ($dependencies.repositories.Count -eq 0)
  {
    Write-Warning "No repositories defined in dependencies"
    return
  }
    
  Write-Info "Cloning repositories from dependencies..."
    
  foreach ($repo in $dependencies.repositories)
  {
    try
    {
      # Use specified destination or default to CloneDir
      $destinationPath = if ($repo.destination)
      { 
        Resolve-Path ([System.Environment]::ExpandEnvironmentVariables($repo.destination))
      } else
      { 
        $CloneDir 
      }
            
      $repoName = Split-Path $repo.url -Leaf -Resolve:$false
      $repoName = $repoName -replace '\.git$', ''
      $targetPath = if ($repo.notCreateChildDir)
      {
        $destinationPath
      } else
      {
        Join-Path $destinationPath $repoName
      }

      # Create destination directory if it doesn't exist
      if (!(Test-Path $targetPath))
      {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        Write-Success "Created directory: $destinationPath"
        Write-Info "Cloning $($repo.url) to $destinationPath..."
        if ($repo.description)
        {
          Write-Info "  Description: $($repo.description)"
        }
        git clone $repo.url $targetPath
        Write-Success "Cloned $repoName"
      } else
      {
        Write-Info "Path for repository $repoName already exists at $targetPath, pulling latest changes..."
        Push-Location $targetPath
        git pull
        Pop-Location
      }

      if ($RunStartup)
      {
        Invoke-RunStartup $repoName $targetPath
      }
    } catch
    {
      Write-Warning "Could not clone $($repo.url): $_"
    }
  }
}

function Invoke-RunStartup
{
  param(
    [string]$repoName,
    [string] $clonePath)

  $repoFile = Join-Path $PSScriptRoot "repos" $repoName "bootstrap.ps1"
  Write-Host "Repo file: $repoFile"
  if (Test-Path $repoFile)
  {
    Write-Host "Init file found in repos directory.  Running on-start: $repoFile."
    & $repoFile  -CloneDirectory $clonePath
  }
}

# Main execution
function Main
{
  # Initialize dependencies once at the start
  $null = Initialize-Dependencies
  if ($null -eq $script:Dependencies)
  {
    Write-Error "Failed to load dependencies. Exiting."
    return
  }
    
  # Show help if requested
  if ($ListSteps)
  {
    Show-AvailableSteps
    return
  }
    
  # Check if any step was specified
  $stepsSpecified = $InstallScoop -or $AddBuckets -or $InstallPackages -or $InstallLanguageServers -or $CloneRepos -or $LaunchUrls -or $All
    
  if (-not $stepsSpecified)
  {
    Write-Warning "No steps specified. Use -ListSteps to see available options or -All to run everything."
    Show-AvailableSteps
    return
  }
    
  Write-Info "Starting Scoop setup and configuration..."
  Write-Info "Script parameters: CloneDirectory=$CloneDirectory"
    
  # Run LaunchUrls if specified (can be run independently or with other steps)
  if ($All -or $LaunchUrls)
  {
    Start-ManualInstallation
  }
    
  if ($All -or $SetEnvironmentVars)
  {
    Start-SetEnvironmentVars
  }

  # Run specified steps
  if ($All -or $InstallScoop)
  {
    Install-Scoop
  }
    
  if ($All -or $AddBuckets)
  {
    Add-ScoopBuckets
  }
    
  if ($All -or $InstallPackages)
  {
    Install-ScoopPackages -PackageFilter $Packages
    Install-Winget
  }
    
  if ($All -or $InstallLanguageServers)
  {
    Install-LanguageServers -LanguageServerFilter $LanguageServers
  }
    
  if ($All -or $CloneRepos)
  {
    Clone-GitRepositories -CloneDir $CloneDirectory -RunStartup $RunRepoStartup
  }
    
  Write-Success "Completed requested steps!"
}

# Run the main function
Main
