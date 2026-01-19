#!/usr/bin/env python3
"""Ajout incrémental de connaissances internes Nexiom/Academia pour Bobodo.

Ce script respecte les procédures .windsurf :
- lecture via auto_supabase_import.read sur app.bobodo_knowledge
- insertion via la RPC admin_execute_sql (service_role), comme seed_bobodo_knowledge.py

Objectif : enrichir la base locale avec des fiches supplémentaires
strictement liées à Nexiom Group et à la plateforme Academia.
"""

from __future__ import annotations

from typing import Any, Dict, List

import auto_supabase_import as sup
import seed_bobodo_knowledge as seed


EXTRA_ITEMS: List[Dict[str, Any]] = [
    {
        "category": "nexiom",
        "title": "Offre de formation propre à Nexiom Group",
        "content": (
            "En plus de son rôle de courtier, Nexiom Group conçoit et met en "+
            "oeuvre ses propres activités de formation avec ses ressources internes. "
            "L'entreprise organise notamment des préparations aux concours directs "
            "de la fonction publique burkinabè, des préparations aux concours "
            "professionnels, des cours d'appui pour le supérieur et pour le "
            "secondaire, ainsi que des actions de sensibilisation et d'autres "
            "formations ponctuelles. "
            "Ces activités restent des prestations de formation et d'accompagnement "
            "proposées par une entreprise légalement constituée, et ne doivent pas "
            "être confondues avec des bourses d'études."
        ),
        "tags": [
            "nexiom",
            "formation",
            "concours",
            "cours-d-appui",
            "sensibilisation",
        ],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "nexiom",
        "title": "Formations et accompagnement sur les marchés publics",
        "content": (
            "Nexiom Group peut proposer des formations et un accompagnement "
            "spécifiques liés aux marchés publics et aux appels d'offres. "
            "Sur demande, l'entreprise peut aider des particuliers ou des "
            "organisations à comprendre les procédures de passation de marché, "
            "à préparer des dossiers d'appel d'offres et à structurer leurs "
            "candidatures, en collaboration avec ses partenaires."
        ),
        "tags": [
            "nexiom",
            "formation",
            "marches-publics",
            "appels-d-offres",
        ],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "nexiom",
        "title": "Formations non diplômantes et certifiantes sur demande",
        "content": (
            "En dehors des formations diplômantes, Nexiom Group peut organiser ou co-organiser "
            "des formations qui aboutissent à une attestation, à un certificat ou simplement "
            "à l'acquisition de compétences (préparation à un concours ou à un examen, "
            "formations pratiques, etc.). "
            "Suite aux demandes des utilisateurs exprimées via la plateforme Academia ou les "
            "autres canaux de communication du groupe, Nexiom Group peut proposer ces "
            "formations en interne ou, pour les formations certifiantes, en collaboration "
            "avec des structures partenaires, car l'entreprise ne délivre pas elle-même de "
            "certifications officielles. "
            "Si une personne a un compte normalement constitué et souhaite une formation qui "
            "n'apparaît pas dans la liste des offres actuelles, elle peut écrire à "
            "l'administrateur de la plateforme. L'administrateur étudiera la demande et, si "
            "la formation est non diplômante, cherchera une solution adaptée en indiquant les "
            "modalités et conditions."
        ),
        "tags": [
            "nexiom",
            "formation",
            "non-diplomante",
            "certificat",
            "demande",
        ],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "academia",
        "title": "Parcours étudiant : Inscription et connexion à Academia",
        "content": (
            "## Parcours étudiant : Inscription et connexion à Academia\n\n"
            "Ce parcours décrit, étape par étape, comment un nouvel utilisateur crée "
            "son compte Academia puis se connecte pour accéder au tableau de bord étudiant.\n\n"
            "### 1. Arriver sur l’écran d’accueil non connecté\n\n"
            "- **Écran affiché** : page d’accueil marketing (AuthLandingScreen) avec le logo Nexiom/Academia, "
            "un bouton `Connexion` à gauche et un bouton rouge `Créer un compte` à droite.\n"
            "- **Action à effectuer** : choisir entre:\n"
            "  - appuyer sur `Créer un compte` pour une première inscription ;\n"
            "  - ou appuyer sur `Connexion` si l’utilisateur a déjà un compte Academia.\n"
            "- **Ce que l’utilisateur voit** : l’application ouvre soit l’écran d’inscription (SignupScreen), "
            "soit l’écran de connexion (LoginScreen).\n\n"
            "### 2. Créer un compte étudiant (SignupScreen)\n\n"
            "- **Écran affiché** : formulaire `Inscription` avec les champs :\n"
            "  - `Nom` ;\n"
            "  - `Prénoms` ;\n"
            "  - `Email` ;\n"
            "  - `Mot de passe` ;\n"
            "  - `Code d’invitation (optionnel)` si l’utilisateur a reçu un lien de la part de l’équipe.\n"
            "- **Actions à effectuer** :\n"
            "  1. Renseigner nom, prénoms, email et mot de passe en respectant les consignes usuelles de sécurité ;\n"
            "  2. Saisir un code d’invitation si l’utilisateur en a un (facultatif) ;\n"
            "  3. Appuyer sur le bouton `Créer le compte`.\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - en cas de succès, l’application envoie un email de confirmation Supabase à l’adresse saisie ;\n"
            "  - si un code d’invitation a été fourni, l’application tente de le valider et affiche un message "
            "    de succès ou un avertissement en bas de l’écran ;\n"
            "  - puis l’écran se ferme et l’utilisateur revient sur la page précédente en attendant de cliquer sur "
            "    le lien reçu dans sa boîte mail.\n\n"
            "### 3. Confirmer le compte via l’email de Supabase\n\n"
            "- **Écran affiché** : dans la boîte mail de l’utilisateur (en dehors de l’app), un message de Supabase "
            "contient un lien de confirmation/redirection.\n"
            "- **Action à effectuer** : ouvrir l’email, cliquer sur le lien de confirmation ou de connexion.\n"
            "- **Ce que l’utilisateur voit** : le lien ouvre un écran `AuthCallbackScreen` dans le navigateur ou l’app, "
            "avec un indicateur `Connexion en cours...`. À la fin du traitement, l’utilisateur est redirigé vers le flux "
            "principal d’authentification (AuthWrapper).\n\n"
            "### 4. Se connecter avec un compte existant (LoginScreen)\n\n"
            "- **Écran affiché** : formulaire `Connexion` avec :\n"
            "  - champ `Email` ;\n"
            "  - champ `Mot de passe` avec icône pour afficher/masquer ;\n"
            "  - lien `Mot de passe oublié ?`.\n"
            "- **Actions à effectuer** :\n"
            "  1. Renseigner l’email et le mot de passe utilisés lors de l’inscription ;\n"
            "  2. Appuyer sur le bouton `Se connecter`.\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - en cas de succès, l’écran se ferme et l’utilisateur est considéré comme connecté ;\n"
            "  - en cas d’erreur (email ou mot de passe incorrect), un message d’erreur rouge s’affiche au-dessus du bouton.\n\n"
            "### 5. Réinitialiser son mot de passe (optionnel)\n\n"
            "- **Écran affiché** : depuis `Connexion`, en cliquant sur `Mot de passe oublié ?`, une demande de lien de "
            "réinitialisation est envoyée à l’email saisi. Après clic sur ce lien dans la boîte mail, l’utilisateur arrive sur "
            "`AuthCallbackScreen` puis sur un écran `Nouveau mot de passe`.\n"
            "- **Actions à effectuer** : saisir et confirmer un nouveau mot de passe, puis valider.\n"
            "- **Ce que l’utilisateur voit** : un message de succès indique que le mot de passe est mis à jour, et l’app "
            "redirige vers la page d’accueil connectée.\n\n"
            "### 6. Arriver sur le tableau de bord étudiant (AuthWrapper / StudentDashboardScreen)\n\n"
            "- **Écran affiché** : une fois connecté, `AuthWrapper` choisit le bon tableau de bord en fonction du rôle "
            "stocké dans le profil Supabase. Si le rôle est `student`, l’utilisateur voit le `StudentDashboardScreen` "
            "avec ses onglets (Accueil, Candidatures, Opportunités, Communautés, Universités, Bobodo, etc.).\n"
            "- **Ce que l’utilisateur voit** : la navigation complète côté étudiant est disponible. Les parcours de "
            "candidature et de suivi décrits dans d’autres fiches partent tous de ce tableau de bord.\n"
        ),
        "tags": [
            "academia",
            "parcours-etudiant",
            "inscription",
            "connexion",
            "compte",
            "authentification",
        ],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "academia",
        "title": "Parcours étudiant : Postuler à une formation via les opportunités",
        "content": (
            "## Parcours étudiant : Postuler à une formation via les opportunités\n\n"
            "Ce parcours explique comment un étudiant connecté explore les opportunités, sélectionne une formation "
            "et envoie une candidature complète (message + CV).\n\n"
            "### 1. Accéder à l’onglet Opportunités\n\n"
            "- **Point de départ** : l’étudiant est déjà connecté et voit le `StudentDashboardScreen`.\n"
            "- **Écran affiché** : onglet `Opportunités` (StudentOpportunitiesTab), présenté comme un fil d’actualité "
            "avec des cartes de type Facebook/LinkedIn (titre de la formation, établissement partenaire, type, lieu, tags).\n"
            "- **Actions à effectuer** :\n"
            "  - utiliser la barre de recherche en haut pour filtrer par mots-clés ;\n"
            "  - filtrer par type d’opportunité (ex. formation, cours d’appui, petit atelier) ;\n"
            "  - activer/désactiver l’affichage des favoris (bookmarks) si nécessaire.\n\n"
            "### 2. Ouvrir une opportunité intéressante\n\n"
            "- **Écran affiché** : chaque élément du feed est une carte avec un résumé de l’offre et des boutons d’action "
            "(en savoir plus, réagir, commenter, enregistrer en favori, etc.).\n"
            "- **Action à effectuer** : toucher la carte ou le bouton dédié pour afficher les détails de la formation "
            "(selon la configuration de l’interface).\n"
            "- **Ce que l’utilisateur voit** : une vue plus détaillée de l’opportunité (description longue, exigences, "
            "éventuelles informations sur les frais ou le calendrier).\n\n"
            "### 3. Lancer la candidature depuis une opportunité\n\n"
            "- **Écran affiché** : sur la carte d’opportunité, l’étudiant trouve un bouton de type `Postuler` ou "
            "`Candidater` (déclenché côté code par `_applyToOpportunity`).\n"
            "- **Action à effectuer** : appuyer sur ce bouton pour ouvrir la fenêtre de candidature.\n"
            "- **Ce que l’utilisateur voit** : une boîte de dialogue `Postuler à cette opportunité` apparaît avec :\n"
            "  - un champ texte `Message de motivation (optionnel)` ;\n"
            "  - un bloc `Joindre un CV` avec un bouton `Parcourir` ;\n"
            "  - les boutons `Annuler` et `Envoyer`.\n\n"
            "### 4. Rédiger le message de motivation (optionnel)\n\n"
            "- **Écran affiché** : dans la boîte de dialogue, un grand champ texte permet de décrire son profil, son "
            "projet et sa motivation.\n"
            "- **Action à effectuer** : rédiger un message clair et concis ; ce champ peut rester vide si l’étudiant "
            "ne souhaite pas ajouter de texte.\n"
            "- **Ce que l’utilisateur voit** : le texte reste visible dans la boîte de dialogue jusqu’à l’envoi.\n\n"
            "### 5. Joindre un CV ou un document\n\n"
            "- **Écran affiché** : bloc `Joindre un CV` qui indique l’état actuel (aucun fichier ou nom du fichier joint).\n"
            "- **Actions à effectuer** :\n"
            "  1. Appuyer sur le bouton `Parcourir` ;\n"
            "  2. Choisir un fichier dans le téléphone ou l’ordinateur (formats acceptés : PDF, image ou Word) ;\n"
            "  3. Attendre que l’envoi se termine.\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - pendant l’envoi, le texte peut indiquer `Envoi en cours...` ;\n"
            "  - en cas de succès, le bloc passe en vert clair avec le nom du fichier ;\n"
            "  - en cas d’erreur (par exemple fichier illisible), un message d’erreur s’affiche en bas de l’écran.\n\n"
            "### 6. Envoyer la candidature\n\n"
            "- **Écran affiché** : la boîte de dialogue affiche les champs remplis et le bouton `Envoyer`.\n"
            "- **Action à effectuer** : appuyer sur `Envoyer`. Le code appelle ensuite la logique métier côté Supabase "
            "pour créer la candidature liée à l’opportunité.\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - si l’opération réussit, la boîte de dialogue se ferme et un message `Candidature envoyée avec succès.` "
            "    apparaît en bas de l’écran ;\n"
            "  - si une erreur survient (ex. problème réseau ou règle côté serveur), un message d’erreur détaillé "
            "    remonte dans une bannière SnackBar.\n\n"
            "### 7. Où retrouver sa candidature après envoi ?\n\n"
            "- **Écran affiché** : onglet `Candidatures` (StudentApplicationsTab) du tableau de bord étudiant.\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - la candidature nouvellement créée apparaît dans la liste `Mes candidatures` avec un statut (brouillon, "
            "    soumise, en cours d’examen, acceptée, rejetée, etc.) ;\n"
            "  - un bouton permet d’ouvrir le détail de la candidature pour suivre les documents, messages et paiements.\n"
            "- **Lien avec les autres fiches** : le détail du suivi (messages à l’administration, ajout de pièces, déclarations "
            "de paiement) est décrit dans la fiche `Parcours étudiant : Suivi de sa candidature dans Academia`.\n"
        ),
        "tags": [
            "academia",
            "parcours-etudiant",
            "postuler",
            "candidature",
            "opportunites",
            "offres",
        ],
        "language": "fr",
        "is_active": True,
    },
    {
        "category": "academia",
        "title": "Parcours étudiant : Suivi de sa candidature dans Academia",
        "content": (
            "## Parcours étudiant : Suivi de sa candidature dans Academia\n\n"
            "Ce parcours détaille comment un étudiant suit l’état de ses candidatures, ajoute des documents, "
            "échange avec l’équipe et déclare des paiements si nécessaire.\n\n"
            "### 1. Accéder à l’onglet Mes candidatures\n\n"
            "- **Point de départ** : l’étudiant est connecté et se trouve sur le `StudentDashboardScreen`.\n"
            "- **Écran affiché** : onglet `Candidatures` (StudentApplicationsTab) avec le bandeau `Mes candidatures` en haut.\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - une liste de cartes, une par candidature, chacune affichant la formation, l’établissement, la date et le "
            "    statut (brouillon, soumise, en cours d’examen, acceptée, rejetée, annulée, etc.) ;\n"
            "  - si aucune candidature n’existe encore, un écran vide explique que les futures candidatures apparaîtront ici "
            "    et propose un bouton `Découvrir des opportunités`.\n\n"
            "### 2. Filtrer les candidatures par statut\n\n"
            "- **Écran affiché** : sous le bandeau, une barre de filtres par statut (brouillon, soumise, under_review, accepted, "
            "rejected, canceled, etc.).\n"
            "- **Actions à effectuer** :\n"
            "  - appuyer sur un filtre pour n’afficher que les candidatures correspondantes ;\n"
            "  - appuyer sur `Tous` pour revenir à la vue globale.\n"
            "- **Ce que l’utilisateur voit** : la liste se met à jour immédiatement en fonction du filtre choisi.\n\n"
            "### 3. Ouvrir le détail d’une candidature\n\n"
            "- **Écran affiché** : en touchant une carte, l’app ouvre `StudentApplicationDetailScreen`, qui présente la "
            "candidature avec plusieurs onglets (résumé, messages, documents, paiements, etc.).\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - les informations récapitulatives (formation, établissement, statut, éventuels commentaires internes) ;\n"
            "  - un onglet `Messages` pour discuter avec l’équipe ;\n"
            "  - un onglet `Documents` pour ajouter ou consulter les pièces jointes ;\n"
            "  - un onglet `Paiements` pour déclarer ou suivre les paiements liés à la candidature, quand c’est applicable.\n\n"
            "### 4. Ajouter des documents complémentaires\n\n"
            "- **Écran affiché** : dans l’onglet `Documents`, un bouton permet d’ajouter un nouveau fichier (géré par le "
            "provider `StudentApplicationFilesProvider`).\n"
            "- **Actions à effectuer** :\n"
            "  1. Appuyer sur le bouton d’ajout de document ;\n"
            "  2. Sélectionner un fichier (PDF, image ou document bureautique) ;\n"
            "  3. Confirmer l’upload.\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - en cas de succès, le nouveau document apparaît dans la liste ;\n"
            "  - en cas d’échec, un message d’erreur explique le problème (format, taille, réseau, etc.).\n\n"
            "### 5. Échanger avec l’équipe via les messages\n\n"
            "- **Écran affiché** : onglet `Messages` de `StudentApplicationDetailScreen`, connecté au provider "
            "`StudentApplicationMessagesProvider`.\n"
            "- **Actions à effectuer** : écrire un message dans la zone prévue, puis l’envoyer pour poser une question, "
            "apporter une précision ou répondre à l’administration.\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - les nouveaux messages de l’équipe s’affichent dans ce fil ;\n"
            "  - les notifications push renvoyant vers cette candidature peuvent ouvrir directement cet écran à partir "
            "    du tableau de bord.\n\n"
            "### 6. Déclarer un paiement lié à la candidature\n\n"
            "- **Écran affiché** : onglet `Paiements` avec un bouton `Déclarer un paiement`.\n"
            "- **Actions à effectuer** :\n"
            "  1. Ouvrir la feuille de déclaration ;\n"
            "  2. Choisir le canal (espèces, Orange Money, Moov Money, Telecel Money, etc.) ;\n"
            "  3. Indiquer le montant effectivement payé et, si disponible, une référence de transaction ou numéro de reçu ;\n"
            "  4. Ajouter une note pour l’administration si nécessaire ;\n"
            "  5. Valider la déclaration.\n"
            "- **Ce que l’utilisateur voit** :\n"
            "  - en cas de succès, un message confirme que le paiement est `en attente de vérification` ;\n"
            "  - l’état de la candidature ou des paiements peut évoluer après validation côté administration.\n\n"
            "### 7. Retour à la liste des candidatures et mises à jour\n\n"
            "- **Comportement général** : en quittant `StudentApplicationDetailScreen`, la liste `Mes candidatures` est "
            "rafraîchie afin de refléter les nouveaux statuts, documents ou paiements.\n"
            "- **Ce que l’utilisateur voit** : les badges ou statuts changent en fonction de l’avancement du dossier, "
            "ce qui lui permet de suivre facilement là où il en est dans le processus.\n"
        ),
        "tags": [
            "academia",
            "parcours-etudiant",
            "suivi",
            "candidature",
            "documents",
            "paiements",
            "messages",
        ],
        "language": "fr",
        "is_active": True,
    },
]


