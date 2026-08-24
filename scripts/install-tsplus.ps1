Write-Host "Installing TSplus..."
try {
  # Get the setup file path from the environment variable
  $setupPath = $env:TSPLUS_SETUP_PATH
  
  if (-not $setupPath -or -not (Test-Path $setupPath)) {
    Write-Error "Setup file not found. Please make sure the download script ran successfully."
    Write-Host "Expected path: $setupPath"
    Write-Host "Current directory: $(Get-Location)"
    exit 1
  }
  
  Write-Host "Using setup file: $setupPath"
  
  # Kill any existing TSplus setup or child processes that might interfere
  $setupProcesses = Get-Process -Name "Setup-TSplus*", "setup-tasks*", "svcr*", "TSplus-Security*" -ErrorAction SilentlyContinue
  foreach ($p in $setupProcesses) {
    Write-Host "Stopping existing process $($p.ProcessName) (PID: $($p.Id))..."
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  }

  # Set silent flags for Inno Setup installer
  $arguments = @(
    '/SP-',
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/NOCANCEL',
    '/CLOSEAPPLICATIONS',
    '/RESTARTAPPLICATIONS',
    '/Addons=no'
  )

  Write-Host "Starting installation process with arguments: $($arguments -join ' ')"
  $process = Start-Process -FilePath $setupPath -ArgumentList $arguments -PassThru

  # Set timeout to 10 minutes (600 seconds)
  $timeoutSeconds = 600
  $elapsedSeconds = 0
  $checkIntervalSeconds = 10

  $requiredFiles = @(
    "C:\Program Files (x86)\TSplus\UserDesktop\files\APSC.exe",
    "C:\Program Files (x86)\TSplus\UserDesktop\files\AdminTool.exe",
    "C:\Program Files (x86)\TSplus\UserDesktop\files\TwoFactor.Admin.exe",
    "C:\Program Files (x86)\TSplus\UserDesktop\files\OneLicense.dll",
    "C:\Program Files (x86)\TSplus\Clients\www\cgi-bin\OneLicense.dll"
  )

  $allFilesPresent = $false

  while (-not $process.HasExited) {
    Start-Sleep -Seconds $checkIntervalSeconds
    $elapsedSeconds += $checkIntervalSeconds

    # Check if all required files are present
    $missingCount = 0
    foreach ($file in $requiredFiles) {
      if (-not (Test-Path $file)) {
        $missingCount++
      }
    }

    if ($missingCount -eq 0) {
      Write-Host "All required TSplus installation files verified on disk!"
      $allFilesPresent = $true
      # Stop lingering processes (e.g. TSplus-Security, rundll32, setup-tasks) that prevent main setup exit
      Write-Host "Terminating lingering setup background processes..."
      Get-Process -Name "Setup-TSplus*", "setup-tasks*", "svcr*", "TSplus-Security*", "rundll32*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      break
    }

    # Log running child setup processes for diagnostics
    $runningChildren = Get-Process -Name "Setup-TSplus*", "setup-tasks*", "svcr*", "TSplus-Security*", "rundll32*" -ErrorAction SilentlyContinue
    if ($runningChildren) {
      $childInfo = ($runningChildren | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ", "
      Write-Host "Installation in progress... ($elapsedSeconds/$timeoutSeconds s). Active processes: $childInfo (Missing files: $missingCount)"
    } else {
      Write-Host "Installation in progress... ($elapsedSeconds/$timeoutSeconds s). (Missing files: $missingCount)"
    }

    if ($elapsedSeconds -ge $timeoutSeconds) {
      Write-Warning "Installation timed out after $timeoutSeconds seconds"
      $process.Kill()
      Get-Process -Name "Setup-TSplus*", "setup-tasks*", "svcr*", "TSplus-Security*", "rundll32*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      throw "Installation timed out after $timeoutSeconds seconds"
    }
  }

  if (-not $allFilesPresent -and $process.ExitCode -ne 0) {
    throw "Installation failed with exit code: $($process.ExitCode)"
  }
  
  Write-Host "TSplus installation completed successfully."
}
catch {
  Write-Error "Error during installation: $_"
  exit 1
}