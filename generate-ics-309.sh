#!/bin/bash

function usage {
    echo "usage: $0 [-d] [-n netname] [-f station file]"
    echo "  -d              Delete any existing log files"
    echo "  -n netname      The name of the net"
    echo "  -f stationfile  The name of the station file"
    exit 1
}

#check for bash version >= 4
if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
  echo "Bash version must to 4 or higher to support associative arrays"
  exit
fi

#check for fzf dependency
if ! command -v fzf &>/dev/null; then
  echo "The 'fzf' command is required for the script. Please install it from https://github.com/junegunn/fzf"
  exit
fi

netName=""
stationsFile="stations.txt"

while getopts "dn:f:" options; do        
  case "${options}" in                 
    d)                                  
      rm -f *.log
      rm -f *.tsv
      ;;
    n)                                  
      netName="${OPTARG}"                 
      ;;
    f) 
      stationsFile="${OPTARG}"
      if [[ ! -r $stationsFile ]]; then
        echo "Can not find or read '$stationsFile' file"
        exit
      fi
      ;;
    *)
      ;;
  esac
done

# cache known stations
declare -A callsigns

# global vars
declare operator
declare myCallAndName
declare qsoFromKeyList=()
declare qsoToKeyList=()
declare qsoTimeList=()
declare qsoMessageList=()

# editableCallsignKeys vars that store the qso information until it's complete
declare qsoFromKey
declare qsoToKey
declare qsoMessage
declare qsoTime

# define log files
timestamp=$(date +"%Y-%m-%d_%H%M%S")
tsv="ics-309.$timestamp.tsv"
log="ics-309.$timestamp.log"
touch $tsv
touch $log

