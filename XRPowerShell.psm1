<# 
    XRPowerShell.ps1
    ----------------

    Version: 0.1.4
#>

Function Connect-XRPL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$wssUri
    )

    # Don't let Connect-XRPL overwrite an existing connection.
    if($webSocket) {
        Write-Host "Error! Already connected to a websocket. `n`t- Use Disconnect-XRPL if you wish to close current connection." -ForegroundColor Red
        return
    }

    <#
        These need to be accessible everywhere.
        Testing as static variable. Should only be one of these at any one time
        TODO: Find better alternative to global variables if possible
    #>
    static $Global:webSocket = New-Object System.Net.WebSockets.ClientWebSocket
    static $Global:cancellationToken = New-Object System.Threading.CancellationToken

    try {
        $command = $webSocket.ConnectAsync($wssUri, $cancellationToken)
        while (!$command.IsCompleted) {
            Start-Sleep -Milliseconds 100
        }
        if($webSocket.State -eq 'Open') {
            Write-Host "Connected!" -ForegroundColor Green
        } else {
            Write-Host "Failed to open Websocket!" -ForegroundColor Red
        }
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
        if($webSocket.State -ne 'Open') {
            Write-Host "Disconnected!" -ForegroundColor Yellow
            $webSocket.dispose()
        } else {
            Write-Host "Error! Failed to disconnect websocket." -ForegroundColor Red
        }        
    } catch {
        Write-Host "Error!" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}

Function Get-ServerInfo {

    $txJSON = 
'{
    "command": "server_info"
}'

    $message = Format-txJSON $txJSON
    Send-Message $message
    Receive-Message
}

Function Get-AccountInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$address
    )

    $txJSON = 
'{
    "command": "account_info",
    "account": "_ADDRESS_"
}'
    $txJSON = $txJSON.replace("_ADDRESS_",$address)
    $message = Format-txJSON $txJSON
    Send-Message $message
    Receive-Message
}

<# 
    Websocket object only accepts an array of bytes for their messages.
    All JSON must be converted before being sent
#>
Function Format-txJSON {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$txJSON
    )
    $encoding = [System.Text.Encoding]::UTF8
    $array = @();
    $array = $encoding.GetBytes($txJSON)

    return New-Object System.ArraySegment[byte] -ArgumentList @(,$array)
}

Function Send-Message {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $message
    )
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
    Write-Host "Message sent to server" -ForegroundColor Cyan
}

Function Receive-Message {
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
        Write-Host "Message received from server" -ForegroundColor Green
        return $receiveMsg
    }
}

Function ConvertTo-ReadableJSON {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$inString
    )
    return $inString | ConvertFrom-Json | ConvertTo-Json -Depth 10
}

Export-ModuleMember -Function *
