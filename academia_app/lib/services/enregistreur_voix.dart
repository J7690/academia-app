import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:record/record.dart';

/// Capte la voix et rend des octets WAV, **sur le web comme sur téléphone**.
///
/// ## Pourquoi ne pas réutiliser `CommunityAudioRecorder`
///
/// Il écrit dans `Directory.systemTemp` — donc `dart:io`, qui n'existe pas sur
/// le web. C'est pour cela qu'il possède un `_stub` web qui refuse simplement
/// d'enregistrer. Ici on passe par `startStream()`, qui rend un flux d'octets
/// sur toutes les plateformes : aucun fichier, aucun `dart:html`, aucune
/// importation conditionnelle.
///
/// ## Pourquoi du WAV
///
/// `startStream` ne produit que du PCM brut, sans en-tête — un moteur de
/// transcription le refuse, car rien ne lui dit la fréquence ni le nombre de
/// canaux. On ajoute donc les 44 octets d'en-tête WAV nous-mêmes. Le WAV est
/// aussi le seul format que `record` garantit sur **tous** les navigateurs.
///
/// ## Le poids, calculé et non subi
///
/// 16 kHz, mono, 16 bits = 32 ko par seconde. Une question de 30 secondes pèse
/// donc ~960 ko, loin des 25 Mo acceptés par l'Edge Function. 16 kHz est
/// exactement ce qu'attend Whisper : échantillonner plus haut alourdirait
/// l'envoi sans rien apporter à la reconnaissance.
class EnregistreurVoix {
  static const int _frequence = 16000;
  static const int _canaux = 1;
  static const int _bitsParEchantillon = 16;

  /// Au-delà, on arrête de soi-même : une question dictée dépasse rarement
  /// 30 secondes, et un micro resté ouvert par accident ne doit pas gonfler
  /// l'envoi indéfiniment.
  static const Duration dureeMax = Duration(seconds: 45);

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _abonnement;
  final List<int> _octets = <int>[];
  bool _enCours = false;
  Timer? _minuteur;

  bool get enCours => _enCours;

  /// Vrai si le micro est autorisé. Sur le web, cela déclenche la demande
  /// d'autorisation du navigateur.
  Future<bool> autorise() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('[ENREGISTREUR] autorisation refusée ou indisponible : $e');
      return false;
    }
  }

  /// Démarre la capture. Renvoie `false` si elle n'a pas pu commencer —
  /// l'appelant doit alors le dire à l'utilisateur plutôt que d'afficher un
  /// micro qui tourne dans le vide.
  Future<bool> demarrer({VoidCallback? surDureeMax}) async {
    if (_enCours) return true;
    _octets.clear();
    try {
      if (!await autorise()) {
        debugPrint('[ENREGISTREUR] micro non autorisé');
        return false;
      }
      final flux = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _frequence,
          numChannels: _canaux,
        ),
      );
      _abonnement = flux.listen(
        _octets.addAll,
        onError: (Object e) => debugPrint('[ENREGISTREUR] flux en erreur : $e'),
      );
      _enCours = true;
      _minuteur = Timer(dureeMax, () {
        debugPrint('[ENREGISTREUR] durée maximale atteinte, arrêt automatique');
        surDureeMax?.call();
      });
      return true;
    } catch (e) {
      debugPrint('[ENREGISTREUR] démarrage impossible : $e');
      _enCours = false;
      return false;
    }
  }

  /// Arrête la capture et rend un WAV complet, ou `null` si rien n'a été capté.
  Future<Uint8List?> arreter() async {
    _minuteur?.cancel();
    _minuteur = null;
    if (!_enCours) return null;
    _enCours = false;
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('[ENREGISTREUR] arrêt en erreur : $e');
    }
    await _abonnement?.cancel();
    _abonnement = null;

    if (_octets.isEmpty) {
      debugPrint('[ENREGISTREUR] aucun son capté');
      return null;
    }
    // Moins de 0,3 s : un appui involontaire, pas une question. On évite
    // d'envoyer au moteur un souffle qu'il transcrirait en mot au hasard.
    if (_octets.length < _frequence * 2 * 0.3) {
      debugPrint('[ENREGISTREUR] capture trop courte (${_octets.length} octets)');
      return null;
    }
    return _emballerEnWav(Uint8List.fromList(_octets));
  }

  Future<void> annuler() async {
    _minuteur?.cancel();
    _minuteur = null;
    _enCours = false;
    try {
      await _recorder.stop();
    } catch (_) {}
    await _abonnement?.cancel();
    _abonnement = null;
    _octets.clear();
  }

  Future<void> liberer() async {
    await annuler();
    await _recorder.dispose();
  }

  /// Ajoute l'en-tête WAV canonique (44 octets) devant le PCM brut.
  static Uint8List _emballerEnWav(Uint8List pcm) {
    const int tailleEntete = 44;
    const int octetsParSeconde = _frequence * _canaux * _bitsParEchantillon ~/ 8;
    const int alignementBloc = _canaux * _bitsParEchantillon ~/ 8;

    final sortie = Uint8List(tailleEntete + pcm.length);
    final vue = ByteData.view(sortie.buffer);

    void ecrireTexte(int position, String texte) {
      for (var i = 0; i < texte.length; i++) {
        sortie[position + i] = texte.codeUnitAt(i);
      }
    }

    ecrireTexte(0, 'RIFF');
    vue.setUint32(4, 36 + pcm.length, Endian.little); // taille totale - 8
    ecrireTexte(8, 'WAVE');
    ecrireTexte(12, 'fmt ');
    vue.setUint32(16, 16, Endian.little); // taille du bloc fmt
    vue.setUint16(20, 1, Endian.little); // 1 = PCM non compressé
    vue.setUint16(22, _canaux, Endian.little);
    vue.setUint32(24, _frequence, Endian.little);
    vue.setUint32(28, octetsParSeconde, Endian.little);
    vue.setUint16(32, alignementBloc, Endian.little);
    vue.setUint16(34, _bitsParEchantillon, Endian.little);
    ecrireTexte(36, 'data');
    vue.setUint32(40, pcm.length, Endian.little);

    sortie.setRange(tailleEntete, tailleEntete + pcm.length, pcm);
    return sortie;
  }
}

typedef VoidCallback = void Function();
