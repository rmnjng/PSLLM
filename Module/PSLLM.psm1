<# PSLLM.psm1

PSLLM - PowerShell Local Language Model

PSLLM is a PowerShell module for managing and interacting with a locally hosted Large Language Model (LLM) using the Cortex server.
It provides functions for AI-driven text generation, conversation management, Retrieval-Augmented Generation (RAG), and local model operations.

Key Features:
- AI Completion & Conversations: Generate AI responses and manage chat threads.
- Configuration & Server Control: Install, start, stop, and configure the LLM server.
- Model & Engine Management: Install, start, stop, and retrieve model and engine details.
- File & RAG Integration: Upload and retrieve files for AI-augmented searches.

This module enables seamless AI-powered automation within PowerShell while keeping data local.

Keywords: AI, LLM, Local AI, Cortex, PowerShell AI, Machine Learning, NLP, Chatbot, Automation, RAG, Language Model, Model Management, AI Server, PSLLM
#>

# Throw if this psm1 file isn't being imported via the manifest.
if (!([System.Environment]::StackTrace.Split("`n") -like '*Microsoft.PowerShell.Commands.ModuleCmdletBase.LoadModuleManifest(*'))
{
    throw [System.Management.Automation.ErrorRecord]::new(
        [System.InvalidOperationException]::new("This module must be imported via its .psd1 file, which is recommended for all modules that supply a .psd1 file."),
        'ModuleImportError',
        [System.Management.Automation.ErrorCategory]::InvalidOperation,
        $MyInvocation.MyCommand.ScriptBlock.Module
    )
}

<#-------------------------------------------------------------------------------------
MAIN FUNCTIONS

- Get-PSLLMCompletion         : Retrieves an AI-generated response using a local model via the Cortex server.
- Enter-PSLLMConversation     : Continues or starts a conversation (thread) with a local Large Language Model (LLM).
- Get-PSLLMRAGContent         : Retrieves relevant content from RAG (Retrieval-Augmented Generation) storage based on input text.
------------------------------------------------------------------------------#>#region

