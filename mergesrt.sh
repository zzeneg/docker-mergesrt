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
        echo "File $MKV_FILE exists, start processing"
        TRACKS_TO_COPY=$(mkvmerge -J "$MKV_FILE" | jq -r "
            .tracks
                | map(select(.type == \"subtitles\"))
                | map(select(.properties.language != \""$LANG"\"))
                | if (\"$REMOVE_PGS\" | length > 0) then map(select(.codec | contains(\"PGS\") | not)) else . end
                | if (. | length > 0) then map(\"-s \" + (.id | tostring)) | join(\" \") else \"-S\" end
            "
        )
        echo "TRACKS_TO_COPY $TRACKS_TO_COPY"
        TEMP_MKV=$FILE_NAME'_merge.mkv'
        OUTPUT=$(mkvmerge -o "$TEMP_MKV" $TRACKS_TO_COPY "$MKV_FILE" --language 0:$LANG "$SRT_FILE")
        RESULT=$?
        if [ "$RESULT" -eq "0" ]; then
            RESULT="merged succesfully"
            echo "Delete $SRT_FILE"
            rm "$SRT_FILE"
            echo "Delete $MKV_FILE"
            rm "$MKV_FILE"
            echo "Rename $TEMP_MKV to $MKV_FILE"
            mv "$TEMP_MKV" "$MKV_FILE"
        else
            RESULT="merge failed: $OUTPUT"
        fi
        sendToWebhook
    else 
        echo "File $MKV_FILE does not exist, skipping"
    fi
}

echo START

DATA_DIR='/data'

find "$DATA_DIR" -type f -regex ".*\.[a-z][a-z][a-z]\.srt$" |
    while read srt; do
        mergesrt "$srt"
    done

inotifywait -m -r $DATA_DIR -e create -e move --include '.*[a-z]{3}\.srt$' --format '%w%f' |
    while read srt; do
        echo "The file '$srt' was created/moved"
        mergesrt "$srt"
    done

echo EXIT