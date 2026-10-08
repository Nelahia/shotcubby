# ShotKeep — runbook pour finir le premier release signé

> Runbook ponctuel : à supprimer une fois le premier release `v2.0.0` publié et le cask
> Homebrew à jour. Pas un doc permanent du projet.

Contexte : tout le travail de code est prêt (signature, notarisation, .dmg, renommage
VaultyShot → ShotKeep), mais la machine où ce commit a été préparé est derrière un proxy
d'entreprise (Zscaler) qui bloque `git push` (upload) vers GitHub, même si tout le reste
(lecture, API) passe. Ce fichier voyage avec le bundle git pour que la suite se fasse
depuis une autre machine / un autre réseau.

## 1. Repo principal : `shotkeep`

Si tu lis ce fichier depuis un `git fetch` d'un bundle plutôt que directement sur
`main`, tu es déjà sur la bonne branche (`sign-and-notarize-release`). Sinon :

```bash
git clone https://github.com/Nelahia/shotkeep.git
cd shotkeep
git fetch /chemin/vers/shotkeep-sign-and-notarize-release.bundle \
  sign-and-notarize-release:sign-and-notarize-release
git checkout sign-and-notarize-release
```

### Pousser, ouvrir la PR, merger

```bash
git push -u origin sign-and-notarize-release
gh pr create --title "Sign, notarize, and rename to ShotKeep" \
  --body "Signs release builds with a Developer ID Application certificate, notarizes via the App Store Connect API, ships as a .dmg, and renames VaultyShot → ShotKeep." \
  --base main
gh pr merge --squash --delete-branch
git checkout main
git pull
```

### Taguer la release

⚠️ **`v1.0.0` et `v1.0.1` existent déjà** (anciennes releases VaultyShot) — ne pas les
réutiliser. Recommandation : repartir sur **`v2.0.0`** (changement de bundle ID + de nom
= nouvelle identité côté Apple/Homebrew, un bump majeur a du sens). Ajuste si tu préfères
un autre numéro.

```bash
git tag v2.0.0
git push origin v2.0.0
```

Ça déclenche `.github/workflows/release.yml`. Suivre avec :

```bash
gh run watch
```

ou sur l'onglet **Actions** du repo GitHub. Le job doit se terminer sur la création d'une
Release GitHub avec `ShotKeep.dmg` attaché.

### Secrets déjà configurés (rien à refaire)

Les 6 secrets suivants sont déjà sur `Nelahia/shotkeep` (le rename de repo les a
préservés) :

- `APPLE_CERTIFICATE_P12_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_API_KEY_P8_BASE64`

Vérifier avec : `gh secret list --repo Nelahia/shotkeep`

---

## 2. Tap Homebrew : `homebrew-tap`

Une fois la release `v2.0.0` publiée avec succès (fichier `.dmg` visible sur
https://github.com/Nelahia/shotkeep/releases), finaliser le cask. Le commit correspondant
est dans le bundle `homebrew-tap-rename-shotkeep.bundle` (transféré séparément, puisque
c'est un autre repo).

### Récupérer le commit depuis le bundle

```bash
git clone https://github.com/Nelahia/homebrew-tap.git
cd homebrew-tap
git fetch /chemin/vers/homebrew-tap-rename-shotkeep.bundle \
  rename-vaultyshot-to-shotkeep:rename-vaultyshot-to-shotkeep
git checkout rename-vaultyshot-to-shotkeep
```

### Remplir la vraie version + sha256

Le fichier `Casks/shotkeep.rb` contient des placeholders :
```ruby
version "1.0.0"
sha256 "PENDING_FIRST_SIGNED_RELEASE"
```

Remplacer par la vraie version taguée (`2.0.0` si tu suis la reco ci-dessus) et le sha256
donné dans la description de la release GitHub (section "SHA256:") ou en le recalculant :

```bash
curl -L -o ShotKeep.dmg https://github.com/Nelahia/shotkeep/releases/download/v2.0.0/ShotKeep.dmg
shasum -a 256 ShotKeep.dmg
```

Puis éditer `Casks/shotkeep.rb` avec les vraies valeurs, retirer le commentaire `# TODO`
en haut du fichier.

### Vérifier et pousser

```bash
brew audit --cask shotkeep || true   # si le tap est déjà ajouté localement
git add Casks/shotkeep.rb
git commit -m "Set ShotKeep v2.0.0 release URL and sha256"
git push -u origin rename-vaultyshot-to-shotkeep
gh pr create --title "Point shotkeep cask at the first signed release" \
  --body "Fills in the real version and sha256 now that ShotKeep v2.0.0 is published." \
  --base main
gh pr merge --squash --delete-branch
```

### Test final

```bash
brew untap nelahia/tap 2>/dev/null; brew tap nelahia/tap
brew install --cask shotkeep
```

L'app doit s'ouvrir sans aucun avertissement Gatekeeper (signée + notarisée).

---

## 3. Reste en todo (pas bloquant, cosmétique)

- `assets/menubar-overview.png` et `assets/menubar-icon.png` montrent encore l'ancien nom
  "VaultyShot" à l'écran — à reprendre après le premier lancement de ShotKeep et à
  republier dans un commit séparé sur `main`.
- Supprimer ce fichier (`RELEASE_RUNBOOK.md`) une fois tout fait.