function Get-PSLLMCompletion {
    <#
    .SYNOPSIS
    Retrieves an AI-generated response from a local language model via the Cortex server.

    .DESCRIPTION
    This advanced function interacts with a local AI model through the Cortex server's chat completion endpoint.
    It supports flexible message input methods:
    - Single message with system context
    - Multiple message thread conversations
    - Customizable model parameters
    - Synchronous and asynchronous processing modes
    - Optional detailed response metadata

    Key Capabilities:
    - Supports both single message and multi-message conversation contexts
    - Configurable model parameters (temperature, max tokens)
    - Async processing with file or window output
    - Detailed response tracking and logging

    .PARAMETER Message
    A single user message to send to the language model. Used when not providing a full message thread.

    .PARAMETER Messages
    An array of message objects representing a conversation thread. Allows for more complex conversational contexts.

    .PARAMETER ModelName
    Specifies the AI model to use. Defaults to the model configured in the system settings.

    .PARAMETER EngineName
    Optional. Specifies a particular engine for model processing.

    .PARAMETER Assistant
    Defines the system role or persona for the AI. Defaults to a helpful assistant persona.

    .PARAMETER MaxTokens
    Maximum number of tokens in the AI's response. Controls response length. Default is 2048.

    .PARAMETER Temperature
    Controls response randomness (0.0-1.0):
    - 0.0: Deterministic, focused responses
    - 1.0: Maximum creativity and variation
    Default is 0.8.

    .PARAMETER TopP
    Controls token selection probability. Influences response diversity.
    Lower values make responses more focused, higher values increase variability.
    Default is 0.95.

    .PARAMETER Detailed
    When specified, returns comprehensive metadata about the response instead of just the text.

    .PARAMETER Async
    Enables asynchronous processing of the request.

    .PARAMETER AsyncType
    Specifies async output method: "File", "Window", or "Both".

    .PARAMETER DataDirectory
    Directory for storing async results. Defaults to %LOCALAPPDATA%\PSLLM.

    .PARAMETER StoreFile
    If set, saves the response to a JSON file in the DataDirectory.

    .PARAMETER Config
    Configuration object containing system settings.

    .EXAMPLE
    # Basic usage with a simple question
    Get-PSLLMCompletion -Message "What is the capital of France?"

    .EXAMPLE
    # Retrieve detailed response metadata
    Get-PSLLMCompletion -Message "Explain quantum computing" -Detailed

    .EXAMPLE
    # Async processing with window display
    Get-PSLLMCompletion -Message "Generate a Python script" -Async -AsyncType Window

    .EXAMPLE
    # Complex conversation thread
    $thread = @(
        @{ role = "user"; content = "Explain machine learning" },
        @{ role = "assistant"; content = "Machine learning is..." }
    )
    Get-PSLLMCompletion -Messages $thread -Temperature 0.7

    .OUTPUTS
    System.String or System.Collections.Hashtable
    - Returns AI response text by default
    - Returns detailed metadata hashtable when -Detailed switch is used

    .NOTES
    - Requires properly configured Cortex server and LLM environment
    - Supports extensive customization of AI interaction
    - Comprehensive logging of interactions
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Variable is used after Measure-Command')]
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $false,
            Position = 0,
            HelpMessage = "Message to send to the LLM.",
            ValueFromPipeline = $true
        )]
        [string]$Message,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Message array to send to the LLM."
        )]
        $Messages,

        [Parameter(Mandatory = $false)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        [string]$EngineName,

        [Parameter(Mandatory = $false)]
        [string]$Assistant = "You are a helpful assistant.",

        [Parameter(Mandatory = $false)]
        [int]$MaxTokens = 2048,

        [Parameter(Mandatory = $false)]
        [single]$Temperature = 0.8,

        [Parameter(Mandatory = $false)]
        [single]$TopP = 0.95,

        [Parameter(Mandatory = $false)]
        [switch]$Detailed,

        [Parameter(Mandatory = $false)]
        [switch]$Async,

        [Parameter(Mandatory = $false)]
        [ValidateSet("File", "Window", "Both")]
        [string]$AsyncType = "File",

        [Parameter(Mandatory = $false)]
        [string]$DataDirectory = "$($env:localappdata)\PSLLM",

        [Parameter(Mandatory = $false)]
        [switch]$StoreFile,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if (-not $PSBoundParameters.ContainsKey('Message') -and -not $PSBoundParameters.ContainsKey('Messages')) {
                throw "You must provide either a -Message or a -Messages parameter."
            }
            if (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $config.ModelName
            }
            if (-not $PSBoundParameters.ContainsKey('EngineName')) {
                $EngineName = $config.EngineName
            }
            Write-PSLLMLog -Line "Starting chat completion request." -Function $MyInvocation.MyCommand -Config $Config

            if ($PSBoundParameters.ContainsKey('Messages')) {
                Write-PSLLMLog -Line "Building message part from thread." -Function $MyInvocation.MyCommand -Config $Config
                $Messages= @($Messages)
                $Messages += @{
                    role    = "system"
                    content = $Assistant
                }
                $messagePart = $Messages
            } else {
                Write-PSLLMLog -Line "Building message part from single message." -Function $MyInvocation.MyCommand -Config $Config
                $Message = Add-PSLLMStringEscapes -String $Message
                $messagePart = @(
                    @{
                        role    = "system"
                        content = $Assistant
                    },
                    @{
                        role    = "user"
                        content = $Message
                    }
                )
            }
            $Assistant = Add-PSLLMStringEscapes -String $Assistant

            $endPoint = "v1/chat/completions"
            $uri = "$($config.BaseUri)/$endPoint"
            $body = @{
                messages           = $messagePart            
                model              = $ModelName
                stream             = $false
                max_tokens         = $MaxTokens
                frequency_penalty  = 0
                presence_penalty   = 0
                temperature        = $Temperature
                top_p              = $TopP
            } | ConvertTo-Json

            if ($Async) {
                Write-PSLLMLog -Line "Processing async request with type: $AsyncType." -Function $MyInvocation.MyCommand -Config $Config            
                Start-PSLLMServer -Config $Config -ModelName $ModelName -EngineName $EngineName -ModelNeeded $true
                Invoke-PSLLMAsyncRequest -Uri $uri -Body $body -AsyncType $AsyncType -DataDirectory $DataDirectory
                Write-Output "Asynchronous request sent. You can now continue working."
                return $null
            } else {
                Write-PSLLMLog -Line "Sending request to model '$ModelName'." -Function $MyInvocation.MyCommand -Config $Config 
                $askingTime = (Get-Date)
            
                $measure = Measure-Command {
                    $response = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -ModelName $ModelName -ModelNeeded $true -EngineName $EngineName -Config $Config
                }

                if ($null -ne $response) {
                    if ($Detailed) {
                        $answer = @{
                            Response       = $response.choices[0].message.content
                            Assistant      = $Assistant
                            Prompt         = $Message
                            Duration       = $($measure.TotalSeconds)
                            PromptTokens   = $($response.usage.prompt_tokens)
                            ResponseTokens = $($response.usage.completion_tokens)
                            TotalTokens    = $($response.usage.total_tokens)
                            Model          = $ModelName
                            AskingTime     = $askingTime
                        }
                        Write-PSLLMLog -Line "AI response: $($answer.Response)" -Function $MyInvocation.MyCommand -Config $Config
                    } 
                    else {
                        $answer = $response.choices[0].message.content
                        Write-PSLLMLog -Line "AI response: $answer" -Function $MyInvocation.MyCommand -Config $Config
                    }
                    if ($StoreFile) {
                        $answer | ConvertTo-Json -Depth 5 |  Out-File -FilePath "$DataDirectory\PSLLM_Answer_$($askingTime).json" -Force
                    }
                    return $answer
                } 
                else {
                    throw "The server returned a null response."
                }
            }
        }
        catch {
            $errorMessage = "Failed to get AI response: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity Error -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Enter-PSLLMConversation {
    <#
    .SYNOPSIS
    Continues or starts a conversation (thread) with a local Language Model (LLM).

    .DESCRIPTION
    The Enter-PSLLMConversation function allows you to interact with a local language model by sending a message and receiving a response. 
    It manages conversation threads, creating a new thread if one doesn't exist or adding to an existing thread with the specified title.

    Key features:
    - Automatically creates a new thread if the specified title doesn't exist
    - Adds user message to the thread
    - Generates an AI response using the specified or default model
    - Adds the AI response back to the thread
    - Supports customization of model parameters like temperature and max tokens

    .PARAMETER Message
    The user input message for which the AI model will generate a response. This is a mandatory parameter.

    .PARAMETER ThreadName
    The name of the conversation to create or add to. This helps in organizing and tracking multiple conversations.

    .PARAMETER ModelName
    Optional. The name of the AI model to use for generating responses. If not specified, uses the model from the configuration.

    .PARAMETER Assistant
    Optional. The initial system role or persona that defines the AI's behavior. Defaults to "You are a helpful assistant."

    .PARAMETER MaxTokens
    Optional. Maximum number of tokens in the AI's response. Defaults to 2048. Controls the length of the generated response.

    .PARAMETER Temperature
    Optional. Controls the randomness of the AI's response. Range is 0.0-1.0. 
    - Lower values (closer to 0) make the output more focused and deterministic
    - Higher values (closer to 1) make the output more creative and varied
    Defaults to 0.8.

    .PARAMETER TopP
    Optional. Controls the cumulative probability cutoff for token selection. 
    - Helps in controlling the diversity of the generated text
    - Defaults to 0.95

    .PARAMETER Config
    Optional. The configuration object containing settings for the LLM interaction. 
    If not provided, the function will import the default configuration.

    .EXAMPLE
    # Start a new conversation about Python programming
    Enter-PSLLMConversation -Message "Explain list comprehensions in Python" -ThreadName "Python Basics"

    .EXAMPLE
    # Continue an existing conversation with more context
    Enter-PSLLMConversation -Message "Can you provide an example of a list comprehension?" -ThreadName "Python Basics" -Temperature 0.5

    .EXAMPLE
    # Use a specific model with custom settings
    Enter-PSLLMConversation -Message "Write a short poem about technology" -ThreadName "Creative Writing" -ModelName "mistral:7b-gguf" -MaxTokens 2048 -Temperature 0.9

    .OUTPUTS
    System.Object[]
    Returns an array of message objects representing the entire conversation thread, 
    which includes both user and AI messages in chronological order.

    Each message object typically contains properties such as:
    - id: Unique identifier for the message
    - role: Either 'user' or 'assistant'
    - content: The text of the message
    - timestamp: When the message was created

    .NOTES
    - Requires a properly configured LLM environment
    - Handles thread creation and management automatically
    - Logs interactions for tracking and debugging
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            HelpMessage = "Message to send to the LLM.",
            ValueFromPipeline = $true
        )]
        [string]$Message,

        [Parameter(
            Mandatory = $true,
            HelpMessage = "Name of the conversation."
        )]
        [string]$ThreadName,

        [Parameter(Mandatory = $false)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        [string]$Assistant = "You are a helpful assistant.",

        [Parameter(Mandatory = $false)]
        [int]$MaxTokens = 2048,

        [Parameter(Mandatory = $false)]
        [single]$Temperature = 0.8,

        [Parameter(Mandatory = $false)]
        [single]$TopP = 0.95,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $config.ModelName
            }

            Write-PSLLMLog -Line "Retrieving thread with name: '$ThreadName'" -Function $MyInvocation.MyCommand -Config $Config
        
            $threads = Get-PSLLMThreads -Config $Config
            $thread = $threads | Where-Object { $_.metadata.title -eq $ThreadName } | Select-Object -First 1
        
            if (-not $thread) {
                Write-PSLLMLog -Line "No such thread, creating it." -Function $MyInvocation.MyCommand -Config $Config
                $thread = New-PSLLMThread -ThreadName $ThreadName -Config $Config
            }
            if ($thread) {
                Write-PSLLMLog -Line "Adding new message and getting all messages." -Function $MyInvocation.MyCommand -Config $Config
                $null = Add-PSLLMThreadMessage -ThreadId $thread.id -Message $Message -Config $Config
                $Messages = Get-PSLLMThreadMessages -ThreadId $thread.id -Config $Config
                Write-PSLLMLog -Line "Getting and storing answer." -Function $MyInvocation.MyCommand -Config $Config
                $aiAnswer = Get-PSLLMCompletion -Messages $Messages -ModelName $ModelName -Assistant $Assistant -MaxTokens $MaxTokens -Temperature $Temperature -TopP $TopP -Config $Config
                $null = Add-PSLLMThreadMessage -ThreadId $thread.id -Message $aiAnswer -Config $Config -Role assistant
                $Messages = Get-PSLLMThreadMessages -ThreadId $thread.id -Config $Config
                $Messages = return $Messages
            }
        }
        catch {
            $errorMessage = "Failed to continue thread: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Get-PSLLMRAGContent {
    <#
    .SYNOPSIS
    Retrieves relevant content from RAG (Retrieval-Augmented Generation) storage based on input text.

    .DESCRIPTION
    Uses embeddings to find and retrieve the most semantically similar content from previously stored RAG data.
    Calculates cosine similarity between the input text and stored embeddings to identify the most relevant content.

    .PARAMETER Text
    The input text to find similar content for.

    .PARAMETER RAGGroup
    The RAG group to search in. Defaults to "Default".

    .PARAMETER ModelName
    Optional. The name of the model to use. If not specified, uses the model from configuration.

    .PARAMETER EngineName
    Optional. The name of the engine to use. If not specified, uses the engine from configuration.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMRAGContent -Text "How do I create a new virtual machine?"
    Retrieves content most similar to the question about virtual machines.

    .EXAMPLE
    Get-PSLLMRAGContent -Text "What is Azure Storage?" -RAGGroup "AzureDocs"
    Searches for content about Azure Storage in the AzureDocs RAG group.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Text,
        
        [Parameter(Mandatory = $false)]
        [string]$RAGGroup = "Default",
        
        [Parameter(Mandatory = $false)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        [string]$EngineName,
        
        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $config.ModelName
            }
            if (-not $PSBoundParameters.ContainsKey('EngineName')) {
                $EngineName = $config.EngineName
            }
            $queryEmbedding = Get-PSLLMEmbedding -Text $Text -ModelName $ModelName -Config $Config
        
            $ragDir = "$env:LOCALAPPDATA\PSLLM\RAG"
            $ragFilePath = Join-Path $ragDir "$($RAGGroup).json"
        
            if (Test-Path -Path $ragFilePath) {
                $existingContent = Get-Content -Path $ragFilePath -Raw | ConvertFrom-Json
                $RAGGroupEmbeddings = $existingContent.Embeddings
                Write-PSLLMLog -Line "Retrieved $($RAGGroupEmbeddings.Count) embeddings." -Function $MyInvocation.MyCommand -Config $Config
                $partSize = $existingContent.PartSize
                Write-PSLLMLog -Line "Part size: '$partSize'." -Function $MyInvocation.MyCommand -Config $Config
            } else {
                Throw "RAG group '$RAGGroup' does not exist. Upload a file first with 'Add-PSLLMFile'."
            }

            $highestSimilarity = 0
            $selectedEmbedding = ''

            Write-PSLLMLog -Line "Comparing cosine similarity." -Function $MyInvocation.MyCommand -Config $Config
        
            foreach ($embedding in $RAGGroupEmbeddings){
                # Ensure vectors are the same length
                if ($embedding.Embedding.Length -ne $queryEmbedding.Length){
                    throw "Vectors must have the same length (RAG: $($embedding.Embedding.Length) / Query: $($queryEmbedding.Length))."
                }

                # Calculate dot product
                $dotProduct = 0
                for ($i = 0; $i -lt $queryEmbedding.Length; $i++) {
                    $dotProduct += $queryEmbedding[$i] * $embedding.Embedding[$i]
                }

                # Calculate magnitudes
                $queryEmbeddingM = $queryEmbedding | ForEach-Object { $_ * $_ } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                $embedding.Embedding = $embedding.Embedding | ForEach-Object { $_ * $_ } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                $magnitudeQ = [math]::Sqrt($queryEmbeddingM)
                $magnitudeE = [math]::Sqrt($embedding.Embedding)

                # Calculate cosine similarity
                if ($magnitudeQ -eq 0 -or $magnitudeE -eq 0) {
                    $similarity = 0
                } else {
                    $similarity = $dotProduct / ($magnitudeQ * $magnitudeE)
                }

                if ($similarity -gt $highestSimilarity) {
                    $highestSimilarity = $similarity
                    $selectedEmbedding = $embedding
                }
            }
            Write-PSLLMLog -Line "Highest similarity: $([math]::round($highestSimilarity,3)) / Part: $($selectedEmbedding.Part)." -Function $MyInvocation.MyCommand -Config $Config
        
            if ($selectedEmbedding) {
                Write-PSLLMLog -Line "Retrieving file content." -Function $MyInvocation.MyCommand -Config $Config
                $fileContent = Get-PSLLMFileContent -FileId $selectedEmbedding.FileID -Config $Config
                if ($fileContent.length -gt $PartSize){
                    $chunks = Split-PSLLMStringIntoChunks -String $fileContent -MaxSize $PartSize
                    Write-PSLLMLog -Line "Retrievied $($chunks.count) parts." -Function $MyInvocation.MyCommand -Config $Config
                    $retrievedRAG = $chunks[$selectedEmbedding.Part]
                } else {
                    $retrievedRAG = $fileContent
                }
            } else {
                Write-PSLLMLog -Line "No similar embedding retrieved." -Function $MyInvocation.MyCommand -Config $Config -Severity Warning
            }
            return $retrievedRAG
        }
        catch {
            $errorMessage = "Failed to retrieve RAG content: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

#endregion
<#-------------------------------------------------------------------------------------
CONFIG MANAGEMENT

- Import-PSLLMConfig          : Imports the PSLLM configurations.
- Save-PSLLMConfig            : Saves the PSLLM configurations.
------------------------------------------------------------------------------#>#region

function Import-PSLLMConfig {
    <#
    .SYNOPSIS
    Imports the PSLLM configurations.

    .DESCRIPTION
    Imports the PSLLM configurations from a JSON file in the local AppData directory.

    .EXAMPLE
    Import-PSLLMConfig
    #>

    # Load or create config
    $configPath = Join-Path $env:LOCALAPPDATA 'PSLLM\PSLLM.config'
    
    if (Test-Path $configPath) {
        $config = Get-Content -Path $configPath | ConvertFrom-Json     
        Write-PSLLMLog -Line "Config loaded." -Function $MyInvocation.MyCommand -Config $config
    } else {
        $config = @{
            EngineName = 'llama-cpp'
            ModelName  = 'mistral:7b-gguf'
            Logging    = $false
            BaseUri    = 'http://127.0.0.1:39281'
        }
        
        Write-PSLLMLog -Line "Default config created." -Function $MyInvocation.MyCommand -Config $config
    }
    return $config
}

function Save-PSLLMConfig {
    <#
    .SYNOPSIS
    Saves the PSLLM configurations.

    .DESCRIPTION
    Saves the PSLLM configurations to a JSON file in the local AppData directory.

    .PARAMETER EngineName
    The name of the engine to use.

    .PARAMETER ModelName
    The name of the model to use.

    .PARAMETER Logging
    Whether verbose outputs are logged to a file.

    .PARAMETER BaseUri
    Base URI of the Cortex server. Defaults to "http://127.0.0.1:39281".

    .EXAMPLE
    Save-PSLLMConfig -EngineName "llama-cpp" -ModelName "mistral:7b-gguf" -Logging $true
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ModelName,
        
        [Parameter()]
        [bool]$Logging,

        [Parameter(Mandatory = $false)]
        [string]$BaseUri = "http://127.0.0.1:39281"
    )

    try {
        $config = Import-PSLLMConfig -Logging $Logging
        
        # Use existing config values if parameters not specified
        if (-not $PSBoundParameters.ContainsKey('EngineName')) {
            $EngineName = $config.EngineName
        }
        if (-not $PSBoundParameters.ContainsKey('ModelName')) {
            $ModelName = $config.ModelName
        }
        if (-not $PSBoundParameters.ContainsKey('Logging')) {
            $Logging = $config.Logging
        }
        if (-not $PSBoundParameters.ContainsKey('BaseUri')) {
            $BaseUri = $config.BaseUri
        }

        Write-PSLLMLog -Line "Starting to save config." -Function $MyInvocation.MyCommand -Config $config
        
        # Ensure config directory exists
        $configDir = Join-Path $env:LOCALAPPDATA 'PSLLM'
        if (-not (Test-Path -Path $configDir)) {
            $null = New-Item -Path $configDir -ItemType Directory
            Write-PSLLMLog -Line "Created directory: '$configDir'." -Function $MyInvocation.MyCommand -Config $config
        }

        # Create and save config
        $configPath = Join-Path $configDir 'PSLLM.config'
        $newConfig = @{
            EngineName = $EngineName
            ModelName  = $ModelName
            Logging    = $Logging
            BaseUri    = $BaseUri
        }

        Write-PSLLMLog -Line "Saving config: EngineName = '$EngineName', ModelName = '$ModelName', Logging = '$Logging', BaseUri = '$BaseUri'" -Function $MyInvocation.MyCommand -Config $config

        $newConfig | ConvertTo-Json | Set-Content -Path $configPath -Force

        Write-PSLLMLog -Line "Config saved successfully." -Function $MyInvocation.MyCommand -Config $config

        Write-Output "Config saved! Use new settings with 'Start-PSLLMServer -Restart'."
    }
    catch {
        $errorMessage = "Failed to save config: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $config        
        Write-Warning $errorMessage
        return $false
    }
}

#endregion
<#-------------------------------------------------------------------------------------
SERVER MANAGEMENT

- Start-PSLLMServer           : Starts the local LLM server with specified engine and model.
- Stop-PSLLMServer            : Stops the local LLM server process.
- Install-PSLLMServer         : Installs the Cortex server for local LLM operations.
- Uninstall-PSLLMServer       : Removes the Cortex application from the system.
- Get-PSLLMHardwareInfo       : Retrieves hardware information from the local LLM server.
- Test-PSLLMHealth            : Tests the health status of the local LLM server.
------------------------------------------------------------------------------#>#region

