# peren

`~/dev/peren`, origin `git@ssh.dev.azure.com:v3/conferosas/peren/peren`. Le gitflow y est une
discipline personnelle : les collègues committent et mergent à leur façon sur les branches
d'intégration, on ne corrige pas leur historique.

## Branches

- Intégration : `Integration/<NN>-<Sujet>` (aujourd'hui `Integration/06-IntegratedInvoice`). Une
  branche de ticket part de sa tête et y revient par PR.
- Le WI d'un chantier peut servir de base à d'autres tickets (`PR/#3264-InvoiceBuilder`) : on part
  alors de sa tête, et sa PR passe avant celles qui en dépendent.

## Hooks

Le hook suivi `.githooks/prepare-commit-msg` appartient à l'équipe (shebang `#!/bin/sh` mais
tableaux bash : il casse sous dash, le `/bin/sh` de WSL). On ne le modifie pas. `gf hooks` installe
ceux du skill dans `.git/hooks`, partagés par tous les worktrees ; l'ancienne copie locale reste en
`prepare-commit-msg.pre-gf`.

Vocabulaire refusé par `commit-msg` (et par `gf start/split/rename` dans les noms) :

```bash
git -C ~/dev/peren config --add gf.forbidden '\b[Ll]ots? ?[0-9]+'
git -C ~/dev/peren config --add gf.forbidden '\b(BACK|FRONT|E2E)-[0-9]+\b'
git -C ~/dev/peren config --add gf.forbidden '\bDC-[0-9]+\b'
```

Interdits aussi, sans motif possible : le mot « lot » pour un découpage de travail, tout identifiant
du vault Obsidian. Les codes métier (`BT-xx`, `BG-xx`, `BR-FR-xx`) sont permis.

## PR

- Titre et description **en français**, pour l'équipe : `#<id> <Sujet en français>`, description qui
  dit ce que la PR apporte et comment la relire.
- Complétion : **Merge (no fast-forward)**, case « Customize merge commit message » cochée, message
  remplacé par la sortie de `gf pr-message` (en anglais).
- Une PR se cite avec sa source et sa cible : « PR 1728 (`PR/#3475-…` → `Integration/06-…`) ».

## Worktrees

Les deux arbres de l'équipe Topain (`~/dev/wt-peren-topain-dev`, `~/dev/wt-peren-topain-qa`) sont le
flux de la squad Multica Topain, décrit dans ses instructions, section « Working trees ». Hors de ce
flux, on n'y touche pas sans que l'utilisateur les nomme, et « crée un worktree » veut dire un nouvel
arbre `~/dev/wt-peren-<sujet>`.
