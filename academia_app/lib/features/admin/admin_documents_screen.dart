import 'package:flutter/material.dart';

import 'admin_brokerage_vouchers_screen.dart';
import 'admin_payment_receipts_screen.dart';

/// « Mes documents » — l'espace de l'administrateur, jumeau de celui de
/// l'étudiant.
///
/// LA DEMANDE, mot pour mot (Jocelyn, 10/09/2026) : « l'administrateur doit
/// être capable de pouvoir les télécharger et les recevoir dans ces documents
/// lui aussi, ainsi que l'étudiant. »
///
/// LES TROIS DOCUMENTS, ET POURQUOI ON LES SÉPARE. Ce sont trois pièces
/// distinctes, avec trois destinataires :
///
///   — LE REÇU DE COURTAGE prouve à l'étudiant ce qu'il a versé à Nexiom pour
///     que Nexiom négocie sa place ;
///   — LE REÇU DES AUTRES ACHATS couvre tout le reste : crédits, travaux
///     dirigés, abonnement, cours en ligne, place de marché ;
///   — LE BON DE COURTAGE prouve à l'ÉTABLISSEMENT que Nexiom a négocié pour
///     ce candidat. Il ne s'adresse pas à l'étudiant, il s'adresse à l'école.
///
/// Les mêler dans une seule liste ferait perdre cette distinction, qui est
/// justement celle que le guichet doit faire.
///
/// UN REGROUPEMENT, PAS UN ONGLET DE PLUS. Le tableau de bord en portait
/// trente ; « Reçus » et « Bons de courtage » y vivaient séparément. Ils sont
/// désormais deux volets d'un même onglet, et le compte descend à vingt-neuf.
/// Ajouter un trente-et-unième onglet pour un espace « Mes documents » aurait
/// éloigné encore ce que Jocelyn demande de rapprocher.
///
/// CE QUE CET ÉCRAN N'AJOUTE PAS. Aucune liste, aucun téléchargement, aucune
/// requête ne sont écrits ici : les deux écrans existants sont réutilisés tels
/// quels, le premier avec son filtre de motif. Un troisième écran de liste
/// aurait été un troisième endroit où corriger le prochain défaut.
class AdminDocumentsScreen extends StatelessWidget {
  const AdminDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  icon: Icon(Icons.receipt_long, size: 18),
                  text: 'Reçus de courtage',
                ),
                Tab(
                  icon: Icon(Icons.shopping_bag_outlined, size: 18),
                  text: 'Reçus des autres achats',
                ),
                Tab(
                  icon: Icon(Icons.qr_code_2, size: 18),
                  text: 'Bons de courtage',
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminPaymentReceiptsScreen(courtageSeulement: true),
                AdminPaymentReceiptsScreen(courtageSeulement: false),
                AdminBrokerageVouchersScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
