# An automated Incident Response information gathering script for Windows 10
This project contains scripts, "irGather.ps1" and "irGather.sh", that gather useful computer information for the purposes of troubleshooting and incident response. The scripts will attempt to run with local-only files, but the PowerShell version does default to the use of several SystemInternals and NirSoft tools. These tools can be downloaded with the script, or they can be pulled by cloning this repo. The Linux script will ask to install packages as needed to complete its process.

## Getting Started
PowerShell
Clone this repo or download the files. On first-run, the script will check for the following directory structure:
./irtools
./irtools/nirsoft
./irtools/sysinternals

If not found, the script will ask if you want to download the external tools. Alternatively, download the zipped tools from this repo and extract them into their appropriate sub-directories.

When ready, the script can be run with the following options:

/update - newly downloads tools, then runs the IR checks
/download - only downloads the tools, does not run IR checks
/hash - hashes the tool ZIPs and compares the hashes on Github; only tests against script-downloaded ZIP files

### Prerequisites
Windows 10; may work with other versions running PowerShell 5.1+

## Getting Started
Linux Script
Clone this repo or download the "irGather.sh" file. On first-run, the script will check for the directory structure:
./irtools

If not found, the folder will be created. If tools to run from the script aren't found, the script will ask if you'd like to use a package manager to install those tools. Answering no will stop the script from running further.

The Linux script can run without arguments, or the -hash argument will hash the compressed files within the ./irtools folder.

### Prerequisites
ifconfig, route, resolvectl, netstat
