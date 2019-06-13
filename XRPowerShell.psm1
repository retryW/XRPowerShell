## XRPowerShell.ps1

Function Connect-XRPL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$wssUri
    )
    $Global:webSocket = New-Object System.Net.WebSockets.ClientWebSocket
    $Global:cancellationToken = New-Object System.Threading.CancellationToken

    try {
        $command = $webSocket.ConnectAsync($wssUri, $cancellationToken)
        while (!$command.IsCompleted) {
            Start-Sleep -Milliseconds 100
        }
        Write-Host "Connected!" -ForegroundColor Green
    } catch {
        Write-Host "Error!" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
    Export-ModuleMember -Variable $webSocket,$cancelToken
}

Function Disconnect-XRPL {
    try {
        $command = $webSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Client disconnect request. Closing web socket.", $cancellationToken)
        while (!$command.IsCompleted) {
            Start-Sleep -Milliseconds 100
        }
        Write-Host "Disconnected!" -ForegroundColor Yellow
    } catch {
        Write-Host "Error!" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}

Export-ModuleMember -Function *
