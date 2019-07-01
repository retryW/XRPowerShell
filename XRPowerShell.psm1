<# 
    XRPowerShell.ps1
    ----------------

    Version: 0.5.0
#>
enum AccountObjectTypes {
    Check
    DepositPreauth
    Escrow
    Offer
    PaymentChannel
    SignerList
    State
}

Function Connect-XRPL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]$wssUri
    )

    # Don't let Connect-XRPL overwrite an existing connection.
    if($webSocket.State -eq 'Open') {
        Write-Host "Error! Already connected to a websocket. `n`t- Use Disconnect-XRPL if you wish to close current connection." -ForegroundColor Red
        return
    }

    <#
        These need to be accessible everywhere.
        TODO: Find better alternative to global variables if possible
    #>
    $Global:webSocket = New-Object System.Net.WebSockets.ClientWebSocket
    $Global:cancellationToken = New-Object System.Threading.CancellationToken
    $Global:wsID = 1

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
            Write-Host "Error! Websocket already disconnected" -ForegroundColor Red
        }        
    } catch {
        Write-Host "Error!" -ForegroundColor Red
        Write-Host $_.Exception.Message
    }
}

#region Server Functions
Function Get-ServerInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON = 
'{
    "id": _ID_,
    "command": "server_info"
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-ServerState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "server_state"
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}
#endregion

#region Utility Functions
Function Get-Fee {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
        $txJSON =
'{
    "id": _ID_,
    "command": "fee"
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Ping-Server {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "ping"
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}
#endregion

#region Account Functions
Function Get-AccountChannels {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [Parameter(Mandatory=$false)]
        [string]$Destination,
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        $LedgerIndex,
        [Parameter(Mandatory=$false)]
        [Int32]$Limit,
        [Parameter(Mandatory=$false)]
        [string]$Marker,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "account_channels",
    "account": "_ADDRESS_",
    _DESTINATION_
    _HASH_
    _LEDGERINDEX_
    _LIMIT_
    _MARKER_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.replace("_ADDRESS_", $Address)
    if ($Destination) {
        $txJSON = $txJSON.Replace("_DESTINATION_", "`"destination_account`": $Destination,")
    } else {
        $txJSON = $txJSON -replace "\s+_DESTINATION_", "`r`n"
    }
    if ($Hash) {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": `"$Hash`",")
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
    } else {
        $txJSON = $txJSON -replace "\s+_HASH_", "`r`n"
        # If -Hash is not used, check for ledger_index.
        if ($LedgerIndex) {
            $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"validated`",")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"closed`",")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"current`",")
                        break;
                    }
                    "" {
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                    default {
                        Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', "`"ledger_index`": $LedgerIndex,")
            } else {
                Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
            }
        } else {
            # No index declared, remove it from the query
            $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
        }
    }
    if ($Limit) {
        $txJSON = $txJSON.Replace("_LIMIT_", "`"limit`": $Limit,")
    } else {
        $txJSON = $txJSON -replace "\s+_LIMIT_", "`r`n"
    }
    if ($MARKER) {
        $txJSON = $txJSON.Replace("_MARKER_", "`"marker`": $Marker")
    } else {
        $txJSON = $txJSON -replace "\s+_MARKER_", "`r`n"
        # Remove comma (,) on last line causing JSON to become invalid (Only required if Marker isn't specified)
        $txJSON = $txJSON -replace ",\s+}", "`r`n}"
    }
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-AccountCurrencies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        $LedgerIndex,
        [Parameter(Mandatory=$false)]
        [switch]$Strict,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON = 
'{
    "id": _ID_,
    "command": "account_info",
    "account": "_ADDRESS_",
    _HASH_
    _LEDGERINDEX_
    "strict": _STRICT_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.replace("_ADDRESS_",$Address)
    if ($Hash) {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": `"$Hash`",")
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
    } else {
        $txJSON = $txJSON -replace "\s+_HASH_", "`r`n"
        # If -Hash is not used, check for ledger_index.
        if ($LedgerIndex) {
            $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"validated`",")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"closed`",")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"current`",")
                        break;
                    }
                    default {
                        Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', "`"ledger_index`": $LedgerIndex,")
            } else {
                Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
            }
        } else {
            $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
        }
    }
    if ($Strict) {
        $txJSON = $txJSON.Replace("_STRICT_", "true")
    } else {
        $txJSON = $txJSON.Replace("_STRICT_", "false")
    }

    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-AccountInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        $LedgerIndex,
        [Parameter(Mandatory=$false)]
        [switch]$Queue,
        [Parameter(Mandatory=$false)]
        [switch]$SignerLists,
        [Parameter(Mandatory=$false)]
        [switch]$Strict,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )

    $txJSON = 
