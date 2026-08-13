import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/features/challenge/smart_whiteboard/models/storyboard_fusion.dart';

void main() {
  // Le JSON tel que l'Edge Function le produit, reduit a ce qui compte.
  Map<String, dynamic> brut() => {
        'engine': 'vision2',
        'theme': 'notebook',
        'scenes': [
          {
            'id': 'scene-001',
            'beat': 'hook',
            'narration': 'Resume de la scene un.',
            'blocks': [
              {
                'id': 'b1',
                'type': 'definition',
                'content': 'Le Marketing : Identifier et satisfaire.',
                'narration': 'Le marketing, c est l art d identifier...',
                'emphasis': 'circle',
                'emphasis_target': 'Identifier',
                'key_words': ['identifier', 'satisfaire'],
              },
            ],
          },
        ],
      };

  // Ce que `Storyboard.toJson()` sait re-emettre : les champs connus, pas plus.
  Map<String, dynamic> edite() => {
        'theme': 'notebook',
        'scenes': [
          {
            'id': 'scene-001',
            'blocks': [
              {
                'id': 'b1',
                'type': 'definition',
                'content': 'Le Marketing : Identifier et satisfaire. (corrige)',
              },
            ],
          },
        ],
      };

  test('le moteur survit a une edition', () {
    final f = fusionnerStoryboard(brut(), edite());
    expect(f['engine'], 'vision2',
        reason: "c'est sa disparition qui faisait retomber le serveur "
            'sur le moteur legacy, sans apercu ni sound design');
  });

  test('la narration et les annotations des blocs survivent', () {
    final f = fusionnerStoryboard(brut(), edite());
    final bloc = (f['scenes'] as List).first['blocks'][0] as Map;
    expect(bloc['narration'], 'Le marketing, c est l art d identifier...');
    expect(bloc['emphasis'], 'circle');
    expect(bloc['emphasis_target'], 'Identifier');
    expect(bloc['key_words'], ['identifier', 'satisfaire']);
  });

  test('la modification de l etudiant gagne', () {
    final f = fusionnerStoryboard(brut(), edite());
    final bloc = (f['scenes'] as List).first['blocks'][0] as Map;
    expect(bloc['content'], contains('(corrige)'));
  });

  test('le beat de scene survit', () {
    final f = fusionnerStoryboard(brut(), edite());
    expect((f['scenes'] as List).first['beat'], 'hook');
  });

  test('sans JSON d origine, on rend l edite tel quel', () {
    expect(fusionnerStoryboard(null, edite()), edite());
    expect(fusionnerStoryboard(<String, dynamic>{}, edite()), edite());
  });

  test('une scene reordonnee garde SES propres champs', () {
    final b = brut();
    (b['scenes'] as List).add({
      'id': 'scene-002',
      'beat': 'recap',
      'blocks': [
        {'id': 'b2', 'type': 'paragraph', 'content': 'Deux.',
         'narration': 'Narration deux.'}
      ],
    });
    // L'etudiant remonte la scene 2 en premier.
    final e = {
      'scenes': [
        {'id': 'scene-002', 'blocks': [
          {'id': 'b2', 'type': 'paragraph', 'content': 'Deux.'}]},
        {'id': 'scene-001', 'blocks': [
          {'id': 'b1', 'type': 'definition', 'content': 'Un.'}]},
      ],
    };
    final f = fusionnerStoryboard(b, e);
    final s = f['scenes'] as List;
    expect(s[0]['beat'], 'recap', reason: 'appariement par id, pas par rang');
    expect(s[0]['blocks'][0]['narration'], 'Narration deux.');
    expect(s[1]['beat'], 'hook');
    expect(s[1]['blocks'][0]['emphasis'], 'circle');
  });
}
