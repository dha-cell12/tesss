# Check for admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Error: This script requires Administrator privileges to start services." -ForegroundColor Red
    Write-Host "Please re-run this script as Administrator." -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting TSplus services..."

$services = @(
    @{Name = "SVCE"; Path = "C:\Program Files (x86)\TSplus\UserDesktop\files\svcenterprise.exe"},
    @{Name = "APSC"; Path = "C:\Program Files (x86)\TSplus\UserDesktop\files\APSC.exe"}
)

foreach ($service in $services) {
    $serviceName = $service.Name
    Write-Host "Checking service: $serviceName"
    
    try {
        $svc = Get-Service -Name $serviceName -ErrorAction Stop
        Write-Host "Found $serviceName service. Starting..."
        
        try {
            Start-Service -Name $serviceName -ErrorAction Stop
            Write-Host "Service $serviceName started successfully."
        } catch {
            Write-Host "Error starting service ${serviceName}: $($_.Exception.Message)" -ForegroundColor Red
        }
    } catch {
        Write-Host "Service $serviceName not found. Attempting to start process directly from $($service.Path)..." -ForegroundColor Yellow
        if (Test-Path $service.Path) {
            Start-Process -FilePath $service.Path -ErrorAction SilentlyContinue
            Write-Host "Started $($serviceName) process directly."
        } else {
            Write-Host "Executable $($service.Path) not found." -ForegroundColor Red
        }
    }
}

Write-Host "TSplus services processing completed." -ForegroundColor Green
