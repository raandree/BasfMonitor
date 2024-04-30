enum Status {
    OK
    Warning
    Error
    Critical
}

class MonitorRecord {
    [string]$ServerName
    [string]$Category
    [string]$Text    
    [Status]$Status
    [hashtable]$ExpectedValue
    [hashtable]$ActualValue
    [datetime]$Timestamp
    [string]$Error
}

function Test-Service {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    $computerName = $env:COMPUTERNAME

    foreach ($service in $Config."$computerName".Services) {
        $result = [MonitorRecord]::new()
        $result.ServerName = $env:COMPUTERNAME
        $result.Timestamp = Get-Date
        $result.Category = 'Service'
        $result.Text = $service.Name
        $result.ExpectedValue = @{
            Status      = $service.Status
            StartType = $service.StartType
        }

        $s = Get-Service $service.Name
        $result.ActualValue = @{
            Status      = $s.Status
            StartType = $s.StartType
        }

        if ($s.Status -eq $service.Status -and $s.StartType -eq $service.StartType) {
            $result.Status = [Status]::OK
        } else {
            $result.Status = [Status]::Critical
        }

        $result

    }

}

function Test-Disk {

    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    $computerName = $env:COMPUTERNAME

    foreach ($disk in $Config."$computerName".Disks) {
        Write-Verbose "Working on Disk '$($disk.DriveLetter)'"
        $result = [MonitorRecord]::new()
        $result.ServerName = $env:COMPUTERNAME
        $result.Timestamp = Get-Date
        $result.Category = 'Disks'
        $result.Text = $disk.DriveLetter
        $result.ExpectedValue = @{
            FreeSpace      = $disk.FreeSpace
        }

        $d = Get-PSDrive -Name $disk.DriveLetter -ErrorAction SilentlyContinue

        if ($null -eq $d)
        {
            $result.Error = "The drive '$($disk.DriveLetter)' does not exist"
            $result.Status = [Status]::Error
            $result
            continue
        }

        $result.ActualValue = @{
            FreeSpace      = $d.Free
            TotalSpace = $d.Used + $d.Free
        }

        if ($disk.FreeSpace.EndsWith('%')) {
            $percent = $disk.FreeSpace.TrimEnd('%')
            $percentageFree = $d.Free / $result.ActualValue.TotalSpace * 100
            if ($percentageFree -le $percent) {
                $result.Status = [Status]::Critical
            } else {
                $result.Status = [Status]::OK
            }
        }
        elseif ($disk.FreeSpace.EndsWith('GB')) {
            [long]$requiredGb = $disk.FreeSpace.TrimEnd('GB')
            $requiredGb = $requiredGb * 1GB
            if ($d.Free -le $requiredGb) {
                $result.Status = [Status]::Critical
            } else {
                $result.Status = [Status]::OK
            }
        }

        $result

    }

}
