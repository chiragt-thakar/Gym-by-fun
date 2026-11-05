import 'package:game_director/game_director.dart';

import 'strings.dart';

/// Coach Kavi's lines in English, Hindi and Gujarati. The coach itself only
/// returns message keys and parameters; this file turns them into text.
/// Hindi and Gujarati should be reviewed by native speakers before launch.
/// Kavi gives game suggestions only — no health, fatigue or weight claims.
String coachText(AppLanguage lang, CoachMessage m) {
  var text = _t[m.key]?[lang] ?? _t[m.key]?[AppLanguage.en] ?? m.key;
  for (final e in m.params.entries) {
    final v = e.key == 'move' ? moveName(lang, '${e.value}') : '${e.value}';
    text = text.replaceAll('{${e.key}}', v);
  }
  return text;
}

String coachKey(AppLanguage lang, String key) =>
    coachText(lang, CoachMessage(key));

String moveName(AppLanguage lang, String move) =>
    _t['move_$move']?[lang] ?? _t['move_$move']?[AppLanguage.en] ?? move;

String difficultyName(AppLanguage lang, Difficulty d) =>
    coachKey(lang, 'level_${d.name}');

/// Why Kavi suggests a change, in one short line.
String reasonText(AppLanguage lang, CoachReason r) =>
    coachKey(lang, 'coach_reason_${r.name}');

const _en = AppLanguage.en, _hi = AppLanguage.hi, _gu = AppLanguage.gu;

