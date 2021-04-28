#!/bin/bash
doFunc="UNSET";
while getopts h flag; do
    case "${flag}" in
        h) doFunc="SET";;
    esac
done;

adminName="Unassigned";
base=".";
baseOut="${base}/reports";
files=("irGather.sh" "exTools.tar.gz");
baseUrl="https://nobutwhy.com/files";
folders=($base $baseOut);
startTime=$(date '+%A %m/%d/%Y %H:%M:%S %z');
datePrefix=$(date '+%Y%d%m-%M');
outPrefix="${baseOut}/${datePrefix}_$(hostname)";

for cDir in ${folders[@]}; do
        [ ! -d $cDir ] && echo "Creating directory '$cDir'"; mkdir -p $cDir;
done

if [[ $doFunc == "SET" ]];
then
        search="${baseOut}/*.tar.gz";
        for file in $search; do
                nHash=$(sha256sum $file);
                echo "${nHash}";
        done
        exit;
fi

echo "Enter the admin name running this script: ";
read adminName;

# Check for tools
hasNetstat=true;
hasIfconfig=true;

if ! command -v netstat &> /dev/null; then hasNetstat=false; fi;
if ! command -v ifconfig &> /dev/null; then hasIfconfig=false; fi;

if [[ $hasNetstat == false ]] || [[ $hasIfconfig == false ]];
then
        toolChoice=false;
        echo "Some tools were not found. Download them now? [y/n]";
        read toolChoice;

        if [[ $toolChoice == "y" ]] || [[ $toolChoice == "Y" ]];
        then
                apt update
                if [[ $hasNetstat == false ]] || [[ $hasIfconfig == false ]];
                then
                        if command -v apt &> /dev/null; then apt -y install net-tools; fi;
                        if command -v dnf &> /dev/null; then dnf -y install net-tools; fi;
                        if command -v zypper &> /dev/null; then zypper -n install net-tools; fi;
                        if command -v pacman &> /dev/null; then pacman -S --noconfirm netstat-nat; fi;
                fi;
        else exit; fi;
fi;


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
