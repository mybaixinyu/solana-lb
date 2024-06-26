#!/bin/sh

RD='\e[1;31m'
YL='\e[1;33m'
GR='\e[1;32m'
BL='\e[1;34m'
NC='\e[1;0m'

UPSTREAMS_UPDATE_INTERVAL=3600
UPSTREAMS_NUMBER=10
LOWER_UPSTREAMS_NUMBER_LIMIT=2
UPSTREAMS_RESPONSE_FORMAT="haproxy"
UPSTREAMS_API_URL="https://api.extrnode.com/endpoints?limit=${UPSTREAMS_NUMBER}&format=${UPSTREAMS_RESPONSE_FORMAT}&is_rpc=true"
FULL_REQUEST_BODY="wget -qO- ${UPSTREAMS_API_URL}"

trap "echo Initializing..." SIGTERM

get_upstreams_list () {
	RAW_REQUEST_BODY=$( ${FULL_REQUEST_BODY} )
	if [ $? -eq 0 ]; then
		echo -e "$( date '+%d/%b/%Y:%T %z' )\t${GR}SUCCESS${NC}\tRequest get upstreams list success. Start formating request"
	else
		echo -e "$( date '+%d/%b/%Y:%T %z' )\t${RD}FAIL${NC}\tRequest get upstreams list failed. Exit..."
		exit 1
	fi

	if [ $( printf '%s' "${RAW_REQUEST_BODY}" | wc -l ) -lt ${LOWER_UPSTREAMS_NUMBER_LIMIT} ]; then
		echo -e "$( date '+%d/%b/%Y:%T %z' )\t${RD}FAIL${NC}\tRequest get upstreams list back with number upstream < ${LOWER_UPSTREAMS_NUMBER_LIMIT}. Exit..."
		exit 1
	fi

	FORMAT_RESPONSE_BODY="$( printf '%s' "${RAW_REQUEST_BODY}" | awk '{printf "%s" " " ,$0}' )"
	if [ $? -eq 0 ]; then
		echo -e "$( date '+%d/%b/%Y:%T %z' )\t${GR}SUCCESS${NC}\tFormating list success. Run caddy reverse proxy with formated list"
	else
		echo -e "$( date '+%d/%b/%Y:%T %z' )\t${RD}FAIL${NC}\tFormating list failed. Exit..."
		exit 1
	fi

	UPSTREAMS_LIST="${FORMAT_RESPONSE_BODY}" $@
	if [ $? -eq 0 ]; then
		echo -e "$( date '+%d/%b/%Y:%T %z' )\t${GR}SUCCESS${NC}\tUsed upstreams list: ${FORMAT_RESPONSE_BODY}"
	else
		echo -e "$( date '+%d/%b/%Y:%T %z' )\t${RD}FAIL${NC}\tRun caddy reverse proxy failed. Exit..."
		exit 1
	fi
}

stop_caddy() {
	while true; do
		pkill caddy || break
		sleep 1
	done
}

i=0
while [ $i -ge 0 ]
do
	if [ $i -eq 0 ]; then
		get_upstreams_list caddy start --config /etc/caddy/Caddyfile --adapter caddyfile
	else
		get_upstreams_list caddy reload --config /etc/caddy/Caddyfile
	fi

	if [ $? -ne 0 ]; then
		stop_caddy
		exit 0
	else
		trap "echo Exiting...;stop_caddy;exit 0" SIGTERM
	fi

	sleep ${UPSTREAMS_UPDATE_INTERVAL} & wait $!
	i=$(( i + 1 ))
done
