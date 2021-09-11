#!/bin/bash

function usage {
    echo "usage: $0 [-d] [-n netname] [-f station file]"
    echo "  -d              Delete any existing log files"
    echo "  -f stationfile  The name of the station file"
    echo "  -n netname      The name of the net"
    echo "  -w number       Number of words to print in output (separated by spaces, starting from left)"
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
wordsToPrint=2

while getopts "dn:f:w:" options; do        
  case "${options}" in                 
    d)                                  
      rm -f ics-309.*
      ;;
    n)                                  
      netName="${OPTARG}"                 
      ;;
    w)                                  
      wordsToPrint="${OPTARG}"                 
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
txt="ics-309.$timestamp.txt"
log="ics-309.$timestamp.log"
touch $txt
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
  qsoToStation="${callsigns["$qsoToKey"]}"

  printf "%s From: %s, To: %s, Message: %s\n" "$qsoTime" "$qsoFromStation" "$qsoToStation" "$qsoMessage" # | tee -a $log

  printf "\n***\n*** Ready for next contact\n***\n\n"

}

# record net end time and complete output files
endNet() {

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
    station="${callsigns["${qsoFromKeyList[$i]}"]}"
    callsign="`echo "${station}" | cut -d" " -f1`"
    fullname="`echo "${station}" | cut -d" " -f2-${wordsToPrint}`"
    qsoFromStation="${callsign^^} ${fullname^}"

    station="${callsigns["${qsoToKeyList[$i]}"]}"
    callsign="`echo "${station}" | cut -d" " -f1`"
    fullname="`echo "${station}" | cut -d" " -f2-${wordsToPrint}`"
    qsoToStation="${callsign^^} ${fullname^}"

    qsoTime="${qsoTimeList[$i]}"
    qsoMessage="${qsoMessageList[$i]}"
    printf "%s From: %s, To: %s, Message: %s\n" "$qsoTime" "$qsoFromStation" "$qsoToStation" "$qsoMessage" | tee -a $log
    printf "%s\t%s\t%s\t%s\n" "$qsoTime" "$qsoFromStation" "$qsoToStation" "$qsoMessage" >>$txt
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
    for (( i=1; i<=${numSelectedCallsigns}; i++ )); do
      echo "$i) ${callsigns[$i]}"
    done
    echo

    if [ "$1" == "TO" ]; then
      echo "a) All/Announcement"
    fi

    printf "%-50s %s\n" "m) Me ($myCallAndName)"  "c) Checkin only"
    printf "%-50s %s\n" "n) New callsign"         "e) Edit callsign"
    printf "%-50s %s\n" "o) Operator ($operator)" "r) Reply (Swap last from/to stations)"
    printf "%-50s %s\n" "u) Unknown callsign"     "rc) Rollcall"
    printf "%-50s %s\n" "h) Help"                 "x) Exit (end net)"
    echo
    
    read -e -p "Select $1 option: " choice

    # ANNOUNCEMENT
    if [ "$1" == "TO" ] && [ "$choice" == "a" ]; then
      stationKey="a"
      station="All/Announcement"

    # EXIT
    elif [ "$choice" == "x" ]; then
      endNet

    # HELP
    elif [ "$choice" == "h" ]; then
      # todo
      echo "Help: Todo"

    # ROLLCALL
    elif [ "$choice" == "rc" ]; then

      qsoFromKey="o"
      echo "Selected FROM station: ${callsigns["$qsoFromKey"]}";

      selectableCallsignKeys=""
      for (( k=1; k<=$numSelectedCallsigns; k++ )); do
        if [ $k -gt 1 ]; then
          selectableCallsignKeys+=", "
        fi
        selectableCallsignKeys+="$k"
      done
      selectableCallsignKeys+=", or 'c' to cancel"

      # validate number
      key=0
      firstLoop=true
      valid=false
      while $firstLoop || ! $valid; do
        firstLoop=false
        read -e -p "Select TO callsign ($selectableCallsignKeys): " key
        if [ $key -gt 0 ] 2>/dev/null && [ $key -le ${numSelectedCallsigns} ] 2>/dev/null; then
          valid=true
        elif [ "$key" == "c" ]; then
          valid=true
        else
          echo "Please try again"
        fi
      done

      if [ "$key" != "c" ]; then
        qsoToKey=$key
        station=${callsigns["$qsoToKey"]}
        echo "Selected TO station: $station";
        read -e -p "Enter message: " qsoMessage

        qsoMessage="Rollcall to $station. Reply: $qsoMessage"
        recordQso
      fi

    # REPLY
    elif [ "$choice" == "r" ]; then

      tmp=$qsoFromKey
      qsoFromKey=$qsoToKey
      qsoToKey=$tmp

      echo "Selected FROM station: ${callsigns["$qsoFromKey"]}";
      echo "Selected TO station: ${callsigns["$qsoToKey"]}";
      read -e -p "Enter message: " qsoMessage
      recordQso

    # MYCALL
    elif [ "$choice" == "m" ]; then
      stationKey="m"
      station="$myCallAndName"

    # OPERATOR
    elif [ "$choice" == "o" ]; then
      stationKey="o"
      station="$operator"

    # UNKNOWN
    elif [ "$choice" == "u" ]; then
      stationKey="u"
      station="Unknown"

    # EDIT STATIONS
    elif [ "$choice" == "e" ]; then
      editableCallsignKeys="m, o"
      for (( k=1; k<=$numSelectedCallsigns; k++ )); do
        editableCallsignKeys+=", $k"
      done
      read -e -p "Select callsign to edit ($editableCallsignKeys): " key
      read -e -p "Enter new value: " newCall
      editCallsign "$key" "$newCall"

    # NEW STATION
    elif [ "$choice" == "n" ]; then
      station=$(fzf --header "Select or type in $1 Station (ESC to exit)" --print-query <$stationsFile | tail -1)
      if [ ! "$station" == "" ]; then
        addCallsign "$station"
        stationKey="${numSelectedCallsigns}";
      fi

    # CHECKIN ONLY
    elif [ "$choice" == "c" ]; then
      station=$(fzf --header "Select or type in CHECKIN Station (ESC to exit)" --print-query <$stationsFile | tail -1)
      if [ ! "$station" == "" ]; then
        addCallsign "$station"
        qsoFromKey="${numSelectedCallsigns}";
        qsoToKey="o"
        qsoTime=$(getCurrTime s)
        qsoMessage="Checkin"
        recordQso
      fi

    # SELECT STATION BY NUMBER
    elif [ $choice -gt 0 ] 2>/dev/null && [ $choice -le ${numSelectedCallsigns} ] 2>/dev/null; then
      stationKey="$choice"
      station="${callsigns[$stationKey]}"

    # WHOOPS
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
  for (( i=1; i<=${numSelectedCallsigns}; i++ )); do
    if [ "${callsigns[$i]}" == "$1" ]; then
      return
    fi
  done

  numSelectedCallsigns=$((numSelectedCallsigns+1))
  callsigns["$numSelectedCallsigns"]="$1"
}

editCallsign() {
  key="$1"
  value="$2"
  if [[ "$key" == "o" ]]; then
    operator="$value"
    callsigns["o"]="$value"
  elif [[ "$key" == "m" ]]; then
    myCallAndName="$value"
    callsigns["m"]="$value"
  elif [ $key -gt 0 ] 2>/dev/null && [ $key -le $numSelectedCallsigns ] 2>/dev/null; then
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

# capture the prepared by
findSingleStation "YOUR"
echo "Prepared By: $myCallAndName"

# capture the operator
findSingleStation "OPERATOR"
echo "Net Operator: $operator"

callsigns["o"]="$operator"
callsigns["m"]="$myCallAndName"
callsigns["a"]=""
callsigns["u"]="Unknown"

numSelectedCallsigns=0
addCallsign "$myCallAndName"

echo
echo "*** Starting QSO log"
echo

# primary loop through all the qso's
while :; do

  # get the FROM stationKey
  selectStation "FROM";
  echo;

  # record time
  qsoTime=$(getCurrTime)

  # get the TO stationKey
  selectStation "TO";
  echo;

  # get message
  read -e -p "Enter message: " qsoMessage
  echo

  # Record QSO
  recordQso

done

