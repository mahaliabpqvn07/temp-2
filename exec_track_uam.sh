#!/bin/bash
# Function to download a file with retries
download_file() {
    local file_name=$1
    local url="https://github.com/anhtuan9414/temp-2/raw/main/$file_name"
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

sudo rm -f track_uam.sh
sudo rm -f $(pwd)/uam_log.txt
download_file track_uam.sh
sudo chmod +x track_uam.sh
./track_uam.sh > $(pwd)/uam_log.txt 2>&1
