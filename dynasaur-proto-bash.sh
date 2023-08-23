#!/bin/bash


DATE_TIME=$(date "+%F %X %z")
DATE_TIME_SHORT=$(date "+%Y%m%d-%H%M%S-%z")

LOG_FILE="$(pwd)/dynasaur-log--$DATE_TIME_SHORT.txt"
PUB_IP_CMD="dig +short myip.opendns.com @resolver1.opendns.com"
NUM_CHECKS=0
CHECK_DELAY=60
LOG_PER=1

REC_TYPE="A"
REC_NAME="sub.domain.ext" # Configure this
ZONE_ID="zone-id" # Configure this
API_TOKEN="api-token" # Configure this


echo -e "===================================="
echo -e "DYNASAUR ($DATE_TIME)"
echo -e "===================================="
echo -e "\nRunning...\n"
log_out="=== DYNASAUR ($DATE_TIME) ===\n"

echo -e "Getting API token status..."
token_ver=$(
    curl -s \
            -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type: application/json" | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['result']['status']);"
)
echo -e "API token status received: $token_ver"
log_out+="[$(date +%X)] API token: $token_ver\n"


if [ "$token_ver" == "active" ]
then
    echo -en "$log_out" >> "$LOG_FILE" && log_out=""

    stored_rec_ip=""

    i=1
    while true
    do
        echo -e "\n=== CHECK #$i ($(date +%X)) ==="
        log_out+="[$(date +%X)] CHECK #$i\n"

        echo -e "Getting public IP address..."
        pub_ip=$($PUB_IP_CMD)
        echo -e "Public IP address received: $pub_ip"
        log_out+="[$(date +%X)] - Pub IP addr: $pub_ip\n"

        if [ "$stored_rec_ip" == "$pub_ip" ]
        then
            echo -e "Stored DNS record IP address matches public IP address."
            log_out+="[$(date +%X)] - Stored DNS rec IP addr == pub IP addr.\n"
        else
            echo -e "Getting active DNS info and locating record..."
            rec=$(
                curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json" | \
                python3 -c "
import sys, json;
for rec in json.load(sys.stdin)['result']:
    if rec['name'] == \"$REC_NAME\" and rec['type'] == \"$REC_TYPE\": 
        json.dump(rec, sys.stdout);
                "
            )
            rec_id=$(echo -en "$rec" | python3 -c "import sys, json; print(json.load(sys.stdin)['id']);")
            echo -e "Active DNS record located: $rec_id";
            log_out+="[$(date +%X)] - Active DNS rec ID: $rec_id\n"

            rec_ip=$(echo -en "$rec" | python3 -c "import sys, json; print(json.load(sys.stdin)['content']);")
            echo -e "Active DNS record IP address identified: $rec_ip";
            log_out+="[$(date +%X)] - Active DNS rec IP addr: $rec_ip\n"

            if [ "$rec_ip" == "$pub_ip" ]
            then
                echo -e "Active DNS record IP address matches public IP address."
                log_out+="[$(date +%X)] - Active DNS rec IP addr == pub IP addr.\n"
                stored_rec_ip=$rec_ip
            else
                echo -e "Updating active & chached DNS record IP address..."
                upd_rec=$(
                    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$rec_id" \
                        -H "Authorization: Bearer $API_TOKEN" \
                        -H "Content-Type: application/json" \
                        -d "{\"name\":\"$REC_NAME\",\"type\":\"$REC_TYPE\",\"proxied\":true,\"content\":\"$pub_ip\",\"comment\":\"Dynasaur ($DATE_TIME_SHORT)\"}"
                )
                stored_rec_ip=$(echo -en "$upd_rec" | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['content']);")
                echo -e "Active & stored DNS record IP address updated: $rec_ip -> $stored_rec_ip"
                log_out+="[$(date +%X)] - New DNS rec IP addr: $rec_ip -> $stored_rec_ip\n"
            fi
        fi

        if (( i % LOG_PER == 0 ));
        then
            echo -e "Saving log file..."
            echo -en "$log_out" >> "$LOG_FILE" && log_out=""
            echo -e "Log file saved."
        fi

        if [[ $NUM_CHECKS == 0 || $i -lt $NUM_CHECKS ]]
        then
            echo -e "Awaiting next check..."
            sleep $CHECK_DELAY
            ((i++))
        else
            break
        fi
    done
fi


echo -e "\nDone!\n"

echo -en "============================================" >> "$LOG_FILE" && log_out=""
echo -e "====================================="