function Start-PSLLMServer {
    <#
    .SYNOPSIS
    Starts the local LLM server with specified engine and model.

    .DESCRIPTION
    Initializes and starts the local LLM server, installing components if necessary.
    This function will:
    1. Install the server if not present
    2. Start the server process if not running
    3. Install and start the specified engine
    4. Install and start the specified model

    .PARAMETER EngineName
    The name of the engine to use. Must be one of: 'llama-cpp', 'onnxruntime', or 'tensorrt-llm'.
    If not specified, uses the engine from configuration.

    .PARAMETER ModelName
    The name of the model to load. If not specified, uses the model from configuration.

    .PARAMETER ModelNeeded
    Determines if only server needs to be started, or model needs to be loaded. Defaults to server only.

    .PARAMETER Restart
    Not only start but first stop the server.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Start-PSLLMServer
    # Starts server with default engine and model from config

    .EXAMPLE
    Start-PSLLMServer -EngineName "llama-cpp" -ModelName "mistral:7b-gguf"
    # Starts server with specific engine and model

    .OUTPUTS
    None
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "Name of the engine to use"
        )]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Name of the model to load"
        )]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        [bool]$ModelNeeded = $false,

        [Parameter(Mandatory = $false)]
        [switch]$Restart,

        [Parameter(Mandatory = $false)]
        $Config
    )
    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        if (-not $PSBoundParameters.ContainsKey('EngineName')) {
            $EngineName = $Config.EngineName
        }
        if (-not $PSBoundParameters.ContainsKey('ModelName')) {
            $ModelName = $Config.ModelName
        }

        if ($VerbosePreference -eq "SilentlyContinue") {
            $isVerbose = $false
        } else {
            $isVerbose = $true
        }
        if ($Restart) {
            Write-PSLLMLog -Line "Restarting LLM server." -Function $MyInvocation.MyCommand -Config $Config
            $stopResult = Stop-PSLLMServer -Config $Config
            if (-not $stopResult) {
                Throw "Failed to stop server."
            }
        }

        Write-PSLLMLog -Line "Starting LLM server with engine '$EngineName' and model '$ModelName'." -Function $MyInvocation.MyCommand -Config $Config

        # Check and install server
        $executable = "$env:localappdata\cortexcpp\cortex.exe"
        if (-not (Test-Path -Path $executable)) {
            $installOK = Install-PSLLMServer -Config $Config
            if (-not $installOK) {
                throw "Server installation failed."
            }
        }

        # Start server process if not running
        $cortexServer = Get-Process cortex-server -ErrorAction SilentlyContinue
        if (-not $cortexServer) {
            Write-PSLLMLog -Line "Starting server process." -Function $MyInvocation.MyCommand -Config $Config

            $null = Start-Process -FilePath $executable -ArgumentList "start" -WindowStyle Hidden
            Start-Sleep -Seconds 2
            
            Write-PSLLMLog -Line "Server process started." -Function $MyInvocation.MyCommand -Config $Config
        }

        # Install and start engine
        Write-PSLLMLog -Line "Checking engine status." -Function $MyInvocation.MyCommand -Config $Config

        $engineResponse = & $executable "engines" "list"
        $engines = @()
        $newCortexRelease = ""
        $newEngineVersion = ""

        foreach ($line in $engineResponse){
            if (($line -like "|*") -and ($line -notlike "| #*")) {
                $engines += $line.Split('|')[2].trim()
            } elseif ($line -like "New Cortex release*") {
                $newCortexRelease = $line
            } elseif ($line -match "^New .+ version available:.*$") {
                $newEngineVersion = $line
            }
        }

        if ($newCortexRelease -ne ""){
            # There is a Cortex update available, update
            Write-PSLLMLog -Line "$newCortexRelease -> updating" -Function $MyInvocation.MyCommand -Config $Config
            $stopResult = Stop-PSLLMServer -Config $Config
            if ($isVerbose) { $VerbosePreference = 'SilentlyContinue' }
            try {
                $cortexUpdateResponse = & $executable "update" 2>&1 | Where-Object { $_ -notmatch 'NativeCommandError' }
            } catch { $null }
            if ($isVerbose) { $VerbosePreference = 'Continue' }
            if ("Updated cortex successfully" -in $cortexUpdateResponse) {
                Write-PSLLMLog -Line "Cortex successfully updated." -Function $MyInvocation.MyCommand -Config $Config
            } else {
                Throw $cortexUpdateResponse
            }
        }
        
        if ($EngineName -in $engines){
            Write-PSLLMLog -Line "Engine $EngineName already available." -Function $MyInvocation.MyCommand -Config $Config
        } else {
            # Download engine
            if ($isVerbose) { $VerbosePreference = 'SilentlyContinue' }
            $engineInstallResponse = & $executable "engines" "install" "$EngineName"
            if ($isVerbose) { $VerbosePreference = 'Continue' }
            if ($engineInstallResponse[-1] -like "*downloaded successfully!"){
                Write-PSLLMLog -Line "Engine $EngineName successfully downloaded." -Function $MyInvocation.MyCommand -Config $Config                
            } else {
                Throw "Failed to download engine $($EngineName): $engineInstallResponse"
            }
        }

        if ($newEngineVersion -ne ""){
            # There is an engine update available, update
            Write-PSLLMLog -Line "$newEngineVersion -> updating" -Function $MyInvocation.MyCommand -Config $Config
            $engineUpdate = Update-PSLLMEngine -EngineName $EngineName -Config $Config
            if ($engineUpdate){
                Write-PSLLMLog -Line "Engine $EngineName is now up to date." -Function $MyInvocation.MyCommand -Config $Config
            } else {
                Throw "Engine $EngineName could not be updated."
            }
        }

        if (-not (Test-Path "$env:localappdata\cortexcpp\engine.dll")){
            Write-PSLLMLog -Line "engine.dll not present, copying now." -Function $MyInvocation.MyCommand -Config $Config
            $srcPath = "$env:USERPROFILE\cortexcpp\engines"
            $relPath = Get-ChildItem $srcPath -Recurse -Name "engine.dll"
            Copy-Item -Path "$srcPath\$relPath" -Destination "$env:localappdata\cortexcpp\" -Force
            Write-PSLLMLog -Line "engine.dll copied to '$env:localappdata\cortexcpp\'." -Function $MyInvocation.MyCommand -Config $Config
        }
        if ($ModelNeeded) {
            $model = Get-PSLLMModel -ModelName $ModelName -Config $Config
        
            if ($model) {
                Write-PSLLMLog -Line "Model $ModelName already available." -Function $MyInvocation.MyCommand -Config $Config
            } else {
                # Download model
                Write-PSLLMLog -Line "Starting to download model '$ModelName'." -Function $MyInvocation.MyCommand -Config $Config
                $modelDownloadResponse = Install-PSLLMModel -ModelName $ModelName -Config $Config

                if ($modelDownloadResponse) {
                    Write-PSLLMLog -Line "Model $ModelName successfully downloaded." -Function $MyInvocation.MyCommand -Config $Config 
                } else {
                    Throw "Model download failed."
                }
            }

            $cortexResponse = & $executable "ps"
            $models = @()

            foreach ($line in $cortexResponse){
                if (($line -like "|*") -and ($line -notlike "| Model*")) {
                    $models += $line.Split('|')[1].trim()
                } 
            }

            if ($ModelName -in $models){
                Write-PSLLMLog -Line "Model $ModelName already running." -Function $MyInvocation.MyCommand -Config $Config
            } else {
                $endPoint = "v1/models/start"
                $body = @{ model = $ModelName } | ConvertTo-Json -Depth 2
                $response = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -ModelName $ModelName -Config $Config

                if ($response.message -eq "Started successfully!"){
                    Write-PSLLMLog -Line "Started model '$ModelName' successfully." -Function $MyInvocation.MyCommand -Config $Config
                } else {
                    Throw $response.message
                }
            }
        } else {
            Write-PSLLMLog -Line "Started server successfully." -Function $MyInvocation.MyCommand -Config $Config
        }
    } catch {
        $errorMessage = "Failed to start server: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

function Stop-PSLLMServer {
    <#
    .SYNOPSIS
    Stops the local LLM server process.

    .DESCRIPTION
    Sends a request to gracefully stop the local LLM server process.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Stop-PSLLMServer
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        $Config
    )

    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        Write-PSLLMLog -Line "Stopping LLM server process." -Function $MyInvocation.MyCommand -Config $Config

        if(Get-Process jan -ErrorAction SilentlyContinue){
            Throw "You cannot kill Cortex while 'Jan' (GUI) is running."
        }
        if(Get-Process cortex-server -ErrorAction SilentlyContinue){     
            Get-Process cortex-server | Stop-Process -Force
            Write-PSLLMLog -Line "Stopped LLM server process." -Function $MyInvocation.MyCommand -Config $Config
            Start-Sleep -Seconds 2
        } else {
            Write-PSLLMLog -Line "Cortex server not running." -Function $MyInvocation.MyCommand -Config $Config
        }
        if(Get-Process cortex -ErrorAction SilentlyContinue){     
            Get-Process cortex | Stop-Process -Force
            Write-PSLLMLog -Line "Stopped cortex process." -Function $MyInvocation.MyCommand -Config $Config
            Start-Sleep -Seconds 2
        } else {
            Write-PSLLMLog -Line "Cortex not running." -Function $MyInvocation.MyCommand -Config $Config
        }

        return $true
    }
    catch {
        $errorMessage = "Failed to stop LLM server process: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

function Install-PSLLMServer {
    <#
    .SYNOPSIS
    Installs the Cortex server for local LLM operations.

    .DESCRIPTION
    Downloads and installs the Cortex server application required for running local LLM operations.
    This function handles the complete installation process including:
    - Checking for existing installation
    - Downloading the installer (~1.8 GB)
    - Running the installation
    - Verifying the installation

    .PARAMETER Force
    If specified, skips confirmation prompts and proceeds with download and installation.
    Use this for automated installations.

    .PARAMETER DownloadUri
    The address from where to download the latest Cortex Windows installer.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Install-PSLLMServer
    # Interactively installs the server with confirmation prompts

    .EXAMPLE
    Install-PSLLMServer -Force
    # Installs the server without confirmation prompts

    .EXAMPLE
    Install-PSLLMServer -Verbose
    # Installs the server with detailed progress information

    .OUTPUTS
    System.Boolean
    Returns $true if installation is successful, $false otherwise
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "Skip confirmation prompts"
        )]
        [switch]$Force,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "The actual Cortex download URL."
        )]
        [string]$DownloadUri = 'https://app.cortexcpp.com/download/latest/windows-amd64-local',

        [Parameter(Mandatory = $false)]
        $Config
    )

    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        Write-PSLLMLog -Line "Starting Cortex server installation." -Function $MyInvocation.MyCommand -Config $Config

        $executable = "$env:localappdata\cortexcpp\cortex.exe"
        $installerPath = "$env:TEMP\cortexinstaller.exe"

        # Check existing installation
        if (Test-Path -Path $executable) {
            Write-PSLLMLog -Line "Cortex already installed." -Function $MyInvocation.MyCommand -Config $Config
            return $true
        }

        # Check for existing installer
        if (Test-Path -Path $installerPath) {
            Write-PSLLMLog -Line "Running existing installer." -Function $MyInvocation.MyCommand -Config $Config
        }
        else {
            # Handle download confirmation
            if (-not $Force) {
                $confirmation = Read-Host -Prompt "Need to download the Cortex installer (~1.8 GB). Proceed? (yes/no)"
                if ($confirmation -notmatch '^(y|yes)$') {
                    throw "Installation cancelled by user."
                }
            }

            # Download installer
            Write-PSLLMLog -Line "Starting installer download." -Function $MyInvocation.MyCommand -Config $Config

            try {
                Start-BitsTransfer -Source $DownloadUri -Destination $installerPath                
                Write-PSLLMLog -Line "Download completed successfully." -Function $MyInvocation.MyCommand -Config $Config
            }
            catch {
                throw "Failed to download installer: $($_.Exception.Message)"
            }
        }

        # Run installation
        Write-PSLLMLog -Line "Starting installation process." -Function $MyInvocation.MyCommand -Config $Config

        $result = Start-Process -FilePath $installerPath -ArgumentList "/SP- /VERYSILENT /SUPPRESSMSGBOXES" -Wait -PassThru
        
        if ($result.ExitCode -eq 0) {
            Write-PSLLMLog -Line "Installation completed successfully." -Function $MyInvocation.MyCommand -Config $Config
            return $true
        }
        else {
            throw "Exit code: $($result.ExitCode)"
        }
    }
    catch {
        $errorMessage = "Installation failed: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

function Uninstall-PSLLMServer {
    <#
    .SYNOPSIS
    Removes the Cortex application from the system.

    .DESCRIPTION
    Uninstalls the Cortex server and optionally deletes its associated data directory. 
    The function identifies the uninstaller in the application directory and executes it silently. 

    If specified, the data directory is also deleted to ensure a clean uninstallation.

    .PARAMETER Force
    Skips confirmation prompts and directly executes the uninstallation.

    .PARAMETER DeleteData
    Removes the data directory after uninstallation.

    .PARAMETER DataDirectory
    Specifies the path to the data directory. Defaults to `%LOCALAPPDATA%\PSLLM`.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Uninstall-PSLLMServer -DeleteData
    # Uninstalls the Cortex server and deletes its data directory.

    .NOTES
    This function ensures no residual data or configurations are left behind.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts.")]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$DeleteData,

        [Parameter(Mandatory = $false)]
        [string]$DataDirectory = "$($env:localappdata)\PSLLM",

        [Parameter(Mandatory = $false)]
        $Config
    )

    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        
        $cortexDir = "$env:localappdata\cortexcpp"
        $uninstallerPath = "$cortexDir\unins000.exe"
        $executable = "$cortexDir\cortex.exe"
        
        if (Test-Path -Path $executable) {
            Write-PSLLMLog -Line "Starting Cortex server uninstallation." -Function $MyInvocation.MyCommand -Config $Config
            $stopResult = Stop-PSLLMServer -Config $Config
            if (-not $stopResult){
                Throw "Failed to stop Cortex server."
            }
            if (!(Test-Path -Path $uninstallerPath)) {
                throw "Uninstaller not found at $uninstallerPath."
            }
            Start-Process -FilePath $uninstallerPath -ArgumentList "/SILENT" -Wait
            Write-PSLLMLog -Line "Cortex server uninstallation successful." -Function $MyInvocation.MyCommand -Config $Config 

        } else {
            Write-PSLLMLog -Line "Cortex not found." -Function $MyInvocation.MyCommand -Config $Config
        }

        if (Test-Path $cortexDir) {
            $null = Remove-Item -Path $cortexDir -Recurse -Force
        }
        
        if (($DeleteData.IsPresent) -and (Test-Path $DataDirectory)) {
            Start-Sleep -Seconds 1
            $null = Remove-Item -Path "$DataDirectory" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Output "Data deleted."
        }
        Write-Output "Cortex uninstalled. Reinstall with 'Start-PSLLMServer'."
    }
    catch {
        $errorMessage = "Uninstallation failed: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

function Get-PSLLMHardwareInfo {
    <#
    .SYNOPSIS
    Retrieves hardware information from the local LLM server.

    .DESCRIPTION
    Gets information about the hardware configuration and capabilities of the local LLM server.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMHardwareInfo
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Config
    )

    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        Write-PSLLMLog -Line "Retrieving hardware information." -Function $MyInvocation.MyCommand -Config $Config

        $endPoint = "v1/hardware"

        $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -Config $Config
        
        Write-PSLLMLog -Line "Hardware information retrieved successfully." -Function $MyInvocation.MyCommand -Config $Config
        
        return $response
    }
    catch {
        $errorMessage = "Failed to retrieve hardware information: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

function Test-PSLLMHealth {
    <#
    .SYNOPSIS
    Tests the health status of the local LLM server.

    .DESCRIPTION
    Performs a health check on the local LLM server by making a request to the health endpoint.
    This function will return the server's health status and can be used to verify connectivity
    and server readiness.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Test-PSLLMHealth
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Config
    )

    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        Write-PSLLMLog -Line "Starting health check." -Function $MyInvocation.MyCommand -Config $Config

        $endPoint = "healthz"

        $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -Config $Config
            
        Write-PSLLMLog -Line "Health check completed successfully." -Function $MyInvocation.MyCommand -Config $Config
            
        return $response
    }
    catch {
        $errorMessage = "Health check failed: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

#endregion
<#-------------------------------------------------------------------------------------
THREAD MANAGEMENT

- Add-PSLLMThreadMessage      : Adds a message to a chat thread.
- Get-PSLLMThreadMessages     : Retrieves messages from a chat thread.
- Get-PSLLMThread             : Retrieves a specific chat thread by title.
- Get-PSLLMThreads            : Retrieves all chat threads from the local LLM server.
- New-PSLLMThread             : Creates a new chat thread.
- Remove-PSLLMThread          : Removes a chat thread from the local LLM server.
------------------------------------------------------------------------------#>#region

function Add-PSLLMThreadMessage {
    <#
    .SYNOPSIS
    Adds a message to a chat thread.

    .DESCRIPTION
    Adds a new message to a specified chat thread using either its ID or title.
    Can optionally create the thread if it doesn't exist.

    .PARAMETER Thread
    The whole thread to add the message to.

    .PARAMETER ThreadId
    The ID of the thread to add the message to.

    .PARAMETER ThreadName
    The title of the thread to add the message to.

    .PARAMETER Message
    The content of the message to add.

    .PARAMETER Role
    The role of the message sender. Can be either "system", "user" or "assistant".

    .PARAMETER CreateThreadIfNotExists
    If specified, creates a new thread with the given name if it doesn't exist.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Add-PSLLMThreadMessage -ThreadId "thread-123456" -Message "Hello!"

    .EXAMPLE
    Add-PSLLMThreadMessage -ThreadName "My Chat" -Message "Hi there" -CreateThreadIfNotExists
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Thread,
        
        [Parameter(Mandatory = $false)]
        [string]$ThreadId,
        
        [Parameter(Mandatory = $false)]
        [string]$ThreadName,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("user", "assistant")]
        [string]$Role = "user",
        
        [Parameter(Mandatory = $false)]
        [switch]$CreateThreadIfNotExists,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if ($PSBoundParameters.ContainsKey('Thread')) {
                $ThreadId = $Thread.id
            } elseif ($PSBoundParameters.ContainsKey('ThreadName')){
                $Thread = Get-PSLLMThread -ThreadName $ThreadName -Config $Config
                if (-not $Thread -and $CreateThreadIfNotExists) {
                    Write-PSLLMLog -Line "Creating new thread with title '$ThreadName'" -Function $MyInvocation.MyCommand -Config $Config
                    $Thread = New-PSLLMThread -ThreadName $ThreadName -Config $Config
                }
                elseif (-not $Thread) {
                    Throw "Thread with name '$ThreadName' not found."
                }
                $ThreadId = $Thread.id
            } elseif (-not $PSBoundParameters.ContainsKey('ThreadId')) {
                Throw "Pass a 'Thread', 'ThreadId' or 'ThreadName' to the function."
            }
            Write-PSLLMLog -Line "Adding message to thread with id '$ThreadId'." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/threads/$ThreadId/messages"
            $body = @{
                role = $Role
                content = $Message
            } | ConvertTo-Json

            Write-PSLLMLog -Line "Sending message to: $endPoint" -Function $MyInvocation.MyCommand -Config $Config

            $response = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -Config $Config
        
            Write-PSLLMLog -Line "Message added successfully." -Function $MyInvocation.MyCommand -Config $Config
        
            return $response
        }
        catch {
            $errorMessage = "Failed to add message: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Get-PSLLMThreadMessages {
    <#
    .SYNOPSIS
    Retrieves messages from a chat thread.

    .DESCRIPTION
    Gets all messages from a specified chat thread using either its ID or title.
    Can optionally format the messages as a chat history.

    .PARAMETER Thread
    The whole thread to retrieve messages from.

    .PARAMETER ThreadId
    The ID of the thread to retrieve messages from.

    .PARAMETER ThreadName
    The title of the thread to retrieve messages from.

    .PARAMETER FormatAsChatHistory
    If specified, formats the output as a readable chat history.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMThreadMessages -ThreadId "thread-123456"

    .EXAMPLE
    Get-PSLLMThreadMessages -ThreadName "My Chat" -FormatAsChatHistory
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = "This function is appropriately named.")]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Thread,
        
        [Parameter(Mandatory = $false)]
        [string]$ThreadId,
        
        [Parameter(Mandatory = $false)]
        [string]$ThreadName,
        
        [Parameter(Mandatory = $false)]
        [switch]$FormatAsChatHistory,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if ($PSBoundParameters.ContainsKey('Thread')) {
                $ThreadId = $Thread.id
            } elseif ($PSBoundParameters.ContainsKey('ThreadName')){
                $Thread = Get-PSLLMThread -ThreadName $ThreadName -Config $Config
                if (-not $Thread) {
                    Throw "Thread with name '$ThreadName' not found."
                }
                $ThreadId = $Thread.id
            } elseif (-not $PSBoundParameters.ContainsKey('ThreadId')) {
                Throw "Pass a 'Thread', 'ThreadId' or 'ThreadName' to the function."
            }
            Write-PSLLMLog -Line "Retrieving thread messages with id '$ThreadId'." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/threads/$ThreadId/messages"

            $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -Config $Config
        
            Write-PSLLMLog -Line "Retrieved $($response.data.Count) messages." -Function $MyInvocation.MyCommand -Config $Config

            $Messages = @()
            foreach ($msg in $response.data){
                $msgObj = @{
                    role    = $msg.role
                    content = $msg.content.text.value
                }
                $Messages += $msgObj
            }
            [array]::Reverse($Messages)
        
            if ($FormatAsChatHistory) {
                $response.data | ForEach-Object {
                    $rolePrefix = if ($_.role -eq "assistant") { "Assistant" } else { "User" }
                    Write-Output "`n$($rolePrefix): $($_.content)"
                }
            }
            return $Messages
        }
        catch {
            $errorMessage = "Failed to retrieve thread messages: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Get-PSLLMThread {
    <#
    .SYNOPSIS
    Retrieves a specific chat thread by title.

    .DESCRIPTION
    Gets a chat thread from the local LLM server using its title.

    .PARAMETER ThreadName
    The name of the thread to retrieve.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMThread -ThreadName "My Chat Session"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ThreadName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            Write-PSLLMLog -Line "Retrieving thread with name: '$ThreadName'" -Function $MyInvocation.MyCommand -Config $Config
        
            $threads = Get-PSLLMThreads -Config $Config
            $thread = $threads | Where-Object { $_.metadata.title -eq $ThreadName } | Select-Object -First 1
        
            if ($thread) {
                Write-PSLLMLog -Line "Thread found: $($thread.id)" -Function $MyInvocation.MyCommand -Config $Config
                return $thread
            } else {
                Write-PSLLMLog -Line "No thread found with name: '$ThreadName'" -Function $MyInvocation.MyCommand -Severity "Warning" -Config $Config
                return $false
            }
        }
        catch {
            $errorMessage = "Failed to retrieve thread: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Get-PSLLMThreads {
    <#
    .SYNOPSIS
    Retrieves all chat threads from the local LLM server.

    .DESCRIPTION
    Gets a list of all available chat threads from the local LLM server.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMThreads
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = "This function is appropriately named.")]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Config
    )

    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        Write-PSLLMLog -Line "Retrieving all threads." -Function $MyInvocation.MyCommand -Config $Config

        $endPoint = "v1/threads"
        
        $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -Config $Config
        
        Write-PSLLMLog -Line "Retrieved $($response.data.Count) threads." -Function $MyInvocation.MyCommand -Config $Config
        
        return $response.data
    }
    catch {
        $errorMessage = "Failed to retrieve threads: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

function New-PSLLMThread {
    <#
    .SYNOPSIS
    Creates a new chat thread.

    .DESCRIPTION
    Creates a new chat thread on the local LLM server with the specified title.
    Optionally can reuse an existing thread if one exists with the same title.

    .PARAMETER ThreadName
    The name for the new thread.

    .PARAMETER ReuseExisting
    If specified, will return an existing thread with the same title instead of creating a new one.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    New-PSLLMThread -ThreadName "New Chat Session"

    .EXAMPLE
    New-PSLLMThread -ThreadName "My Chat" -ReuseExisting
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$ThreadName,
        
        [Parameter(Mandatory = $false)]
        [switch]$ReuseExisting,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            Write-PSLLMLog -Line "Creating new thread with name: '$ThreadName'" -Function $MyInvocation.MyCommand -Config $Config
            if ($ReuseExisting) {
                Write-PSLLMLog -Line "ReuseExisting flag is set." -Function $MyInvocation.MyCommand -Config $Config
            }

            if ($ReuseExisting) {
                $existingThread = Get-PSLLMThread -ThreadName $ThreadName -Config $Config
                if ($existingThread) {
                    Write-PSLLMLog -Line "Reusing existing thread: $($existingThread.id)" -Function $MyInvocation.MyCommand -Config $Config
                    return $existingThread
                }
            }

            $endPoint = "v1/threads"
            $body = @{
                metadata = @{
                    title = $ThreadName
                }
            } | ConvertTo-Json

            Write-PSLLMLog -Line "Creating new thread with name '$ThreadName'" -Function $MyInvocation.MyCommand -Config $Config

            $response = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -Config $Config
        
            return $response
        }
        catch {
            $errorMessage = "Failed to create thread: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Remove-PSLLMThread {
    <#
    .SYNOPSIS
    Removes a chat thread from the local LLM server.

    .DESCRIPTION
    Deletes a specified chat thread from the local LLM server using either its ID or title.

    .PARAMETER Thread
    The whole thread to remove.

    .PARAMETER ThreadId
    The ID of the thread to remove.

    .PARAMETER ThreadName
    The title of the thread to remove.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Remove-PSLLMThread -ThreadId "thread-123456"

    .EXAMPLE
    Remove-PSLLMThread -ThreadName "My Chat Session"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Thread,
        
        [Parameter(Mandatory = $false)]
        [string]$ThreadId,
        
        [Parameter(Mandatory = $false)]
        [string]$ThreadName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if ($PSBoundParameters.ContainsKey('Thread')) {
                $ThreadId = $Thread.id
            } elseif ($PSBoundParameters.ContainsKey('ThreadName')){
                $Thread = Get-PSLLMThread -ThreadName $ThreadName -Config $Config
                if (-not $Thread) {
                    Throw "Thread with name '$ThreadName' not found."
                }
                $ThreadId = $Thread.id
            } elseif (-not $PSBoundParameters.ContainsKey('ThreadId')) {
                Throw "Pass a 'Thread', 'ThreadId' or 'ThreadName' to the function."
            }

            Write-PSLLMLog -Line "Starting thread removal process." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/threads/$ThreadId"

            Write-PSLLMLog -Line "Sending delete request to: $endPoint" -Function $MyInvocation.MyCommand -Config $Config

            $response = Invoke-PSLLMRequest -Method Delete -EndPoint $endPoint -Config $Config
            
            Write-PSLLMLog -Line "Thread deletion successful." -Function $MyInvocation.MyCommand -Config $Config
            
            return $response.deleted
        }
        catch {
            $errorMessage = "Failed to remove thread: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

#endregion
<#-------------------------------------------------------------------------------------
FILE MANAGEMENT

- Add-PSLLMFile               : Uploads a file to the local LLM server.
- Get-PSLLMFileContent        : Retrieves the content of a file from the local LLM server.
- Get-PSLLMFiles              : Retrieves a list of files available on the local LLM server.
- Remove-PSLLMFile            : Removes a file from the local LLM server.
------------------------------------------------------------------------------#>#region

function Add-PSLLMFile {
    <#
    .SYNOPSIS
    Uploads a file to the local LLM server.

    .DESCRIPTION
    Uploads a specified file to the local LLM server for use with assistants or other
    purposes. Supports various file purposes and handles the multipart form data upload.

    .PARAMETER FilePath
    The path to the file to upload.

    .PARAMETER Purpose
    The purpose of the file. Defaults to "assistants".

    .PARAMETER RAGGroup
    The RAG group to add the file to. Defaults to "Default".

    .PARAMETER PartSize
    The size of the chunk to embedd. Defaults to 1024.

    .PARAMETER ModelName
    Optional. The name of the model to use. If not specified, uses the model from configuration.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Add-PSLLMFile -FilePath "C:\data\context.txt"

    .EXAMPLE
    Add-PSLLMFile -FilePath "C:\data\training.json" -Purpose "fine-tuning"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Purpose = "assistants",
        
        [Parameter(Mandatory = $false)]
        [string]$RAGGroup = "Default",

        [Parameter(Mandatory = $false)]
        [int]$PartSize = 1024,
        
        [Parameter(Mandatory = $false)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $config.ModelName
            }
            if (-not $FilePath.EndsWith(".txt")) {
                $fileType = $FilePath.split('.')[-1]
                Throw "File type '$fileType' currently not supported, only 'txt'."
            }

            Write-PSLLMLog -Line "Starting file upload: '$FilePath' / Purpose: $Purpose." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/files"
            $file = Get-Item $FilePath
        
            $FormTemplate = @'
--{0}
Content-Disposition: form-data; name="files[]"; filename="{1}"
Content-Type: {2}

{3}
--{0}
Content-Disposition: form-data; name="purpose"

{4}
--{0}--

'@
            $enc = [System.Text.Encoding]::GetEncoding("iso-8859-1")
            $boundary = [guid]::NewGuid().Guid
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $Data = $enc.GetString($bytes)
            $body = $FormTemplate -f $boundary, $file.Name, 'application/json', $Data, $Purpose

            Write-PSLLMLog -Line "Sending file upload request to: $endPoint" -Function $MyInvocation.MyCommand -Config $Config

            $response = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -ModelName $ModelName -Config $Config

            Write-PSLLMLog -Line "File upload successful: $($response.id)" -Function $MyInvocation.MyCommand -Config $Config
   
            $fileContent = Get-PSLLMFileContent -FileId $($response.id) -Config $Config

            if ($fileContent.length -gt $PartSize){
                $chunks = Split-PSLLMStringIntoChunks -String $fileContent -MaxSize $PartSize
                $partCounter = 0
                foreach ($chunk in $chunks) {
                    $lastRAG = Save-PSLLMRAGEmbedding -Text $chunk -FileId $($response.id) -RAGGroup $RAGGroup -Part $partCounter -PartSize $part -ModelName $ModelName -Config $Config
                    $partCounter = $partCounter + 1
                }
            } else {
                $lastRAG = Save-PSLLMRAGEmbedding -Text $fileContent -FileId $($response.id) -RAGGroup $RAGGroup -Part 0 -PartSize $part -ModelName $ModelName -Config $Config
            }

            return $lastRAG
        }
        catch {
            $errorMessage = "Failed to add RAG file: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Get-PSLLMFileContent {
    <#
    .SYNOPSIS
    Retrieves the content of a file from the local LLM server.

    .DESCRIPTION
    Gets the content of a specified file from the local LLM server using its file ID.

    .PARAMETER FileId
    The ID of the file to retrieve.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMFileContent -FileId "file-123456"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$FileId,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            Write-PSLLMLog -Line "Retrieving content for file: '$FileId'." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/files/$FileId/content"

            $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -Config $Config
        
            Write-PSLLMLog -Line "File content retrieved successfully." -Function $MyInvocation.MyCommand -Config $Config
        
            return $response
        }
        catch {
            $errorMessage = "Failed to retrieve file content: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Get-PSLLMFiles {
    <#
    .SYNOPSIS
    Retrieves a list of files available on the local LLM server.

    .DESCRIPTION
    Gets all files that have been uploaded to the local LLM server for use with
    assistants or other purposes.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMFiles
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = "This function is appropriately named.")]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        $Config
    )

    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        Write-PSLLMLog -Line "Retrieving file list." -Function $MyInvocation.MyCommand -Config $Config

        $endPoint = "v1/files"

        $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -Config $Config
        Write-PSLLMLog -Line "Retrieved $($response.data.Count) files." -Function $MyInvocation.MyCommand -Config $Config
        
        return $response.data
    }
    catch {
        $errorMessage = "Failed to retrieve files: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

function Remove-PSLLMFile {
    <#
    .SYNOPSIS
    Removes a file from the local LLM server.

    .DESCRIPTION
    Deletes a specified file from the local LLM server using its file ID.

    .PARAMETER FileId
    The ID of the file to remove.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Remove-PSLLMFile -FileId "file-123456"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$FileId,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }        
            Write-PSLLMLog -Line "Removing file: '$FileId'." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/files/$FileId"

            Write-PSLLMLog -Line "Sending delete request to: $endPoint" -Function $MyInvocation.MyCommand -Config $Config

            $response = Invoke-PSLLMRequest -Method Delete -EndPoint $endPoint -Config $Config

            Write-PSLLMLog -Line "File deletion successful." -Function $MyInvocation.MyCommand -Config $Config
        
            return $response.deleted
        }
        catch {
            $errorMessage = "Failed to remove file: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

#endregion
<#-------------------------------------------------------------------------------------
MODEL MANAGEMENT

- Get-PSLLMModel              : Retrieves a specific model by name.
- Get-PSLLMModels             : Retrieves all available models from the local LLM server.
- Start-PSLLMModel            : Starts a model on the local LLM server.
- Stop-PSLLMModel             : Stops a running model on the local LLM server.
- Install-PSLLMModel          : Installs a new model on the local LLM server.
- Remove-PSLLMModel           : Removes a model from the local LLM server.
------------------------------------------------------------------------------#>#region

function Get-PSLLMModel {
    <#
    .SYNOPSIS
    Retrieves a specific model by name.

    .DESCRIPTION
    Gets a model from the local LLM server using its name.

    .PARAMETER ModelName
    The name of the model to retrieve.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMModel -ModelName "tinyllama"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }        
            if (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $Config.ModelName
            }
        
            Write-PSLLMLog -Line "Retrieving model with name: '$ModelName'." -Function $MyInvocation.MyCommand -Config $Config

            $models = Get-PSLLMModels -Config $Config
            $model = $models | Where-Object { $_.model -eq $ModelName } | Select-Object -First 1
        
            if ($model) {
                Write-PSLLMLog -Line "Model found: $($model.model)." -Function $MyInvocation.MyCommand -Config $Config
                return $model
            } else {
                Write-PSLLMLog -Line "No model found with name: '$ModelName'." -Function $MyInvocation.MyCommand -Config $Config
                return $false
            }
        }
        catch {
            $errorMessage = "Failed to retrieve model: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Get-PSLLMModels {
    <#
    .SYNOPSIS
    Retrieves all available models from the local LLM server.

    .DESCRIPTION
    Gets a list of all models that are available on the local LLM server.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMModels
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = "This function is appropriately named.")]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $Config
    )

    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        Write-PSLLMLog -Line "Retrieving available models." -Function $MyInvocation.MyCommand -Config $Config

        $endPoint = "v1/models"

        $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -Config $Config
        
        Write-PSLLMLog -Line "Retrieved $($response.data.Count) models." -Function $MyInvocation.MyCommand -Config $Config
        
        return $response.data
    }
    catch {
        $errorMessage = "Failed to retrieve models: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

function Start-PSLLMModel {
    <#
    .SYNOPSIS
    Starts a model on the local LLM server.

    .DESCRIPTION
    Initializes and starts a specified model on the local LLM server. If the model is not
    already installed, it will be downloaded and installed first. This function handles the
    complete lifecycle of getting a model ready for use, including:
    - Checking if the model exists
    - Installing if necessary
    - Starting the model
    - Verifying the model is running

    .PARAMETER ModelName
    The name and version of the model to start, in the format "name:version".
    If not specified, uses the model from configuration.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Start-PSLLMModel
    # Starts the default model specified in configuration

    .EXAMPLE
    Start-PSLLMModel -ModelName "mistral:7b-gguf"
    # Starts the specified model
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory = $false,
            Position = 0,
            HelpMessage = "Name of the model to start",
            ValueFromPipeline = $true
        )]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }        
            if (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $config.ModelName
            }
            Write-PSLLMLog -Line "Attempting to start model: '$ModelName'." -Function $MyInvocation.MyCommand -Config $Config

            # Check if model exists
            $installedModel = Get-PSLLMModel -ModelName $ModelName -Config $Config
            if (-not $installedModel) {
                $installResult = Install-PSLLMModel -ModelName $ModelName -Config $Config
                if (-not $installResult) {
                    throw "Failed to install model '$ModelName'"
                }
            }

            # Prepare request
            $endPoint = "v1/models/start"
            $body = @{
                model = $ModelName
            } | ConvertTo-Json

            # Start model
            $response = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -ModelName $ModelName -Config $Config
            
            Write-PSLLMLog -Line "Model '$ModelName' started successfully." -Function $MyInvocation.MyCommand -Config $Config
            
            return $response.message        
        }
        catch {
            $errorMessage = "Failed to start model: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Stop-PSLLMModel {
    <#
    .SYNOPSIS
    Stops a running model on the local LLM server.

    .DESCRIPTION
    Gracefully stops a specified model that is running on the local LLM server.

    .PARAMETER Model
    The model to stop.

    .PARAMETER ModelName
    The name of the model to stop.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Stop-PSLLMModel -ModelName "mistral:7b-gguf"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Model,

        [Parameter(Mandatory = $false)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if ($PSBoundParameters.ContainsKey('Model')) {
                $ModelName = $Model.id
            } elseif (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $Config.ModelName
            }
            Write-PSLLMLog -Line "Stopping model: '$ModelName'." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/models/stop"
            $body = @{
                model = $ModelName
            } | ConvertTo-Json

            $response = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -ModelName $ModelName -Config $Config
        
            Write-PSLLMLog -Line "Model stopped successfully." -Function $MyInvocation.MyCommand -Config $Config
        
            return $response.message
        }
        catch {
            $errorMessage = "Failed to stop model: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Install-PSLLMModel {
    <#
    .SYNOPSIS
    Installs a new model on the local LLM server.

    .DESCRIPTION
    Downloads and installs a specified model on the local LLM server for use with chat completions
    and other tasks. Chose any model from "https://cortex.so/models".

    .PARAMETER ModelName
    The name of the model to install.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Install-PSLLMModel -ModelName "mistral:7b-gguf"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }        
            if (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $Config.ModelName
            }
            Write-PSLLMLog -Line "Installing model: '$ModelName'." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/models/pull"
            $body = @{
                model = $ModelName
            } | ConvertTo-Json

            $previousModels = Get-PSLLMModels -Config $Config
            if ($ModelName -in ($previousModels | Select-Object model).model){
                Write-PSLLMLog -Line "Model $ModelName already installed." -Function $MyInvocation.MyCommand -Config $Config
                return $true
            }

            $previousCount = $previousModels.count
            Write-PSLLMLog -Line "Previous model count: $previousCount." -Function $MyInvocation.MyCommand -Config $Config

            $modelInstall = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -Config $Config

            if ($modelInstall) {        
                Write-PSLLMLog -Line "Model installation started." -Function $MyInvocation.MyCommand -Config $Config

                $currentCount = $previousCount

                while ($currentCount -ne ($previousCount + 1)) {
                    Start-Sleep -Seconds 20
                    Write-PSLLMLog -Line "Checking model installation status." -Function $MyInvocation.MyCommand -Config $Config
                    $currentCount = @(Get-PSLLMModels -Config $Config).count
                }

                Write-PSLLMLog -Line "Model successfully installed." -Function $MyInvocation.MyCommand -Config $Config
                return $true
            } else {
                Throw "Invalid model name."
            }
        }
        catch {
            $errorMessage = "Failed to install model: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Remove-PSLLMModel {
    <#
    .SYNOPSIS
    Removes a model from the local LLM server.

    .DESCRIPTION
    Deletes a specified model from the local LLM server using either its ID or name.

    .PARAMETER Model
    The whole model to remove.

    .PARAMETER ModelId
    The ID of the model to remove.

    .PARAMETER ModelName
    The title of the model to remove.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Remove-PSLLMModel -ModelId "model-123456"

    .EXAMPLE
    Remove-PSLLMModel -ModelName "mistral:7b-gguf"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Model,
        
        [Parameter(Mandatory = $false)]
        [string]$ModelId,
        
        [Parameter(Mandatory = $false)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if ($PSBoundParameters.ContainsKey('Model')) {
                $ModelId = $Model.id
            } elseif ($PSBoundParameters.ContainsKey('ModelName')){
                $Model = Get-PSLLMModel -ModelName $ModelName -Config $Config
                if (-not $Model) {
                    Throw "Model with name '$ModelName' not found."
                }
                $ModelId = $Model.id
            } elseif (-not $PSBoundParameters.ContainsKey('ModelId')) {
                $ModelName = $Config.ModelName
                $Model = Get-PSLLMModel -ModelName $ModelName -Config $Config
                if (-not $Model) {
                    Throw "Model with name '$ModelName' not found."
                }
                $ModelId = $Model.id
            }
            Write-PSLLMLog -Line "Starting model removal process." -Function $MyInvocation.MyCommand -Config $Config

            if ($PSCmdlet.ShouldProcess($ModelId, "Remove model")) {
                $endPoint = "v1/models/$ModelId"

                Write-PSLLMLog -Line "Sending delete request to: $endPoint" -Function $MyInvocation.MyCommand -Config $Config

                $response = Invoke-PSLLMRequest -Method Delete -EndPoint $endPoint -ModelName $ModelName -Config $Config

                Write-PSLLMLog -Line "Model deletion successful." -Function $MyInvocation.MyCommand -Config $Config
            
                return $response.deleted
            }
        }
        catch {
            $errorMessage = "Failed to remove model: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

#endregion
<#-------------------------------------------------------------------------------------
ENGINE MANAGEMENT

- Get-PSLLMEngine             : Retrieves the requested LLM engine from the local server.
- Get-PSLLMEngineReleases     : Retrieves all available releases for a specific LLM engine.
- Start-PSLLMEngine           : Loads and starts a specific LLM engine on the local server.
- Update-PSLLMEngine          : Updates a specific LLM engine on the local server.
- Stop-PSLLMEngine            : Stops a loaded engine on the local LLM server.
- Install-PSLLMEngine         : Installs a specific LLM engine on the local server.
- Uninstall-PSLLMEngine       : Uninstalls a specific LLM engine from the local server.
------------------------------------------------------------------------------#>#region

function Get-PSLLMEngine {
    <#
    .SYNOPSIS
    Retrieves the requested LLM engine from the local server.

    .DESCRIPTION
    Gets the requested LLM engine (llama-cpp, onnxruntime, tensorrt-llm) from the local server.

    .PARAMETER EngineName
    The name of the engine to use.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMEngine -EngineName "llama-cpp"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if (-not $PSBoundParameters.ContainsKey('EngineName')) {
                $EngineName = $Config.EngineName
            }        
            Write-PSLLMLog -Line "Retrieving engine $EngineName." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/engines/$EngineName"

            try {
                $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -EngineName $EngineName -Config $Config
            } catch {
                $installReturn = Install-PSLLMEngine -EngineName $EngineName -Config $Config
                if (-not $installReturn){
                    Throw "Failed installing engine."
                } else {
                    $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -EngineName $EngineName -Config $Config
                }
            }
        
            Write-PSLLMLog -Line "Retrieved engine: $EngineName." -Function $MyInvocation.MyCommand -Config $Config
        
            return $response
        }
        catch {
            $errorMessage = "Failed to retrieve engine: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Get-PSLLMEngineReleases {
    <#
    .SYNOPSIS
    Retrieves all available releases for a specific LLM engine.

    .DESCRIPTION
    Gets a list of all releases for the specified LLM engine from the local server.

    .PARAMETER EngineName
    The name of the engine (llama-cpp, onnxruntime, or tensorrt-llm).

    .PARAMETER Latest
    Switch to only get the latest release.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMEngineReleases -EngineName "llama-cpp"
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = "This function is appropriately named.")]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,

        [Parameter(Mandatory = $false)]
        [switch]$Latest,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if (-not $PSBoundParameters.ContainsKey('EngineName')) {
                $EngineName = $Config.EngineName
            }
            Write-PSLLMLog -Line "Retrieving releases for engine: $EngineName." -Function $MyInvocation.MyCommand -Config $Config

            if ($Latest) {
                $endPoint = "v1/engines/$EngineName/releases/latest"
            } else {
                $endPoint = "v1/engines/$EngineName/releases"
            }

            $response = Invoke-PSLLMRequest -Method Get -EndPoint $endPoint -EngineName $EngineName -Config $Config
        
            if ($Latest) {
                Write-PSLLMLog -Line "Retrieved latest release of $EngineName." -Function $MyInvocation.MyCommand -Config $Config
            } else {
                Write-PSLLMLog -Line "Retrieved $($response.Count) releases." -Function $MyInvocation.MyCommand -Config $Config
            }
        
            return $response
        }
        catch {
            $errorMessage = "Failed to retrieve engine releases: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Start-PSLLMEngine {
    <#
    .SYNOPSIS
    Loads and starts a specific LLM engine on the local server.

    .DESCRIPTION
    Initializes and starts the specified LLM engine on the local server.

    .PARAMETER EngineName
    The name of the engine to start (llama-cpp, onnxruntime, or tensorrt-llm).

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Start-PSLLMEngine -EngineName "llama-cpp"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }        
            if (-not $PSBoundParameters.ContainsKey('EngineName')) {
                $EngineName = $Config.EngineName
            }

            $installedEngine = Get-PSLLMEngine -EngineName $EngineName -Config $Config

            if (!($installedEngine)){
                Install-PSLLMEngine -EngineName $EngineName -Config $Config
            }
        
            Write-PSLLMLog -Line "Starting engine: '$EngineName'" -Function $MyInvocation.MyCommand -Config $Config
        
            $endPoint = "v1/engines/$EngineName/load"

            $null = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -EngineName $EngineName -Body $body -ContentType application/json -Config $Config
        
            Write-PSLLMLog -Line "Engine loaded successfully." -Function $MyInvocation.MyCommand -Config $Config
        
            return $true
        }
        catch {
            $errorMessage = "Failed to load engine: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Update-PSLLMEngine {
    <#
    .SYNOPSIS
    Updates a specific LLM engine on the local server.

    .DESCRIPTION
    Updates the specified LLM engine to the latest version on the local server.

    .PARAMETER Engine
    The engine to update.

    .PARAMETER EngineName
    The name of the engine to update (llama-cpp, onnxruntime, or tensorrt-llm).

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Update-PSLLMEngine -EngineName "llama-cpp"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Engine,

        [Parameter(Mandatory = $false)]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if ($PSBoundParameters.ContainsKey('Engine')) {
                $EngineName = $Engine.engine
            } elseif (-not $PSBoundParameters.ContainsKey('EngineName')) {
                $EngineName = $Config.EngineName
            }
            Write-PSLLMLog -Line "Updating engine: $EngineName." -Function $MyInvocation.MyCommand -Config $Config

            $engineStart = Start-PSLLMEngine -EngineName $EngineName -Config $Config

            if ($engineStart) {

                $endPoint = "v1/engines/$EngineName/update"

                $null = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -EngineName $EngineName -Body $body -ContentType application/json -Config $Config
        
                Write-PSLLMLog -Line "Engine update completed successfully." -Function $MyInvocation.MyCommand -Config $Config
        
                return $true
            } else {
                Throw "Could not start engine $EngineName."
            }
        }
        catch {
            $errorMessage = "Failed to update engine: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Stop-PSLLMEngine {
    <#
    .SYNOPSIS
    Stops a loaded engine on the local LLM server.

    .DESCRIPTION
    Gracefully stops a specified engine that is running on the local LLM server.

    .PARAMETER Engine
    The engine to stop.

    .PARAMETER EngineName
    The name of the model to stop.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Stop-PSLLMEngine -EngineName "llama-cpp"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Engine,

        [Parameter(Mandatory = $false)]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if ($PSBoundParameters.ContainsKey('Engine')) {
                $EngineName = $Engine.engine
            } elseif (-not $PSBoundParameters.ContainsKey('EngineName')) {
                $EngineName = $Config.EngineName
            }
            Write-PSLLMLog -Line "Stopping engine: '$EngineName'." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/engines/$EngineName/load"

            $response = Invoke-PSLLMRequest -Method Delete -EndPoint $endPoint -EngineName $EngineName -Config $Config
        
            Write-PSLLMLog -Line "Engine unloaded successfully." -Function $MyInvocation.MyCommand -Config $Config
        
            return $response.message
        }
        catch {
            $errorMessage = "Failed to unload engine: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Install-PSLLMEngine {
    <#
    .SYNOPSIS
    Installs a specific LLM engine on the local server.

    .DESCRIPTION
    Downloads and installs the specified LLM engine on the local server.

    .PARAMETER EngineName
    The name of the engine to install (llama-cpp, onnxruntime, or tensorrt-llm).

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Install-PSLLMEngine -EngineName "llama-cpp"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if (-not $PSBoundParameters.ContainsKey('EngineName')) {
                $EngineName = $Config.EngineName
            }
            Write-PSLLMLog -Line "Installing engine: $EngineName." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/engines/$EngineName/install"

            $response = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -Config $Config
        
            Write-PSLLMLog -Line "Engine installation completed successfully." -Function $MyInvocation.MyCommand -Config $Config
        
            return $response
        }
        catch {
            $errorMessage = "Failed to install engine: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Uninstall-PSLLMEngine {
    <#
    .SYNOPSIS
    Uninstalls a specific LLM engine from the local server.

    .DESCRIPTION
    Removes the specified LLM engine from the local server.

    .PARAMETER Engine
    The engine to uninstall.

    .PARAMETER EngineName
    The name of the engine to uninstall (llama-cpp, onnxruntime, or tensorrt-llm).

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Uninstall-PSLLMEngine -EngineName "llama-cpp"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $Engine,

        [Parameter(Mandatory = $false)]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if ($PSBoundParameters.ContainsKey('Engine')) {
                $EngineName = $Engine.engine
            } elseif (-not $PSBoundParameters.ContainsKey('EngineName')) {
                $EngineName = $Config.EngineName
            }
            Write-PSLLMLog -Line "Uninstalling engine: $EngineName." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/engines/$EngineName/install"

            $response = Invoke-PSLLMRequest -Method Delete -EndPoint $endPoint -EngineName $EngineName -Config $Config
        
            Write-PSLLMLog -Line "Engine uninstallation completed successfully." -Function $MyInvocation.MyCommand -Config $Config
        
            return $response.message
        }
        catch {
            $errorMessage = "Failed to uninstall engine: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

#endregion
<#-------------------------------------------------------------------------------------
PRIVATE FUNCTIONS

- Add-PSLLMStringEscapes      : Prepares strings for use in JSON by escaping special characters.
- Get-PSLLMEmbedding          : Generates embeddings for the provided text using a local LLM model.
- Invoke-PSLLMAsyncCompletion : Handles asynchronous AI request processing for chat completions.
- Invoke-PSLLMRequest         : Makes HTTP requests to the local LLM server with automatic error handling and retry logic.
- Save-PSLLMRAGEmbedding      : Adds a RAG embedding to a RAG group.
- Split-PSLLMStringIntoChunks : Splits a string into smaller chunks while preserving sentence boundaries.
- Write-PSLLMLog              : Internal function for logging PSLLM module operations.
------------------------------------------------------------------------------#>#region

function Add-PSLLMStringEscapes {
    <#
    .SYNOPSIS
    Prepares strings for use in JSON by escaping special characters.

    .DESCRIPTION
    This function escapes characters that might interfere with JSON parsing or formatting. 
    Common escape sequences (e.g., backslashes, double quotes, and control characters like newlines or tabs) 
    are processed to ensure compatibility with JSON encoding standards.

    .PARAMETER String
    The input string to be escaped for JSON compatibility.

    .EXAMPLE
    Add-CBAIStringEscapes -String "Line1\nLine2"
    # Returns: "Line1\\nLine2"

    .EXAMPLE
    Add-CBAIStringEscapes -String 'Path\to\"file\"'
    # Returns: "Path\\to\\\"file\\\""

    .OUTPUTS
    System.String
    A JSON-compatible escaped string.

    .NOTES
    This function is useful when generating JSON payloads for API requests or other systems requiring strict encoding.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = "This function is appropriately named.")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$String
    )

    # Ensure the string is properly encoded in UTF-8
    $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($String)
    $escapedString = [System.Text.Encoding]::UTF8.GetString($utf8Bytes)
    $escapedString = $escapedString -replace '\\', '\\\\'  # Escape backslashes
    $escapedString = $escapedString -replace '"', '\"'     # Escape double quotes
    $escapedString = $escapedString -replace '[“”]', '\"'  # Normalize and escape smart quotes
    $escapedString = $escapedString -replace "`n", '\n'    # Escape newline
    $escapedString = $escapedString -replace "`r", '\r'    # Escape carriage return
    $escapedString = $escapedString -replace "`t", '\t'    # Escape tab
    $escapedString = $escapedString -replace "`b", '\b'    # Escape backspace
    $escapedString = $escapedString -replace "`f", '\f'    # Escape form feed

    return $escapedString
}

