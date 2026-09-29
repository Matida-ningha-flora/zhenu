import 'package:flutter_test/flutter_test.dart';
import 'package:zhendu_app/data/services/lsf_grammar.dart';

void main() {
  // Petit vocabulaire : ce que le dictionnaire / le serveur connaît.
  const vocabulary = {
    'manger',
    'aller',
    'ecole',
    'maison',
    'viande',
    'content',
    'faim',
    'habiter',
    'chien',
    'pomme de terre',
    'vouloir',
    'boire',
    'eau',
    'merci',
    'bonjour',
    'comprendre',
    'medecin',
    'travail',
    'venir',
  };
  bool known(String phrase) => vocabulary.contains(phrase);
  String lsf(String french) => LsfGrammar.translate(french, known).join(' ');

  test('le temps d’abord, le verbe à la fin', () {
    expect(lsf('Je vais à l’école demain.'), 'DEMAIN ECOLE MOI ALLER');
  });

  test('pas d’articles ni de verbe être', () {
    expect(lsf('Je suis content.'), 'MOI CONTENT');
    expect(lsf('J’ai faim'), 'MOI FAIM');
  });

  test('négation après le verbe, avec le « non » de la tête', () {
    final units = LsfGrammar.translate('Je ne mange pas de viande', known);
    expect(units.join(' '), 'MOI VIANDE MANGER PAS');
    expect(units.every((u) => u.negated), isTrue);
  });

  test('mot interrogatif à la fin, sourcils froncés', () {
    final units = LsfGrammar.translate('Où habites-tu ?', known);
    expect(units.join(' '), 'TOI HABITER OU');
    expect(units.first.expression, LsfExpression.questionWh);
  });

  test('question fermée : sourcils levés', () {
    final units = LsfGrammar.translate('Tu veux de l’eau ?', known);
    expect(units.join(' '), 'TOI EAU VOULOIR');
    expect(units.first.expression, LsfExpression.questionYesNo);
  });

  test('passé : FINI après le verbe, sauf repère de temps', () {
    expect(lsf('Il a mangé'), 'LUI MANGER FINI');
    expect(lsf('Hier, il a mangé'), 'HIER LUI MANGER');
  });

  test('futur proche', () {
    expect(lsf('Nous allons manger'), 'FUTUR NOUS MANGER');
  });

  test('les pronoms sont des pointages', () {
    final units = LsfGrammar.translate('Tu comprends ?', known);
    expect(units.first.point, PointTarget.you);
  });

  test('salutations gardées telles quelles', () {
    expect(lsf('Bonjour, merci !'), 'BONJOUR MERCI');
  });

  test('expression de plusieurs mots', () {
    expect(lsf('Je mange une pomme de terre'), 'MOI POMME DE TERRE MANGER');
  });
}
