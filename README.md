# Docker Registry CLI Script

## Description
Ce script permet de gérer un registre Docker privé. Il offre une interface interactive (via `whiptail`) pour lister les repositories, supprimer des images, récupérer des manifests, et **pull** des images directement depuis un registre Docker.

Le script prend également en charge l'exécution en mode non interactif (ligne de commande) pour une utilisation automatisée.

## Prérequis
- `docker` doit être installé sur la machine.
- `whiptail` doit être installé pour utiliser l'interface interactive.
- Un accès à un registre Docker privé.

## Installation
1. Téléchargez ou clonez le script dans le répertoire souhaité.
2. Assurez-vous que le script est exécutable :
   ```bash
   chmod +x docker_registry_cli.sh
   ```
3. Changez les variables situé en haut du script

## Utilisation

### Mode interactif (interface `whiptail`)
Pour utiliser le script en mode interactif, lancez-le avec l'option `-gnu` :
```bash
./docker_registry_cli.sh -gnu
```

Cela ouvrira un menu avec les options suivantes :
- **Lister tous les repositories et tags** : Affiche la liste des repositories présents dans le registre, avec leurs tags respectifs.
- **Lister les tags d'un repository** : Vous permet de choisir un repository et de lister ses tags.
- **Récupérer le manifest d'une image** : Sélectionnez un repository et un tag pour afficher le manifest de l'image.
- **Supprimer une image** : Sélectionnez un repository et un tag, puis supprimez l'image correspondante.
- **Supprimer toutes les images d'un repository** : Supprime toutes les images associées à un repository spécifique.
- **Pull une image (avec URL)** : Permet de pull une image en saisissant l'URL complète (incluant le tag ou le digest).
- **Quitter** : Quitter le script.

### Mode ligne de commande
Le script peut être utilisé directement en ligne de commande avec les options suivantes :

```bash
./docker_registry_cli.sh [options] <commande> [<args>]
```

#### Options
- `-k` : Ignorer la vérification du certificat SSL.
- `-gnu` : Utiliser le mode interactif avec `whiptail`.
- `-h` ou `--help` : Afficher l'aide.

#### Commandes disponibles

- `list` : Lister tous les repositories et tags.
  - Exemple :
    ```bash
    ./docker_registry_cli.sh list
    ```

- `list -r <repository>` : Lister les tags d'un repository spécifique.
  - Exemple :
    ```bash
    ./docker_registry_cli.sh list -r mon-repo
    ```

- `get-manifest -r <repository> -t <tag>` : Récupérer le manifest d'une image spécifique.
  - Exemple :
    ```bash
    ./docker_registry_cli.sh get-manifest -r mon-repo -t latest
    ```

- `delete-image -r <repository> [-t <tag> | -d <digest>]` : Supprimer une image spécifique par tag ou digest.
  - Exemple :
    ```bash
    ./docker_registry_cli.sh delete-image -r mon-repo -t latest
    ```

- `delete-all -r <repository>` : Supprimer toutes les images d'un repository.
  - Exemple :
    ```bash
    ./docker_registry_cli.sh delete-all -r mon-repo
    ```

- `pull -r <repository> -t <tag>` : Pull une image spécifique depuis le registre.
  - Exemple :
    ```bash
    ./docker_registry_cli.sh pull -r mon-repo -t latest
    ```

## Journalisation
Les requêtes et réponses HTTP effectuées par le script sont journalisées dans un fichier `debug.log` pour faciliter le débogage.

## Exemples d'utilisation

### Mode interactif
Lancez le script en mode interactif :
```bash
./docker_registry_cli.sh -gnu
```

### Lister les repositories
Lister tous les repositories disponibles :
```bash
./docker_registry_cli.sh list
```

### Supprimer une image
Supprimer une image par son tag :
```bash
./docker_registry_cli.sh delete-image -r mon-repo -t latest
```

### Pull une image
Pull une image spécifique en ligne de commande :
```bash
./docker_registry_cli.sh pull -r mon-repo -t latest
```

### Pull une image avec l'URL (mode interactif)
Utiliser le menu interactif pour saisir l'URL complète d'une image à puller :
```bash
./docker_registry_cli.sh -gnu
```

Puis, dans le menu, choisissez l'option **Pull une image (avec URL)** et entrez l'URL.

## Licence
Ce script est distribué sous licence libre. Utilisation à vos propres risques.

## Auteurs
- TomSgn
