Begin;

Create View banner(name, version, author) As Values
('SQLite Hangman', 'v0.6.0', 'Mateusz Adamowski');

Create Table level (
    id Integer Primary Key
        Not Null
        Check (id = 1),
    levelname Text
        Not Null
        Check (levelname in ('normal', 'nightmare', 'easy'))
);
Insert into level select 1, 'normal';

Create View hangman_art (line, num, minm, maxm) As
    Values
    ('  --==[ :TITLE: ]==--', 0, 0, 6),
    ('', 1, 0, 6),
    ('  :MSG:', 2, 0, 6),
    ('', 3, 0, 6),
    ('     +-----+-+', 4, 0, 6),
    ('     |      \|', 5, 0, 6),
    ('     ^       |   :WORD:', 6, 0, 0),
    ('     O       |   :WORD:', 6, 1, 6),
    ('             |', 7, 0, 1),
    ('     |       |', 7, 2, 2),
    ('    /|       |', 7, 3, 3),
    ('    /|\      |', 7, 4, 6),
    ('             |   :GUESSES:', 8, 0, 4),
    ('    /        |   :GUESSES:', 8, 5, 5),
    ('    / \      |   :GUESSES:', 8, 6, 6),
    ('             |', 9, 0, 6),
    ('         ___/|\___', 10, 0, 6),
    ('', 11, 0, 6),
    ('', 12, 0, 6);

Create Table wordid (
    wordid Int Not Null Unique
);

Create Table guesses (
    letter Text Not Null Unique
);

Create View word As
    Select Upper(word) As word
    From words
    Join wordid
    On (words.id = wordid.wordid)
    Limit 1;

Create View question As
    With Recursive pos(n, q) As (
        Select 0 As n , '' As q
        Union All
        Select
            n+1,
            q || Case
            When Upper(Substr((Select word From word), n+1, 1)) In (Select Upper(letter) From guesses)
            Then Upper(Substr((Select word From word), n+1, 1))
            Else '_'
            End
        From pos
        Where n < (Select Length(word) From word Limit 1)
    )
    Select
        q As question
    From pos
    Order By n Desc
    Limit 1;

Create View fails As
    Select letter
    From guesses
    Where InStr((Select word From word Limit 1), Upper(letter)) = 0;

Create View failcount As
    Select count() as failcount From fails;

Create View status As
    Select Case
    When (Select failcount = 6 From failcount)
    Then 'gameover'
    When (Select question = word From word Join question)
    Then 'win'
    Else 'guess'
    End As status;

Create View message As
    Select
        Case
        When (Select Count() = 0 From guesses)
        Then (
            Case When (Select Count() = 0 From wordid)
            Then '> insert into game select ''start'';'
            Else '> insert into game select ''x'';' End
        )
        When (Select 'gameover' = status From status)
        Then 'GAME OVER: ' || (Select word From word)
        When (Select 'win' = status From status)
        Then 'You won!'
        Else 'Guess another letter...'
        End As msg;

Create View game As
    Select
        Case
        When InStr(line, ':MSG:')
        Then Replace(line, ':MSG:', (Select msg From message))
        When InStr(line, ':TITLE:')
        Then Replace(line, ':TITLE:', (Select name || ' ' || version From banner))
        When InStr(line, ':WORD:')
        Then Replace(line, ':WORD:', (Select question From question))
        When InStr(line, ':GUESSES:')
        Then Replace(line, ':GUESSES:', Coalesce(
            (Select Group_Concat(letter) From fails),
            '...'
        ))
        Else line End As game
        From hangman_art
        Where (Select failcount Between minm And maxm From failcount)
        Order By num;

Create View possible_words As
 Select id, word From words Join question Where (Upper(word) Like question)
 Except
 Select Distinct id, word From words Join fails Join question
 Where (InStr(word, Lower(letter)));

Create View word_lengths(len) As
 Select Distinct Length(word)
 From words;

