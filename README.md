# ICS 309 Logger

## Purpose
The *ICS 309 Logger* is a command line script to help capture information and activity during an 
amateur radio Directed Net. That information can then be used to generate a formal ICS-309 Communication Log.

## Features
- Provides a loop to record QSO's, keeping track of who has already been logged in to the script.
- For speed of entry, utilizes the [fzf](https://github.com/junegunn/fzf) command-line fuzzy finder tool to radiply search for callsigns and names.
- Outputs information in multiple formats (e.g., log, tsv) to be imported and used to generate a more formal ICS 309 Communication log.

## Requirements
- Runs on Linux/Unix platforms.
- Runs on macOS with slight modifications.
- Bash 4+ is required as associative arrays are used in this script.
- The [fzf](https://github.com/junegunn/fzf) command-line fuzzy finder is a required dependency.

## Installation
- Download to any directory.
- Edit the *stations.txt* file (or create a separate file) with frequently used stations that fzf can search through when asking for FROM and TO stations.

### Installing on macOS
- The bash version for macOS stopped advancing at 3.2. As a result, a Terminal session
will not be able to run this script. To get around this, you can use Homebrew to install
a 4+ version of bash, change the shebang on the script, then run in a separate bash session. 
For example:

```
bash-3.2$ brew install bash
bash-3.2$ sudo bash -c "echo $(brew --prefix)/bin/bash >> /private/etc/shells"
bash-3.2$ brew install fzf
bash-3.2$ vi ./generate-ics-309.sh ///changed first line to #!/usr/local/bin/bash
bash-3.2$ /usr/local/bin/bash
bash-5.1$ ./generate-ics-309.sh  
```

## Running
The *generate-ics-309.sh* script can be executed simply by invoking it on the command line.

```
$ ./generate-ics-309.sh
```

Optional command-line arguments can be passed in as follows:

```
-n <netName>        // Name of the incident 
-f <stationsFile>   // Custom stations file for fzf to use
```

Example with optional command-line arguments:

```  
$ ./generate-ics-309.sh -n 'Emergency Practice Net' -f custom-stations.txt
``` 

## Output

### Log file
A reader friendly log file is generated with a name format of `ics-309.YYYY-MM-DD_HHMMSS.log` which 
contains all the net activity, but is informal and not intended to be used as an official ICS 309 form. 

```
Incident Name: Emergency Practice Net
Operational Period, From: 2021-03-31 16:53, To: 2021-03-31 16:54
Net Operator: ABC123 Some Operator
COMMUNICATIONS LOG
16:54 From: ABC123 Some Operator, To: Announcement, Message: Lets start the net
16:54 From: KC7YYZ Carl Erickson, To: ABC123 Some Operator, Message: KC7YYZ Carl here
16:54 From: ABC123 Some Operator, To: Announcement, Message: Thanks everyone!
Prepared By: KC7YYZ Carl Erickson
Date & Time Prepared: 2021-03-31 16:54
Page 1 of 1
```

### TSV file
A tab-separated log file is generated with a name format of `ics-309.YYYY-MM-DD_HHMMSS.tsv` which 
only contains each QSO (i.e., time, from, to, message), and can be used with the 
Winlink ICS-309 template.

```
16:57	ABC123 Some Operator	Announcement	Lets start the net
16:57	KC7YYZ Carl Erickson	ABC123 Some Operator	KC7YYZ Carl here
16:57	ABC123 Some Operator	Announcement	Thanks everyone!
``` 

## License
[MIT](./LICENSE)

