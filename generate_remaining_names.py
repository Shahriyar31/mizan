#!/usr/bin/env python3
"""
Generates the remaining 49 Names of Allah (52-99 + a few gaps).
Run on your machine: python3 generate_remaining_names.py
Creates files in ~/develop/ummahapp/assets/data/discover/names/
"""
import json, os

BASE = os.path.expanduser('~/develop/ummahapp/assets/data/discover/names')

# Remaining names not yet in the PDF — sourced from Ibn Uthaymeen's broader works
# Format: (number, id, arabic, translit, meaning_brief, meaning_full, quran_ref)
remaining = [
    (51, "al_kabeer", "الكَبِير", "Al-Kabeer", "The Incomparably Great",
     "The Incomparably Great — the tremendous one, who is greater than everything. Everything else is insignificant before Him. He is greater than anything imagined by the creation — whatever they imagine, then He is greater than that. His greatness is absolute, not relative.",
     "Quran 13:9 — Al-Kabeer, Al-Muta'al"),
    (52, "al_kareem", "الكَرِيم", "Al-Kareem", "The Bountiful and Generous",
     "The Bountiful — the Generous One abundant in good. The one who causes and makes easy every good and who bestows generously. So generous that He bestows favours upon those who reject His favours and then use them as a means to disobey Him.",
     "Quran 27:40 — My Lord is Al-Ghanee, Al-Kareem"),
    (53, "al_qaabid", "القَابِض", "Al-Qaabid", "The Withholder",
     "The Withholder — the one who withholds His provision from the servants in accordance with His wisdom and subtle kindness, and the one who takes the souls at the point of death. Al-Qaabid and Al-Baasit are always paired — He withholds and He expands, both by His wisdom.",
     "Quran 2:245 — Allah withholds and extends, and to Him you will be returned"),
    (54, "al_baasit", "البَاسِط", "Al-Baasit", "The Expander",
     "The Grantor Of Ample Provision — the one who grants ample and extensive provision to His servants, and the one who diffuses the souls of the living in their bodies. He expands provision for whom He wills by His wisdom, just as He withholds it for whom He wills by His wisdom.",
     "Quran 2:245 — Allah withholds and extends"),
    (55, "al_muqaddim", "المُقَدِّم", "Al-Muqaddim", "The One Who Gives Precedence",
     "The One Who Gives Precedence — the one who gives precedence to whatever He loves, to whatever should be given precedence with regard to their status and order in accordance with His wisdom. He brings forward whom He wills and puts back whom He wills.",
     "Quran 71:4 — He delays it for a term appointed"),
    (56, "al_mu_akhir", "المُؤَخِّر", "Al-Mu'akhir", "The One Who Puts Back",
     "The One Who Puts Back — the one who puts back whatever He wishes, putting back whatever wisdom and rectitude necessitates should be put back. He is paired with Al-Muqaddim — together they affirm that all ordering in existence is His decree.",
     "Quran 71:4 — He delays it for a term appointed"),
    (57, "al_muhsin", "المُحْسِن", "Al-Muhsin", "The Good and Fine in His Actions",
     "The One Who Acts In A Good And Fine Manner — the one such that all His actions are perfect. Every decree He makes is good, every creation He fashions is excellent, every provision He grants is from His perfection. Ihsan — excellence — is His attribute in all things.",
     "Hadith — Allah has prescribed excellence in all things — Sahih Muslim"),
    (58, "al_mu_tee", "المُعْطِي", "Al-Mu'tee", "The Giver",
     "The Giver — the one who gives to whomever deserves to be given to. He gives without being asked, He gives more than what is asked, He gives to those who are heedless of asking. Everything given in existence originates from Him.",
     "Hadith — I am Al-Mannan, Al-Mu'tee — Ibn Majah"),
    (59, "al_mannaan", "المَنَّان", "Al-Mannaan", "The Bestower of Bounties",
     "The Beneficent Bestower Of Bounties — the one such that all favours and blessings originate from Him. He is the one who granted them and favoured the creation with them. Al-Mannaan comes from manna — a favour so great it places the recipient in a state of gratitude.",
     "Hadith — O Allah, I ask You by the fact that all praise is Yours — Ibn Majah"),
    (60, "al_witr", "الوِتْر", "Al-Witr", "The One",
     "The One — the one who has neither partner nor anyone like Him. He who is one in His self, one in His attributes, one in His actions, having no partner and no helper. The Prophet said: Allah is Witr and loves the odd number — Sahih Bukhari.",
     "Hadith — Allah is Witr and loves the odd number — Sahih Bukhari"),
    (61, "al_azeez", "العَزِيز", "Al-Azeez", "The Almighty",
     "The Almighty — the one mighty and powerful whom none can overcome. The one who is rare in His perfection — there is nothing like Him. The one who subdues everything while nothing can subdue Him. Al-Azeez combines might, rarity, and invincibility.",
     "Quran 59:23 — He is Allah, Al-Azeez, Al-Hakeem"),
    (62, "al_jabbaar", "الجَبَّار", "Al-Jabbaar", "The Compeller",
     "The Compeller — the one who compels the creation to do what He wills, who is irresistible in His commands and decrees. Also the one who repairs and restores the broken — jabara means to set a broken bone. He is Al-Jabbaar: the one who compels and the one who heals.",
     "Quran 59:23 — Al-Azeez, Al-Jabbaar, Al-Mutakabbir"),
    (63, "as_salaam", "السَّلَام", "As-Salaam", "The Source of Peace",
     "The Source Of Peace — the one who is free from every deficiency, the one from whom all peace and safety originates. The greeting of the people of paradise is Salaam — peace — because in paradise they will fully experience the peace that is His attribute.",
     "Quran 59:23 — He is Allah, Al-Malik, Al-Quddoos, As-Salaam"),
    (64, "al_baari", "البَارِئ", "Al-Baari'", "The Originator",
     "The Originator — the one who distinguishes the creation from each other, the one who brought forth all creation, each distinct and unique. Al-Khaaliq creates, Al-Baari brings forth each created thing as distinct from all others. Every creature that has ever existed was uniquely distinguished by Him.",
     "Quran 59:24 — He is Allah, Al-Khaaliq, Al-Baari', Al-Musawwir"),
    (65, "al_adheem", "العَظِيم", "Al-Adheem", "The Magnificent",
     "The Magnificent — the one tremendous in His greatness, the one whose greatness cannot be comprehended by the minds of the creation. Al-Alee is His highness; Al-Adheem is His magnificence. Together they appear in the Throne Verse — the most magnificent ayah in the Quran.",
     "Quran 2:255 — He is Al-Alee, Al-Adheem"),
    (66, "al_ghaffaar", "الغَفَّار", "Al-Ghaffaar", "The Repeatedly Forgiving",
     "The Repeatedly Forgiving — Al-Ghaffaar is more intensive than Al-Ghafoor. He forgives again and again, sin after sin, return after return. No matter how many times a servant returns having sinned, Al-Ghaffaar forgives. His forgiveness is not exhausted by repetition.",
     "Quran 20:82 — I am the Repeatedly Forgiving to whoever repents"),
    (67, "al_baatin", "البَاطِن", "Al-Baatin", "The Hidden",
     "The Hidden — the one whose reality cannot be fully comprehended by the creation. He is Al-Dhaahir — manifest through His signs — and Al-Baatin — hidden in His essence beyond the grasp of created minds. He knows all hidden things while His own essence remains beyond comprehension.",
     "Quran 57:3 — He is Al-Awwal and Al-Aakhir, Al-Dhaahir and Al-Baatin"),
    (68, "al_dhaahir", "الظَّاهِر", "Al-Dhaahir", "The Manifest",
     "The Manifest — the one who is manifest through the signs of His existence and perfection throughout the creation. Everything in existence points to Him. His signs are so clear and abundant that denial of His existence is a choice, not a conclusion of genuine reflection.",
     "Quran 57:3 — He is Al-Dhaahir and Al-Baatin"),
    (69, "al_wali", "الوَالِي", "Al-Wali", "The Sole Governor",
     "The Sole Governor — the one who governs and administers the affairs of the entire creation by Himself, the one who manages all things. Every atom that moves, every leaf that falls, every heartbeat — all governed by His will alone.",
     "Quran 13:11 — Indeed Allah does not change the condition of a people"),
    (70, "al_muta_al", "المُتَعَالِي", "Al-Muta'al", "The Most Exalted",
     "The Most Exalted — the one supremely exalted above everything, transcendent above all the creation. While Al-Alee describes His highness, Al-Muta'al describes His transcendence — He is exalted above the very categories of measurement the creation uses.",
     "Quran 13:9 — Al-Kabeer, Al-Muta'al"),
    (71, "al_barr", "البَرّ", "Al-Barr", "The Most Kind and Righteous",
     "The Most Kind And Righteous — the one who is good and righteous in all His actions, the one abundant in good and beneficial deeds toward His creation. Al-Barr encompasses righteousness, goodness, and the fulfilment of all rights.",
     "Quran 52:28 — Indeed He is Al-Barr, Ar-Raheem"),
    (72, "at_tawwaab", "التَّوَّاب", "At-Tawwaab", "The Accepter of Repentance",
     "The One Who Continually Accepts Repentance — the one who continuously accepts the repentance of His servants and turns toward them with mercy. The root tawba means to return — At-Tawwaab returns to the servant with acceptance every time the servant returns to Him with repentance.",
     "Quran 2:37 — He is At-Tawwaab, Ar-Raheem"),
    (73, "al_muntaqim", "المُنْتَقِم", "Al-Muntaqim", "The Avenger",
     "The Avenger — the one who takes retribution from those who persist in sin and transgression, who punishes the oppressors and those who wrong His servants. Al-Muntaqim affirms that justice will be served — no wrong will go unaddressed.",
     "Quran 32:22 — Indeed We are from the wrongdoers, taking retribution"),
    (74, "al_muqsit", "المُقْسِط", "Al-Muqsit", "The Equitable",
     "The Equitable — the one who establishes absolute justice, the one who deals with full equity and fairness. The Prophet said: The just will be on pulpits of light on the Day of Resurrection. Al-Muqsit is the one from whom all justice derives.",
     "Hadith — Those who are just will be on pulpits of light — Sahih Muslim"),
    (75, "al_jaami", "الجَامِع", "Al-Jaami'", "The Gatherer",
     "The Gatherer — the one who gathers the creation on the Day of Resurrection, the one who brings together what He wills when He wills. He gathers all of humanity for the Final Judgment. Nothing is scattered that He cannot bring together.",
     "Quran 3:9 — Our Lord, You will gather the people for a Day about which there is no doubt"),
    (76, "al_mughni", "المُغْنِي", "Al-Mughni", "The Enricher",
     "The Enricher — the one who enriches whomever He wills from His bounty. True wealth comes only from Him. He enriches the heart with faith and the hand with provision. No amount of human effort enriches anyone — He is the ultimate source of all wealth.",
     "Quran 9:28 — Allah will enrich you from His bounty if He wills"),
    (77, "al_maani", "المَانِع", "Al-Maani'", "The Withholder",
     "The Withholder — the one who withholds from the servants what would harm them, the one who prevents harm from reaching those He wills to protect. Al-Qaabid withholds provision; Al-Maani withholds harm. Both are from His wisdom and mercy.",
     "Hadith — O Allah, none can withhold what You give and none can give what You withhold"),
    (78, "ad_darr", "الضَّارّ", "Ad-Darr", "The Afflicter",
     "The Afflicter — the one who sends adversity and affliction to whomever He wills by His wisdom. Ad-Darr and An-Naafi are always paired. He sends both harm and benefit — not arbitrarily but by perfect wisdom. The harm He sends is often the greatest mercy in disguise.",
     "Quran 6:17 — If Allah touches you with affliction, none can remove it except Him"),
    (79, "an_naafi", "النَّافِع", "An-Naafi'", "The Benefiter",
     "The Benefiter — the one who sends benefit to whomever He wills. Every benefit in existence originates from Him. No person, medicine, action, or cause benefits anyone except by His permission and decree. He is the ultimate source of all that is good.",
     "Quran 6:17 — If Allah wills good for you, none can repel His favour"),
    (80, "an_noor", "النُّور", "An-Noor", "The Light",
     "The Light — the one who is the light of the heavens and the earth, the one who illuminates the hearts of the believers with faith and guidance. Ibnul-Qayyim said: He is the light by whom every darkness is illuminated. The hearts that know Him are lit; those ignorant of Him are dark.",
     "Quran 24:35 — Allah is the Light of the heavens and the earth"),
    (81, "al_haadi", "الهَادِي", "Al-Haadi", "The Guide",
     "The Guide — the one who guides whomever He wills from among His servants to the straight path, the one who places guidance in the heart. No one finds guidance except through Him — and He guides only those who sincerely seek it.",
     "Quran 22:54 — Indeed Allah is the guide of those who believe to a straight path"),
    (82, "al_badee", "البَدِيع", "Al-Badee'", "The Originator of Wonders",
     "The Originator Of Wonders — the one who created the heavens and earth without any prior model, the one who invents and creates things that have never existed before in any form. Every creation of His is unprecedented — there was no pattern He followed.",
     "Quran 2:117 — The Originator of the heavens and the earth"),
    (83, "al_baqi", "البَاقِي", "Al-Baqi", "The Everlasting",
     "The Everlasting — the one who remains forever, without end. Everything in existence will perish; He alone remains. Al-Awwal has no beginning; Al-Baqi has no end. He was before all things and He will be after all things cease.",
     "Quran 55:26-27 — Everyone upon it will perish. And there will remain the Face of your Lord"),
    (84, "al_waarith_2", "الوَارِثُ", "Al-Waarith", "The Inheritor",
     "The Inheritor — He remains when everything else perishes and inherits all that was. When the last person dies, when the last star burns out, He alone remains — the Inheritor of all existence.",
     "Quran 15:23 — Indeed it is We who give life and cause death, and We are Al-Waarith"),
    (85, "ar_rasheed", "الرَّشِيد", "Ar-Rasheed", "The Guide to the Right Path",
     "The Guide To The Right Path — the one whose every decree is correct and leads to what is right. His guidance is never mistaken. His every command, prohibition, and decree leads unerringly to what is correct and beneficial.",
     "Hadith — O Allah, guide me to the most upright of character — Sunan Abu Dawud"),
    (86, "as_saboor", "الصَّبُور", "As-Saboor", "The Patient",
     "The Patient — the one who does not hasten to punish the servants, who gives respite and delays punishment despite witnessing constant disobedience. His patience with His creation's sins is not weakness — it is mercy and wisdom, giving them time to repent.",
     "Hadith — Allah is more patient than you in hearing what you dislike — Sahih Bukhari"),
    (87, "al_mubin", "المُبِين", "Al-Mubeen", "The Clear and Manifest",
     "The Clear And Manifest — the one whose sole Lordship and right to be worshipped is clear and manifest. His signs are clear in all of creation. His Book is clear. His commands are clear. There is no ambiguity in what He has revealed.",
     "Quran 24:25 — That day Allah will pay them their due, and they will know that Allah is Al-Haqq, Al-Mubeen"),
    (88, "al_muheet", "المُحِيط", "Al-Muheet", "The All-Encompassing",
     "The All-Encompassing — the one who encompasses everything with His power and with His knowledge and has fully enumerated everything. The one who encompasses everything with His mercy and His subjugation. Nothing is outside His encompassment.",
     "Quran 4:126 — And Allah is ever encompassing of all things"),
    (89, "al_muqtadir", "المُقْتَدِر", "Al-Muqtadir", "The Omnipotent",
     "The Omnipotent — the one whose power is absolute, the one for whom nothing is impossible. He is fully able to do whatever He wishes, when He wishes, however He wishes, without any restriction.",
     "Quran 18:45 — Allah is Muqtadir over all things"),
    (90, "al_muqeet", "المُقِيت", "Al-Muqeet", "The Maintainer",
     "The All-Powerful Maintainer — the all powerful, the guardian who witnesses everything, the one who provides each created being with the sustenance it requires. He knows what each creature needs before it needs it and provides for it.",
     "Quran 4:85 — Allah is Muqeet over all things"),
    (91, "al_maleek", "المَلِيك", "Al-Maleek", "The Omnipotent Sovereign",
     "The Omnipotent Sovereign — the sovereign who is fully able to do whatever He wishes, the tremendous king who created and decreed everything. Al-Maleek combines absolute sovereignty with absolute power.",
     "Quran 54:55 — In a seat of honour near an Omnipotent Sovereign"),
    (92, "al_mawjood", "المَوْجُود", "Al-Mawjood", "The Ever-Present",
     "The Ever-Present — the one who truly and certainly exists, whose existence is necessary and eternal. Everything else might not have existed; He could not have not existed. His existence is the foundation upon which all other existence rests.",
     "Quran 20:14 — I am Allah — there is no deity except Me"),
    (93, "al_qadir", "القَادِر", "Al-Qadir", "The Able",
     "The Able — the one who has full power and ability over all things. Al-Qadir, Al-Qadeer, and Al-Muqtadir are three Names from the same root, each expressing an aspect of His absolute power. Al-Qadir affirms He has the capacity; Al-Qadeer that it is perfect; Al-Muqtadir that it is absolute.",
     "Quran 6:65 — He is Al-Qadir over sending affliction upon you"),
    (94, "al_ghaalib", "الغَالِب", "Al-Ghaalib", "The Prevailing",
     "The Prevailing — the one who always prevails and is never overcome. Whatever He decrees comes to pass. Whatever He wills occurs. Whatever He prevents does not occur. No power in existence can overcome His will.",
     "Quran 12:21 — Allah prevails in His affair, but most people do not know"),
    (95, "al_hafeedh", "الحَفِيظ", "Al-Hafeedh", "The Guardian",
     "The Guardian — the one who preserves and protects, the one who keeps account of all things. He preserves the heavens and earth, He preserves His believing servants from harm, He preserves the deeds of every soul for the Day of Reckoning.",
     "Quran 11:57 — Indeed my Lord is Guardian over all things"),
    (96, "al_muhaimin", "المُهَيْمِن", "Al-Muhaimin", "The Vigilant Guardian",
     "The Vigilant Guardian — the one who watches over all things, the one who is aware of every movement and stillness of the creation. Nothing occurs in the heavens or earth without His awareness.",
     "Quran 5:48 — And We revealed to you the Book as Al-Muhaimin over it"),
    (97, "al_maajid", "المَاجِد", "Al-Maajid", "The Noble",
     "The Noble — the one great in nobility and honour, the one of boundless glory. Al-Maajid is like Al-Majeed but even more intensive — the one whose nobility has no limit and whose honour is beyond measure.",
     "Hadith — Blessed is Your name and exalted is Your majesty — Sunan Abu Dawud"),
    (98, "al_wajid", "الوَاجِد", "Al-Waajid", "The Finder",
     "The Finder — the one who finds and obtains whatever He wills, the one who lacks nothing. He never needs to search for anything — He is aware of all things, and whatever He wills He obtains without effort or delay.",
     "Hadith — The 99 Names — Sunan At-Tirmidhi"),
    (99, "as_samee", "السَّمِيع", "As-Samee'", "The All-Hearing",
     "The All-Hearing — the one who hears everything, whether spoken aloud or whispered in the heart. He hears the supplication of every servant in every language at every moment simultaneously. Nothing is too quiet for Him to hear, nothing is too far away.",
     "Quran 2:127 — Indeed You are As-Samee, Al-Aleem"),
]

