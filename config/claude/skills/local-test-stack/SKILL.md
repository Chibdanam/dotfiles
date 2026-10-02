---
name: local-test-stack
description: Prouver la pile de test locale peren AVANT tout run (ApiTester headless ou UI, Playwright devlocal, curl de fumée), sur ~/dev/peren comme sur un worktree. À charger dès qu'un test va lire la pile locale, avant de lancer quoi que ce soit. Un run sur une pile mal montée est faux (process sur un ancien build ou un autre arbre, collection ou captures d'un autre checkout, base Cosmos disparue, Vite périmé) et coûte 10 à 25 min par passe. Donne le script de preuve, l'ordre stop/start et la commande ApiTester exacte pour l'arbre visé.
argument-hint: "[arbre testé, défaut ~/dev/peren] [arbre principal, défaut ~/dev/peren]"
---

# Pile de test locale

Un run ne prouve quelque chose que si chaque exécutable qu'il touche tourne sur le code de l'arbre testé, noté T.
En septembre, les runs faux venaient autant de `~/dev/peren` que des worktrees.

## 1. Prouver, relancer seulement sur KO

```bash
bash ~/.claude/skills/local-test-stack/check.sh post T
```

`post` vérifie, pour chacune des quatre apps, qu'elle tourne depuis T, qu'aucune DLL n'a été reconstruite et qu'aucune
source de ses projets n'a changé depuis son démarrage. Il vérifie aussi que Cosmos n'a ni redémarré ni planté sous les
apps et que la base Archive existe, que l'ApiTester vise le workspace et la collection de T, que `Results/` est propre
et que Vite est plus récent que le dernier checkout de dematDashboard. Il finit par la commande de run exacte.

Zéro KO : lancer les tests (§2). Sinon, une commande par appel, sans `&&` :

```bash
env -C ~/dev/peren mise r stop core archive demat invoice   # tue les apps de tous les arbres
bash ~/.claude/skills/local-test-stack/check.sh pre T     # worktree : copie les fichiers ignorés sans rien écraser
env -C T mise r start core archive demat invoice            # build séquentiel puis start --no-build, 4 à 7 min
bash ~/.claude/skills/local-test-stack/check.sh post T
```

Lancer `mise r start` en arrière-plan. Il saute une app « already running » quel que soit l'arbre d'où elle tourne,
d'où le stop d'abord. Une pile mixte voulue (Archive d'un worktree de release pour reproduire un bug, `pile.sh` de
dematDashboard) est permise si elle est annoncée : `post` liste alors en KO les apps de l'autre arbre, c'est attendu.

## 2. Lancer

**ApiTester**, depuis `~/dev/zz-api-tester` : la ligne `RUN` de `post`.

- Sur `~/dev/peren` : `mise run headless --test-set Demat --folder <dossier>`.
- Sur un worktree : jamais `mise run headless` sans `--workspace`. `mise.local.toml` fixe `APITESTER_HOME` sur
  `~/dev/peren` et mise l'impose au shell. La collection et l'environnement ne suivent pas le workspace : il faut les
  trois chemins, que la ligne `RUN` donne. Tant que `feature/headless-workspace` n'est pas mergée, elle passe par
  `mise exec -- dotnet run … -workspace`, et `mise exec` est nécessaire : hors mise, `postman` est la 1.65 au lieu de la
  1.56 épinglée.
- Fenêtre ApiTester ouverte (`mise run status`) : préfixer `APITESTER_UI_PORT=5311 APITESTER_CALLBACK_PORT=7311`
  plutôt que `mise run stop`, qui tuerait celle de l'utilisateur.
- Run Demat complet, environ 25 min : en arrière-plan.
- Après : `rtk proxy git -C T status --short -- Demat/Demat/PrinterTesterApp/ApiTester/Results` est le diff du run.
  Sur un worktree, le même sur `~/dev/peren` doit être vide. Rapports dans `~/.local/state/apitester/runs/<horodatage>/`,
  `postman-report.trx` (`grep -o 'outcome="[A-Za-z]*"' | sort | uniq -c`) et `postman-report-diffs.json`.
  `rtk proxy` parce que RTK tronque la sortie git.

**Playwright devlocal** (dematDashboard) : Vite sert `~/dev/dematDashboard` sur 4300 et 4302, le relancer après tout
changement de branche. Preuve du code servi : `curl -s http://localhost:4302/retailer/@fs/<chemin absolu> | grep <symbole>`,
sans `/retailer` sur 4300. Le premier chargement dépasse parfois 30 s : `curl -s -o /dev/null --max-time 240
http://localhost:4302/retailer/` d'abord. Puis
`env -C ~/dev/dematDashboard/TestsPlayWright TEST_ENV=devlocal mise exec -- npx playwright test src/specs/<dossier> --reporter=line`.

## 3. Lire le résultat avant d'accuser le code

- Rouges connus du dossier Demat : « Lignes exclues d'un tiers » (documenté dans sa définition) et « Reçu exclu de la
  facturation » (station Tokheim non mappée, correctif `PR/#NOWI-TokheimUnmappedStation` non mergé). Pour jouer avec
  des correctifs non mergés : worktree jetable `tmp/pile-<sujet>` et un `merge --no-ff` par correctif.
- Un `Inconclusive` à la première passe d'un scénario neuf vient de ses captures « Added » : la deuxième passe tranche.
- Bruit connu des captures, à restaurer par `git checkout -- ':(literal)<chemin>'` et jamais à committer :
  `[SETUP]CreateUsers` (noms propres à la machine), `continuationToken: null` des listes, `companyLogo` de
  `GetGiftByCompanyid`, `CompanySummary`, `GetReceiptContent` de Loyalty.
- `Scenari/Demat/Third Party` exige l'acteur `CRPartner`, sans jeton : en headless, il bloque sur une WebView. Pour un
  run Demat complet, jouer une copie de la collection sans ce dossier (`--postman-path <copie>`).
- Base Archive recréée : les reçus locaux sont perdus, le dire, puis relancer les quatre apps. `cosmos-init` en échec :
  `env -C ~/dev/peren mise r cosmos:restart` (tâche de son `mise.local.toml`).
- `mise r stop` et `pkill -f` tuent le shell de Claude si sa ligne contient `run --project <App>` : une commande par appel.

## 4. Après

Dire dans le bilan quelle pile a tourné (arbre, heure de démarrage des apps) et si Cosmos a été recréé. Remettre les
apps de `~/dev/peren` si l'utilisateur en a besoin.
