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

  $targetFile = "C:\Program Files (x86)\TSplus\UserDesktop\files\APSC.exe"

  while (-not $process.HasExited) {
    Start-Sleep -Seconds $checkIntervalSeconds
    $elapsedSeconds += $checkIntervalSeconds

    # Log running related child setup processes to identify what is waiting
    $runningChildren = Get-Process -Name "Setup-TSplus*", "setup-tasks*", "svcr*", "TSplus-Security*", "rundll32*" -ErrorAction SilentlyContinue
    if ($runningChildren) {
      $childInfo = ($runningChildren | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ", "
      Write-Host "Installation in progress... ($elapsedSeconds/$timeoutSeconds s). Active setup processes: $childInfo"
    } else {
      Write-Host "Installation in progress... ($elapsedSeconds/$timeoutSeconds s)."
    }

    # If key installation files are already present, check if primary setup completed or is waiting on background add-ons
    if (Test-Path $targetFile) {
      Write-Host "Target file APSC.exe detected at $targetFile!"
      # If main process exited or is waiting on secondary child tasks for > 60 seconds after files exist, break/clean up
      if ($elapsedSeconds -ge 180) {
        Write-Host "Required installation files exist and wait threshold reached. Terminating lingering installer tasks if any..."
        Get-Process -Name "Setup-TSplus*", "setup-tasks*", "svcr*", "TSplus-Security*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        break
      }
    }

    if ($elapsedSeconds -ge $timeoutSeconds) {
      Write-Warning "Installation timed out after $timeoutSeconds seconds"
      $process.Kill()
      Get-Process -Name "Setup-TSplus*", "setup-tasks*", "svcr*", "TSplus-Security*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      throw "Installation timed out after $timeoutSeconds seconds"
    }
  }
  
  if ($process.ExitCode -ne 0) {
    throw "Installation failed with exit code: $($process.ExitCode)"
  }
  
  Write-Host "TSplus installation completed successfully with exit code: $($process.ExitCode)"
}
catch {
  Write-Error "Error during installation: $_"
  exit 1
}