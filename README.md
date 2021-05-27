# Data Manip and Information Gathering Scripts
This project contains assorted scripts for manipulating or gathering data.

# IR Gather
These scripts, "irGather.ps1" and "irGather.sh", gather useful computer information for the purposes of troubleshooting and incident response. The scripts attempt to run with local-only files, but the PowerShell version does default to the use of several SystemInternals and NirSoft tools. These tools can be downloaded with the script, or they can be pulled by cloning this repo. The Linux script will ask to install packages as needed to complete its process.

For Windows, the script may work any versions running PowerShell 5.1+
For Linux, the script requires ifconfig, route, resolvectl, and netstat

# Python File Obfuscation
The script "pyObfuscation.py" uses Python to play with detecting and hiding information within files. In its current form, the script returns file types, encrypts file data and embeds that in a new file, and then injects false file signatures to misdirect the nature of a file on a cursory glance.