function Get-PSLLMEmbedding {
    <#
    .SYNOPSIS
    Generates embeddings for the provided text using a local LLM model.

    .DESCRIPTION
    Creates vector embeddings from input text using a specified model or the default model
    from configuration. These embeddings can be used for semantic search, text comparison,
    and other NLP tasks.

    .PARAMETER Text
    The text to generate embeddings for.

    .PARAMETER ModelName
    Optional. The name of the model to use. If not specified, uses the model from configuration.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Get-PSLLMEmbedding -Text "Hello world"
    # Generates embeddings using the configured default model

    .EXAMPLE
    Get-PSLLMEmbedding -Text "Complex technical concept" -ModelName "custom-model"
    # Generates embeddings using a specific model
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Text,
        
        [Parameter(Mandatory = $false)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }        
            if (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $config.ModelName
            }

            Write-PSLLMLog -Line "Starting embedding generation, using model: $ModelName." -Function $MyInvocation.MyCommand -Config $Config

            $endPoint = "v1/embeddings"
        
            $body = @{
                input = $Text
                model = $ModelName
            } | ConvertTo-Json

            $response = Invoke-PSLLMRequest -Method Post -EndPoint $endPoint -Body $body -ContentType application/json -ModelName $ModelName -ModelNeeded $true -Config $Config

            Write-PSLLMLog -Line "Embedding generation successful." -Function $MyInvocation.MyCommand -Config $Config
        
            return $response.data[0].embedding
        }
        catch {
            $errorMessage = "Failed to generate embedding: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Invoke-PSLLMAsyncCompletion {
    <#
    .SYNOPSIS
    Handles asynchronous AI request processing for chat completions.

    .DESCRIPTION
    Executes an asynchronous request to the Cortex server for AI-generated chat completions. 
    The function allows users to continue other tasks while the request is being processed. 
    The output can be saved to a file in the user's temporary directory or displayed in a dynamically generated UI window.

    .PARAMETER Body
    The JSON-formatted body of the request containing the input message, assistant role, and model settings.

    .PARAMETER AsyncType
    Specifies how the response is handled for asynchronous processing. Options:
    - "File": Saves the response to a JSON file in the system's temporary folder.
    - "Window": Displays the response in a dynamically generated graphical window.
    - "Both": Combination of file and window.

    .EXAMPLE
    Invoke-PSLLMAsyncCompletion -Body $body -AsyncType "File"
    # Sends an asynchronous request and saves the output to a JSON file.

    .EXAMPLE
    Invoke-PSLLMAsyncCompletion -Body $body -AsyncType "Window"
    # Sends an asynchronous request and displays the output in a new window.

    .OUTPUTS
    File: A JSON file containing the response in the system's temporary folder (when -AsyncType "File").
    Window: A graphical UI displaying the response (when -AsyncType "Window").

    .NOTES
    The Cortex server must be running locally, and the `Body` parameter must be properly structured as a JSON object.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='Variable is used after Measure-Command')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Uri = "http://127.0.0.1:39281/v1/chat/completions",

        [Parameter(Mandatory = $false)]
        [string]$Body = "",

        [Parameter(Mandatory = $false)]
        [ValidateSet("File", "Window", "Both")]
        [string]$AsyncType = "File",

        [Parameter(Mandatory = $false)]
        [string]$DataDirectory = "$($env:localappdata)\PSLLM"
    )

    $syncHash = [hashtable]::Synchronized(@{})
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.Open()

    $runspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
    $runspace.SessionStateProxy.SetVariable("uri", $Uri)
    $runspace.SessionStateProxy.SetVariable("body", $Body)
    $runspace.SessionStateProxy.SetVariable("asyncType", $AsyncType)
    $runspace.SessionStateProxy.SetVariable("dataDirectory", $DataDirectory)

    $psCmd = [PowerShell]::Create().AddScript({
        $askingTime = (Get-Date)
        $measure = Measure-Command {
            $response = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType application/json
        }
        $query = $body | ConvertFrom-Json
        $detailedResponse = @{
            Response       = $response.choices[0].message.content
            Assistant      = $query.messages[0].content
            Prompt         = $query.messages[1].content
            Duration       = $($measure.TotalSeconds)
            PromptTokens   = $($response.usage.prompt_tokens)
            ResponseTokens = $($response.usage.completion_tokens)
            TotalTokens    = $($response.Response.usage.total_tokens)
            AskingTime     = $askingTime
        }

        if ($asyncType -in @("File","Both")){
            $detailedResponse | ConvertTo-Json -Depth 5 |  Out-File -FilePath "$dataDirectory\PSLLM_Answer_$($askingTime).json" -Force
        } 
        if ($asyncType -in @("Window","Both")){
            [xml]$responseXaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="PSLLM Response" MinWidth="620" MinHeight="450" Background="#FFF5F5F5">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        
        <!-- Labels and TextBoxes -->
        <Label Grid.Row="0" Grid.Column="0" Content="Asking Time:" VerticalAlignment="Center" Margin="5"/>
        <TextBox Grid.Row="0" Grid.Column="1" Name="txtAskingTime" Margin="5" IsReadOnly="True" Background="#FFF5F5F5"/>

        <Label Grid.Row="1" Grid.Column="0" Content="Prompt:" VerticalAlignment="Center" Margin="5"/>
        <TextBox Grid.Row="1" Grid.Column="1" Name="txtPrompt" Margin="5" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#FFF5F5F5"/>
        
        <Label Grid.Row="2" Grid.Column="0" Content="Assistant:" VerticalAlignment="Center" Margin="5"/>
        <TextBox Grid.Row="2" Grid.Column="1" Name="txtAssistant" Margin="5" IsReadOnly="True" Background="#FFF5F5F5"/>
        
        <Label Grid.Row="3" Grid.Column="0" Content="Duration:" VerticalAlignment="Center" Margin="5"/>
        <TextBox Grid.Row="3" Grid.Column="1" Name="txtDuration" Margin="5" IsReadOnly="True" Background="#FFF5F5F5"/>
        
        <Label Grid.Row="4" Grid.Column="0" Content="Tokens:" VerticalAlignment="Center" Margin="5"/>
        <TextBox Grid.Row="4" Grid.Column="1" Name="txtTokens" Margin="5" IsReadOnly="True" Background="#FFF5F5F5"/>
        
        <Label Grid.Row="5" Grid.Column="0" Content="Response:" VerticalAlignment="Top" Margin="5"/>
        <TextBox Grid.Row="5" Grid.Column="1" Name="txtResponse" Margin="5" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Background="#FFF5F5F5"/>
        
        <!-- Buttons -->
        <StackPanel Grid.Row="6" Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="5">
            <Button Name="btnCopy" Content="Copy Response" Width="100" Height="30" Margin="0,0,10,0" Background="#FF4B4B4B" BorderBrush="white" Foreground="white"/>
            <Button Name="btnClose" Content="Close" Width="75" Height="30" IsCancel="True" IsDefault="True" Background="#FF4B4B4B" BorderBrush="white" Foreground="white"/>
        </StackPanel>
    </Grid>
</Window>
"@

            $responseReader = (New-Object System.Xml.XmlNodeReader $responseXaml)
            $syncHash.Window = [Windows.Markup.XamlReader]::Load($responseReader)

            $responseXaml.SelectNodes("//*[@Name]") | ForEach-Object {
                Set-Variable -Name "$($_.Name)" -Value $syncHash.Window.FindName($_.Name)
            }
            $txtAskingTime.Text = $detailedResponse.AskingTime
            $txtPrompt.Text = $detailedResponse.Prompt
            $txtAssistant.Text = $detailedResponse.Assistant
            $txtDuration.Text = "$($detailedResponse.Duration) seconds"
            $txtTokens.Text = "Prompt: $($detailedResponse.PromptTokens) / Response: $($detailedResponse.ResponseTokens)"
            $txtResponse.Text = $detailedResponse.Response

            # Close button behavior
            $btnClose.Add_Click({ $syncHash.Window.Close() })
            $btnCopy.Add_Click({ [System.Windows.Clipboard]::SetText($detailedResponse.Response) })

            # Show the window
            $syncHash.Window.ShowDialog() | Out-Null        
        }
    })

    $psCmd.Runspace = $runspace
    $null = $psCmd.BeginInvoke()
}

