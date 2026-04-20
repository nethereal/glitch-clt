# Set UTF-8 encoding for console output to handle emojis correctly
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$url = "http://localhost:9998"
$modelId = "qwen3.6-35b-a3b-iq4xs"
$timeout = 300
$startTime = Get-Date

Write-Host "Waiting for server at $url..." -ForegroundColor Cyan
$ready = $false
while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
    try {
        $response = Invoke-RestMethod -Uri "$url/v1/models" -Method Get -ErrorAction SilentlyContinue
        if ($response) {
            Write-Host "Server is ready! (Found model: $($response.data[0].id))" -ForegroundColor Green
            $ready = $true
            break
        }
    } catch {
        # Continue waiting
    }
    Start-Sleep -Seconds 5
}

if (-not $ready) {
    Write-Host "Timeout waiting for server." -ForegroundColor Red
    exit 1
}

$prompt = "Hello! Can you confirm your name and current context window size?"
Write-Host "`nSending chat request..." -ForegroundColor Yellow
Write-Host "Message: $prompt" -ForegroundColor Gray

$headers = @{ "Content-Type" = "application/json" }
$body = @{
    model = $modelId
    messages = @(
        @{ role = "system"; content = "You are a helpful assistant." },
        @{ role = "user"; content = $prompt }
    )
    max_tokens = 500
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$url/v1/chat/completions" -Method Post -Headers $headers -Body $body
    
    Write-Host "`nResponse from model:" -ForegroundColor Green
    Write-Host "--------------------"
    
    $message = $response.choices[0].message
    $content = $message.content
    $reasoning = $message.reasoning_content

    if ($null -ne $reasoning -and $reasoning -ne "") {
        Write-Host "🧠 THOUGHT PROCESS:" -ForegroundColor DarkCyan
        Write-Host $reasoning -ForegroundColor DarkGray
        Write-Host ""
    }

    if ($null -ne $content -and $content -ne "") {
        Write-Host $content
    } elseif ($null -eq $reasoning -or $reasoning -eq "") {
        Write-Host "(Received completely empty response content.)" -ForegroundColor Yellow
    }
    
    Write-Host "--------------------"
} catch {
    Write-Host "Failed to connect: $_" -ForegroundColor Red
}
