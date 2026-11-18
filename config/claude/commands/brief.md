---
description: Génère le brief matinal et l'insère dans la note Obsidian du jour
---

Lance le brief matinal à la demande.

Exécute cette commande, puis rends compte brièvement :

```
mise -C /home/mcma/dev/zz-daily-cron run brief $ARGUMENTS
```

Arguments utiles (à passer tels quels dans `$ARGUMENTS`) :

- *(aucun)* — brief du jour, écrit dans la note
- `--dry-run` — affiche le brief sans toucher à la note
- `--date 2026-08-14` — rejoue une journée passée
- `20260921` : tout depuis cette date (00h00) jusqu'à maintenant ; une heure est
  acceptée entre guillemets (`'2026-09-30 14:00'`)
- `--keep-bundle` — conserve `cache/<date>/bundle.json` pour inspection

Après exécution :

1. Si des sources sont en échec (ligne `sources en echec` dans la sortie), dis lesquelles et
   pourquoi — le message d'erreur est dans `~/.local/state/zz-daily-cron/brief/log/brief-<date>.log`.
2. Sinon, confirme simplement le chemin de la note et le nombre de lignes.

N'affiche pas le brief entier si la note a été écrite : l'utilisateur va le lire dans Obsidian.
