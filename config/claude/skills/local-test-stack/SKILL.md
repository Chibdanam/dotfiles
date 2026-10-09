---
name: local-test-stack
description: Prouver la pile de test locale peren AVANT tout run (ApiTester headless ou UI, Playwright devlocal, curl de fumée), sur ~/dev/peren comme sur un worktree. À charger dès qu'un test va lire la pile locale, avant de lancer quoi que ce soit. Un run sur une pile mal montée est faux (process sur un ancien build ou un autre arbre, collection ou captures d'un autre checkout, base Cosmos disparue, Vite périmé) et coûte 10 à 25 min par passe. Donne le script de preuve, l'ordre stop/start, la commande ApiTester exacte pour l'arbre visé, ciblée sur les scénarios de la story, et son attente fiable.
argument-hint: "[arbre testé, défaut ~/dev/peren] [arbre principal, défaut ~/dev/peren]"
---

# Pile de test locale

Un run ne prouve quelque chose que si chaque exécutable qu'il touche tourne sur le code de l'arbre testé, noté T.

## 1. Prouver, relancer seulement sur KO

```bash
bash ~/.claude/skills/local-test-stack/check.sh post T
```

`post` ne modifie rien et prend quelques secondes. Il vérifie, pour chacune des quatre apps, qu'elle tourne depuis T, qu'aucune DLL n'a été reconstruite et qu'aucune
source de ses projets n'a changé depuis son démarrage. Il vérifie aussi que Cosmos n'a ni redémarré ni planté sous les
apps et que la base Archive existe, que l'ApiTester vise le workspace et la collection de T, que `Results/` est propre
et que Vite est plus récent que le dernier checkout de dematDashboard. Il finit par la commande de run exacte.

Zéro KO : lancer les tests (§2). Sinon, une commande par appel, sans `&&` :

```bash
env -C ~/dev/peren mise r stop core archive demat invoice   # tue les apps de tous les arbres
bash ~/.claude/skills/local-test-stack/check.sh pre T     # copie les fichiers ignorés sans rien écraser, crée la base Cosmos si absente
env -C T mise r start core archive demat invoice            # build séquentiel puis start --no-build, 4 à 7 min
bash ~/.claude/skills/local-test-stack/check.sh post T
```

Lancer `mise r start` en arrière-plan. Il saute une app « already running » quel que soit l'arbre d'où elle tourne,
d'où le stop d'abord. Une pile mixte voulue (Archive d'un worktree de release pour reproduire un bug, `pile.sh` de
dematDashboard) est permise si elle est annoncée : `post` liste alors en KO les apps de l'autre arbre, c'est attendu.

## 2. Lancer

**ApiTester** : la ligne `RUN` de `post`, c'est-à-dire `apitester-run.sh`, un appel Bash par commande :

```bash
bash ~/.claude/skills/local-test-stack/apitester-run.sh start T --test-set Demat --folder '<[SCENARIO] 1>' --folder '<[SCENARIO] 2>'
bash ~/.claude/skills/local-test-stack/apitester-run.sh wait <dossier affiché par start>   # appel Bash avec timeout 600000
```

- Ciblage : un `--folder` par `[SCENARIO]` de la story, avec le nom exact du dossier (virgules, apostrophes et accents
  compris). Un seul run, un seul rapport. Les setups du chemin de chaque scénario et l'authentification de ses rôles
  suivent seuls. Un dossier produit entier (`--folder Invoice` : 1 280 requêtes, 11 min) seulement si la story le
  demande. Un nom sans scénario fait refuser tout le run (`exit=3`, nom cité dans la sortie).
- Attente : `start` détache le run (`setsid`) et rend la main. `wait` bloque au plus 540 s et regarde toutes les 5 s :
  - `DONE exit=<code> end=<heure> trx=<heure>` suivi du décompte des `outcome` : le run est fini ;
  - `STILL_RUNNING` : relancer `wait` tout de suite, dans le même tour ;
  - `DIED` : le run est mort sans code, lire `run.log`.
  Jamais `pgrep -f` ni boucle `sleep` pour attendre : un motif trouve aussi le shell qui le porte, et l'attente tourne
  jusqu'à son timeout. Ne jamais finir un tour sans `DONE`, car le run détaché survit au tour. Pour abandonner :
  `kill -- -$(cat <dossier>/pid)` (le PID est le groupe du run).
