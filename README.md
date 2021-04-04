# An automated Incident Response information gathering script for Windows 10
This project contains a script, "irGather.ps1", that gathers useful computer information for the purposes of troubleshooting and incident response. The script will attempt to run with local-only files, but it does default to the use of several SystemInternals and NirSoft tools. These tools can be downloaded with the script, or they can be pulled by cloning this repo.

## Getting Started
Clone this repo or download the files. On first-run, the script will check for the following directory structure:
./irtools
./irtools/nirsoft
./irtools/sysinternals

If not found, the script will ask if you want to download the external tools. Alternatively, download the zipped tools form this repo and extract them into their appropriate sub-directories.

When ready, the script can be run with the following options:

/update - newly downloads tools, then runs the IR checks
/download - only downloads the tools, does not run IR checks
/hash - hashes the tool ZIPs and compares the hashes on Github; only tests against script-downloaded ZIP files

### Prerequisites
Windows 10; may work with other versions running PowerShell 6+
