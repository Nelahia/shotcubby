# Brief logo — ShotCubby

> À donner tel quel à une conversation Claude dédiée à la création du logo.
> Contient tout le contexte nécessaire sur l'app, sans avoir à lire le repo.

## L'application

**ShotCubby** est une app macOS légère qui vit dans la barre de menu (menu bar), écrite en
Swift/SwiftUI/AppKit. Elle n'a pas d'icône dans le Dock (`NSApp.setActivationPolicy(.accessory)`)
— son seul point de présence visible en permanence à l'écran est l'icône dans la barre de menu,
tout en haut à droite de l'écran, à côté de l'horloge, du Wi-Fi, etc.

**Ce qu'elle fait** : elle capture automatiquement tous les screenshots pris via les raccourcis
macOS standards et les range dans un dossier unique (`~/ShotCubby`) au lieu de les laisser
s'accumuler en vrac sur le Bureau.

- `⌘⇧3` / `⌘⇧4` (capture écran entier / sélection) → le fichier est détecté puis déplacé
- `⌘⇧⌃3` / `⌘⇧⌃4` (copie dans le presse-papiers) → l'image est détectée et sauvegardée

Cliquer sur l'icône de la barre de menu ouvre un popover avec :
- une grille de miniatures des derniers screenshots
- au survol : copier / révéler dans le Finder / supprimer
- un compteur de screenshots dans l'en-tête
- un bouton "Open Folder" pour sauter direct dans `~/ShotCubby`

## Distribution & personnalité

- Closed source, zéro dépendance externe, zéro télémétrie
- Build signé (Developer ID) + notarisé par Apple
- Public : utilisateurs mac un peu power-user, qui vivent dans leur barre de menu et
  veulent un outil qui s'efface — pas une app "fun" ou grand public, plutôt un outil
  de précision, discret, rapide

## Direction visuelle déjà posée (à respecter pour cohérence)

Une landing page a déjà été dessinée pour le site d'installation, avec cette identité :

- **Palette** : fond neutre froid (gris-bleu très clair en light, quasi noir en dark),
  encre quasi-noire pour le texte, et un **accent cyan-teal vif** :
  `#0FB6C9` en light theme, `#35D6E6` en dark theme. Cet accent fait écho à la couleur
  du rectangle de sélection que macOS dessine à l'écran quand on fait `⌘⇧4` (la fameuse
  sélection translucide bleu-cyan avec le lasso de capture).
- **Typographie** : Archivo (display, gras, condensé) pour les titres, IBM Plex Sans
  pour le texte courant, IBM Plex Mono pour tout ce qui est raccourcis clavier / noms
  de fichiers / valeurs techniques.
- **Motif récurrent** : des petits **crochets d'angle façon viseur** (coin supérieur
  gauche + droit, comme les repères d'autofocus d'un appareil photo, ou comme les
  poignées du rectangle de sélection de capture macOS) qui encadrent les éléments clés.
- **Signature** : le tagline retenu est *"Shot. Kept."*

## Icône actuelle (placeholder à remplacer)

L'icône de barre de menu utilisée aujourd'hui est un simple SF Symbol générique :
`folder.fill` (un dossier plein, monochrome). C'est un placeholder — il n'a aucune
identité propre à ShotCubby et doit être remplacé par un vrai logo.

## Ce qu'il faut produire

1. **Icône de barre de menu (prioritaire)**
   - Glyphe monochrome, fond transparent, "template image" (macOS l'affiche automatiquement
     en noir ou blanc selon le thème — donc une seule couleur, pas de dégradé, pas de palette)
   - Doit rester lisible à 16–22px (très petit, à côté d'autres icônes système)
   - Doit évoquer "capture + archivage", pas juste un dossier générique. Pistes possibles :
     un cadre/viseur (coins de sélection) entourant une petite forme, un déclencheur
     d'appareil photo combiné à une pointe d'archive, un rectangle de sélection stylisé
   - Surtout **pas de texte** dans l'icône

2. **Icône d'application (.icns, master 1024×1024)**
   - Suit les conventions actuelles des icônes macOS (canevas "squircle" arrondi,
     un peu de profondeur/relief autorisé mais rien de kitsch ou trop chargé)
   - Utilisée dans : le panneau "About", le Finder, le fond du `.dmg` d'installation
   - Doit rester lisible aussi en petit (16/32/128px), pas seulement en grand

3. **(Optionnel) Variante carrée pour le header GitHub / la landing page**
   - Version couleur simplifiée, utilisable comme avatar/mark dans le README et la nav
     du site

## Contraintes

- Fonctionne aussi bien en light mode qu'en dark mode (la barre de menu change de fond)
- Pas de clipart "appareil photo" ou "dossier" trop littéral/générique
- Doit se sentir comme un outil de précision pour power-users, pas comme un gadget ludique
- Références de ton (pour calibrer, pas pour copier) : CleanShot X, Shottr, Dropshare —
  utilitaires macOS de capture d'écran avec des icônes géométriques nettes et minimales
