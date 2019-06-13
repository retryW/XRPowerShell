# XRPowerShell
A PowerShell Module / API to connect to the XRP Ledger via Websockets

*Usage*

1. Clone this repository or save the contents into a .psm1 file
2. Import the Module
```powershell
Import-Module 
```
3. Connect to a XRPL websocket
```powershell
Connect-XRPL "wss://s1.ripple.com:443"
```
4. Get info on the rippled server
```powershell
Get-ServerInfo
```
5. Query the XRP Ledger
```powershell
Send-Transaction
```
