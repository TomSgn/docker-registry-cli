#!/bin/bash

# Docker Registry CLI Script avec journalisation et whiptail
# Version: 2.8
# Auteur: TomSgn
# Description: Un outil CLI pour gérer les repositories et images Docker Registry avec journalisation et support interactif via whiptail.

# URL par défaut de votre Docker Registry
REGISTRY_URL="<Modifier>"
CURL_OPTS=""
USE_WHIPTAIL=false

# Fonction pour afficher l'aide
usage() {
    echo "Usage: $0 [options] <commande> [<args>]"
    echo ""
    echo "Options générales :"
    echo "  -k                      Ignorer la vérification du certificat SSL."
    echo "  -gnu                    Utiliser le mode interactif (whiptail)."
    echo "  -h, --help              Afficher ce message d'aide."
    echo ""
    echo "Commandes en mode ligne de commande :"
    echo "  list                    Lister tous les repositories et tags."
    echo "  list -r <repository>    Lister les tags pour un repository spécifique."
    echo "  get-manifest -r <repository> -t <tag>   Récupérer le manifest d'une image spécifique."
    echo "  delete-image -r <repository> [-t <tag> | -d <digest>]  Supprimer une image spécifique par tag ou digest."
    echo "  delete-all -r <repository>   Supprimer toutes les images (tags) d'un repository."
    echo "  pull -r <repository> -t <tag>  Pull une image depuis le registre."
    echo ""
    echo "Exemples :"
    echo "  $0 list"
    echo "  $0 list -r mon-repo"
    echo "  $0 get-manifest -r mon-repo -t latest"
    echo "  $0 delete-image -r mon-repo -t latest"
    echo "  $0 delete-all -r mon-repo"
    echo "  $0 pull -r mon-repo -t latest"
}

# Fonction pour récupérer la liste des repositories
get_repositories() {
    repos=$(curl -s $CURL_OPTS https://$REGISTRY_URL/v2/_catalog \
    | grep -oP '(?<="repositories":\[)[^]]+' \
    | tr -d '"' | tr ',' '\n')
    echo "$repos"
}

# Fonction pour lister tous les repositories et leurs tags
list_all() {
    repos=$(get_repositories)

    if [ -z "$repos" ]; then
        if [ "$USE_WHIPTAIL" == true ]; then
            whiptail --msgbox "Aucun repository trouvé." 10 50
        else
            echo "Aucun repository trouvé."
        fi
        exit 1
    fi

    output=""
    for repo in $repos; do
        output+="$repo:\n"
        tags=$(curl -s $CURL_OPTS https://$REGISTRY_URL/v2/$repo/tags/list \
        | grep -oP '(?<="tags":\[)[^]]*' \
        | tr -d '"' | tr ',' '\n')
        if [ -z "$tags" ]; then
            output+="  Aucun tag trouvé.\n"
        else
            for tag in $tags; do
                output+="  $tag\n"
            done
        fi
        output+="\n"
    done

    if [ "$USE_WHIPTAIL" == true ]; then
        tmpfile=$(mktemp)
        echo -e "$output" > "$tmpfile"
        whiptail --title "Repositories et Tags" --scrolltext \
        --textbox "$tmpfile" 25 80
        rm "$tmpfile"
    else
        echo -e "$output"
    fi
}

# Fonction pour lister les tags d'un repository spécifique
list_repo() {
    repo="$1"
    tags=$(curl -s $CURL_OPTS https://$REGISTRY_URL/v2/$repo/tags/list \
    | grep -oP '(?<="tags":\[)[^]]*' \
    | tr -d '"' | tr ',' '\n')

    if [ -z "$tags" ]; then
        if [ "$USE_WHIPTAIL" == true ]; then
            whiptail --msgbox "Aucun tag trouvé pour le repository '$repo'." \
            10 50
        else
            echo "Aucun tag trouvé pour le repository '$repo'."
        fi
        exit 1
    fi

    if [ "$USE_WHIPTAIL" == true ]; then
        whiptail --title "Tags pour $repo" --msgbox "$(echo "$tags")" 15 50
    else
        for tag in $tags; do
            echo "$tag"
        done
    fi
}