'{
    "id": _ID_,
    "command": "account_info",
    "account": "_ADDRESS_",
    _HASH_
    _LEDGERINDEX_
    "queue": _QUEUE_,
    "signer_lists": _SIGNLISTS_,
    "strict": _STRICT_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.replace("_ADDRESS_",$Address)
    if ($Hash) {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": $Hash,")
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
    } else {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": `"$Hash`",")
        # If -Hash is not used, check for ledger_index.
        if ($LedgerIndex) {
            $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"validated`",")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"closed`",")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"current`",")
                        break;
                    }
                    default {
                        Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', "`"ledger_index`": $LedgerIndex,")
            } else {
                Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
            }
        } else {
            $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
        }
    }
    if ($Queue) {
        $txJSON = $txJSON.Replace("_QUEUE_", "true")
    } else {
        $txJSON = $txJSON.Replace("_QUEUE_", "false")
    }
    if ($SignerLists) {
        $txJSON = $txJSON.Replace("_SIGNLISTS_", "true")
    } else {
        $txJSON = $txJSON.Replace("_SIGNLISTS_", "false")
    }
    if ($Strict) {
        $txJSON = $txJSON.Replace("_STRICT_", "true")
    } else {
        $txJSON = $txJSON.Replace("_STRICT_", "false")
    }

    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-AccountLines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        $LedgerIndex,
        [Parameter(Mandatory=$false)]
        [string]$Peer,
        [Parameter(Mandatory=$false)]
        [Int32]$Limit,
        [Parameter(Mandatory=$false)]
        [Int32]$Marker,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )

    $txJSON =
