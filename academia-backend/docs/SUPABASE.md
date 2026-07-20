# Guide Supabase

## Connexion
Le backend utilise `@supabase/supabase-js` avec la **service role key** (`src/modules/supabase/supabase.client.ts`). Cette clé contourne la RLS : elle vit **uniquement** côté serveur, jamais dans l'app Flutter/web.

Variables : `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.

## Couche Service (règle d'or)
Aucun module n'accède directement aux tables. Toutes les opérations passent par `DatabaseService` (`src/database/database.service.ts`) :

```ts
import { databaseService } from './database/database.service.js';

await databaseService.list('eleves', { filters: { auto_ecole_id: id }, limit: 50 });
await databaseService.getByIdOrFail('eleves', eleveId);
await databaseService.insert('paiements', { eleve_id, montant });
await databaseService.update('eleves', eleveId, { statut: 'actif' });
await databaseService.remove('paiements', paiementId);
await databaseService.rpc('unified_commission_split_generator', { p_payment_id });
```

Avantages : gestion d'erreurs et logging centralisés, remplacement de la base facilité, aucune duplication d'accès.

## Types TypeScript typés depuis le schéma
`src/database/database.types.ts` est un placeholder permissif. Pour des types réels :

```bash
# nécessite la CLI Supabase + `supabase login`
SUPABASE_PROJECT_ID=<votre-ref> npm run generate:types
```

## Sécurité — RLS
Un audit du projet a signalé plusieurs tables avec **RLS désactivée** (tables de test dans le schéma `public`). En production, activer la RLS et définir des politiques adaptées. Ne pas activer la RLS sans politiques : cela bloquerait tout accès. Voir https://supabase.com/docs/guides/database/postgres/row-level-security
