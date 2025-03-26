#!/bin/bash
###################################################################
# Author:  Dan Bechard
# Date:    May 9, 2013
# Desc:    Displays status of all repositories in directory to allow
#          the user to easily identify uncommited changes and pending
#          commits on the remote.
#
# === CHANGELOGS ===
#
# July 13, 2022:
#   - Update to fallback on main if master branch not found
#   - Remove unused, required second arg for --pull
#
# Dec 24, 2024:
#   - Optimize master branch check using rev-parse
#   - Fix PULL_BEHIND condition syntax to work on Windows
#
###################################################################
CLR='\e[0m' #Clear

BLACK='\e[00;30m'
RED='\e[00;31m'
GREEN='\e[00;32m'
YELLOW='\e[00;33m'
BLUE='\e[00;34m'
PURPLE='\e[00;35m'
CYAN='\e[00;36m'
LGRAY='\e[00;37m' #Default foreground color

DGRAY='\e[01;30m'
LRED='\e[01;31m'
LGREEN='\e[01;32m'
LYELLOW='\e[01;33m'
LBLUE='\e[01;34m'
LPURPLE='\e[01;35m'
LCYAN='\e[01;36m'
WHITE='\e[01;37m'
###################################################################

# Root directory of the repository structure
REPO_DIR=C:/Users/User/Documents/Development/jai-modules;
PULL_BEHIND=

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -p|--pull)
      PULL_BEHIND=1
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# Verify root directory exists
function CheckPrereqs {
	if [ ! -d ${REPO_DIR} ] ; then
		PrintLn;
		Print "Error: " RED;
		Print "${REPO_DIR} " YELLOW;
		PrintLn "does not exist."
		read -p ""
		exit
	fi
}

function CheckGitStatus {
	for i in ${REPO_DIR}/$1* ; do
		if [ -d "$i" ] ; then
			cd $i;

			# Print directory name
			FormatPrint "%-16b" "${PWD##*/}" CYAN

			# Skip directories starting with an undersocre
			if [[ ${PWD##*/} == _* ]] ; then
				PrintLn "Skipping underscore directory" DGRAY
				continue;
			fi

			# Check if Git repository
			if [ -z "$(git rev-parse --git-dir)" ] ; then
				PrintLn "Not a Git repository" RED;
				continue;
			fi

			# Note: http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_01.html
			# [ -n $(command) ] returns true if length of command result is non-zero
			# [ -z $(command) ] returns true if length of command result is zero

			isBehind=false; isAhead=false; dirty=false;
			master="master"
			if [ -z "$(git rev-parse --verify master)" ] ; then
				master="main"
			fi

			# Detect local repositories with no remotes
			if [ -z "$(git branch -r)" ] ; then
				Print "Local repository" YELLOW;
				PrintLn " (no remotes)" RED;
			else
				# Fetch updates from remote
				[ "$(git fetch)" ]

				# Check for behind/ahead commits
				[ -n "$(git log --oneline HEAD..origin/$master)" ] && isBehind=true
				[ -n "$(git log --oneline origin/$master..HEAD)" ] && isAhead=true
			fi

			# Check for uncommitted changes
			[ -n "$(git status -s --porcelain)" ] && dirty=true
			if $dirty || $isBehind || $isAhead ; then
				if $isBehind ; then
					r=$(git log --oneline HEAD..origin/$master | wc -l | tr -d ' ');
					PrintLn "Behind $r commit(s)" YELLOW;
					if [ $PULL_BEHIND ] ; then
						git pull
					fi
				elif $isAhead ; then
					r=$(git log --oneline origin/$master..HEAD | wc -l | tr -d ' ');
					PrintLn "Ahead $r commit(s)" YELLOW;
				fi
				if $dirty ; then
					PrintLn "Uncommitted changes" PURPLE;
					git status -s;
					PrintLn;
				fi
			else
				PrintLn "Clean" GREEN
			fi
		fi
	done
}

function Print {
	if [ $# = 2 ] ; then
		printf "${!2}%b${CLR}" "$1"
	elif [ $# = 1 ] ; then
		printf "%b" "$1"
	else
		PrintLn "Print expects 1,2 arguments, $# provided." RED
	fi
}

function PrintLn {
	if [ $# = 2 ] ; then
		printf "${!2}%b${CLR}" "$1\n"
	elif [ $# = 1 ] ; then
		printf "%b" "$1\n"
	elif [ $# = 0 ] ; then
		printf "%b" "\n"
	else
		PrintLn "PrintLn expects 0,1,2 arguments, $# provided." RED
	fi
}

function FormatPrint {
	if [ $# = 3 ] ; then
		printf "${!3}$1${CLR}" "$2"
	elif [ $# = 2 ] ; then
		printf "$1" "$2"
	else
		PrintLn "FormatPrint expects 2,3 arguments, $# provided." RED
	fi
}

function FormatPrintLn {
	if [ $# = 3 ] ; then
		printf "${!3}$1${CLR}" "$2\n"
	elif [ $# = 2 ] ; then
		printf "$1" "$2\n"
	else
		PrintLn "FormatPrintLn expects 2,3 arguments, $# provided." RED
	fi
}

CheckPrereqs
CheckGitStatus /
sleep 2