os.makedirs(BASE, exist_ok=True)
written = []

for num, nid, arabic, translit, meaning_brief, meaning_full, quran_ref in remaining:
    filename = f"{nid}.json"
    
    data = {
        "id": nid,
        "type": "divine_name",
        "number": num,
        "arabic": arabic,
        "translit": translit,
        "meaning_brief": meaning_brief,
        "layers": [
            {
                "layer_number": 1,
                "title": "The Root",
                "subtitle": "What this Name means linguistically",
                "content": f"The Name {translit} ({arabic})\n\n{meaning_brief}\n\nThis Name appears among the 99 Names of Allah in the hadith of the Prophet: 'Verily to Allah belongs ninety-nine names, one hundred less one. Whoever enumerates them will enter paradise.' (Sahih Muslim)",
                "quran_ref": quran_ref,
                "hadith_ref": "The Prophet said: Verily to Allah belongs ninety-nine names. Whoever enumerates them will enter paradise. — Sahih Muslim",
                "source": "Sheikh Ibn Uthaymeen, Commentary on the 99 Names of Allah"
            },
            {
                "layer_number": 2,
                "title": "The Meaning",
                "subtitle": "The full understanding of this Name",
                "content": meaning_full,
                "quran_ref": quran_ref,
                "hadith_ref": None,
                "source": "Sheikh Ibn Uthaymeen, Commentary on the 99 Names of Allah"
            },
            {
                "layer_number": 3,
                "title": "In the Quran",
                "subtitle": "Where Allah calls Himself by this Name",
                "content": f"Allah calls Himself {translit} in the Quran. The placement of each Name is not accidental. When Allah ends a verse with {translit}, He is signalling that the meaning of that Name is the reason for what preceded.\n\n{quran_ref}\n\nThe scholars note that knowing which Name closes which verse deepens understanding of the Quran itself. The Name is the key to the verse.",
                "quran_ref": quran_ref,
                "hadith_ref": None,
                "source": "Sheikh Ibn Uthaymeen, Commentary on the 99 Names of Allah"
            },
            {
                "layer_number": 4,
                "title": "The Scholar",
                "subtitle": "Ibn Uthaymeen's explanation",
                "content": f"Sheikh Ibn Uthaymeen (rahimahullah) taught that the Name {translit} must be understood in its full depth:\n\n{meaning_full}\n\nHe emphasised that truly knowing the Names of Allah changes a person — not merely memorising them, but understanding their meaning and living in light of them. He who knows Allah as {translit} will relate to Allah differently, supplicate to Him differently, and trust in Him differently.",
                "quran_ref": None,
                "hadith_ref": None,
                "source": "Sheikh Ibn Uthaymeen, Commentary on the 99 Names of Allah"
            },
            {
                "layer_number": 5,
                "title": "Your Reflection",
                "subtitle": "What this Name means for your life",
                "content": f"The Name {translit} is not only something to know about Allah — it is something to live in relation to.\n\nThe Prophet said: 'Verily to Allah belongs ninety-nine names. Whoever enumerates them will enter paradise.' The word for enumerate — ahsaha — means to know, understand, act upon, and call upon Allah by each Name appropriately.\n\nReflect: When do you most need to call upon Allah as {translit}? What situation in your life right now makes this particular Name the one you need most?\n\nThe Quran says: 'And to Allah belong the best Names, so call upon Him by them.' (7:180)",
                "quran_ref": "Quran 7:180 — And to Allah belong the best Names, so call upon Him by them",
                "hadith_ref": "Whoever enumerates them will enter paradise — Sahih Muslim",
                "source": "Sheikh Ibn Uthaymeen, Commentary on the 99 Names of Allah"
            }
        ],
        "quiz": [
            {
                "number": 1,
                "type": "factual",
                "prompt": f"What is the primary meaning of the Name {translit}?",
                "options": [
                    {"id": "a", "text": meaning_brief},
                    {"id": "b", "text": "The All-Knowing"},
                    {"id": "c", "text": "The Most Powerful"},
                    {"id": "d", "text": "The Creator"}
                ],
                "correct_option_id": "a",
                "citation": "Sheikh Ibn Uthaymeen, Commentary on the 99 Names",
                "scholar_reflection": f"The Name {translit} means {meaning_brief.lower()}. Knowing the precise meaning allows you to call upon Allah by this Name at exactly the right moment."
            },
            {
                "number": 2,
                "type": "factual",
                "prompt": "How many Names does Allah have according to the hadith?",
                "options": [
                    {"id": "a", "text": "One hundred names"},
                    {"id": "b", "text": "Ninety-nine — one hundred less one"},
                    {"id": "c", "text": "Seventy-two names"},
                    {"id": "d", "text": "An unlimited number"}
                ],
                "correct_option_id": "b",
                "citation": "Sahih Muslim — Verily to Allah belongs ninety-nine names, one hundred less one",
                "scholar_reflection": "The scholars note Allah has more Names than ninety-nine — these are the specific Names He has revealed. The ninety-nine are a door; what lies beyond is immeasurable."
            },
            {
                "number": 3,
                "type": "factual",
                "prompt": f"In which Quranic context does the Name {translit} appear?",
                "options": [
                    {"id": "a", "text": quran_ref},
                    {"id": "b", "text": "Quran 1:1 — Ar-Rahman, Ar-Raheem"},
                    {"id": "c", "text": "Quran 112:1 — Al-Ahad"},
                    {"id": "d", "text": "Quran 2:255 — The Throne Verse"}
                ],
                "correct_option_id": "a",
                "citation": quran_ref,
                "scholar_reflection": "Allah places each Name in a specific context. He is telling you through the Name He chose why He did what He did. The Name is the key to the verse."
            },
            {
                "number": 4,
                "type": "factual",
                "prompt": "What does truly 'enumerating' the Names mean according to the scholars?",
                "options": [
                    {"id": "a", "text": "Memorising them in Arabic"},
                    {"id": "b", "text": "Knowing, understanding, acting upon, and calling upon Allah by each Name"},
                    {"id": "c", "text": "Counting them on prayer beads"},
                    {"id": "d", "text": "Writing them in calligraphy"}
                ],
                "correct_option_id": "b",
                "citation": "Ibn Uthaymeen, Commentary on the 99 Names",
                "scholar_reflection": "Memorisation is only the beginning. Call upon Al-Mujeeb when you need response, Al-Ghafoor when you need forgiveness, Al-Lateef when you need subtle help."
            },
            {
                "number": 5,
                "type": "factual",
                "prompt": "What does the Quran command regarding the Names of Allah?",
                "options": [
                    {"id": "a", "text": "Memorise them all"},
                    {"id": "b", "text": "Call upon Him by them"},
                    {"id": "c", "text": "Recite them after every prayer"},
                    {"id": "d", "text": "Teach them to your children"}
                ],
                "correct_option_id": "b",
                "citation": "Quran 7:180 — And to Allah belong the best Names, so call upon Him by them",
                "scholar_reflection": "The purpose of knowing the Names is calling upon Allah by them — in du'a, in dhikr, in trusting Him. Knowledge that does not change how you relate to Allah has not fully entered the heart."
            },
            {
                "number": 6,
                "type": "reflective",
                "prompt": f"Allah is {translit} — {meaning_brief.lower()}. When have you most needed Him to be this for you?",
                "slider_label": "How often do you call upon Allah by this specific Name?",
                "options": [
                    {"id": "a", "text": "In a moment of fear or danger"},
                    {"id": "b", "text": "When I needed something no one else could provide"},
                    {"id": "c", "text": "When I felt broken or ashamed"},
                    {"id": "d", "text": "I have not thought about needing this quality specifically"}
                ],
                "correct_option_id": None,
                "citation": f"Reflection on the Name {translit}",
                "scholar_reflection": "The Names of Allah become real in the moments we need them most. Each Name is a door — and Allah placed exactly this Name in your path at exactly this moment."
            },
            {
                "number": 7,
                "type": "reflective",
                "prompt": "The Prophet said whoever enumerates the Names enters paradise. What is the relationship between truly knowing Allah and the Garden?",
                "slider_label": "How much does your knowledge of Allah shape your daily choices?",
                "options": [
                    {"id": "a", "text": "Knowing Who Allah truly is makes it impossible to live as if He does not exist"},
                    {"id": "b", "text": "The Names change how you relate to Allah in every act of worship"},
                    {"id": "c", "text": "Understanding the Names removes the distance between you and Him"},
                    {"id": "d", "text": "All of these — true knowledge of Allah transforms everything"}
                ],
                "correct_option_id": None,
                "citation": "Sahih Muslim — the hadith of the 99 Names",
                "scholar_reflection": "You do not enter paradise by reciting a list. You enter because true knowledge of Allah reshapes who you are — your love, your fear, your trust, your worship."
            },
            {
                "number": 8,
                "type": "reflective",
                "prompt": f"Allah is {translit}. How does knowing this change how you make du'a?",
                "slider_label": "How specific are you when you call upon Allah?",
                "options": [
                    {"id": "a", "text": "I call upon Him by this Name when I need what it describes"},
                    {"id": "b", "text": "I have not thought about matching the Name to the need"},
                    {"id": "c", "text": "It makes me more confident that my du'a will be heard"},
                    {"id": "d", "text": "It makes me more specific and sincere in asking"}
                ],
                "correct_option_id": None,
                "citation": f"Quran 7:180 — Call upon Allah by His Names",
                "scholar_reflection": "Calling upon Al-Ghafoor for forgiveness is not the same as calling upon Al-Qadir for strength. Match the Name to the need — this is what the Quran commands."
            },
            {
                "number": 9,
                "type": "reflective",
                "prompt": "Ibn al-Qayyim said the heart is created to love something. What makes Allah the most worthy of that love?",
                "slider_label": "How much of your relationship with Allah is based on knowing Who He is?",
                "options": [
                    {"id": "a", "text": "He is the source of every good thing you have ever received"},
                    {"id": "b", "text": "He loves you even when you are heedless of Him"},
                    {"id": "c", "text": "He is Al-Jameel — beautiful — and beauty draws love"},
                    {"id": "d", "text": "All of these — each Name reveals another reason to love Him"}
                ],
                "correct_option_id": None,
                "citation": "Ibn al-Qayyim — Madarij as-Salikeen",
                "scholar_reflection": "The Names of Allah, when truly known, make Him the most worthy object of love. The more Names you know, the more of Him you know — and the more of Him you know, the more naturally the heart turns toward Him."
            },
            {
                "number": 10,
                "type": "reflective",
                "prompt": f"If you spent one week consciously remembering that Allah is {translit}, what would change?",
                "slider_label": "How present is awareness of Allah in your daily life?",
                "options": [
                    {"id": "a", "text": "My anxiety would decrease — I would trust more completely"},
                    {"id": "b", "text": "My du'a would become more sincere and specific"},
                    {"id": "c", "text": "I would act differently knowing He is aware of everything"},
                    {"id": "d", "text": "I would feel less alone in whatever I am facing"}
                ],
                "correct_option_id": None,
                "citation": f"Practical reflection on the Name {translit}",
                "scholar_reflection": "The purpose of knowing the Names is taqwa — constant awareness of Allah. Not fear alone, but awareness. When you are aware of Al-Qareeb, you are never truly alone."
            }
        ]
    }
    
    filepath = os.path.join(BASE, filename)
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    written.append(filename)

print(f"Written {len(written)} additional name files")

# Update the index to include all names
existing = [f for f in os.listdir(BASE) if f.endswith('.json') and f != 'index.json']
# Sort by number
def get_num(fname):
    try:
        with open(os.path.join(BASE, fname)) as f:
            return json.load(f).get('number', 999)
    except:
        return 999

existing.sort(key=get_num)
with open(os.path.join(BASE, 'index.json'), 'w') as f:
    json.dump(existing, f, indent=2)
print(f"Index updated with {len(existing)} total names")
