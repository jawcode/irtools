<#
.SYNOPSIS 
    Function Run-Complete - downloads Sysinternals/NirSoft, uses tools to gather IR information, outputs txt file summary and zipped results
	Options: 
		/update - download tools to update them and then continues running the gathering script
		/download - only downloads the tools; allows for update without gathering details
		/hash - hashes the tool ZIPs and compares them with the online versions
.NOTES 
    Author: J.A. Waters | jawaters@jawaters.com | @jawdev | https://github.com/jawcode
#>
# Load namespaces
using assembly System.Net.Http;
using namespace System.Net.Http;

# Set error policy
$ErrorActionPreference = "Stop";

# Configure for private LANs / untrusted certificate environments
add-type @"
	using System.Net;
	using System.Security.Cryptography.X509Certificates;
	public class TrustAllCertsPolicy : ICertificatePolicy {
		public bool CheckValidationResult(
			ServicePoint srvPoint, X509Certificate certificate,
			WebRequest request, int certificateProblem) {
			return true;
		}
	}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy;
# Force PowerShell to use additional TLS capability
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS, [Net.SecurityProtocolType]::TLS11, [Net.SecurityProtocolType]::TLS12, [Net.SecurityProtocolType]::SSL3;
[Net.ServicePointManager]::SecurityProtocol = "TLS, TLS11, TLS12, SSL3";

# Local globals
$adminName = "Unassigned";
$base = (Get-Location).toString() + "\irtools";
$files = "sysinternalsTools.zip", "nirsoftTools.zip";
$filesAlt = "sysInternalsToolsA.zip", "sysInternalsToolsB.zip", "nirsoftTools.zip";
$baseUrl = "https://nobutwhy.com/files/";
$baseUrlAlt = "https://github.com/jawcode/irtools/raw/main/";
$folders = "$base", "$base\sysinternals", "$base\nirsoft";
$fIndex = @{'sysinternals' = 1; 'nirsoft' = 2;};
$startTime = $(Get-Date -Format "dddd MM/dd/yyyy HH:mm:ss K");
$datePrefix = $(Get-Date -Format "yyyyMMdd-mmss");
$outPrefix = $base + "\" + $datePrefix + "_" + $(HOSTNAME);

