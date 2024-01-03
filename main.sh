#!/bin/bash

function main() {
    # Check if the number of arguments is correct
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <dir1> <dir2>"
        exit 1
    fi

    # Check if the arguments are directories
    if [[ ! -d $1 || ! -d $2 ]]; then
        echo "Error: $1 or $2 is not a directory"
        exit 1
    fi

    # Check if the directories are the same
    if [[ $1 -ef $2 ]]; then
        echo "Error: $1 and $2 are the same directory"
        exit 1
    fi

    # Check if the directories are empty
    if [[ -z "$(ls -A $1)" ]]; then
        echo "Error: $1 is empty"
        exit 1
    fi

    if [[ -z "$(ls -A $2)" ]]; then
        echo "Error: $2 is empty"
        exit 1
    fi

    # Check if the directories are readable
    if [[ ! -r $1 || ! -r $2 ]]; then
        echo "Error: $1 or $2 is not readable"
        exit 1
    fi

    # Check if the directories are writable
    if [[ ! -w $1 || ! -w $2 ]]; then
        echo "Error: $1 or $2 is not writable"
        exit 1
    fi

    # Create the synchronization log file if it doesn't exist
    sync_log=".sync.log"
    if [[ ! -f $sync_log ]]; then
        touch $sync_log
    fi
    
    # Make write and read the two directories (and their subdirectories and files) for the current prosess
    # chmod -R 600 $1
    # chmod -R 600 $2

    # Create entry in the sync log for each file in $1 if not exist in $2 (and vice versa)
    # with size of the file, permissions, path, date of last modification, and hash

    for file in $(find $1 -type f); do
        # Get the path of the file relative to $1
        file_path=${file#$1}

        # Check if the file is already in the sync log or in $2
        if [[ -z "$(grep -E "^$file_path" $sync_log)" || ! -f "$2$file_path" ]]; then
            # Get the size of the file
            file_size=$(stat -c %s $file)

            # Get the permissions of the file
            file_permissions=$(stat -c %a $file)

            # Get the date of last modification of the file
            file_date=$(stat -c %y $file)

            # Get the hash of the file
            file_hash=$(sha256sum $file | cut -d ' ' -f 1)

            # Add the entry to the sync log
            echo "$file_path $file_size $file_permissions $file_date $file_hash" >> $sync_log

            # Copy the file to $2
            cp $file $2$file_path
        fi
    done

    # Same for $2
    for file in $(find $2 -type f); do
        # Get the path of the file relative to $2
        file_path=${file#$2}

        # Check if the file is already in the sync log or in $1
        if [[ -z "$(grep -E "^$file_path" $sync_log)" || ! -f "$1$file_path" ]]; then
            # Get the size of the file
            file_size=$(stat -c %s $file)

            # Get the permissions of the file
            file_permissions=$(stat -c %a $file)

            # Get the date of last modification of the file
            file_date=$(stat -c %y $file)

            # Get the hash of the file
            file_hash=$(sha256sum $file | cut -d ' ' -f 1)

            # Add the entry to the sync log
            echo "$file_path $file_size $file_permissions $file_date $file_hash" >> $sync_log

            # Copy the file to $1
            cp $file $1$file_path
        fi
    done

    # Run sync function
    sync $1 $2

}

function diff() {
    # Check if the number of arguments is correct
    if [[ $# -ne 2 ]]; then
        echo "Usage: $0 <file1> <file2>"
        exit 1
    fi

    # Check if the arguments are files
    if [[ ! -f $1 || ! -f $2 ]]; then
        echo "Error: $1 or $2 is not a file"
        exit 1
    fi

    # Check if the files are the same
    if [[ $1 -ef $2 ]]; then
        echo "Error: $1 and $2 are the same file"
        exit 1
    fi

    # Check if the files are readable
    if [[ ! -r $1 || ! -r $2 ]]; then
        echo "Error: $1 or $2 is not readable"
        exit 1
    fi

    diff -u $1 $2 | grep -E '^\+|^-'
}

# Sync function
function sync() {
    #For loop for $1
    for file in $(find $1 -type f); do
        # Get the path of the file relative to $1
        file_path=${file#$1}
        
        # Get the path of the file relative to $2
        file_path2=${file#$2}

        # Check if the file is not a folder in $2 and print conflict
        if [[ -d "$2$file_path" ]]; then
            echo "Conflict: $file_path is a file in $1 and a folder in $2"
        fi

        # Get the size of the file
        file_size=$(stat -c %s $file)

        # Get the permissions of the file
        file_permissions=$(stat -c %a $file)

        # Get the date of last modification of the file
        file_date=$(stat -c %y $file)

        # Get the hash of the file
        file_hash=$(sha256sum $file | cut -d ' ' -f 1)

        # Check if the file is already in the sync log
        if [[ -n "$(grep -E "^$file_path" $sync_log)" ]]; then
            # Get the size of the file in the sync log
            sync_log_file_size=$(grep -E "^$file_path" $sync_log | cut -d ' ' -f 2)

            # Get the permissions of the file in the sync log
            sync_log_file_permissions=$(grep -E "^$file_path" $sync_log | cut -d ' ' -f 3)

            # Get the date of last modification of the file in the sync log
            sync_log_file_date=$(grep -E "^$file_path" $sync_log | cut -d ' ' -f 4)

            # Get the hash of the file in the sync log
            sync_log_file_hash=$(grep -E "^$file_path" $sync_log | cut -d ' ' -f 5)

            # Check the hash of $2 file
            file2_hash=$(sha256sum $2$file_path | cut -d ' ' -f 1)

            # If the file in $1 is not the same in the sync log but $2 file is the same in the log sync
            # copy $1 file to $2, add replace sync log line by the new one
            if [[ $file_hash != $sync_log_file_hash && $file_hash == $file2_hash ]]; then
                cp $file $2$file_path
                sed -i "s/^$file_path $sync_log_file_size $sync_log_file_permissions $sync_log_file_date $sync_log_file_hash/$file_path $file_size $file_permissions $file_date $file_hash/" $sync_log
            fi

            # If neither $1 nor $2 files are the same in the sync log but they are the same in $1 and $2
            # add replace sync log line by the new one
            if [[ $file_hash != $sync_log_file_hash && $file_hash == $file2_hash ]]; then
                sed -i "s/^$file_path $sync_log_file_size $sync_log_file_permissions $sync_log_file_date $sync_log_file_hash/$file_path $file_size $file_permissions $file_date $file_hash/" $sync_log
            fi

            # If neither $1 nor $2 files are the same in the sync log but they are not the same in $1 and $2
            # print conflict
            if [[ $file_hash != $sync_log_file_hash && $file_hash != $file2_hash ]]; then
                echo "Conflict: $file_path is different in $1 and $2"
            fi
        fi
    done

    # Same for $2
    for file in $(find $2 -type f); do
        # Get the path of the file relative to $2
        file_path=${file#$2}

        # Get the path of the file relative to $1
        file_path2=${file#$1}

        # Check if the file is not a folder in $1 and print conflict
        if [[ -d "$1$file_path" ]]; then
            echo "Conflict: $file_path is a file in $2 and a folder in $1"
        fi

        # Get the size of the file
        file_size=$(stat -c %s $file)

        # Get the permissions of the file
        file_permissions=$(stat -c %a $file)

        # Get the date of last modification of the file
        file_date=$(stat -c %y $file)

        # Get the hash of the file
        file_hash=$(sha256sum $file | cut -d ' ' -f 1)

        # Check if the file is already in the sync log
        if [[ -n "$(grep -E "^$file_path" $sync_log)" ]]; then
            # Get the size of the file in the sync log
            sync_log_file_size=$(grep -E "^$file_path" $sync_log | cut -d ' ' -f 2)

            # Get the permissions of the file in the sync log
            sync_log_file_permissions=$(grep -E "^$file_path" $sync_log | cut -d ' ' -f 3)

            # Get the date of last modification of the file in the sync log
            sync_log_file_date=$(grep -E "^$file_path" $sync_log | cut -d ' ' -f 4)

            # Get the hash of the file in the sync log
            sync_log_file_hash=$(grep -E "^$file_path" $sync_log | cut -d ' ' -f 5)

            # Check the hash of $1 file
            file2_hash=$(sha256sum $1$file_path | cut -d ' ' -f 1)

            # If the file in $2 is not the same in the sync log but $1 file is the same in the log sync
            # copy $2 file to $1, add replace sync log line by the new one
            if [[ $file_hash != $sync_log_file_hash && $file_hash == $file2_hash ]]; then
                cp $file $1$file_path
                sed -i "s/^$file_path $sync_log_file_size $sync_log_file_permissions $sync_log_file_date $sync_log_file_hash/$file_path $file_size $file_permissions $file_date $file_hash/" $sync_log
            fi

            # If neither $1 nor $2 files are the same in the sync log but they are the same in $1 and $2
            # add replace sync log line by the new one
            if [[ $file_hash != $sync_log_file_hash && $file_hash == $file2_hash ]]; then
                sed -i "s/^$file_path $sync_log_file_size $sync_log_file_permissions $sync_log_file_date $sync_log_file_hash/$file_path $file_size $file_permissions $file_date $file_hash/" $sync_log
            fi

            # If neither $1 nor $2 files are the same in the sync log but they are not the same in $1 and $2
            # print conflict
            if [[ $file_hash != $sync_log_file_hash && $file_hash != $file2_hash ]]; then
                echo "Conflict: $file_path is different in $1 and $2"
            fi
        fi
    done
}

# Call main function
main $1 $2