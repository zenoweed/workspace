#!/bin/bash

default_path="/home/$USER/Documents/workspace"

usage() {
	echo -e "\nUsage: $0 [OPTIONS]"
	echo "Options:"
	echo " -h, help	Display this help message"
	echo " -c, clear	Clear workspace"
	echo " -l, list	List workspace folders"
	echo " -t, tree	Tree workspace folders and files"
	exit 0
}

extract_argument() {
  echo "${2:-${1#*=}}"
}

has_argument() {
    [[ ("$1" == *=* && -n ${1#*=}) || ( ! -z "$2" && "$2" != -*)  ]];
}

clear() {
	echo "Workspace Contents:"
	list
	read -p "Clearing workspace. Continue? (Y/N): " confirm 
	if  [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]];then
		rm -vrf $default_path/*
		echo "Cleared workspace"
	else
		echo "Cancelled clearing workspace"
		exit 1
	fi
}

list() {
    ls $default_path
}
create_new() {
	mkdir -p $default_path/$1
	if [ -n "$2" ]; then
		touch $default_path/$1/$2
	else
		touch $default_path/$1/file
	fi
	code $default_path/$1	
	exit	
}

create_random() {
	dir="D$RANDOM"
	mkdir -p $default_path/$dir
	touch $default_path/$dir/$RANDOM
	code $default_path/$dir/
	exit	
}
handle_options() {
	while [ $# -gt 0 ] ; do
		case $1 in
			-h | --help)
				usage
				;;
			-c | clear)
				clear
				;;
			-l | list)
				list
				;;
			-n | new)
        		if ! has_argument $@; then
					create_random
				fi

				arg=$(extract_argument $@)
				create_new $arg $3

				;;
            -t | tree)
                tree $default_path
                ;;
			*)
				echo -e "\nInvalid option: $1" >&2
				usage

		esac
		shift
	done
}

handle_options "$@"