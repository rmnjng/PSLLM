# PSLLM - PowerShell Local Language Model

## Overview  
PSLLM is a PowerShell module for managing and interacting with a locally hosted Large Language Model (LLM) using the Cortex server. It enables AI-driven text generation, conversation management, Retrieval-Augmented Generation (RAG), and local model operations.  

## Features  
- **AI Completion & Conversations**: Generate AI responses and manage chat threads.  
- **Configuration & Server Control**: Install, start, stop, and configure the LLM server.  
- **Model & Engine Management**: Install, start, stop, and retrieve models and engines.  
- **File & RAG Integration**: Upload and retrieve files for AI-augmented searches.  

## Purpose
PSLLM **should** be used for...
- **Sensitive data**: completeley local LLMs, no data ever leaves the computer.
- **Asynchronous workflows**: with e.g., scheduled tasks or in potentially long-running scripts.
- **Bulk operations**: because it can be scheduled and run in the background, it is perfect for operating the same or multiple LLM operations based on an array of inputs.
- **Cost-sensitive automation**: it is free, what do you want more?
- **PowerShell integrations**: everything you can access from PowerShell (local and Internet) can be used in the LLM workflow, e.g., as input data or output mechanism.

PSLLM **should not** be used for...
- **Acting as a chatbot**: speed heavily relies on your hardware. A cloud GPU cluster will be faster, but not every workflow depends on speed. And at the pace models currently advance in quality and speed, this will not be an issue for long.

## Installation  
### Prerequisites  
- PowerShell 5.1
- Internet for installation, not for LLM usage.

### Install from PowerShell Gallery  
```powershell
Install-Module -Name PSLLM -Scope CurrentUser
```