function Invoke-PSLLMRequest {
    <#
    .SYNOPSIS
    Makes HTTP requests to the local LLM server with automatic error handling and retry logic.

    .DESCRIPTION
    Sends HTTP requests (GET, POST, PUT, DELETE) to the local LLM server endpoint. Includes automatic 
    server restart and retry on failure, logging, and configuration management. Supports both body-less 
    (GET, DELETE) and body-including (POST, PUT) requests.

    .PARAMETER Method
    The HTTP method to use for the request. Valid values are: Get, Post, Put, Delete.

    .PARAMETER EndPoint
    The endpoint URL path to send the request to, relative to the base URI.

    .PARAMETER Body
    The request body to send (for POST/PUT requests). Defaults to an empty string.

    .PARAMETER ContentType
    The content type of the request. Defaults to "application/json".

    .PARAMETER EngineName
    The LLM engine to use. Valid values are: llama-cpp, onnxruntime, tensorrt-llm.
    If not specified, uses the value from config.

    .PARAMETER ModelName
    The name of the model to use. If not specified, uses the value from config.

    .PARAMETER ModelNeeded
    Determines if only server needs to be started, or model needs to be loaded. Defaults to server only.

    .PARAMETER Config
    The configuration object containing server settings. If not specified, imports default config.

    .EXAMPLE
    Invoke-PSLLMRequest -Method Get -EndPoint "v1/models"
    Gets a list of all available models from the server.

    .EXAMPLE
    $body = @{
        prompt = "Hello, world!"
        max_tokens = 100
    } | ConvertTo-Json
    Invoke-PSLLMRequest -Method Post -EndPoint "v1/completions" -Body $body
    Sends a completion request to the server.

    .NOTES
    The function includes automatic retry logic - if a request fails, it will attempt to restart 
    the server and retry the request once before failing.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Get", "Post", "Put", "Delete")]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$EndPoint,

        [Parameter(Mandatory = $false)]
        [string]$Body = "",

        [Parameter(Mandatory = $false)]
        [string]$ContentType = "application/json",

        [Parameter(Mandatory = $false)]
        [ValidateSet('llama-cpp', 'onnxruntime', 'tensorrt-llm')]
        [string]$EngineName,

        [Parameter(Mandatory = $false)]
        [string]$ModelName,

        [Parameter(Mandatory = $false)]
        [bool]$ModelNeeded = $false,

        [Parameter(Mandatory = $false)]
        $Config
    )
    try {
        if (-not $PSBoundParameters.ContainsKey('Config')) {
            $Config = Import-PSLLMConfig
        }
        if (-not $PSBoundParameters.ContainsKey('EngineName')) {
            $EngineName = $Config.EngineName
        }
        if (-not $PSBoundParameters.ContainsKey('ModelName')) {
            $ModelName = $Config.ModelName
        }
        if ($VerbosePreference -eq "SilentlyContinue") {
            $isVerbose = $false
        } else {
            $isVerbose = $true
        }

        Write-PSLLMLog -Line "Starting request to '$EndPoint' of type '$Method'." -Function $MyInvocation.MyCommand -Severity Information -Config $Config

        $uri = "$($Config.BaseUri)/$EndPoint"
        if ($Method -eq "Get" -or $Method -eq "Delete") {
            # GET and DELETE should not include a body
            try {
                if ($isVerbose) { $VerbosePreference = 'SilentlyContinue' }
                $response = Invoke-RestMethod -Method $Method -Uri $uri
                if ($isVerbose) { $VerbosePreference = 'Continue' }
            } catch {
                if ($isVerbose) { $VerbosePreference = 'Continue' }
                #$responseMessage = ($_ | ConvertFrom-Json).message
                #write-host $responseMessage
                Write-PSLLMLog -Line "Failed request: $responseMessage" -Function $MyInvocation.MyCommand -Severity Warning -Config $Config
                Start-PSLLMServer -EngineName $EngineName -ModelName $ModelName -Config $Config -ModelNeeded $ModelNeeded -Restart
                if ($isVerbose) { $VerbosePreference = 'SilentlyContinue' }
                $response = Invoke-RestMethod -Method $Method -Uri $uri
                if ($isVerbose) { $VerbosePreference = 'Continue' }
            }
        } else {
            # POST, PUT, etc., can include a body
            try {
                if ($isVerbose) { $VerbosePreference = 'SilentlyContinue' }
                $response = Invoke-RestMethod -Method $Method -Uri $uri -Body $Body -ContentType $ContentType
                if ($isVerbose) { $VerbosePreference = 'Continue' }
            } catch {
                if ($isVerbose) { $VerbosePreference = 'Continue' }
                try {
                    $tempResponse = $_
                    $responseMessage = ($tempResponse | ConvertFrom-Json).message
                    switch ($responseMessage) {
                        'Invalid model handle or not supported!' {return $false}
                    }
                } catch {
                    $responseMessage = $tempResponse
                }
                Write-PSLLMLog -Line "Failed request: $responseMessage" -Function $MyInvocation.MyCommand -Severity Warning -Config $Config
                Start-PSLLMServer -EngineName $EngineName -ModelName $ModelName -Config $Config -ModelNeeded $ModelNeeded -Restart
                if ($isVerbose) { $VerbosePreference = 'SilentlyContinue' }
                $response = Invoke-RestMethod -Method $Method -Uri $uri -Body $Body -ContentType $ContentType
                if ($isVerbose) { $VerbosePreference = 'Continue' }
            }
        }

        return $response
    }
    catch {
        $errorMessage = "Failed to invoke REST method: $($_.Exception.Message)"
        Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
        Write-Warning $errorMessage
        return $false
    }
}

