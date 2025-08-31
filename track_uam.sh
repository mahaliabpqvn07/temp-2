#!/bin/bash
# Function to download a file with retries
download_file() {
    local file_name=$1
    local url=$2
    local output=$file_name
    local wait_seconds=2
    local retry_count=0
    local max_retries=50

    while [ $retry_count -lt $max_retries ]; do
        wget --no-check-certificate -q "$url" -O "$output"

        if [ $? -eq 0 ]; then
            echo "Download successful: $file_name saved as $output."
            return 0
        else
            retry_count=$((retry_count + 1))
            echo "Download failed. Retrying in $wait_seconds seconds..."
            echo "Retrying to download $file_name from $url (Attempt $retry_count/$max_retries)..."
            sleep $wait_seconds
        fi
    done

    echo "Failed to download $file_name after $max_retries attempts."
    exit 1
}

nameFile=track_uam_hub.sh
#sudo rm -f $nameFile
download_file $nameFile "https://github.com/anhtuan9414/temp-2/raw/main/$nameFile"
sudo chmod +x $nameFile
#(crontab -l | grep -v "$(pwd)/ex-trak.sh"; echo "*/30 * * * * $(pwd)/ex-trak.sh") | crontab - && crontab -l
#crontab -l | grep -v "^*/30 \* \* \* \* $(pwd)/exec_track_uam.sh$" | crontab -
./$nameFile
