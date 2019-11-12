#!/bin/bash
#title            :para-comm.sh
#description      :This script is used to run parallel ssh commands
#author           :rasimuddinvs@gmail.com
#date             :20161005
#version          : 1.0
command="uptime"
input=""
serverlist=""
login_user=""
AUTH_VALUE="FAIL"

# Parse command line options
while getopts "hsf:u:l:c:" flag; do
  case "$flag" in
    h)  echo "Usage: $0 [-f <file>] [-c <command>] [-h] [-s]"
        echo "  -f specifies the input file. Use -f filename to read from a file. If no file is specified, stdin is used."
        echo "  -c lets you specify a command to run on each server. By default this command is \"uptime\"."
        echo "  -h prints this help message."
        echo "  -u Give user. Default user is service"
        echo "  -l Ldap server Authentication"
        echo "eg: cat <serverlist> | para-comm.sh -c 'uptime' "
        exit 0
        ;;

    f)  serverlist=$OPTARG
        ;;
    c)  command="$OPTARG"
        ;;
    u)  user_in=$OPTARG
        ;;
    l)  login_user=$OPTARG
        ;;
    *)  exit 1
        ;;
  esac
done

# If no input file is specified, use stdin
if [[ -z "$serverlist" ]]; then
  tempfile=$(mktemp)
  while read data; do
    echo $data >> $tempfile
  done
  serverlist=$tempfile
fi

if [[ -n "$login_user" ]];then
    TEST_USR=$(ssh -q -t -l "$login_user" localhost "id -un")
    echo "Authentication successful for user $TEST_USR"
    [[ $TEST_USR != $login_user ]] && { echo "Authentication failure for $login_user" ;exit 1; }
    AUTH_VALUE="SUCCESS"
fi

# Count the number of "CPU's" or hyperthreads on this machine
threads="$(awk '/^processor/ {cpu++} END {print cpu}' /proc/cpuinfo)"

# Fancy colors in terminal output for increased legibility
bluetxt=$(tput setaf 6)
normaltxt=$(tput sgr0)
boldtxt=$(tput bold)
user=${user_in:-service}
RESTART_NUM=$(echo $command | egrep "stop|restart" 2>/dev/null | wc -l)

if [[ ( $RESTART_NUM -gt 0  &&  $AUTH_VALUE != "SUCCESS") ]];then
    echo "stop and restart command not allowed without option -l" ;exit 1;
fi

cmd="{ printf \"%s\\n%s\\n\" \"###### ${bluetxt}${boldtxt}SERVER${normaltxt} ######\" \"\$(ssh -q -l $user -o ConnectTimeout=3 SERVER \"source /etc/profile;$command\" 2>&1)\"; }"

# Use xargs for parallelism, use as many threads as the CPU supports
# Inside the xargs, start subshells to run ssh with the specified or default command
xargs -a $serverlist -I"SERVER" -P${threads} -n1 sh -c "$cmd "

# If a temporary file was created to put the serverlist in, remove it
if [[ ! -z "$tempfile" ]]; then
  find $tempfile -type f | xargs rm
