#!/bin/sh

sendToWebhook() {
    if [ -n "$WEBHOOK_URL" ] && [ -n "$WEBHOOK_TEMPLATE" ]; then
        data=$(eval "echo \"$WEBHOOK_TEMPLATE\"")
        curl -s -S -X POST -d "$data" -H "Content-Type: application/json" $WEBHOOK_URL
    fi
}

mergesrt() {
    SRT_FILE=$1
    echo "SRT file: $SRT_FILE"
    LANG=$(echo "$SRT_FILE" | sed -r 's|^.*\.([a-z]{3})\.srt$|\1|')
    echo "Subtitle language: $LANG"
    FILE_NAME=$(echo "$SRT_FILE" | sed 's|\.'"$LANG"'\.srt||')
    echo "File name: $FILE_NAME"
    MKV_FILE=$FILE_NAME'.mkv'
    if [ -f "$MKV_FILE" ]; then
        echo "File $MKV_FILE exists, start merging"
        TEMP_MKV=$FILE_NAME'_merge.mkv'
        mkvmerge -o "$TEMP_MKV" -s !$LANG "$MKV_FILE" --language 0:$LANG "$SRT_FILE"
        echo "Delete $SRT_FILE"
        rm "$SRT_FILE"
        echo "Delete $MKV_FILE"
        rm "$MKV_FILE"
        echo "Rename $TEMP_MKV to $MKV_FILE"
        mv "$TEMP_MKV" "$MKV_FILE"
        sendToWebhook
    else 
        echo "File $MKV_FILE does not exist, skipping"
    fi
}

echo START

DATA_DIR="/data"

find $DATA_DIR -type f -regex ".*\.[a-z][a-z][a-z]\.srt$" |
    while read srt; do
        mergesrt "$srt"
    done

inotifywait -m -r $DATA_DIR -e create -e move --include '.*[a-z]{3}\.srt$' --format '%w%f' |
    while read srt; do
        echo "The file '$srt' was created/moved"
        mergesrt "$srt"
    done