'{
    "id": _ID_,
    "command": "account_lines",
    "account": "_ADDRESS_",
    _HASH_
    _LEDGERINDEX_
    _PEER_
    _LIMIT_
    _MARKER_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.Replace("_ADDRESS_", $Address)
    if ($Hash) {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": `"$Hash`",")
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
    } else {
        $txJSON = $txJSON -replace "\s+_HASH_", "`r`n"
        # If -Hash is not used, check for ledger_index.
        if ($LedgerIndex) {
            $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"validated`",")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"closed`",")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"current`",")
                        break;
                    }
                    default {
                        Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', "`"ledger_index`": $LedgerIndex,")
            } else {
                Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
            }
        } else {
            $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
        }
    }
    if ($Peer) {
        $txJSON = $txJSON.Replace("_PEER_", "`"peer`": `"$Peer`",")
    } else {
        $txJSON = $txJSON -replace "\s+_PEER_", "`r`n"
    }
    if ($Limit) {
        $txJSON = $txJSON.Replace("_LIMIT_", "`"limit`": $Limit,")
    } else {
        $txJSON = $txJSON -replace "\s+_LIMIT_", "`r`n"
    }
    if ($Marker) {
        $txJSON = $txJSON.Replace("_MARKER_", "`"marker`": $Marker")
    } else {
        $txJSON = $txJSON -replace "\s+_MARKER_", "`r`n"
        # Remove comma (,) on last line causing JSON to become invalid (Only required if Marker isn't specified)
        $txJSON = $txJSON -replace ",\s+}", "`r`n}"
    }

    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-AccountObjects {
        [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [Parameter(Mandatory=$false)]
        [AccountObjectTypes]$Type,
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        $LedgerIndex,
        [Parameter(Mandatory=$false)]
        [string]$Peer,
        [Parameter(Mandatory=$false)]
        [Int32]$Limit,
        [Parameter(Mandatory=$false)]
        [Int32]$Marker,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )

    $txJSON =
'{
    "id": _ID_,
    "command": "account_objects",
    "account": "_ADDRESS_",
    _TYPE_
    _HASH_
    _LEDGERINDEX_
    _LIMIT_
    _MARKER_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.Replace("_ADDRESS_", $Address)
    if ($Type) {
        $txJSON = $txJSON.Replace("_TYPE_", "`"type`": `"$Type`",")
    } else {
        $txJSON = $txJSON -replace "\s+_TYPE_", "`r`n"
    }
    if ($Hash) {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": `"$Hash`",")
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
    } else {
        $txJSON = $txJSON -replace "\s+_HASH_", "`r`n"
        # If -Hash is not used, check for ledger_index.
        if ($LedgerIndex) {
            $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"validated`",")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"closed`",")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"current`",")
                        break;
                    }
                    default {
                        Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', "`"ledger_index`": $LedgerIndex,")
            } else {
                Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
            }
        } else {
            $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
        }
    }
    if ($Limit) {
        $txJSON = $txJSON.Replace("_LIMIT_", "`"limit`": $Limit,")
    } else {
        $txJSON = $txJSON -replace "\s+_LIMIT_", "`r`n"
    }
    if ($Marker) {
        $txJSON = $txJSON.Replace("_MARKER_", "`"marker`": $Marker")
    } else {
        $txJSON = $txJSON -replace "\s+_MARKER_", "`r`n"
        # Remove comma (,) on last line causing JSON to become invalid (Only required if Marker isn't specified)
        $txJSON = $txJSON -replace ",\s+}", "`r`n}"
    }

    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-AccountOffers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [Parameter(Mandatory=$false)]
        [Int32]$Limit,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "account_offers",
    "account": "_ADDRESS_",
    _HASH_
    _LEDGERINDEX_
    _LIMIT_
    _MARKER_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.replace("_ADDRESS_", $Address)
    if ($Hash) {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": `"$Hash`",")
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
    } else {
        $txJSON = $txJSON -replace "\s+_HASH_", "`r`n"
        # If -Hash is not used, check for ledger_index.
        if ($LedgerIndex) {
            $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"validated`",")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"closed`",")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"current`",")
                        break;
                    }
                    default {
                        Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', "`"ledger_index`": $LedgerIndex,")
            } else {
                Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
            }
        } else {
            $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
        }
    }
    if ($Limit) {
        $txJSON = $txJSON.Replace("_LIMIT_", "`"limit`": $Limit,")
    } else {
        $txJSON = $txJSON -replace "\s+_LIMIT_", "`r`n"
    }
    if ($Marker) {
        $txJSON = $txJSON.Replace("_MARKER_", "`"marker`": $Marker")
    } else {
        $txJSON = $txJSON -replace "\s+_MARKER_", "`r`n"
        # Remove comma (,) on last line causing JSON to become invalid (Only required if Marker isn't specified)
        $txJSON = $txJSON -replace ",\s+}", "`r`n}"
    }

    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-AccountTx {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        [string]$LedgerIndex,
        [Parameter(Mandatory=$false)]
        [Int32]$Limit,
        [Parameter(Mandatory=$false)]
        [string]$Marker,
        [Parameter(Mandatory=$false)]
        [Int32]$LedgerMax,
        [Parameter(Mandatory=$false)]
        [Int32]$LedgerMin,
        [Parameter(Mandatory=$false)]
        [Switch]$Binary,
        [Parameter(Mandatory=$false)]
        [Switch]$Forward,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "account_tx",
    "account": "_ADDRESS_",
    _HASH_
    _LEDGERINDEX_
    _LIMIT_
    _MARKER_
    "ledger_index_min": _MIN_,
    "ledger_index_max": _MAX_,
    "binary": _BINARY_,
    "forward": _FORWARD_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.replace("_ADDRESS_", $Address)
    if ($Hash) {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": `"$Hash`",")
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
    } else {
        $txJSON = $txJSON -replace "\s+_HASH_", "`r`n"
        # If -Hash is not used, check for ledger_index.
    if ($LedgerIndex) {
        $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"validated`",")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"closed`",")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"current`",")
                        break;
                    }
                    default {
                        Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', "`"ledger_index`": $LedgerIndex,")
            } else {
                Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
            }
        } else {
            $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
        }
    }
    if ($Limit) {
        $txJSON = $txJSON.Replace("_LIMIT_", "`"limit`": $Limit,")
    } else {
        $txJSON = $txJSON -replace "\s+_LIMIT_", "`r`n"
    }
    if ($Marker) {
        $txJSON = $txJSON.Replace("_MARKER_", "`"marker`": `"$Marker`",")
    } else {
        $txJSON = $txJSON -replace "\s+_MARKER_", "`r`n"
    }
    if ($LedgerMin) {
        $txJSON = $txJSON.Replace("_MIN_", $LedgerMin)
    } else {
        $txJSON = $txJSON.Replace("_MIN_", "-1")
    }
    if ($LedgerMax) {
        $txJSON = $txJSON.Replace("_MAX_", $LedgerMax)
    } else {
        $txJSON = $txJSON.Replace("_MAX_", "-1")
    }
    if ($Binary) {
        $txJSON = $txJSON.Replace("_BINARY_", "true")
    } else {
        $txJSON = $txJSON.Replace("_BINARY_", "false")
    }
    if ($Forward) {
        $txJSON = $txJSON.Replace("_FORWARD_", "true")
    } else {
        $txJSON = $txJSON.Replace("_FORWARD_", "false")
    }
    
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-GatewayBalances {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        [string]$LedgerIndex,
        [Parameter(Mandatory=$false)]
        $HotWallet,
        [Parameter(Mandatory=$false)]
        [switch]$Strict,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "account_tx",
    "account": "_ADDRESS_",
    _HASH_
    _LEDGERINDEX_
    _HOTWALLET_
    "strict": _STRICT_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.replace("_ADDRESS_", $Address)
    if ($Hash) {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": `"$Hash`",")
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
    } else {
        $txJSON = $txJSON -replace "\s+_HASH_", "`r`n"
        # If -Hash is not used, check for ledger_index.
    if ($LedgerIndex) {
        $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"validated`",")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"closed`",")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"current`",")
                        break;
                    }
                    default {
                        Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', "`"ledger_index`": $LedgerIndex,")
            } else {
                Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
            }
        } else {
            $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
        }
    }
    if ($HotWallet) {
        if ($HotWallet.GetType().Name -eq "String") {
            $txJSON = $txJSON.Replace('"_HOTWALLET_"', "`"hotwallet`": `"$HotWallet`",")
        } elseif ($HotWallet.GetType().Name -eq "Object[]") {
            $walletStr = "["
            foreach ($wallet in $HotWallet) {
                if ($wallet.GetType().Name -eq "String") {
                    $walletStr += "`"$wallet`","
                } else {
                    $txJSON = $txJSON -replace "\s+_HOTWALLET_", "`r`n"
                    break
                }
            }
            # Remove extra ',' from end of string
            $walletStr = $walletStr.Substring(0,$walletStr.Length-1) + "]"
            $txJSON = $txJSON.Replace('"_HOTWALLET_"', "`"hotwallet`": $LedgerIndex,")
        } else {
            $txJSON = $txJSON -replace "\s+_HOTWALLET_", "`r`n"
        }
    } else {
        $txJSON = $txJSON -replace "\s+_HOTWALLET_", "`r`n"
    }
    if ($Strict) {
        $txJSON = $txJSON.Replace("_STRICT_", "true")
    } else {
        $txJSON = $txJSON.Replace("_STRICT_", "false")
    }

    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-NoRippleCheck {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Address,
        [Parameter(Mandatory=$true)]
        [string]$Role,
        [Parameter(Mandatory=$false)]
        [Switch]$Transactions,
        [Parameter(Mandatory=$false)]
        [Int32]$Limit,
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        $LedgerIndex,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
        
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "noripple_check",
    "account": "_ADDRESS_",
    "role": "_ROLE_",
    _LIMIT_
    _HASH_
    _LEDGERINDEX_
    "transactions": _TRANSACTIONS_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.replace("_ADDRESS_", $Address)
    $txJSON = $txJSON.replace("_ROLE_", $Role)
    if ($Hash) {
        $txJSON = $txJSON.Replace("_HASH_", "`"ledger_hash`": `"$Hash`",")
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
    } else {
        $txJSON = $txJSON -replace "\s+_HASH_", "`r`n"
        # If -Hash is not used, check for ledger_index.
        if ($LedgerIndex) {
            $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"validated`",")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"closed`",")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace("_LEDGERINDEX_", "`"ledger_index`": `"current`",")
                        break;
                    }
                    default {
                        Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                        $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', "`"ledger_index`": $LedgerIndex,")
            } else {
                Write-Host "Invalid input. Tx sent but ledger_index has been omitted" -ForegroundColor Yellow
                $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
            }
        } else {
            $txJSON = $txJSON -replace "\s+_LEDGERINDEX_", "`r`n"
        }
    }
    if ($Limit) {
        $txJSON = $txJSON.Replace("_LIMIT_", "`"limit`": $Limit,")
    } else {
        $txJSON = $txJSON -replace "\s+_LIMIT_", "`r`n"
    }
    if ($Transactions) {
        $txJSON = $txJSON.Replace("_TRANSACTIONS_", "true")
    } else {
        $txJSON = $txJSON.Replace("_TRANSACTIONS_", "false")
    }

    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}
#endregion

#region Ledger Functions
Function Get-Ledger {
    [CmdletBinding()]
    param (
        # I hate variables starting with uppercase. But being a -Switch, looks stupid lowercase.
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        $LedgerIndex,
        [Parameter(Mandatory=$false)]
        [switch]$Full,
        [Parameter(Mandatory=$false)]
        [switch]$Accounts,
        [Parameter(Mandatory=$false)]
        [switch]$Transactions,
        [Parameter(Mandatory=$false)]
        [switch]$Expand,
        [Parameter(Mandatory=$false)]
        [switch]$Binary,
        [Parameter(Mandatory=$false)]
        [switch]$Queue,
        [Parameter(Mandatory=$false)]
        [switch]$OwnerFunds,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "ledger",
    "ledger_hash": "_LEDGERHASH_",
    "ledger_index": "_LEDGERINDEX_",
    "full": _FULL_,
    "accounts": "_ACCOUNTS_",
    "transactions": _TRANSACTIONS_,
    "expand": _EXPAND_,
    "binary": _BINARY_,
    "queue": _QUEUE_,
    "owner_funds": _OWNERFUNDS_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    if ($Hash) {
        $txJSON = $txJSON.Replace('_LEDGERHASH_', $Hash)
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON.Replace('    "ledger_index": "_LEDGERINDEX_",', "")
    } else {
        $txJSON = $txJSON.Replace('    "ledger_hash": "_LEDGERHASH_",', "")
        
        # If -Hash is not used, check for ledger_index.
        if ($LedgerIndex) {
            $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace('_LEDGERINDEX_', "validated")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace('_LEDGERINDEX_', "closed")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace('_LEDGERINDEX_', "current")
                        break;
                    }
                    default {
                        $txJSON = $txJSON.Replace('    "ledger_index": "_LEDGERINDEX_",', "")
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', $LedgerIndex)
            } else {
                $txJSON = $txJSON.Replace('    "ledger_index": "_LEDGERINDEX_",', "")
            }
        } else {
            $txJSON = $txJSON.Replace('    "ledger_index": "_LEDGERINDEX_",', "")
        }
    }
    if ($Full) {
        $txJSON = $txJSON.Replace("_FULL_", "true")
    } else {
        $txJSON = $txJSON.Replace("_FULL_", "false")
    }
    if ($Accounts) {
        $txJSON = $txJSON.Replace("_ACCOUNTS_", "true")
    } else {
        $txJSON = $txJSON.Replace("_ACCOUNTS_", "false")
    }
    if ($Transactions) {
        $txJSON = $txJSON.Replace("_TRANSACTIONS_", "true")
    } else {
        $txJSON = $txJSON.Replace("_TRANSACTIONS_", "false")
    }
    if ($Expand) {
        $txJSON = $txJSON.Replace("_EXPAND_", "true")
    } else {
        $txJSON = $txJSON.Replace("_EXPAND_", "false")
    }
    if ($Binary) {
        $txJSON = $txJSON.Replace("_BINARY_", "true")
    } else {
        $txJSON = $txJSON.Replace("_BINARY_", "false")
    }
    if ($Queue) {
        $txJSON = $txJSON.Replace("_QUEUE_", "true")
    } else {
        $txJSON = $txJSON.Replace("_QUEUE_", "false")
    }
    if ($OwnerFunds) {
        $txJSON = $txJSON.Replace("_OWNERFUNDS_", "true")
    } else {
        $txJSON = $txJSON.Replace("_OWNERFUNDS_", "false")
    }

    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-LedgerClosed {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "ledger_closed"    
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-LedgerCurrent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "ledger_current"    
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-LedgerData {
        [CmdletBinding()]
    param (
        # I hate variables starting with uppercase. But being a -Switch, looks stupid lowercase.
        [Parameter(Mandatory=$false)]
        [string]$Hash,
        [Parameter(Mandatory=$false)]
        $LedgerIndex,
        [Parameter(Mandatory=$false)]
        [switch]$Binary,
        [Parameter(Mandatory=$false)]
        [Int32]$Limit,
        [Parameter(Mandatory=$false)]
        [string]$Marker,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "ledger_data",
    "ledger_hash": "_LEDGERHASH_",
    "ledger_index": "_LEDGERINDEX_",
    _LIMIT_
    _MARKER_
    "binary": _BINARY_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    if ($Hash) {
        $txJSON = $txJSON.Replace('_LEDGERHASH_', $Hash)
        # If -Hash is used, we don't want to also specify a ledger_index.
        $txJSON = $txJSON.Replace('    "ledger_index": "_LEDGERINDEX_",', "")
    } else {
        $txJSON = $txJSON.Replace('    "ledger_hash": "_LEDGERHASH_",', "")
        
        # If -Hash is not used, check for ledger_index.
        if ($LedgerIndex) {
            $type = $LedgerIndex.GetType().Name
            if ($type -eq "String") {
                switch($LedgerIndex) {
                    "validated" {
                        $txJSON = $txJSON.Replace('_LEDGERINDEX_', "validated")
                        break;
                    }
                    "closed" {
                        $txJSON = $txJSON.Replace('_LEDGERINDEX_', "closed")
                        break;
                    }
                    "current" {
                        $txJSON = $txJSON.Replace('_LEDGERINDEX_', "current")
                        break;
                    }
                    default {
                        $txJSON = $txJSON.Replace('    "ledger_index": "_LEDGERINDEX_",', "")
                        break;
                    }
                }
            } elseif ($type -eq "Int32" -or $type -eq "Decimal") {
                $txJSON = $txJSON.Replace('"_LEDGERINDEX_"', $LedgerIndex)
            } else {
                $txJSON = $txJSON.Replace('    "ledger_index": "_LEDGERINDEX_",', "")
            }
        } else {
            $txJSON = $txJSON.Replace('    "ledger_index": "_LEDGERINDEX_",', "")
        }
    }
    if ($Limit) {
        $txJSON = $txJSON.Replace("_LIMIT_", "`"limit`": $Limit,")
    } else {
        $txJSON = $txJSON -replace "\s+_LIMIT_", "`r`n"
    }
    if ($Marker) {
        $txJSON = $txJSON.Replace("_MARKER_", "`"marker`": `"$Marker`",")
    } else {
        $txJSON = $txJSON -replace "\s+_MARKER_", "`r`n"
    }
    if ($Binary) {
        $txJSON = $txJSON.Replace("_BINARY_", "true")
    } else {
        $txJSON = $txJSON.Replace("_BINARY_", "false")
    }

    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-LedgerEntry {
 # TODO
}
#endregion

#region Transaction Functions
Function Submit-Transaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Transaction,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "submit",
    "tx_blob": "_BLOB_"   
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.Replace("_BLOB_", $Transaction)
    
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Submit-MultiSigned {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$txJSON,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )

    Send-Message (Format-txJSON $txJSON)
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Get-Transaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Transaction,
        [Parameter(Mandatory=$false)]
        [switch]$Binary,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    $txJSON =
'{
    "id": _ID_,
    "command": "tx",
    "transaction": "_TRANSACTION_",
    "binary": _BINARY_
}'
    $txJSON = $txJSON.replace("_ID_", $wsID)
    $txJSON = $txJSON.Replace("_TRANSACTION_", $Transaction)
    if ($Binary) {
        $txJSON = $txJSON.Replace("_BINARY_", "true")
    } else {
        $txJSON = $txJSON.Replace("_BINARY_", "false")
    }
    
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}

Function Send-CustomTx {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$txJSON,
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
    Send-Message (Format-txJSON $txJSON)
    $Global:wsID++
    if($ToString) {
        Receive-Message -ToString
    } else {
        Receive-Message
    }
}
#endregion

#region Helper Functions
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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [switch]$ToString
    )
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
        if ($ToString) {
            return $receiveMsg | ConvertFrom-Json | ConvertTo-Json -Depth 10
        } else {
            return $receiveMsg | ConvertFrom-Json
        }
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
#endregion

Export-ModuleMember -Function *
