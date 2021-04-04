#!/bin/bash

adminName="Unassigned";
base=".";
baseOut="${base}/reports";
files=("irGather.sh" "exTools.tar.gz");
baseUrl="https://nobutwhy.com/files";
folders=($base $baseOut "$base/exTools");
startTime=$(date '+%A %m/%d/%Y %H:%M:%S %z');
datePrefix=$(date '+%Y%d%m-%M');
outPrefix="${baseOut}/${datePrefix}_$(hostname)";

for cDir in ${folders[@]}; do
        [ ! -d $cDir ] && echo "Creating directory '$cDir'"; mkdir -p $cDir;
done

echo "Writing result files..."
# Create specific files for detailed output
echo "IP Info..."
ifconfig > "${outPrefix}_ipReport.txt";
echo "Routes..."
route > "${outPrefix}_routeReport.txt";
echo "DNS..."
resolvectl status > "${outPrefix}_dnsReport.txt";
echo -e "Network ports...\n"
netstat -ntlup > "${outPrefix}_portReport.txt";

# Output summary
sumFile="${outPrefix}_summary.txt";
sumText="-- IR Information Gathering Script \n";
sumText="${sumText}-- Script started on $startTime \n";
sumText="${sumText}-- Admin Name: $adminName \n\n";
sumText="${sumText}-\tDevice Name: \t\t $(hostname) \n";

getSerial=$(dmidecode -t system | grep Serial);
sumText="${sumText}-\tDevice Serial:\t\t $(cut -d : -f2 <<< $getSerial) \n";

sumText="${sumText}-\tDevices Address(es):\t $(hostname -I) \n\n";

endDate=$(date '+%A %m/%d/%Y %H:%M:%S %z');
sumText="${sumText}-- Script completed on ${endDate}";

echo -e $sumText > $sumFile;

echo -e "Compressing results...\n";
endFile="${outPrefix}_IR-Report.tar.gz";
tar -czvf $endFile $baseOut/*.txt;
rm -f $baseOut/*.txt;

resHash=$(sha256sum $endFile);
echo -e "The script is complete. The results are in a tar.gz file with a SHA-256 Hash of: ${resHash}\n";
echo $resHash > "${outPrefix}_resultsHash.txt";