def main() -> int:
    # Lire les connaissances existantes pour éviter les doublons de titre
    existing = sup.read("app.bobodo_knowledge", limit=500)
    existing_titles = set()
    if existing.get("success") and isinstance(existing.get("data"), list):
        for row in existing["data"]:
            title = str(row.get("title") or "").strip()
            if title:
                existing_titles.add(title)

    if not existing.get("success"):
        print("[WARN] Lecture app.bobodo_knowledge échouée (méthode API), poursuite quand même.")

    for item in EXTRA_ITEMS:
        title = str(item["title"])
        category = str(item["category"])
        content = str(item["content"])
        tags = [str(t) for t in item.get("tags", [])]
        language = str(item.get("language", "fr"))
        is_active = bool(item.get("is_active", True))

        if title in existing_titles:
            print("[SKIP] Connaissance déjà présente, ignorée:", title)
            continue

        # Échapper les quotes simples pour le SQL
        def esc(value: str) -> str:
            return value.replace("'", "''")

        tags_sql = ", ".join(f"'{esc(t)}'" for t in tags)
        sql = f"""
INSERT INTO app.bobodo_knowledge (category, title, content, tags, language, is_active)
VALUES (
  '{esc(category)}',
  '{esc(title)}',
  '{esc(content)}',
  ARRAY[{tags_sql}],
  '{esc(language)}',
  {'TRUE' if is_active else 'FALSE'}
);
""".strip()

        if not seed.call_admin_execute_sql(sql):
            print("[ERROR] Échec d'insertion connaissance via admin_execute_sql:", title)
            return 1

        print("[OK] Connaissance insérée:", title)

    print("[SUCCESS] Ajout des connaissances Nexiom/Academia terminé.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
