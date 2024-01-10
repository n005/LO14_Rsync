#!/bin/bash

# Chemins des fichiers en question
chemin_fichier1=$1
chemin_fichier2=$2

# Affiche une boîte de dialogue avec trois boutons pour choisir le fichier à supprimer
reponse=$(zenity --question --text="Choisissez le fichier à supprimer :" --ok-label="Supprimer fichier 1" --cancel-label="Supprimer fichier 2")

# Vérifie la réponse de l'utilisateur
if [ $? = 0 ]; then
    rm -rf "$chemin_fichier1"
    zenity --info --text="Le fichier 1 a été supprimé avec succès."
else
    rm -rf "$chemin_fichier2"
    zenity --info --text="Le fichier 2 a été supprimé avec succès."
fi
