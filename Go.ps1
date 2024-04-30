ipmo .\Monitor.psm1 -Force
import-Configuration

Start-Monitoring
$result = @()
$result += Test-Service
$result += Test-Disk

$result