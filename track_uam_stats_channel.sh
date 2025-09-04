#!/bin/bash
nowDate=$(date +"%d-%m-%Y %H:%M:%S" --date="7 hours")
echo $nowDate
API_URL="$1"
API_KEY="$2"
# Telegram Bot Configuration
BOT_TOKEN="$3"
CHANNEL_ID="$4"
GROUP_ID="$5"

IMAGE_URL="https://github.com/anhtuan9414/temp-2/raw/main/utopia_banner.jpg"
IMAGE_PATH="/tmp/utopia_banner.jpg"

IMAGE_URL_2="https://github.com/anhtuan9414/temp-2/raw/main/utopia_banner_2.jpg"
IMAGE_PATH_2="/tmp/utopia_banner_2.jpg"

if [ ! -f "$IMAGE_PATH" ]; then
    curl -L -o "$IMAGE_PATH" "$IMAGE_URL"
fi

if [ ! -f "$IMAGE_PATH_2" ]; then
    curl -L -o "$IMAGE_PATH_2" "$IMAGE_URL_2"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Retry parameters
max_retries=30
retry_count=0

get_current_block_self() {
    local fromBlock=$(cat lastBlockStats.txt 2>/dev/null)
    if [ -z "$fromBlock" ] || [ "$fromBlock" == "null" ]; then
        fromBlock=184846
    fi
    while [ $retry_count -lt $max_retries ]; do
        local data=$(curl -s -X POST $API_URL/api/1.0 \
            -H "Content-Type: application/json" \
            -d '{
                "method": "getMiningBlocksWithTreasury",
                "params": {
                    "fromBlockId": "'"$fromBlock"'",
                    "limit": "1"
                },
                "token": "'"$API_KEY"'"
            }')
    
        if [ -n "$data" ] && [ "$data" != "null" ]; then
            lastBlockTime=$(date -d "$(echo $data | grep -oP '"dateTime":\s*"\K[^"]+') +7 hours" +"%d-%m-%Y %H:%M")
            lastBlock=$(echo $data | grep -oP '"id":\s*\K\d+')
            miningThreads=$(echo $data | grep -oP '"involvedInCount":\s*\K\d+')
            totalMiningThreads=$(echo $data | grep -oP '"numberMiners":\s*\K\d+')
            rewardPerThread=$(echo $data | grep -oP '"price":\s*\K\d+\.\d+')
            break
        else
            retry_count=$((retry_count + 1))
            echo "Attempt $retry_count/$max_retries failed to fetch current block. Retrying in 10 seconds..."
            sleep 10
        fi
    done
}
lastBlockStats=lastBlockStats_$API_KEY.txt
fromBlock=$(cat $lastBlockStats 2>/dev/null)
get_balance_self() {
    max_retries=30
    retry_count=0
    if [ -z "$fromBlock" ] || [ "$fromBlock" == "null" ]; then
        fromBlock=184846
    fi
    while [ $retry_count -lt $max_retries ]; do
        local data=$(curl -s -X POST $API_URL/api/1.0 \
            -H "Content-Type: application/json" \
            -d '{
                "method": "getBalance",
                "params": {
                    "currency": "CRP"
                },
                "token": "'"$API_KEY"'"
            }')
    
        if [ -n "$data" ] && [ "$data" != "null" ]; then
            balance=$(printf "%.8f" "$(echo $data | grep -oP '"result":\s*\K\d+\.\d+')")
            if [ -z "$balance" ] || [ "$balance" == "null" ]; then
                balance=0
            fi
            break
        else
            retry_count=$((retry_count + 1))
            echo "Attempt $retry_count/$max_retries failed to fetch balance. Retrying in 10 seconds..."
            sleep 10
        fi
    done
}

get_crp_price() {
    max_retries=30
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        local data=$(curl 'https://crp.is:8182/market/pairs' \
                      -H 'Accept: application/json, text/plain, */*' \
                      -H 'Accept-Language: en-US,en;q=0.9,vi;q=0.8' \
                      -H 'Connection: keep-alive' \
                      -H 'Origin: https://crp.is' \
                      -H 'Referer: https://crp.is/' \
                      -H 'Sec-Fetch-Dest: empty' \
                      -H 'Sec-Fetch-Mode: cors' \
                      -H 'Sec-Fetch-Site: same-site' \
                      -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36' \
                      -H 'sec-ch-ua: "Chromium";v="134", "Not:A-Brand";v="24", "Google Chrome";v="134"' \
                      -H 'sec-ch-ua-mobile: ?0' \
                      -H 'sec-ch-ua-platform: "Windows"')
    
        if [ -n "$data" ] && [ "$data" != "null" ]; then
            crpPrice=$(echo $data | jq '.result.pairs[] | select(.pair.pair == "crp_usdt") | '.data_market.close'')
            break
        else
            retry_count=$((retry_count + 1))
            echo "Attempt $retry_count/$max_retries failed to fetch crp price. Retrying in 10 seconds..."
            sleep 10
        fi
    done
}

lastMiningDateStats=lastMiningDateStats_$API_KEY.txt
fromDate=$(cat $lastMiningDateStats 2>/dev/null)
get_mining_info() {
    if [ -z "$fromDate" ] || [ "$fromDate" == "null" ]; then
        fromDate=""
    fi
    local res=$(curl -s -X POST $API_URL/api/1.0 \
                    -H "Content-Type: application/json" \
                    -d '{
                        "method": "getFinanceHistory",
                        "params": {
                            "currency": "CRP",
                            "filters": "ALL_MINING",
                            "fromDate": "'"$fromDate"'"
                        },
                        "token": "'"$API_KEY"'"
                    }' | jq -c '.result[0]')
    miningReward=$(echo "$res" | jq -r '.amount_string')
    miningDetails=$(echo "$res" | jq -r '.details')
    miningCreated=$(echo "$res" | jq -r '.created')
}

get_usdt_vnd_rate() {
    local res=$(curl --compressed 'https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search' \
  -H "Content-Type: application/json" \
  --data-raw '{"fiat":"VND","page":1,"rows":1,"tradeType":"SELL","asset":"USDT","countries":[],"proMerchantAds":false,"shieldMerchantAds":false,"filterType":"tradable","periods":[],"additionalKycVerifyFilter":0,"publisherType":"merchant","payTypes":[],"classifies":["mass","profession","fiat_trade"],"tradedWith":false,"followed":false}')
    sellRate=$(echo "$res" | jq -r '.data[0].adv.price')
}


# Function to send a Telegram notification
send_telegram_notification() {
    local POST_TEXT="$1"
    local COMMENT_TEXT="$2"
    # ✅ Step 1: Send the post to the channel
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendPhoto" \
     -F chat_id="$CHANNEL_ID" \
     -F photo=@"$IMAGE_PATH" \
     -F caption="$(echo -e "$POST_TEXT")" > /dev/null
    echo "✅ Successfully send the post to the channel!"
    
    if [ -n "$COMMENT_TEXT" ] && [ "$COMMENT_TEXT" != "null" ]; then
        # ✅ Step 2: Wait for Telegram to automatically forward the post to the group (small delay)
        echo "⏳ Waiting for Telegram to forward the post to the group..."
        sleep 5
        
        # ✅ Step 3: Get the message_id of the forwarded post in the group
        # Find the most recent message in the group with 'is_automatic_forward=true'
        
        # Fetch updates (containing the forward in the group)
        local UPDATE=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getUpdates")
        
        # ✅ Extract the message_id from the forwarded message
        local FORWARDED_MSG_ID=$(echo "$UPDATE" | jq ".result[] | select(.message.chat.id == $GROUP_ID and .message.is_automatic_forward == true) | .message.message_id" | tail -n1)
        
        # Check if found
        if [ -z "$FORWARDED_MSG_ID" ]; then
          echo "❌ Could not find the forwarded post in the group!"
          exit 1
        fi
        
        echo "✅ Found message_id in group: $FORWARDED_MSG_ID"
        
        # ✅ Step 4: Send a comment (reply to the post in the group)
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendPhoto" \
         -F chat_id="$GROUP_ID" \
         -F photo=@"$IMAGE_PATH_2" \
         -F caption="$(echo -e "$COMMENT_TEXT")" \
         -F reply_to_message_id="$FORWARDED_MSG_ID" > /dev/null
        
        echo "✅ Successfully commented on the post!"
    fi
}

get_current_block_self

if [ "$lastBlock" -le "$fromBlock" ]; then
    echo "✅ Block $lastBlock has been processed. Status: informed."
    exit 0
fi

echo $lastBlock > $lastBlockStats

get_balance_self
get_crp_price
get_mining_info
get_usdt_vnd_rate

value=$(echo "$crpPrice * $balance" | bc -l)
formattedValue=$(printf "%.4f" "$value")
vndValue=$(echo "$sellRate * $formattedValue" | bc -l)
vndFormattedValue=$(LC_NUMERIC=en_US.UTF-8 printf "%'.0f\n" "$vndValue")
messageBot="🚀 Mining Stats\n"
messageBotCmt=""

textStats="$nowDate\n$messageBot\n🍀 CRP/USDT (based crp.is): $crpPrice\$\n🍀 USDT/VND Binance P2P: $(LC_NUMERIC=en_US.UTF-8 printf "%'.0f\n" "$sellRate")đ\n🍀 CRP Balance: $balance CRP ≈ $formattedValue\$ ≈ $vndFormattedValueđ\n🍀 Mining Threads: $miningThreads\n🍀 Last Block: $lastBlock\n🍀 Last Block Time: $lastBlockTime\n🍀 Reward Per Thread: $rewardPerThread CRP\n🍀 Total Mining Threads: $totalMiningThreads\n"
if [ -n "$miningReward" ] && [ "$miningReward" != "null" ] && [ "$miningThreads" -ne 0 ]; then
   messageBotCmt="🏦 Estimated Earnings\n"
   echo $miningCreated > $lastMiningDateStats
   formattedTime=$(date -d "$miningCreated UTC +7 hours" +"%d-%m-%Y %H:%M")
   miningRewardValue=$(echo "$crpPrice * $miningReward" | bc -l)
   formattedMiningRewardValue=$(printf "%.4f" "$miningRewardValue")
   miningRewardVndValue=$(echo "$sellRate * $formattedMiningRewardValue" | bc -l)
   formattedMiningRewardVndValue=$(LC_NUMERIC=en_US.UTF-8 printf "%'.0f\n" "$miningRewardVndValue")
   textStats+="🍀 $miningDetails [$formattedTime]: $miningReward CRP ≈ $formattedMiningRewardValue$ ≈ $formattedMiningRewardVndValueđ"

   textStats+="\n\n$messageBotCmt\n"
   dailyReward=$(echo "$miningReward * 96" | bc -l)
   dailyRewardValue=$(echo "$crpPrice * $dailyReward" | bc -l)
   formattedDailyRewardValue=$(printf "%.4f" "$dailyRewardValue")
   dailyMiningRewardVndValue=$(echo "$sellRate * $formattedDailyRewardValue" | bc -l)
   formattedDailyMiningRewardVndValue=$(LC_NUMERIC=en_US.UTF-8 printf "%'.0f\n" "$dailyMiningRewardVndValue")
   textStats+="🍀 Daily: $dailyReward CRP ≈ $formattedDailyRewardValue$ ≈ $formattedDailyMiningRewardVndValueđ\n"
   
   weeklyReward=$(echo "$dailyReward * 7" | bc -l)
   weeklyRewardValue=$(echo "$crpPrice * $weeklyReward" | bc -l)
   formattedWeeklyRewardValue=$(printf "%.4f" "$weeklyRewardValue")
   weeklyMiningRewardVndValue=$(echo "$sellRate * $formattedWeeklyRewardValue" | bc -l)
   formattedWeeklyMiningRewardVndValue=$(LC_NUMERIC=en_US.UTF-8 printf "%'.0f\n" "$weeklyMiningRewardVndValue")
   textStats+="🍀 Weekly: $weeklyReward CRP ≈ $formattedWeeklyRewardValue$ ≈ $formattedWeeklyMiningRewardVndValueđ\n"
   
   monthlyReward=$(echo "$dailyReward * 30" | bc -l)
   monthlyRewardValue=$(echo "$crpPrice * $monthlyReward" | bc -l)
   formattedMonthlyRewardValue=$(printf "%.4f" "$monthlyRewardValue")
   monthlyMiningRewardVndValue=$(echo "$sellRate * $formattedMonthlyRewardValue" | bc -l)
   formattedMonthlyMiningRewardVndValue=$(LC_NUMERIC=en_US.UTF-8 printf "%'.0f\n" "$monthlyMiningRewardVndValue")
   textStats+="🍀 Monthly: $monthlyReward CRP ≈ $formattedMonthlyRewardValue$ ≈ $formattedMonthlyMiningRewardVndValueđ"
   
fi

if [ -f stats_$API_KEY.txt ]; then
    cp stats_$API_KEY.txt pre_stats_$API_KEY.txt
fi

echo -e $textStats > stats_$API_KEY.txt

if [ ! -f pre_stats_$API_KEY.txt ]; then
    cp stats_$API_KEY.txt pre_stats_$API_KEY.txt
fi

extract_value() {
    echo "$1" | grep -oE '[0-9]+(,[0-9]{3})*(\.[0-9]+)?' | tr -d ',' | tail -1
}

compare_values() {
    local field="$1"
    local before_line="$2"
    local after_line="$3"
    local message=""
    local pass="1"

    if [[ -z "$after_line" ]]; then return; fi

    if [[ "$field" == "Last Block" || "$field" == "Last Block Time" ]]; then
        message+="\n$after_line"
        pass="0"
    fi

    local before_val=$(extract_value "$before_line")
    local after_val=$(extract_value "$after_line")

    if [[ -z "$before_val" || -z "$after_val" ]]; then
        message+="\n$after_line"
        pass="0"
    fi

    if [ "$pass" = "1" ]; then
      before_val="${before_val/,/.}"
      after_val="${after_val/,/.}"
  
      local unit=""
      local fo="%.4f"
      case "$field" in
          "CRP/USDT")
              unit="$"
              ;;
          "Reward Per Thread")
              unit=" CRP"
              fo="%.8f"
              ;;
          "Total Mining Threads" | "Mining Threads")
              fo="%.0f"
              ;;
          "USDT/VND Binance P2P" | "CRP Balance" | "Mining reward for block" | "Daily" | "Weekly" | "Monthly")
              unit="đ"
              fo="%.0f"
              ;;
      esac
      delta=$(awk "BEGIN { printf \"$fo\", $after_val - $before_val }")
      if (( $(awk "BEGIN { print ($delta > 0) }") )); then
          emoji="🟢"
      elif (( $(awk "BEGIN { print ($delta < 0) }") )); then
          emoji="🔴"
      fi
  
      if (( $(awk "BEGIN {print ($delta == 0)}") )); then
          message+="\n$after_line"
      else
          if [[ "$unit" == "đ" ]]; then
              delta_formated=$(LC_NUMERIC=en_US.UTF-8 printf "%'.0f\n" "$delta")
          else
              delta_formated=$delta
          fi
          if (( $(awk "BEGIN { print ($delta > 0) }") )); then
              message+="\n$after_line $emoji (+$delta_formated$unit)"
          else
              message+="\n$after_line $emoji ($delta_formated$unit)"
          fi
      fi
    fi
    
    if [[ "$field" == "Daily" || "$field" == "Weekly" || "$field" == "Monthly" ]]; then
       messageBotCmt+=$message
    else
       messageBot+=$message
    fi
}



FIELDS=(
    "CRP/USDT"
    "USDT/VND Binance P2P"
    "CRP Balance"
    "Mining Threads"
    "Last Block"
    "Last Block Time"
    "Reward Per Thread"
    "Total Mining Threads"
    "Mining reward for block"
    "Daily"
    "Weekly"
    "Monthly"
)

for field in "${FIELDS[@]}"; do
    before_line=$(grep -i "$field" pre_stats_$API_KEY.txt | head -1)
    after_line=$(grep -i "$field" stats_$API_KEY.txt | head -1)
    compare_values "$field" "$before_line" "$after_line"
done

cat stats_$API_KEY.txt

send_telegram_notification "$messageBot" "$messageBotCmt"
