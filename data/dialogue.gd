class_name Dialogue
extends RefCounted
## Teksty handlarzy. Konteksty: greet, first, after_extract, profit, after_death, many_deaths, kill_szab,
## buy, no_money, no_room, sell, refuse, empty_hand, insure_ok, insure_no, already, quest_new, quest_active,
## quest_done, quest_none, mail_ok, mail_lost, corpse. Brakujący kontekst wraca do greet.

const TRADERS := {
	"kw": {"name": "Chorąży Wójt", "role": "Zbrojmistrz"},
	"med": {"name": "Doktor Ruda", "role": "Medyk"},
	"pos": {"name": "Sznurek", "role": "Skup"},
}
const ORDER := ["kw", "med", "pos"]

const CONTRACT := [
	"KONTRAKT 0001/K",
	"",
	"Zleceniodawca: nie dotyczy.",
	"Zleceniobiorca: Operator (dane uzupełniono z urzędu).",
	"",
	"Przedmiot umowy: wejście w strefę kordonu, pozyskanie przedmiotów i dokumentów wskazanych w załączniku (brak załącznika),",
	"oraz powrót. Powrót jest zalecany, ale nie jest warunkiem płatności.",
	"",
	"Wynagrodzenie: zależy od tego, co Pan(i) przyniesie. Zleceniodawca ma interes w tym, aby kompleks nie został zapomniany.",
	"",
	"Na miejscu pracują trzej handlarze. Radzimy z nimi rozmawiać. Wszystkim pozostałym radzimy nie ufać.",
	"",
	"Przed pierwszym wejściem odbędzie się krótkie szkolenie. Szkolenie nie liczy się do wyniku i niczego nie zabiera.",
]

