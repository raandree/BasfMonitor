enum Status {
    OK
    Warning
    Error
    Critical
}

function Add-VariableToPSSession
{
    [CmdletBinding(
        SupportsShouldProcess = $false,
        ConfirmImpact = 'None'
    )]

    param
    ( 
        [Parameter(
            HelpMessage	= 'Provide the session(s) to load the functions into', 
            Mandatory	= $true,
            Position	= 0
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Runspaces.PSSession[]] 
        $Session,

        [Parameter( 
            HelpMessage = 'Provide the variable info to load into the session(s)', 
            Mandatory = $true, 
            Position = 1, 
            ValueFromPipeline	= $true 
        )]
        [ValidateNotNull()]
        [System.Management.Automation.PSVariable]
        $PSVariable
    )

    begin 
    {
        $cmdName = (Get-PSCallStack)[0].Command
        Write-Debug "[$cmdName] Entering function"

        $scriptBlock = 
        {
            param([string]$_AL_Path, [object]$Value)
            $null = Set-Item -Path Variable:\$_AL_Path -Value $Value
        }
    }

    process
    {
        if ($PSVariable.Name -eq 'PSBoundParameters')
        {
            Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList 'ALBoundParameters', $PSVariable.Value
        }
        else
        {
            Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $PSVariable.Name, $PSVariable.Value
        }
    }

    end
    {
        Write-Debug "[$cmdName] Exiting function"
    }
}

class MonitorRecord {
    [string]$ServerName
    [string]$Category
    [string]$Text    
    [Status]$Status
    [hashtable]$ExpectedValue
    [hashtable]$ActualValue
    [datetime]$Timestamp
}

function Import-Configuration {

    param (
        [Parameter()]
        [string]$Path = "$PSScriptRoot\Config",

        [switch]$PassThru
    )

    $script:config = @{}

    foreach ($file in Get-ChildItem -Path $Path -Filter *.yml) {
        $config = Get-Content -Path $file.FullName -Raw | ConvertFrom-Yaml
        $script:config.Add($file.BaseName, $config)
    }

    if ($PassThru) {
        $script:config
    }

}

function Get-Configuration {
    $script:config
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
            StartupType = $service.StartupType
        }

        $s = Get-Service $service.Name
        $result.ActualValue = @{
            Status      = $s.Status
            StartupType = $s.StartupType
        }

        if ($s.Status -eq $service.Status -and $s.StartupType -eq $service.StartupType) {
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
        $result = [MonitorRecord]::new()
        $result.ServerName = $env:COMPUTERNAME
        $result.Timestamp = Get-Date
        $result.Category = 'Disks'
        $result.Text = $disk.DriveLetter
        $result.ExpectedValue = @{
            FreeSpace      = $disk.FreeSpace
        }

        $d = Get-PSDrive -Name $disk.DriveLetter
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

function Start-Monitoring
{
    Invoke-Command -ComputerName $script:config.Keys -ScriptBlock {
        Import-Module Monitor
        $results = @()
        $results += Test-Service -Config $using:config
        $results += Test-Disk -Config $using:config
        $results
    }
}