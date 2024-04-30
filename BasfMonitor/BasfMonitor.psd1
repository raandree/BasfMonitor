@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'Monitor.psm1'

    # Version number of this module.
    ModuleVersion     = '0.0.1'

    # ID used to uniquely identify this module
    GUID              = '817d3559-e48d-432e-adee-4fd5ec67f9a5'

    # Author of this module
    Author            = 'Me'

    # Company or vendor of this module
    CompanyName       = 'BASF'

    # Copyright statement for this module
    Copyright         = '(c) ...'

    # Description of the functionality provided by this module
    Description       = 'Monitoring Demo'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules     = @('MonitorRules.psm1')

    # Functions to export from this module
    FunctionsToExport = @('*')
}
