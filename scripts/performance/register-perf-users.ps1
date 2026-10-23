[CmdletBinding()]
param(
    [string]$BaseUrl = "https://api.ankangxai.cn",

    [ValidateRange(1, 1000)]
    [int]$Count = 100,

    [ValidateNotNullOrEmpty()]
    [string]$Prefix = "perf_user_",

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Password,

    [ValidateRange(0, 10000)]
    [int]$DelayMilliseconds = 150,

    [string]$OutputDirectory = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
$normalizedBaseUrl = $BaseUrl.TrimEnd("/")

if ($Password.Length -lt 6) {
    throw "Password must contain at least 6 characters."
}

$maximumUsername = "$Prefix$($Count.ToString('000'))"
if ($maximumUsername.Length -gt 20) {
    throw "Generated username '$maximumUsername' exceeds the 20-character limit. Shorten Prefix."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$resultPath = Join-Path $OutputDirectory "perf-register-results.csv"
$usernamePath = Join-Path $OutputDirectory "perf-usernames.json"

$results = [System.Collections.Generic.List[object]]::new()
$successfulUsernames = [System.Collections.Generic.List[string]]::new()

Write-Host "Target: $normalizedBaseUrl"
Write-Host "Accounts: $Prefix$($Count.ToString('000')) (count: $Count)"
Write-Host "The password will not be written to result files."

for ($index = 1; $index -le $Count; $index++) {
    $username = "$Prefix$($index.ToString('000'))"
    $requestBody = @{
        username        = $username
        password        = $Password
        confirmPassword = $Password
        phone           = ""
    } | ConvertTo-Json -Compress

    $startedAt = Get-Date
    try {
        $response = Invoke-RestMethod `
            -Uri "$normalizedBaseUrl/api/auth/register" `
            -Method Post `
            -ContentType "application/json" `
            -Body $requestBody `
            -TimeoutSec 20

        $success = $response.code -eq 200
        $message = [string]$response.message

        if ($success) {
            $successfulUsernames.Add($username)
            Write-Host "[$index/$Count] $username registered" -ForegroundColor Green
        }
        else {
            Write-Host "[$index/$Count] $username rejected: $message" -ForegroundColor Yellow
        }

        $results.Add([PSCustomObject]@{
            Username   = $username
            Success    = $success
            Message    = $message
            HttpStatus = 200
            DurationMs = [math]::Round(((Get-Date) - $startedAt).TotalMilliseconds)
        })
    }
    catch {
        $httpStatus = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $httpStatus = [int]$_.Exception.Response.StatusCode
        }

        $results.Add([PSCustomObject]@{
            Username   = $username
            Success    = $false
            Message    = $_.Exception.Message
            HttpStatus = $httpStatus
            DurationMs = [math]::Round(((Get-Date) - $startedAt).TotalMilliseconds)
        })

        Write-Host "[$index/$Count] $username request failed: $($_.Exception.Message)" `
            -ForegroundColor Red
    }

    if ($DelayMilliseconds -gt 0 -and $index -lt $Count) {
        Start-Sleep -Milliseconds $DelayMilliseconds
    }
}

$results |
    Export-Csv -LiteralPath $resultPath -NoTypeInformation -Encoding UTF8

ConvertTo-Json -InputObject $successfulUsernames.ToArray() |
    Set-Content -LiteralPath $usernamePath -Encoding UTF8

$successCount = $successfulUsernames.Count
$failureCount = $Count - $successCount

Write-Host ""
Write-Host "Batch registration finished"
Write-Host "Succeeded: $successCount"
Write-Host "Failed: $failureCount"
Write-Host "Results: $resultPath"
Write-Host "Usernames: $usernamePath"

if ($failureCount -gt 0) {
    Write-Warning "Some accounts failed. Inspect perf-register-results.csv before retrying."
    exit 2
}
