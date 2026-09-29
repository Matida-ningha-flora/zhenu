/// Passage du français à l'ordre de la LSF (glose).
///
/// La LSF n'est pas du français signé mot à mot. Les règles appliquées :
/// - le temps d'abord (HIER, DEMAIN…), puis le lieu, puis les personnes et
///   les objets ; l'action (le verbe) vient à la fin ;
/// - pas d'articles, de prépositions ni de verbe « être » ;
/// - les verbes à l'infinitif ; le passé est marqué par FINI après le verbe
///   (s'il n'y a pas déjà un repère de temps), le futur par FUTUR au début ;
/// - la négation (PAS, JAMAIS, RIEN…) après le verbe, avec un « non » de la
///   tête ;
/// - le mot interrogatif (QUOI, OÙ, QUAND…) à la fin, avec les sourcils
///   froncés ; une question fermée se signe sourcils levés ;
/// - les pronoms sont des pointages (vers soi, vers l'autre, sur le côté).
///
/// Ces règles couvrent les phrases courantes ; une phrase complexe reste
/// compréhensible mais peut différer de ce que ferait un interprète.
library;

/// Direction d'un pointage (pronom).
enum PointTarget { me, you, other, we, youPlural, them }

/// Expression du visage et de la tête qui accompagne la phrase.
enum LsfExpression { neutral, questionYesNo, questionWh, negation }

/// Un élément de la phrase en LSF.
class GlossUnit {
  /// Mot ou expression à signer (forme de base : « aller », « pomme de terre »).
  final String gloss;

  /// Pronom : pointage dans cette direction.
  final PointTarget? point;

  /// Expression de la phrase à laquelle appartient l'élément.
  final LsfExpression expression;

  /// La phrase est niée (hochement de tête « non » en plus de l'expression).
  final bool negated;

  const GlossUnit(this.gloss,
      {this.point,
      this.expression = LsfExpression.neutral,
      this.negated = false});

  GlossUnit withSentence(LsfExpression expression, bool negated) =>
      GlossUnit(gloss, point: point, expression: expression, negated: negated);

  @override
  String toString() => gloss.toUpperCase();
}

enum _Role { time, place, subject, other, verb, aspect, negation, question }

class _Item {
  final String gloss;
  final _Role role;
  final PointTarget? point;
  _Item(this.gloss, this.role, {this.point});
}

class LsfGrammar {
  LsfGrammar._();

  /// Transforme un texte français en suite d'éléments LSF.
  /// [known] indique si un signe existe pour un mot ou une expression
  /// (forme normalisée, minuscules sans accents).
  static List<GlossUnit> translate(
      String text, bool Function(String phrase) known) {
    final units = <GlossUnit>[];
    for (final sentence in _sentences(text)) {
      units.addAll(_sentence(sentence, known));
    }
    return units;
  }

