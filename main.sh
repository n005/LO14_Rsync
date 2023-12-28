#!/bin/zsh

# Crée une syncronisation entre deux dossiers $A et $B en n'utilisant pas rsync
# mais en utilisant cp et rm. Le script doit être appelé avec deux arguments
# $A et $B qui sont les deux dossiers à synchroniser. Le script doit
# synchroniser les deux dossiers de la manière suivante :
# - Si un fichier est présent dans $A mais pas dans $B, alors le fichier est
#   copié de $A vers $B.
# - Si un fichier est présent dans $B mais pas dans $A, alors le fichier est
#   supprimé de $B.
# - Si un fichier est présent dans $A et dans $B, alors le fichier est copié
#   de $A vers $B si la date de dernière modification de $A est plus récente
#   que celle de $B. Sinon, le fichier est supprimé de $B.
# Il y a utilisation d'un journal de synchronisation qui est un fichier
# .sync.log qui contient la liste des fichiers p, le type et les permissions 
# du fichier p, la taille de p ainsi que la date de dernière modification de p.
# Ce fichier est créé s'il n'existe pas. 
# Si le fichier existe, alors le script doit lire son contenu et ne pas copier les
# fichiers qui sont déjà présents dans le journal. Le script doit ensuite
# ajouter à la fin du fichier les fichiers copiés et supprimés lors de la
# synchronisation.

# Main:

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

    # Read the synchronization log file
    while IFS= read -r line; do
        # Extract the file path from the log entry
        file=$(echo $line | awk '{print $1}')

        # Check if the file exists in both directories
        if [[ -f $1/$file && -f $2/$file ]]; then
            # Get the modification dates of the files
            date1=$(stat -c %Y $1/$file)
            date2=$(stat -c %Y $2/$file)

            # Compare the modification dates
            if [[ $date1 -gt $date2 ]]; then
                # Copy the file from $1 to $2
                cp $1/$file $2/$file
                echo "Copied $file from $1 to $2"
            elif [[ $date1 -lt $date2 ]]; then
                # Remove the file from $2
                rm $2/$file
                echo "Removed $file from $2"
            fi
        fi
    done < $sync_log

    # Synchronize the directories
    for file in $1/*; do
        # Extract the file name from the path
        filename=$(basename $file)

        # Check if the file exists in $2
        if [[ ! -f $2/$filename ]]; then
            # Copy the file from $1 to $2
            cp $file $2/$filename
            echo "Copied $filename from $1 to $2"
            echo "$filename" >> $sync_log
        fi
    done

    for file in $2/*; do
        # Extract the file name from the path
        filename=$(basename $file)

        # Check if the file exists in $1
        if [[ ! -f $1/$filename ]]; then
            # Remove the file from $2
            rm $file
            echo "Removed $filename from $2"
            echo "$filename" >> $sync_log
        fi
    done
}

# Crée une fonction qui affiche les différences entre deux fichiers texte, avec un + devant les lignes ajoutées et un - devant les lignes supprimées.

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


