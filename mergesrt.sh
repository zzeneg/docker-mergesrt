#!/bin/sh

DATA_DIR='/data'

sendToWebhook() {
    if [ -n "$WEBHOOK_URL" ] && [ -n "$WEBHOOK_TEMPLATE" ]; then
        data=$(eval "echo \"$WEBHOOK_TEMPLATE\"")
        curl -s -S -X POST -d "$data" -H "Content-Type: application/json" $WEBHOOK_URL
    fi
}

# MKVMERGE COMMANDS -------------------------------------------------------------------
merge() {
    output=$1
    input=$2
    import=$3
    ext=$4
    type=$5
    lang=$6

    case $ext in
                srt)
                    if [ "$type" == "sdh" ] || [ "$type" == "hi" ] || [ "$type" == "cc" ]; then
                        mkvmerge -o "$output" "$input" --language 0:$lang --track-name 0:$type --hearing-impaired-flag 0:true "$import"
                    elif [ "$type" == "forced" ]; then
                        mkvmerge -o "$output" "$input" --language 0:$lang --track-name 0:$type --forced-display-flag 0:true "$import"
                    else
                        mkvmerge -o "$output" "$input" --language 0:$lang --track-name 0:$lang "$import"
                    fi
                    return 
                    ;;
                idx)
                    mkvmerge -o "$output" "$input" "$import"
                    return
                    ;;
            esac
}

# PROCESS FILE INFORMATION HERE ---------------------------------------------------------
process() {
    IMPORT_FILE=$1
    echo "Imported file: $IMPORT_FILE"
    # PARSE FILE COMPONENTS ------------------------------------------------------------
    EXT=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f1 | rev)
    echo "Extension: $EXT"
    if [ "$EXT" == "srt" ]; then
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
    else
        FILE_NAME=$(echo "$IMPORT_FILE" | sed 's|\.'"$EXT"'||')
    fi
    echo "File name: $FILE_NAME"
    
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
    MERGE_FILE=$FILE_NAME'.merge'
    merge "$MERGE_FILE" "$VIDEO_FILE" "$IMPORT_FILE" "$EXT" "$TYPE" "$LANG"
    # When doing large batches sometimes the merge does not seem to work correctly.
    # this is used to keep running the merge untill the file has detected a subtitle.
    while !(mkvmerge --identify "$MERGE_FILE" | grep -c -q 'subtitle') do
        echo "Subtitle is missing from merge file.  Rerunning merge"
        rm "$MERGE_FILE"
        merge "$MERGE_FILE" "$VIDEO_FILE" "$IMPORT_FILE" "$EXT" "$TYPE" "$LANG"
    done
    RESULT=$?
    # CLEAN UP  --------------------------------------------------------------------------
    if [ "$RESULT" -eq "0" ] || [ "$RESULT" -eq "1" ]; then
        RESULT=$([ "$RESULT" -eq "0" ] && echo "merge succeeded" || echo "merge completed with warnings")
        echo "$RESULT"
        echo "subtitle found successful"
        echo "Delete $IMPORT_FILE"
        rm "$IMPORT_FILE"
        echo "Delete $VIDEO_FILE"
        rm "$VIDEO_FILE"
        echo "Rename $MERGE_FILE to $FILE_NAME.mkv"
        mv "$MERGE_FILE" "$FILE_NAME.mkv"
        # rm "$MERGE_FILE"
    else
        RESULT="merge failed"
        echo "$RESULT"
    fi

    sendToWebhook
}

# LOOK FOR FILES ON STARTUP -------------------------------------------------------------
find "$DATA_DIR" -type f -name "*.???*.??.srt" -o -name "*.???*.???.srt" -o -name "*.idx" |
    while read file; do
        process "$file"
    done
    
# MONITOR FOR NEW FILES IN DIR ----------------------------------------------------------
inotifywait -m -r $DATA_DIR -e create -e moved_to --include '.*\.([a-z]{2,3}\.srt|idx)$' --format '%w%f' |
    while read file; do
        echo "The file '$file' was created/moved"
        process "$file"
    done
