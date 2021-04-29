<#
 writeToggle.ps1
.SYNOPSIS 
    Toggles the registry setting "Deny_Write" for all removable storage; running will notify the current status after changing the setting
	.NOTES 
    Author: J.A. Waters | jawaters@jawaters.com | @jawdev | https://github.com/jawcode
#>

# Local globals
$base = "$((Get-Location).toString())\writeEnableCheck";
$writeEnabled = $False;
$regLocs = 		"HKCU:\SOFTWARE\Policies\Microsoft\Windows\",
				"HKLM:\SOFTWARE\Policies\Microsoft\Windows\",
				"HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\",
				"HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\",
				"HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\",
				"HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\",
				"HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\",
				"HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\",
				"HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\",
				"HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\";
				
$regNames =		"RemovableStorageDevices", # Coverall for User
				"RemovableStorageDevices", # Coverall for Computer
				"{53f56308-b6bf-11d0-94f2-00a0c91efb8b}", # CDs and DVDs
				"{53f5630b-b6bf-11d0-94f2-00a0c91efb8b}", # Tape drives
				"{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}", # USB Drives
				"{53f56311-b6bf-11d0-94f2-00a0c91efb8b}", # Floppies
				"{6AC27878-A6FA-4155-BA85-F98F491D4F33}", # WPD devices Type 1
				"{F33FDC04-D1AC-4E8E-9A30-19BBD4B108AE}", # WPD devices Type 2
				"Terminal Services", # Remote desktop local drives
				"Terminal Services"; # Remote desktop clipboard

$regProps = "Deny_Write",
			"Deny_Write",
			"Deny_Write",
			"Deny_Write",
			"Deny_Write",
			"Deny_Write",
			"Deny_Write",
			"Deny_Write",
			"fDisableCdm",
			"fDisableClip";


class Utils {
	[int]genFolders($base) {
		$folderCount = 0;
		
		if (!(Test-Path -Path $base)) {
			Write-Host "Output directory was not found. Generating  $global:base..." -ForegroundColor White;
			New-Item -Path $global:base -ItemType Directory | Out-Null; $folderCount++;
		}
		else { $folderCount++; }
		return $folderCount;
	}
}
$utilRes = New-Object -TypeName Utils;

Function Run-Main {
	# Loop through reg locs; if any are non-existent or set to "0", just attempt to create all and set to 1. If they do exist, check first if it is 1 or 0, set rest based on first one
	Write-Host "Checking current registry settings...";
	
	$keyFound = $True;
	for($i = 0; $i -lt $regLocs.length; $i++) {
		$regKey = $regLocs[$i] + $regNames[$i];
		$cProp = $regProps[$i];
		
		# Check for first key, adjust all based on first found
		if($i -eq 0) { $keyFound = Test-Path $regkey; }
		if(!$keyFound) {			
			New-Item -Path $regLocs[$i] -Name $regNames[$i] -Force | Out-Null;
			Set-ItemProperty -Path $regKey -Name $cProp -Value 1;
		}
		else { if($(Test-Path $regKey)) { Remove-Item -Path $regkey -Recurse -Force | Out-Null; } }
	}
	# Kill explorer to refresh drive access
	Stop-Process -Name 'explorer' -Force;
	
	$lastSet = "disable writing";
	$fileName = "$base\WRITE_DISABLED";
	if($keyFound) { 
		$lastSet = "enable writing";
		Remove-Item $fileName;
		$fileName = "$base\WRITE_ENABLED";
	}
	else { Remove-Item "$base\WRITE_ENABLED"; }
	
	Write-Host "The registry was modified to $lastSet to removable storage.";
	echo "The last run set the registry to $lastSet" > $fileName;
}

# Perform some basic argument processing
$argsProcess = [System.Collections.ArrayList]@();
$argsProcessed = "";
if($args.length -gt 0) {
	switch($args[0]) {
		"/help" { $argsProcess.Add("help") > $null; }
	}
	$argsProcessed = $argsProcess -Join ";";
}
else { $argsProcessed = "NONE"; }

if($argsProcessed.indexOf('help') -lt 0) {
	$resCount = $utilRes.genFolders($base);
		
	if($resCount -eq 1) {
		if($argsProcessed.indexOf('NONE') -gt -1) { Run-Main($argsProcessed); }
	}
}
else {
	Write-Host "";
	Write-Host "-----------------------------------------------------Write Restrict-----------------------------------------------------" -ForegroundColor Yellow;
	Write-Host "This script toggles between enabling or disabling write restrictions for removable media.";
	Write-Host "A log is stored locally in a 'writeEnableCheck' folder relative to the script's run location.";
  Write-Host "The log file simply states whether writing is currently enabled or disabled.";
	Write-Host "Options: None";
}
