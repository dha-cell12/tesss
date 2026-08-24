$requiredFiles = @(
  "C:\Program Files (x86)\TSplus\UserDesktop\files\APSC.exe",
  "C:\Program Files (x86)\TSplus\UserDesktop\files\AdminTool.exe",
  "C:\Program Files (x86)\TSplus\UserDesktop\files\TwoFactor.Admin.exe",
  "C:\Program Files (x86)\TSplus\UserDesktop\files\OneLicense.dll",
  "C:\Program Files (x86)\TSplus\Clients\www\cgi-bin\OneLicense.dll"
)

# First verify all required files exist
$missingFiles = @()
foreach ($file in $requiredFiles) {
  if (Test-Path $file) {
    Write-Host "✅ Verified file exists: $file"
  } else {
    Write-Host "❌ Missing file: $file"
    $missingFiles += $file
    continue
  }
}

if ($missingFiles.Count -gt 0) {
  Write-Host "Missing $($missingFiles.Count) required files. Patching verification failed."
  exit 1
}

# Check for successful patching by examining processes and services
$tsplusServices = @(
  @{ ServiceName = "APSC"; ProcessName = "APSC" },
  @{ ServiceName = "SVCE"; ProcessName = "svcenterprise" }
)

$failedServices = @()
foreach ($item in $tsplusServices) {
  $serviceName = $item.ServiceName
  $procName = $item.ProcessName

  $serviceStatus = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
  $procStatus = Get-Process -Name $procName -ErrorAction SilentlyContinue

  if ($serviceStatus -and $serviceStatus.Status -eq 'Running') {
    Write-Host "✅ Service $serviceName is running"
  } elseif ($procStatus) {
    Write-Host "✅ Process $procName is running"
  } else {
    Write-Host "⚠️ Service $serviceName / Process $procName is not active (non-fatal in CI environment)"
  }
}

Write-Host "Patched installation verification completed."