const Map<String, Map<AppLanguage, String>> _t = {
  'coach_name': {_en: 'Coach Kavi', _hi: 'कोच कवि', _gu: 'કોચ કવિ'},
  'coach_try_level': {
    _en: 'Try {level}',
    _hi: '{level} आज़माएँ',
    _gu: '{level} અજમાવો',
  },
  'coach_try_assist': {
    _en: 'Turn on assist mode',
    _hi: 'असिस्ट मोड चालू करें',
    _gu: 'આસિસ્ટ મોડ ચાલુ કરો',
  },
  'coach_next_goal': {
    _en: 'Next goal',
    _hi: 'अगला लक्ष्य',
    _gu: 'આગલું લક્ષ્ય',
  },
  'coach_applied': {
    _en: 'Done — your next run uses this.',
    _hi: 'हो गया — अगली दौड़ में यही रहेगा।',
    _gu: 'થઈ ગયું — આગલી દોડમાં આ જ રહેશે.',
  },
  // Levels and moves
  'level_beginner': {_en: 'Beginner', _hi: 'शुरुआती', _gu: 'શરૂઆતી'},
  'level_intermediate': {_en: 'Intermediate', _hi: 'मध्यम', _gu: 'મધ્યમ'},
  'level_advanced': {_en: 'Advanced', _hi: 'उन्नत', _gu: 'અદ્યતન'},
  'move_squat': {_en: 'squats', _hi: 'स्क्वॉट', _gu: 'સ્ક્વોટ'},
  'move_leanLeft': {
    _en: 'left leans',
    _hi: 'बाईं ओर झुकना',
    _gu: 'ડાબે ઝૂકવું',
  },
  'move_leanRight': {
    _en: 'right leans',
    _hi: 'दाईं ओर झुकना',
    _gu: 'જમણે ઝૂકવું',
  },
  'move_raiseArms': {
    _en: 'arm raises',
    _hi: 'हाथ ऊपर उठाना',
    _gu: 'હાથ ઉપર ઉઠાવવા',
  },
  // Reasons
  'coach_reason_noHistory': {
    _en: 'Play a run and I will start suggesting.',
    _hi: 'एक दौड़ खेलिए, फिर मैं सुझाव दूँगा।',
    _gu: 'એક દોડ રમો, પછી હું સૂચન આપીશ.',
  },
  'coach_reason_steady': {
    _en: 'This level suits you right now.',
    _hi: 'अभी यह लेवल आपके लिए ठीक है।',
    _gu: 'હમણાં આ લેવલ તમારા માટે યોગ્ય છે.',
  },
  'coach_reason_readyToMoveUp': {
    _en: 'Two smooth runs in a row — ready for a new challenge?',
    _hi: 'लगातार दो बढ़िया दौड़ — नई चुनौती के लिए तैयार?',
    _gu: 'સતત બે સરસ દોડ — નવા પડકાર માટે તૈયાર?',
  },
  'coach_reason_atTop': {
    _en: 'You are on the top level and doing great.',
    _hi: 'आप सबसे ऊँचे लेवल पर हैं और बढ़िया कर रहे हैं।',
    _gu: 'તમે સૌથી ઊંચા લેવલ પર છો અને સરસ કરી રહ્યા છો.',
  },
  'coach_reason_runNotFinished': {
    _en: 'An easier setting may help you reach the finish.',
    _hi: 'आसान सेटिंग से आप फ़िनिश तक पहुँच सकते हैं।',
    _gu: 'સરળ સેટિંગથી તમે ફિનિશ સુધી પહોંચી શકો.',
  },
  'coach_reason_heartsLost': {
    _en: 'A few hearts slipped away — more warning time may help.',
    _hi: 'कुछ दिल छूट गए — ज़्यादा चेतावनी समय मदद कर सकता है।',
    _gu: 'થોડા દિલ છૂટી ગયા — વધુ ચેતવણી સમય મદદ કરી શકે.',
  },
  'coach_reason_feltHard': {
    _en: 'You said that felt hard — let\'s make the next one gentler.',
    _hi: 'आपने कहा यह कठिन लगा — अगली बार थोड़ा आसान करते हैं।',
    _gu: 'તમે કહ્યું આ અઘરું લાગ્યું — આગલી વાર થોડું સરળ કરીએ.',
  },
  // Recaps
  'coach_recap_best': {
    _en: 'New personal best: {score} points! Most of your moves were {move}.',
    _hi: 'नया व्यक्तिगत रिकॉर्ड: {score} अंक! सबसे ज़्यादा आपने {move} किए।',
    _gu: 'નવો વ્યક્તિગત રેકોર્ડ: {score} પોઇન્ટ! સૌથી વધુ તમે {move} કર્યા.',
  },
  'coach_recap_flawless': {
    _en: 'Not a single heart lost — {cleared} obstacles cleared!',
    _hi: 'एक भी दिल नहीं गया — {cleared} बाधाएँ पार!',
    _gu: 'એક પણ દિલ ન ગયું — {cleared} અવરોધો પાર!',
  },
  'coach_recap_finished': {
    _en: 'You made it to the end with {score} points. Nice run!',
    _hi: 'आप {score} अंकों के साथ अंत तक पहुँचे। बढ़िया दौड़!',
    _gu: 'તમે {score} પોઇન્ટ સાથે અંત સુધી પહોંચ્યા. સરસ દોડ!',
  },
  'coach_recap_effort': {
    _en: 'You cleared {cleared} obstacles. Every run teaches the path.',
    _hi: 'आपने {cleared} बाधाएँ पार कीं। हर दौड़ रास्ता सिखाती है।',
    _gu: 'તમે {cleared} અવરોધો પાર કર્યા. દરેક દોડ રસ્તો શીખવે છે.',
  },
  // Goals
  'coach_goal_finish': {
    _en: 'Reach the finish line.',
    _hi: 'फ़िनिश लाइन तक पहुँचें।',
    _gu: 'ફિનિશ લાઇન સુધી પહોંચો.',
  },
  'coach_goal_all_hearts': {
    _en: 'Finish with all {hearts} hearts.',
    _hi: 'सभी {hearts} दिलों के साथ पूरा करें।',
    _gu: 'બધા {hearts} દિલ સાથે પૂરું કરો.',
  },
  'coach_goal_score': {
    _en: 'Score {score} points.',
    _hi: '{score} अंक बनाएँ।',
    _gu: '{score} પોઇન્ટ મેળવો.',
  },
  // Form tips
  'coach_tip_squat_deeper': {
    _en: 'Sink a little deeper on squats — only as far as comfortable.',
    _hi: 'स्क्वॉट में थोड़ा और नीचे जाएँ — बस जितना आराम से हो सके।',
    _gu: 'સ્ક્વોટમાં થોડું વધુ નીચે જાઓ — ફક્ત આરામથી થાય એટલું.',
  },
  'coach_tip_squat_rise': {
    _en: 'Stand all the way up before the next squat.',
    _hi: 'अगले स्क्वॉट से पहले पूरा सीधा खड़े हों।',
    _gu: 'આગલા સ્ક્વોટ પહેલાં પૂરા સીધા ઊભા થાઓ.',
  },
  'coach_tip_lean_further': {
    _en: 'Lean a touch further to the side, keeping it comfortable.',
    _hi: 'थोड़ा और बगल में झुकें, आराम से।',
    _gu: 'થોડું વધુ બાજુએ ઝૂકો, આરામથી.',
  },
  'coach_tip_lean_centre': {
    _en: 'Return to centre before the next lean.',
    _hi: 'अगली बार झुकने से पहले बीच में लौटें।',
    _gu: 'આગલી વાર ઝૂકતા પહેલાં વચ્ચે પાછા આવો.',
  },
  'coach_tip_raise_higher': {
    _en: 'Lift your hands above your head for orbs and gates.',
    _hi: 'ऑर्ब और गेट के लिए हाथ सिर के ऊपर उठाएँ।',
    _gu: 'ઓર્બ અને ગેટ માટે હાથ માથા ઉપર ઉઠાવો.',
  },
  'coach_tip_raise_lower': {
    _en: 'Bring your arms down before the next raise.',
    _hi: 'अगली बार उठाने से पहले हाथ नीचे लाएँ।',
    _gu: 'આગલી વાર ઉઠાવતા પહેલાં હાથ નીચે લાવો.',
  },
  'coach_tip_camera': {
    _en:
        'I lost sight of you a few times — add light in front of you and '
        'step back so your whole body fits.',
    _hi:
        'कुछ बार आप दिखे नहीं — सामने रोशनी बढ़ाएँ और पीछे हटें ताकि पूरा '
        'शरीर दिखे।',
    _gu:
        'થોડી વાર તમે દેખાયા નહીં — સામે પ્રકાશ વધારો અને પાછળ ખસો જેથી '
        'આખું શરીર દેખાય.',
  },
  // Weekly balance
  'coach_balance_variety': {
    _en:
        '{percent}% of this week\'s moves were {move}. Try a different '
        'stage for some variety.',
    _hi:
        'इस हफ़्ते {percent}% मूव {move} थे। बदलाव के लिए दूसरा स्टेज आज़माएँ।',
    _gu: 'આ અઠવાડિયે {percent}% મૂવ {move} હતા. બદલાવ માટે બીજું સ્ટેજ અજમાવો.',
  },
  'coach_balance_lighter': {
    _en: 'Your last few runs felt hard. How about a lighter run today?',
    _hi: 'पिछली कुछ दौड़ कठिन लगीं। आज हल्की दौड़ कैसी रहेगी?',
    _gu: 'છેલ્લી થોડી દોડ અઘરી લાગી. આજે હળવી દોડ કેવી રહેશે?',
  },
};
