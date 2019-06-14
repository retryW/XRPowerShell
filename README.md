# XRPowerShell
A PowerShell Module / API to connect to the XRP Ledger via Websockets

**Usage**

1. Clone this repository or save the contents into a .psm1 file
2. Import the Module
```powershell
Import-Module 
```
3. Connect to a XRPL websocket
```powershell
Connect-XRPL "wss://s1.ripple.com:443"
```
4. Get info on an XRPL address
```powershell
Get-AccountInfo "rpbvDUFjb1RZYfMGoy8ki8itHNEXaeCALE"
```
5. Make any response more readable (but no longer an object)
```powershell
ConvertTo-ReadableJSON $input
```
OR pipe it
```powershell
Get-AccountInfo "rpbvDUFjb1RZYfMGoy8ki8itHNEXaeCALE" | ConvertTo-ReadableJSON
```

6. Query the XRP Ledger with any valid command (yet to be implemented)
```powershell
$txJSON =
'{
    "id": 1,
    "command": "account_lines",
    "account": "rpbvDUFjb1RZYfMGoy8ki8itHNEXaeCALE",
    "ledger": "current"
}'
$tx = Format-TxJSON $txJSON
Send-Transaction $tx
```

7. Disconnect from the XRPL
```powershell
Disconnect-XRPL
```
