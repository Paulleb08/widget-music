# MusicWidget

Petit widget flottant pour macOS qui affiche en direct la cover du morceau en cours (Spotify ou Apple Music).

Au survol de la souris apparaissent :
- les boutons précédent / lecture-pause / suivant ;
- un bouton paramètres (roue crantée) pour choisir le style **Liquid Glass** ou **Coloré**, et quitter.

Le widget se déplace en le faisant glisser ; sa position et le style sont mémorisés.

## Installation

```bash
./build.sh
```

Au premier lancement, macOS demande l'autorisation de contrôler Spotify / Music : il faut accepter.

Le vrai effet Liquid Glass nécessite macOS 26 et Xcode 26 ; sinon un flou translucide classique est utilisé.
