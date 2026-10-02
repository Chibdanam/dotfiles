---
name: worktree-test-stack
description: Monter et PROUVER une pile de test locale depuis un worktree peren avant tout run (ApiTester headless, Playwright devlocal, curl). À charger dès qu'un test doit tourner sur un arbre autre que ~/dev/peren, AVANT de lancer quoi que ce soit — un run sur une pile mal montée est faux (ancien build, jetons absents, base Cosmos disparue) et coûte 10 min par passe. Donne la liste des fichiers ignorés à copier, l'ordre stop/start, les quatre preuves à lire, et la commande ApiTester pointée sur le worktree.
argument-hint: "<chemin du worktree> [chemin de l'arbre principal, défaut ~/dev/peren]"
---

# Pile de test sur un worktree

Un worktree n'a que les fichiers TRACKÉS. Tout ce qui fait tourner la pile en local est ignoré par git
et vit dans `~/dev/peren` seulement. Un run lancé sans ces fichiers, ou avec les apps de l'arbre
principal encore vivantes, teste autre chose que la branche : deux runs faux le 28 Sep 2026 (#3508).

## 1. Copier les fichiers ignorés (jamais commités, jamais poussés)

Depuis l'arbre principal `M` vers le worktree `W` :

| Fichier | Rôle | Sans lui |
|---|---|---|
| `mise.toml` | tâches `start`/`stop`/`cosmos:init` | `mise r start` inconnu |
| `CoreWebApi/appsettings.shared.Local.json` | conn strings, Cosmos gateway, secret B2C, KeyVault off | env Production, KeyVault, crash |
| `certs/` (pem, key, pfx) | cert Kestrel + trust Core↔Archive | HTTPS refusé |
| `compose.wsl.yml` | infra Docker (si absent du tracké) | `mise r status` muet |
| `Demat/Demat/PrinterTesterApp/ApiTester/Config/collection.environment.json` | **jetons des acteurs** (Retailer, User1, User2) | 100 % des requêtes en 401, tout rouge |
| `…/ApiTester/Config/collection.settings.json`, `collection.global.json`, `collection.local.json` | réglages locaux de l'ApiTester | source de collection nulle |

`bash ~/.claude/skills/worktree-test-stack/check.sh W [M]` fait la copie manquante en le disant, puis les preuves du §3.

## 2. Arrêter l'ancien, démarrer le nouveau

```bash
cd M; mise r stop core archive demat invoice      # les apps de l'arbre principal tiennent les ports
cd W; mise r start core archive demat invoice     # build séquentiel PUIS start --no-build, logs ~/logs/<App>/latest.log
```

Les quatre ensemble, toujours : une pile mi-ancienne mi-neuve donne des échecs incompréhensibles.

## 3. Prouver avant de lancer (les quatre preuves)

1. **Chemin des process** : `pgrep -af 'bin/Debug/net8.0/(CoreWebApi|ArchiveWebApi|DematProcessor|InvoiceGenerationWebJobs)$'` → tous sous `W`.
2. **Fraîcheur des binaires** : `stat -c %Y W/<App>/bin/Debug/net8.0/<App>.dll` ≥ `git -C W log -1 --format=%ct`, et heure de démarrage des process (`ps -o lstart=`) postérieure au build.
3. **Content root** : `grep "Content root path" ~/logs/CoreWebApi/latest.log ~/logs/ArchiveWebApi/latest.log` → `W/…`, et `Now listening on` présent.
4. **Cosmos** : `docker inspect peren-cosmos --format '{{.State.Status}} restarts={{.RestartCount}} started={{.State.StartedAt}}'`. Un `StartedAt` postérieur au dernier `cosmos:init` = base Archive PERDUE (l'émulateur classique ne persiste pas) → `cd W; mise r cosmos:init` puis `mise r stop archive demat invoice` + `start` (les clients Cosmos ne survivent pas à la recréation). Prévenir l'utilisateur : ses reçus locaux sont perdus.

Un curl de fumée sur la route touchée par la branche (attendu ≠ comportement de l'ancien build) clôt la preuve.

## 4. Lancer les tests SUR le worktree

- **ApiTester** (depuis `~/dev/zz-api-tester`, après `mise run stop`) — le workspace vient de `APITESTER_HOME`, pas de `--postman-path` ; sans lui les captures et le diff vont dans l'arbre principal (fichiers renumérotés « ajoutés », scénarios « Inconclusive ») :

  ```bash
  APITESTER_HOME=W/Demat/Demat/PrinterTesterApp/ApiTester \
    dotnet run --project src/ApiTester -- -headless -postmanRunMode converted -testSet Demat -folder <Dossier>
  ```
  **Jamais `mise run headless` pour un worktree** : le `[env]` de `zz-api-tester/mise.local.toml` fixe `APITESTER_HOME` sur `~/dev/peren` et écrase celui du shell dans toute tâche mise ; le run joue alors l'environnement, les globales et le `--working-dir` de l'arbre principal et y écrit ses captures (2 Oct 2026, PR 1757). Fenêtre ApiTester ouverte : préfixer `APITESTER_UI_PORT=5311 APITESTER_CALLBACK_PORT=7311` plutôt que la fermer, les `save-result` suivent le port de rappel.
  Vérifier d'abord : `… -- --print-paths` → `root=`, `results=`, `gitRoot=` sous `W` ; après le run, la ligne `postman collection run … -e … --working-dir …` du log cite `W`, et `git -C M status --short Demat` est vide. Rapports : `~/.local/state/apitester/runs/<horodatage>/postman-report.trx` (`grep -o 'outcome="[A-Za-z]*"' | sort | uniq -c`). Après le run, `git -C W status --short Demat` = le diff des captures ; les rouges connus du dossier Invoice : « Lignes exclues d'un tiers » (documenté), « Reçu exclu de la facturation » (station Tokheim non mappée).
- **Playwright devlocal** (dematDashboard) : les serveurs Vite de `~/dev/dematDashboard` sur 4300/4302 servent la branche COURANTE de ce dossier (HMR) ; un second `serve-devlocal` part sur 4304/4305 et Playwright ne le voit pas. `curl -s http://localhost:4300/src/<fichier modifié> | grep <symbole retiré>` prouve ce qui est servi. Puis `cd TestsPlayWright; TEST_ENV=devlocal npx playwright test src/specs/<dossier> --reporter=line`.

## 5. Après

Remettre ce qui a été détourné : settings de l'ApiTester (`~/.config/apitester/settings.json`) si modifiés, apps de l'arbre principal si l'utilisateur en a besoin, et dire dans le bilan quelle pile a tourné (chemin + heure de build) et si Cosmos a été recréé.
