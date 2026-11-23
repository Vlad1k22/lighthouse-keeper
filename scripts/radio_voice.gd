extends Node
## Радиоэфир с нейроозвучкой: утренние сводки диспетчера, ночные голоса, записи и реакции на события.
## Голос синтезирован заранее (Piper, ru irinia) и обработан под рацию: tools/voice/generate_voice.py.
## text — субтитры, say — то, что произносится (числа словами), style — обработка звука.
const DIR := "res://assets/audio/voice/"
const STATION := "СВОДКА · БЕРЕГОВАЯ СТАНЦИЯ"
const DISPATCH := "БЕРЕГ-ЧЕТЫРЕ"
const GHOST := "ГОЛОС В ЭФИРЕ"
const RECORD := "ЗАПИСЬ ПРЕЖНЕЙ СМЕНЫ"
const CAPTAIN := "КАПИТАН НА КАРТИНЕ"
const LINES := {
	"brief_1": {"speaker":STATION,"style":"dispatch","text":"Маяк «Северный», автоматическая сводка. Смотритель, найдите канистру топлива на тропе у хижины и запустите генератор маяка. Затем поднимитесь к линзе. До темноты укрепите хижину — три бревна с валежника."},
	"brief_2": {"speaker":STATION,"style":"dispatch","text":"Сводка для «Северного». Прежний смотритель оставил красный ящик с инструментами на старом складе к северу. Заберите инструменты и две детали. Ночью тени пойдут к генератору и к хижине. Держите свет.","hint":"Луч фонаря — ПКМ или C. Цель отмечена бирюзовым маркером."},
	"brief_3": {"speaker":STATION,"style":"dispatch","text":"Сводка для «Северного». Без воды смена долго не протянет. Почините насос колодца: нужно одно бревно и две детали. Потом наполните флягу.","hint":"H у насоса — наполнить флягу."},
	"brief_4": {"speaker":STATION,"style":"dispatch","text":"Сводка для «Северного». Передатчик на радиостанции молчит. Аккумулятор остался в остове старой лодки на северном берегу. Найдите его и почините передатчик — тогда мы сможем говорить напрямую."},
	"brief_5": {"speaker":DISPATCH,"style":"dispatch","text":"«Северный», это Берег-четыре. Связь есть! Подойдите к домашнему радио в хижине: передаём первую цифру кода. Потом займитесь корпусом катера — пять бревен и две детали."},
	"brief_6": {"speaker":DISPATCH,"style":"dispatch","text":"Берег-четыре — «Северному». Катеру нужен двигатель, это четыре детали. В гавани у топливных бочек есть аварийный запас. Вскройте пломбу."},
	"brief_7": {"speaker":DISPATCH,"style":"dispatch","text":"«Северный», приём. У валежника видели человека в жёлтом плаще. Осмотрите следы и прочтите табличку на тропе. Ночью за ним не ходите."},
	"brief_8": {"speaker":DISPATCH,"style":"dispatch","text":"Берег-четыре. Вторая цифра кода — в памятке под насосом колодца. Ночью возможен обрыв питания. Если луч погаснет, идите к генератору с ручным фонарём."},
	"brief_9": {"speaker":DISPATCH,"style":"dispatch","text":"«Северный», вы давно не ели горячего. Проверьте ловушку в гавани и приготовьте улов на печи. Ночь будет тихой. Слишком тихой."},
	"brief_10": {"speaker":DISPATCH,"style":"dispatch","text":"Берег-четыре. Этой ночью ждём осаду. Разожгите костёр в гавани — это резервный свет — и проверьте аптечку. Держите баррикаду целой."},
	"brief_11": {"speaker":DISPATCH,"style":"dispatch","text":"«Северный», третья цифра — в остове лодки. Потом найдите внешний буй на карте в рубке катера. Ночью кто-то будет говорить нашим позывным. Сверяйте контрольную отметку."},
	"brief_12": {"speaker":DISPATCH,"style":"dispatch","text":"Берег-четыре. Погрузите на катер три готовых блюда. Пайки — в сухом ящике в гавани. Последний шторм пройдёт этой ночью."},
	"brief_13": {"speaker":DISPATCH,"style":"dispatch","text":"«Северный», последний день. Передайте код из трёх цифр на передатчике и нанесите маршрут на путевой лист. Выдержите эту ночь — утром ждём вас у внешнего буя."},
	"brief_14": {"speaker":DISPATCH,"style":"dispatch","text":"Берег-четыре — «Северному». Море открыто. Заправьте бак, проверьте провизию и становитесь к штурвалу. Мы видим ваш свет. Возвращайтесь домой."},
	"first_radio": {"speaker":GHOST,"style":"ghost","text":"…Красный ящик. Старый склад…"},
	"transmitter_on": {"speaker":DISPATCH,"style":"dispatch","text":"«Северный», говорит Берег-четыре! Слышим вас. Штормовая полоса закроет выход до 14-го дня. Готовьте катер и ждите контрольную группу.","say":"«Северный», говорит Берег-четыре! Слышим вас. Штормовая полоса закроет выход до четырнадцатого дня. Готовьте катер и ждите контрольную группу."},
	"code_digit_1": {"speaker":DISPATCH,"style":"dispatch","text":"Записывайте: первая цифра контрольной группы — 3. Полный код ждём утром перед последней ночью.","say":"Записывайте: первая цифра контрольной группы — три. Полный код ждём утром перед последней ночью."},
	"code_confirm": {"speaker":DISPATCH,"style":"dispatch","text":"Берег-четыре подтверждает пакет 314. У внешнего буя вас ждут утром четырнадцатого дня.","say":"Берег-четыре подтверждает пакет триста четырнадцать. У внешнего буя вас ждут утром четырнадцатого дня."},
	"archive_log": {"speaker":RECORD,"style":"record","text":"Два часа шестнадцать минут… Следы у валежника… опять мои."},
	"archive_crew": {"speaker":RECORD,"style":"record","text":"Если выберешься к катеру, загляни под койку в каюте «Северного». Мы оставили там страницу с подписями."},
	"service_freq": {"speaker":DISPATCH,"style":"dispatch","text":"Берег-четыре. Служебная частота. Ждите вызова по расписанию и сверяйте контрольные отметки."},
	"static_voice": {"speaker":GHOST,"style":"ghost","text":"…«Северный»… откройте дверь… мы уже снаружи…"},
	"false_call": {"speaker":"БЕРЕГ-ЧЕТЫРЕ?","style":"ghost","text":"«Северный», это Берег-четыре! Шторм кончился. Немедленно выходите к пляжу, мы вас заберём!"},
	"confirm_11": {"speaker":DISPATCH,"style":"dispatch","text":"Берег-четыре, контрольная отметка 22:10. Это мы. Ложный вызов не слушайте, оставайтесь у света.","say":"Берег-четыре, контрольная отметка двадцать два десять. Это мы. Ложный вызов не слушайте, оставайтесь у света."},
	"confirm_13": {"speaker":DISPATCH,"style":"dispatch","text":"Берег-четыре, контрольная отметка 23:40. Сигнал подтверждён. До утра оставайтесь у света.","say":"Берег-четыре, контрольная отметка двадцать три сорок. Сигнал подтверждён. До утра оставайтесь у света."},
	"alone": {"speaker":DISPATCH,"style":"ghost","text":"«Северный», ответьте. Последний катер ушёл три недели назад. Больше никто не высаживался на острове. Повторяю: вы там один."},
	"night_start": {"speaker":DISPATCH,"style":"dispatch","text":"«Северный», темнеет. Держите генератор и хижину до рассвета. Тени тянутся к свету."},
	"raid_first": {"speaker":DISPATCH,"style":"dispatch","text":"Вижу движение у вашего маяка! Тени идут к свету. Выжигайте их лучом фонаря.","hint":"Зажмите ПКМ (или C) и наведите мышь на тень."},
	"light_out": {"speaker":DISPATCH,"style":"dispatch","text":"«Северный», ваш маяк погас! Срочно к генератору!"},
	"barricade_broken": {"speaker":DISPATCH,"style":"dispatch","text":"Баррикада хижины пробита. Почините её у верстака до рассвета."},
	"dawn_good": {"speaker":DISPATCH,"style":"dispatch","text":"Доброе утро, «Северный». Ваш свет горел всю ночь. Отличная работа."},
	"event_wreck": {"speaker":DISPATCH,"style":"dispatch","text":"«Северный», у вас на берегу груз с затонувшего судна. Заберите, пока не смыло приливом."},
	"event_sparks": {"speaker":DISPATCH,"style":"dispatch","text":"Ваш генератор перегревается! Проверьте проводку, иначе сгорит запас топлива."},
	"event_fog": {"speaker":DISPATCH,"style":"dispatch","text":"С моря идёт туман. В нём что-то движется. Держите фонарь наготове.","hint":"Зажмите ПКМ (или C) и наведите мышь на тень."},
	"event_shoal": {"speaker":DISPATCH,"style":"dispatch","text":"У вашего причала косяк рыбы. Хороший шанс на редкий улов."},
	"event_bottle": {"speaker":DISPATCH,"style":"dispatch","text":"В прибое что-то блестит. Похоже на бутылку с запиской."},
	"captain_ready": {"speaker":CAPTAIN,"style":"captain","text":"Вы готовы, дети?"},
	"captain_louder": {"speaker":CAPTAIN,"style":"captain","text":"Не слышу! Громче!"}
}

