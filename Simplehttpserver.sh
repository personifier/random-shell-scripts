#!/bin/sh

#

# Copyright (C) 2017 Upper Stream.

#

# See the bottom of this file for licensing conditions.

#

#set -x

set -e

# program name

program=${0##*/}

usage() {

	cat <<-EOF	Usage:

	

	$program [-p port] [docroot]

	$program -H

	

	-p port : specify listening port number; defaults to 10080

	-H      : print this help and quit

	docroot : specify document root directory; defaults to the current directory

EOF

}

# default listening port

port=10080

# Configure in accordance with your environment

nc=$(command -v nc) || true

pid_file=/tmp/$program.pid

makefifo() {

	name="$1"

	mkfifo -m 0600 $name.fifo && echo $name.fifo

}

get_content_type() {

	file="$1"

	case $file in

	*.html|*.htm) printf "text/html";;

	*.txt|*.sh)   printf "text/plain";;

	*)            printf "application/octet-stream";;

	esac

}

respond() {

	file="$1"

	length=$(wc -c < $file)

	length=${length##*[!0123456789]}

	content_type=$(get_content_type $file)

	{ cat $fifo2 > /dev/null; printf ""; } > $fifo1 &

	printf "HTTP 200 OK\r\n\Content-Length: $length\r\nContent-Type: $content_type\r\n\r\n" >> $fifo1

	case $content_type in

	text/html|text/plain)

		cat $file >> $fifo1

		;;	

	*)

		dd if=$file of=$fifo1 2> /dev/null

		;;

	esac

	sleep 1; echo "end" > $fifo2

	printf "200 $length"

}

execute_get() {

	if [ "$1" = "/" ]; then

		path="/index.html"

	else

		path=$1

	fi

	file=$docroot$path

	dir=$(cd $(dirname $file); pwd)/

	if echo $dir | grep ^$docroot/ > /dev/null && test -f $file; then

		respond $file

	else

		message="$path not found\r\n"

		printf "HTTP 404 Not Found\r\n\Content-Length: ${#message}\r\n\r\n$message" > $fifo1

		printf "404 -"

	fi

}

execute() {

	method="$1"

	path="$2"

	case $method in

	GET)

		execute_get $path

		;;

	*)

		message="$1 unsupported\r\n_"

		message=${message%_}

		printf "HTTP 501 Not Implemented\r\n\Content-Length: ${#message}\r\n\r\n$message" > $fifo

		printf "501 -"

		;;

	esac

}

cleanup() {

	rm $fifo1 $fifo2 $pid_file

}

interrupt() {

	cleanup

	exit 0

}

get_source_ip() {

	source_ip="xxx.xxx.xxx.xxx"

	if ! ifconfig=$(command -v ifconfig); then

		printf $source_ip

		return

	fi

	if ! sockstat=$(command -v sockstat) && ! netstat=$(command -v netstat); then

		printf $source_ip

		return

	fi

	if [ "$(uname)" = "Linux" ]; then

		myips=$(

			$ifconfig | 

			awk '/^[ \t]*inet / {print substr($2, 6)} /^[ \t]*inet6 / {print substr($3,0,index($3,"/") - 1)}'

		)

	else

		myips=$($ifconfig | grep inet | cut -f2 -d' ')

	fi

	for ip in $myips; do

		if [ "$sockstat"]; then

			source=$($sockstat | grep -F "$ip:$port") || true

			if [ "$source" ]; then

				set -- $source

				source_ip=${7%:*}

				break

			fi

		elif [ "$netstat" ]; then

			source=$($netstat -an | grep -F "$ip:$port") || true

			if [ "$source" ]; then

				set -- $source

				source_ip=${5%:*}

				break

			fi

		fi

	done

	printf "$source_ip"

}

parse() {

	cr=$(printf "\r")

	while read line; do

		line=${line%$cr}

		case "$line" in

		GET*)

			set -- $line

			method=$1

			path=$2

			;;

		Host:*)

			host=${line#Host: }

			;;

		*:*)

			;;

		"")

			source=$(get_source_ip)

			date=$(date +'%d/%m/%Y:%H:%M:%S %z')

			status_length=$(execute $method $path)

			printf "$source - - [$date] $method \"http://$host$path\" $status_length\n"

			trap - INT

			exit

			;;

		*)

			;;

		esac

	done

}

# dependency verification

for cmd in nc; do

	test -z "$(eval echo $"$cmd")" && { echo "$0: \`$cmd\` not found"; exit 2; }

done

while getopts p:H opt; do

	case $opt in

	p) port=$OPTARG;;

	H) usage; exit 255;;

	*) usage; exit 255;;

	esac

done

shift $((OPTIND-1))

if [ $# -eq 0 ]; then

	docroot=.

else

	docroot="$1"

fi

docroot=$(cd $docroot; pwd)

# FIFO to write HTTP response

if ! fifo1=$(makefifo /tmp/${0##*/}.$$.1); then

	echo "$0: creating a named pipe failed.  Already running?" 1>&2

	exit 1

fi

# FIFO for internal event notification

if ! fifo2=$(makefifo /tmp/${0##*/}.$$.2); then

	echo "$0: creating a named pipe failed.  Already running?" 1>&2

	exit 1

fi

trap interrupt INT

echo $$ > $pid_file

cat 1>&2 <<EOF

Simple HTTP Server

Listening at the port number $port.

Type ^C to quit.

EOF

while cat $fifo1 | $nc -l $port | parse; do

	:

done

cleanup

exit

Copyright 2017 Upper Stream.

Permission is hereby granted, free of charge, to any person obtaining a copy of

this software and associated documentation files (the "Software"), to deal in the

Software without restriction, including without limitation the rights to use,

copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the

Software, and to permit persons to whom the Software is furnished to do so, subject

to the following conditions:

The above copyright notice and this permission notice shall be included in all

copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,

INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A

PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT

HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION

OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE

SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
