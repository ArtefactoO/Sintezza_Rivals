-- English strings are the keys. Add Russian text without changing argument order.

local ADDON, root = ...
local ns = root.PvP

local L = {}

L.ruRU = {
    ["v%s: /rivals opens the window. Right-click the minimap icon for PvP history."] = "v%s: /rivals открывает окно, ПКМ по мечам — историю PvP.",
    ["v%s loaded."] = "Загружена версия %s.",
    ["enemy nameplates are off (Ctrl+V turns them on): Sintezza Rivals sees most enemies through their nameplates"] =
        "Неймплейты противников выключены. Нажми Ctrl+V, чтобы Sintezza Rivals мог замечать противников.",
    ["/rivals marks opens marker previews. /rivals config opens all settings."] = "/rivals marks открывает предпросмотр меток, /rivals config — все настройки.",
    ["Enemies"] = "Противники", ["Duels"] = "Дуэли", ["Stats"] = "Статистика",
    ["All seen"] = "Все встреченные", ["Nearby now"] = "Рядом", ["Ignored"] = "В игноре",
    ["By enemy"] = "По игрокам", ["Kills & deaths"] = "Убийства и смерти", ["Options"] = "Настройки",
    ["Settings"] = "Настройки", ["Features"] = "Функции",
    ["Detection"] = "Обнаружение", ["Alerts"] = "Оповещения", ["Chat"] = "Чат", ["Map"] = "Карта",
    ["Sharing"] = "Обмен данными", ["Window"] = "Окно", ["Tools"] = "Инструменты", ["Data"] = "Данные",
    ["Enemy"] = "Противник", ["Level"] = "Уровень", ["Race"] = "Раса", ["Last seen in"] = "Где замечен",
    ["Coords"] = "Координаты", ["Source"] = "Источник", ["Seen"] = "Встречи", ["Last"] = "Когда",
    ["Players"] = "Игроки", ["Deaths"] = "Смерти", ["Kills"] = "Убийства", ["Zone"] = "Зона",
    ["Killed you"] = "Убил тебя", ["You killed"] = "Ты убил", ["Watched"] = "Отслеживаемые",
    ["%s (%s) spotted in %s"] = "%s (%s) замечен: %s",
    ["|cffff2020WATCHED|r %s (%s) spotted via %s, %s"] = "|cffff2020МЕТКА|r %s (%s) замечен: %s, %s",
    ["Killed by %s (%s)"] = "Тебя убил игрок %s (%s)",
    ["You died. Killer unknown."] = "Ты погиб. Убийца неизвестен.",
    ["sure"] = "высокая уверенность", ["likely"] = "вероятно", ["guess"] = "предположительно",
    [" · Most damage from %s (%d%%)"] = " · Больше всего урона нанес игрок %s (%d%%)",
    ["You killed %s"] = "Ты убил игрока %s.",
    ["|cffff8000%s|r: %d of your deaths here, %d enemies seen in the last hour"] =
        "|cffff8000%s|r · Твоих смертей: %d, противников за последний час: %d",
    ["this zone"] = "Эта зона", ["someone"] = "Кто-то",
    ["|cffff8000%s went into stealth|r right next to you"] = "|cffff8000%s ушел в скрытность|r рядом с тобой.",
    ["%s went into stealth"] = "%s ушел в скрытность", ["within nameplate range"] = "В радиусе видимости неймплейтов",
    ["|cffff5555STEALTH|r"] = "|cffff5555СКРЫТНОСТЬ|r",
    ["%s is here"] = "%s рядом", ["%s spotted: %s"] = "Обнаружен игрок %s · %s",
    ["%s killed you %dx, added to the watchlist"] = "Игрок %s убил тебя %d раз. Включено отслеживание.",
    ["alerts for %s are back on"] = "Оповещения об игроке «%s» включены.",
    ["ignoring %s: no more alerts about them"] = "Оповещения об игроке «%s» отключены.",
    ["duel won against %s"] = "Победа в дуэли с игроком «%s».", ["duel lost to %s"] = "Поражение в дуэли с игроком «%s».",
    ["duel with %s finished, result unreadable"] = "Дуэль с игроком «%s» завершена. Результат неизвестен.",
    ["Duel results"] = "Результаты дуэлей",
    ["PvP history: Duels"] = "История PvP: дуэли",
    ["Duel results and your record against each opponent."] = "Результаты отдельных дуэлей и счет по соперникам.",
    ["Click a name to open the opponent card."] = "Нажми на имя, чтобы открыть карточку соперника.",
    ["Which tab the window starts on."] = "Раздел, который открывается первым.",
    ["Every duel"] = "Все дуэли", ["By opponent"] = "По соперникам",
    ["By class"] = "По классам", ["Class"] = "Класс", ["Unknown class"] = "Класс неизвестен",
    ["Unknown"] = "неизвестен", ["Unknown outcomes"] = "Без исхода",
    ["Duel count"] = "Дуэлей", ["Duel wins"] = "Побед", ["Duel losses"] = "Поражений", ["Last duel"] = "Последняя дуэль",
    ["Duel classes: %d"] = "Классов в списке: %d", ["Class filter: %s"] = "Класс: %s",
    ["Click a class to see its duels."] = "Нажми на класс, чтобы посмотреть дуэли против него.",
    ["search opponent, class or zone"] = "Имя, класс или зона",
    ["Opponent"] = "Соперник", ["Result"] = "Результат", ["Fought in"] = "Где",
    ["Record"] = "Победы / поражения", ["Win rate"] = "Доля побед", ["Last result"] = "Последний результат",
    ["When"] = "Когда", ["Duel win"] = "Победа", ["Duel loss"] = "Поражение",
    ["Duel result unknown"] = "Неизвестен",
    ["opponent fled"] = "соперник покинул дуэль", ["you fled"] = "ты покинул дуэль",
    ["No recorded duels"] = "Записей о дуэлях пока нет", ["No matching duels"] = "Дуэли не найдены",
    ["Duels listed: %d"] = "Дуэлей в списке: %d", ["Duel opponents: %d"] = "Соперников в списке: %d",
    ["Unknown results"] = "Неизвестных результатов",
    ["%ds"] = "%d с", ["%dm"] = "%d мин", ["%dh"] = "%d ч", ["%dd"] = "%d д",
    ["%dm %02ds"] = "%d мин %02d с", ["%d rows"] = "Строк: %d",
    ["Language"] = "Язык", ["Match the game client"] = "Как в клиенте", ["Layout"] = "Оформление",
    ["Modern"] = "Современное", ["Classic"] = "Классическое", ["Window opacity"] = "Непрозрачность окна",
    ["Window scale"] = "Масштаб окна", ["Minimap button"] = "Кнопка у миникарты",
    ["Open the window on"] = "Вкладка при открытии", ["Last used"] = "Последняя открытая",
    ["open-world intel: who is out there, who keeps killing you, and where"] = "Встречи и бои в открытом мире",
    ["Every enemy player seen, newest first."] = "Противники по времени последней встречи.",
    ["Who kills you, who you killed back, and who others reported."] = "Соперники, добивания и сообщения союзников.",
    ["Window and buttons"] = "Окно и кнопки",
    ["Markers and map"] = "Метки на карте", ["Sharing with other players"] = "Обмен с другими игроками",
    ["Left-click opens the window. Right-click opens PvP history."] = "ЛКМ открывает окно, ПКМ — историю PvP.",

    ["search every setting"] = "Поиск по настройкам",
    ["No matching settings in this category."] = "В этой категории ничего не найдено.",
    ["Open the Sintezza Rivals settings window."] = "Открой окно настроек Sintezza Rivals.",
    ["Open Sintezza Rivals settings"] = "Открыть настройки",
    ["Switch off the parts you do not want. A change needs a reload."] = "Отключи ненужные функции. Изменения вступят в силу после перезагрузки интерфейса.",
    ["What gets recorded, and when you are warned about a zone."] = "Что записывать и когда предупреждать об опасных зонах.",
    ["How the addon tells you something happened."] = "Когда показывать баннеры и воспроизводить звуки.",
    ["What reaches the chat frame"] = "Сообщения в чате",
    ["World map pins and minimap blips."] = "Метки на карте мира и миникарте.",
    ["Size, position and the ways to open the addon."] = "Размер, положение и способы открыть окно.",
    ["Everything the addon can do on demand. None of it needs a typed command."] = "Действия и диагностика.",
    ["Your data"] = "Сохраненные данные",
    ["Copy it out, hand it over, or clear parts of it."] = "Экспорт, использование памяти и очистка данных.",
    ["Enemies and sightings"] = "Встречи с противниками",
    ["Records every enemy player you see. Enemies, Zones, nameplate markers, the tooltip line and the stealth warning."] = "Записывает встречи с противниками и включает предупреждение об уходе в скрытность.",
    ["Kills and deaths"] = "Убийства и смерти",
    ["Your PvP deaths with the killer and everyone who hit you, and your kills. Threats and the kill tally."] = "Записывает убийства и смерти в PvP. По сводке о смерти показывает нападавших.",
    ["Every duel you fight and your record against each opponent."] = "Записывает дуэли и результаты по каждому сопернику.",
    ["Map and minimap pins"] = "Метки на карте и миникарте",
    ["Where enemies were seen, where you died, and where you won, on the world map and the minimap."] = "Показывает места встреч, смертей и убийств.",
    ["Addon enabled"] = "Аддон включен",
    ["Master switch. With this off nothing is recorded at all."] = "Управляет записью событий.",
    ["Watch nameplates"] = "Отслеживать неймплейты",
    ["Record an enemy the moment their nameplate appears. This catches the most."] = "Записывает встречу при появлении неймплейта противника.",
    ["Watch your target"] = "Отслеживать цель",
    ["Record whoever you target."] = "Записывает встречу при выборе противника в цель.",
    ["Watch mouseover"] = "Отслеживать наведение мыши",
    ["Record whoever you hover the mouse over."] = "Записывает встречу при наведении курсора на противника.",
    ["Same enemy counts again after"] = "Интервал между встречами с одним игроком",
    ["A sighting inside this window only bumps the counter instead of alerting again."] = "Повторное обнаружение в пределах интервала обновляет сведения без нового оповещения.",
    ["Warn me when I enter a dangerous zone"] = "Предупреждать при входе в опасную зону",
    ["On zone change: how often you died there and how many enemies were seen in the last hour."] = "При входе показывает число смертей в зоне и противников за последний час.",
    ["Watched enemy spotted"] = "Замечен отслеживаемый противник",
    ["You died"] = "Ты погиб",
    ["You killed somebody"] = "Ты убил противника",
    ["Duel results"] = "Результаты дуэлей",
    ["Entering a dangerous zone"] = "Вход в опасную зону",
    ["Every new enemy seen"] = "Каждый замеченный противник",
    ["Off by default: in a busy zone this is a line every few seconds."] = "В оживленной зоне сообщения могут появляться каждые несколько секунд.",
    ["Your own actions"] = "Твои действия",
    ["Watching and ignoring players. Off by default."] = "Изменения в списках отслеживания и игнора.",
    ["Banner for watched enemies"] = "Баннер при встрече с отслеживаемым противником",
    ["A notice near the top of the screen when a watched enemy turns up. Drag it where you like, click it to dismiss. This is the signal you can rely on."] = "Баннер можно перетащить или закрыть щелчком.",
    ["Sound for watched enemies"] = "Звук при встрече с отслеживаемым противником",
    ["Plays the raid-warning sound with the banner. Never on a flight path."] = "Воспроизводит звук рейдового предупреждения. Во время перелета звук отключен.",
    ["Warn when someone stealths next to you"] = "Предупреждать об уходе в скрытность рядом",
    ["A rogue or druid casting Stealth, Vanish or Prowl within nameplate range: a banner and a line, because after that there is nothing to see."] = "Оповещает, когда разбойник или друид уходит в скрытность в радиусе видимости неймплейтов.",
    ["A line on unit tooltips"] = "Сведения в подсказке игрока",
    ["Adds what the addon knows to the game's own tooltip when you hover a player: times they killed you, times you killed them, times seen, watched."] = "Показывает встречи, счет убийств и состояние отслеживания.",
    ["Same enemy may alert again after"] = "Интервал между оповещениями",
    ["A per-enemy cooldown, so a long fight does not repeat the alert."] = "Отдельно для каждого противника.",
    ["Ignore enemies this far below you"] = "Порог оповещения по разнице уровней",
    ["A level difference. At -5 an enemy five or more levels under you is recorded but never alerts, because they are not a threat. Zero alerts on everyone."] = "При −5 противники на пять и более уровней ниже записываются без оповещений. При 0 оповещения включены для всех.",
    ["everyone alerts"] = "Все противники",
    ["%d levels"] = "%d ур.",
    ["%d s"] = "%d с",
    ["%d min"] = "%d мин",
    ["Different sound for rogues and druids"] = "Отдельный звук для разбойников и друидов",
    ["The ambushers get a sharper sound, so you know what kind of trouble it is before you look."] = "Позволяет узнать о встрече с этими классами по звуку.",
    ["Screenshot when you die"] = "Снимок экрана при смерти",
    ["Takes a screenshot the moment you go down. Off by default."] = "Игра делает снимок в момент смерти.",
    ["Try it"] = "Проверка оповещения",
    ["Shows exactly what a watched-enemy alert looks like."] = "Показывает пример баннера.",
    ["Test alert"] = "Показать пример",
    ["Watched enemy nearby"] = "Отслеживаемый противник рядом",
    ["Level 60, Tarren Mill"] = "Уровень 60, Мельница Таррен",
    ["Pins for enemy sightings"] = "Места встреч с противниками",
    ["Pins for your deaths"] = "Места твоих смертей",
    ["Pins for your kills"] = "Места твоих убийств",
    ["Hand coordinates to TomTom as well"] = "Передавать координаты в TomTom",
    ["When TomTom is installed, clicking a coordinate also sets a waypoint there."] = "При открытии координат TomTom ставит точку маршрута, если он установлен.",
    ["Hide sightings older than"] = "Скрывать встречи старше",
    ["Deaths and kills are always shown."] = "Срок действует только для встреч.",
    ["Minimap blips"] = "Метки на миникарте",
    ["Marks where you saw an enemy last. It is your own position at the time, not theirs now."] = "Отмечает место, где ты находился при последней встрече.",
    ["Minimap: watched enemies only"] = "Только отслеживаемые противники",
    ["Off shows every recent sighting."] = "При выключении видны все недавние встречи.",
    ["Keep watched blips on the minimap edge"] = "Показывать дальние метки на краю миникарты",
    ["When they were last seen further away than the minimap reaches, the blip sticks to the rim so the direction still reads."] = "Метка на краю показывает направление к месту встречи.",
    ["Your deaths on the minimap"] = "Смерти на миникарте",
    ["Hide blips older than"] = "Скрывать метки старше",
    ["Look"] = "Внешний вид",
    ["Choose a theme. Changes apply after reloading the interface."] = "Тема меняется после перезагрузки интерфейса.",
    ["Graphite, brass and teal."] = "Графит, латунь и бирюза.",
    ["Flat dark panels, blue accent. The default."] = "Темные панели с синими акцентами.",
    ["Warmer, in the game's own gold and bronze, closer to the default interface."] = "Золото и бронза в стиле интерфейса WoW.",
    ["Reload the interface to apply the layout?"] = "Перезагрузить интерфейс, чтобы применить оформление?",
    ["Reload the interface to apply the change?"] = "Перезагрузить интерфейс, чтобы применить изменения?",
    ["Reload"] = "Перезагрузить", ["Later"] = "Позже",
    ["Applies after reloading the interface."] = "Вступает в силу после перезагрузки интерфейса.",
    ["layout set to %s; reload to see it"] = "Выбрано оформление «%s». Перезагрузи интерфейс.",
    ["language set; reload to see it"] = "Язык выбран. Перезагрузи интерфейс.",
    ["Opening it"] = "Открытие окна",
    ["Which tab the window starts on."] = "Вкладка, которая открывается первой.",
    ["Keybindings"] = "Клавиши",
    ["Opens the game key bindings; look for the Sintezza Rivals section."] = "Откроет настройки клавиш WoW. Ищи раздел Sintezza Rivals.",
    ["Open bindings"] = "Открыть клавиши",
    ["open Game Menu, then Key Bindings, and look for Sintezza Rivals"] = "Открой настройки клавиш WoW и найди раздел Sintezza Rivals.",
    ["On-screen strip"] = "Панель на экране",
    ["Show the strip"] = "Показать панель",
    ["A thin bar you leave on screen: recent enemy sightings in this zone and watched enemies nearby."] = "Показывает недавние встречи в зоне и отслеживаемых противников поблизости.",
    ["Lock the strip"] = "Закрепить панель",
    ["Stops dragging it around."] = "Запрещает перетаскивать панель.",
    ["Position"] = "Положение", ["Lock the window"] = "Закрепить окно",
    ["Stops dragging and resizing it."] = "Запрещает перемещать окно и менять размер.",
    ["First-run guide"] = "Первое знакомство",
    ["The welcome window again: layout and the things worth knowing."] = "Повторно открыть окно знакомства с аддоном.",
    ["Show it"] = "Открыть", ["Window position"] = "Положение окна",
    ["Puts the window back in the middle of the screen at its default size."] = "Возвращает обычный размер и перемещает окно в центр экрана.",
    ["Reset"] = "Сбросить",
    ["In a fight"] = "Противники", ["Toggle target watch"] = "Отслеживание выбранной цели",
    ["Adds or removes whoever you have targeted. There is a key binding for this too."] = "Добавляет или убирает цель из списка отслеживания. Действию можно назначить клавишу.",
    ["Watch target"] = "Отслеживание цели",
    ["When something looks wrong"] = "Диагностика", ["Status"] = "Состояние аддона",
    ["Prints where you are, what is stored and the last error."] = "Выводит текущую зону, объем данных и последнюю ошибку.",
    ["Show status"] = "Показать состояние", ["Report a problem"] = "Отчет о проблеме",
    ["Builds a text block with the version, client build, where you were, the data counts and the last errors, ready to paste on the project page with what happened."] = "Собирает версии аддона и клиента, сведения о зоне и последние ошибки для отчета.",
    ["Build report"] = "Собрать отчет", ["Map pin diagnosis"] = "Проверка меток карты",
    ["Prints what the map code sees: the canvas, which map is open, how many pins and how much data there is."] = "Выводит текущую карту, число меток и объем данных.",
    ["Check map pins"] = "Проверить метки",
    ["Take it out"] = "Экспорт", ["Everything as CSV"] = "Экспорт в CSV",
    ["Sightings, deaths and kills in one text box, ready to paste into a spreadsheet."] = "Готовит встречи, смерти и убийства для вставки в таблицу.",
    ["Copy CSV"] = "Копировать CSV", ["Memory"] = "Память",
    ["Keep memory tidy by itself"] = "Автоматическая очистка памяти",
    ["Nudges the garbage collector along every twenty seconds out of combat, so the figure in the add-on list stays near what the addon actually holds. Costs a fraction of a millisecond."] = "Освобождает неиспользуемую память раз в 20 секунд вне боя.",
    ["Memory in use"] = "Использование памяти",
    ["What the addon uses now, and how much is stored."] = "Показывает объем памяти и число сохраненных записей.",
    ["Show"] = "Показать", ["Tidy up"] = "Очистить", ["Clear"] = "Очистка",
    ["The watchlist"] = "Список отслеживания",
    ["Removes every watched enemy. Sightings, deaths and kills are kept."] = "Убирает всех противников из списка отслеживания. История сохраняется.",
    ["Clear watchlist"] = "Сбросить список", ["The ignore list"] = "Список игнора",
    ["Removes everyone you told the addon to stay quiet about."] = "Возвращает оповещения для всех игроков из списка игнора.",
    ["Clear ignored"] = "Сбросить игнор",
    ["Clear log"] = "Очистить журнал", ["Clear errors"] = "Очистить ошибки",
    ["Everything recorded"] = "История событий",
    ["Clears sightings, deaths, kills and duels from this database. Settings and the watchlist are kept. There is no undo."] = "Безвозвратно удаляет встречи, смерти, убийства и дуэли из этой базы. Настройки и список отслеживания сохраняются.",
    ["Clears sightings, deaths, kills, battlegrounds and duels from this database. Settings and the watchlist are kept. There is no undo."] = "Безвозвратно удаляет встречи, смерти, убийства, матчи на полях боя и дуэли из этой базы. Настройки и список отслеживания сохраняются.",
    ["Clear recorded sightings, deaths, kills, battlegrounds and duels?"] = "Удалить записи о встречах, смертях, убийствах, матчах на полях боя и дуэлях?",
    ["Forget everything"] = "Очистить записи", ["Clear recorded sightings, deaths, kills and duels?"] = "Удалить записи о встречах, смертях, убийствах и дуэлях?",
    ["Forget"] = "Удалить", ["Cancel"] = "Отмена",
    ["watchlist cleared"] = "Список отслеживания очищен.",
    ["ignore list cleared"] = "Список игнора очищен.",
    ["error list cleared"] = "Список ошибок очищен.",
    ["all recorded data cleared"] = "История очищена.",
    ["Diagnostics"] = "Диагностика",
    ["Logging and the API probe. All off by default."] = "Журнал и диагностика API. По умолчанию выключены.",
    ["Demo data"] = "Демонстрационные данные", ["Add"] = "Добавить",
    ["Fills every table with made-up records, marked as demo in the window. Clear removes exactly what it added."] = "Добавляет тестовые записи с отметкой «Демо». Очистка удаляет эти записи.",
    ["Interface self test"] = "Самопроверка интерфейса", ["Run self test"] = "Запустить",
    ["Drives every tab, view, sort, scroll, popup and the message parser, and reports anything that errors."] = "Проверяет вкладки, сортировку, прокрутку, окна и разбор сообщений.",
    ["Keep an internal log"] = "Вести журнал диагностики",
    ["Off by default. Warnings and errors are always kept; this adds the chatty info lines, useful only when something needs diagnosing."] = "Добавляет служебные сообщения. Ошибки и предупреждения записываются всегда.",
    ["Capture raw chat payloads"] = "Сохранять исходные сообщения чата",
    ["Keeps system and honor messages as they were received. Off by default."] = "Сохраняет исходный текст системных сообщений и сообщений о чести.",
    ["Log line limit"] = "Предел строк журнала",
    ["Run the API probe automatically"] = "Запускать диагностику API автоматически",
    ["The probe mapped this client already. Leaving it off saves memory and a battery run on every context change; /rivals probe still works. Takes effect after a reload."] = "Проверяет API при смене игрового контекста. Настройка вступает в силу после перезагрузки интерфейса.",
    ["Run the probe now"] = "Диагностика API", ["Run probe"] = "Запустить",
    ["Re-runs the API diagnostic for the context you are in and prints a summary."] = "Проверяет API в текущих условиях и выводит результат.",
    ["Print the full probe result"] = "Подробности диагностики", ["Probe dump"] = "Показать отчет",
    ["One line per API call for the context you are in: ok, secret, nil, error, missing or blocked."] = "Выводит результат каждого вызова API.",
    ["Check the probe's own logic"] = "Проверка диагностики", ["Run check"] = "Проверить",
    ["A tiny self test of the classifier that decides ok / secret / nil / error."] = "Проверяет, как распознаются результаты вызовов API.",
    ["Re-test the combat log"] = "Проверка журнала боя", ["Test combat log"] = "Проверить",
    ["Tries to register the combat log again. It is forbidden on this client, so expect the blocked popup."] = "Пробует подключиться к журналу боя. Клиент может показать предупреждение о блокировке.",

    ["Player"] = "Игрок", ["everything recorded about one player"] = "Сведения об игроке",
    ["Alliance"] = "Альянс", ["Horde"] = "Орда",
    ["WATCHED"] = "ОТСЛЕЖ.", ["IGNORED"] = "ИГНОР",
    ["Level %d"] = "Уровень %d", ["Watch"] = "Отслеживать", ["Unwatch"] = "Не отслеживать",
    ["Ignore"] = "Игнорировать", ["Stop ignoring"] = "Снять игнор",
    ["Show on map"] = "Показать на карте", ["Copy"] = "Копировать", ["Actions"] = "Действия",
    ["Last sighting on map"] = "Последняя встреча на карте",
    ["Hide nameplate marker"] = "Скрыть метку на неймплейте", ["Restore nameplate marker"] = "Вернуть метку на неймплейте",
    ["Marked spot"] = "Отмеченное место",
    ["%s %s, level %s"] = "%s %s, уровень %s",
    ["%s, %s ago, seen %dx"] = "%s, %s назад, встреч: %d",
    ["an earlier spot on their route"] = "Место одной из предыдущих встреч.",
    ["You died here"] = "Ты погиб здесь",
    ["Killer: %s"] = "Убийца: %s", ["unknown"] = "неизвестно",
    ["no coordinates for that one"] = "Для этой записи нет координат.",
    ["times they killed you"] = "Сколько раз тебя убил", ["times you killed them"] = "Сколько раз ты его убил",
    ["duels won / lost"] = "Победы и поражения в дуэлях",
    ["Where"] = "Где встречались", ["Between you"] = "Ваши бои",
    ["last seen"] = "Последняя встреча", ["exactly"] = "Место и координаты",
    ["times seen"] = "Число встреч", ["usually around"] = "Обычно около",
    ["nameplate"] = "Неймплейт", ["target"] = "Цель", ["mouseover"] = "Наведение мыши",
    ["last fought"] = "Последний бой", ["kills you most in"] = "Чаще всего убивает в зоне",
    ["hit you in"] = "Урон перед смертью", ["most damage"] = "Нанес больше всех", ["known for"] = "Примечания",
    ["%d of your deaths, %d damage"] = "Смертей: %d, урон: %d", ["in %d of them"] = "В %d боях",
    ["%d, first %s"] = "%d, первая %s назад",
    ["win rate"] = "Доля побед", ["last duel"] = "Последняя дуэль",
    ["fought in"] = "Место дуэли", ["length"] = "Длительность",
    ["%.0f%% of %d"] = "%.0f%% из %d", [", %d not read"] = ", без результата: %d",
    ["you won"] = "победа", ["you lost"] = "поражение", ["result not read"] = "результат неизвестен",
    ["%s average, %s longest"] = "%s в среднем, %s максимум",
    ["no longer watching %s"] = "Отслеживание игрока %s выключено.",
    ["watching %s: you will be told when you spot them"] = "Включены оповещения о встречах с игроком %s.",
    ["the watchlist is full (%d); unwatch someone first"] = "Список отслеживания заполнен (%d). Сначала убери кого-нибудь из списка.",
    ["target an enemy player first"] = "Выбери вражеского игрока.",
    ["In combat"] = "В бою", ["Paused"] = "Приостановлено",
    ["Times seen"] = "Число встреч", ["Side"] = "Фракция",
    ["Enemies are still recorded; alerts that need a closer look wait until the fight ends."] = "Встречи записываются. Часть оповещений появится после боя.",
    ["Arenas are not world PvP. Nothing is recorded here."] = "На арене история открытого мира приостановлена.",
    ["Inside a dungeon. Nothing is recorded until you are back outside."] = "В подземелье история открытого мира приостановлена.",
    ["Inside a raid. Nothing is recorded until you are back outside."] = "В рейде история открытого мира приостановлена.",

    ["Known for"] = "Примечания", ["Lone wolf"] = "Одиночка",
    ["most of their kills on you were alone"] = "Чаще всего убивал тебя в одиночку.",
    ["Pack hunter"] = "Охотник в группе", ["usually kills you with two or more others"] = "Обычно убивает тебя вместе с двумя и более игроками.",
    ["Lowbie farmer"] = "Охотник на младших", ["killed you twice or more while ten or more levels above you"] = "Убил тебя минимум дважды, будучи на десять или более уровней выше.",
    ["Camper"] = "Кемпер", ["killed you three times inside one hour"] = "Убил тебя трижды за час.",
    ["Giant slayer"] = "Убийца великанов", ["killed you while five or more levels below you"] = "Убил тебя, будучи на пять или более уровней ниже.",
    ["Welcome to Sintezza Rivals"] = "Знакомство со Sintezza Rivals",
    ["Choose a layout and the features you want to use."] = "Выбери оформление и нужные функции.",
    ["Let's go"] = "Готово",
    ["1. Pick a layout"] = "Оформление", ["2. What do you want to use"] = "Функции", ["3. Worth knowing"] = "Управление",
}

