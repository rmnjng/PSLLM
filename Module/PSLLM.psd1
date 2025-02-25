#
# Module manifest for module 'PSLLM'
#
# Generated on: 2025-02-21
#
 
@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PSLLM.psm1'
 
    # Version number of this module.
    ModuleVersion = '0.5.1'
 
    # Supported PSEditions
    # CompatiblePSEditions = @()
 
    # ID used to uniquely identify this module
    GUID = '7f6381a0-b5d8-4153-aec2-d6c4e4d33029'
 
    # Author of this module
    Author = 'rmnjng'
 
    # Company or vendor of this module
    # CompanyName = ''
 
    # Copyright statement for this module
    Copyright = 'Copyright © 2025 rmnjng. All rights reserved.'
 
    # Description of the functionality provided by this module
    Description = 'Powerful, secure, and free AI for every PowerShell workflow — running locally, with full control.'
 
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1.0.0'
 
    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''
 
    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''
 
    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = '4.6.2.0'
 
    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = '4.0.30319.42000'
 
    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = 'None'
 
    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()
 
    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()
 
    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()
 
    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()
 
    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()
 
    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()
 
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-PSLLMCompletion'
        'Enter-PSLLMConversation'
        'Get-PSLLMRAGContent'
        'Import-PSLLMConfig'
        'Save-PSLLMConfig'
        'Start-PSLLMServer'
        'Stop-PSLLMServer'
        'Install-PSLLMServer'
        'Uninstall-PSLLMServer'
        'Get-PSLLMHardwareInfo'
        'Test-PSLLMHealth'
        'Add-PSLLMThreadMessage'
        'Get-PSLLMThreadMessages'
        'Get-PSLLMThread'
        'Get-PSLLMThreads'
        'New-PSLLMThread'
        'Remove-PSLLMThread'
        'Add-PSLLMFile'
        'Get-PSLLMFileContent'
        'Get-PSLLMFiles'
        'Remove-PSLLMFile'
        'Get-PSLLMModel'
        'Get-PSLLMModels'
        'Start-PSLLMModel'
        'Stop-PSLLMModel'
        'Install-PSLLMModel'
        'Remove-PSLLMModel'
        'Get-PSLLMEngine'
        'Get-PSLLMEngineReleases'
        'Start-PSLLMEngine'
        'Update-PSLLMEngine'
        'Stop-PSLLMEngine'
        'Install-PSLLMEngine'
        'Uninstall-PSLLMEngine'
    )
 
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()
 
    # Variables to export from this module
    # VariablesToExport = ''
 
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()
 
    # DSC resources to export from this module
    # DscResourcesToExport = @()
 
    # List of all modules packaged with this module
    # ModuleList = @()
 
    # List of all files packaged with this module
    # FileList = @()
 
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
 
        PSData = @{
 
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = 'AI', 'LLM', 'Local-AI', 'Cortex', 'PowerShell-AI', 'Machine-Learning', 'NLP', 'Chatbot', 'Automation', 'RAG', 'Language-Model', 'Model-Management', 'AI-Server', 'PSLLM'
 
            # A URL to the license for this module.
            LicenseUri = 'https://github.com/rmnjng/PSLLM/blob/main/LICENSE'
 
            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/rmnjng/PSLLM'
 
            # A URL to an icon representing this module.
            IconUri = 'https://raw.githubusercontent.com/rmnjng/PSLLM/refs/heads/main/PSLLM.png'
 
            # ReleaseNotes of this module
            # ReleaseNotes = 'https://github.com/rmnjng/PSLLM/releases/latest'
 
            # Prerelease tag for PSGallery.
            # Prerelease = 'beta1'
 
        } # End of PSData hashtable
 
    } # End of PrivateData hashtable
 
    # HelpInfo URI of this module
    # HelpInfoURI = ''
 
    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
