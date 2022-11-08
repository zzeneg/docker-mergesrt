#!/bin/sh

sendToWebhook() {
    if [ -n "$WEBHOOK_URL" ] && [ -n "$WEBHOOK_TEMPLATE" ]; then
        data=$(eval "echo \"$WEBHOOK_TEMPLATE\"")
        curl -s -S -X POST -d "$data" -H "Content-Type: application/json" $WEBHOOK_URL
    fi
}

mergecommand() {
    merge=$1
    video=$2
    import=$3
    ext=$4
    type=$5
    lang=$6

    case $ext in
                srt)
                    if [ "$type" == "sdh" ] || [ "$type" == "hi" ] || [ "$type" == "cc" ]; then
                        mkvmerge -o "$merge" "$video" --language 0:$lang --track-name 0:$type --hearing-impaired-flag 0:true "$import"
                    elif [ "$type" == "forced" ]; then
                        mkvmerge -o "$merge" "$video" --language 0:$lang --track-name 0:$type --forced-display-flag 0:true "$import"
                    else
                        mkvmerge -o "$merge" "$video" --language 0:$lang --track-name 0:$lang "$import"
                    fi
                    return 
                    ;;
                idx)
                    mkvmerge -o "$merge" "$video" "$import"
                    ;;
            esac
}

# MERGE SRT FILES HERE -----------------------------------------------------------------
mergesrt() {
    IMPORT_FILE=$1
    FILE_COUNT=0
    echo "Imported file: $IMPORT_FILE" |& tee -a "$DATA_DIR\output.txt"
    # PARSE FILE COMPONENTS ------------------------------------------------------------
    EXT=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f1 | rev)
    echo "Extension: $EXT" | tee -a "$DATA_DIR\output.txt"
    LANG=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f2 | rev)
    echo "Subtitle language: $LANG" | tee -a "$DATA_DIR\output.txt"
    TYPE=$(echo "$IMPORT_FILE" | rev | cut -d'.' -f3 | rev)
    if [ "$TYPE" == 'sdh' ] || [ "$TYPE" == 'forced' ] || [ "$TYPE" == 'hi' ] || [ "$TYPE" == 'cc' ]; then
        echo "Subtitle type: $TYPE" | tee -a "$DATA_DIR\output.txt"
        FILE_NAME=$(echo "$IMPORT_FILE" | sed 's|\.'"$TYPE"'\.'"$LANG"'\.'"$EXT"'||')
    else 
        TYPE=""
        FILE_NAME=$(echo "$IMPORT_FILE" | sed 's|\.'"$LANG"'\.'"$EXT"'||')
    fi
    echo "File name: $FILE_NAME" | tee -a "$DATA_DIR\output.txt"
    
    VIDEO_FILE=$FILE_NAME'.mkv'
    # CHECK IF VIDEO EXISTS -------------------------------------------------------------
    if [ ! -f "$VIDEO_FILE" ]; then
        VIDEO_FILE=$FILE_NAME'.mp4'
    fi
    if [ ! -f "$VIDEO_FILE" ]; then
        echo "File $VIDEO_FILE does not exist, skipping" | tee -a "$DATA_DIR\output.txt"
        return
    fi
    echo "File $VIDEO_FILE exists, start merging" | tee -a "$DATA_DIR\output.txt"
    MERGE_FILE=$FILE_NAME'.merge'
    # MKVMERGE COMMAND BASED ON TYPE ----------------------------------------------------
    # When doing large batches sometimes the merge does not seem to work correctly.
    # this is used to keep running the merge untill the file has detected a subtitle.
    
    mergecommand "$MERGE_FILE" "$VIDEO_FILE" "$IMPORT_FILE" "$EXT" "$TYPE" "$LANG"
    
    while !(mkvmerge --identify "$MERGE_FILE" | grep -c -q 'subtitle') do
        echo "Subtitle is missing from merge file.  Rerunning merge" | tee -a "$DATA_DIR\output.txt"
        rm "$MERGE_FILE"
        mergecommand "$MERGE_FILE" "$VIDEO_FILE" "$IMPORT_FILE" "$EXT" "$TYPE" "$LANG"
    done
    RESULT=$?
    # CLEAN UP  --------------------------------------------------------------------------
    if [ "$RESULT" -eq "0" ] || [ "$RESULT" -eq "1" ]; then
        RESULT=$([ "$RESULT" -eq "0" ] && echo "merge succeeded" || echo "merge completed with warnings") | tee -a "$DATA_DIR\output.txt"
        echo "$RESULT" | tee -a "$DATA_DIR\output.txt"
        echo "subtitle found successful" | tee -a "$DATA_DIR\output.txt"
        #echo "Delete $IMPORT_FILE"
        #rm "$IMPORT_FILE"
        echo "Delete $VIDEO_FILE" | tee -a "$DATA_DIR\output.txt"
        rm "$VIDEO_FILE"
        echo "Rename $MERGE_FILE to $FILE_NAME.mkv" | tee -a "$DATA_DIR\output.txt"
        mv "$MERGE_FILE" "$FILE_NAME.mkv"
        # rm "$MERGE_FILE"
    else
        RESULT="merge failed" | tee -a "$DATA_DIR\output.txt"
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
    #mkvmerge -o "$MERGE_FILE" "$VIDEO_FILE" "$IMPORT_FILE"
    mergecommand "$MERGE_FILE" "$VIDEO_FILE" "$IMPORT_FILE"
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
find "$DATA_DIR" -type f -name "*.???*.??.srt" -o -name "*.???*.???.srt" -o -name "*.idx" |
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