class Utils {
	[string]checkHashes([string[]]$files, [string]$base) {		
		$valid = "UNKNOWN";
		$sysActual = $(wget https://raw.githubusercontent.com/jawcode/irtools/main/sysinternalsHash.txt).Content;
		$nirActual = $(wget https://raw.githubusercontent.com/jawcode/irtools/main/nirHash.txt).Content;
		
		$hashes = $sysActual, $nirActual;
		Write-Host $hashes[0];
		Write-Host $files[0];
		
		$validCount = 0;
		for($i = 0; $i -lt $files.length; $i++) {
			$fileName = $files[$i];
			$curFile = $base + "\" + $files[$i];
			$curHash = $(Get-FileHash $curFile).Hash.toString().Trim();
			$validHash = $hashes[$i].toString().Trim();
			
			$outColor = "White";
			$passFail = "PASS";
			$numOut = $i + 1;
			if($curHash -ne $validHash) { $outColor = "Red"; $passFail = "FAIL"; }
			else { $validCount++; }
			Write-Host "File $numOut - $fileName`:`n$validHash - reference`n$curHash - local $passFail `n" -ForegroundColor $outColor;
		}
		
		$maxCount = $files.length;
		Write-Host "$validCount of $maxCount passed.";
		if($validCount -eq $maxCount) { $valid = "valid"; }
		else { $valid = "invalid"; }
		
		Write-Host -NoNewLine "The hashes were found to be ";
		Write-Host -NoNewLine $valid -ForegroundColor Yellow;
		$startRun = Read-Host -Prompt '. Run the information gathering tool? [(Y)es/(N)o]';
		if($startRun.toLower()[0] -eq 'y') { Build-Data; }
		
		return $valid;
	}
	[int]genFolders($folders) {
		$folderCount = 0;
		$warning = $False;
		$downloadResponse = "UNK";
		
		for($i = 0; $i -lt $folders.length; $i++) {
			if (!(Test-Path -Path $folders[$i])) {
				if(!($warning)) {
					$downloadResponse = Read-Host -Prompt 'SysInternals and NirSoft tools were not found. Do you want to download them now? [(Y)es/(N)o]';
					
					if($downloadResponse.toLower()[0] -eq 'y') { Write-Host "Directories were not found. Generating..." -ForegroundColor White; $warning = $True; }
					else {
						Write-Host "The tools are required to continue. Pre-download them, or allow them to download to continue. Exiting." -ForegroundColor "Red";
						$folderCount = -1;
						break;
					}
				}
				if($downloadResponse.toLower()[0] -eq 'y') { New-Item -Path $folders[$i] -ItemType Directory -Verbose | Out-Null; $folderCount++; }
			}
			else { $folderCount++; }
		}
		if($downloadResponse.toLower()[0] -eq 'y') { Download-Files; }
		
		return $folderCount;
	}
	[string]portsDetail() {
		$res = $(netstat -an)[3..$(netstat -an).count];
		
		return $res;
	}
	[string]ports() {
		$res = "";
		$local = $(netstat -an)[3..$(netstat -an).count] | ConvertFrom-String | select p3;
		$remote = $(netstat -an)[3..$(netstat -an).count] | ConvertFrom-String | select p4;
		
		$localString = ($local | ForEach-Object {$_.P3.toString().split(":")[1]});
		$remoteString = ($remote | ForEach-Object {$_.P4.toString().split(":")[1]});
		
		$outLocal = [System.Collections.ArrayList]@();
		ForEach ($item in $localString) {
			if($item -ne $null) {
				if($outLocal.indexOf($item) -eq -1) {
					$outLocal.Add($item);
				}
			}
		}
		$outLocal = $outLocal -Join ","
		$res = $outLocal;
		
		$outRemote = [System.Collections.ArrayList]@();
		ForEach ($item in $remoteString) {
			if($outRemote.indexOf($item) -eq -1 -AND $item.length -gt 1) {
				$outRemote.Add($item);
			}
		}
		$outRemote = $outRemote -Join ","
		$res += ";" + $outRemote;

		return $res;
	}
}
$utilRes = New-Object -TypeName Utils;

Function Get-File($sourceDest) {
		$source = $sourceDest.Split(";")[0];
		$destination = $sourceDest.Split(";")[1];

		$source = $source.toString();
		$destination = $destination.toString();
	
		# HTTP client request
		$handler = New-Object System.Net.Http.HttpClientHandler;
		$httpClient = New-Object System.Net.Http.HttpClient($handler);
		$response = $httpClient.GetAsync($source);
		$response.Wait();
		 
		# File stream
		$outputFile = [System.IO.FileStream]::new($destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write);
		$downloadTask = $response.Result.Content.CopyToAsync($outputFile);
		$downloadTask.Wait();
		$outputFile.Close();
		
		Write-Host -NoNewLine "Downloaded $source...";
}

Function Download-Files() {	
		for($i = 0; $i -lt $files.length; $i++) {
				$curFile = $files[$i];
				$fileString = $baseUrl + $curFile;
				$outString = $base + "\" + $curFile;
				Write-Host "Downloading $fileString to $outString" -ForegroundColor White;
				Get-File($fileString + ";" + $outString);

				if (Test-Path -Path $outString) {
					$extractLoc = $folders[$fIndex["sysinternals"]];
					if($files[$i].indexOf("nirsoft") -gt -1) { $extractLoc = $folders[$fIndex["nirsoft"]]; }

					Unblock-File -Path $outString
					Write-Host "Extracting $curFile to $extractLoc" -ForegroundColor White;
					Expand-Archive -Path $outString -DestinationPath $extractLoc -Force
				}
				else { Throw "The file $curFile failed to download. Exiting."; }
		}
}

Function Build-Data() {
	Write-Host -NoNewLine "Pulling information..." -ForegroundColor White;
	# Tools downloaded and ready, gather information
	$allPortsSum = $utilRes.ports();
	$lPorts = $allPortsSum.Split(";")[0];
	$rPorts = $allPortsSum.Split(";")[1];
	
	Write-Host -NoNewLine "Writing result files..." -ForegroundColor White;
	
	# Create specific files for detailed output
	Write-Host -NoNewLine "IP Info..." -ForegroundColor White;
	ipconfig /all > ($outPrefix + "_ipReport.txt");
	Write-Host -NoNewLine "Routes..." -ForegroundColor White;
	route print > ($outPrefix + "_routeReport.txt");
	Write-Host -NoNewLine "DNS..." -ForegroundColor White;
	ipconfig /displaydns > ($outPrefix + "_dnsReport.txt");
	Write-Host -NoNewLine "Network ports..." -ForegroundColor White;
	echo $utilRes.portsDetail() > ($outPrefix + "_portReport.txt");
	Write-Host -NoNewLine "MsInfo32..." -ForegroundColor White;
	Start-Process -Wait "msinfo32.exe" -ArgumentList $("/report " + $outPrefix + "_msinfo32Report.txt");
	
	# SysInternals default-run tools; accept EULA for each before pulling data
	$sysRun = $folders[$fIndex["sysinternals"]] + "\";
	Write-Host -NoNewLine "Autorun Settings (SysInternals)..." -ForegroundColor White;
	$(Invoke-Expression $($sysRun + "Autorunsc.exe /accepteula")) > ($outPrefix + "_autorunsReport.txt");
	Write-Host -NoNewLine "Processes (SysInternals)..." -ForegroundColor White;
	$(Invoke-Expression $($sysRun + "pslist.exe /accepteula")) > ($outPrefix + "_processReport.txt");
	
	# NirSoft default-run tools
	$sysRun = $folders[$fIndex["nirsoft"]] + "\";
	Write-Host -NoNewLine "DLLs (NirSoft)..." -ForegroundColor White;
	Start-Process -Wait $($sysRun + "dllexp.exe") -ArgumentList $("/stext " + $outPrefix + "_dllReport.txt");
	
	Write-Host -NoNewLine "Summary file..." -ForegroundColor White;
	# Output the summary file
	$sumFile = $outPrefix + "_summary.txt";
	echo "-- IR Information Gathering Script `n" > $sumFile;
	echo "-- Script started on $startTime `n" >> $sumFile;
	echo "-- Admin name: $adminName `n" >> $sumFile;
	echo "-  Device Name:`t$(HOSTNAME)" >> $sumFile;
	$serial = $($(wmic bios get serialnumber).Split("SerialNumber") -Join " ").Trim();
	echo "-  Device Serial:`t$serial" >> $sumFile;
	echo "-  Device Address(es):`t$(Get-NetIPAddress | ForEach-Object {$_} | ForEach-Object {$_.IPAddress})" >> $sumFile;
	echo "-  Local Active Ports:`t$lPorts" >> $sumFile;
	echo "-  Remote Active Ports:`t$rPorts" >> $sumFile;
	echo "-- Script complete on $(Get-Date -Format "dddd MM/dd/yyyy HH:mm:ss K") `n" >> $sumFile;
	
	# Zip output
	Write-Host "Zipping results..." -ForegroundColor White;
	$outZip = $outPrefix + "_IR-Report.zip";
	$zipDetails = @{
		Path = $base + "\*.txt";
		CompressionLevel = "Fastest";
		DestinationPath = $outZip;
	}
	Compress-Archive @zipDetails;
	
	Remove-Item ($base + "\*.txt");
	
	$resHash = $(Get-FileHash $outZip).Hash;
	Write-Host "The script is complete. The results are zipped with a SHA-256 Hash of: " + $resHash;
	echo $resHash > ($outPrefix + "_resultsHash.txt");
}

Function Run-Complete {
	$adminName = Read-Host -Prompt 'Input the identity of the user running this script';
		
	if($args.indexOf('nonlocal') -gt -1) { Download-Files; }
	else {
		Write-Host "Starting process using local tools..." -ForegroundColor White;
	}
	
	Build-Data;
}

# Perform some basic argument processing
$argsProcess = [System.Collections.ArrayList]@();
$argsProcessed = "";
if($args.length -gt 0) {
	switch($args[0]) {
		"/update" { $argsProcess.Add("nonlocal") > $null; }
		"/download" { $argsProcess.Add("download") > $null; }
		"/hash" { $argsProcess.Add("hash") > $null; }
		"/help" { $argsProcess.Add("help") > $null; }
	}
	$argsProcessed = $argsProcess -Join ";";
}
else { $argsProcessed = "NONE"; }

if($argsProcessed.indexOf('help') -lt 0) {
	$resCount = $utilRes.genFolders($folders);
		
	if($resCount -eq 3) {
		if($argsProcessed.indexOf('nonlocal') -gt -1 -OR $argsProcessed.indexOf('NONE') -gt -1) { Run-Complete($argsProcessed); }
		if($argsProcessed.indexOf('download') -gt -1) { Download-Files; }
		if($argsProcessed.indexOf('hash') -gt -1) {
			$hashResult = $utilRes.checkHashes($files, $base);
		}
	}
}
else {
	Write-Host "";
	Write-Host "-------------------------------------------------------IR Script-------------------------------------------------------" -ForegroundColor Yellow;
	Write-Host "This script downloads SysInternals and NirSoft tools, and then uses those and system utilities to gather IR information.";
	Write-Host "Results are stored locally in an 'irtools' folder relative to the script's run location.";
	Write-Host "Options:`n";
	Write-Host -NoNewLine "`tthe default assumes that "; Write-Host -NoNewLine "/firstrun " -ForegroundColor Yellow; Write-Host "has already been performed.";
	Write-Host "`t/update - newly downloads tools, then runs the IR checks";
	Write-Host "`t/download - only downloads the tools, does not run IR checks";
	Write-Host "`t/hash - hashes the tool ZIPs and compares them to a hash on Github; prompts for confirmation before starting";
}