ns.LOCALE = root.locale == "ruRU" and L.ruRU or {}

local ru = L.ruRU
ru["BLOCKED func=%s on item=%s, skipped from now on"] = "Заблокировано: %s, запись %s. Повтор отключен."
ru["context=%s zone=%s%s mapID=%s"] = "Контекст %s · Зона %s%s · ID карты %s"
ru["build=%s %s interface=%s addon=%s"] = "Клиент %s %s · Интерфейс %s · Аддон %s"
ru["probed: %s"] = "Проверено: %s"
ru["log=%d raw-kinds=%d errors=%d blocked=%d"] = "Строк журнала %d · Типов сообщений %d · Ошибок %d · Блокировок %d"
ru["blocked: %s -> %s"] = "Заблокировано: %s → %s"
ru["sightings=%d zones=%d deaths=%d kills=%d nemesis=%d (alerts %s)"] = "Встречи %d · Зоны %d · Смерти %d · Добивания %d · Противники %d · Оповещения %s"
ru["secret/missing sighting fields: %s"] = "Скрытые или отсутствующие поля встреч: %s"
ru["last error: %s"] = "Последняя ошибка: %s"
ru["the probe module is not installed: add the RivalsPvP_Probe folder next to this one"] = "Модуль RivalsPvP_Probe не установлен."
ru["tidied up, now holding %.2f MB"] = "После сборки мусора: %.2f МБ"
ru["tidied up"] = "Сборка мусора завершена."
ru["|cff40ff40live: %.2f MB|r%s   (before the collect: %.2f MB, so %.1f MB was garbage)"] =
    "|cff40ff40Память: %.2f МБ|r%s · До сборки %.2f МБ · Освобождено %.1f МБ"