Create View winning_nightmare As
    Select
    *, (
        Select count()
        From words
        Where Length(word) = len And Not (
            InStr(Upper(word), l1) Or
            InStr(Upper(word), l2) Or
            Instr(Upper(word), l3) Or
            Instr(Upper(word), l4) Or
            Instr(Upper(word), l5)
        )
    ) As wn
    From five_letters
    Join word_lengths
    Where wn <= 1;

Create View abc(letter) As
    With Recursive a(letter) As (
        Select 'A'
        Union All
        Select
            Char(Unicode(letter) + 1) 
        From a
        Where letter < 'Z'
        )
    Select * From a;

Create View five_letters(l1, l2, l3, l4, l5) As 
    Select *
    From abc a1, abc a2, abc a3, abc a4, abc a5
    Where a1.letter < a2.letter
        And a2.letter < a3.letter
        And a3.letter < a4.letter
        And a4.letter < a5.letter;

Create View hint(letter, `count`, words) As
    Select abc.letter As letter, count() as `count`, group_concat(word, ', ')
    From abc
    Left Join guesses
    On (Upper(guesses.letter) = Upper(abc.letter))
    Join possible_words
    On (InStr(Upper( word), Upper(abc.letter)))
    Where guesses.letter Is Null
    Group By abc.letter
    Order By `count` Desc;

Create Trigger action_start_game
    Instead Of Insert On game
    When Upper(new.game) = 'START'
    Begin
        Delete From wordid;
        Insert Into wordid
            Select id From words Order By Random() Limit 1;
        Delete From guesses;
    End;

Create Trigger action_guess_letter_normal
    Instead Of Insert On game
    When
        (Select levelname From level) = 'normal'
        And Length( new.game) = 1
        And (Lower( new.game) != Upper(new.game))
        And (Select Count() = 0 From guesses Where Upper(letter) = Upper(new.game))
        And (Select Count() = 1 From wordid)
    Begin
        Insert Into guesses Select Upper(new.game);
    End;

Create Trigger action_guess_letter_nightmare_swap
    Instead Of Insert On game
    When
        (Select levelname From level) = 'nightmare'
        And Length(new.game) = 1
        And (Lower(new.game ) != Upper(new.game))
        And (Select Count() = 0 From guesses Where Upper(letter) = Upper(new.game))
        And (Select Count() = 1 From wordid)
        And (Select Count() > 0 From possible_words
            Where Not InStr(Upper(word), Upper(new.game))
        )
    Begin
        Update wordid Set wordid = (
            Select id From possible_words
            Where Not InStr(Upper(word), Upper(new.game))
            Order By Random() Limit 1
        );
        Insert Into guesses Select Upper(new.game);
    End;

Create Trigger action_guess_letter_nightmare_noswap
    Instead Of Insert On game
    When
        (Select levelname From level) = 'nightmare'
        And Length(new.game) = 1
        And (Lower(new.game) != Upper(new.game))
        And (Select Count() = 0 From guesses Where Upper(letter) = Upper(new.game))
        And (Select Count() = 1 From wordid)
        And (Select Count() = 0 From possible_words
            Where Not InStr(Upper(word), Upper(new.game))
        )
    Begin
        Insert Into guesses Select Upper(new.game);
    End;

Create Trigger action_guess_letter_easy_swap
    Instead Of Insert On game
    When
        (Select levelname From level) = 'easy'
        And Length(new.game) = 1
        And (Lower(new.game) != Upper(new.game))
        And (Select Count() = 0 From guesses Where Upper(letter) = Upper(new.game))
        And (Select Count() = 1 From wordid)
        And (Select Count() > 0 From possible_words
            Where InStr(Upper(word), Upper(new.game))
       )
    Begin
        Update wordid Set wordid = (
            Select id From possible_words
            Where InStr(Upper(word), Upper(new.game))
            Order By Random() Limit 1
       );
        Insert Into guesses Select Upper(new.game);
    End;

Create Trigger action_guess_letter_easy_noswap
    Instead Of Insert On game
    When
        (Select levelname From level) = 'easy'
        And Length(new.game) = 1
        And (Lower(new.game) != Upper(new.game))
        And (Select Count() = 0 From guesses Where Upper(letter) = Upper(new.game))
        And (Select Count() = 1 From wordid)
        And (Select Count() = 0 From possible_words
            Where InStr(Upper(word), Upper(new.game))
       )
    Begin
        Insert Into guesses Select Upper(new.game);
    End;


