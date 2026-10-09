---
name: gitflow
description: Procédé git des dépôts peren (ADO) : un work item → une racine PR/#<id>-Sujet → des sous-branches qui prolongent le nom du parent (PR/#<id>-Sujet-Detail, récursif) → merge --no-ff dans le parent seul, après rebase sur sa tête courante (jamais de départ croisé), avec un corps de 3 à 5 lignes. Deux worktrees permanents par équipe, wt-peren-topain-dev et wt-peren-topain-qa, où l'on change de branche d'un work item à l'autre, spikes compris. Tout ce que git porte s'écrit en anglais. À charger au début de tout travail git — créer une branche ou un worktree, découper, merger, renommer, reformuler un merge — avant la première commande. Référence seule : décrit, ne pilote rien.
argument-hint: "[start | split | merge | reword | rename] <contexte>"
---

# Gitflow peren

Le work item Azure DevOps est le seul pointeur durable partagé par l'équipe. Tout le procédé
découle de là : le numéro nomme la branche, la branche nomme les commits (hook
`prepare-commit-msg` : `[<nom après le dernier slash>] `), et la lignée des noms garde la
vision initiale lisible dans `git log`.

## 1. Un travail commence par un work item

- Chercher ou faire créer le WI **avant** la première branche destinée à origin.
- Le WI vit seul : besoin, périmètre, critères d'acceptation, hors-périmètre, en termes
  produit. Zéro chemin de fichier, zéro identifiant de suivi local, zéro outillage hors sujet.
- Description écrite **en entier** dans la réponse, corrigée avec l'utilisateur, puis
  `az boards work-item create`. Toute commande `az` d'écriture passe par AskUserQuestion.
- Un défaut trouvé en route reçoit **son propre Bug**. Ses commits portent le numéro du Bug,
  sa branche est une racine `PR/#<bug>-Sujet`, jamais une sous-branche du ticket qui l'a révélé.

## 2. La racine du work item

`PR/#<id>-Sujet`

- Préfixe `PR/` obligatoire. Sujet en PascalCase court qui décrit **le contenu**.
- Interdits dans les noms et les messages : « lot », `BACK-xx`, `FRONT-xx`, `DC-x`, `E2E-xx`,
  tout identifiant du vault Obsidian. Les codes métier (`BT-xx`, `BG-xx`, `BR-FR-xx`) sont permis.
- Plusieurs racines par WI sont possibles quand le WI couvre des préoccupations distinctes,
  mais la règle par défaut est une racine et des sous-branches.

## 3. Une subdivision prolonge le nom de son parent

`PR/#<id>-Sujet-Detail`, puis `PR/#<id>-Sujet-Detail-SousDetail`, sans limite de profondeur.

- On **hérite du nom complet du parent** et on ajoute un segment. On ne décline jamais le nom
  (`PR/#3377-InvoiceDateScenarios` est faux ; `PR/#3377-InvoiceIssueDate-Scenarios` est juste).
- Le segment ajouté ne répète pas ce que le parent dit déjà : sous
  `PR/#3374-InvoicePostmanScenari`, la sous-branche des tickets est `-TicketScenarios`,
  pas `-InvoiceTicketScenarios`.
- Le hook tague alors chaque commit avec la lignée entière :
  `[#3374-InvoicePostmanScenari-TicketScenarios] postman: …`.

## 4. Une branche se merge dans son parent, jamais plus haut

