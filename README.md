# MusicWidget

Petit widget flottant pour macOS qui affiche en direct la cover du morceau en cours sur Apple Music.

Au survol de la souris apparaissent :
- les boutons précédent / lecture-pause / suivant ;
- un bouton paramètres (roue crantée) pour choisir le style **Liquid Glass** ou **Coloré**, et quitter.

Le widget se déplace en le faisant glisser ; sa position et le style sont mémorisés.

## Tuto d'installation

Ouvre l'app **Terminal** (Cmd + Espace, tape « Terminal », Entrée), puis colle les commandes une par une.

**1. Installer les outils de compilation** (une seule fois, environ 5 minutes)

```bash
xcode-select --install
```

Une fenêtre s'ouvre : clique « Installer » et attends la fin. Si le Terminal répond « already installed », passe à l'étape 2.

**2. Télécharger le widget**

```bash
cd ~ && git clone -b claude/intelligent-edison-yrlmsl https://github.com/Paulleb08/widget-music.git
```

**3. Compiler et lancer**

```bash
cd ~/widget-music && ./build.sh
```

Le widget apparaît au milieu de l'écran. Lance un morceau dans Music : macOS demande si MusicWidget peut contrôler Music, clique **Autoriser**. (Si tu as cliqué « Refuser » : Réglages Système → Confidentialité et sécurité → Automatisation → MusicWidget → coche Music.)

**4. (Optionnel) Le garder dans Applications et le lancer au démarrage du Mac**

```bash
cp -R ~/widget-music/MusicWidget.app /Applications/
```

Puis Réglages Système → Général → Ouverture → « Ouvrir à l'ouverture de session » → **+** → choisis MusicWidget dans Applications.

## Mettre à jour

```bash
cd ~/widget-music && git pull && ./build.sh
```

## Utilisation

- **Déplacer** : clique-glisse le widget.
- **Contrôles et réglages** : passe la souris sur la cover.
- **Changer de style** : roue crantée → Liquid Glass ou Coloré.
- **Quitter** : roue crantée → Quitter.

Le vrai effet Liquid Glass nécessite macOS 26 ; sur les versions plus anciennes, un flou translucide classique est utilisé.
