####################################################
#
# Title:         locknpwn
# Author:        p3rki3
# Version:       1.0
# Category:      Prank
# Target:        Windows 10
# 
# Example prank payload for the Bashbunny Powershell Framework.  Bashbunny
# can be removed when the LED goes green.  Powershell scripts runs in a 
# hidden powershell window in unattended mode
#
# Waits 5 minutes (300 seconds) and then triggers rest of the payload
# Volume on the computer speaker is turned up (and off if already off)
# Warns the unsuspecting user that they didn't lock their computer while 
# they were away from their desk and they should have done, because now
# they've been hacked.
# Computer is locked 
# Randomly every 10-30 seconds the computer reminds them that they have been pwned
#
####################################################
# First off, just go to sleep for 5 minutes and give the unsuspecting user time to return to his/her desk
Start-Sleep -Seconds 300
# Now we are going to use a comObject to turn up/on the speaker volume (turn down 30% and then up 30%, so we get a minimum vol of 30%
$wshShell = new-object -com wscript.shell
for($i=0; $i -le 14; $i++) { $wshShell.SendKeys([char]174) }
for($i=0; $i -le 14; $i++) { $wshShell.SendKeys([char]175) }

# Now we are going to use some .NET scripting to access the speech synthesis API
Add-Type -AssemblyName System.Speech
$SpeechSynth = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer
$SpeechSynth.Speak("Oh no! You didn't lock me and left me unattended! I've been hacked!")
Start-Sleep -Seconds 1

# Now we are going to lock the workstation and remind the user what they should have done
$SpeechSynth.Speak("You should have locked me, like this!")
$CmdString = {rundll32.exe user32.dll,LockWorkStation}
Invoke-Command $CmdString

# Finally, just to be really annoying, we are going to nag-remind the user that they've been pwned; and no, muting the PC doesn't stop us as we 
# just keep turning the volume back on
while($True) {
    for($i=0; $i -le 14; $i++) { $wshShell.SendKeys([char]174) }
    for($i=0; $i -le 14; $i++) { $wshShell.SendKeys([char]175) }
    $SpeechSynth.Speak("Warning! Your Computer has been pwned!")
    Start-Sleep -Seconds (Get-Random -Minimum 10 -Maximum 30)
}