- Sur un worktree, `start` ajoute lui-même `--workspace`, `--postman-path` et `--environment` vers T, sans quoi
  `mise.local.toml` ramène le workspace sur `~/dev/peren`. Il ajoute toujours `--report-dir` vers son dossier.
- Branche d'ApiTester pas encore mergée : préfixer `APITESTER_DIR=<checkout de cette branche>`.
- Fenêtre ApiTester ouverte (`mise run status`) : préfixer `APITESTER_UI_PORT=5311 APITESTER_CALLBACK_PORT=7311`
  plutôt que `mise run stop`, qui tuerait celle de l'utilisateur.
- Preuve depuis l'interface sur un worktree : `mise exec -- dotnet run --project src/ApiTester -- -workspace
  T/Demat/Demat/PrinterTesterApp/ApiTester` ouvre la fenêtre sur T. Y choisir la collection et l'environnement de T
  (réglages, source de collection), puis remettre ceux de `~/dev/peren` à la fin : le choix est enregistré.
- Run Demat complet, environ 25 min : le même `start` sans `--folder`, puis `wait` relancé jusqu'à `DONE`.
- Après : `rtk proxy git -C T status --short -- Demat/Demat/PrinterTesterApp/ApiTester/Results` est le diff du run.
  Sur un worktree, le même sur `~/dev/peren` doit être vide. Rapports dans le dossier affiché par `start`
  (`~/.local/state/apitester/runs/<horodatage>/`) : `postman-report.trx`, `postman-report-diffs.json`, `run.log`.
  `rtk proxy` parce que RTK tronque la sortie git.

**Playwright devlocal** (dematDashboard) : Vite sert `~/dev/dematDashboard` sur 4300 et 4302, le relancer après tout
changement de branche. Preuve du code servi : `curl -s http://localhost:4302/retailer/@fs/<chemin absolu> | grep <symbole>`.
Le premier chargement dépasse parfois 30 s : `curl -s -o /dev/null --max-time 240
http://localhost:4302/retailer/` d'abord. Puis
`env -C ~/dev/dematDashboard/TestsPlayWright TEST_ENV=devlocal mise exec -- npx playwright test src/specs/<dossier> --reporter=line`.

## 3. Lire le résultat avant d'accuser le code

- Rouges connus du dossier Demat : « Lignes exclues d'un tiers » (documenté dans sa définition) et « Reçu exclu de la
  facturation » (station Tokheim non mappée, correctif `PR/#NOWI-TokheimUnmappedStation` non mergé). Pour jouer avec
  des correctifs non mergés : dans `~/dev/wt-peren-topain-qa`, en HEAD détaché, un `merge --no-ff` par correctif
  (skill `gitflow`, §9). Jamais un worktree de plus.
- Un `Inconclusive` à la première passe d'un scénario neuf vient de ses captures « Added » : la deuxième passe tranche.
- Une différence avec `Results/` n'est jamais du bruit. Chaque fichier que le run modifie ou ajoute s'analyse : le
  champ qui change, sa cause (code de la branche, scénario, pile locale, date du run), légitime ou défaut. Le bilan
  les présente tous à l'utilisateur, qui seul décide de restaurer, de committer ou de corriger.
- `Scenari/Demat/Third Party` exige l'acteur `CRPartner`, sans jeton : en headless, il bloque sur une WebView. Pour un
  run Demat complet, jouer une copie de la collection sans ce dossier (`--postman-path <copie>`).
- Base Archive absente ou recréée : les reçus locaux sont perdus, le dire, puis relancer les quatre apps. Cosmos qui
  ne répond pas : `env -C ~/dev/peren mise r cosmos:restart` (tâche de son `mise.local.toml`).
- `mise r stop` et `pkill -f` tuent le shell de Claude si sa ligne contient `run --project <App>` : une commande par appel.

## 4. Après

Dire dans le bilan quelle pile a tourné (arbre, heure de démarrage des apps) et si Cosmos a été recréé. Remettre les
apps de `~/dev/peren` si l'utilisateur en a besoin.