var game: Node
var player: AudioStreamPlayer
var queue: Array[String] = []
var current := ""
var subtitle_time := 0.0
var played := {}
var cache := {}

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "RadioVoice"
	player.bus = "Dialogue"
	player.volume_db = -2.0
	add_child(player)
	player.finished.connect(_next)

func reset() -> void:
	queue.clear()
	played.clear()
	current = ""
	subtitle_time = 0
	if is_instance_valid(player):
		player.stop()

func stream_for(id: String) -> AudioStream:
	if cache.has(id):
		return cache[id]
	var path := DIR + id + ".ogg"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	cache[id] = stream
	return stream

## Поставить реплику в эфир. once — не повторять в этой смене. urgent — прервать текущую.
func say(id: String, once := false, urgent := false) -> bool:
	if not LINES.has(id):
		return false
	if once and played.has(id):
		return false
	played[id] = true
	if urgent:
		queue.clear()
		_play(id)
		return true
	if current.is_empty():
		_play(id)
	elif queue.size() < 2 and id != current and id not in queue:
		queue.append(id)
	return true

func _play(id: String) -> void:
	current = id
	var stream := stream_for(id)
	var line: Dictionary = LINES[id]
	var words := String(line.text).split(" ").size()
	subtitle_time = maxf(3.5, words * .42 + 1.2)
	if stream != null and is_instance_valid(player):
		player.stream = stream
		player.play()
		subtitle_time = stream.get_length() + .8
	if is_instance_valid(game) and is_instance_valid(game.sound):
		game.sound.radio_signal()

func _next() -> void:
	if not queue.is_empty():
		_play(queue.pop_front())

func _process(delta: float) -> void:
	if current.is_empty():
		return
	subtitle_time -= delta
	if subtitle_time <= 0 and not (is_instance_valid(player) and player.playing):
		current = ""
		_next()

func speaking() -> bool:
	return not current.is_empty()

func subtitle() -> Dictionary:
	if current.is_empty():
		return {}
	var line: Dictionary = LINES[current]
	return {"speaker":line.speaker,"text":line.text,"hint":line.get("hint",""),"style":line.style}