function Save-PSLLMRAGEmbedding {
    <#
    .SYNOPSIS
    Adds a RAG embedding to a RAG group.

    .DESCRIPTION
    Adds a RAG embedding to a RAG group.

    .PARAMETER Text
    The text to create an embedding for.

    .PARAMETER FileId
    The id of to the file.

    .PARAMETER Part
    The part of the file.

    .PARAMETER RAGGroup
    The RAG group to add the embedding to. Defaults to "Default".

    .PARAMETER PartSize
    The size of the chunk to embedd. Defaults to 1024.

    .PARAMETER ModelName
    Optional. The name of the model to use. If not specified, uses the model from configuration.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Save-PSLLMRAGEmbedding
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Text,
        
        [Parameter(Mandatory = $true)]
        [string]$FileId,
        
        [Parameter(Mandatory = $false)]
        [int]$Part = 0,
        
        [Parameter(Mandatory = $false)]
        [string]$RAGGroup = "Default",
        
        [Parameter(Mandatory = $false)]
        [int]$PartSize = 1024,
        
        [Parameter(Mandatory = $false)]
        [string]$ModelName,
        
        [Parameter(Mandatory = $false)]
        $Config
    )
    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Config')) {
                $Config = Import-PSLLMConfig
            }
            if (-not $PSBoundParameters.ContainsKey('ModelName')) {
                $ModelName = $config.ModelName
            }
        
            # Create RAG directory if it doesn't exist
            $ragDir = "$env:LOCALAPPDATA\PSLLM\RAG"
            if (-not (Test-Path -Path $ragDir)) {
                $null = New-Item -Path $ragDir -ItemType Directory -Force
                Write-PSLLMLog -Line "Created directory: '$ragDir'." -Function $MyInvocation.MyCommand -Config $config
            }
        
            $ragFilePath = Join-Path $ragDir "$($RAGGroup).json"
        
            # Load or initialize RAG group
            if (Test-Path -Path $ragFilePath) {
                # Read existing content and convert to PowerShell objects
                $existingContent = Get-Content -Path $ragFilePath -Raw | ConvertFrom-Json
                $RAGGroupObject = @{
                    PartSize = $existingContent.PartSize
                    Embeddings = @()
                }
            
                # Properly reconstruct existing embeddings
                foreach ($existingEmbed in $existingContent.Embeddings) {
                    $RAGGroupObject.Embeddings += @{
                        FileID = $existingEmbed.FileID
                        Part = $existingEmbed.Part
                        Embedding = $existingEmbed.Embedding
                    }
                }
            
                Write-PSLLMLog -Line "Retrieved RAG group '$($RAGGroup)' from file." -Function $MyInvocation.MyCommand -Config $config
            } else {
                # Initialize new RAG group
                $RAGGroupObject = @{
                    PartSize = $PartSize
                    Embeddings = @()
                }
                Write-PSLLMLog -Line "Created RAG group '$($RAGGroup)' from scratch." -Function $MyInvocation.MyCommand -Config $config
            }
        
            # Create new embedding
            $embedding = Get-PSLLMEmbedding -Text $Text -ModelName $ModelName -Config $Config
        
            # Add new embedding to array
            $RAGGroupObject.Embeddings += @{
                FileID = $FileId
                Part = $Part
                Embedding = $embedding
            }
        
            # Save updated object
            $jsonContent = $RAGGroupObject | ConvertTo-Json -Depth 10
            Set-Content -Path $ragFilePath -Value $jsonContent -Force
        
            # Return the properly structured object
            return [PSCustomObject]$RAGGroupObject
        }
        catch {
            $errorMessage = "Failed to add RAG embedding: $($_.Exception.Message)"
            Write-PSLLMLog -Line $errorMessage -Function $MyInvocation.MyCommand -Severity "Error" -Config $Config
            Write-Warning $errorMessage
            return $false
        }
    }
}

