# Résultat attendu de l’audit ultra rigoureux du module TD

- **1. Tables TD (schéma app)** :
  - Lister toutes les tables commençant par td_ (ex: td_fields, td_programs, td_collections, td_sessions, td_teachers, etc.)
- **2. Policies RLS** :
  - Détail de chaque policy sur chaque table TD (nom, expression USING/WITH CHECK)
- **3. GRANTs effectifs** :
  - Pour chaque table TD, liste des droits (SELECT, INSERT, UPDATE, DELETE) par rôle (authenticated, service_role, etc.)
- **4. Fonctions/RPCs TD** :
  - Noms, schémas, types (fonction, procédure), pour tout ce qui contient "td"
- **5. Colonnes critiques** :
  - Pour td_fields et td_programs : nom, type, nullable, défaut

---

**Étape suivante** :
- Lire le résultat SQL réel (en JSON ou dans les logs) pour chaque point ci-dessus.
- Comparer point par point avec les accès et modèles utilisés côté Flutter dans `AdminTdCatalogProvider` et autres providers TD.
- Vérifier qu’aucune confusion n’existe avec l’autre module TD (autres schémas ou tables non concernées).

---

**Note** :
- Si le résultat SQL n’est pas disponible dans les logs, il faut ajuster le script Python pour qu’il écrive explicitement le résultat dans un fichier ou dans la console.
