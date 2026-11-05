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
};