# Fonction pour récupérer le manifest d'une image
get_manifest() {
    repo="$1"
    tag="$2"
    manifest=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    $CURL_OPTS https://$REGISTRY_URL/v2/$repo/manifests/$tag)

    if [ -z "$manifest" ]; then
        if [ "$USE_WHIPTAIL" == true ]; then
            whiptail --msgbox "Échec de la récupération du manifest pour $repo:$tag." \
            10 50
        else
            echo "Échec de la récupération du manifest pour $repo:$tag."
        fi
        exit 1
    fi

    if [ "$USE_WHIPTAIL" == true ]; then
        tmpfile=$(mktemp)
        echo "$manifest" > "$tmpfile"
        whiptail --title "Manifest de $repo:$tag" --scrolltext \
        --textbox "$tmpfile" 25 80
        rm "$tmpfile"
    else
        echo "$manifest"
    fi
}

# Fonction pour récupérer le digest d'une image par tag avec journalisation
get_digest_by_tag() {
    repo="$1"
    tag="$2"

    echo "Récupération du digest pour le repository '$repo' et le tag '$tag'..." >> debug.log

    # Récupérer le digest à partir du tag
    digest_header=$(curl -sI -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    $CURL_OPTS https://$REGISTRY_URL/v2/$repo/manifests/$tag)

    echo "Requête Curl envoyée : curl -sI -H \"Accept: application/vnd.docker.distribution.manifest.v2+json\" $CURL_OPTS https://$REGISTRY_URL/v2/$repo/manifests/$tag" >> debug.log
    echo "Réponse de la requête :" >> debug.log
    echo "$digest_header" >> debug.log

    # Extraire le digest
    digest=$(echo "$digest_header" | grep -i Docker-Content-Digest | awk '{print $2}' | tr -d $'\r')

    if [ -z "$digest" ]; then
        echo "Échec de la récupération du digest pour $repo:$tag" >> debug.log
        if [ "$USE_WHIPTAIL" == true ]; then
            whiptail --msgbox "Échec de la récupération du digest pour $repo:$tag." 10 50
        else
            echo "Échec de la récupération du digest pour $repo:$tag."
        fi
        exit 1
    fi

    echo "Digest récupéré : $digest" >> debug.log
    echo "$digest"
}

# Fonction pour supprimer une image par tag ou digest
delete_image() {
    repo="$1"
    identifier="$2"
    id_type="$3"

    echo "Suppression de l'image pour le repository '$repo' avec l'identifiant '$identifier' (type: $id_type)..." >> debug.log

    if [ "$id_type" == "tag" ]; then
        # Récupérer le digest via le tag
        digest=$(get_digest_by_tag "$repo" "$identifier")
    else
        digest="$identifier"
    fi

    echo "Suppression de l'image avec le digest : $digest" >> debug.log

    # Supprimer l'image via le digest
    response=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    $CURL_OPTS https://$REGISTRY_URL/v2/$repo/manifests/$digest)

    echo "Requête Curl DELETE envoyée : curl -s -o /dev/null -w \"%{http_code}\" -X DELETE -H \"Accept: application/vnd.docker.distribution.manifest.v2+json\" $CURL_OPTS https://$REGISTRY_URL/v2/$repo/manifests/$digest" >> debug.log
    echo "Réponse HTTP : $response" >> debug.log

    if [ "$response" == "202" ]; then
        if [ "$USE_WHIPTAIL" == true ]; then
            whiptail --msgbox "Image supprimée avec succès." 10 50
        else
            echo "Image supprimée avec succès."
        fi
    else
        echo "Échec de la suppression de l'image. HTTP $response" >> debug.log
        if [ "$USE_WHIPTAIL" == true ]; then
            whiptail --msgbox "Échec de la suppression de l'image. HTTP $response" 10 50
        else
            echo "Échec de la suppression de l'image. HTTP $response"
        fi
        exit 1
    fi
}

# Fonction pour supprimer toutes les images d'un repository
delete_all_images() {
    repo="$1"
    tags=$(curl -s $CURL_OPTS https://$REGISTRY_URL/v2/$repo/tags/list \
    | grep -oP '(?<="tags":\[)[^]]*' \
    | tr -d '"' | tr ',' '\n')

    if [ -z "$tags" ]; then
        if [ "$USE_WHIPTAIL" == true ]; then
            whiptail --msgbox "Aucun tag trouvé pour le repository '$repo'." \
            10 50
        else
            echo "Aucun tag trouvé pour le repository '$repo'."
        fi
        exit 1
    fi

    if [ "$USE_WHIPTAIL" == true ]; then
        whiptail --yesno "Êtes-vous sûr de vouloir supprimer toutes les images du repository '$repo' ?" \
        10 60
        response=$?
        if [ $response -ne 0 ]; then
            whiptail --msgbox "Opération annulée." 10 50
            exit 0
        fi
    else
        echo "Êtes-vous sûr de vouloir supprimer toutes les images du repository '$repo' ? (y/N)"
        read confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Opération annulée."
            exit 0
        fi
    fi

    for tag in $tags; do
        if [ "$USE_WHIPTAIL" != true ]; then
            echo "Suppression de $repo:$tag..."
        fi
        delete_image "$repo" "$tag" "tag"
    done

    if [ "$USE_WHIPTAIL" == true ]; then
        whiptail --msgbox "Toutes les images ont été supprimées du repository '$repo'." \
        10 50
    else
        echo "Toutes les images ont été supprimées du repository '$repo'."
    fi
}

# Fonction pour pull une image avec un input whiptail
pull_image_with_whiptail() {
    # Utilisation de whiptail pour demander l'URL de l'image (incluant le tag ou manifest)
    image_url=$(whiptail --inputbox "Entrez l'URL de l'image (incluant le tag ou manifest):" 10 60 "" 3>&1 1>&2 2>&3)

    # Vérification si l'utilisateur a bien entré quelque chose
    if [ -z "$image_url" ]; then
        whiptail --msgbox "Aucune URL fournie. Opération annulée." 10 50
        exit 1
    fi

    # Pull de l'image
    docker pull "$image_url"
    if [ $? -eq 0 ]; then
        whiptail --msgbox "Image $image_url téléchargée avec succès." 10 50
    else
        whiptail --msgbox "Échec du téléchargement de l'image $image_url." 10 50
        exit 1
    fi
}

# Fonction pour afficher le menu principal en mode interactif
main_menu() {
    while true; do
        CHOICE=$(whiptail --title "Docker Registry CLI" \
        --menu "Choisissez une option :" 15 60 7 \
            "1" "Lister tous les repositories et tags" \
            "2" "Lister les tags d'un repository" \
            "3" "Récupérer le manifest d'une image" \
            "4" "Supprimer une image" \
            "5" "Supprimer toutes les images d'un repository" \
            "6" "Pull une image (avec URL)" \
            "7" "Quitter" 3>&1 1>&2 2>&3)

        case $CHOICE in
            1)
                list_all
                ;;
            2)
                select_repository
                list_repo "$REPO"
                ;;
            3)
                select_repository
                select_tag "$REPO"
                get_manifest "$REPO" "$TAG"
                ;;
            4)
                select_repository
                select_tag "$REPO"
                delete_image "$REPO" "$TAG" "tag"
                ;;
            5)
                select_repository
                delete_all_images "$REPO"
                ;;
            6)
                pull_image_with_whiptail
                ;;
            7)
                exit 0
                ;;
        esac
    done
}

