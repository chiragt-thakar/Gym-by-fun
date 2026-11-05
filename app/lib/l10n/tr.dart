import 'strings.dart';

/// The language currently chosen in Settings. Updated by the settings
/// notifier; the app root rebuilds when it changes.
AppLanguage currentLanguage = AppLanguage.en;

/// Translates an English UI string into the current language. Strings with no
/// entry fall back to English. Keyed by the English text so screens stay
/// readable. Hindi and Gujarati should be reviewed by native speakers before
/// launch.
String tr(String en) {
  if (currentLanguage == AppLanguage.en) return en;
  final t = _t[en];
  if (t == null) return en;
  return currentLanguage == AppLanguage.hi ? t.$1 : t.$2;
}

const Map<String, (String, String)> _t = {
  // Onboarding
  'Continue': ('आगे बढ़ें', 'આગળ વધો'),
  'Before you play': ('खेलने से पहले', 'રમતા પહેલાં'),
  'MotionQuest is for adults aged 18 and over.': (
    'MotionQuest 18 वर्ष और उससे अधिक उम्र के वयस्कों के लिए है।',
    'MotionQuest 18 વર્ષ અને તેથી વધુ ઉંમરના પુખ્તો માટે છે.',
  ),
  'I am 18 or older': (
    'मेरी उम्र 18 या उससे अधिक है',
    'મારી ઉંમર 18 કે તેથી વધુ છે',
  ),
  'I am under 18': ('मेरी उम्र 18 से कम है', 'મારી ઉંમર 18 થી ઓછી છે'),
  'Sorry — MotionQuest is only for adults right now. Thanks for your interest!': (
    'माफ़ कीजिए — अभी MotionQuest केवल वयस्कों के लिए है। रुचि के लिए धन्यवाद!',
    'માફ કરશો — હાલમાં MotionQuest ફક્ત પુખ્તો માટે છે. રસ બતાવવા બદલ આભાર!',
  ),
  'Readiness check': ('तैयारी जाँच', 'તૈયારી તપાસ'),
  'A quick check before you move. Your answers stay on this screen and are not saved.':
      (
        'हिलने-डुलने से पहले एक छोटी जाँच। आपके जवाब इसी स्क्रीन पर रहते हैं और सेव नहीं होते।',
        'હલનચલન પહેલાં નાની તપાસ. તમારા જવાબો આ સ્ક્રીન પર જ રહે છે અને સેવ થતા નથી.',
      ),
  'Has a doctor ever said you have a heart condition or high blood pressure?': (
    'क्या किसी डॉक्टर ने कभी कहा है कि आपको हृदय रोग या हाई ब्लड प्रेशर है?',
    'શું કોઈ ડૉક્ટરે ક્યારેય કહ્યું છે કે તમને હૃદયની તકલીફ કે હાઈ બ્લડ પ્રેશર છે?',
  ),
  'Do you feel pain in your chest at rest or when you are active?': (
    'क्या आराम करते या सक्रिय रहते समय आपके सीने में दर्द होता है?',
    'શું આરામ કરતી વખતે કે સક્રિય હો ત્યારે તમારી છાતીમાં દુખાવો થાય છે?',
  ),
  'Do you lose balance because of dizziness, or have you fainted recently?': (
    'क्या चक्कर आने से आपका संतुलन बिगड़ता है, या हाल में आप बेहोश हुए हैं?',
    'શું ચક્કર આવવાથી તમારું સંતુલન બગડે છે, અથવા તાજેતરમાં તમે બેભાન થયા છો?',
  ),
  'Do you have a bone, joint or back problem that movement could make worse?': (
    'क्या आपको हड्डी, जोड़ या पीठ की कोई समस्या है जो हिलने-डुलने से बढ़ सकती है?',
    'શું તમને હાડકાં, સાંધા કે પીઠની કોઈ તકલીફ છે જે હલનચલનથી વધી શકે?',
  ),
  'Are you pregnant, or recovering from surgery or an injury?': (
    'क्या आप गर्भवती हैं, या किसी सर्जरी या चोट से उबर रहे हैं?',
    'શું તમે ગર્ભવતી છો, અથવા કોઈ સર્જરી કે ઈજામાંથી સાજા થઈ રહ્યા છો?',
  ),
  'No': ('नहीं', 'ના'),
  'Yes': ('हाँ', 'હા'),
  'Please talk to a doctor before playing. If you choose to play, keep low-impact mode on, move gently, and stop if anything hurts.':
      (
        'खेलने से पहले कृपया डॉक्टर से बात करें। अगर आप खेलें, तो लो-इम्पैक्ट मोड चालू रखें, धीरे चलें और दर्द हो तो रुक जाएं।',
        'રમતા પહેલાં કૃપા કરીને ડૉક્ટર સાથે વાત કરો. જો તમે રમો, તો લો-ઇમ્પેક્ટ મોડ ચાલુ રાખો, ધીમે હલો અને દુખાવો થાય તો અટકી જાઓ.',
      ),
  'I understand — continue gently': (
    'मैं समझता/समझती हूँ — धीरे से आगे बढ़ें',
    'હું સમજું છું — ધીમેથી આગળ વધો',
  ),
  // Sign-in
  'Sign in': ('साइन इन', 'સાઇન ઇન'),
  'Save your progress and join your gym crew.': (
    'अपनी प्रगति सेव करें और अपने जिम क्रू से जुड़ें।',
    'તમારી પ્રગતિ સેવ કરો અને તમારા જિમ ક્રૂમાં જોડાઓ.',
  ),
  'Mobile number': ('मोबाइल नंबर', 'મોબાઇલ નંબર'),
  '6-digit code': ('6 अंकों का कोड', '6 અંકનો કોડ'),
  'Send code': ('कोड भेजें', 'કોડ મોકલો'),
  'Verify': ('पुष्टि करें', 'ચકાસો'),
  'Play offline for now': ('अभी ऑफ़लाइन खेलें', 'હમણાં ઑફલાઇન રમો'),
  'That code is not right. Try again.': (
    'यह कोड सही नहीं है। फिर से कोशिश करें।',
    'આ કોડ સાચો નથી. ફરી પ્રયાસ કરો.',
  ),
  'The code expired. Ask for a new one.': (
    'कोड की समय-सीमा खत्म हो गई। नया कोड मंगाएं।',
    'કોડની મુદત પૂરી થઈ. નવો કોડ મંગાવો.',
  ),
  'Too many tries. Please wait a few minutes.': (
    'बहुत ज़्यादा कोशिशें। कृपया कुछ मिनट रुकें।',
    'ઘણા બધા પ્રયાસ. કૃપા કરી થોડી મિનિટ રાહ જુઓ.',
  ),
  'No connection. You can play offline and sign in later.': (
    'इंटरनेट नहीं है। आप ऑफ़लाइन खेल सकते हैं और बाद में साइन इन कर सकते हैं।',
    'ઇન્ટરનેટ નથી. તમે ઑફલાઇન રમી શકો અને પછી સાઇન ઇન કરી શકો.',
  ),
  // Setup
  'Set up your space': ('अपनी जगह तैयार करें', 'તમારી જગ્યા તૈયાર કરો'),
  'Prop the phone up in portrait against a wall or a bottle, front camera facing you.':
      (
        'फ़ोन को दीवार या बोतल के सहारे खड़ा रखें, सामने का कैमरा आपकी ओर।',
        'ફોનને દીવાલ કે બોટલના ટેકે ઊભો રાખો, આગળનો કેમેરા તમારી તરફ.',
      ),
  'Clear a 2 × 2 m space, away from furniture edges.': (
    'फ़र्नीचर से दूर 2 × 2 मीटर जगह खाली करें।',
    'ફર્નિચરથી દૂર 2 × 2 મીટર જગ્યા ખાલી કરો.',
  ),
  'Stand 2 – 2.5 m away so your whole body fits, head to feet.': (
    '2 – 2.5 मीटर दूर खड़े हों ताकि सिर से पैर तक पूरा शरीर दिखे।',
    '2 – 2.5 મીટર દૂર ઊભા રહો જેથી માથાથી પગ સુધી આખું શરીર દેખાય.',
  ),
  'Light in front of you works best; avoid a bright window behind you.': (
    'रोशनी आपके सामने हो तो सबसे अच्छा; पीछे तेज़ खिड़की न हो।',
    'પ્રકાશ તમારી સામે હોય તો શ્રેષ્ઠ; પાછળ તેજ બારી ન હોય.',
  ),
  'Allow camera and start': (
    'कैमरे की अनुमति दें और शुरू करें',
    'કેમેરાની મંજૂરી આપો અને શરૂ કરો',
  ),
  'Camera permission is needed to play. You can allow it in Android Settings → Apps → MotionQuest.':
      (
        'खेलने के लिए कैमरे की अनुमति चाहिए। Android सेटिंग्स → ऐप्स → MotionQuest में अनुमति दें।',
        'રમવા માટે કેમેરાની મંજૂરી જોઈએ. Android સેટિંગ્સ → ઍપ્સ → MotionQuest માં મંજૂરી આપો.',
      ),
  'Camera permission is needed to play.': (
    'खेलने के लिए कैमरे की अनुमति चाहिए।',
    'રમવા માટે કેમેરાની મંજૂરી જોઈએ.',
  ),
  'Great — hold still…': ('बढ़िया — स्थिर रहें…', 'સરસ — સ્થિર રહો…'),
  'Next: calibrate': ('आगे: कैलिब्रेट करें', 'આગળ: કેલિબ્રેટ કરો'),
  // Calibration
  'Stand tall and still': ('सीधे और स्थिर खड़े रहें', 'સીધા અને સ્થિર ઊભા રહો'),
  'Raise both arms above your head': (
    'दोनों हाथ सिर के ऊपर उठाएं',
    'બંને હાથ માથા ઉપર ઊંચા કરો',
  ),
  'Do two comfortable squats': (
    'दो आरामदायक स्क्वाट करें',
    'બે આરામદાયક સ્ક્વોટ કરો',
  ),
  'Lean to your left and hold': (
    'बाईं ओर झुकें और रुकें',
    'ડાબી બાજુ નમો અને રોકાઓ',
  ),
  'Lean to your right and hold': (
    'दाईं ओर झुकें और रुकें',
    'જમણી બાજુ નમો અને રોકાઓ',
  ),
  'All set!': ('सब तैयार!', 'બધું તૈયાર!'),
  'Make sure your whole body is in the frame.': (
    'ध्यान रखें कि पूरा शरीर फ्रेम में हो।',
    'ધ્યાન રાખો કે આખું શરીર ફ્રેમમાં હોય.',
  ),
  'Move only as far as feels comfortable. The game uses your range.': (
    'उतना ही हिलें जितना आरामदायक लगे। गेम आपकी सीमा का उपयोग करता है।',
    'જેટલું આરામદાયક લાગે તેટલું જ હલો. ગેમ તમારી મર્યાદા વાપરે છે.',
  ),
  // Warm-up / cool-down
  'March in place': ('एक जगह मार्च करें', 'એક જગ્યાએ માર્ચ કરો'),
  'March gently on the spot, swing your arms.': (
    'एक जगह धीरे-धीरे मार्च करें, हाथ हिलाएं।',
    'એક જગ્યાએ ધીમે માર્ચ કરો, હાથ હલાવો.',
  ),
  'Arm circles': ('हाथ घुमाना', 'હાથ ગોળ ફેરવો'),
  'Small arm circles, then bigger.': (
    'छोटे घेरे, फिर बड़े।',
    'નાના વર્તુળ, પછી મોટા.',
  ),
  'Side reaches': ('साइड रीच', 'બાજુ તરફ ખેંચાણ'),
  'Reach one arm over your head, then the other.': (
    'एक हाथ सिर के ऊपर ले जाएं, फिर दूसरा।',
    'એક હાથ માથા ઉપર લઈ જાઓ, પછી બીજો.',
  ),
  'Half squats': ('हाफ़ स्क्वाट', 'હાફ સ્ક્વોટ'),
  'Slow, gentle half squats. Knees over toes.': (
    'धीमे, हल्के हाफ़ स्क्वाट। घुटने पंजों के ऊपर।',
    'ધીમા, હળવા હાફ સ્ક્વોટ. ઘૂંટણ પંજા ઉપર.',
  ),
  'Shoulder rolls': ('कंधे घुमाना', 'ખભા ફેરવો'),
  'Roll your shoulders back and breathe.': (
    'कंधे पीछे घुमाएं और सांस लें।',
    'ખભા પાછળ ફેરવો અને શ્વાસ લો.',
  ),
  'Overhead stretch': ('ऊपर की ओर खिंचाव', 'ઉપર તરફ ખેંચાણ'),
  'Reach both arms up and breathe out slowly.': (
    'दोनों हाथ ऊपर करें और धीरे सांस छोड़ें।',
    'બંને હાથ ઉપર કરો અને ધીમે શ્વાસ છોડો.',
  ),
  'Side stretch left': ('बाईं ओर खिंचाव', 'ડાબી બાજુ ખેંચાણ'),
  'Lean gently to the left and hold.': (
    'धीरे से बाईं ओर झुकें और रुकें।',
    'ધીમેથી ડાબી બાજુ નમો અને રોકાઓ.',
  ),
  'Side stretch right': ('दाईं ओर खिंचाव', 'જમણી બાજુ ખેંચાણ'),
  'Lean gently to the right and hold.': (
    'धीरे से दाईं ओर झुकें और रुकें।',
    'ધીમેથી જમણી બાજુ નમો અને રોકાઓ.',
  ),
  'Calf stretch': ('पिंडली का खिंचाव', 'પિંડીનું ખેંચાણ'),
  'Hold a wall, step one foot back, heel down. Swap halfway.': (
    'दीवार पकड़ें, एक पैर पीछे, एड़ी नीचे। आधे में पैर बदलें।',
    'દીવાલ પકડો, એક પગ પાછળ, એડી નીચે. અડધે પગ બદલો.',
  ),
  'Deep breaths': ('गहरी सांसें', 'ઊંડા શ્વાસ'),
  'Breathe in for four, out for six. Great work.': (
    'चार तक सांस लें, छह तक छोड़ें। बहुत बढ़िया।',
    'ચાર સુધી શ્વાસ લો, છ સુધી છોડો. ખૂબ સરસ.',
  ),
  'Skip': ('छोड़ें', 'છોડો'),
  'Tutorial': ('ट्यूटोरियल', 'ટ્યુટોરિયલ'),
  // Results
  'Results': ('परिणाम', 'પરિણામ'),
  'You escaped the forest!': (
    'आप जंगल से बच निकले!',
    'તમે જંગલમાંથી બચી નીકળ્યા!',
  ),
  'Good effort — the forest will be there tomorrow.': (
    'अच्छी कोशिश — जंगल कल भी यहीं होगा।',
    'સારો પ્રયાસ — જંગલ કાલે પણ અહીં હશે.',
  ),
  'Score': ('स्कोर', 'સ્કોર'),
  'Moves done': ('मूव्स किए', 'કરેલી મૂવ્સ'),
  'Active min': ('सक्रिय मिनट', 'સક્રિય મિનિટ'),
  'Energy': ('ऊर्जा', 'ઊર્જા'),
  'Cleared': ('पार किए', 'પાર કર્યા'),
  'Hearts left': ('बचे दिल', 'બાકી હૃદય'),
  'How hard did that feel?': ('यह कितना कठिन लगा?', 'આ કેટલું અઘરું લાગ્યું?'),
  '1 = very easy · 5 = very hard': (
    '1 = बहुत आसान · 5 = बहुत कठिन',
    '1 = ખૂબ સરળ · 5 = ખૂબ અઘરું',
  ),
  'Done': ('हो गया', 'થઈ ગયું'),
  'Go to home': ('होम पर जाएं', 'હોમ પર જાઓ'),
  'Home': ('होम', 'હોમ'),
  'Something hurt': ('कुछ दर्द हुआ', 'કંઈક દુખ્યું'),
  'Where did it hurt?': ('दर्द कहाँ हुआ?', 'ક્યાં દુખ્યું?'),
  'Thank you for telling us': ('बताने के लिए धन्यवाद', 'જણાવવા બદલ આભાર'),
  // Home
  'Warm-up · Forest Escape · Cool-down': (
    'वार्म-अप · फ़ॉरेस्ट एस्केप · कूल-डाउन',
    'વોર્મ-અપ · ફોરેસ્ટ એસ્કેપ · કૂલ-ડાઉન',
  ),
  'Streak': ('लगातार दिन', 'સળંગ દિવસ'),
  'Shields': ('शील्ड', 'શીલ્ડ'),
  'Hero level': ('हीरो लेवल', 'હીરો લેવલ'),
  'Gym Crew': ('जिम क्रू', 'જિમ ક્રૂ'),
  'Have a gym code? Join your crew.': (
    'जिम कोड है? अपने क्रू से जुड़ें।',
    'જિમ કોડ છે? તમારા ક્રૂમાં જોડાઓ.',
  ),
  'Sign in to join your gym crew.': (
    'जिम क्रू से जुड़ने के लिए साइन इन करें।',
    'જિમ ક્રૂમાં જોડાવા સાઇન ઇન કરો.',
  ),
  'World map': ('विश्व मानचित्र', 'વિશ્વ નકશો'),
  'Coming soon': ('जल्द आ रहा है', 'ટૂંક સમયમાં'),
  'Squat · Lean · Raise arms': (
    'स्क्वाट · झुकना · हाथ ऊपर',
    'સ્ક્વોટ · નમવું · હાથ ઉપર',
  ),
  'Premium': ('प्रीमियम', 'પ્રીમિયમ'),
  'Premium via your gym': ('आपके जिम से प्रीमियम', 'તમારા જિમ તરફથી પ્રીમિયમ'),
  // Crew
  'Join your gym crew': ('अपने जिम क्रू से जुड़ें', 'તમારા જિમ ક્રૂમાં જોડાઓ'),
  'Members of partner gyms get Premium free.': (
    'पार्टनर जिम के सदस्यों को प्रीमियम मुफ़्त मिलता है।',
    'પાર્ટનર જિમના સભ્યોને પ્રીમિયમ મફત મળે છે.',
  ),
  'Gym code': ('जिम कोड', 'જિમ કોડ'),
  'Share my activity with my gym': (
    'मेरी गतिविधि मेरे जिम के साथ साझा करें',
    'મારી પ્રવૃત્તિ મારા જિમ સાથે શેર કરો',
  ),
  'Join crew': ('क्रू से जुड़ें', 'ક્રૂમાં જોડાઓ'),
  'Leave this gym': ('यह जिम छोड़ें', 'આ જિમ છોડો'),
  'Needs a connection.': ('इंटरनेट चाहिए।', 'ઇન્ટરનેટ જોઈએ.'),
  'No sessions yet this week. Be the first!': (
    'इस हफ़्ते अभी कोई सेशन नहीं। पहले बनें!',
    'આ અઠવાડિયે હજી કોઈ સેશન નથી. પહેલા બનો!',
  ),
  'This code is no longer active.': (
    'यह कोड अब सक्रिय नहीं है।',
    'આ કોડ હવે સક્રિય નથી.',
  ),
  'Leave your current gym first.': (
    'पहले अपना मौजूदा जिम छोड़ें।',
    'પહેલાં તમારું હાલનું જિમ છોડો.',
  ),
  'This code has reached its member limit. Ask your gym for a new one.': (
    'इस कोड की सदस्य सीमा पूरी हो गई है। अपने जिम से नया कोड मांगें।',
    'આ કોડની સભ્ય મર્યાદા પૂરી થઈ. તમારા જિમ પાસે નવો કોડ માંગો.',
  ),
  // Quest pause and checkpoint
  'Something went wrong.': ('कुछ गड़बड़ हो गई।', 'કંઈક ખોટું થયું.'),
  'The camera could not start. Please try again.': (
    'कैमरा शुरू नहीं हो सका। कृपया फिर से कोशिश करें।',
    'કૅમેરા શરૂ ન થઈ શક્યો. કૃપા કરીને ફરી પ્રયાસ કરો.',
  ),
  'Out of hearts': ('दिल खत्म हो गए', 'હૃદય પૂરા થઈ ગયા'),
  'Your checkpoint is saved.': (
    'आपका चेकपॉइंट सेव है।',
    'તમારો ચેકપોઇન્ટ સાચવેલ છે.',
  ),
  'Continue from checkpoint': (
    'चेकपॉइंट से जारी रखें',
    'ચેકપોઇન્ટથી ચાલુ રાખો',
  ),
  'Finish run': ('दौड़ समाप्त करें', 'દોડ પૂરી કરો'),
  'Paused': ('रुका हुआ', 'થોભાવેલ'),
  'Ready? Step back into view and tap Resume.': (
    'तैयार? कैमरे के सामने आएं और फिर से शुरू करें दबाएं।',
    'તૈયાર? કૅમેરા સામે આવો અને ફરી શરૂ કરો દબાવો.',
  ),
  'Resume': ('फिर से शुरू करें', 'ફરી શરૂ કરો'),
  'Quit (this run is not saved)': (
    'छोड़ें (यह दौड़ सेव नहीं होगी)',
    'છોડો (આ દોડ સાચવાશે નહીં)',
  ),
  'Pause': ('रोकें', 'થોભો'),
  // Stage info sheet and body diagram
  'Main focus': ('मुख्य ध्यान', 'મુખ્ય ધ્યાન'),
  'Also works': ('साथ में काम करता है', 'સાથે કામ કરે છે'),
  'Front thighs': ('जांघ का अगला हिस्सा', 'જાંઘનો આગળનો ભાગ'),
  'Glutes': ('कूल्हे की मांसपेशियाँ', 'નિતંબના સ્નાયુ'),
  'Back thighs': ('जांघ का पिछला हिस्सा', 'જાંઘનો પાછળનો ભાગ'),
  'Calves': ('पिंडलियाँ', 'પિંડી'),
  'Core': ('पेट और कमर (कोर)', 'પેટ અને કમર (કોર)'),
  'Side waist': ('कमर के किनारे', 'કમરની બાજુ'),
  'Shoulders': ('कंधे', 'ખભા'),
  'Upper back': ('ऊपरी पीठ', 'ઉપલી પીઠ'),
  'Arms': ('बाहें', 'હાથ'),
  'Outer hips': ('कूल्हे का बाहरी हिस्सा', 'નિતંબનો બહારનો ભાગ'),
  'Squat': ('स्क्वाट', 'સ્ક્વોટ'),
  'Side lean': ('बगल में झुकना', 'બાજુમાં ઝૂકવું'),
  'Overhead reach': ('हाथ ऊपर उठाना', 'હાથ ઉપર લંબાવવા'),
  'Light': ('हल्का', 'હળવું'),
  'Moderate': ('मध्यम', 'મધ્યમ'),
  'Intensity': ('तीव्रता', 'તીવ્રતા'),
  'World': ('दुनिया', 'દુનિયા'),
  'Free': ('मुफ़्त', 'મફત'),
  'Trains': ('किन हिस्सों पर काम', 'કયા ભાગો પર કામ'),
  'Moves': ('हरकतें', 'હલનચલન'),
  'Benefits': ('फ़ायदे', 'ફાયદા'),
  'Why it helps': ('यह क्यों मदद करता है', 'આ કેમ મદદ કરે છે'),
  'Play': ('खेलें', 'રમો'),
  'Regular muscle-strengthening and aerobic activity is part of general fitness guidance from:':
      (
        'नियमित मांसपेशी-मज़बूती और एरोबिक गतिविधि इनकी सामान्य फ़िटनेस सलाह का हिस्सा है:',
        'નિયમિત સ્નાયુ-મજબૂતી અને એરોબિક પ્રવૃત્તિ આની સામાન્ય ફિટનેસ સલાહનો ભાગ છે:',
      ),
  'General fitness information, not medical advice. Stop if anything hurts.': (
    'सामान्य फ़िटनेस जानकारी, चिकित्सा सलाह नहीं। कहीं दर्द हो तो रुक जाएँ।',
    'સામાન્ય ફિટનેસ માહિતી, તબીબી સલાહ નથી. ક્યાંય દુખે તો અટકી જાઓ.',
  ),
  'Body diagram style': ('शरीर चित्र की शैली', 'શરીર ચિત્રની શૈલી'),
  'Used on stage info. You choose; we never guess.': (
    'स्टेज जानकारी में दिखता है। आप चुनें; हम कभी अनुमान नहीं लगाते।',
    'સ્ટેજ માહિતીમાં દેખાય છે. તમે પસંદ કરો; અમે ક્યારેય અનુમાન લગાવતા નથી.',
  ),
  'Neutral': ('सामान्य', 'સામાન્ય'),
  'Female': ('महिला', 'સ્ત્રી'),
  'Male': ('पुरुष', 'પુરુષ'),
  // Stage benefits (general fitness information)
  'Gets you moving with easy, controlled squats.': (
    'आसान, नियंत्रित स्क्वाट से आपको चलने-फिरने में लगाता है।',
    'સરળ, નિયંત્રિત સ્ક્વોટથી તમને હલનચલન કરાવે છે.',
  ),
  'Practises leaning side to side with balance.': (
    'संतुलन के साथ दाएँ-बाएँ झुकने का अभ्यास कराता है।',
    'સંતુલન સાથે ડાબે-જમણે ઝૂકવાનો અભ્યાસ કરાવે છે.',
  ),
  'Adds active minutes to your week.': (
    'आपके हफ़्ते में सक्रिय मिनट जोड़ता है।',
    'તમારા અઠવાડિયામાં સક્રિય મિનિટ ઉમેરે છે.',
  ),
  'Builds leg strength with repeated squats.': (
    'बार-बार स्क्वाट से पैरों की ताकत बढ़ाता है।',
    'વારંવાર સ્ક્વોટથી પગની તાકાત વધારે છે.',
  ),
  'Side leans work the muscles along your waist.': (
    'बगल में झुकने से कमर के किनारे की मांसपेशियाँ काम करती हैं।',
    'બાજુએ ઝૂકવાથી કમરની બાજુના સ્નાયુઓ કામ કરે છે.',
  ),
  'Reaching up gently moves the shoulders.': (
    'हल्के से ऊपर पहुँचने से कंधे हिलते हैं।',
    'હળવેથી ઉપર પહોંચવાથી ખભા હલે છે.',
  ),
  'A longer mix of squats and leans for steady effort.': (
    'लगातार मेहनत के लिए स्क्वाट और झुकने का लंबा मेल।',
    'સતત મહેનત માટે સ્ક્વોટ અને ઝૂકવાનું લાંબું મિશ્રણ.',
  ),
  'Helps build muscular endurance in the legs.': (
    'पैरों में मांसपेशियों का दम-खम बढ़ाने में मदद करता है।',
    'પગમાં સ્નાયુઓની સહનશક્તિ વધારવામાં મદદ કરે છે.',
  ),
  'Counts toward weekly activity guidelines.': (
    'हफ़्ते की गतिविधि सलाह में गिना जाता है।',
    'અઠવાડિયાની પ્રવૃત્તિ સલાહમાં ગણાય છે.',
  ),
  'Side leans work the waist and outer hips.': (
    'बगल में झुकने से कमर और कूल्हों का बाहरी हिस्सा काम करता है।',
    'બાજુએ ઝૂકવાથી કમર અને થાપાનો બહારનો ભાગ કામ કરે છે.',
  ),
  'Squats keep the legs working between walls.': (
    'दीवारों के बीच स्क्वाट से पैर काम करते रहते हैं।',
    'દીવાલો વચ્ચે સ્ક્વોટથી પગ કામ કરતા રહે છે.',
  ),
  'Practises moving with control and balance.': (
    'नियंत्रण और संतुलन के साथ हिलने-डुलने का अभ्यास कराता है।',
    'નિયંત્રણ અને સંતુલન સાથે હલનચલનનો અભ્યાસ કરાવે છે.',
  ),
  'Wide leans and squats for a fuller workout.': (
    'पूरे वर्कआउट के लिए चौड़े झुकाव और स्क्वाट।',
    'પૂરા વર્કઆઉટ માટે પહોળા ઝુકાવ અને સ્ક્વોટ.',
  ),
  'Builds muscular endurance in legs and waist.': (
    'पैरों और कमर में मांसपेशियों का दम-खम बढ़ाता है।',
    'પગ અને કમરમાં સ્નાયુઓની સહનશક્તિ વધારે છે.',
  ),
  'Overhead reaches move the shoulders and arms.': (
    'सिर के ऊपर हाथ ले जाने से कंधे और बाँहें हिलती हैं।',
    'માથા ઉપર હાથ લઈ જવાથી ખભા અને હાથ હલે છે.',
  ),
  'Squats and leans keep the whole body involved.': (
    'स्क्वाट और झुकने से पूरा शरीर काम में लगा रहता है।',
    'સ્ક્વોટ અને ઝૂકવાથી આખું શરીર કામમાં રહે છે.',
  ),
  'Breaks up long periods of sitting.': (
    'लंबे समय तक बैठे रहने के बीच विराम देता है।',
    'લાંબો સમય બેસી રહેવામાં વિરામ આપે છે.',
  ),
  'A faster mix of reaches, squats and leans.': (
    'ऊपर पहुँचने, स्क्वाट और झुकने का तेज़ मेल।',
    'ઉપર પહોંચવા, સ્ક્વોટ અને ઝૂકવાનું ઝડપી મિશ્રણ.',
  ),
  'Raises your effort for steady aerobic activity.': (
    'लगातार एरोबिक गतिविधि के लिए आपकी मेहनत बढ़ाता है।',
    'સતત એરોબિક પ્રવૃત્તિ માટે તમારી મહેનત વધારે છે.',
  ),
  'Builds muscular endurance in legs and shoulders.': (
    'पैरों और कंधों में मांसपेशियों का दम-खम बढ़ाता है।',
    'પગ અને ખભામાં સ્નાયુઓની સહનશક્તિ વધારે છે.',
  ),
  'A gentle pace with plenty of overhead reaches.': (
    'धीमी रफ़्तार, जिसमें सिर के ऊपर कई बार हाथ ले जाना है।',
    'ધીમી ગતિ, જેમાં માથા ઉપર ઘણી વાર હાથ લઈ જવાના છે.',
  ),
  'Easy squats keep the legs active.': (
    'आसान स्क्वाट से पैर सक्रिय रहते हैं।',
    'સરળ સ્ક્વોટથી પગ સક્રિય રહે છે.',
  ),
  'A relaxed way to add movement to your day.': (
    'अपने दिन में हलचल जोड़ने का आरामदायक तरीका।',
    'તમારા દિવસમાં હલનચલન ઉમેરવાની આરામદાયક રીત.',
  ),
  'A steady mix of squats, leans and reaches.': (
    'स्क्वाट, झुकने और ऊपर पहुँचने का स्थिर मेल।',
    'સ્ક્વોટ, ઝૂકવા અને ઉપર પહોંચવાનું સ્થિર મિશ્રણ.',
  ),
  'Builds leg strength and muscular endurance.': (
    'पैरों की ताकत और मांसपेशियों का दम-खम बढ़ाता है।',
    'પગની તાકાત અને સ્નાયુઓની સહનશક્તિ વધારે છે.',
  ),
};