const L := {
	"kw": {
		"first": ["Nowy. Dobrze. Stary już by wiedział, że nie ma tu darmowych rzeczy. Ja nie daję kredytu, nie przyjmuję zwrotów i nie pytam."],
		"greet": ["Co dziś?", "Mów, co potrzebujesz. Tylko szybko, mam inwentaryzację.", "Towar jest. Pieniądze też, mam nadzieję, że Twoje."],
		"after_extract": ["Wróciłeś. Bywa.", "Cały? To się zapisze w moich księgach jako dobry znak.", "Wróciłeś w jednym kawałku. Pogratulować nie będę, bo to by podniosło cenę."],
		"profit": ["Ciężko Ci się nosi, jak widzę. Mogę ulżyć, za 55 procent.", "Pełny plecak i uśmiech. Za dużo uśmiechu. Pokaż, co masz."],
		"after_death": ["Straciłeś sprzęt. Wiesz, że to się liczy jako moja sprzedaż, po fakcie?", "Znowu golas? Po co oddawałeś mi te rzeczy? A, nie oddawałeś."],
		"many_deaths": ["Trzy razy z rzędu. Mogę dać zniżkę na stałego klienta. Tylko nie zniżkę na rozsądek.", "Zacznij mówić, co Cię zabiło. Ja Ci dobiorę przedmiot, który tego nie robi."],
		"kill_szab": ["Słyszałem, że przerzedzasz osiedle. Dobrze. Przynajmniej coś się dzieje."],
		"buy": ["Tak, to dobry wybór.", "Zapłacone. Reklamacji nie przyjmuję.", "Dobrze. Uważaj, żeby tego nie zgubić."],
		"no_money": ["Bony, nie obietnice.", "Brakuje Ci. Wróć, jak wrócisz."],
		"no_room": ["Skrytka pełna. Sprzedaj coś albo wyrzuć. Ja nie mam magazynu na Twoje rzeczy."],
		"sell": ["Przyjęte. Cena jest ostateczna.", "Zgoda. Papierów nie potrzeba."],
		"refuse": ["Nie moja branża. Idź do Sznurka, on bierze wszystko.", "Tego nie skupuję. Mam mundury i metal, nie bibeloty."],
		"empty_hand": ["Weź coś do ręki, a nie machasz."],
		"insure_ok": ["Podpisane. Ubezpieczalnia obiecuje zwrot. Obietnica to nie gwarancja.", "Zapisane. W razie czego zwrot przyjdzie pocztą po rajdzie. Zazwyczaj."],
		"insure_no": ["Tego nie ubezpieczam. Nie ma sensu ubezpieczać tego, co nie ma ceny."],
		"already": ["Ten już ma polisę."],
		"quest_new": ["Mam robotę. Płacę lepiej niż inni. Co nie znaczy, że dobrze."],
		"quest_active": ["Jeszcze nie skończone. Czekam."],
		"quest_done": ["Dobrze. Zapisane. Wybierz, co chcesz.", "Zrobione, dziękuję. Nie, nie będę serdeczny."],
		"quest_none": ["Nic dla Ciebie nie mam. Wróć, jak się ktoś zdenerwuje."],
		"mail_ok": ["Ubezpieczalnia przysłała Twoje rzeczy. Uważaj tym razem."],
		"mail_lost": ["Ubezpieczalnia zgubiła Twoje rzeczy. Mówią, że nie rozumieją, jak to możliwe. Ja rozumiem."],
		"corpse": ["Twoje ciało leży gdzieś na terenie. Jeśli pójdziesz po sprzęt, to Twoja sprawa. Ja bym poszedł z kimś."],
	},
	"med": {
		"first": ["Cicho. Tu się nie krzyczy. Tu się przychodzi, kiedy boli i dziękuje, kiedy przestaje."],
		"greet": ["Boli coś?", "Siadaj. Pokaż ręce.", "Nie robię cudów. Robię opatrunki."],
		"after_extract": ["Wróciłeś. To dobrze. Dla mnie, bo mam kogo leczyć.", "Cały? Nikt nie jest cały. Pokaż się."],
		"profit": ["Przyniosłeś dużo. Ludzie tak robią, kiedy nie wiedzą, co zrobić z rękami.", "Pełne kieszenie to często puste głowy. Ale nie obrażam."],
		"after_death": ["Znowu cię wyciągnęli. Nie, nikt cię nie wyciągnął. Wstałeś sam. Z reguły wstaje się sam.", "Tego się nie leczy opatrunkiem. Tu trzeba zacząć od nowa."],
		"many_deaths": ["Trzy razy z rzędu. Zastanów się, czy to nie ma wzoru. Ja już widzę wzór.", "Wiesz, jaka jest najgorsza rana? Powtarzalna."],
		"kill_szab": ["Słyszę, że szabrownicy to dawni sąsiedzi. Nie mówię, żebyś przestał. Mówię, żebyś pamiętał."],
		"buy": ["Dobrze. Pamiętaj: bandaż nie goli, nie ratuje, tylko daje czas.", "Proszę. Używaj mądrze.", "To pomoże. Nie wszystkim, ale pomoże."],
		"no_money": ["Przykro mi, ale nie mogę dawać na kredyt. Mam zobowiązania wobec własnego sumienia."],
		"no_room": ["Nie ma gdzie położyć. Zrób miejsce."],
		"sell": ["Dobrze. Przyda się.", "Przyjęte. Nie pytam o pochodzenie, ale zapamiętuję."],
		"refuse": ["Tego nie biorę. Biorę leki, próbki i papiery. Resztę zanieś do Sznurka.", "To nie moja dziedzina."],
		"empty_hand": ["Pokaż, co masz w ręku."],
		"insure_ok": ["To nie moja branża, ale rozumiem, że czasem warto dać sobie szansę."],
		"insure_no": ["Nie."],
		"already": ["Już ubezpieczone."],
		"quest_new": ["Mam prośbę. Może nie powinienem prosić, ale proszę."],
		"quest_active": ["Wciąż czekam. Proszę nie spieszyć się z ryzykiem."],
		"quest_done": ["Dziękuję. Naprawdę. Wybierz, co ci się przyda.", "Dobrze. Wiem już dość. Wybierz, co chcesz."],
		"quest_none": ["Na razie nic. Dziękuję."],
		"mail_ok": ["Ubezpieczalnia przysłała paczkę dla Ciebie. Otwórz, zanim znowu wyjdziesz."],
		"mail_lost": ["Paczka z ubezpieczalni nie doszła. Zdarza się."],
		"corpse": ["Pamiętasz, gdzie zostawiłeś siebie? To ważne. Mapa pomaga."],
	},
	"pos": {
		"first": ["O, nowa twarz, nowa torba, nowe nadzieje. Tu każdy coś sprzedaje. Ja po prostu kupuję szybciej."],
		"greet": ["Co masz?", "Handel jest jak oddychanie. Kto przestaje, ten się dusi.", "Pokaż, co przyniosłeś. Chyba że nic, to też pokaż."],
		"after_extract": ["Jesteś. Dobrze, bo już pomyślałem, że ktoś inny będzie mi kradł towar.", "Cały? Dobrze. Bo martwi nie sprzedają."],
		"profit": ["Pełne torby! No, no. Jak bym to widział w swoim sklepie, to bym się pomodlił.", "Dużo. Za dużo, żeby było uczciwie. Zapłacę uczciwie."],
		"after_death": ["Aj. Znowu bez niczego? Przecież to, co zostawiłeś, ktoś już sprzedaje.", "Nie przejmuj się. Strata to też rodzaj zysku, tylko dla kogoś innego."],
		"many_deaths": ["Trzy razy. Zaczynam widzieć w Tobie stałego dostawcę, tylko że dla innych.", "Przestań umierać, bo ludzie zaczną na to liczyć."],
		"kill_szab": ["Moi znajomi mówią, że ktoś ostatnio przerzedza osiedle. Nie wiem, kto. Ale chciałbym, żeby przestał.", "Ci, których zabiłeś, mieli rodziny. To nie wyrzut, to ofertowa informacja."],
		"buy": ["Dobry wybór. Dla mnie też.", "Płacisz, masz. Prosta zasada.", "Sprzedane! Uwielbiam to słowo."],
		"no_money": ["Pieniądze nie rosną na drzewie. Rosną w sejfach. Ale tego akurat nie polecam."],
		"no_room": ["Nie ma miejsca. Sprzedaj coś, to zrobi się miejsce na kupno."],
		"sell": ["Zrobione. Biorę wszystko, co błyszczy i co nie ma instrukcji.", "Dobra cena, jak na te czasy.", "Chętnie. Wiem, komu to dalej sprzedam."],
		"refuse": ["Tego nawet ja nie wezmę. A biorę dziwne rzeczy.", "Za wąska specjalizacja. Idź do Wójta, zbrojenia to jego.", "Nie biorę leków. Lekarz by się obraził."],
		"empty_hand": ["Daj coś do ręki, to pogadamy."],
		"insure_ok": ["Hm. Z tym to do Wójta. Ale kto wie."],
		"insure_no": ["Nie."],
		"already": ["Już."],
		"quest_new": ["Mam interes. Chcesz zarobić?"],
		"quest_active": ["Jeszcze nie ma. Pamiętaj, kto czeka."],
		"quest_done": ["Dobrze, dobrze. Wybieraj. Ja zawsze płacę, bo to dobry interes.", "Zrobione. Zawsze chętnie z Tobą handluję."],
		"quest_none": ["Chwilowo wszystko sprzedane."],
		"mail_ok": ["Ubezpieczalnia coś ci przysłała. Moje podejrzenie: nie wszystko."],
		"mail_lost": ["Nie dotarło, co miało dotrzeć. Ubezpieczalnia przeprasza, bo musi."],
		"corpse": ["Twoje ciało jeszcze tam leży. Mogę kupić od Ciebie jego współrzędne, tylko po co. Sam pójdziesz."],
	},
}


static func line(trader: String, ctx: String) -> String:
	var t: Dictionary = L.get(trader, L["kw"])
	var pool: Array = t.get(ctx, t["greet"])
	return pool[randi() % pool.size()]