# Fonction pour sélectionner un repository
select_repository() {
    repos=$(get_repositories)

    if [ -z "$repos" ]; then
        whiptail --msgbox "Aucun repository trouvé." 10 50
        exit 1
    fi

    repo_array=()
    for repo in $repos; do
        repo_array+=("$repo" "")
    done

    REPO=$(whiptail --title "Sélectionnez un repository" --menu \
    "Liste des repositories :" 20 60 10 "${repo_array[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$REPO" ]; then
        whiptail --msgbox "Aucun repository sélectionné." 10 50
        exit 1
    fi
}

# Fonction pour sélectionner un tag
select_tag() {
    repo="$1"
    tags_json=$(curl -s $CURL_OPTS https://$REGISTRY_URL/v2/$repo/tags/list)

    if [ -z "$tags_json" ]; then
        whiptail --msgbox "Aucun tag trouvé pour le repository '$repo'." 10 50
        exit 1
    fi

    # Extraire les tags correctement
    tags=$(echo "$tags_json" | grep -oP '(?<="tags":\[)[^\]]*' | tr -d '\"' | tr ',' '\n')

    if [ -z "$tags" ]; then
        whiptail --msgbox "Aucun tag disponible pour le repository '$repo'." 10 50
        exit 1
    fi

    # Nettoyer les tags pour enlever les espaces vides
    tags=$(echo "$tags" | sed '/^\s*$/d')

    tag_array=()
    for tag in $tags; do
        tag_array+=("$tag" "")
    done

    TAG=$(whiptail --title "Sélectionnez un tag" --menu \
    "Liste des tags pour $repo :" 20 60 10 "${tag_array[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$TAG" ]; then
        whiptail --msgbox "Aucun tag sélectionné." 10 50
        exit 1
    fi
}

# Script principal
if [ $# -eq 0 ]; then
    main_menu
fi

# Parsing des options générales
while true; do
    case "$1" in
        -k)
            CURL_OPTS="-k"
            shift
            ;;
        -gnu)
            USE_WHIPTAIL=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

