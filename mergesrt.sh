#!/bin/sh

sendToWebhook() {
    if [ -n "$WEBHOOK_URL" ] && [ -n "$WEBHOOK_TEMPLATE" ]; then
        data=$(eval "echo \"$WEBHOOK_TEMPLATE\"")
        curl -s -S -X POST -d "$data" -H "Content-Type: application/json" $WEBHOOK_URL
    fi
}

#mergecheck() {
#    IMPORT_FILE=$1
#    echo "Imported file: $IMPORT_FILE"
#    EXT=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f1 | rev)
#    mergesrt "$srt"
#    mergeidx "$srt"
#}

mergesrt() {
    IMPORT_FILE=$1
    echo "Imported file: $IMPORT_FILE"
    EXT=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f1 | rev)
    echo "Extension: $EXT"
    #LANG=$(echo "$SRT_FILE" | sed -r 's|^.*\.([a-z]{2,3})\.srt$|\1|')
    LANG=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f2 | rev)
    echo "Subtitle language: $LANG"
    #TYPE=$(echo "$SRT_FILE" | sed -r 's|^.*\.([a-z]{2,})\.'"$LANG"'\.srt$|\1|')
    TYPE=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f3 | rev)
    if [ "$TYPE" == 'sdh' ] || [ "$TYPE" == 'forced' ] || [ "$TYPE" == 'hi' ] || [ "$TYPE" == 'cc' ]; then
        echo "Subtitle type: $TYPE"
        FILE_NAME=$(echo "$IMPORT_FILE" | sed 's|\.'"$TYPE"'\.'"$LANG"'\.'"$EXT"'||')
    else 
        TYPE=""
        FILE_NAME=$(echo "$IMPORT_FILE" | sed 's|\.'"$LANG"'\.'"$EXT"'||')
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
    if [ "$TYPE" == "sdh" ] || [ "$TYPE" == "hi" ] || [ "$TYPE" == "cc" ]; then
        mkvmerge -o "$MERGE_FILE" -s !$LANG "$VIDEO_FILE" --language 0:$LANG --track-name 0:$TYPE --hearing-impaired-flag 0:true "$IMPORT_FILE"
    elif [ "$TYPE" == "forced" ]; then
        mkvmerge -o "$MERGE_FILE" -s !$LANG "$VIDEO_FILE" --language 0:$LANG --track-name 0:$TYPE --forced-display-flag 0:true "$IMPORT_FILE"
    else
        mkvmerge -o "$MERGE_FILE" -s !$LANG "$VIDEO_FILE" --language 0:$LANG --track-name 0:$LANG "$IMPORT_FILE"
    fi
    RESULT=$?
    if [ "$RESULT" -eq "0" ] || [ "$RESULT" -eq "1" ]; then
        RESULT=$([ "$RESULT" -eq "0" ] && echo "merge succeeded" || echo "merge completed with warnings")
        echo "$RESULT"
        echo "Delete $IMPORT_FILE"
        rm "$IMPORT_FILE"
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

mergeidx() {
    IMPORT_FILE=$1
    EXT=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f1 | rev)
    echo "Extension: $EXT"
    #LANG=$(echo "$SRT_FILE" | sed -r 's|^.*\.([a-z]{2,3})\.srt$|\1|'
    FILE_NAME=$(echo "$IMPORT_FILE" | sed 's|\.'"$EXT"'||')
    echo "File name: $FILE_NAME"
    if [ ! -f "$FILE_NAME"'.sub' ]; then
        echo "$FILE_NAME"'.sub' "file does not exist, skipping"
        return
    fi
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
    mkvmerge -o "$MERGE_FILE" "$VIDEO_FILE" "$IMPORT_FILE"
    RESULT=$?
    if [ "$RESULT" -eq "0" ] || [ "$RESULT" -eq "1" ]; then
        RESULT=$([ "$RESULT" -eq "0" ] && echo "merge succeeded" || echo "merge completed with warnings")
        echo "$RESULT"
        echo "Deleting .idx file"
        rm "$IMPORT_FILE"
        echo "Deleting .sub file"
        rm "$FILE_NAME.sub"
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

find "$DATA_DIR" -type f -name "*.srt" -o -name "*.idx" |
    while read srt; do
        echo "The file '$file' was created/moved"
        EXT=$(echo "$file" | rev | cut -d'.' -f1 | rev)
        case $EXT in
            srt)
                mergesrt "$file"
                ;;
            idx)
                mergeidx "$file"
                ;;
        esac
    done

inotifywait -m -r $DATA_DIR -e create -e moved_to --include '.*\.([a-z]{2,3}\.srt|idx)$' --format '%w%f' |
    while read file; do
        echo "The file '$file' was created/moved"
        EXT=$(echo "$file" | rev | cut -d'.' -f1 | rev)
        case $EXT in
            srt)
                mergesrt "$file"
                ;;
            idx)
                mergeidx "$file"
                ;;
        esac
    done

echo EXIT
