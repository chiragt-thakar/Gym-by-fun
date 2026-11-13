/// UI strings and voice cues in English, Hindi and Gujarati.
///
/// English is complete; Hindi and Gujarati cover the in-game voice cues and
/// key screens for the Ahmedabad pilot (full screens arrive in Stage 4).
enum AppLanguage {
  en('English', 'en-IN'),
  hi('हिंदी', 'hi-IN'),
  gu('ગુજરાતી', 'gu-IN');

  const AppLanguage(this.label, this.ttsLocale);
  final String label;
  final String ttsLocale;
}

class S {
  S(this.lang);
  final AppLanguage lang;

  String t(String key) =>
      _strings[key]?[lang] ?? _strings[key]?[AppLanguage.en] ?? key;

  static const Map<String, Map<AppLanguage, String>> _strings = {
    'app_name': {AppLanguage.en: 'Joynetic'},
    'tagline': {
      AppLanguage.en: 'Your body is the controller.',
      AppLanguage.hi: 'आपका शरीर ही कंट्रोलर है।',
      AppLanguage.gu: 'તમારું શરીર જ કંટ્રોલર છે.',
    },
    'choose_language': {
      AppLanguage.en: 'Choose your language',
      AppLanguage.hi: 'अपनी भाषा चुनें',
      AppLanguage.gu: 'તમારી ભાષા પસંદ કરો',
    },
    'continue': {
      AppLanguage.en: 'Continue',
      AppLanguage.hi: 'आगे बढ़ें',
      AppLanguage.gu: 'આગળ વધો',
    },
    'daily_quest': {
      AppLanguage.en: 'Daily Quest',
      AppLanguage.hi: 'डेली क्वेस्ट',
      AppLanguage.gu: 'ડેઇલી ક્વેસ્ટ',
    },
    'play': {
      AppLanguage.en: 'Play',
      AppLanguage.hi: 'खेलें',
      AppLanguage.gu: 'રમો',
    },
    'squat_hint': {
      AppLanguage.en: 'Squat to duck!',
      AppLanguage.hi: 'झुकने के लिए स्क्वाट करें!',
      AppLanguage.gu: 'નીચે નમવા સ્ક્વોટ કરો!',
    },
    'lean_hint': {
      AppLanguage.en: 'Lean to change lane!',
      AppLanguage.hi: 'लेन बदलने के लिए झुकें!',
      AppLanguage.gu: 'લેન બદલવા બાજુમાં નમો!',
    },
    'orb_hint': {
      AppLanguage.en: 'Raise your arms to grab energy!',
      AppLanguage.hi: 'ऊर्जा पकड़ने के लिए हाथ ऊपर करें!',
      AppLanguage.gu: 'ઊર્જા પકડવા હાથ ઉપર કરો!',
    },
    'gate_hint': {
      AppLanguage.en: 'Arms up to open the gate!',
      AppLanguage.hi: 'दरवाज़ा खोलने के लिए हाथ ऊपर!',
      AppLanguage.gu: 'દરવાજો ખોલવા હાથ ઉપર!',
    },
    'checkpoint': {
      AppLanguage.en: 'Checkpoint! A heart comes back.',
      AppLanguage.hi: 'चेकपॉइंट! एक दिल वापस मिला।',
      AppLanguage.gu: 'ચેકપોઇન્ટ! એક હૃદય પાછું મળ્યું.',
    },
    'step_back': {
      AppLanguage.en: 'Step back into the frame. The game waits for you.',
      AppLanguage.hi: 'फ्रेम में वापस आएं। गेम आपका इंतज़ार कर रहा है।',
      AppLanguage.gu: 'ફ્રેમમાં પાછા આવો. ગેમ તમારી રાહ જુએ છે.',
    },
    'too_far': {
      AppLanguage.en: 'Come a little closer.',
      AppLanguage.hi: 'थोड़ा पास आइए।',
      AppLanguage.gu: 'થોડા નજીક આવો.',
    },
    'too_close': {
      AppLanguage.en: 'Step back a little.',
      AppLanguage.hi: 'थोड़ा पीछे जाइए।',
      AppLanguage.gu: 'થોડા પાછળ જાઓ.',
    },
    'low_visibility': {
      AppLanguage.en:
          'I can\'t see you clearly. Add some light or move clutter away.',
      AppLanguage.hi: 'आप साफ़ नहीं दिख रहे। रोशनी बढ़ाएं।',
      AppLanguage.gu: 'તમે સ્પષ્ટ દેખાતા નથી. થોડો પ્રકાશ વધારો.',
    },
    'tracking_back': {
      AppLanguage.en: 'Got you! Back to the run.',
      AppLanguage.hi: 'मिल गए! चलिए आगे।',
      AppLanguage.gu: 'મળી ગયા! ચાલો આગળ.',
    },
    'frame_ok': {
      AppLanguage.en: 'Perfect, you are in the frame!',
      AppLanguage.hi: 'बढ़िया, आप फ्रेम में हैं!',
      AppLanguage.gu: 'સરસ, તમે ફ્રેમમાં છો!',
    },
    'frame_find_me': {
      AppLanguage.en: 'Step into the frame so I can see you.',
      AppLanguage.hi: 'फ्रेम में आइए ताकि मैं आपको देख सकूँ।',
      AppLanguage.gu: 'ફ્રેમમાં આવો જેથી હું તમને જોઈ શકું.',
    },
    'frame_step_back': {
      AppLanguage.en: 'Step back so your head and feet fit.',
      AppLanguage.hi: 'थोड़ा पीछे जाइए ताकि सिर से पैर तक दिखें।',
      AppLanguage.gu: 'થોડા પાછળ જાઓ જેથી માથાથી પગ સુધી દેખાઓ.',
    },
    'frame_step_closer': {
      AppLanguage.en: 'Come a little closer.',
      AppLanguage.hi: 'थोड़ा पास आइए।',
      AppLanguage.gu: 'થોડા નજીક આવો.',
    },
    'frame_move_left': {
      AppLanguage.en: 'Move a little to your left.',
      AppLanguage.hi: 'थोड़ा अपनी बाईं ओर जाइए।',
      AppLanguage.gu: 'થોડા તમારી ડાબી બાજુ ખસો.',
    },
    'frame_move_right': {
      AppLanguage.en: 'Move a little to your right.',
      AppLanguage.hi: 'थोड़ा अपनी दाईं ओर जाइए।',
      AppLanguage.gu: 'થોડા તમારી જમણી બાજુ ખસો.',
    },
    'frame_more_light': {
      AppLanguage.en: 'I cannot see you clearly. Add light in front of you.',
      AppLanguage.hi: 'आप साफ़ नहीं दिख रहे। सामने रोशनी बढ़ाएं।',
      AppLanguage.gu: 'તમે સ્પષ્ટ દેખાતા નથી. સામે પ્રકાશ વધારો.',
    },
    'setup_auto': {
      AppLanguage.en: 'Perfect! Hold still. Calibration starts in 3 seconds.',
      AppLanguage.hi: 'बढ़िया! स्थिर रहें। 3 सेकंड में कैलिब्रेशन शुरू होगा।',
      AppLanguage.gu: 'સરસ! સ્થિર રહો. 3 સેકન્ડમાં કેલિબ્રેશન શરૂ થશે.',
    },
    'cal_skip': {
      AppLanguage.en: 'No problem. We will use a gentle setting for that one.',
      AppLanguage.hi: 'कोई बात नहीं। इसके लिए हम हल्की सेटिंग रखेंगे।',
      AppLanguage.gu: 'કોઈ વાંધો નહીં. આ માટે અમે હળવી સેટિંગ રાખીશું.',
    },
    'cal_paused': {
      AppLanguage.en: 'Calibration waits. Get back into the frame.',
      AppLanguage.hi: 'कैलिब्रेशन रुका है। फ्रेम में वापस आइए।',
      AppLanguage.gu: 'કેલિબ્રેશન અટક્યું છે. ફ્રેમમાં પાછા આવો.',
    },
    'warmup': {
      AppLanguage.en: 'Warm-up',
      AppLanguage.hi: 'वार्म-अप',
      AppLanguage.gu: 'વોર્મ-અપ',
    },
    'cooldown': {
      AppLanguage.en: 'Cool-down',
      AppLanguage.hi: 'कूल-डाउन',
      AppLanguage.gu: 'કૂલ-ડાઉન',
    },
    'well_done': {
      AppLanguage.en: 'Well done!',
      AppLanguage.hi: 'शाबाश!',
      AppLanguage.gu: 'શાબાશ!',
    },
    'stop_if_hurts': {
      AppLanguage.en: 'Stop if anything hurts.',
      AppLanguage.hi: 'दर्द हो तो रुक जाएं।',
      AppLanguage.gu: 'દુખાવો થાય તો અટકી જાઓ.',
    },
    'video_never_leaves': {
      AppLanguage.en: 'The camera reads your body position on this phone. Video never leaves your phone and is never saved.',
      AppLanguage.hi: 'कैमरा इसी फ़ोन पर आपकी मुद्रा पढ़ता है। वीडियो कभी फ़ोन से बाहर नहीं जाता और सेव नहीं होता।',
      AppLanguage.gu: 'કેમેરા આ જ ફોન પર તમારી મુદ્રા વાંચે છે. વિડિયો ક્યારેય ફોનની બહાર જતો નથી અને સેવ થતો નથી.',
    },
    'not_medical': {
      AppLanguage.en:
          'Joynetic is a game for general fitness, not medical advice.',
      AppLanguage.hi:
          'Joynetic सामान्य फिटनेस के लिए एक गेम है, चिकित्सा सलाह नहीं।',
      AppLanguage.gu:
          'Joynetic સામાન્ય ફિટનેસ માટેની ગેમ છે, તબીબી સલાહ નથી.',
    },
  };
}
