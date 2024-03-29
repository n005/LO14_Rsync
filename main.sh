#!/bin/bash

function main() {
    # Check if the arguments are directories
    if [[ ! -d $1 || ! -d $2 ]]; then
        
zenity --error --title="Erreur Critique" --text="Error: $1 or $2 is not a directory." --ok-label="Fermer" --width=300  
      exit 1
    fi

    # Check if the directories are the same
    if [[ $1 -ef $2 ]]; then
zenity --error --title="Erreur Critique" --text="Error: $1 or $2 are the same." --ok-label="Fermer" --width=300  

        exit 1
    fi

    # Check if the directories are empty
    if [[ -z "$(ls -A $1)" ]]; then
zenity --error --title="Erreur Critique" --text="Error: $1 is empty." --ok-label="Fermer" --width=300  

        exit 1
    fi

    if [[ -z "$(ls -A $2)" ]]; then
zenity --error --title="Erreur Critique" --text="Error: $2 is empty." --ok-label="Fermer" --width=300  

        exit 1
    fi

    # Create the synchronization log file if it doesn't exist
    sync_log=".sync.log"
    if [[ ! -f $sync_log ]]; then
        touch $sync_log
    fi

    # Create the log file move file if it doesn't exist
    log_move=".log_move"
    if [[ ! -f $log_move ]]; then
        touch $log_move
    fi
    
    # Make write and read the two directories (and their subdirectories and files) for the current prosess
    # chmod -R 600 $1
    # chmod -R 600 $2

    # Create entry in the sync log for each file in $1 if not exist in $2 (and vice versa)
    # with size of the file, permissions, path, date of last modification, and hash

    for file in $(find -L $1 -type f); do
        # Get the path of the file relative to $1
        file_path=${file#$1}

        # Check if the file is already in the sync log or in $2
        if [[ -z "$(grep -E "^$file_path " $sync_log)" && ! -f "$2$file_path" ]]; then
            # Get the size of the file
            file_size=$(stat -c %s $file)

            # Get the permissions of the file
            file_permissions=$(stat -c %a $file)

            # Get the date of last modification of the file
            file_date=$(stat -c %y $file)

            # Get the hash of the file
            file_hash=$(sha256sum $file | cut -d ' ' -f 1)

            # Check if the file is not a folder in $2 and print conflict
            if [[ -d "$2$file_path" ]]; then
             # Affiche une boîte de dialogue avec trois boutons pour choisir le fichier à su
                    bash sip $1$file_path $2$file_path
            fi

            # Add the entry to the sync log
            echo "$file_path $file_size $file_permissions $file_date $file_hash" >> $sync_log

            # Copy the file to $2
            install -D -m $file_permissions $file $2$file_path

            # Add the entry to the log_move
            current_date=$(date +"%Y-%m-%d %H:%M:%S")
            echo "$current_date copy $file to $2$file_path" >> $log_move
        fi
    done

    # Same for $2
    for file in $(find -L $2 -type f); do
        # Get the path of the file relative to $2
        file_path=${file#$2}
        # Check if the file is already in the sync log or in $1
        if [[ -z "$(grep -E "^$file_path " $sync_log)" && ! -f "$1$file_path" ]]; then
            # Get the size of the file
            file_size=$(stat -c %s $file)

            # Get the permissions of the file
            file_permissions=$(stat -c %a $file)

            # Get the date of last modification of the file
            file_date=$(stat -c %y $file)

            # Get the hash of the file
            file_hash=$(sha256sum $file | cut -d ' ' -f 1)

            # Check if the file is not a folder in $1 and print conflict
            if [[ -d "$1$file_path" ]]; then
                bash sip $1$file_path $2$file_path
            fi
            # Add the entry to the sync log
            echo "$file_path $file_size $file_permissions $file_date $file_hash" >> $sync_log

            # Copy the file to $1
            install -D -m $file_permissions $file $1$file_path

            # Add the entry to the log_move
            current_date=$(date +"%Y-%m-%d %H:%M:%S")
            echo "$current_date copy $file to $1$file_path" >> $log_move
        fi
    done

    # Run sync function
    sync $1 $2

}

function difference() {
    # Check if the number of arguments is correct
    if [[ $# -ne 2 ]]; then
zenity --error --title="Erreur Critique" --text="Nombre de param incor." --ok-label="Fermer" --width=300  
  
        exit 1
    fi

    # Check if the arguments are files
    if [[ ! -f $1 || ! -f $2 ]]; then
zenity --error --title="Erreur Critique" --text="Error: $1 or $2 is not a file." --ok-label="Fermer" --width=300  
        
        exit 1
    fi

    # Check if the files are the same
    if [[ $1 -ef $2 ]]; then
zenity --error --title="Erreur Critique" --text="Error: $1 and $2 are the same file." --ok-label="Fermer" --width=300  

        exit 1
    fi

    # Check if the files are readable
    if [[ ! -r $1 || ! -r $2 ]]; then
zenity --error --title="Erreur Critique" --text="Error: $1 or $2 is not readable." --ok-label="Fermer" --width=300  
        exit 1
    fi
# Affiche une boîte de dialogue avec une question (Oui/Non)
zenity --question --text="Voulez-vous afficher la difference ?"

# Vérifie la réponse de l'utilisateur
if [ $? = 0 ]; then
    diff -u $1 $2

fi


    # Ask which file to keep and check if the answer is correct
reponse=$(zenity --question --text="Conflit détecté:\nChoisissez l'action à effectuer:" \
               --ok-label="supp fichier de $2" \
               --cancel-label="supp fichier $1" \
               --title="Résoudre le Conflit")
    # Vérifie la réponse de l'utilisateur
if [ $? -eq 0 ]; then
    current_date=$(date +"%Y-%m-%d %H:%M:%S")

        install -D -m $(stat -c %a $1) $1 $2
        # Add the entry to the log_move
        echo "$current_date copy $1 to $2" >> $log_move
    else
        install -D -m $(stat -c %a $2) $2 $1
        # Add the entry to the log_move
        echo "$current_date copy $2 to $1" >> $log_move
    fi

}

# Sync function
function sync() {
    #For loop for $1
    for file in $(find -L $1 -type f); do
        # Get the path of the file relative to $1
        file_path=${file#$1}
        
        # Get the path of the file relative to $2
        file_path2=${file#$2}

        # Check if the file is not a folder in $2 and print conflict
        if [[ -d "$2$file_path" ]]; then
            bash sip $1$file_path $2$file_path
        fi
        
        # Get the size of the file
        file_size=$(stat -c %s $file)

        # Get the permissions of the file
        file_permissions=$(stat -c %a $file)

        # Get the date of last modification of the file
        file_date=$(stat -c %y $file)

        # Get the hash of the file
        file_hash=$(sha256sum $file | cut -d ' ' -f 1)

        # Check the hash of $2 file
        file2_hash=$(sha256sum $2$file_path | cut -d ' ' -f 1)

        # Check if the file is already in the sync log
        if [[ -n "$(grep -E "^$file_path " $sync_log)" ]]; then
            # Get the size of the file in the sync log
            sync_log_file_size=$(grep -E "^$file_path " $sync_log | cut -d ' ' -f 2)

            # Get the permissions of the file in the sync log
            sync_log_file_permissions=$(grep -E "^$file_path " $sync_log | cut -d ' ' -f 3)

            # Get the date of last modification of the file in the sync log
            sync_log_file_date=$(grep -E "^$file_path " $sync_log | cut -d ' ' -f 4-6)

            # Get the hash of the file in the sync log
            sync_log_file_hash=$(grep -E "^$file_path " $sync_log | cut -d ' ' -f 7)

            # If the file in $1 is not the same in the sync log but $2 file is the same in the log sync
            # copy $1 file to $2, add replace sync log line by the new one
            if [[ $file_hash != $sync_log_file_hash && $sync_log_file_hash == $file2_hash ]]; then
                install -D -m $file_permissions $file $2$file_path
                # Add the entry to the log_move
                current_date=$(date +"%Y-%m-%d %H:%M:%S")
                echo "$current_date copy $file to $2$file_path" >> $log_move
                awk -v file_path="$file_path" -v sync_log_file_size="$sync_log_file_size" -v sync_log_file_permissions="$sync_log_file_permissions" -v sync_log_file_date="$sync_log_file_date" -v sync_log_file_hash="$sync_log_file_hash" -v file_size="$file_size" -v file_permissions="$file_permissions" -v file_date="$file_date" -v file_hash="$file_hash" '{ if ($0 ~ "^"file_path) { $0 = file_path " " file_size " " file_permissions " " file_date " " file_hash } print }' $sync_log > temp && mv temp $sync_log
            fi

            # If the file is in $1 and the sync log but not in $2
            # remove the file from $1, remove the entry from the sync log
            if [[ $file_hash == $sync_log_file_hash && ! -f "$2$file_path" ]]; then
                rm $file
                # Add the entry to the log_move
                current_date=$(date +"%Y-%m-%d %H:%M:%S")
                echo "$current_date remove $file" >> $log_move
                awk '!/^$file_path/' $sync_log > $sync_log
            fi

            # If neither $1 nor $2 files are the same in the sync log but they are not the same in $1 and $2
            # print conflict
            if [[ $file_hash != $sync_log_file_hash && $file2_hash != $sync_log_file_hash && $file_hash != $file2_hash ]]; then
                #echo "Conflict: $file_path is different in $1 and $2"
                # Summon diff
                difference $1$file_path $2$file_path
            fi

            # If neither $1 nor $2 files are the same in the sync log but they are the same in $1 and $2
            # add replace sync log line by the new one
            if [[ $file_hash != $sync_log_file_hash && $file_hash == $file2_hash ]]; then
                awk -v file_path="$file_path" -v sync_log_file_size="$sync_log_file_size" -v sync_log_file_permissions="$sync_log_file_permissions" -v sync_log_file_date="$sync_log_file_date" -v sync_log_file_hash="$sync_log_file_hash" -v file_size="$file_size" -v file_permissions="$file_permissions" -v file_date="$file_date" -v file_hash="$file_hash" '{ if ($0 ~ "^"file_path) { $0 = file_path " " file_size " " file_permissions " " file_date " " file_hash } print }' $sync_log > temp && mv temp $sync_log
            fi
        fi
        # If the file is in $1 and $2 but not in the sync log
        # add the entry to the sync log
        if [[ $file_hash == $file2_hash && -z "$(grep -E "^$file_path " $sync_log)" ]]; then
            echo "$file_path $file_size $file_permissions $file_date $file_hash" >> $sync_log
        fi

        # If the file in $1 are different from the file in $2 and not in the sync log
        # print conflict
        if [[ $file_hash != $file2_hash && -z "$(grep -E "^$file_path " $sync_log)" ]]; then
            #echo "Conflict: $file_path is different in $1 and $2"
            # Summon diff
            difference $1$file_path $2$file_path
        fi
    done

    # Same for $2
    for file in $(find -L $2 -type f); do
        # Get the path of the file relative to $2
        file_path=${file#$2}

        # Get the path of the file relative to $1
        file_path2=${file#$1}

        # Check if the file is not a folder in $1 and print conflict
        if [[ -d "$1$file_path" ]]; then
        bash sip $1$file_path $2$file_path

        fi

        # Get the size of the file
        file_size=$(stat -c %s $file)

        # Get the permissions of the file
        file_permissions=$(stat -c %a $file)

        # Get the date of last modification of the file
        file_date=$(stat -c %y $file)

        # Get the hash of the file
        file_hash=$(sha256sum $file | cut -d ' ' -f 1)

        # Check the hash of $1 file
        file2_hash=$(sha256sum $1$file_path | cut -d ' ' -f 1)

        # Check if the file is already in the sync log
        if [[ -n "$(grep -E "^$file_path " $sync_log)" ]]; then
            # Get the size of the file in the sync log
            sync_log_file_size=$(grep -E "^$file_path " $sync_log | cut -d ' ' -f 2)

            # Get the permissions of the file in the sync log
            sync_log_file_permissions=$(grep -E "^$file_path " $sync_log | cut -d ' ' -f 3)

            # Get the date of last modification of the file in the sync log
            sync_log_file_date=$(grep -E "^$file_path " $sync_log | cut -d ' ' -f 4-6)

            # Get the hash of the file in the sync log
            sync_log_file_hash=$(grep -E "^$file_path " $sync_log | cut -d ' ' -f 7)

            # If the file in $2 is not the same in the sync log but $1 file is the same in the log sync
            # copy $2 file to $1, add replace sync log line by the new one
            if [[ $file_hash != $sync_log_file_hash && $sync_log_file_hash == $file2_hash ]]; then
                install -D -m $file_permissions $file $1$file_path
                # Add the entry to the log_move
                current_date=$(date +"%Y-%m-%d %H:%M:%S")
                echo "$current_date copy $file to $1$file_path" >> $log_move
                awk -v file_path="$file_path" -v sync_log_file_size="$sync_log_file_size" -v sync_log_file_permissions="$sync_log_file_permissions" -v sync_log_file_date="$sync_log_file_date" -v sync_log_file_hash="$sync_log_file_hash" -v file_size="$file_size" -v file_permissions="$file_permissions" -v file_date="$file_date" -v file_hash="$file_hash" '{ if ($0 ~ "^"file_path) { $0 = file_path " " file_size " " file_permissions " " file_date " " file_hash } print }' $sync_log > temp && mv temp $sync_log
            fi

            # If the file is in $2 and the sync log but not in $1
            # remove the file from $2, remove the entry from the sync log
            if [[ $file_hash == $sync_log_file_hash && ! -f "$1$file_path" ]]; then
                rm $file
                # Add the entry to the log_move
                current_date=$(date +"%Y-%m-%d %H:%M:%S")
                echo "$current_date remove $file" >> $log_move
                awk -v file_path="$file_path" '{ if ($0 !~ "^"file_path) { print } }' $sync_log > temp && mv temp $sync_log
            fi

            # If neither $1 nor $2 files are the same in the sync log but they are not the same in $1 and $2
            # print conflict
            if [[ $file_hash != $sync_log_file_hash && $file2_hash != $sync_log_file_hash && $file_hash != $file2_hash ]]; then
                #echo "Conflict: $file_path is different in $1 and $2"
                # Summon diff
                difference $1$file_path $2$file_path
            fi

            # If neither $1 nor $2 files are the same in the sync log but they are the same in $1 and $2
            # add replace sync log line by the new one
            if [[ $file_hash != $sync_log_file_hash && $file_hash == $file2_hash ]]; then
                awk -v file_path="$file_path" -v sync_log_file_size="$sync_log_file_size" -v sync_log_file_permissions="$sync_log_file_permissions" -v sync_log_file_date="$sync_log_file_date" -v sync_log_file_hash="$sync_log_file_hash" -v file_size="$file_size" -v file_permissions="$file_permissions" -v file_date="$file_date" -v file_hash="$file_hash" '{ if ($0 ~ "^"file_path) { $0 = file_path " " file_size " " file_permissions " " file_date " " file_hash } print }' $sync_log > temp && mv temp $sync_log
            fi
        fi
        # If the file is in $1 and $2 but not in the sync log
        # add the entry to the sync log
        if [[ $file_hash == $file2_hash && -z "$(grep -E "^$file_path " $sync_log)" ]]; then
            echo "$file_path $file_size $file_permissions $file_date $file_hash" >> $sync_log
        fi
        # If the file in $1 are different from the file in $2 and not in the sync log
        # print conflict
        if [[ $file_hash != $file2_hash && -z "$(grep -E "^$file_path " $sync_log)" ]]; then
            #echo "Conflict: $file_path is different in $1 and $2"
            # Summon diff
            difference $1$file_path $2$file_path
        fi
    done
    
    # Run cleanup function
    cleanup $1 $2
}

# Clean up sync log function
function cleanup() {
    # For loop of the sync log
    while IFS= read -r line; do
        # Get the path of the file relative to $1
        file_path=$(echo $line | cut -d ' ' -f 1)
        file_path=${file_path#$1}
        # Get the path of the file relative to $2
        file_path2=$(echo $line | cut -d ' ' -f 1)
        file_path2=${file_path2#$2}

        # remove entry in the sync log if the file doesn't exist in $1 and $2
        if [[ ! -f "$1$file_path" && ! -f "$2$file_path2" ]]; then
            awk -v file_path="$file_path" '{ if ($0 !~ "^"file_path) { print } }' $sync_log > temp && mv temp $sync_log
        fi
    done < $sync_log

    # Delete duplicate entries in the sync log
    awk '!seen[$0]++' $sync_log > temp && mv temp $sync_log
}

# Check if the number of arguments is correct
if [[ $# -ne 2 ]]; then
    
zenity --error --title="Erreur Critique" --text="Nombre de parm incor." --ok-label="Fermer" --width=300

    exit 1
fi

# Check if the directories are readable
if [[ ! -r $1 || ! -r $2 ]]; then
    
zenity --error --title="Erreur Critique" --text="Error: $1 or $2 is not readable." --ok-label="Fermer" --width=300

    exit 1
fi

# Check if the directories are writable
if [[ ! -w $1 || ! -w $2 ]]; then
   
zenity --error --title="Erreur Critique" --text="Error: $1 or $2 is not writable." --ok-label="Fermer" --width=300

    exit 1
fi

# Call main function
main $1 $2