### Manual Installation  
1. Download the latest release from [GitHub Releases](#).  
2. Extract the module to your PowerShell modules directory (`$env:PSModulePath`).  
3. Import the module:  
   ```powershell
   Import-Module PSLLM
   ```


## Quick Start
### Generating AI Responses
```powershell
Get-PSLLMCompletion -Message "What is the capital of France?"
```

On the first run, the following happens:
- Download and run the [Cortex Windows installer](https://cortex.so/) (~1.8 GB).
- Download the default engine ([llama-cpp](https://github.com/ggml-org/llama.cpp)).
- Download and load the default model ([Mistral 7B](https://huggingface.co/cortexso/mistral)) - Model size depends on the amount of parameters as well as quantization. Check out [Managing Models](#managing-models) for more information.
- Generate the response.

### Managing Conversations
This command starts or adds to a multi-turn conversation. It sends the whole thread to the LLM and adds the new message as well as the AI answer to the thread.
```powershell
Enter-PSLLMConversation -Message "Explain list comprehensions in Python" -ThreadName "Python Basics"
```

Display the whole thread:
```powershell
Get-PSLLMThreadMessages -ThreadName "Python Basics" -FormatAsChatHistory
```

### Managing Models
Model selection can be tricky, because the options are vast. The recommendation is to start with specially prepared models by Cortex.so, found on [HuggingFace](https://huggingface.co/cortexso).
Every model in the *.gguf format can be used, but let's start with the Cortex.so models.

The easiest way is through their [model page](https://cortex.so/models). Copy the command of the model you'd like to try (e.g., "cortex run llama3.2").
Open up a command prompt and run the command, after installing Cortex ("Install-PSLLMServer").
Then you should be presented a selection of models. In this example:
```bash
Available to download:
    1. llama3.2:1b
    2. llama3.2:3b
```

Copy the name of the model, size, and quantization you want (e.g., "llama3.2:3b"), for reference check the table below.

This name can then be used as `$ModelName` parameter with the PowerShell module.


Model size approximations based on the amount of **P**arameters and the used **Q**uantization:

|  P/Q  |   q2   |   q3   |   q4   |   q5   |   q6   |   q8   |
|-------|:------:|:------:|:------:|:------:|:------:|:------:|
|  **1B**  | 0.6GB | 0.7GB | 0.8GB | 0.9GB |   1GB | 1.3GB |
|  **3B**  | 1.4GB | 1.7GB |   2GB | 2.3GB | 2.6GB | 3.4GB |
|  **7B**  | 2.7GB | 3.5GB | 4.3GB | 5.1GB |   6GB | 7.7GB |
| **14B**  | 5.7GB | 7.3GB |   9GB |  10GB |  12GB |  16GB |
| **32B**  |  12GB |  16GB |  19GB |  23GB |  27GB |  35GB |
| **70B**  |  26GB |  34GB |  42GB |  50GB |   N/A  |   N/A  |

This is also roughly the amount of physical memory (RAM, not GPU) needed to run the models. Inference can be run on GPUs as well as CPUs, the only difference is speed.

### Storing Default Configurations
Some parameters that are used throughout the module can be stored centrally. This eliminates the need for specifying each time. 
This example enbales logging to '`$env:localappdata\PSLLM\PSLLM.log`' and sets the 8 B DeepSeek llama distilation (q4) model as default. If not already, the model will be downloaded and loaded by default.

```powershell
Save-PSLLMConfig -Logging $true -ModelName 'deepseek-r1-distill-llama-8b:8b-gguf-q4-km'
```

For all configuration options, check out [Save-PSLLMConfig](#save-psllmconfig).

### Verbose
For interactive usage, for example during development, it is highly recommended to make use of the '-Verbose' parameter, available for every PSLLM function.


## Command Reference  
See the [full command reference](#functions) for details on available cmdlets.  


## Contributing  
Contributions are welcome!


## License  
This project is licensed under the **Apache License 2.0**. See the [LICENSE](LICENSE) file for details.
PSLLM is built on top of other open source projects, most directly on [Cortex.so](https://cortex.so/).


## Support  
For issues, please open a ticket on the [GitHub Issues](#) page.  


## Functions

### Main Functions
- [Get-PSLLMCompletion](#get-psllmcompletion)
- [Enter-PSLLMConversation](#enter-psllmconversation)
- [Get-PSLLMRAGContent](#get-psllmragcontent)

### Config Management
- [Import-PSLLMConfig](#import-psllmconfig)
- [Save-PSLLMConfig](#save-psllmconfig)

### Server Management
- [Start-PSLLMServer](#start-psllmserver)
- [Stop-PSLLMServer](#stop-psllmserver)
- [Install-PSLLMServer](#install-psllmserver)
- [Uninstall-PSLLMServer](#uninstall-psllmserver)
- [Get-PSLLMHardwareInfo](#get-psllmhardwareinfo)
- [Test-PSLLMHealth](#test-psllmhealth)

### Thread Management
- [Add-PSLLMThreadMessage](#add-psllmthreadmessage)
- [Get-PSLLMThreadMessages](#get-psllmthreadmessages)
- [Get-PSLLMThread](#get-psllmthread)
- [Get-PSLLMThreads](#get-psllmthreads)
- [New-PSLLMThread](#new-psllmthread)
- [Remove-PSLLMThread](#remove-psllmthread)

### File Management
- [Add-PSLLMFile](#add-psllmfile)
- [Get-PSLLMFileContent](#get-psllmfilecontent)
- [Get-PSLLMFiles](#get-psllmfiles)
- [Remove-PSLLMFile](#remove-psllmfile)

### Model Management
- [Get-PSLLMModel](#get-psllmmodel)
- [Get-PSLLMModels](#get-psllmmodels)
- [Start-PSLLMModel](#start-psllmmodel)
- [Stop-PSLLMModel](#stop-psllmmodel)
- [Install-PSLLMModel](#install-psllmmodel)
- [Remove-PSLLMModel](#remove-psllmmodel)

### Engine Management
- [Get-PSLLMEngine](#get-psllmengine)
- [Get-PSLLMEngineReleases](#get-psllmenginereleases)
- [Start-PSLLMEngine](#start-psllmengine)
- [Update-PSLLMEngine](#update-psllmengine)
- [Stop-PSLLMEngine](#stop-psllmengine)
- [Install-PSLLMEngine](#install-psllmengine)
- [Uninstall-PSLLMEngine](#uninstall-psllmengine)


## Get-PSLLMCompletion

### Synopsis
Retrieves an AI-generated response from a local language model via the Cortex server.

### Description
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

### Parameters
#### -Message
**Type:** String

**Description:** A single user message to send to the language model. Used when not providing a full message thread.

#### -Messages
**Type:** Object

**Description:** An array of message objects representing a conversation thread. Allows for more complex conversational contexts.

#### -ModelName
**Type:** String

**Description:** Specifies the AI model to use. Defaults to the model configured in the system settings.

#### -EngineName
**Type:** String

**Description:** Optional. Specifies a particular engine for model processing.

#### -Assistant
**Type:** String

**Description:** Defines the system role or persona for the AI. Defaults to a helpful assistant persona.

#### -MaxTokens
**Type:** Int32

**Description:** Maximum number of tokens in the AI's response. Controls response length. Default is 2048.

#### -Temperature
**Type:** Single

**Description:** Controls response randomness (0.0-1.0):
- 0.0: Deterministic, focused responses
- 1.0: Maximum creativity and variation
Default is 0.8.

#### -TopP
**Type:** Single

**Description:** Controls token selection probability. Influences response diversity.
Lower values make responses more focused, higher values increase variability.
Default is 0.95.

#### -Detailed
**Type:** SwitchParameter

**Description:** When specified, returns comprehensive metadata about the response instead of just the text.

#### -Async
**Type:** SwitchParameter

**Description:** Enables asynchronous processing of the request.

#### -AsyncType
**Type:** String

**Description:** Specifies async output method: "File", "Window", or "Both".

#### -DataDirectory
**Type:** String

**Description:** Directory for storing async results. Defaults to %LOCALAPPDATA%\PSLLM.

#### -StoreFile
**Type:** SwitchParameter

**Description:** If set, saves the response to a JSON file in the DataDirectory.

#### -Config
**Type:** Object

**Description:** Configuration object containing system settings.

### Examples
#### --- EXAMPLE 1 ---
Basic usage with a simple question

```powershell
Get-PSLLMCompletion -Message "What is the capital of France?" 
```

#### --- EXAMPLE 2 ---
Retrieve detailed response metadata

```powershell
Get-PSLLMCompletion -Message "Explain quantum computing" -Detailed
```

#### --- EXAMPLE 3 ---
Async processing with window display

```powershell
Get-PSLLMCompletion -Message "Generate a Python script" -Async -AsyncType Window
```

#### --- EXAMPLE 4 ---
Complex conversation thread

```powershell
$thread = @(
    @{ role = "user"; content = "Explain machine learning" },
    @{ role = "assistant"; content = "Machine learning is..." }
)
Get-PSLLMCompletion -Messages $thread -Temperature 0.7  
``` 


## Enter-PSLLMConversation

### Synopsis
Continues or starts a conversation (thread) with a local Language Model (LLM).

### Description
The Enter-PSLLMConversation function allows you to interact with a local language model by sending a message and receiving a response. 
It manages conversation threads, creating a new thread if one doesn't exist or adding to an existing thread with the specified title.

Key features:
- Automatically creates a new thread if the specified title doesn't exist
- Adds user message to the thread
- Generates an AI response using the specified or default model
- Adds the AI response back to the thread
- Supports customization of model parameters like temperature and max tokens

### Parameters
#### -Message
**Type:** String

**Description:** The user input message for which the AI model will generate a response. This is a mandatory parameter.

#### -ThreadName
**Type:** String

**Description:** The name of the conversation to create or add to. This helps in organizing and tracking multiple conversations.

#### -ModelName
**Type:** String

**Description:** Optional. The name of the AI model to use for generating responses. If not specified, uses the model from the configuration.

#### -Assistant
**Type:** String

**Description:** Optional. The initial system role or persona that defines the AI's behavior. Defaults to "You are a helpful assistant."

#### -MaxTokens
**Type:** Int32

**Description:** Optional. Maximum number of tokens in the AI's response. Defaults to 2048. Controls the length of the generated response.

#### -Temperature
**Type:** Single

**Description:** Optional. Controls the randomness of the AI's response. Range is 0.0-1.0. 
- Lower values (closer to 0) make the output more focused and deterministic
- Higher values (closer to 1) make the output more creative and varied
Defaults to 0.8.

#### -TopP
**Type:** Single

**Description:** Optional. Controls the cumulative probability cutoff for token selection. 
- Helps in controlling the diversity of the generated text
- Defaults to 0.95

#### -Config
**Type:** Object

**Description:** Optional. The configuration object containing settings for the LLM interaction. 
If not provided, the function will import the default configuration.

### Examples
#### --- EXAMPLE 1 ---
Start a new conversation about Python programming

```powershell
Enter-PSLLMConversation -Message "Explain list comprehensions in Python" -ThreadName "Python Basics"
``` 

#### --- EXAMPLE 2 ---
Continue an existing conversation with more context

```powershell
Enter-PSLLMConversation -Message "Can you provide an example of a list comprehension?" -ThreadName "Python Basics" -Temperature 0.5
```

#### --- EXAMPLE 3 ---
Use a specific model with custom settings

```powershell
Enter-PSLLMConversation -Message "Write a short poem about technology" -ThreadName "Creative Writing" -ModelName "mistral:7b-gguf" -MaxTokens 2048 -Temperature 0.9
```


## Get-PSLLMRAGContent

### Synopsis
Retrieves relevant content from RAG (Retrieval-Augmented Generation) storage based on input text.

### Description
Uses embeddings to find and retrieve the most semantically similar content from previously stored RAG data.
Calculates cosine similarity between the input text and stored embeddings to identify the most relevant content.

### Parameters
#### -Text
**Type:** String

**Description:** The input text to find similar content for.

#### -RAGGroup
**Type:** String

**Description:** The RAG group to search in. Defaults to "Default".

#### -ModelName
**Type:** String

**Description:** Optional. The name of the model to use. If not specified, uses the model from configuration.

#### -EngineName
**Type:** String

**Description:** Optional. The name of the engine to use. If not specified, uses the engine from configuration.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
Retrieves content most similar to the question about virtual machines.

```powershell
Get-PSLLMRAGContent -Text "How do I create a new virtual machine?"
``` 

#### --- EXAMPLE 2 ---
Searches for content about Azure Storage in the AzureDocs RAG group.

```powershell
Get-PSLLMRAGContent -Text "What is Azure Storage?" -RAGGroup "AzureDocs"
``` 


## Import-PSLLMConfig

### Synopsis
Imports the PSLLM configurations.

### Description
Imports the PSLLM configurations from a JSON file in the local AppData directory.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Import-PSLLMConfig
```

## Save-PSLLMConfig

### Synopsis
Saves the PSLLM configurations.

### Description
Saves the PSLLM configurations to a JSON file in the local AppData directory.

### Parameters
#### -EngineName
**Type:** String

**Description:** The name of the engine to use.

#### -ModelName
**Type:** String

**Description:** The name of the model to use.

#### -Logging
**Type:** Boolean

**Description:** Whether verbose outputs are logged to a file.

#### -BaseUri
**Type:** String

**Description:** Base URI of the Cortex server. Defaults to "http://127.0.0.1:39281".

### Examples
#### --- EXAMPLE 1 ---
```powershell
Save-PSLLMConfig -EngineName "llama-cpp" -ModelName "mistral:7b-gguf" -Logging $true
```

## Start-PSLLMServer

### Synopsis
Starts the local LLM server with specified engine and model.

### Description
Initializes and starts the local LLM server, installing components if necessary.
This function will:
1. Install the server if not present
2. Start the server process if not running
3. Install and start the specified engine
4. Install and start the specified model

### Parameters
#### -EngineName
**Type:** String

**Description:** The name of the engine to use. Must be one of: 'llama-cpp', 'onnxruntime', or 'tensorrt-llm'.
If not specified, uses the engine from configuration.

#### -ModelName
**Type:** String

**Description:** The name of the model to load. If not specified, uses the model from configuration.

#### -ModelNeeded
**Type:** Boolean

**Description:** Determines if only server needs to be started, or model needs to be loaded. Defaults to server only.

#### -Restart
**Type:** SwitchParameter

**Description:** Not only start but first stop the server.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
Starts server with default engine and model from config

```powershell
Start-PSLLMServer
```  

#### --- EXAMPLE 2 ---
Starts server with specific engine and model

```powershell
Start-PSLLMServer -EngineName "llama-cpp" -ModelName "mistral:7b-gguf"
```  


## Stop-PSLLMServer

### Synopsis
Stops the local LLM server process.

### Description
Sends a request to gracefully stop the local LLM server process.

### Parameters
#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Stop-PSLLMServer
```


## Install-PSLLMServer

### Synopsis
Installs the Cortex server for local LLM operations.

### Description
Downloads and installs the Cortex server application required for running local LLM operations.
This function handles the complete installation process including:
- Checking for existing installation
- Downloading the installer (~1.8 GB)
- Running the installation
- Verifying the installation

### Parameters
#### -Force
**Type:** SwitchParameter

**Description:** If specified, skips confirmation prompts and proceeds with download and installation.
Use this for automated installations.

#### -DownloadUri
**Type:** String

**Description:** The address from where to download the latest Cortex Windows installer.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
Interactively installs the server with confirmation prompts

```powershell
Install-PSLLMServer
```

#### --- EXAMPLE 2 ---
Installs the server without confirmation prompts 

```powershell
Install-PSLLMServer -Force
```

#### --- EXAMPLE 3 ---
Installs the server with detailed progress information

```powershell
Install-PSLLMServer -Verbose
```


## Uninstall-PSLLMServer

### Synopsis
Removes the Cortex application from the system.

### Description
Uninstalls the Cortex server and optionally deletes its associated data directory. 
The function identifies the uninstaller in the application directory and executes it silently. 

If specified, the data directory is also deleted to ensure a clean uninstallation.

### Parameters
#### -Force
**Type:** SwitchParameter

**Description:** Skips confirmation prompts and directly executes the uninstallation.

#### -DeleteData
**Type:** SwitchParameter

**Description:** Removes the data directory after uninstallation.

#### -DataDirectory
**Type:** String

**Description:** Specifies the path to the data directory. Defaults to `%LOCALAPPDATA%\PSLLM`.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
Uninstalls the Cortex server and deletes its data directory.

```powershell
Uninstall-PSLLMServer -DeleteData
```


## Get-PSLLMHardwareInfo

### Synopsis
Retrieves hardware information from the local LLM server.

### Description
Gets information about the hardware configuration and capabilities of the local LLM server.

### Parameters
#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMHardwareInfo
```


## Test-PSLLMHealth

### Synopsis
Tests the health status of the local LLM server.

### Description
Performs a health check on the local LLM server by making a request to the health endpoint.
This function will return the server's health status and can be used to verify connectivity
and server readiness.

### Parameters
#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Test-PSLLMHealth
```


## Add-PSLLMThreadMessage

### Synopsis
Adds a message to a chat thread.

### Description
Adds a new message to a specified chat thread using either its ID or title.
Can optionally create the thread if it doesn't exist.

### Parameters
#### -Thread
**Type:** Object

**Description:** The whole thread to add the message to.

#### -ThreadId
**Type:** String

**Description:** The ID of the thread to add the message to.

#### -ThreadName
**Type:** String

**Description:** The title of the thread to add the message to.

#### -Message
**Type:** String

**Description:** The content of the message to add.

#### -Role
**Type:** String

**Description:** The role of the message sender. Can be either "system", "user" or "assistant".

#### -CreateThreadIfNotExists
**Type:** SwitchParameter

**Description:** If specified, creates a new thread with the given name if it doesn't exist.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Add-PSLLMThreadMessage -ThreadId "thread-123456" -Message "Hello!"
```

#### --- EXAMPLE 2 ---
```powershell
Add-PSLLMThreadMessage -ThreadName "My Chat" -Message "Hi there" -CreateThreadIfNotExists
```


## Get-PSLLMThreadMessages

### Synopsis
Retrieves messages from a chat thread.

### Description
Gets all messages from a specified chat thread using either its ID or title.
Can optionally format the messages as a chat history.

### Parameters
#### -Thread
**Type:** Object

**Description:** The whole thread to retrieve messages from.

#### -ThreadId
**Type:** String

**Description:** The ID of the thread to retrieve messages from.

#### -ThreadName
**Type:** String

**Description:** The title of the thread to retrieve messages from.

#### -FormatAsChatHistory
**Type:** SwitchParameter

**Description:** If specified, formats the output as a readable chat history.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMThreadMessages -ThreadId "thread-123456"
```

#### --- EXAMPLE 2 ---
```powershell
Get-PSLLMThreadMessages -ThreadName "My Chat" -FormatAsChatHistory
```


## Get-PSLLMThread

### Synopsis
Retrieves a specific chat thread by title.

### Description
Gets a chat thread from the local LLM server using its title.

### Parameters
#### -ThreadName
**Type:** String

**Description:** The name of the thread to retrieve.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMThread -ThreadName "My Chat Session"
```


## Get-PSLLMThreads

### Synopsis
Retrieves all chat threads from the local LLM server.

### Description
Gets a list of all available chat threads from the local LLM server.

### Parameters
#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMThreads
```


## New-PSLLMThread

### Synopsis
Creates a new chat thread.

### Description
Creates a new chat thread on the local LLM server with the specified title.
Optionally can reuse an existing thread if one exists with the same title.

### Parameters
#### -ThreadName
**Type:** String

**Description:** The name for the new thread.

#### -ReuseExisting
**Type:** SwitchParameter

**Description:** If specified, will return an existing thread with the same title instead of creating a new one.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
New-PSLLMThread -ThreadName "New Chat Session"
```

### --- EXAMPLE 2 ---
```powershell
New-PSLLMThread -ThreadName "My Chat" -ReuseExisting
```


## Remove-PSLLMThread

### Synopsis
Removes a chat thread from the local LLM server.

### Description
Deletes a specified chat thread from the local LLM server using either its ID or title.

### Parameters
#### -Thread
**Type:** Object

**Description:** The whole thread to remove.

#### -ThreadId
**Type:** String

**Description:** The ID of the thread to remove.

#### -ThreadName
**Type:** String

**Description:** The title of the thread to remove.

#### -Config
**Type:** Object

**Description:** The current configuration object.

#### -WhatIf
**Type:** SwitchParameter

**Description:** 

#### -Confirm
**Type:** SwitchParameter

**Description:** 

### Examples
#### --- EXAMPLE 1 ---
```powershell
Remove-PSLLMThread -ThreadId "thread-123456"
```

#### --- EXAMPLE 2 ---
```powershell
Remove-PSLLMThread -ThreadName "My Chat Session"
```


## Add-PSLLMFile

### Synopsis
Uploads a file to the local LLM server.

### Description
Uploads a specified file to the local LLM server for use with assistants or other
purposes. Supports various file purposes and handles the multipart form data upload.

### Parameters
#### -FilePath
**Type:** String

**Description:** The path to the file to upload.

#### -Purpose
**Type:** String

**Description:** The purpose of the file. Defaults to "assistants".

#### -RAGGroup
**Type:** String

**Description:** The RAG group to add the file to. Defaults to "Default".

#### -PartSize
**Type:** Int32

**Description:** The size of the chunk to embedd. Defaults to 1024.

#### -ModelName
**Type:** String

**Description:** Optional. The name of the model to use. If not specified, uses the model from configuration.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Add-PSLLMFile -FilePath "C:\data\context.txt"
```

#### --- EXAMPLE 2 ---
```powershell
Add-PSLLMFile -FilePath "C:\data\training.json" -Purpose "fine-tuning"
```


## Get-PSLLMFileContent

### Synopsis
Retrieves the content of a file from the local LLM server.

### Description
Gets the content of a specified file from the local LLM server using its file ID.

### Parameters
#### -FileId
**Type:** String

**Description:** The ID of the file to retrieve.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMFileContent -FileId "file-123456"
```


## Get-PSLLMFiles

### Synopsis
Retrieves a list of files available on the local LLM server.

### Description
Gets all files that have been uploaded to the local LLM server for use with
assistants or other purposes.

### Parameters
#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMFiles
```


## Remove-PSLLMFile

### Synopsis
Removes a file from the local LLM server.

### Description
Deletes a specified file from the local LLM server using its file ID.

### Parameters
#### -FileId
**Type:** String

**Description:** The ID of the file to remove.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Remove-PSLLMFile -FileId "file-123456"
```


## Get-PSLLMModel

### Synopsis
Retrieves a specific model by name.

### Description
Gets a model from the local LLM server using its name.

### Parameters
#### -ModelName
**Type:** String

**Description:** The name of the model to retrieve.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMModel -ModelName "tinyllama"
```


## Get-PSLLMModels

### Synopsis
Retrieves all available models from the local LLM server.

### Description
Gets a list of all models that are available on the local LLM server.

### Parameters
#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMModels
```


## Start-PSLLMModel

### Synopsis
Starts a model on the local LLM server.

### Description
Initializes and starts a specified model on the local LLM server. If the model is not
already installed, it will be downloaded and installed first. This function handles the
complete lifecycle of getting a model ready for use, including:
- Checking if the model exists
- Installing if necessary
- Starting the model
- Verifying the model is running

### Parameters
#### -ModelName
**Type:** String

**Description:** The name and version of the model to start, in the format "name:version".
If not specified, uses the model from configuration.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
Starts the default model specified in configuration

```powershell
Start-PSLLMModel
```

#### --- EXAMPLE 2 ---
Starts the specified model

```powershell
Start-PSLLMModel -ModelName "mistral:7b-gguf"
```


## Stop-PSLLMModel

### Synopsis
Stops a running model on the local LLM server.

### Description
Gracefully stops a specified model that is running on the local LLM server.

### Parameters
#### -Model
**Type:** Object

**Description:** The model to stop.

#### -ModelName
**Type:** String

**Description:** The name of the model to stop.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Stop-PSLLMModel -ModelName "mistral:7b-gguf"
```


## Install-PSLLMModel

### Synopsis
Installs a new model on the local LLM server.

### Description
Downloads and installs a specified model on the local LLM server for use with chat completions
and other tasks. Chose any model from "https://cortex.so/models".

### Parameters
#### -ModelName
**Type:** String

**Description:** The name of the model to install.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Install-PSLLMModel -ModelName "mistral:7b-gguf"
```


## Remove-PSLLMModel

### Synopsis
Removes a model from the local LLM server.

### Description
Deletes a specified model from the local LLM server using either its ID or name.

### Parameters
#### -Model
**Type:** Object

**Description:** The whole model to remove.

#### -ModelId
**Type:** String

**Description:** The ID of the model to remove.

#### -ModelName
**Type:** String

**Description:** The title of the model to remove.

#### -Config
**Type:** Object

**Description:** The current configuration object.

#### -WhatIf
**Type:** SwitchParameter

**Description:** 

#### -Confirm
**Type:** SwitchParameter

**Description:** 

### Examples
#### --- EXAMPLE 1 ---
```powershell
Remove-PSLLMModel -ModelId "model-123456"
```

#### --- EXAMPLE 2 ---
```powershell
Remove-PSLLMModel -ModelName "mistral:7b-gguf"
```


## Get-PSLLMEngine

### Synopsis
Retrieves the requested LLM engine from the local server.

### Description
Gets the requested LLM engine (llama-cpp, onnxruntime, tensorrt-llm) from the local server.

### Parameters
#### -EngineName
**Type:** String

**Description:** The name of the engine to use.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMEngine -EngineName "llama-cpp"
```


## Get-PSLLMEngineReleases

### Synopsis
Retrieves all available releases for a specific LLM engine.

### Description
Gets a list of all releases for the specified LLM engine from the local server.

### Parameters
#### -EngineName
**Type:** String

**Description:** The name of the engine (llama-cpp, onnxruntime, or tensorrt-llm).

#### -Latest
**Type:** SwitchParameter

**Description:** Switch to only get the latest release.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Get-PSLLMEngineReleases -EngineName "llama-cpp"
```


## Start-PSLLMEngine

### Synopsis
Loads and starts a specific LLM engine on the local server.

### Description
Initializes and starts the specified LLM engine on the local server.

### Parameters
#### -EngineName
**Type:** String

**Description:** The name of the engine to start (llama-cpp, onnxruntime, or tensorrt-llm).

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Start-PSLLMEngine -EngineName "llama-cpp"
```


## Update-PSLLMEngine

### Synopsis
Updates a specific LLM engine on the local server.

### Description
Updates the specified LLM engine to the latest version on the local server.

### Parameters
#### -Engine
**Type:** Object

**Description:** The engine to update.

#### -EngineName
**Type:** String

**Description:** The name of the engine to update (llama-cpp, onnxruntime, or tensorrt-llm).

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Update-PSLLMEngine -EngineName "llama-cpp"
```


## Stop-PSLLMEngine

### Synopsis
Stops a loaded engine on the local LLM server.

### Description
Gracefully stops a specified engine that is running on the local LLM server.

### Parameters
#### -Engine
**Type:** Object

**Description:** The engine to stop.

#### -EngineName
**Type:** String

**Description:** The name of the model to stop.

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Stop-PSLLMEngine -EngineName "llama-cpp"
```


## Install-PSLLMEngine

### Synopsis
Installs a specific LLM engine on the local server.

### Description
Downloads and installs the specified LLM engine on the local server.

### Parameters
#### -EngineName
**Type:** String

**Description:** The name of the engine to install (llama-cpp, onnxruntime, or tensorrt-llm).

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Install-PSLLMEngine -EngineName "llama-cpp"
```


## Uninstall-PSLLMEngine

### Synopsis
Uninstalls a specific LLM engine from the local server.

### Description
Removes the specified LLM engine from the local server.

### Parameters
#### -Engine
**Type:** Object

**Description:** The engine to uninstall.

#### -EngineName
**Type:** String

**Description:** The name of the engine to uninstall (llama-cpp, onnxruntime, or tensorrt-llm).

#### -Config
**Type:** Object

**Description:** The current configuration object.

### Examples
#### --- EXAMPLE 1 ---
```powershell
Uninstall-PSLLMEngine -EngineName "llama-cpp"
```