if [ "$USE_WHIPTAIL" == true ]; then
    main_menu
    exit 0
fi

# Gestion des autres commandes en ligne de commande
COMMAND="$1"
shift

case "$COMMAND" in
    list)
        while getopts ":r:" opt; do
            case $opt in
                r)
                    REPO="$OPTARG"
                    ;;
                \?)
                    echo "Option invalide : -$OPTARG" >&2
                    usage
                    exit 1
                    ;;
                :)
                    echo "L'option -$OPTARG requiert un argument." >&2
                    usage
                    exit 1
                    ;;
            esac
        done
        if [ -z "$REPO" ]; then
            list_all
        else
            list_repo "$REPO"
        fi
        ;;
    get-manifest)
        while getopts ":r:t:" opt; do
            case $opt in
                r)
                    REPO="$OPTARG"
                    ;;
                t)
                    TAG="$OPTARG"
                    ;;
                \?)
                    echo "Option invalide : -$OPTARG" >&2
                    usage
                    exit 1
                    ;;
                :)
                    echo "L'option -$OPTARG requiert un argument." >&2
                    usage
                    exit 1
                    ;;
            esac
        done
        if [ -z "$REPO" ] || [ -z "$TAG" ];then
            echo "Erreur : Le repository et le tag sont requis."
            usage
            exit 1
        fi
        get_manifest "$REPO" "$TAG"
        ;;
    delete-image)
        while getopts ":r:t:d:" opt; do
            case $opt in
                r)
                    REPO="$OPTARG"
                    ;;
                t)
                    IDENTIFIER="$OPTARG"
                    ID_TYPE="tag"
                    ;;
                d)
                    IDENTIFIER="$OPTARG"
                    ID_TYPE="digest"
                    ;;
                \?)
                    echo "Option invalide : -$OPTARG" >&2
                    usage
                    exit 1
                    ;;
                :)
                    echo "L'option -$OPTARG requiert un argument." >&2
                    usage
                    exit 1
                    ;;
            esac
        done
        if [ -z "$REPO" ] || [ -z "$IDENTIFIER" ]; then
            echo "Erreur : Le repository et le tag ou le digest sont requis."
            usage
            exit 1
        fi
        delete_image "$REPO" "$IDENTIFIER" "$ID_TYPE"
        ;;
    delete-all)
        while getopts ":r:" opt; do
            case $opt in
                r)
                    REPO="$OPTARG"
                    ;;
                \?)
                    echo "Option invalide : -$OPTARG" >&2
                    usage
                    exit 1
                    ;;
                :)
                    echo "L'option -$OPTARG requiert un argument." >&2
                    usage
                    exit 1
                    ;;
            esac
        done
        if [ -z "$REPO" ]; then
            echo "Erreur : Le repository est requis."
            usage
            exit 1
        fi
        delete_all_images "$REPO"
        ;;
    pull)
        while getopts ":r:t:" opt; do
            case $opt in
                r)
                    REPO="$OPTARG"
                    ;;
                t)
                    TAG="$OPTARG"
                    ;;
                \?)
                    echo "Option invalide : -$OPTARG" >&2
                    usage
                    exit 1
                    ;;
                :)
                    echo "L'option -$OPTARG requiert un argument." >&2
                    usage
                    exit 1
                    ;;
            esac
        done
        if [ -z "$REPO" ] || [ -z "$TAG" ]; then
            echo "Erreur : Le repository et le tag sont requis."
            usage
            exit 1
        fi
        pull_image "$REPO" "$TAG"
        ;;
    *)
        echo "Commande inconnue : $COMMAND"
        usage
        exit 1
        ;;
esac
