# Migrations référencement / commissions — 14 juillet 2026

Ces migrations sont **appliquées en production** et enregistrées dans l'historique de migration Supabase (schema `supabase_migrations.schema_migrations`) :

| Version | Nom | Rôle |
|---------|-----|------|
| 20260714000106 | referral_multiactor_schema | Colonnes créateur + rôle bénéficiaire, table `content_assets`, index d'unicité multi-bénéficiaires (fichier présent ici) |
| 20260714000202 | referral_multiactor_rpcs | RPC config (owner/promoteur/créateur/plateforme + fenêtre), `app_register_share` étendu, RPC bibliothèque de contenus |
| 20260714000337 | unified_commission_split_generator | `app_generate_commission_split_for_payment` (taux grille + cap, split configurable, idempotent) |
| 20260714104717 | wire_unified_commission_into_payment_paths | Branchement dans `app_admin_confirm_payment`, désactivation du bénéficiaire `commercial` de `revenue_split_rules` (fin du double crédit) |
| 20260714104823 | ligdicash_confirm_uses_unified_commission | `app_confirm_ligdicash_payment` utilise le générateur unifié |

## Résorber la dérive de schéma (recommandé)

Tout le domaine commercial historique avait été appliqué hors migration. Pour rapatrier l'état réel dans le repo en une commande :

```bash
supabase link --project-ref thevdfcwlcqzdoybfvgs
supabase db pull            # génère les fichiers de migration manquants depuis la prod
```

Ensuite : **ne plus jamais** appliquer de DDL hors migration (bannir `admin_execute_sql` pour le schéma).

## Revenir en arrière (si besoin)

Le seul changement de comportement en prod est la désactivation du bénéficiaire `commercial` dans `actor_balances`. Pour rétablir l'ancien comportement :

```sql
UPDATE app.revenue_split_rules SET is_active = TRUE WHERE beneficiary_type = 'commercial';
```

Rien d'autre n'a d'effet tant qu'aucun scénario de partage ≠ `first_click_100` n'est activé par l'admin.