Create View words (id, word) As
    Select key, atom From JSON_Each(
    '["able","about","account","acid","across","act","addition","adjustment",' ||
    '"advertisement","after","again","against","agreement","air","all","almos' ||
    't","among","amount","amusement","and","angle","angry","animal","answer",' ||
    '"ant","any","apparatus","apple","approval","arch","argument","arm","army' ||
    '","art","attack","attempt","attention","attraction","authority","automat' ||
    'ic","awake","baby","back","bad","bag","balance","ball","band","base","ba' ||
    'sin","basket","bath","beautiful","because","bed","bee","before","behavio' ||
    'ur","belief","bell","bent","berry","between","bird","birth","bit","bite"' ||
    ',"bitter","black","blade","blood","blow","blue","board","boat","body","b' ||
    'oiling","bone","book","boot","bottle","box","boy","brain","brake","branc' ||
    'h","brass","bread","breath","brick","bridge","bright","broken","brother"' ||
    ',"brown","brush","bucket","building","bulb","burn","burst","business","b' ||
    'ut","butter","button","cake","camera","canvas","card","care","carriage",' ||
    '"cart","cat","cause","certain","chain","chalk","chance","change","cheap"' ||
    ',"cheese","chemical","chest","chief","chin","church","circle","clean","c' ||
    'lear","clock","cloth","cloud","coal","coat","cold","collar","colour","co' ||
    'mb","come","comfort","committee","common","company","comparison","compet' ||
    'ition","complete","complex","condition","connection","conscious","contro' ||
    'l","cook","copper","copy","cord","cork","cotton","cough","country","cove' ||
    'r","cow","crack","credit","crime","cruel","crush","cry","cup","current",' ||
    '"curtain","curve","cushion","damage","danger","dark","daughter","day","d' ||
    'ead","dear","death","debt","decision","deep","degree","delicate","depend' ||
    'ent","design","desire","destruction","detail","development","different",' ||
    '"digestion","direction","dirty","discovery","discussion","disease","disg' ||
    'ust","distance","distribution","division","dog","door","doubt","down","d' ||
    'rain","drawer","dress","drink","driving","drop","dry","dust","ear","earl' ||
    'y","earth","east","edge","education","effect","egg","elastic","electric"' ||
    ',"end","engine","enough","equal","error","even","event","ever","every","' ||
    'example","exchange","existence","expansion","experience","expert","eye",' ||
    '"face","fact","fall","false","family","far","farm","fat","father","fear"' ||
    ',"feather","feeble","feeling","female","fertile","fiction","field","figh' ||
    't","finger","fire","first","fish","fixed","flag","flame","flat","flight"' ||
    ',"floor","flower","fly","fold","food","foolish","foot","for","force","fo' ||
    'rk","form","forward","fowl","frame","free","frequent","friend","from","f' ||
    'ront","fruit","full","future","garden","general","get","girl","give","gl' ||
    'ass","glove","goat","gold","good","government","grain","grass","great","' ||
    'green","grey","grip","group","growth","guide","gun","hair","hammer","han' ||
    'd","hanging","happy","harbour","hard","harmony","hat","hate","have","hea' ||
    'd","healthy","hear","hearing","heart","heat","help","high","history","ho' ||
    'le","hollow","hook","hope","horn","horse","hospital","hour","house","how' ||
    '","humour","ice","idea","ill","important","impulse","increase","industry' ||
    '","ink","insect","instrument","insurance","interest","invention","iron",' ||
    '"island","jelly","jewel","join","journey","judge","jump","keep","kettle"' ||
    ',"key","kick","kind","kiss","knee","knife","knot","knowledge","land","la' ||
    'nguage","last","late","laugh","law","lead","leaf","learning","leather","' ||
    'left","leg","let","letter","level","library","lift","light","like","limi' ||
    't","line","linen","lip","liquid","list","little","living","lock","long",' ||
    '"look","loose","loss","loud","love","low","machine","make","male","man",' ||
    '"manager","map","mark","market","married","mass","match","material","may' ||
    '","meal","measure","meat","medical","meeting","memory","metal","middle",' ||
    '"military","milk","mind","mine","minute","mist","mixed","money","monkey"' ||
    ',"month","moon","morning","mother","motion","mountain","mouth","move","m' ||
    'uch","muscle","music","nail","name","narrow","nation","natural","near","' ||
    'necessary","neck","need","needle","nerve","net","new","news","night","no' ||
    'ise","normal","north","nose","not","note","now","number","nut","observat' ||
    'ion","off","offer","office","oil","old","only","open","operation","opini' ||
    'on","opposite","orange","order","organization","ornament","other","out",' ||
    '"oven","over","owner","page","pain","paint","paper","parallel","parcel",' ||
    '"part","past","paste","payment","peace","pen","pencil","person","physica' ||
    'l","picture","pig","pin","pipe","place","plane","plant","plate","play","' ||
    'please","pleasure","plough","pocket","point","poison","polish","politica' ||
    'l","poor","porter","position","possible","pot","potato","powder","power"' ||
    ',"present","price","print","prison","private","probable","process","prod' ||
    'uce","profit","property","prose","protest","public","pull","pump","punis' ||
    'hment","purpose","push","put","quality","question","quick","quiet","quit' ||
    'e","rail","rain","range","rat","rate","ray","reaction","reading","ready"' ||
    ',"reason","receipt","record","red","regret","regular","relation","religi' ||
    'on","representative","request","respect","responsible","rest","reward","' ||
    'rhythm","rice","right","ring","river","road","rod","roll","roof","room",' ||
    '"root","rough","round","rub","rule","run","sad","safe","sail","salt","sa' ||
    'me","sand","say","scale","school","science","scissors","screw","sea","se' ||
    'at","second","secret","secretary","see","seed","seem","selection","self"' ||
    ',"send","sense","separate","serious","servant","sex","shade","shake","sh' ||
    'ame","sharp","sheep","shelf","ship","shirt","shock","shoe","short","shut' ||
    '","side","sign","silk","silver","simple","sister","size","skin","skirt",' ||
    '"sky","sleep","slip","slope","slow","small","smash","smell","smile","smo' ||
    'ke","smooth","snake","sneeze","snow","soap","society","sock","soft","sol' ||
    'id","some","son","song","sort","sound","soup","south","space","spade","s' ||
    'pecial","sponge","spoon","spring","square","stage","stamp","star","start' ||
    '","statement","station","steam","steel","stem","step","stick","sticky","' ||
    'stiff","still","stitch","stocking","stomach","stone","stop","store","sto' ||
    'ry","straight","strange","street","stretch","strong","structure","substa' ||
    'nce","such","sudden","sugar","suggestion","summer","sun","support","surp' ||
    'rise","sweet","swim","system","table","tail","take","talk","tall","taste' ||
    '","tax","teaching","tendency","test","than","that","the","then","theory"' ||
    ',"there","thick","thin","thing","this","thought","thread","throat","thro' ||
    'ugh","thumb","thunder","ticket","tight","till","time","tin","tired","toe' ||
    '","together","tomorrow","tongue","tooth","top","touch","town","trade","t' ||
    'rain","transport","tray","tree","trick","trouble","trousers","true","tur' ||
    'n","twist","umbrella","under","unit","use","value","verse","very","vesse' ||
    'l","view","violent","voice","waiting","walk","wall","war","warm","wash",' ||
    '"waste","watch","water","wave","wax","way","weather","week","weight","we' ||
    'll","west","wet","wheel","when","where","while","whip","whistle","white"' ||
    ',"who","why","wide","will","wind","window","wine","wing","winter","wire"' ||
    ',"wise","with","woman","wood","wool","word","work","worm","wound","writi' ||
    'ng","wrong","year","yellow","yes","yesterday","you","young"]');

Commit;
