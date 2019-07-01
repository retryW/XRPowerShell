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

5. Make any response readable from console (but no longer a PowerShell object)

Add `-ToString` to any function. Eg:
```powershell
Get-AccountInfo "rpbvDUFjb1RZYfMGoy8ki8itHNEXaeCALE" -ToString
```

6. Query the XRP Ledger with any valid command JSON
```powershell
$txJSON =
'{
    "id": 1337,
    "command": "account_lines",
    "account": "rpbvDUFjb1RZYfMGoy8ki8itHNEXaeCALE",
    "ledger": "current"
}'
Send-CustomTx $txJSON
```

7. Disconnect from the XRPL
```powershell
Disconnect-XRPL
```