  static List<String> _sentences(String text) {
    final out = <String>[];
    final buffer = StringBuffer();
    for (final char in text.split('')) {
      buffer.write(char);
      if ('.!?;\n'.contains(char)) {
        out.add(buffer.toString());
        buffer.clear();
      }
    }
    if (buffer.toString().trim().isNotEmpty) out.add(buffer.toString());
    return out.where((s) => s.trim().isNotEmpty).toList();
  }

  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[àâä]'), 'a')
      .replaceAll(RegExp(r'[îï]'), 'i')
      .replaceAll(RegExp(r'[ôö]'), 'o')
      .replaceAll(RegExp(r'[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  // --- Lexique ---------------------------------------------------------

  static const _pronouns = {
    'je': PointTarget.me,
    'me': PointTarget.me,
    'moi': PointTarget.me,
    'tu': PointTarget.you,
    'te': PointTarget.you,
    'toi': PointTarget.you,
    'il': PointTarget.other,
    'elle': PointTarget.other,
    'lui': PointTarget.other,
    'on': PointTarget.we,
    'nous': PointTarget.we,
    'vous': PointTarget.youPlural,
    'ils': PointTarget.them,
    'elles': PointTarget.them,
    'eux': PointTarget.them,
    'leur': PointTarget.them,
  };

  static const _possessives = {
    'mon': PointTarget.me,
    'ma': PointTarget.me,
    'mes': PointTarget.me,
    'ton': PointTarget.you,
    'ta': PointTarget.you,
    'tes': PointTarget.you,
    'son': PointTarget.other,
    'sa': PointTarget.other,
    'ses': PointTarget.other,
    'notre': PointTarget.we,
    'nos': PointTarget.we,
    'votre': PointTarget.youPlural,
    'vos': PointTarget.youPlural,
  };

  static const pointGloss = {
    PointTarget.me: 'moi',
    PointTarget.you: 'toi',
    PointTarget.other: 'lui',
    PointTarget.we: 'nous',
    PointTarget.youPlural: 'vous',
    PointTarget.them: 'eux',
  };

  static const _possessiveGloss = {
    PointTarget.me: 'mon',
    PointTarget.you: 'ton',
    PointTarget.other: 'son',
    PointTarget.we: 'notre',
    PointTarget.youPlural: 'votre',
    PointTarget.them: 'leur',
  };

  static const _dropped = {
    'le',
    'la',
    'les',
    'l',
    'un',
    'une',
    'des',
    'de',
    'du',
    'd',
    'a',
    'au',
    'aux',
    'en',
    'y',
    'se',
    's',
    'ce',
    'cet',
    'cette',
    'ces',
    'c',
    'et',
    'que',
    'qu',
    'ne',
    'n',
    'est-ce',
    'donc',
    'alors',
    'tres',
    'bien sur',
  };

  static const _placePrepositions = {'a', 'au', 'aux', 'dans', 'chez', 'en'};

  static const _time = {
    'hier',
    'demain',
    'aujourd hui',
    'maintenant',
    'ce soir',
    'ce matin',
    'cet apres-midi',
    'bientot',
    'plus tard',
    'avant-hier',
    'apres-demain',
    'tout a l heure',
    'tout de suite',
    'la semaine prochaine',
    'la semaine derniere',
    'l annee prochaine',
    'l annee derniere',
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
    'matin',
    'soir',
    'nuit',
    'midi',
    'semaine',
    'toujours',
    'souvent',
    'parfois',
    'deja',
    'avant',
    'apres',
    'tot',
    'tard',
  };

  static const _whWords = {
    'qui': 'qui',
    'quoi': 'quoi',
    'que': 'quoi',
    'ou': 'ou',
    'quand': 'quand',
    'comment': 'comment',
    'pourquoi': 'pourquoi',
    'combien': 'combien',
    'quel': 'quel',
    'quelle': 'quel',
    'quels': 'quel',
    'quelles': 'quel',
  };

  static const _negations = {
    'pas': 'pas',
    'jamais': 'jamais',
    'rien': 'rien',
    'personne': 'personne',
    'plus': 'plus',
    'aucun': 'aucun',
    'aucune': 'aucun',
  };

  /// Formule figées gardées telles quelles (salutations, politesse).
  static const _fixed = {
    'bonjour',
    'bonsoir',
    'salut',
    'merci',
    'au revoir',
    'a bientot',
    's il vous plait',
    's il te plait',
    'ca va',
    'oui',
    'non',
    'd accord',
    'pardon',
    'excusez-moi',
    'bienvenue',
    'bravo',
    'bonne nuit',
    'bon appetit',
    'felicitations',
    'desole',
    'desolee',
  };

  static const _etre = {
    'suis',
    'es',
    'est',
    'sommes',
    'etes',
    'sont',
    'etais',
    'etait',
    'etions',
    'etiez',
    'etaient',
    'ete',
    'serai',
    'seras',
    'sera',
    'serons',
    'serez',
    'seront',
    'serais',
    'serait',
    'etre',
    'soit',
    'sois',
  };

  static const _avoir = {
    'ai',
    'as',
    'a',
    'avons',
    'avez',
    'ont',
    'avais',
    'avait',
    'avions',
    'aviez',
    'avaient',
    'aurai',
    'auras',
    'aura',
    'aurons',
    'aurez',
    'auront',
    'eu',
    'avoir',
  };

  static const _aller = {'vais', 'vas', 'va', 'allons', 'allez', 'vont'};

  /// « J'ai faim » ➜ MOI FAIM : états exprimés sans le verbe avoir.
  static const _states = {
    'faim',
    'soif',
    'peur',
    'mal',
    'froid',
    'chaud',
    'sommeil',
    'raison',
    'tort',
    'honte',
    'envie',
    'besoin',
  };

  /// Formes irrégulières courantes ➜ infinitif.
  static const _irregular = {
    'fais': 'faire',
    'fait': 'faire',
    'faisons': 'faire',
    'faites': 'faire',
    'font': 'faire',
    'ferai': 'faire',
    'fera': 'faire',
    'faisais': 'faire',
    'veux': 'vouloir',
    'veut': 'vouloir',
    'voulons': 'vouloir',
    'voulez': 'vouloir',
    'veulent': 'vouloir',
    'voulu': 'vouloir',
    'voudrais': 'vouloir',
    'voudrait': 'vouloir',
    'peux': 'pouvoir',
    'peut': 'pouvoir',
    'pouvons': 'pouvoir',
    'pouvez': 'pouvoir',
    'peuvent': 'pouvoir',
    'pu': 'pouvoir',
    'pourrais': 'pouvoir',
    'pourrait': 'pouvoir',
    'dois': 'devoir',
    'doit': 'devoir',
    'devons': 'devoir',
    'devez': 'devoir',
    'doivent': 'devoir',
    'du': 'devoir',
    'sais': 'savoir',
    'sait': 'savoir',
    'savons': 'savoir',
    'savez': 'savoir',
    'savent': 'savoir',
    'su': 'savoir',
    'vais': 'aller',
    'vas': 'aller',
    'va': 'aller',
    'allons': 'aller',
    'allez': 'aller',
    'vont': 'aller',
    'alle': 'aller',
    'allee': 'aller',
    'irai': 'aller',
    'ira': 'aller',
    'viens': 'venir',
    'vient': 'venir',
    'venons': 'venir',
    'venez': 'venir',
    'viennent': 'venir',
    'venu': 'venir',
    'venue': 'venir',
    'viendrai': 'venir',
    'prends': 'prendre',
    'prend': 'prendre',
    'prenons': 'prendre',
    'prenez': 'prendre',
    'prennent': 'prendre',
    'pris': 'prendre',
    'comprends': 'comprendre',
    'comprend': 'comprendre',
    'comprenons': 'comprendre',
    'comprenez': 'comprendre',
    'comprennent': 'comprendre',
    'compris': 'comprendre',
    'apprends': 'apprendre',
    'apprend': 'apprendre',
    'appris': 'apprendre',
    'bois': 'boire',
    'boit': 'boire',
    'buvons': 'boire',
    'buvez': 'boire',
    'boivent': 'boire',
    'bu': 'boire',
    'dors': 'dormir',
    'dort': 'dormir',
    'dormons': 'dormir',
    'dormez': 'dormir',
    'dorment': 'dormir',
    'dormi': 'dormir',
    'pars': 'partir',
    'part': 'partir',
    'partons': 'partir',
    'partez': 'partir',
    'partent': 'partir',
    'parti': 'partir',
    'partie': 'partir',
    'sors': 'sortir',
    'sort': 'sortir',
    'sortons': 'sortir',
    'sorti': 'sortir',
    'vois': 'voir',
    'voit': 'voir',
    'voyons': 'voir',
    'voyez': 'voir',
    'voient': 'voir',
    'vu': 'voir',
    'verrai': 'voir',
    'dis': 'dire',
    'dit': 'dire',
    'disons': 'dire',
    'dites': 'dire',
    'disent': 'dire',
    'lis': 'lire',
    'lit': 'lire',
    'lisons': 'lire',
    'lisez': 'lire',
    'lu': 'lire',
    'ecris': 'ecrire',
    'ecrit': 'ecrire',
    'ecrivons': 'ecrire',
    'ecrivez': 'ecrire',
    'mets': 'mettre',
    'met': 'mettre',
    'mis': 'mettre',
    'connais': 'connaitre',
    'connait': 'connaitre',
    'connu': 'connaitre',
    'attends': 'attendre',
    'attend': 'attendre',
    'attendu': 'attendre',
    'entends': 'entendre',
    'entend': 'entendre',
    'entendu': 'entendre',
    'vends': 'vendre',
    'vend': 'vendre',
    'vendu': 'vendre',
    'reponds': 'repondre',
    'repond': 'repondre',
    'repondu': 'repondre',
    'finis': 'finir',
    'finit': 'finir',
    'finissons': 'finir',
    'fini': 'finir',
    'choisis': 'choisir',
    'choisit': 'choisir',
    'choisi': 'choisir',
    'ouvre': 'ouvrir',
    'ouvert': 'ouvrir',
    'appelle': 'appeler',
    'appelles': 'appeler',
    'appellent': 'appeler',
    'achete': 'acheter',
    'achetes': 'acheter',
    'mange': 'manger',
    'mangeons': 'manger',
    'habite': 'habiter',
    'aime': 'aimer',
    'nais': 'naitre',
    'ne': 'naitre',
    'nee': 'naitre',
    'meurs': 'mourir',
    'meurt': 'mourir',
    'mort': 'mourir',
    'vis': 'vivre',
    'vit': 'vivre',
    'vecu': 'vivre',
    'cours': 'courir',
    'court': 'courir',
    'couru': 'courir',
  };

  static const _regularEndings = [
    'erons',
    'eront',
    'erez',
    'erai',
    'eras',
    'era',
    'erais',
    'erait',
    'aient',
    'ions',
    'iez',
    'ais',
    'ait',
    'ons',
    'ez',
    'ent',
    'ees',
    'ee',
    'es',
    'e',
  ];

  static const _participleEndings = [
    'e',
    'ee',
    'es',
    'ees',
    'i',
    'ie',
    'is',
    'u',
    'ue',
    'us',
    'it',
    'te',
    'ert'
  ];

  /// Infinitif d'une forme conjuguée, s'il est connu (sinon `null`).
  static String? _verb(String word, bool Function(String) known) {
    final irregular = _irregular[word];
    if (irregular != null) return irregular;
    if (RegExp(r'(er|ir|re|oir)$').hasMatch(word) && known(word)) return word;
    for (final ending in _regularEndings) {
      if (word.length > ending.length + 1 && word.endsWith(ending)) {
        final stem = word.substring(0, word.length - ending.length);
        for (final suffix in ['er', 'ir', 're']) {
          if (known('$stem$suffix')) return '$stem$suffix';
        }
        // « mangeons » ➜ « manger », « commençons » ➜ « commencer ».
        if (stem.endsWith('ge') &&
            known('${stem.substring(0, stem.length - 1)}er')) {
          return '${stem.substring(0, stem.length - 1)}er';
        }
      }
    }
    // Participes en -i / -u des verbes du 2e et 3e groupe.
    if (word.endsWith('i') && known('${word}r')) return '${word}r';
    if (word.endsWith('is') &&
        known('${word.substring(0, word.length - 1)}r')) {
      return '${word.substring(0, word.length - 1)}r';
    }
    return null;
  }

  /// Verbe absent du dictionnaire mais conjugué après un pronom
  /// (« tu habites ») : infinitif du 1er groupe supposé.
  static String? _guessVerb(String word) {
    for (final ending in ['ons', 'ez', 'ent', 'es', 'e']) {
      if (word.length > ending.length + 2 && word.endsWith(ending)) {
        return '${word.substring(0, word.length - ending.length)}er';
      }
    }
    return null;
  }

  static bool _looksLikeParticiple(String word) =>
      _participleEndings.any((e) => word.endsWith(e)) ||
      _irregular.containsKey(word);

  static bool _isInfinitive(String word) =>
      RegExp(r'(er|ir|re|oir)$').hasMatch(word) && word.length > 3;

  /// Nom au pluriel ➜ singulier, si le singulier est connu.
  static String _singular(String word, bool Function(String) known) {
    if (known(word)) return word;
    if (word.length > 3 && (word.endsWith('s') || word.endsWith('x'))) {
      final single = word.substring(0, word.length - 1);
      if (known(single)) return single;
    }
    if (word.endsWith('aux') &&
        known('${word.substring(0, word.length - 3)}al')) {
      return '${word.substring(0, word.length - 3)}al';
    }
    return word;
  }

  // --- Phrase ----------------------------------------------------------

  static List<GlossUnit> _sentence(String raw, bool Function(String) known) {
    final lowered = raw.toLowerCase().replaceAll('’', "'").trim();
    var question = lowered.endsWith('?');
    // « Où » (lieu) ne doit pas être confondu avec « ou » (choix).
    final hasWhereAccent = lowered.contains('où');
    var text = _fold(lowered);
    if (text.contains('est-ce que') || text.contains('est ce que')) {
      question = true;
      text = text.replaceAll(RegExp(r"est[- ]ce qu'?e?"), ' ');
    }
    // Élisions : j' ➜ je, l' ➜ le, n' ➜ ne…
    text = text
        .replaceAllMapped(RegExp(r"\b(j|l|d|n|m|t|s|c|qu)'"),
            (m) => '${m[1] == 'qu' ? 'que' : '${m[1]}e'} ')
        .replaceAll(RegExp(r"-t-"), ' ')
        // Inversion « veux-tu » : question fermée.
        .replaceAllMapped(
            RegExp(r'(\w)-(je|tu|il|elle|on|nous|vous|ils|elles)\b'), (m) {
          question = true;
          return '${m[1]} ${m[2]}';
        })
        // Impératif : « donne-moi » ➜ « donne moi ».
        .replaceAllMapped(
            RegExp(r'(\w)-(moi|toi|lui|nous|vous|leur|le|la|les|en|y)\b'),
            (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp(r"[^a-z0-9\s'-]"), ' ')
        .replaceAll("'", ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // « aujourd hui » reste une expression.
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];

    final items = <_Item>[];
    var negated = false;
    var past = false;
    var future = false;
    var whQuestion = false;
    var sawNe = false;
    var i = 0;
    var afterVerb = false;

    String? phraseAt(int start, Set<String> set) {
      for (var size = 4; size >= 2; size--) {
        if (start + size > words.length) continue;
        final phrase = words.sublist(start, start + size).join(' ');
        if (set.contains(phrase)) return phrase;
      }
      return null;
    }

    String? knownPhraseAt(int start) {
      for (var size = 3; size >= 2; size--) {
        if (start + size > words.length) continue;
        final phrase = words.sublist(start, start + size).join(' ');
        if (known(phrase)) return phrase;
      }
      return null;
    }

    while (i < words.length) {
      final word = words[i];
      final next = i + 1 < words.length ? words[i + 1] : null;

      // Formules figées et expressions de temps sur plusieurs mots.
      final fixed = phraseAt(i, _fixed);
      if (fixed != null) {
        items.add(_Item(fixed, _Role.other));
        i += fixed.split(' ').length;
        continue;
      }
      final time = phraseAt(i, _time);
      if (time != null) {
        items.add(_Item(time, _Role.time));
        i += time.split(' ').length;
        continue;
      }
      // Expression connue du dictionnaire (« pomme de terre »).
      final phrase = knownPhraseAt(i);
      if (phrase != null) {
        items.add(_Item(phrase, _Role.other));
        i += phrase.split(' ').length;
        continue;
      }

      if (word == 'ne') {
        sawNe = true;
        i++;
        continue;
      }
      if (_negations.containsKey(word) &&
          (sawNe || word == 'pas' || word == 'jamais')) {
        negated = true;
        items.add(_Item(_negations[word]!, _Role.negation));
        i++;
        continue;
      }
      // Mot interrogatif (« ou » seulement s'il était écrit « où »).
      if (_whWords.containsKey(word) &&
          (word != 'ou' || hasWhereAccent) &&
          (word != 'que' || i == 0) &&
          (word != 'qui' || i == 0 || question)) {
        whQuestion = true;
        question = true;
        items.add(_Item(_whWords[word]!, _Role.question));
        i++;
        continue;
      }
      if (_fixed.contains(word)) {
        items.add(_Item(word, _Role.other));
        i++;
        continue;
      }
      if (_time.contains(word)) {
        items.add(_Item(word, _Role.time));
        i++;
        continue;
      }
      // « a » : verbe avoir (« il a faim », « Paul a mangé ») ou préposition.
      final avoirA = word == 'a' &&
          i > 0 &&
          next != null &&
          (_states.contains(next) ||
              {'un', 'une', 'des', 'du', 'de', 'beaucoup', 'besoin', 'deja'}
                  .contains(next) ||
              (_looksLikeParticiple(next) && _verb(next, known) != null));
      // Lieu : « à l'école », « chez le médecin », « dans la cuisine ».
      if (!avoirA && _placePrepositions.contains(word) && next != null) {
        var j = i + 1;
        while (j < words.length &&
            {
              'le',
              'la',
              'les',
              'l',
              'un',
              'une',
              'mon',
              'ma',
              'ta',
              'ton',
              'sa',
              'son'
            }.contains(words[j])) {
          j++;
        }
        if (j < words.length &&
            !_pronouns.containsKey(words[j]) &&
            _verb(words[j], known) == null &&
            !_isInfinitive(words[j]) &&
            !_dropped.contains(words[j])) {
          final place = knownPhraseAt(j) ?? words[j];
          items.add(_Item(_singular(place, known), _Role.place));
          i = j + place.split(' ').length;
          continue;
        }
        i++;
        continue;
      }
      final pronoun = _pronouns[word];
      if (pronoun != null) {
        // Sujet s'il précède le verbe, sinon complément.
        items.add(_Item(
            pointGloss[pronoun]!, afterVerb ? _Role.other : _Role.subject,
            point: pronoun));
        i++;
        continue;
      }
      final possessive = _possessives[word];
      if (possessive != null) {
        items.add(_Item(_possessiveGloss[possessive]!, _Role.other,
            point: possessive));
        i++;
        continue;
      }
      // Verbe être : absent en LSF (« je suis content » ➜ MOI CONTENT).
      if (_etre.contains(word)) {
        if (next != null &&
            _looksLikeParticiple(next) &&
            _verb(next, known) != null) {
          past = true; // passé composé avec être : « je suis allé »
        }
        i++;
        continue;
      }
      // Avoir : auxiliaire, état (« j'ai faim ») ou possession.
      if (_avoir.contains(word) && word != 'a' || avoirA) {
        final after = next == null ? null : _verb(next, known);
        if (after != null && _looksLikeParticiple(next!)) {
          past = true;
          i++;
          continue;
        }
        if (next != null && _states.contains(next)) {
          i++;
          continue;
        }
        items.add(_Item('avoir', _Role.verb));
        afterVerb = true;
        i++;
        continue;
      }
      // Futur proche : « je vais manger » ➜ FUTUR MOI MANGER.
      if (_aller.contains(word) && next != null && _isInfinitive(next)) {
        future = true;
        i++;
        continue;
      }
      if (_dropped.contains(word)) {
        i++;
        continue;
      }
      final previous = i > 0 ? words[i - 1] : null;
      final verb = _verb(word, known) ??
          (previous != null && _pronouns.containsKey(previous) ||
                  next != null && _pronouns.containsKey(next) && question
              ? _guessVerb(word)
              : null);
      if (verb != null) {
        if (RegExp(r'(erai|eras|era|erons|erez|eront)$').hasMatch(word)) {
          future = true;
        }
        if (RegExp(r'(ais|ait|aient)$').hasMatch(word) &&
            !word.endsWith('fait')) {
          past = true;
        }
        items.add(_Item(verb, _Role.verb));
        afterVerb = true;
        i++;
        continue;
      }
      items.add(_Item(_singular(word, known), _Role.other));
      i++;
    }

    // Une phrase sans verbe (salutation, mot isolé) garde son ordre.
    final hasVerb = items.any((it) => it.role == _Role.verb);
    List<_Item> ordered;
    if (!hasVerb) {
      ordered = [
        ...items.where((it) => it.role == _Role.time),
        ...items.where((it) =>
            it.role != _Role.time &&
            it.role != _Role.negation &&
            it.role != _Role.question),
        ...items.where((it) => it.role == _Role.negation),
        ...items.where((it) => it.role == _Role.question),
      ];
    } else {
      final hasTime = items.any((it) => it.role == _Role.time);
      ordered = [
        if (future && !hasTime) _Item('futur', _Role.time),
        ...items.where((it) => it.role == _Role.time),
        ...items.where((it) => it.role == _Role.place),
        ...items.where((it) => it.role == _Role.subject),
        ...items.where((it) => it.role == _Role.other),
        ...items.where((it) => it.role == _Role.verb),
        if (past && !hasTime) _Item('fini', _Role.aspect),
        ...items.where((it) => it.role == _Role.negation),
        ...items.where((it) => it.role == _Role.question),
      ];
    }

    final expression = whQuestion
        ? LsfExpression.questionWh
        : question
            ? LsfExpression.questionYesNo
            : negated
                ? LsfExpression.negation
                : LsfExpression.neutral;
    return [
      for (final it in ordered)
        GlossUnit(it.gloss,
            point: it.point, expression: expression, negated: negated)
    ];
  }
}