# fetch current time in "HH:MM" (s) or "YYYY-MM-DD HH:MM" (default) format
getCurrTime() {
  if [[ $# -eq 1 ]] && [[ "$1" == "s" ]]; then
    local format="%H:%M"
  else
    local format="%Y-%m-%d %H:%M"
  fi
  echo $(date +"$format")
}

# record a qso to log files
recordQso() {
  qsoFromKeyList+=("$qsoFromKey")
  qsoToKeyList+=("$qsoToKey")
  qsoTimeList+=("$qsoTime")
  qsoMessageList+=("$qsoMessage")

  qsoFromStation="${callsigns["$qsoFromKey"]}"
  # todo decode the following stations in the printf below
  #callsigns["o"]="$operator"
  #callsigns["m"]="$myCallAndName"
  #callsigns["a"]=""
  #callsigns["u"]="Unknown"
  qsoToStation="${callsigns["$qsoToKey"]}"

  printf "%s From: %s, To: %s, Message: %s\n" "$qsoTime" "$qsoFromStation" "$qsoToStation" "$qsoMessage" # | tee -a $log
}

# record net end time and complete output files
endNet() {

  # append static callsigns for convenience
  callsigns["o"]="$operator"
  callsigns["m"]="$myCallAndName"
  callsigns["a"]=""
  callsigns["u"]="Unknown"

  # end the net
  netEnd=$(getCurrTime)
  echo
  printf "Net end: $netEnd\n"

  # print out the net log
  printf "Incident Name: $incidentName\n" | tee -a $log
  printf "Operational Period, From: $netStart, To: $netEnd\n" | tee -a $log
  printf "Net Operator: $operator\n" | tee -a $log
  printf "COMMUNICATIONS LOG\n" | tee -a $log

  for (( i=0; i<${#qsoFromKeyList[@]}; i++ ));
  do
    qsoFromStation="${callsigns["${qsoFromKeyList[$i]}"]}"
    qsoToStation="${callsigns["${qsoToKeyList[$i]}"]}"
    qsoTime="${qsoTimeList[$i]}"
    qsoMessage="${qsoMessageList[$i]}"
    printf "%s From: %s, To: %s, Message: %s\n" "$qsoTime" "$qsoFromStation" "$qsoToStation" "$qsoMessage" | tee -a $log
    printf "%s\t%s\t%s\t%s\n" "$qsoTime" "$qsoFromStation" "$qsoToStation" "$qsoMessage" >>$tsv
  done

  printf "Prepared By: $myCallAndName\n" | tee -a $log
  printf "Date & Time Prepared: $netEnd\n" | tee -a $log
  printf "Page 1 of 1\n" | tee -a $log

  exit 1
}

findSingleStation() {
  stationKey=""
  while [[ -z "${stationKey}" ]]; do
    stationKey=$(fzf --header "Select or type in $1 Station" --print-query <$stationsFile | tail -1)
  done
  if [[ "$1" == "OPERATOR" ]]; then
    operator="$stationKey"
  elif [[ "$1" == "YOUR" ]]; then
    myCallAndName="$stationKey"
  fi
}

selectStation() {
  stationKey=""
  station=""
  while [[ -z "${stationKey}" ]]; do
    # display known stations
    echo "Select an option for $1 station:"
    for (( i=1; i<=${#callsigns[@]}; i++ )); do 
      echo "$i) ${callsigns[$i]}"
    done

    if [ "$1" == "TO" ]; then
      echo "a) All/Announcement"
    fi

    echo "e) Edit callsign"
    echo "m) Me ($myCallAndName)"
    echo "n) New callsign"
    echo "o) Operator ($operator)"
    echo "u) Unknown callsign"
    echo "x) Exit (end net)"

    read -e -p "Select $1 option: " choice

    if [ "$1" == "TO" ] && [ "$choice" == "a" ]; then
      stationKey="a"
      station="Announcement"
    elif [ "$choice" == "x" ]; then
      endNet
    elif [ "$choice" == "m" ]; then
      stationKey="m"
      station="$myCallAndName"
    elif [ "$choice" == "o" ]; then
      stationKey="o"
      station="$operator"
    elif [ "$choice" == "u" ]; then
      stationKey="u"
      station="Unknown"
    elif [ "$choice" == "e" ]; then
      editableCallsignKeys="m, o"
      for k in "${!callsigns[@]}"; do
        editableCallsignKeys+=", $k"
      done
      read -e -p "Select callsign to edit ($editableCallsignKeys): " key
      read -e -p "Enter new value: " newCall
      editCallsign "$key" "$newCall"
    elif [ "$choice" == "n" ]; then
      station=$(fzf --header "Select or type in $1 Station (ESC to exit)" --print-query <$stationsFile | tail -1)
      if [ ! "$station" == "" ]; then
        addCallsign "$station"
        stationKey="${#callsigns[@]}";
      fi
    elif [ $choice -gt 0 ] 2>/dev/null && [ $choice -le ${#callsigns[@]} ] 2>/dev/null; then
      stationKey="$choice"
      station="${callsigns[$stationKey]}"
    else
      echo
      echo "** Invalid option. Please try again."
      echo
    fi
  done

  echo "Selected $1 station: $station";

  # cache the from or to
  if [[ "$1" == "FROM" ]]; then
    qsoFromKey="$stationKey"
  elif [[ "$1" == "TO" ]]; then
    qsoToKey="$stationKey"
  fi
}

addCallsign() {
  callsigns["$((${#callsigns[@]} + 1))"]="$1"
}

editCallsign() {
  key="$1"
  value="$2"
  if [[ "$key" == "o" ]]; then
    operator="$value"
  elif [[ "$key" == "m" ]]; then
    myCallAndName="$value"  
  elif [ $key -gt 0 ] 2>/dev/null && [ $key -le ${#callsigns[@]} ] 2>/dev/null; then
    callsigns["$key"]="$value"
  fi
}

# capture the incident name
read -e -p "Incident Name [$netName]: " incidentName
if [[ "$incidentName" == "" ]]; then
  incidentName="$netName"
fi

# capture the operational period start date/time
read -e -p "Operational Period (Date/Time) From [$(getCurrTime)]: " netStart
if [[ "$netStart" == "" ]]; then
  netStart="$(getCurrTime)"
fi

# capture the operator
findSingleStation "OPERATOR"
echo "Net Operator: $operator"

# capture the prepared by
findSingleStation "YOUR"
echo "Prepared By: $myCallAndName"

echo
echo "*** Starting QSO log"
echo

# primary loop through all the qso's
while :; do

  # get the FROM stationKey
  selectStation "FROM";
  echo;

  # record time
  qsoTime=$(getCurrTime s)

  # get the TO stationKey
  selectStation "TO";
  echo;

  # get message
  read -e -p "Enter message: " qsoMessage
  echo

  # Record QSO
  recordQso

  echo
  echo "*** Ready for next contact"
  echo
done

