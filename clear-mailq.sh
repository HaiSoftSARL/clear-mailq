#!/bin/bash
# Function Clear mail queue
# Author: Robin Labadie
# Company: HaiSoft
# Usage: clear-mailq.sh -s/d [time]

# Set input
command="$1"
timevalue="$2"
toomanyhargs="$3"

# Script self name
selfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

# TIME
SECONDS=0

# Check user input
fn_check_uinput(){
        # No command was provided
        if [ -z "${command}" ]; then
                echo "Missing argument!"
                fn_usage
        # Check if command is valid
        elif [ "${command}" != "-r" ]&&[ "${command}" != "-s" ]; then
                echo "Command unknown!"
                fn_usage
        fi
	# Command -r without time
	if [ "${command}" == "-r" ]&&[ -z "${timevalue}" ]; then
               echo "Cannot remove without a time value"
               fn_usage
	# No time value set
        elif [ -z "${timevalue}" ]; then
                # Default to 1 hour
                timevalue="1"
        # Time value is not a number
        elif [[ "${timevalue}" != ?(-)+([0-9]) ]]; then
                echo "Invalid time!"
                fn_usage
        fi
	# Too many arguments
	if [ -n "${toomanyhargs}" ]; then
               echo "Too many arguments!"
               fn_usage
	fi
}

fn_usage(){
	echo ""
        echo "Usage: ./${selfname} -arg [time in hours]"
        echo "Available commands:"
        echo " * ./${selfname} -s [time in hours] - Show outdated mails in queue"
        echo " * ./${selfname} -r [time in hours] - Remove outdated mails in queue"
        exit
}

fn_compare_date(){
        # Date 1
        #dt1="Wed May 31 08:21:14 "
        dt1="$1"
        # Compute the seconds since epoch for date 1
        t1="$(date --date="$dt1" +%s)"

        # Date 2 : Current date
        dt2="$(date +%Y-%m-%d\ %H:%M:%S)"
        # Compute the seconds since epoch for date 2
        t2="$(date --date="$dt2" +%s)"

        # Compute the difference in dates in seconds
        let "tDiff=$t2-$t1"
        # Compute the approximate hour difference
        let "hDiff=$tDiff/3600"

        # returns hDiff
}

fn_mailq(){
	echo "[START] Gathering mail queue"
        mailqueue="$(mailq)"
        echo "[INFO] Sorting mail queue"
        # sortedq="$(echo "${mailqueue}" | grep "^[A-F0-9]" | sort -k5n -k6n | awk '{print $1 " " $4 " " $5 " " $6}')"
	sortedq="$(echo "${mailqueue}" | grep "^[A-F0-9]" -A2 )"
}

fn_show_expired(){
        oldcount=0
        totalcount=0
        echo "[INFO] Gathering information"
	# View info from sorted mails
	while IFS= read -r line; do
		# Workaround to make the loop lighter
		if [ "${detection}" == "positive" ]; then
			echo "${line}"
			detection="lastline"
		elif [ "${detection}" == "lastline" ];then
			echo "${line}"
			unset detection
		else
			# If line starts with hexadecimal value (mail ID), then we grep the mailid
			mailid="$(echo "$line" | grep "^[A-F0-9]" | awk '{print $1}')"
			# If the mailid is set
			if [ -n "${mailid}" ]; then
				# The date of the mail
				maildate="$(echo "$line" | awk '{print $4 " " $5 " " $6}')"
				# How old is the mail compared to now
				fn_compare_date "${maildate}"
				# If mail is older than time set
				if [ "${hDiff}" -ge "${timevalue}" ]; then
					detection="positive"
					echo ""
					echo "${line}"
					oldcount="$((oldcount+1))"
				fi
				totalcount="$((totalcount+1))"	
			fi
		fi
        done < <(echo "${sortedq}")
        echo "[INFO] Mails older than ${timevalue} hours: ${oldcount} out of ${totalcount} total"
}

fn_remove_expired(){
        oldcount=0
        totalcount=0
        echo "[ACTION] Removing..."
	while IFS= read -r line; do
		# If line starts with hexadecimal value (mail ID), then we grep the mailid
		mailid="$(echo "$line" | grep "^[A-F0-9]" | awk '{print $1}')"
		# If the mailid is set
		if [ -n "${mailid}" ]; then
			# The date of the mail
			maildate="$(echo "$line" | awk '{print $4 " " $5 " " $6}')"
			# How old is the mail compared to now
			fn_compare_date "${maildate}"
			# If mail is older than time set
			if [ "${hDiff}" -ge "${timevalue}" ]; then
				echo "[ACTION] Removing mail ${mailid}"
				postsuper -d "${mailid}"
				oldcount="$((oldcount+1))"
			fi
			totalcount="$((totalcount+1))"	
		fi
	done < <(echo "${sortedq}")
	echo "[INFO] ${oldcount} mails older than ${timevalue} hours removed out of ${totalcount} total"
}

fn_check_uinput
fn_mailq
if [ "${command}" == "-s" ]; then
	fn_show_expired
elif [ "${command}" == "-r" ]; then
	fn_remove_expired
fi
# Display duration
duration=$SECONDS
echo "[INFO] $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
exit
