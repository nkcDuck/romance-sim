param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$ConfigPath = "romance_sim/.image-api.local.json",
    [string]$Provider = "",
    [string]$Model = "",
    [string]$Endpoint = "",
    [string]$ApiKey = "",
    [string]$ReferenceImagePath = "",
    [string]$Size = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

function Get-ConfigValue {
    param($ConfigObj, [string]$PropName)
    if ($null -eq $ConfigObj) { return "" }
    $prop = $ConfigObj.PSObject.Properties[$PropName]
    if ($null -ne $prop -and $null -ne $prop.Value) {
        return [string]$prop.Value
    }
    return ""
}

function Get-MimeTypeFromPath {
    param([string]$Path)
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        ".png"  { return "image/png" }
        ".jpg"  { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".webp" { return "image/webp" }
        default { return "image/png" }
    }
}

function Find-ImagePayload {
    param($Node)
    if ($null -eq $Node) { return $null }

    if ($Node -is [string] -or $Node.GetType().IsPrimitive) {
        return $null
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [System.Collections.IDictionary])) {
        foreach ($item in $Node) {
            $found = Find-ImagePayload -Node $item
            if ($null -ne $found) { return $found }
        }
        return $null
    }

    if ($Node -is [PSCustomObject] -or $Node -is [System.Collections.IDictionary]) {
        $typeProp = $Node.PSObject.Properties["type"]
        $dataProp = $Node.PSObject.Properties["data"]
        if ($null -ne $typeProp -and [string]$typeProp.Value -eq "image" -and $null -ne $dataProp -and $dataProp.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($dataProp.Value)) {
            return @{ kind = "b64"; data = [string]$dataProp.Value }
        }

        $b64Prop = $Node.PSObject.Properties["b64_json"]
        if ($null -ne $b64Prop -and $b64Prop.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($b64Prop.Value)) {
            return @{ kind = "b64"; data = [string]$b64Prop.Value }
        }

        $inlineProp = $Node.PSObject.Properties["inlineData"]
        if ($null -ne $inlineProp -and $null -ne $inlineProp.Value) {
            $inlineDataProp = $inlineProp.Value.PSObject.Properties["data"]
            if ($null -ne $inlineDataProp -and $inlineDataProp.Value -is [string] -and -not [string]::IsNullOrWhiteSpace($inlineDataProp.Value)) {
                return @{ kind = "b64"; data = [string]$inlineDataProp.Value }
            }
        }

        $urlProp = $Node.PSObject.Properties["url"]
        if ($null -ne $urlProp -and $urlProp.Value -is [string] -and ([string]$urlProp.Value -match '^https?://')) {
            return @{ kind = "url"; url = [string]$urlProp.Value }
        }

        foreach ($prop in $Node.PSObject.Properties) {
            if ($null -ne $prop.Value) {
                $found = Find-ImagePayload -Node $prop.Value
                if ($null -ne $found) { return $found }
            }
        }
    }

    return $null
}

$cfg = $null
if (-not [string]::IsNullOrWhiteSpace($ConfigPath) -and (Test-Path $ConfigPath)) {
    try {
        $cfg = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Error "Failed to parse config JSON at $ConfigPath"
        exit 1
    }
}

$resolvedProvider = if (-not [string]::IsNullOrWhiteSpace($Provider)) { $Provider } else { Get-ConfigValue $cfg "provider" }
if ([string]::IsNullOrWhiteSpace($resolvedProvider)) {
    $resolvedProvider = "openai-compatible"
}
$resolvedProvider = $resolvedProvider.Trim().ToLowerInvariant()

$resolvedModel = if (-not [string]::IsNullOrWhiteSpace($Model)) { $Model } else { Get-ConfigValue $cfg "model" }
$resolvedEndpoint = if (-not [string]::IsNullOrWhiteSpace($Endpoint)) { $Endpoint } else { Get-ConfigValue $cfg "endpoint" }
$resolvedSize = if (-not [string]::IsNullOrWhiteSpace($Size)) { $Size } else { Get-ConfigValue $cfg "size" }

switch ($resolvedProvider) {
    "gemini" {
        if ([string]::IsNullOrWhiteSpace($resolvedEndpoint)) {
            $resolvedEndpoint = "https://generativelanguage.googleapis.com/v1beta/interactions"
        }
        if ([string]::IsNullOrWhiteSpace($resolvedModel)) {
            $resolvedModel = "gemini-nano-banana-2.1"
        }
    }
    "openai-compatible" {
        if ([string]::IsNullOrWhiteSpace($resolvedEndpoint)) {
            $resolvedEndpoint = "https://api.openai.com/v1/images/generations"
        }
        if ([string]::IsNullOrWhiteSpace($resolvedModel)) {
            $resolvedModel = "gpt-image-1"
        }
        if ([string]::IsNullOrWhiteSpace($resolvedSize)) {
            $resolvedSize = "1024x1024"
        }
    }
    "custom" {
        if ([string]::IsNullOrWhiteSpace($resolvedEndpoint)) {
            Write-Error "Provider 'custom' requires a non-empty endpoint."
            exit 1
        }
    }
    default {
        Write-Error "Unsupported provider '$resolvedProvider'. Supported: gemini, openai-compatible, custom."
        exit 1
    }
}

# Resolve API key without ever printing it
$resolvedKey = ""
if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
    $resolvedKey = $ApiKey.Trim()
}

if ([string]::IsNullOrWhiteSpace($resolvedKey)) {
    $envName = Get-ConfigValue $cfg "api_key_env"
    if (-not [string]::IsNullOrWhiteSpace($envName)) {
        $envVal = [Environment]::GetEnvironmentVariable($envName)
        if (-not [string]::IsNullOrWhiteSpace($envVal)) {
            $resolvedKey = $envVal.Trim()
        }
    }
}