ru["the whole interface, every addon included: %.1f MB"] = "Все аддоны: %.1f МБ"
ru["twenty window rebuilds left %+.0f KB behind; anything under ~20 KB is noise"] =
    "После 20 обновлений окна: %+.0f КБ (менее 20 КБ — погрешность)"
ru["memory API unavailable"] = "Замер памяти недоступен."
ru["stored: %d sightings, %d zones, %d deaths, %d kills, %d nemesis, %d watched"] =
    "Встречи %d · Зоны %d · Смерти %d · Добивания %d · Противники %d · Наблюдение %d"
ru["logs: %d lines (cap %d), %d errors, %d probe rows in %d contexts"] =
    "Журнал %d из %d строк · Ошибки %d · Проверки %d в %d контекстах"
ru["the probe results are the biggest thing stored; |cffffd100/rivals clear probe|r frees them"] =
    "|cffffd100/rivals clear probe|r очищает результаты проверки API."
ru["logging=%s raw=%s probe autoRun=%s; all three are off by default"] =
    "Журнал %s · Запись сообщений %s · Автопроверка API %s"
ru["measuring what the addon allocates for 20 seconds..."] = "Замер выделения памяти на 20 секунд."
ru["allocating about %.1f KB/s (%.1f MB an hour) with the window %s"] = "Выделено около %.1f КБ/с (%.1f МБ/ч) · Окно %s"
ru["selftest FAIL: classifier missing"] = "Самопроверка недоступна: нет классификатора."
ru["selftest: expected %s, got %s"] = "Самопроверка: ожидалось %s, получено %s"
ru["selftest %s (%d/%d)"] = "Самопроверка %s (%d/%d)"
ru["usage: /rivals clear log|errors|probe|raw|all"] = "Команда /rivals clear log|errors|probe|raw|all"
ru["repeat /rivals clear %s within 10s to confirm"] = "Для подтверждения повтори /rivals clear %s в течение 10 сек."
ru["cleared %s"] = "Очищено: %s"
ru["export stamped (%d contexts, %d errors). Now /reload or logout, then send:"] =
    "Отчет подготовлен: контекстов %d, ошибок %d. Сохрани через /reload или выход из игры."
