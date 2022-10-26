#!/bin/sh

sendToWebhook() {
    if [ -n "$WEBHOOK_URL" ] && [ -n "$WEBHOOK_TEMPLATE" ]; then
        data=$(eval "echo \"$WEBHOOK_TEMPLATE\"")
        curl -s -S -X POST -d "$data" -H "Content-Type: application/json" $WEBHOOK_URL
    fi
}

mergesrt() {
    declare -a TYPE_LIST=("sdh", "forced", "hi", "cc")
    SRT_FILE=$1
    echo "SRT file: $SRT_FILE"
    #LANG=$(echo "$SRT_FILE" | sed -r 's|^.*\.([a-z]{2,3})\.srt$|\1|')
    LANG=$(echo "$SRT_FILE" | rev | cut -d'.' -f2 | rev)
    echo "Subtitle language: $LANG"
    #TYPE=$(echo "$SRT_FILE" | sed -r 's|^.*\.([a-z]{2,})\.'"$LANG"'\.srt$|\1|')
    if [[ $(echo "$SRT_FILE" | rev | cut -d'.' -f3 | rev) =~ ${TYPE_LIST[*]} ]]; then
        TYPE=$(echo "$SRT_FILE" | rev | cut -d'.' -f3 |rev)
        echo "Subtitle type: $TYPE"
    fi
    if [ '$TYPE' ]; then
        FILE_NAME=$(echo "$SRT_FILE" | sed 's|\.'"$TYPE"'\.'"$LANG"'\.srt||')
    else 
        FILE_NAME=$(echo "$SRT_FILE" | sed 's|\.'"$LANG"'\.srt||')
    fi
    echo "File name: $FILE_NAME"
    VIDEO_FILE=$FILE_NAME'.mkv'
    if [ ! -f "$VIDEO_FILE" ]; then
        VIDEO_FILE=$FILE_NAME'.mp4'
    fi
    if [ ! -f "$VIDEO_FILE" ]; then
        echo "File $VIDEO_FILE does not exist, skipping"
        return
    fi

    echo "File $VIDEO_FILE exists, start merging"
    MERGE_FILE=$FILE_NAME'.merge'
    if [ "${TYPE,,}" == "sdh" ] || [ "${TYPE,,}" == "hi" ]; then 
        mkvmerge -o "$MERGE_FILE" -s !$LANG "$VIDEO_FILE" --language 0:$LANG --track-name 0:$TYPE --hearing-impaired-flag "0:yes" "$SRT_FILE"
    elif [ "${TYPE,,}" == "forc"* ]; then 
        mkvmerge -o "$MERGE_FILE" -s !$LANG "$VIDEO_FILE" --language 0:$LANG --track-name 0:$TYPE --forced-display-flag "0:yes" "$SRT_FILE"
    else
        mkvmerge -o "$MERGE_FILE" -s !$LANG "$VIDEO_FILE" --language 0:$LANG --track-name 0:$LANG "$SRT_FILE"
    fi
    RESULT=$?
    if [ "$RESULT" -eq "0" ] || [ "$RESULT" -eq "1" ]; then
        RESULT=$([ "$RESULT" -eq "0" ] && echo "merge succeeded" || echo "merge completed with warnings")
        echo "$RESULT"
        echo "Delete $SRT_FILE"
        rm "$SRT_FILE"
        echo "Delete $VIDEO_FILE"
        rm "$VIDEO_FILE"
        echo "Rename $MERGE_FILE to $FILE_NAME.mkv"
        mv "$MERGE_FILE" "$FILE_NAME.mkv"
    else
        RESULT="merge failed"
        echo "$RESULT"
    fi

    sendToWebhook
}

echo START

DATA_DIR='/data'

find "$DATA_DIR" -type f -regex ".*\.(?:[a-z]?)[a-z][a-z]\.srt$" |
    while read srt; do
        mergesrt "$srt"
    done

inotifywait -m -r $DATA_DIR -e create -e moved_to --include '.*\.[a-z]{2,3}\.srt$' --format '%w%f' |
    while read srt; do
        echo "The file '$srt' was created/moved"
        mergesrt "$srt"
    done

echo EXIT
