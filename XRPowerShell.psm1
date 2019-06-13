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
    Export-ModuleMember -Variable $webSocket,$cancellationToken
}

Function Disconnect-XRPL {
    try {
        $command = $webSocket.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "Client disconnect request. Closing web socket.", $cancellationToken)
        while (!$command.IsCompleted) {
            Start-Sleep -Milliseconds 100
        }
        Write-Host "Disconnected!" -ForegroundColor Yellow
        $webSocket.dispose()
    } catch {
        Write-Host "Error!" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}

Function Get-ServerInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$ToConsole
    )

    $txJSON = 
'{
    "id": 1,
    "command": "server_info"
}'

    #$txJSON = (New-Object -TypeName PSObject -Prop $tx) | ConvertTo-Json
    $encoding = [System.Text.Encoding]::UTF8
    $array = @();
    $array = $encoding.GetBytes($txJSON)

    $message = New-Object System.ArraySegment[byte] -ArgumentList @(,$array)
    $command = $webSocket.SendAsync($message, [System.Net.WebSockets.WebSocketMessageType]::Text, [System.Boolean]::TrueString, $cancellationToken)
    
    $start = Get-Date
    $timeout = 30
    while (!$command.IsCompleted) {
        $elapsed = ((Get-Date) - $start).Seconds
        if($elapsed -gt $timeout) {
            Write-Host "Warning! Message took longer than $timeout and may not have been sent."
            return
        }
        Start-Sleep -Milliseconds 100
    }
    Write-Host "Message sent to server"

    $size = 1024
    $array = [byte[]] @(,0) * $size
    $receiveArr = New-Object System.ArraySegment[byte] -ArgumentList @(,$array)

    $receiveMsg = ""
    if($webSocket.State -eq 'Open') {
        Do {
            $command = $webSocket.ReceiveAsync($receiveArr, $cancellationToken)
            while (!$command.IsCompleted) {
                Start-Sleep -Milliseconds 100
            }
            $receiveArr.Array[0..($command.Result.Count - 1)] | foreach {$receiveMsg += [char]$_}
        } until ($command.Result.Count -lt $size)
    }
    if ($receiveMsg) {
        if(!$ToConsole) {
            return $inputObj = $receiveMsg
        } else {
            Write-Host (ConvertTo-ReadableJSON $receiveMsg)
        }
    }
}

Function ConvertTo-ReadableJSON {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$inString
    )
    return $inString | ConvertFrom-Json | ConvertTo-Json -Depth 10
}

Export-ModuleMember -Function *