function Split-PSLLMStringIntoChunks {
    <#
    .SYNOPSIS
    Splits a string into smaller chunks while preserving sentence boundaries.

    .DESCRIPTION
    Takes a large string and splits it into smaller chunks based on a maximum size parameter.
    Attempts to keep sentences intact by splitting on sentence boundaries (periods) where possible.
    Used internally by RAG functions to create manageable text segments for embedding.

    .PARAMETER String
    The input string to be split into chunks.

    .PARAMETER MaxSize
    The maximum size (in characters) for each chunk.

    .EXAMPLE
    Split-PSLLMStringIntoChunks -String $longDocument -MaxSize 1024
    Splits a long document into chunks of maximum 1024 characters each.

    .EXAMPLE
    $chunks = Split-PSLLMStringIntoChunks -String (Get-Content -Raw 'document.txt') -MaxSize 512
    Reads a file and splits its content into 512-character chunks.
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = "This function is appropriately named.")]
    param (
        [string]$String,
        [int]$MaxSize
    )
    # Split the string into sentences based on periods (adjust if needed for different delimiters)
    $sentences = $String -split '(?<=\.)\s+'

    # Initialize variables
    $chunks = @()
    $currentChunk = ""

    # Loop through each sentence and assemble chunks
    foreach ($sentence in $sentences) {
        if (($currentChunk.Length + $sentence.Length + 1) -le $MaxSize) {
            # Add the sentence to the current chunk
            $currentChunk += " " + $sentence
        } else {
            # Save the current chunk and start a new one
            $chunks += $currentChunk.Trim()
            $currentChunk = $sentence
        }
    }

    # Add the final chunk if it has content
    if ($currentChunk.Trim()) {
        $chunks += $currentChunk.Trim()
    }
    return $chunks
}