1. Rebaser la branche sur la **tête courante du parent** (jamais l'inverse).
2. `git merge --no-ff <branche>` depuis le parent.
3. Le commit de merge garde le sujet par défaut (`[tag] Merge branch 'x' into y`) et porte un
   **corps de 3 à 5 lignes** : ce que la branche fait et pourquoi, pas les détails.
4. La racine ne part dans le chantier ou la branche d'intégration qu'une fois ses
   sous-branches absorbées. Aucun raccourci sous-branche → chantier.

`git log --first-parent` du parent doit rester une liste de merges sans départ croisé.

**Le rebase de l'étape 1 n'est pas facultatif et il se refait chaque fois que le parent bouge.**
Deux branches coupées du même point puis mergées l'une après l'autre donnent un départ croisé :
la seconde doit être rebasée sur le merge de la première avant d'être mergée à son tour. Tant
que la branche n'est **pas encore poussée**, ce rebase ne coûte rien et se fait sans rien
demander — c'est exactement pourquoi il a lieu maintenant plutôt qu'après un push, où il
exigerait un `push --force` (§8).

Quand la branche à rebaser part d'un commit qui a lui-même été réécrit, `git rebase <parent>
<branche>` rejouerait aussi les commits de l'ancien parent, avec les conflits qui vont avec :
viser la base explicitement.

```bash
git rebase --onto <tête du parent> <ancienne base de la branche> <branche>
```

Après une réécriture, `git diff <ancienne tête> <nouvelle tête>` doit être vide : seuls les
identifiants changent.

Un merge sans corps est **reformulé** (même arbre, mêmes parents, mêmes dates), jamais squashé.

## 5. Tout ce que git porte s'écrit en anglais

Noms de branches, sujets et corps de commit, corps de merge, noms de tags. La documentation du
dépôt peut être en français ; l'historique, non — il se lit à côté du code, et le code est en
anglais. Une conversation menée en français ne change pas la langue du commit qu'elle produit.

## 6. Granularité des commits

- Un objectif non encore atteint vit dans **un seul commit** (amend / squash) jusqu'à ce que ça
  marche ; ensuite un commit par préoccupation, message en prose qui dit ce que le changement
  fait et ce dont il dépend.
- Compléter le travail d'un collègue : sa philosophie, une branche, un commit.

## 7. `#NOWI` : exception locale

`PR/#NOWI_Sujet` sert à gérer finement du travail local sans ticket. Il ne touche jamais
origin sans AskUserQuestion : créer un WI et recréer la branche sous `PR/#<id>-…`,
rattacher à un WI existant (comme sous-branche, donc renommée et retaguée), ou exception assumée.

## 8. Moments de contrôle humain (AskUserQuestion)

- Avant tout `az boards work-item create/update/relation add`.
- Avant qu'une branche `#NOWI` touche origin.
- Avant tout `push --force*` (réécriture d'une branche déjà poussée).
- Quand la subdivision dépasse ce qui avait été annoncé (nouvelle profondeur, nouvelle racine).

## 9. Deux worktrees permanents par équipe, pas un de plus

Chaque nouvel arbre recompile tout (4 à 8 min). Une équipe a donc deux worktrees peren, toujours les mêmes d'un
work item à l'autre, en plus de `~/dev/peren`. Pour l'équipe Topain :

- `~/dev/wt-peren-topain-dev` : on y code, on y change de work item et de sous-branche, on y rebase et on y merge (dev).
- `~/dev/wt-peren-topain-qa` : on y vérifie le commit livré et on y écrit les scénarios de test (QA).

- **Aucun autre arbre de travail**, quel que soit le work item : ni `git worktree add`, ni `git clone`, ni
  `multica repo checkout`, ni copie (`cp -r`). Un clone ou un checkout Multica recompile autant qu'un worktree.
  `~/dev/peren` ne compte pas.
- **Un nouveau work item ou une autre sous-branche se prend par `git switch`** dans le worktree de son rôle, après
  avoir committé le travail en cours (§6). Le rebase et le merge `--no-ff` dans le parent (§4) se font dans `-dev`.
- **`-qa` est en HEAD détaché** sur le commit livré. Git refuse la même branche dans deux arbres, et la branche du
  dev vit dans `-dev`. La QA écrit ses scénarios sur sa propre sous-branche dans `-qa`. Pour vérifier, elle se
  détache sur le commit livré et y merge sa branche : ce merge est jetable, aucune branche ne bouge.
- **Un spike se fait dans l'un des deux**, jamais dans un troisième, y compris pour le lead dev. Il prend une branche
  `tmp/<WI>-spike-<sujet>`, puis l'arbre revient à son état d'avant et la branche est supprimée. Il va dans l'arbre
  qui ne sert pas à ce moment-là. Si les deux servent, le spike attend : on ne change jamais de branche sous un
  collègue qui travaille dans l'arbre.
- Les deux worktrees ne sont jamais supprimés en fin de work item.

```bash
# Une seule fois, s'ils n'existent pas encore
git -C ~/dev/peren worktree add ~/dev/wt-peren-topain-dev <branche>
git -C ~/dev/peren worktree add --detach ~/dev/wt-peren-topain-qa <commit>

# Dev : racine d'un nouveau work item, découpe, passage d'une sous-branche à l'autre
git -C ~/dev/wt-peren-topain-dev switch -c 'PR/#3541-Sujet' 'PR/#3264-InvoiceBuilder'
git -C ~/dev/wt-peren-topain-dev switch -c 'PR/#3541-Sujet-Detail' 'PR/#3541-Sujet'
git -C ~/dev/wt-peren-topain-dev switch 'PR/#3541-Sujet-Autre'

# QA : ses scénarios sur sa branche, puis la vérification en détaché
git -C ~/dev/wt-peren-topain-qa switch -c 'PR/#3541-Sujet-TestScenarios' <commit livré>
git -C ~/dev/wt-peren-topain-qa switch --detach <commit livré>
git -C ~/dev/wt-peren-topain-qa merge --no-ff --no-edit 'PR/#3541-Sujet-TestScenarios'

# Spike dans l'arbre libre, puis retour et suppression
git -C ~/dev/wt-peren-topain-qa switch -c 'tmp/3541-spike-<sujet>' <commit de départ>
git -C ~/dev/wt-peren-topain-qa switch --detach <commit d'avant>
git -C ~/dev/wt-peren-topain-qa branch -D 'tmp/3541-spike-<sujet>'

# Contrôle : tout arbre peren sous ~/dev, worktrees du cache Multica compris (clones, checkouts, copies).
# Un dépôt est peren s'il contient le commit racine de peren, quelle que soit son origine (Azure, chemin local,
# cache Multica) ; un clone superficiel, qui n'a pas ce commit, est reconnu à son URL.
# Sortie attendue : ~/dev/peren et les deux worktrees de l'équipe, rien d'autre. Les worktrees PR-edit de
# DevLens (~/dev/DevLens/data) appartiennent à l'application DevLens, pas à l'équipe.
{ for g in ~/dev/peren ~/dev/wt-multica/.repos/*/*+peren+peren.git; do git -C "$g" worktree list --porcelain 2>/dev/null; done | sed -n 's/^worktree //p'
  find ~/dev -maxdepth 6 \( -path "$HOME/dev/DevLens/data" -o -name node_modules -o -name bin -o -name obj \) -prune -o -name .git -prune -printf '%h\n' 2>/dev/null |
    while read -r d; do
      if git -C "$d" cat-file -e 4a3cf88c3c534d459a3488a2abe9f9b85bb8298f 2>/dev/null; then echo "$d"
      else case $(git -C "$d" remote get-url origin 2>/dev/null) in */peren/peren | */_git/peren) echo "$d" ;; esac; fi
    done
} | grep -v '\.git$' | sort -u | sed "s|^$HOME|~|"
```

## Recettes

Créer une racine depuis la tête du chantier :

```bash
git switch -c 'PR/#3377-InvoiceIssueDate' 'PR/#3264-InvoiceBuilder'
```

Découper :

```bash
git switch -c 'PR/#3377-InvoiceIssueDate-Scenarios' 'PR/#3377-InvoiceIssueDate'
```

Merger une sous-branche dans son parent :

```bash
git rebase 'PR/#3377-InvoiceIssueDate' 'PR/#3377-InvoiceIssueDate-Scenarios'
git switch 'PR/#3377-InvoiceIssueDate'
git merge --no-ff 'PR/#3377-InvoiceIssueDate-Scenarios' -F merge-msg.txt
```

Reformuler un merge en tête de branche sans changer arbre, parents ni dates :

```bash
M=$(git rev-parse HEAD)
GIT_AUTHOR_DATE="$(git show -s --format=%aI $M)" GIT_COMMITTER_DATE="$(git show -s --format=%cI $M)" \
  git commit-tree "$M^{tree}" -p "$M^1" -p "$M^2" -F merge-msg.txt
git update-ref refs/heads/<branche> <nouveau-hash> "$M"
```

Renommer une sous-branche non poussée et retaguer ses commits (dates conservées) :

```bash
git branch -m 'PR/#3377-InvoiceDateScenarios' 'PR/#3377-InvoiceIssueDate-Scenarios'
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --msg-filter \
  "sed -E 's/^\[#3377-InvoiceDateScenarios\]/[#3377-InvoiceIssueDate-Scenarios]/'" \
  'PR/#3377-InvoiceIssueDate..PR/#3377-InvoiceIssueDate-Scenarios'
```

Le hook crie « fatal: ref HEAD is not a symbolic ref » pendant un rebase ou un filter-branch :
sans effet. Les branches empilées sur une branche réécrite sont ensuite rebasées avec
`git rebase --onto <nouvelle tête> <ancienne tête> <branche empilée>`.
