-- Injection cours Droit International Privé (DIP) Licence III
-- Utilise app_td_admin_import_text_bulk pour créer source_doc + chunks RAG
-- Approche: appel direct SQL (même logique que la RPC) car migration = service_role

DO $$
DECLARE v_doc_id UUID;
BEGIN
  -- Source document
  INSERT INTO app.td_source_documents (
    subject, university, study_year, doc_type,
    storage_bucket, storage_path, original_filename,
    status, extracted_text
  ) VALUES (
    'Droit International Privé', NULL, 'L3', 'cours',
    'manual', 'manual/dip_l3_cours_complet.txt', 'Cours_DIP_L3_BF.txt',
    'indexed',
    'Cours complet de Droit International Privé Licence III — Introduction, sources, compétence internationale, effets des jugements étrangers, conflits de lois, qualification, renvoi, ordre public international, statut personnel, mariage, divorce, filiation, successions.'
  )
  RETURNING id INTO v_doc_id;

  -- ═══ CHUNKS ═══
  INSERT INTO app.td_doc_chunks (id, source_document_id, chunk_index, content, metadata, chunk_type, subject, university, study_year, token_count) VALUES

  (gen_random_uuid(), v_doc_id, 0,
$c$DROIT INTERNATIONAL PRIVÉ — OBJET DE LA MATIÈRE

Le DIP est la discipline juridique qui s'intéresse aux relations privées internationales. Plus exactement, le DIP est le droit qui régit les relations internationales privées et qui réglemente les problèmes particuliers que posent les relations privées du fait de leur caractère international.

Pour comprendre l'objet du DIP, il est nécessaire de définir la relation internationale privée et d'identifier les problèmes spécifiques que posent ces relations.

Les rapports juridiques dont le DIP entend être la discipline se distinguent par deux caractéristiques : leur caractère international et leur nature privée. Le DIP est une matière transversale car tout type de relation privée est susceptible d'être affecté d'un élément d'extranéité.$c$,
  '{"source":"cours","topic":"introduction","subtopic":"objet_DIP"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 200),

  (gen_random_uuid(), v_doc_id, 1,
$c$NOTION DE RELATION INTERNATIONALE PRIVÉE — ÉLÉMENT D'EXTRANÉITÉ

Le qualificatif « international » signifie qu'une relation juridique n'intéresse le DIP que si elle présente un caractère international, c'est-à-dire que la relation entretient des liens (ou des rattachements) avec deux ou plusieurs États.

Exemples : un mariage entre deux italiens résidant au BF devant l'OEC burkinabè ; un contrat de vente entre un vendeur au BF et un acheteur au Mali exécuté au Bénin.

L'élément d'extranéité est l'élément par lequel la situation se rattache à un autre système juridique et qui donne à la relation son caractère international. Il ne s'agit pas nécessairement de la nationalité. En matière de statut personnel, l'extranéité est souvent provoquée par la nationalité. En matière extrapatrimoniale, l'extranéité peut provenir du lieu de situation du bien, du domicile, du lieu d'exécution, du lieu de réalisation du fait générateur du dommage.$c$,
  '{"source":"cours","topic":"introduction","subtopic":"element_extraneite"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 220),

  (gen_random_uuid(), v_doc_id, 2,
$c$PROBLÈMES SPÉCIFIQUES QUE POSE LA RELATION PRIVÉE INTERNATIONALE

Il y en a principalement 3 :

1. La compétence internationale des juridictions burkinabè : aptitude des juridictions burkinabè dans leur ensemble à connaître d'un litige empreint d'un élément d'extranéité.

2. L'efficacité au BF des jugements et actes publics étrangers : un jugement étranger peut-il produire des effets au BF ?

3. Le conflit de lois : parmi les lois potentiellement applicables, laquelle faut-il appliquer ? Le terme « conflit » exprime une situation de concurrence entre plusieurs lois potentiellement applicables à une même situation juridique.

En plus de ces trois problèmes principaux, deux questions additionnelles : la question des conflits de nationalités et la question de la situation des étrangers (droits et obligations des étrangers au BF).$c$,
  '{"source":"cours","topic":"introduction","subtopic":"trois_problemes_DIP"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 200),

  (gen_random_uuid(), v_doc_id, 3,
$c$SOURCES DU DIP — PRINCIPES GÉNÉRAUX DU DROIT INTERNATIONAL

Le rôle du droit international général en tant que source du DIP est très modeste.

En matière de conflit de nationalités : le principe de la compétence exclusive de l'État pour légiférer sur sa nationalité. Chaque État a pleine compétence pour déterminer ses nationaux et ne peut légiférer que sur sa seule nationalité.

Deux recommandations : 1) Il est souhaitable que tout individu ait une nationalité (éviter l'apatridie — Convention de NY 1954). L'article 143 du CPF en est une application. 2) Il faut éviter le cumul de nationalités (recommandation aujourd'hui désuète).

Le concept de territorialité a trois sens en DIP : limitation des actes de contrainte étatique au territoire ; les organes d'un État ne sont liés que par les injonctions de leur propre État ; le droit international permet des lois d'application territoriale.$c$,
  '{"source":"cours","topic":"sources","subtopic":"principes_generaux"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 210),

  (gen_random_uuid(), v_doc_id, 4,
$c$SOURCES DU DIP — DROIT INTERNATIONAL CONVENTIONNEL

La condition des étrangers : domaine où les traités jouent un rôle considérable. Deux catégories : les traités fonctionnant sur la base de la réciprocité et les traités sans réciprocité bénéficiant à toute personne sous la juridiction d'un État partie.

Pour le BF : Protocole de Dakar du 29 mai 1979 (CEDEAO, libre circulation), Traité UEMOA (art. 91 et s.), Convention d'établissement avec le Mali (30 septembre 1969).

Questions juridictionnelles : Convention avec la France (24 avril 2018), Convention avec le Mali (23 novembre 1963), Convention avec la Côte d'Ivoire (30 juillet 2014), 3 conventions avec le Maroc (3 septembre 2018). Accords multilatéraux : Convention UAM (21 avril 1961), Accord ANAD (21 avril 1981, jamais entré en vigueur).$c$,
  '{"source":"cours","topic":"sources","subtopic":"droit_conventionnel"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 200),

  (gen_random_uuid(), v_doc_id, 5,
$c$SOURCES — CONFLITS DE LOIS ET CONFÉRENCE DE LA HAYE

Les conflits de lois : domaine faiblement couvert par le droit conventionnel.

La Conférence de DIP de La Haye : regroupement d'experts (professeurs d'université) chargé d'élaborer des conventions multilatérales. Nombreuses conventions depuis les années 1950 (adoption, régimes matrimoniaux, etc.). Le BF est partie depuis 2013 et a ratifié deux conventions avant son adhésion : Convention sur la protection des enfants et la coopération en matière d'adoption internationale (29 mai 1993), Convention sur les aspects civils de l'enlèvement international d'enfants (25 octobre 1980).

Les conventions contenant des règles matérielles : Convention de Vienne du 11 avril 1980 sur la vente internationale de marchandises.

La jurisprudence internationale ne joue quasiment aucun rôle en DIP car la CIJ est pratiquement la seule juridiction internationale universelle.$c$,
  '{"source":"cours","topic":"sources","subtopic":"conference_la_haye"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 210),

  (gen_random_uuid(), v_doc_id, 6,
$c$SOURCES COMMUNAUTAIRES DU DIP

Droit CEDEAO et UEMOA : essentiellement les dispositions sur la libre circulation (règles d'entrée, séjour et établissement) qui concernent la condition des étrangers.

OHADA : organisation d'harmonisation du droit matériel. Particularité : unification du droit matériel qui ne vise pas que les situations internationales et qui ne s'est pas accompagnée d'une uniformisation des règles de conflit de lois. Le législateur opte pour des règles d'applicabilité dans chaque acte uniforme. Ce mécanisme est efficace car il écarte les règles de CL des États membres, mais pas totalement : en cas de lacune du droit OHADA et pour les rapports extra-communautaires, les règles de DIP s'appliquent.

Sources internes : le BF a codifié son DIP dans le CPF en 1989. Les articles 1002-1050 du CPF constituent la principale source du DIP burkinabè.$c$,
  '{"source":"cours","topic":"sources","subtopic":"sources_communautaires_internes"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 200),

  (gen_random_uuid(), v_doc_id, 7,
$c$COMPÉTENCE INTERNATIONALE — RÈGLE GÉNÉRALE (ART. 988 CPF)

Article 988 du CPF : « Les règles internes de compétence territoriale déterminent, sauf disposition contraire, la compétence internationale des juridictions et des autorités administratives burkinabè. »

Il faut transposer les critères de compétence territoriale interne à la compétence internationale :
- Art. 43 CPC : tribunal du domicile du défendeur. Les juridictions burkinabè sont compétentes si le défendeur est domicilié au BF. Critère principal : actor sequitur forum rei.
- En matière contractuelle (art. 44+) : compétence si le contrat s'est formé au BF ou si l'obligation doit être/a été exécutée au BF.
- En matière délictuelle (art. 45) : compétence si le fait générateur s'est produit au BF.
- En matière d'aliment : compétence si le créancier est domicilié au BF.
- En matière immobilière : compétence exclusive si l'immeuble est situé au BF.$c$,
  '{"source":"cours","topic":"competence_internationale","subtopic":"art_988_regle_generale"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 230),

  (gen_random_uuid(), v_doc_id, 8,
$c$FOR DE NATIONALITÉ EN MATIÈRE DE STATUT PERSONNEL (ART. 990 CPF)

Art. 990 : « En matière de statut personnel, les juridictions burkinabè peuvent connaître de toute action dans laquelle le demandeur ou le défendeur a la nationalité burkinabè au jour de l'introduction de l'instance. »

Caractéristiques :
- Champ limité aux litiges en matière de statut personnel (état et capacité des personnes).
- Caractère facultatif (non exclusif) : l'article institue une simple faculté, pas une obligation. La méconnaissance n'est pas un motif de refus de reconnaissance (al. 2), sauf exception de l'article 1000 CPF.
- Caractère résiduel/subsidiaire : le for de nationalité ne fonde la compétence que lorsqu'aucun critère de compétence ordinaire ne peut être utilisé (ex: quand le défendeur n'est pas domicilié au BF).$c$,
  '{"source":"cours","topic":"competence_internationale","subtopic":"art_990_for_nationalite"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 200),

  (gen_random_uuid(), v_doc_id, 9,
$c$FOR DE RÉCIPROCITÉ (ART. 989 CPF)

Art. 989 : si les juridictions d'un État étranger sont compétentes pour connaître des actions contre des burkinabè selon des critères non retenus par le droit burkinabè, ces mêmes critères seront applicables pour les litiges où le défendeur est un ressortissant de cet État.

Exemple : L'article 14 du Code civil français permet de citer un burkinabè devant les tribunaux français par un français. Par réciprocité, un français peut être assigné devant les juridictions burkinabè en matière patrimoniale.

Critiques :
1) Technique : le juge burkinabè doit connaître les règles de compétence des différents États étrangers (parfois jurisprudentielles). Ex : for du patrimoine en Allemagne.
2) Philosophique : c'est une mesure de rétorsion entre États qui s'applique à des intérêts privés.$c$,
  '{"source":"cours","topic":"competence_internationale","subtopic":"art_989_for_reciprocite"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 200),

  (gen_random_uuid(), v_doc_id, 10,
$c$CLAUSES ATTRIBUTIVES DE JURIDICTION (CAJ)

Définition : clause par laquelle les parties désignent l'ordre juridictionnel compétent en prévision d'un litige. Utilisée pour la sécurité juridique (connaître à l'avance l'État compétent).

Effets : 1) Attribue compétence à un ordre juridictionnel. 2) Exclut la compétence des autres.

Régime au BF : Le CPC (art. 51 al. 3) prohibe en principe les clauses modifiant la compétence territoriale interne. Exception : admises entre commerçants si clause spécifiée de façon très apparente.

Question de l'extension à la CAJ internationale : L'art. 988 CPF suggère l'extension, mais les arguments contre sont forts : les CAJ n'ont pas le même objet qu'en droit interne ; les acteurs internationaux sont des professionnels. La France a admis les CAJ depuis l'arrêt du 17 décembre 1985 (Cass.). Au BF, la question reste à préciser par la jurisprudence.$c$,
  '{"source":"cours","topic":"competence_internationale","subtopic":"CAJ"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 210),

  (gen_random_uuid(), v_doc_id, 11,
$c$CONFLITS DE PROCÉDURE — LITISPENDANCE ET CONNEXITÉ

Litispendance internationale (art. 992 CPF) : une demande identique (même objet, même cause, mêmes parties) est pendante devant un tribunal étranger. Le juge burkinabè peut surseoir à statuer si la décision étrangère est susceptible d'être reconnue au BF. C'est une simple faculté, non une obligation.

Conditions : identité de parties, d'objet et de cause ; la juridiction étrangère doit avoir été saisie en premier ; la décision étrangère doit être susceptible d'être reconnue au BF.

Connexité internationale : demandes liées entre elles par un lien étroit tel qu'il y a intérêt à les instruire et juger ensemble. Solution identique à la litispendance : le juge peut surseoir à statuer.$c$,
  '{"source":"cours","topic":"competence_internationale","subtopic":"litispendance_connexite"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 180),

  (gen_random_uuid(), v_doc_id, 12,
$c$EFFETS DES JUGEMENTS ÉTRANGERS AU BF — EXEQUATUR

Un jugement étranger ne peut pas, en principe, être exécuté au BF sans une procédure préalable : l'exequatur. L'exequatur est la procédure par laquelle un tribunal burkinabè autorise l'exécution d'un jugement étranger sur le territoire national.

Art. 993 CPF : les décisions étrangères en matière de statut personnel produisent leurs effets au BF sans exequatur (reconnaissance automatique), sauf pour l'exécution forcée.

Art. 994 CPF : pour l'exécution forcée, l'exequatur est nécessaire. Le tribunal vérifie : la compétence du juge étranger, la régularité de la procédure, l'absence de contrariété à l'ordre public international burkinabè, l'absence de fraude à la loi.

L'art. 1000 CPF : exception — si un jugement étranger a été rendu en méconnaissance de la compétence exclusive des juridictions burkinabè (for de l'art. 990), sa reconnaissance peut être refusée.$c$,
  '{"source":"cours","topic":"effets_jugements_etrangers","subtopic":"exequatur"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 220),

  (gen_random_uuid(), v_doc_id, 13,
$c$CONFLITS DE LOIS — LA TECHNIQUE CONFLICTUELLE

La méthode dominante pour résoudre un conflit de lois est la technique conflictuelle qui consiste à utiliser une règle de conflit de lois.

La règle de conflit de lois ne donne pas directement la solution au fond. Elle désigne la loi applicable à la situation. Structure : une catégorie de rattachement (ex : « les effets du mariage ») et un facteur de rattachement (ex : « la loi nationale commune des époux »).

Mise en oeuvre en 3 étapes :
1. Identifier la règle de conflit applicable (qualification)
2. Appliquer la règle de conflit pour identifier l'État dont le droit régit la situation
3. Appliquer la loi désignée pour donner une solution sur le fond

Trois questions majeures : la qualification de la situation, le renvoi, et l'ordre public international.$c$,
  '{"source":"cours","topic":"conflits_de_lois","subtopic":"technique_conflictuelle"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 200),

  (gen_random_uuid(), v_doc_id, 14,
$c$QUALIFICATION EN DIP — CONFLITS DE QUALIFICATION

La qualification consiste à ranger une situation internationale privée dans la catégorie de rattachement d'une règle de conflit de lois. On qualifie pour choisir la règle de conflit applicable.

Spécificité en DIP : la qualification peut porter sur une institution configurée à l'étranger. Deux difficultés : 1) L'institution ne correspond pas exactement à son équivalent en droit interne — il faut « internationaliser » les concepts. 2) L'institution est inconnue du for (ex : trust, partenariat enregistré) — analyser ses éléments caractéristiques et sa fonction.

Conflit de qualification : se pose quand la situation correspond à plusieurs catégories de rattachement avec des facteurs différents. Il faut déterminer le champ d'application de chaque loi.

Méthodes : Qualification lege fori (loi du for, méthode dominante) vs qualification lege causae (loi désignée par la règle de conflit).$c$,
  '{"source":"cours","topic":"conflits_de_lois","subtopic":"qualification"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 210),

  (gen_random_uuid(), v_doc_id, 15,
$c$LE RENVOI EN DIP

Le renvoi conduit le juge à appliquer la règle de conflit de lois d'un État autre que le sien.

Conditions : 1) La règle de conflit du for désigne un droit étranger (y compris ses règles de CL). 2) La règle de CL étrangère est différente de celle du for. 3) Le juge applique la règle de CL étrangère qui renvoie la compétence.

Renvoi au 1er degré : la règle de CL étrangère renvoie au droit du for. Première application : arrêt Forgo (jurisprudence française).

Renvoi au 2e degré : la règle de CL étrangère désigne le droit d'un 3e État qui retient sa compétence.

Art. 1005 CPF : admission du renvoi en matière de statut personnel. Al. 2 : renvoi au 1er degré admis. Al. 3 : renvoi au 2e degré admis. Si le 3e État ne retient pas sa compétence, on revient aux règles de CL du for.

Art. 1006 CPF : exclusion du renvoi quand la règle de CL utilise le critère de la volonté ou poursuit un objectif substantiel.$c$,
  '{"source":"cours","topic":"conflits_de_lois","subtopic":"renvoi"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 230),

  (gen_random_uuid(), v_doc_id, 16,
$c$ORDRE PUBLIC INTERNATIONAL (ART. 1010 CPF)

Art. 1010 : « Le droit étranger déclaré applicable est écarté si son application au cas d'espèce conduit à un résultat gravement incompatible avec les principes fondamentaux de l'ordre public, tel que cette notion est entendue en droit international privé burkinabè. »

Conditions de mise en oeuvre :
1) Incompatibilité grave entre les effets du droit étranger et les valeurs d'OPI du for (la simple différence ne suffit pas).
2) Étendue des effets : plus les effets sont importants, plus l'OPI se justifie (théorie de l'effet atténué).
3) Intensité du rattachement au for (ordre public de proximité).

Effets : Effet négatif = éviction du droit étranger (limitée aux seules dispositions incompatibles). Effet positif = application du droit burkinabè en remplacement.

Contenu de l'OPI : paramètres internationaux (droits fondamentaux), communautaires et nationaux.$c$,
  '{"source":"cours","topic":"conflits_de_lois","subtopic":"ordre_public_international"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 220),

  (gen_random_uuid(), v_doc_id, 17,
$c$MARIAGE — CONDITIONS DE FORME ET DE FOND

Forme (art. 1023 CPF) : régie par la loi du lieu de célébration (locus regit actum). Le mariage peut aussi être célébré en forme diplomatique/consulaire. Au BF, les agents diplomatiques étrangers ne peuvent célébrer que des mariages entre leurs ressortissants.

Conditions de fond (art. 1022 CPF) :
- Même nationalité : loi de l'État national commun des époux.
- Nationalités distinctes : application distributive des lois nationales pour les conditions personnelles (âge) ; application cumulative (loi la plus sévère) pour les conditions relationnelles (lien de parenté).

Effets du mariage (art. 1024 CPF) :
- Même nationalité — loi nationale commune.
- Nationalités distinctes — loi du domicile commun.
- Pas de domicile commun — loi du dernier domicile commun si un époux l'a conservé.
- Sinon — loi du for.

Art. 1025 : les articles 299-305 du CPF (régime matrimonial primaire) sont des lois d'application immédiate.$c$,
  '{"source":"cours","topic":"statut_personnel","subtopic":"mariage"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 240),

  (gen_random_uuid(), v_doc_id, 18,
$c$DIVORCE EN DIP — ART. 1028 CPF

Forme : application de locus regit actum. La procédure est régie par la loi du lieu où le divorce est prononcé.

Causes et effets (art. 1028) : mêmes critères que l'article 1024 :
- Même nationalité — loi nationale commune.
- Nationalités distinctes — loi du domicile commun.
- Pas de domicile commun — loi du dernier domicile commun si conservé.
- Sinon — loi du for.

Domaine : effets personnels du divorce, pensions alimentaires (art. 1029), indemnités.

Exceptions à la loi du divorce :
- Aptitude au remariage — loi nationale de chaque ex-époux.
- Port du nom du mari — art. 1020 al. 2.
- Relations parents-enfants (garde, visite) — loi nationale de l'enfant.
- Effets sur le régime matrimonial et successions — loi du régime matrimonial ou loi successorale.$c$,
  '{"source":"cours","topic":"statut_personnel","subtopic":"divorce"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 200),

  (gen_random_uuid(), v_doc_id, 19,
$c$FILIATION EN DIP — ARTICLES 1030-1037 CPF

Filiation maternelle de plein droit (art. 1030) : loi nationale de la mère au jour de la naissance.
Filiation paternelle de plein droit (art. 1031) : loi nationale du père au jour de la naissance. Subsidiairement : loi du domicile commun des parents, puis loi du for.
Filiation volontaire (art. 1032) : fond régi par la loi nationale de l'enfant. Forme : loi nationale de l'enfant ou loi du lieu (locus regit actum).
Filiation judiciaire et contestation (art. 1033) : loi nationale de l'enfant. En cas de changement de nationalité, l'enfant peut choisir le moment le plus favorable.

Effets (art. 1034) : parents mariés — loi des effets du mariage. Hors mariage ou après dissolution — loi nationale de l'enfant.

Adoption (art. 1035-1037) : conditions régies cumulativement par les lois nationales de l'adoptant et de l'adopté. Effets : loi nationale de l'adoptant.$c$,
  '{"source":"cours","topic":"statut_personnel","subtopic":"filiation"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 230),

  (gen_random_uuid(), v_doc_id, 20,
$c$OBLIGATIONS ALIMENTAIRES, RÉGIME MATRIMONIAL, SUCCESSIONS

Obligations alimentaires (art. 1041 CPF) : loi matérielle du domicile du créancier (exclusion du renvoi). Subsidiairement : loi de la nationalité commune. En dernier recours : loi burkinabè. Domaine (art. 1042) : étendue des aliments, qualité pour agir, délais, limites de l'obligation.

Régime matrimonial (art. 1026 CPF) :
- Sans contrat : même nationalité — loi nationale commune ; nationalités distinctes — loi du premier domicile commun.
- Avec contrat : même nationalité — loi nationale commune ; nationalités distinctes — choix de la loi nationale d'un époux, à défaut loi du premier domicile commun.

Successions (art. 1043-1044 CPF) : principe de la loi nationale du défunt au moment du décès. Exception : si le défunt avait des liens manifestement plus étroits avec l'État de son domicile. Art. 1044 : possibilité de choisir la loi applicable (loi de l'État dont le défunt a la nationalité ou le domicile au moment du décès).$c$,
  '{"source":"cours","topic":"statut_personnel","subtopic":"alimentaires_regime_successions"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 240),

  (gen_random_uuid(), v_doc_id, 21,
$c$STATUT PERSONNEL — NOM ET CAPACITÉ

Le nom (art. 1020 CPF) : la détermination, la protection et le changement volontaire du nom sont régis par la loi nationale de l'intéressé. Le changement de nom consécutif à un changement d'état est régi par la loi gouvernant les effets de l'état nouveau, avec possibilité pour l'intéressé de demander l'application de sa loi nationale.

La capacité (art. 1017 CPF) : la capacité générale d'une personne physique est régie par sa loi nationale. Cette règle s'applique également lorsque la capacité d'exercice est élargie par le mariage. Domaine : incapacités générales d'exercice (causes, étendue, sanction) et émancipation par le mariage.

La nationalité : pas de conflit de lois en cette matière car chaque État dispose d'une compétence exclusive pour légiférer sur sa nationalité.

Le genre : nouvelle catégorie émergente en DIP liée à la réassignation sexuelle.$c$,
  '{"source":"cours","topic":"statut_personnel","subtopic":"nom_capacite"}'::jsonb, 'content', 'Droit International Privé', NULL, 'L3', 200);

END;
$$;