function Write-PSLLMLog {
    <#
    .SYNOPSIS
    Internal function for logging PSLLM module operations.

    .DESCRIPTION
    Writes log entries to the PSLLM log file using a standardized format.
    For internal module use only.

    .PARAMETER Line
    The message to log.

    .PARAMETER Function
    The name of the calling function.

    .PARAMETER Severity
    The severity level of the log entry. Valid values: Information, Warning, Error.
    Defaults to Information.

    .PARAMETER Config
    The current configuration object.

    .EXAMPLE
    Write-PSLLMLog -Line "Starting operation" -Function "Get-PSLLMChatCompletion"
    # Logs an information message

    .EXAMPLE
    Write-PSLLMLog -Line "Operation failed" -Function "Add-PSLLMFile" -Severity Error
    # Logs an error message
    #>
    [CmdletBinding()]
    #[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    param (
        [Parameter(Mandatory, ValueFromPipeline = $true)]
        [string]$Line,
        
        [Parameter(Mandatory)]
        [string]$Function,

        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',

        [Parameter(Mandatory)]
        $Config
    )
    process {
        Write-Verbose "$(get-date -format "HH:mm:ss:fff") | $Line"
        if ($Config.Logging){

            $logFolder = Join-Path $env:LOCALAPPDATA 'PSLLM'
            $logFile = Join-Path $logFolder 'PSLLM.log'

            # Ensure log directory exists
            if (-not (Test-Path $logFile)) {
                if (-not (Test-Path $logFolder)) {
                    $null = New-Item -Path $logFolder -ItemType Directory
                    Write-PSLLMLog -Line "Created directory: $logFolder" -Function $MyInvocation.MyCommand -Config $Config
                }
            }

            $severityCode = switch ($Severity) {
                'Information' { 1 }
                'Warning'     { 2 }
                'Error'       { 3 }
            }

            $logEntry = "<![LOG[$Line]LOG]!>" +
                        "<time=`"$(Get-Date -Format 'HH:mm:ss.ffffff')`" " +
                        "date=`"$(Get-Date -Format 'M-d-yyyy')`" " +
                        "component=`"$Function`" " +
                        "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +
                        "type=`"$severityCode`" " +
                        "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " +
                        "file=`"`">"

            $null = Start-Job -ScriptBlock {
                Add-Content -Path $using:logFile -Value $using:logEntry -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

#endregion
