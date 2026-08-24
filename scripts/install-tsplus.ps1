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
  
  # Set silent flags for Inno Setup installer to avoid modal popups or prompt hangs
  $arguments = @(
    '/SP-',
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/NOCANCEL',
    '/CLOSEAPPLICATIONS',
    '/RESTARTAPPLICATIONS',
    '/Addons=yes'
  )
  
  Write-Host "Starting installation process with arguments: $($arguments -join ' ')"
  $process = Start-Process -FilePath $setupPath -ArgumentList $arguments -PassThru

  # Set timeout to 10 minutes (600 seconds)
  $timeoutSeconds = 600
  $elapsedSeconds = 0
  $checkIntervalSeconds = 10

  while (-not $process.HasExited) {
    Start-Sleep -Seconds $checkIntervalSeconds
    $elapsedSeconds += $checkIntervalSeconds

    if ($elapsedSeconds % 30 -eq 0) {
      Write-Host "Installation in progress... ($elapsedSeconds/$timeoutSeconds seconds elapsed)"
    }

    if ($elapsedSeconds -ge $timeoutSeconds) {
      Write-Warning "Installation timed out after $timeoutSeconds seconds"
      $process.Kill()
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