ru["a chat line for every new enemy: %s"] = "Новые противники в чате: %s"
ru["watching: %s (%s)%s"] = "Наблюдение: %s (%s)%s"
ru["watchlist empty: right-click a row in the window, or use /rivals watch target"] = "Список наблюдения пуст."
ru["minimap blips %s"] = "Точки на миникарте: %s"
ru["window %s"] = "Окно %s"
ru["scale %.2f"] = "Масштаб %.2f"
ru["usage: /rivals scale 0.5-2.0"] = "Команда /rivals scale 0.5-2.0"
ru["window position reset"] = "Положение окна сброшено."
ru["map: path=%s shown=%s map %s = %s pins=%s"] = "Карта: путь %s · Показ %s · ID %s = %s · Метки %s"
ru["canvas size %.0f x %.0f"] = "Размер карты %.0f × %.0f"
ru["data: %d sightings, %d deaths, %d kills | cfg enabled=%s minutes=%d"] = "Встречи %d · Смерти %d · Добивания %d · Показ %s · Минуты %d"
ru["    hint: %s"] = "    Сообщение: %s"
ru["#%d %s%s %.1f,%.1f killer=%s (%s, %s) %ds in combat"] = "#%d %s%s %.1f,%.1f · Убийца %s (%s, %s) · В бою %d с"
ru["--- last %d of %d deaths ---"] = "Последние смерти: %d из %d"
ru["nemesis: %s (%s) killed me %d, killed by me %d"] = "Противник %s (%s) · Убил меня %d · Я убил %d"
ru["no deaths recorded"] = "Нет записей о смертях."
ru["the on-screen strip is %s"] = "Панель встреч %s"
ru["%s (%d): %d sightings, %d players, %d deaths, %d kills, %s ago%s"] = "%s (%d) · Встречи %d · Игроки %d · Смерти %d · Добивания %d · %s назад%s"
ru["%s L%s %s - %s ago - %sx - %s"] = "%s, ур. %s · %s · %s назад · %s раз · %s"
ru["--- last %d of %d sightings ---"] = "Последние встречи: %d из %d"
ru["--- zones ---"] = "Зоны"
ru["no sightings yet"] = "Нет записей о встречах."
ru["no zone data yet"] = "Нет записей по зонам."
ru["on"] = "вкл."
ru["off"] = "выкл."
ru["locked"] = "закреплено"
ru["unlocked"] = "разблокировано"
ru["open"] = "открыто"
ru["closed"] = "закрыто"
ru["shown"] = "видна"
ru["hidden"] = "скрыта"
