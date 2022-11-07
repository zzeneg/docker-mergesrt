#!/bin/sh

sendToWebhook() {
    if [ -n "$WEBHOOK_URL" ] && [ -n "$WEBHOOK_TEMPLATE" ]; then
        data=$(eval "echo \"$WEBHOOK_TEMPLATE\"")
        curl -s -S -X POST -d "$data" -H "Content-Type: application/json" $WEBHOOK_URL
    fi
}

# MERGE SRT FILES HERE -----------------------------------------------------------------
mergesrt() {
    IMPORT_FILE=$1
    FILE_COUNT=0
    echo "Imported file: $IMPORT_FILE"
    # PARSE FILE COMPONENTS ------------------------------------------------------------
    EXT=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f1 | rev)
    echo "Extension: $EXT"
    LANG=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f2 | rev)
    echo "Subtitle language: $LANG"
    TYPE=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f3 | rev)
    if [ "$TYPE" == 'sdh' ] || [ "$TYPE" == 'forced' ] || [ "$TYPE" == 'hi' ] || [ "$TYPE" == 'cc' ]; then
        echo "Subtitle type: $TYPE"
        FILE_NAME=$(echo "$IMPORT_FILE" | sed 's|\.'"$TYPE"'\.'"$LANG"'\.'"$EXT"'||')
    else 
        TYPE=""
        FILE_NAME=$(echo "$IMPORT_FILE" | sed 's|\.'"$LANG"'\.'"$EXT"'||')
    fi
    echo "File name: $FILE_NAME"
    
    # CHECK IF THERE ARE MORE THAN 1 SUBS
    echo "Count: " ls -dq $FILE_NAME* | wc -l
    
    read -p "Press any key to resume ..."
    
    VIDEO_FILE=$FILE_NAME'.mkv'
    # CHECK IF VIDEO EXISTS -------------------------------------------------------------
    if [ ! -f "$VIDEO_FILE" ]; then
        VIDEO_FILE=$FILE_NAME'.mp4'
    fi
    if [ ! -f "$VIDEO_FILE" ]; then
        echo "File $VIDEO_FILE does not exist, skipping"
        return
    fi
    echo "File $VIDEO_FILE exists, start merging"
    MERGE_FILE=$FILE_NAME'.merge.mkv'
    # MKVMERGE COMMAND BASED ON TYPE ----------------------------------------------------
    if [ "$TYPE" == "sdh" ] || [ "$TYPE" == "hi" ] || [ "$TYPE" == "cc" ]; then
        mkvmerge -o "$MERGE_FILE" -s !$LANG "$VIDEO_FILE" --language 0:$LANG --track-name 0:$TYPE --hearing-impaired-flag 0:true "$IMPORT_FILE"
    elif [ "$TYPE" == "forced" ]; then
        mkvmerge -o "$MERGE_FILE" -s !$LANG "$VIDEO_FILE" --language 0:$LANG --track-name 0:$TYPE --forced-display-flag 0:true "$IMPORT_FILE"
    else
        mkvmerge -o "$MERGE_FILE" -s !$LANG "$VIDEO_FILE" --language 0:$LANG --track-name 0:$LANG "$IMPORT_FILE"
    fi
    RESULT=$?
    # CLEAN UP  --------------------------------------------------------------------------
    if [ "$RESULT" -eq "0" ] || [ "$RESULT" -eq "1" ]; then
        RESULT=$([ "$RESULT" -eq "0" ] && echo "merge succeeded" || echo "merge completed with warnings")
        mkvmerge --identify "$MERGE_FILE"
        if mkvmerge --identify "$MERGE_FILE" | grep -q 'subtitle'; then
        echo "matched"
        fi

        #echo "$RESULT"
        #echo "Delete $IMPORT_FILE"
        #rm "$IMPORT_FILE"
        #echo "Delete $VIDEO_FILE"
        #rm "$VIDEO_FILE"
        #echo "Rename $MERGE_FILE to $FILE_NAME.mkv"
        #mv "$MERGE_FILE" "$FILE_NAME.mkv"
    else
        RESULT="merge failed"
        echo "$RESULT"
    fi

    sendToWebhook
}

# MERGE IDX FILES HERE -----------------------------------------------------------------
mergeidx() {
    IMPORT_FILE=$1
    echo "Imported file: $IMPORT_FILE"
    # PARSE FILE COMPONENTS
    EXT=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f1 | rev)
    echo "Extension: $EXT"
    FILE_NAME=$(echo "$IMPORT_FILE" | sed 's|\.'"$EXT"'||')
    echo "File name: $FILE_NAME"
    # CHECK IF .SUB EXSISTS -------------------------------------------------------------
    if [ ! -f "$FILE_NAME"'.sub' ]; then
        echo "$FILE_NAME"'.sub' "file does not exist, skipping"
        return
    fi
    # CHECK IF VIDEO EXISTS -------------------------------------------------------------
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
    # MKVMERGE COMMAND ------------------------------------------------------------------
    mkvmerge -o "$MERGE_FILE" "$VIDEO_FILE" "$IMPORT_FILE"
    RESULT=$?
    # CLEAN UP --------------------------------------------------------------------------
    if [ "$RESULT" -eq "0" ] || [ "$RESULT" -eq "1" ]; then
        RESULT=$([ "$RESULT" -eq "0" ] && echo "merge succeeded" || echo "merge completed with warnings")
        #echo "$RESULT"
        #echo "Deleting .idx file"
        #rm "$IMPORT_FILE"
        #echo "Deleting .sub file"
        #rm "$FILE_NAME.sub"
        #echo "Delete $VIDEO_FILE"
        #rm "$VIDEO_FILE"
        #echo "Rename $MERGE_FILE to $FILE_NAME.mkv"
        #mv "$MERGE_FILE" "$FILE_NAME.mkv"
    else
        RESULT="merge failed"
        echo "$RESULT"
    fi
    sendToWebhook
}

echo START

DATA_DIR='/data'

# LOOK FOR FILES ON STARTUP -------------------------------------------------------------
find "$DATA_DIR" -type f -name "*.??.srt" -o -name "*.???.srt" -o -name "*.idx" |
    while read file; do
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
    
# MONITOR FOR NEW FILES IN DIR ----------------------------------------------------------
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
