---
name: gitflow
description: Procédé git des dépôts suivis par work items ADO : un work item → une branche PR/#<id>-Sujet linéaire, seule à partir sur origin → des feuilles locales PR/#<id>-Sujet-Detail, squashées en un commit avec corps et passées en fast-forward par `gf land` → entrée dans l'intégration par la PR, en merge no-ff au message réécrit en anglais. Script `gf` (start, split, land, rename, pr-message, check, hooks) et hooks git qui font respecter les règles. Tout ce que git porte s'écrit en anglais. À charger au début de tout travail git — créer une branche, découper, intégrer une feuille, renommer, préparer une PR — avant la première commande.
argument-hint: "[start | split | land | rename | pr-message | check | hooks] <contexte>"
---

# Gitflow

Le work item est le seul pointeur durable partagé par l'équipe. Il nomme la branche du ticket, la
branche nomme les commits (hook `prepare-commit-msg` : `[<nom après le dernier slash>] `), et chaque
commit de cette branche dit ce qu'il apporte et pourquoi : son historique se relit comme un sommaire.

Les opérations passent par le script du skill, qui fait les rebase, les squash et les contrôles :

```bash
GF=~/.claude/skills/gitflow/scripts/gf
$GF help
```

Avant de travailler dans un dépôt, lire sa référence si elle existe : `references/<dépôt>.md`
(vocabulaire interdit, langue des PR, branches d'intégration).

## 1. Un travail commence par un work item

- Chercher ou faire créer le WI **avant** la première branche destinée à origin.
- Le WI vit seul : besoin, périmètre, critères d'acceptation, hors-périmètre, en termes produit.
  Zéro chemin de fichier, zéro identifiant de suivi local.
- Description écrite **en entier** dans la réponse, corrigée avec l'utilisateur, puis
  `az boards work-item create`.
- Un défaut trouvé en route reçoit **son propre Bug** et sa propre branche `PR/#<bug>-Sujet`, jamais
  une feuille du ticket qui l'a révélé.

## 2. La branche du ticket

`PR/#<id>-Sujet`, créée par `$GF start <id> <Sujet> <base>` (sans upstream, pour qu'un push ne
parte pas vers la base).

- Sujet en PascalCase court, sans tiret, qui décrit **le contenu**.
- Une branche par WI ; plusieurs seulement si le WI couvre des préoccupations distinctes.
- **Linéaire** : aucun commit de merge à l'intérieur.
- **Chaque commit a un corps** : ce que fait le changement, pourquoi, et de quoi il dépend. Le hook
  `commit-msg` refuse un commit sans corps sur cette branche.
- Un objectif non encore atteint vit dans **un seul commit** jusqu'à ce que ça marche ; ensuite un
  commit par préoccupation.

## 3. Les feuilles locales

Une préoccupation se travaille sur une feuille qui **prolonge le nom complet** de la branche du
ticket : `$GF split <Detail>` crée `PR/#<id>-Sujet-Detail` et s'y place.

- Le segment ajouté ne répète pas ce que le parent dit déjà (`-TicketScenarios` sous
  `PR/#3374-InvoicePostmanScenari`, pas `-InvoiceTicketScenarios`).
- Une feuille **n'est jamais poussée**. Ses commits sont libres : essais, `wip`, sans corps.
- Une feuille se termine par :

  ```bash
  $GF land -F msg.txt          # depuis la feuille, ou : $GF land -F msg.txt <feuille>
  ```

  `gf land` rebase la feuille sur la tête de son parent (le nom moins le dernier segment), crée
  **un seul commit** avec le message de `msg.txt` (sujet, ligne vide, corps ; le tag du parent est
  posé à la place de celui de la feuille), avance le parent en fast-forward, vérifie que l'arbre est
  celui de la feuille rebasée, puis supprime la feuille. Message refusé ou conflit : rien n'a bougé
  côté parent.
- Conflit pendant le rebase : le résoudre, `git rebase --continue`, relancer `gf land`. `rerere`
  rejoue ensuite les résolutions déjà faites.
- Les agents (Multica ou autres) qui travaillent pour l'utilisateur produisent des feuilles comme les
  autres : squashées par `gf land`.
- **Le travail d'un collègue garde ses commits** : `$GF land --keep <branche>` rebase et avance le
  parent en fast-forward, auteurs et commits intacts, branche conservée.
- Contraintes de worktree : la feuille se pose depuis l'arbre où elle est extraite, et le parent ne
  doit être extrait dans aucun autre arbre (`gf` le refuse).

## 4. L'entrée dans l'intégration : la PR

1. Tant que la PR n'est pas ouverte, rebaser la branche du ticket sur la tête de l'intégration, puis
   `$GF check <intégration>` : il signale les merges, les tags manquants, les commits sans corps, les
   fixups non squashés et les motifs interdits.
2. Ouvrir la PR (titre et description : voir la référence du dépôt).
3. **PR ouverte et récupérée par des relecteurs : plus de rebase**, même si l'intégration avance. On
   n'intervient que si ADO déclare un conflit à la complétion.
4. Complétion en **merge (no fast-forward)**, message réécrit en anglais (« Customize merge commit
   message ») :

   ```bash
   $GF pr-message <n> "<English subject>" body.txt
   # [#3541-MenuZeroPricedLines] Merged PR 1781: Handle zero-priced menu lines
   #
   # <corps de 3 à 5 lignes : ce que la branche apporte et pourquoi>
   ```

Les branches créées avant ce procédé (sous-branches mergées `--no-ff` dans leur parent) restent
telles quelles : on ne réécrit pas un historique existant pour l'adopter.

## 5. Tout ce que git porte s'écrit en anglais

Noms de branches, sujets et corps de commit, message de merge de PR, noms de tags. Une conversation
menée en français ne change pas la langue du commit qu'elle produit.

## 6. `#NOWI` : travail local sans ticket

`$GF start NOWI <Sujet> <base>` crée `PR/#NOWI-Sujet` (tiret, jamais underscore). Le hook
`pre-push` refuse de l'envoyer sur origin. Pour en sortir, AskUserQuestion entre :

- créer un WI, puis `$GF rename 'PR/#NOWI-Sujet' 'PR/#<id>-Sujet' <base>` ;
- en faire une feuille d'un WI existant : `$GF rename 'PR/#NOWI-Sujet' 'PR/#<id>-Parent-Sujet'`,
  puis `gf land` ;
- exception assumée par l'utilisateur : `GF_ALLOW_NOWI=1 git push …`.

## 7. Réécrire sans perdre

- **Renommer et retaguer** : `$GF rename <ancienne> <nouvelle> [<base>]`. Il réécrit les tags
  `[ancienne…]` en `[nouvelle…]` sur `<base>..<ancienne>`, garde arbres, auteurs et dates, fait suivre
  les branches qui pointaient sur un commit réécrit, donne la commande `git rebase --onto` pour celles
  qui en partent, et compare l'inventaire des refs avant et après. Jamais `git filter-branch` : il
  supprime au passage des branches sans rapport.
- **Prouver un rebase** : `git range-diff '<branche>@{1}...<branche>'` montre commit par commit ce
  qui a changé ; une réécriture de messages seule doit donner `git diff <ancienne tête> <nouvelle>`
  vide.
- **Sauvegarder avant une opération risquée : un tag**, pas une branche. `rebase.updateRefs` déplace
  les branches qui pointent dans la plage rebasée, pas les tags.
- **Réécrire une branche déjà poussée** : AskUserQuestion d'abord, puis
  `GF_ALLOW_FORCE=1 git push --force-with-lease --force-if-includes`. Le hook `pre-push` refuse tout
  push qui réécrit une branche distante, quel que soit le drapeau.
- **Reformuler le merge en tête** (dépôt sans PR) sans changer arbre, parents ni date d'auteur :
  `GIT_COMMITTER_DATE="$(git show -s --format=%cI)" git commit --amend -F merge-msg.txt`.

## 8. Moments de contrôle humain (AskUserQuestion)

Le hook Claude `claude-guard.sh` transforme en demande de permission les commandes qui suivent,
quelle que soit leur écriture (`git -C`, `rtk git`, commandes chaînées) ; l'AskUserQuestion montre
avant ce qui va partir, en entier.

- `az boards work-item create/update/delete`, `az boards work-item relation add/remove`.
- `az repos pr create/update`.
- Tout push forcé.
- Une branche `#NOWI` qui toucherait origin.
- Une subdivision qui dépasse ce qui avait été annoncé (nouvelle branche de ticket, feuille de feuille).

## 9. Mise en place

Une fois par machine (versionné dans les dotfiles) :

```bash
git config --global rebase.updateRefs true   # une pile de branches se rebase d'un coup
git config --global rerere.enabled true      # une résolution de conflit se rejoue
```

et le hook Claude dans `~/.claude/settings.json` : `PreToolUse`, matcher `Bash`, commande
`~/.claude/skills/gitflow/scripts/claude-guard.sh`.

Une fois par dépôt :

```bash
$GF hooks                                     # lie prepare-commit-msg, commit-msg et pre-push
git config --add gf.forbidden '<regex ERE>'   # motifs refusés dans les messages et les noms
```

`gf hooks` garde un hook existant sous `<nom>.pre-gf`. Les worktrees partagent les hooks du dépôt.

Les worktrees ne relèvent pas de ce skill : leur politique dépend de l'équipe ou de l'orchestrateur
qui les utilise.