if ([string]::IsNullOrWhiteSpace($resolvedKey)) {
    $defaultEnvVal = [Environment]::GetEnvironmentVariable("ROMANCE_SIM_IMAGE_API_KEY")
    if (-not [string]::IsNullOrWhiteSpace($defaultEnvVal)) {
        $resolvedKey = $defaultEnvVal.Trim()
    }
}

if ([string]::IsNullOrWhiteSpace($resolvedKey)) {
    if ($resolvedProvider -eq "gemini") {
        $gemKey = [Environment]::GetEnvironmentVariable("GEMINI_API_KEY")
        if (-not [string]::IsNullOrWhiteSpace($gemKey)) { $resolvedKey = $gemKey.Trim() }
    } elseif ($resolvedProvider -eq "openai-compatible") {
        $oaiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY")
        if (-not [string]::IsNullOrWhiteSpace($oaiKey)) { $resolvedKey = $oaiKey.Trim() }
    }
}

if ([string]::IsNullOrWhiteSpace($resolvedKey)) {
    $cfgKey = Get-ConfigValue $cfg "api_key"
    if (-not [string]::IsNullOrWhiteSpace($cfgKey)) {
        $resolvedKey = $cfgKey.Trim()
    }
}

$hasApiKey = -not [string]::IsNullOrWhiteSpace($resolvedKey)
$hasRefImage = (-not [string]::IsNullOrWhiteSpace($ReferenceImagePath)) -and (Test-Path $ReferenceImagePath)

if ($DryRun) {
    Write-Output "STATUS=DRY_RUN_OK"
    Write-Output "PROVIDER=$resolvedProvider"
    Write-Output "MODEL=$resolvedModel"
    Write-Output "ENDPOINT=$resolvedEndpoint"
    Write-Output "HAS_API_KEY=$hasApiKey"
    Write-Output "HAS_REFERENCE_IMAGE=$hasRefImage"
    exit 0
}

if (-not $hasApiKey -and $resolvedProvider -ne "custom") {
    Write-Error "Missing API key for provider '$resolvedProvider'. Supply via -ApiKey, environment variable, or local git-ignored config."
    exit 1
}

$headers = @{
    "Content-Type" = "application/json; charset=utf-8"
}

if ($null -ne $cfg -and $null -ne $cfg.PSObject.Properties["extra_headers"] -and $null -ne $cfg.extra_headers) {
    foreach ($hProp in $cfg.extra_headers.PSObject.Properties) {
        if ($null -ne $hProp.Value) {
            $headers[$hProp.Name] = [string]$hProp.Value
        }
    }
}

$bodyObj = $null
if ($resolvedProvider -eq "gemini") {
    $headers["x-goog-api-key"] = $resolvedKey
    if (-not $headers.ContainsKey("Api-Revision")) {
        $headers["Api-Revision"] = "2026-05-20"
    }
    $inputItems = @(
        @{
            type = "text"
            text = $Prompt
        }
    )
    if ($hasRefImage) {
        $refBytes = [System.IO.File]::ReadAllBytes($ReferenceImagePath)
        $refB64 = [Convert]::ToBase64String($refBytes)
        $refMime = Get-MimeTypeFromPath -Path $ReferenceImagePath
        $inputItems += @{
            type      = "image"
            mime_type = $refMime
            data      = $refB64
        }
    }
    $bodyObj = @{
        model = $resolvedModel
        input = $inputItems
    }
} elseif ($resolvedProvider -eq "openai-compatible") {
    $headers["Authorization"] = "Bearer $resolvedKey"
    $bodyObj = @{
        model  = $resolvedModel
        prompt = $Prompt
        n      = 1
        size   = $resolvedSize
    }
} else {
    if ($hasApiKey) {
        $headers["Authorization"] = "Bearer $resolvedKey"
    }
    $bodyObj = @{
        prompt = $Prompt
    }
    if (-not [string]::IsNullOrWhiteSpace($resolvedModel)) {
        $bodyObj["model"] = $resolvedModel
    }
}

$jsonBody = $bodyObj | ConvertTo-Json -Depth 10 -Compress
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)

$response = $null
try {
    $response = Invoke-RestMethod -Method Post -Uri $resolvedEndpoint -Headers $headers -Body $bodyBytes -ContentType "application/json; charset=utf-8"
} catch {
    $errMsg = $_.Exception.Message
    if ($hasApiKey -and -not [string]::IsNullOrWhiteSpace($errMsg)) {
        $errMsg = $errMsg.Replace($resolvedKey, "***")
    }
    Write-Error "Image API request failed ($resolvedProvider): $errMsg"
    exit 1
}

$payload = Find-ImagePayload -Node $response
if ($null -eq $payload) {
    Write-Error "No image data or image URL found in API response from provider '$resolvedProvider'."
    exit 1
}

$outDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

if ($payload.kind -eq "b64") {
    $rawB64 = $payload.data
    if ($rawB64 -match '^data:image/[^;]+;base64,(.+)$') {
        $rawB64 = $matches[1]
    }
    $imgBytes = [Convert]::FromBase64String($rawB64)
    [System.IO.File]::WriteAllBytes($OutputPath, $imgBytes)
} elseif ($payload.kind -eq "url") {
    Invoke-WebRequest -Uri $payload.url -OutFile $OutputPath | Out-Null
}

Write-Output "STATUS=OK"
Write-Output "PROVIDER=$resolvedProvider"
Write-Output "MODEL=$resolvedModel"
Write-Output "OUTPUT=$OutputPath"
