

function Add-VariableToPSSession {
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

    begin {
        $cmdName = (Get-PSCallStack)[0].Command
        Write-Debug "[$cmdName] Entering function"

        $scriptBlock = 
        {
            param([string]$_AL_Path, [object]$Value)
            $null = Set-Item -Path Variable:\$_AL_Path -Value $Value
        }
    }

    process {
        if ($PSVariable.Name -eq 'PSBoundParameters') {
            Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList 'ALBoundParameters', $PSVariable.Value
        }
        else {
            Invoke-Command -Session $Session -ScriptBlock $scriptBlock -ArgumentList $PSVariable.Name, $PSVariable.Value
        }
    }

    end {
        Write-Debug "[$cmdName] Exiting function"
    }
}



function Import-Configuration {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

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

function Start-Monitoring {
    [CmdletBinding()]
    param()

    $c = $script:config
    $computers = [string[]]$script:config.Keys
    Invoke-Command -ComputerName $computers -ScriptBlock {
        $computerName = $env:COMPUTERNAME
        $config = $using:c

        $results = @()
        if ($config."$computerName".Services) {
            $results += Test-Service -Config $config -Verbose
        }
        if ($config."$computerName".Disks) {
            $results += Test-Disk -Config $config -Verbose
        }
        $results

    } -ErrorVariable connectionErrors

    Write-Error "Failed to connect to '$($connectionErrors.TargetObject)'"

}