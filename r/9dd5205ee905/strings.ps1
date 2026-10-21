$AllStrings = @{
    ru = @{
        AppTitle     = 'autosettings.win - настройка приватности Windows'
        OsLine       = '{0}, сборка {1}, {2}'
        ArchX64      = 'x64'
        ArchArm64    = 'ARM64'
        ArchX86      = 'x86, 32 бита'
        ArchTitle    = 'Не удалось узнать, какой в компьютере процессор. От этого зависит, какие программы подойдут.'
        ArchPick1    = '[1] Intel или AMD, 64-битная Windows - почти все компьютеры'
        ArchPick2    = '[2] ARM - Snapdragon и другие процессоры ARM'
        ArchPick3    = '[3] 32-битная Windows'
        ArchWhere    = 'Где посмотреть: Параметры - Система - О системе, строка «Тип системы».'
        ArchAsk      = 'Номер'
        PreTitle     = 'Перед началом стоит знать:'
        PreReboot    = 'Windows ждёт перезагрузки после обновления или установки. Часть настроек может не встать, пока компьютер не перезагружен.'
        PreSpace     = 'На системном диске свободно {0} ГБ. Программам и обновлениям этого может не хватить.'
        PreAccount   = 'Окно открыто от имени {0}, а в Windows вошёл {1}. Личные настройки запишутся для {0}.'
        PreAsk       = 'Enter - продолжить, 0 - выйти'
        ChooseLang   = 'Выберите язык:'
        LangRu       = '[1] Русский'
        LangEn       = '[2] English'
        LangEnter    = '(Enter - {0})'
        LangRuName   = 'Русский'
        LangEnName   = 'English'
        LangAsk      = 'Язык'
        MenuTitle    = 'Что настроить:'
        SectionPrivacy = 'Приватность'
        SectionSystem  = 'Система'
        SectionPresets = 'Готовые наборы'
        SectionDev   = 'Для разработчика'
        EditionNote  = 'Полностью отключить телеметрию можно только на Enterprise/Education; на Home/Pro минимум - «Обязательные данные».'
        WtOffer      = 'Можно поставить современный терминал Windows (Windows Terminal) - меню будет выглядеть приятнее.'
        WtAsk        = 'Поставить Windows Terminal? (y/n)'
        WtInstalling = 'Происходит магия: ставим Windows Terminal...'
        WtInstalled  = 'Windows Terminal установлен. В следующий раз запустите установку в нём - будет красивее.'
        WtFail       = 'Не удалось поставить Windows Terminal. Продолжаем в текущем окне.'
        MenuLang     = 'l - язык / language'
        MenuHint     = '/слово - поиск    2.3 - сразу в пункт'
        MenuBack     = '0 - назад'
        CountOf      = '{0} из {1}'
        WtHint       = 'В Windows Terminal меню выглядит лучше - его можно поставить в пункте {0}.'
        SearchTitle  = 'Поиск: {0}'
        SearchNone   = 'Ничего не найдено. Попробуйте другое слово.'
        SearchIn     = 'внутри: {0}'
        SearchNotHere = 'на этом компьютере ({0}) не работает: {1}'
        NotHere      = 'На этом компьютере ({0}) это не работает, поэтому в меню этого нет.'
        MenuExit     = '0 - выход'
        MenuChanged  = 'j - что изменено и возврат'
        ChangedTitle = 'Что изменено на этом компьютере'
        ChangedEmpty = 'Сейчас здесь нет настроек, которые изменил autosettings.win.'
        ChangedModules = 'Терминал, DNS, сертификаты и программы возвращаются на своих экранах буквой r.'
        ChangedActions = 'Номер - вернуть как было (можно несколько: 1 3)    r - вернуть всё    0 - назад'
        ChangedBad   = 'Не понял выбор. Введите номера из списка или r.'
        MenuAsk      = 'Номер пункта'
        NeedBuild    = '{0} - нужна сборка Windows от {1}'
        NotForWin    = 'Этот пункт не подходит для вашей версии Windows.'
        PickHint     = 'Введите номера пунктов через пробел, чтобы применить (например: 1 3).'
        PickActions  = 'a - применить все    r - вернуть как было    0 - назад'
        PresetModules   = 'Ещё в наборе - отдельным шагом, после вопроса:'
        PtTitle      = 'Перенос программ'
        PtLead       = @('Сохрани список своих программ в файл, а на новом или переустановленном компьютере поставь их одной командой.', 'Файлы лежат в папке «Документы\AutoSettings.win\programs» - их можно перенести на флешке.')
        PtActions    = '1 - сохранить список программ    2 - поставить программы из файла    0 - назад'
        PtNoWinget   = 'На компьютере нет winget - поставь «Установщик приложений» из Microsoft Store.'
        PtNoDir      = 'Не получилось открыть папку для списков: {0}'
        PtExporting  = 'Сохраняю список программ'
        PtExported   = 'Список сохранён, программ в нём: {0}.'
        PtExportFail = 'Список сохранить не получилось.'
        PtNoFiles    = 'Списков пока нет. Сначала сохрани список или положи файл в папку {0}.'
        PtPickFile   = 'Номер файла (0 - назад)'
        PtBadFile    = 'Этот файл не похож на список программ winget.'
        PtEmpty      = 'В файле нет программ из каталога winget - ставить нечего.'
        PtImportAsk  = 'Поставить программ: {0}? (y/n)'
        PtImporting  = 'Ставлю программы из списка'
        PtImported   = 'Готово, программ в списке: {0}. Те, что уже стояли, не тронуты.'
        PtReboot     = 'Программы поставлены, для части нужна перезагрузка.'
        PtImportPartial = 'Часть программ поставить не получилось - их нет в каталоге или установщик вернул ошибку.'
        PanelsTitle   = 'Классические панели'
        PanelsActions = 'Номер - открыть    0 - назад'
        PanelsMissing = 'Этого окна на компьютере нет.'
        Panels        = @{ 'control' = 'Панель управления'; 'programs' = 'Программы и компоненты'; 'network' = 'Сетевые подключения'; 'sound' = 'Звук'; 'mouse' = 'Мышь'; 'power' = 'Электропитание'; 'printers' = 'Устройства и принтеры'; 'region' = 'Региональные стандарты'; 'timedate' = 'Дата и время'; 'system' = 'Свойства системы'; 'security' = 'Безопасность и обслуживание'; 'firewall' = 'Брандмауэр Защитника Windows'; 'computer' = 'Управление компьютером'; 'restore' = 'Восстановление системы' }
        TelTitle      = 'Службы и задачи телеметрии'
        TelLead       = @('Служба DiagTrack и задачи, которые собирают и отправляют сведения в Microsoft.',
                          'Перед правкой записывается снимок - буква r возвращает всё, как было.')
        TelActions    = 'a - выключить всё    r - вернуть как было    0 - назад'
        TelOffAsk     = 'Выключить службу DiagTrack и задачи сбора сведений? Понадобятся права администратора. (y/n)'
        TelOffDone    = 'Служба и задачи телеметрии выключены.'
        TelRevertDone = 'Службы и задачи возвращены как были.'
        TelPartial    = 'Часть изменений Windows не приняла ({0}) - некоторые задачи защищены системой.'
        TelNoSnap     = 'Снимка нет: модуль ещё ничего не менял.'
        TelBadSnap    = 'Снимок не прочитался, ничего не изменено.'
        TelServiceNow = 'Служба {0}: {1}'
        TelTaskNow    = 'Задача {0}: {1}'
        TelMode       = @{ Automatic = 'запускается сама'; Manual = 'вручную'; Disabled = 'выключена'; Enabled = 'включена'; Missing = 'нет'; Unknown = 'не удалось узнать' }
        EsignTitle    = 'Программы для электронной подписи'
        EsignLead     = @('Ставим только файл с проверенной подписью производителя. Если подпись не та - файл не запускается.',
                          'КриптоПро ставится пробной версией на 90 дней; ключ лицензии вводится потом в «Инструментах КриптоПро».')
        EsignActions  = 'Номер - поставить    0 - назад'
        EsignAsk      = 'Скачать и поставить «{0}»? Установщик попросит права администратора. (y/n)'
        EsignPageSteps = @('Открыли страницу производителя в браузере.',
                           '1. Скачай установщик «{0}» (на сайте КриптоПро нужно войти или зарегистрироваться).',
                           '2. Перетащи скачанный файл в это окно и нажми Enter. Пустая строка - назад.')
        EsignPathAsk  = 'Файл'
        EsignBadPath  = 'Файл не найден или это не установщик (.msi или .exe).'
        EsignNoSig    = 'подписи нет'
        EsignBadSig   = '«{0}» не запущен: подпись не производителя ({1}).'
        EsignSigOk    = 'Подпись «{0}» проверена: {1}.'
        EsignRunning  = 'Идёт установка - ответь на вопросы установщика.'
        EsignNoDownload = 'Не удалось скачать «{0}» с сайта производителя.'
        EsignDone     = '«{0}» поставлен.'
        EsignReboot   = '«{0}» поставлен. Чтобы он заработал, перезагрузи компьютер.'
        EsignCancelled = 'Установку «{0}» отменили.'
        EsignFail     = 'С «{0}» не получилось, код {1}.'
        EsignVipnet   = @('Открыли страницу загрузок ИнфоТеКС.',
                          'ViPNet CSP бесплатный, но дистрибутив и серийный номер приходят на почту после заявки на сайте.',
                          'Заявку заполняешь ты сам - мы за тебя личные данные не отправляем. Установщик из письма запускай сам.')
        Esign         = @{
            'gosuslugi' = @{ Name = 'Плагин Госуслуг'; Desc = 'вход на Госуслуги по электронной подписи' }
            'cades'     = @{ Name = 'КриптоПро ЭЦП Browser plug-in'; Desc = 'подпись документов на сайтах' }
            'csp'       = @{ Name = 'КриптоПро CSP'; Desc = 'криптопровайдер для ЭЦП, 90 дней бесплатно' }
            'rutoken'   = @{ Name = 'Драйверы Рутокен'; Desc = 'чтобы компьютер видел ключ Рутокен' }
            'vipnet'    = @{ Name = 'ViPNet CSP'; Desc = 'криптопровайдер ИнфоТеКС, по заявке на сайте' }
        }
        BuiltinTitle  = 'Встроенные программы Windows'
        BuiltinLead   = @('Программы, которые Windows ставит сама. Удаляются только у тебя, другие пользователи компьютера их сохранят.',
                          'Вернуть можно в любой момент буквой r: программа поставится заново из Microsoft Store.')
        BuiltinActions = 'Номера через пробел - удалить    r - вернуть удалённое    0 - назад'
        BuiltinNone   = 'Ни одной программы из списка на компьютере нет.'
        BuiltinCanBack = 'Удалено здесь и можно вернуть: {0}.'
        BuiltinDataWarn = 'Вместе с программой удалятся её данные на этом компьютере (заметки, настройки).'
        BuiltinRemoveAsk = 'Удалить эти программы ({0})? (y/n)'
        BuiltinRemoved = '«{0}» удалена.'
        BuiltinRemoveFail = '«{0}» удалить не получилось - Windows не разрешила.'
        BuiltinHowBack = 'Вернуть удалённое - буква r на этом экране.'
        BuiltinNoSnap = 'Вернуть нечего: здесь ещё ничего не удаляли.'
        BuiltinNoWinget = 'Не нашёлся winget (App Installer) - без него вернуть программы не получится. Его можно поставить из Microsoft Store.'
        BuiltinRestoreAsk = 'Поставить заново из Microsoft Store ({0})? (y/n)'
        BuiltinRestored = '«{0}» снова на месте.'
        BuiltinRestoreFail = '«{0}» вернуть не получилось, код winget {1}. Попробуй позже: буква r повторит.'
        CompTitle     = 'Компоненты Windows'
        CompLead      = 'Встроенные части Windows, которые выключены по умолчанию. Включение берёт файлы из Центра обновления.'
        CompActions   = 'Номер - включить    r и номер - выключить (r2)    0 - назад'
        CompEnableAsk = 'Включить «{0}»? Может понадобиться перезагрузка. (y/n)'
        CompDisableAsk = 'Выключить «{0}»? Может понадобиться перезагрузка. (y/n)'
        CompOn        = '«{0}» включён.'
        CompOff       = '«{0}» выключен.'
        CompReboot    = 'Готово. Чтобы «{0}» заработал как надо, перезагрузи компьютер.'
        CompFail      = 'С «{0}» не получилось, код DISM {1}.'
        Comp          = @{
            'netfx3'  = @{ Name = '.NET Framework 3.5'; Desc = 'для старых программ, в том числе бухгалтерских' }
            'sandbox' = @{ Name = 'Песочница Windows'; Desc = 'чистая Windows в окне, чтобы безопасно открыть сомнительный файл' }
            'hyperv'  = @{ Name = 'Hyper-V'; Desc = 'виртуальные машины от Microsoft' }
            'directplay' = @{ Name = 'DirectPlay'; Desc = 'для старых игр, которые без него не запускаются' }
            'recall'  = @{ Name = 'Recall'; Desc = 'снимки экрана для поиска по истории; r и номер - выключить' }
        }
        RepairTitle   = 'Починить Windows'
        RepairLead    = 'Встроенные средства Windows. Каждое запускается отдельно и сначала спрашивает.'
        RepairActions = 'Номер - запустить    0 - назад'
        RepairConfirm = 'Запустить? (y/n)'
        RepairDeclined = 'Окно администратора не подтверждено - ничего не изменено.'
        RepairFail    = 'Не получилось - Windows вернула ошибку.'
        Repair        = @{
            'sfc-verify' = @{ Name = 'Проверить системные файлы (только проверка)'; Ask = 'Windows проверит системные файлы и ничего не изменит. Это займёт 5-15 минут.'; Done = 'Системные файлы в порядке.'; Found = 'Есть повреждённые системные файлы - запусти пункт 2.' }
            'sfc-fix'    = @{ Name = 'Восстановить системные файлы'; Ask = 'Windows скачает исправные копии системных файлов и заменит повреждённые. Нужен интернет, займёт 15-40 минут.'; Done = 'Системные файлы проверены и восстановлены.'; Found = 'Восстановить хранилище компонентов не удалось. Подробности - в журнале CBS.log в папке Windows\Logs\CBS.' }
            'disk-scan'  = @{ Name = 'Проверить диск Windows (только проверка)'; Ask = 'Windows проверит диск с системой, не останавливая работу, и ничего не изменит.'; Done = 'Ошибок на диске нет.'; Found = 'На диске есть ошибки. Исправить их Windows предложит при следующей перезагрузке.' }
            'wu-reset'   = @{ Name = 'Сбросить Центр обновления'; Ask = 'Сбросится кэш Центра обновления: папки SoftwareDistribution и catroot2 будут переименованы, службы обновления перезапущены. История обновлений в окне «Параметры» станет пустой.'; Done = 'Центр обновления сброшен. Старые папки сохранены с пометкой .bak.'; Found = 'Папки сброшены, но служба обновления не запустилась - похоже, её выключил другой «оптимизатор». Пока её не включить, обновления не придут.' }
            'time-sync'  = @{ Name = 'Синхронизировать время'; Ask = 'Windows сверит часы с сервером времени.'; Done = 'Время синхронизировано.'; Found = 'Сервер времени не ответил.' }
            'proxy'      = @{ Name = 'Сбросить прокси'; Ask = 'Будут выключены прокси-серверы Windows: для тебя и для системных служб. Если прокси нужен на работе - не запускай.'; Done = 'Прокси выключен.'; Found = 'Прокси сброшен не полностью.' }
            'icons'      = @{ Name = 'Обновить значки'; Ask = 'Windows перечитает кэш значков. Помогает, когда у файлов пустые или чужие значки.'; Done = 'Значки обновлены. Если не помогло - перезагрузи компьютер.'; Found = 'Значки обновить не удалось.' }
            'store'      = @{ Name = 'Сбросить кэш Microsoft Store'; Ask = 'Откроется окно, которое очистит кэш магазина, затем магазин откроется сам.'; Done = 'Сброс кэша магазина запущен.'; Found = 'Сброс кэша магазина не запустился.' }
            'winget'     = @{ Name = 'Перерегистрировать winget'; Ask = 'Windows заново подключит «Установщик приложений» (winget). Помогает, когда команда winget не находится.'; Done = 'winget перерегистрирован. Открой новое окно терминала.'; Found = 'Перерегистрировать winget не удалось - поставь «Установщик приложений» из Microsoft Store.' }
            'cleanmgr'   = @{ Name = 'Очистка диска'; Ask = 'Откроется встроенная «Очистка диска» Windows. Что удалять, выберешь сам в её окне.'; Done = 'Очистка диска открыта.'; Found = 'Очистка диска не открылась.' }
            'components' = @{ Name = 'Убрать старые копии обновлений'; Ask = 'Windows удалит копии системных файлов, оставшиеся от прошлых обновлений. После этого установленные обновления нельзя будет удалить. Займёт 5-20 минут.'; Done = 'Старые копии обновлений удалены.'; Found = 'Очистка прошла не полностью.' }
            'unlock'     = @{ Name = 'Вернуть Диспетчер задач, редактор реестра и «Выполнить»'; Ask = 'Будут сняты запреты на Диспетчер задач, редактор реестра и окно «Выполнить», если их поставила программа. Если компьютер рабочий и запреты поставил администратор, он вернёт их сам.'; Done = 'Запреты сняты. Выйди из системы и войди снова.'; Found = 'Запреты сняты не полностью.' }
        }
        RpTitle      = 'Точка восстановления'
        RpLead       = @('Точка восстановления сохраняет системные файлы, драйверы и реестр Windows.', 'Если после изменений что-то сломается, Windows вернётся к этому состоянию. Твои документы она не трогает.')
        RpActions    = '1 - создать точку сейчас    2 - открыть восстановление системы    0 - назад'
        RpEnableAsk  = 'Защита системы на диске Windows выключена. Включить её и создать точку? (y/n)'
        RpDone       = 'Точка восстановления создана.'
        RpToday      = 'Windows не создала новую точку: с прошлой прошло меньше суток. Последняя точка на месте.'
        RpOff        = 'Точка не создана: защита системы на диске Windows выключена.'
        RpFail       = 'Точку создать не получилось.'
        RpDeclined   = 'Окно администратора не подтверждено - точка не создана.'
        RpNoRstrui   = 'Окно восстановления системы на этом компьютере не найдено.'
        PresetModuleAsk = 'Настроить сейчас: {0}? (y/n)'
        OptionalTag  = '(необязательно, меняет привычное поведение)'
        OptionalNote = 'Пункты с пометкой «необязательно» по кнопке «a» не применяются - выберите их номером.'
        Effect       = @{ 'restart' = '(после перезагрузки)'; 'signout' = '(после выхода из системы)'; 'explorer' = '(после перезапуска Проводника)'; 'install-only' = '(при следующей установке)' }
        AllOptional = 'Здесь всё на выбор: «a» ничего не меняет. Введите номера нужных пунктов.'
        Choice       = 'Выбор'
        BadChoice    = 'Не понял выбор. Введите номера из списка, a или r.'
        AppliedCount = 'Применено: {0} из {1}'
        SnapSaved    = "На всякий случай запомнили, как было (вернуть - пункт 'r')."
        SnapCopy     = 'Копия для вас (можно посмотреть):'
        Oops         = 'Не получилось:'
        Applied      = 'применено'
        Failed       = 'не удалось'
        ApplyDone    = 'Применено настроек: {0} из {1}.'
        Magic        = @(
            'Происходит магия',
            'Колдуем',
            'Варим зелье',
            'Машем волшебной палочкой',
            'Шепчем Windows на ушко',
            'Уговариваем Windows по-хорошему'
        )
        ResultTitle  = 'Результат:'
        OutFailed    = 'Не удалось: {0}'
        ResultEmpty  = '(подробностей нет)'
        LogWhere     = 'Подробности - в журнале: Документы, папка AutoSettings.win, logs.'
        ReadBack     = 'значение не встало: после записи в реестре другое'
        LiveUac      = 'Windows спросит разрешение - ответьте «Да»'
        LiveLong     = 'большие программы ставятся по нескольку минут, окно не закрывайте'
        OutNoSnap    = 'не удалось запомнить, как было, поэтому ничего не меняли'
        OutMore      = 'и ещё не удалось: {0}'
        OutDeclined  = 'Без прав администратора пропущено настроек: {0}. Повторите и ответьте «Да» на запрос Windows.'
        OutRestored  = 'Возвращено значений: {0}.'
        OutRevertDeclined = 'Без прав администратора общесистемная часть не возвращена. Повторите и ответьте «Да».'
        OutPartRevert = 'Вернули не всё. Что не получилось:'
        TermOmpKept  = 'oh-my-posh удалить не удалось - его можно убрать в «Установленных приложениях»'
        NoSnapshot   = 'Снимка нет - восстанавливать не из чего. Снимок создаётся при применении.'
        Restoring    = 'Восстановление из снимка от {0}'
        RestoreDone  = 'Возвращено значений: {0}. Пропущено посторонних записей: {1}.'
        SkipType     = 'пропущено (тип {0} не разрешён): {1}\{2}'
        SnapUnsafe   = "Папка снимков '{0}' принадлежит не администратору или открыта слишком широко. Остановлено."
        ElevateApply = 'Для общесистемных политик нужны права администратора - сейчас появится запрос Windows (UAC).'
        ElevateRevert = 'Для отката общесистемных политик нужны права администратора - появится запрос Windows (UAC).'
        ElevateDeclined = 'Права администратора не предоставлены - общесистемная часть пропущена. Пользовательские настройки применены.'
        HklmFailed   = 'Не удалось применить общесистемных политик: {0}.'
        PressEnter   = 'Нажмите Enter, чтобы продолжить'
        TermsNote    = 'Продолжая использовать сервис, вы подтверждаете, что прочитали пользовательское соглашение и полностью с ним согласны:'
        TermsUrl     = 'https://autosettings.win/ru/legal/terms/'
        YandexNetCat      = 'Яндекс.ДНС и поиск Яндекса'
        CertCat           = 'Сертификаты для госуслуг и ЭЦП'
        TermCat           = 'Терминал: строка приглашения и шрифт'
        TermTitle         = 'Терминал: строка приглашения и шрифт'
        TermWarn          = @(
            'Что будет сделано (по вашему подтверждению):',
            '- установлен oh-my-posh (красивая строка приглашения);',
            '- установлен шрифт JetBrainsMono Nerd Font (кириллица, латиница, иконки);',
            '- этот шрифт включён в консоли и в Windows Terminal;',
            '- выбранная тема прописана в ваш профиль PowerShell.',
            'Права администратора уже получены на старте - отдельного запроса не будет.',
            'Всё сохраняется в снимок и возвращается пунктом "r". Отказ ничего не меняет.'
        )
        TermFontManual    = 'Хотите поставить шрифт сами? Скачайте, распакуйте, установите .ttf:'
        TermNoThemes      = 'В папке {0} нет тем oh-my-posh. Повторите пункт: темы скачаются заново.'
        TermThemesDlFail  = 'Не удалось скачать темы oh-my-posh с github.com: {0}. Проверьте доступ к github.com и повторите пункт.'
        TermActions       = 'y - сделать    r - вернуть как было    0 - назад'
        TermInstalling    = 'Происходит магия: ставим oh-my-posh...'
        TermOmpReady      = 'oh-my-posh готов.'
        TermOmpFail       = 'Не удалось установить oh-my-posh (нужен winget). Ничего не изменено.'
        TermPickTheme     = 'Выберите тему строки приглашения:'
        TermMinimalHint   = 'Темы с minimal в названии работают и без Nerd Font (без иконок).'
        TermShowAll       = 'a - показать все темы'
        TermPreviewHint   = 'p <номер> - предпросмотр в новом окне'
        TermBack          = '0 - назад'
        TermPreviewWindow = 'Предпросмотр. Это окно можно закрыть.'
        TermFontInstalling = 'Колдуем над шрифтом JetBrainsMono Nerd Font...'
        TermFontOk        = 'Шрифт установлен.'
        TermFontFail      = 'Шрифт установить не удалось - можно поставить вручную, скачав по ссылке:'
        TermApplied       = 'Тема "{0}" применена.'
        TermIconWarn      = 'Без Nerd Font иконки будут показаны квадратами.'
        TermLiveOk        = 'Строка приглашения включена прямо в этом окне - результат виден сразу.'
        TermFontNewWindow = 'Значки шрифта появятся после открытия нового окна терминала.'
        TermOpenNew       = 'Откройте новый терминал, чтобы увидеть результат.'
        TermReverted      = 'Возвращено как было.'
        AiCat             = 'Настройка ИИ для работы в терминале'
        AiTitle           = 'Настройка ИИ для работы в терминале'
        AiProviderClaude  = '[1] Claude Code - строка приглашения и статус-бар'
        AiProviderCodex   = '[2] Codex - статус-бар с контекстом и лимитами подписки, тема AutoSettings, без сбора статистики'
        AiWarn            = @(
            'Что будет сделано (по вашему подтверждению):',
            '- установлены oh-my-posh, шрифт JetBrainsMono Nerd Font и Python (если нет);',
            '- установлен красивый статус-бар Claude Code с плашкой AutoSettings.;',
            '- установлен профиль PowerShell (подсказки, значки файлов, общие инструменты).',
            'Для остальных агентов (пункты 2-7) дописываются только недостающие строки их настроек - ваши не меняются.',
            'Права администратора уже получены на старте - отдельного запроса не будет.',
            'Всё сохраняется в снимок и возвращается пунктом "r". Отказ ничего не меняет.'
        )
        AiActions         = '1-7 - выбрать агента    r - вернуть как было    0 - назад'
        AiProviderCopilot = '[3] Copilot CLI - статус-бар AutoSettings: модель, контекст, токены, премиум-запросы'
        AiProviderGemini  = '[4] Gemini CLI - подвал с контекстом и дневным лимитом, тема AutoSettings, без сбора статистики'
        AiProviderQwen    = '[5] Qwen Code - статус-бар с контекстом и токенами, без сбора статистики'
        AiAgentMissing    = '{0} не найден. Поставьте его в «ИИ-агенты: установка» и вернитесь сюда.'
        AiAgentSkipJson   = 'В настройках {0} есть комментарии, или файл не читается - ничего не меняю, чтобы не потерять ваше.'
        AiAgentAlready    = '{0} уже настроен - менять нечего.'
        AiAgentOpenNew    = 'Перезапустите {0}, чтобы увидеть результат.'
        AiCopilotDone     = 'Copilot CLI настроен: статус-бар AutoSettings, сессии не выгружаются наружу, подсказки и баннер выключены.'
        AiCopilotPrivacyOnly = 'У Copilot CLI уже есть свой статус-бар - оставил его. Выключил выгрузку сессий, подсказки и баннер.'
        AiCopilotNoOmp    = 'Не нашёл oh-my-posh для статус-бара Copilot - ничего не меняю. Сначала настройте пункт 1 или «Терминал».'
        AiGeminiDone      = 'Gemini CLI настроен: подвал с контекстом и дневным лимитом, тема AutoSettings, статистика выключена.'
        AiQwenDone        = 'Qwen Code настроен: статус-бар с контекстом и токенами, статистика выключена.'
        AiSnapForged      = 'Снимок {0} указывает за пределы папок агентов - пропущен, ничего не тронуто.'
        AiProviderOpencode = '[6] opencode - сессии не уходят по публичной ссылке'
        AiProviderCrush   = '[7] Crush - без сбора статистики и без подписи Crush в commit'
        AiAgentOwnFile    = '{0} берёт настройки из файла, который вы назначили сами, - его не трогаю.'
        AiOpencodeDone    = 'opencode настроен: сессии больше не выкладываются по публичной ссылке. Статус-бар у него не настраивается.'
        AiCrushDone       = 'Crush настроен: статистика выключена, подписи Crush в commit больше нет. Статус-бар у него не настраивается.'
        AiCodexMissing    = 'Codex не найден. Поставьте его в «ИИ-агенты: установка» и вернитесь сюда.'
        AiCodexSkip       = 'Настройки Codex устроены непривычно (таблица tui задана дважды или строками tui.x) - ничего не меняю, чтобы не сломать.'
        AiCodexAlready    = 'Codex уже настроен - менять нечего.'
        AiCodexDone       = 'Codex настроен: статус-бар с контекстом и лимитами подписки, тема AutoSettings, статистика и отзывы выключены.'
        AiCodexOpenNew    = 'Перезапустите Codex. Состав статус-бара меняется командой /statusline.'
        AiPyChecking      = 'Проверяю Python...'
        AiPyInstalling    = 'Происходит магия: ставим Python. Это может занять пару минут...'
        AiPyReady         = 'Python готов.'
        AiPyFail          = 'Не получилось поставить Python. Если на компьютере есть старый Python, удалите его в «Установленных приложениях» и попробуйте ещё раз. Ничего не изменено.'
        AiModules         = 'Колдуем над значками файлов и автодополнением...'
        AiProfileDone     = 'Профиль PowerShell установлен.'
        AiStatusDone      = 'Статус-бар Claude Code настроен.'
        AiOpenNew         = 'Откройте новый терминал и Claude Code, чтобы увидеть результат.'
        AiSettingsSkip    = 'settings.json Claude Code не читается - статус-бар не прописан, остальное сделано.'
        AiPwshOffer       = @(
            'У вас Windows PowerShell 5.1 - это старая версия.',
            'Рекомендуем установить последнюю версию PowerShell 7 (ставится рядом, 5.1 остаётся).',
            'Справка: https://learn.microsoft.com/ru-ru/powershell/'
        )
        AiPwshAsk         = 'Установить PowerShell 7? (y - да, Enter - пропустить)'
        AiPwshInstalling  = 'Устанавливаю PowerShell 7...'
        AiPwshDone        = 'PowerShell 7 установлен (откройте его как pwsh).'
        AiPwshSkip        = 'PowerShell 7 не установлен - продолжаю на текущей версии.'
        AiNodeChecking    = 'Проверяю Node.js/npm (нужны для MCP-серверов Claude Code)...'
        AiNodeInstalling  = 'Устанавливаю Node.js (LTS)...'
        AiNodeReady       = 'Node.js/npm на месте.'
        AiNodeFail        = 'Node.js поставить не удалось - MCP-серверы Claude Code работать не будут.'

        WslTitle     = 'WSL 2 + Ubuntu (Linux в Windows - для tmux и Unix-инструментов)'
        WslWarn      = @(
            'Что будет сделано (по вашему подтверждению):',
            '- включены компоненты Windows: WSL и Virtual Machine Platform;',
            '- установлены WSL 2 (ядро Linux) и дистрибутив Ubuntu;',
            'Это НЕ правка реестра: нужны права администратора и ПЕРЕЗАГРУЗКА.',
            'Откат (r) удаляет дистрибутив Ubuntu (wsl --unregister, данные стираются); сам WSL остаётся.',
            'Ставит один вызов подписанного Microsoft wsl.exe. Отказ ничего не меняет.'
        )
        WslActions   = 'y - установить    r - удалить Ubuntu    0 - назад'
        WslInstalling = 'Происходит магия: ставим WSL 2 и Ubuntu. Windows спросит разрешение, это может занять несколько минут...'
        WslDone      = 'WSL 2 и Ubuntu установлены. После перезагрузки откройте Ubuntu, задайте имя и пароль, затем: sudo apt install tmux'
        WslReboot    = 'Нужна перезагрузка, чтобы завершить установку WSL 2.'
        WslFail      = 'Установить WSL не удалось (нужны права администратора и Windows 10 2004+/11). Смотрите открывшееся окно.'
        WslNoWsl     = 'wsl.exe не найден или его подпись не подтверждена - установка отменена.'
        WslPresent   = 'Ubuntu уже установлена в WSL - ничего не меняю.'
        WslRevertAsk = 'Удалить дистрибутив Ubuntu из WSL? Его данные будут стёрты. (y/n)'
        WslRevertNone = 'Ubuntu этим инструментом не ставилась - удалять нечего.'
        WslReverted  = 'Ubuntu удалена из WSL. Сам WSL оставлен.'
        WslRevertFail = 'Не получилось убрать Ubuntu. Закройте окна WSL и попробуйте ещё раз.'

        DevCat       = 'Дополнительные средства разработки'
        DevTitle     = 'Дополнительные средства разработки (через winget)'
        DevWarn      = @(
            'Ставится подписанным пакетным менеджером winget - без Chocolatey и сетевых установщиков.',
            'WSL требует прав администратора и перезагрузки; Build Tools C++ - несколько ГБ.',
            'Выберите номера для установки. [+] - уже установлено.'
        )
        DevActions   = 'номера - установить   a - все   u - обновить   x - удалить   0 - назад'
        DevLooking   = 'Смотрим, что уже установлено...'
        DevHave      = 'Уже установлено: {0}'
        DevReboot    = 'Установлено, но для завершения нужна перезагрузка: {0}'
        DevUpdated   = 'Обновлено: {0}'
        DevFresh     = 'Обновлять нечего: {0}'
        DevOpened    = 'Открыта страница в браузере: {0}'
        DevLinksOnly = 'Здесь ссылки на страницы производителей - выберите номер.'
        DevInstalling = 'Происходит магия: ставим {0}. Это может занять несколько минут...'
        DevOk        = 'Установлено: {0}'
        DevFail      = 'Не получилось: {0}. Попробуйте ещё раз; если не поможет - перезагрузите компьютер.'
        DevRemoving  = 'Убираем {0}...'
        DevRemoved   = 'Удалено: {0}'
        DevRemoveAsk = 'Номера для удаления (через пробел или запятую)'
        DevRemoveConfirm = 'Удалить с компьютера: {0}? (y/n)'
        DevNoWinget  = 'winget не найден или его подпись не подтверждена - нужен App Installer из Microsoft Store.'
        DevNeedNode  = 'Для «{0}» нужен Node.js - его ставит пункт «Инструменты разработки».'
        DevNodeAsk   = 'Для «{0}» нужен Node.js. Поставить его сейчас? (y/n)'
        DevNodeRestart = 'Node.js поставлен, но это окно его ещё не видит. Откройте новое окно и повторите.'
        AgentsTitle  = 'ИИ-агенты для консоли: установка'
        AgentsWarn   = @(
            'Claude Code, Codex и Crush ставит winget; Gemini CLI, opencode и Qwen Code - npm (нужен Node.js).',
            'Ключи и вход в учётные записи этот экран не трогает: каждый агент спросит их сам при первом запуске.',
            'Выберите номера для установки. [+] - уже установлено.'
        )
        TermWtAction = 'w - поставить Windows Terminal'
    }
    en = @{
        AppTitle     = 'autosettings.win - Windows privacy setup'
        OsLine       = '{0}, build {1}, {2}'
        ArchX64      = 'x64'
        ArchArm64    = 'ARM64'
        ArchX86      = 'x86, 32-bit'
        ArchTitle    = 'Could not tell which processor this computer has. It decides which programs will fit.'
        ArchPick1    = '[1] Intel or AMD, 64-bit Windows - nearly every computer'
        ArchPick2    = '[2] ARM - Snapdragon and other ARM processors'
        ArchPick3    = '[3] 32-bit Windows'
        ArchWhere    = 'Where to look: Settings - System - About, the line "System type".'
        ArchAsk      = 'Number'
        PreTitle     = 'Worth knowing before you start:'
        PreReboot    = 'Windows is waiting for a restart after an update or install. Some settings may not take effect until the PC restarts.'
        PreSpace     = 'The system drive has {0} GB free. Programs and updates may need more.'
        PreAccount   = 'This window runs as {0}, but {1} is signed in to Windows. Personal settings will be written for {0}.'
        PreAsk       = 'Enter - continue, 0 - quit'
        ChooseLang   = 'Choose a language:'
        LangRu       = '[1] Russian'
        LangEn       = '[2] English'
        LangEnter    = '(Enter - {0})'
        LangRuName   = 'Russian'
        LangEnName   = 'English'
        LangAsk      = 'Language'
        MenuTitle    = 'What to configure:'
        SectionPrivacy = 'Privacy'
        SectionSystem  = 'System'
        SectionPresets = 'Ready-made sets'
        SectionDev   = 'For developers'
        EditionNote  = 'Telemetry can be fully turned off only on Enterprise/Education; on Home/Pro the minimum is "Required data".'
        WtOffer      = 'You can install the modern Windows Terminal - the menu will look nicer.'
        WtAsk        = 'Install Windows Terminal? (y/n)'
        WtInstalling = 'Magic in progress: installing Windows Terminal...'
        WtInstalled  = 'Windows Terminal installed. Next time run the setup inside it for a nicer look.'
        WtFail       = 'Could not install Windows Terminal. Continuing in the current window.'
        MenuLang     = 'l - language / язык'
        MenuHint     = '/word - search    2.3 - jump to an item'
        MenuBack     = '0 - back'
        CountOf      = '{0} of {1}'
        WtHint       = 'The menu looks better in Windows Terminal - you can install it in item {0}.'
        SearchTitle  = 'Search: {0}'
        SearchNone   = 'Nothing found. Try another word.'
        SearchIn     = 'inside: {0}'
        SearchNotHere = 'does not run on this computer ({0}): {1}'
        NotHere      = 'This does not run on this computer ({0}), so it is not in the menu.'
        MenuExit     = '0 - exit'
        MenuChanged  = 'j - what changed, undo'
        ChangedTitle = 'What changed on this PC'
        ChangedEmpty = 'No settings changed by autosettings.win are in place right now.'
        ChangedModules = 'Terminal, DNS, certificates and programs are undone on their own screens with r.'
        ChangedActions = 'Number - undo (several: 1 3)    r - undo all    0 - back'
        ChangedBad   = 'Did not understand. Enter numbers from the list or r.'
        MenuAsk      = 'Item number'
        NeedBuild    = '{0} - needs Windows build {1} or newer'
        NotForWin    = 'This item does not fit your version of Windows.'
        PickHint     = 'Enter item numbers separated by spaces to apply (for example: 1 3).'
        PickActions  = 'a - apply all    r - restore previous    0 - back'
        PresetModules   = 'Also in this set - a separate step, asks first:'
        PtTitle      = 'Move your programs'
        PtLead       = @('Save the list of your programs to a file, then install them on a new or reinstalled PC with one command.', 'The files are in "Documents\AutoSettings.win\programs" - you can carry them on a USB stick.')
        PtActions    = '1 - save the list of programs    2 - install programs from a file    0 - back'
        PtNoWinget   = 'winget is not on this PC - install App Installer from Microsoft Store.'
        PtNoDir      = 'Could not open the folder for lists: {0}'
        PtExporting  = 'Saving the list of programs'
        PtExported   = 'List saved, programs in it: {0}.'
        PtExportFail = 'Could not save the list.'
        PtNoFiles    = 'No lists yet. Save a list first or put a file in {0}.'
        PtPickFile   = 'File number (0 - back)'
        PtBadFile    = 'This file does not look like a winget program list.'
        PtEmpty      = 'The file has no programs from the winget catalog - nothing to install.'
        PtImportAsk  = 'Install programs: {0}? (y/n)'
        PtImporting  = 'Installing programs from the list'
        PtImported   = 'Done, programs in the list: {0}. Those already installed were left alone.'
        PtReboot     = 'Programs installed, some need a restart.'
        PtImportPartial = 'Some programs could not be installed - they are not in the catalog or the installer returned an error.'
        PanelsTitle   = 'Classic panels'
        PanelsActions = 'Number - open    0 - back'
        PanelsMissing = 'This window is not on this PC.'
        Panels        = @{ 'control' = 'Control Panel'; 'programs' = 'Programs and Features'; 'network' = 'Network Connections'; 'sound' = 'Sound'; 'mouse' = 'Mouse'; 'power' = 'Power Options'; 'printers' = 'Devices and Printers'; 'region' = 'Region'; 'timedate' = 'Date and Time'; 'system' = 'System Properties'; 'security' = 'Security and Maintenance'; 'firewall' = 'Windows Defender Firewall'; 'computer' = 'Computer Management'; 'restore' = 'System Restore' }
        TelTitle      = 'Telemetry services and tasks'
        TelLead       = @('The DiagTrack service and the tasks that collect and send data to Microsoft.',
                          'A snapshot is taken before any change - the r key puts everything back.')
        TelActions    = 'a - turn all off    r - put back as it was    0 - back'
        TelOffAsk     = 'Turn off the DiagTrack service and the data collection tasks? Administrator rights are needed. (y/n)'
        TelOffDone    = 'Telemetry service and tasks are off.'
        TelRevertDone = 'Services and tasks are back as they were.'
        TelPartial    = 'Windows did not accept some changes ({0}) - some tasks are protected by the system.'
        TelNoSnap     = 'No snapshot: this module has not changed anything yet.'
        TelBadSnap    = 'The snapshot could not be read, nothing was changed.'
        TelServiceNow = 'Service {0}: {1}'
        TelTaskNow    = 'Task {0}: {1}'
        TelMode       = @{ Automatic = 'starts automatically'; Manual = 'manual'; Disabled = 'off'; Enabled = 'on'; Missing = 'absent'; Unknown = 'could not check' }
        EsignTitle    = 'E-signature programs'
        EsignLead     = @('We install only a file with the vendor''s verified signature. If the signature is wrong, the file is not run.',
                          'CryptoPro installs as a 90-day trial; you enter the license key later in CryptoPro Tools.')
        EsignActions  = 'Number - install    0 - back'
        EsignAsk      = 'Download and install "{0}"? The installer will ask for administrator rights. (y/n)'
        EsignPageSteps = @('The vendor page is open in your browser.',
                           '1. Download the "{0}" installer (the CryptoPro site asks you to sign in or register).',
                           '2. Drag the downloaded file into this window and press Enter. Empty line - back.')
        EsignPathAsk  = 'File'
        EsignBadPath  = 'File not found, or it is not an installer (.msi or .exe).'
        EsignNoSig    = 'no signature'
        EsignBadSig   = '"{0}" was not run: the signature is not the vendor''s ({1}).'
        EsignSigOk    = 'Signature of "{0}" verified: {1}.'
        EsignRunning  = 'Installing - answer the installer''s questions.'
        EsignNoDownload = 'Could not download "{0}" from the vendor site.'
        EsignDone     = '"{0}" installed.'
        EsignReboot   = '"{0}" installed. Restart the PC for it to work.'
        EsignCancelled = 'Installation of "{0}" was cancelled.'
        EsignFail     = 'Something went wrong with "{0}", code {1}.'
        EsignVipnet   = @('The InfoTeCS downloads page is open.',
                          'ViPNet CSP is free, but the installer and serial number arrive by e-mail after you apply on the site.',
                          'You fill in the request yourself - we do not send your personal data. Run the installer from the e-mail yourself.')
        Esign         = @{
            'gosuslugi' = @{ Name = 'Gosuslugi plugin'; Desc = 'sign in to Gosuslugi with an e-signature' }
            'cades'     = @{ Name = 'CryptoPro CAdES Browser plug-in'; Desc = 'sign documents on websites' }
            'csp'       = @{ Name = 'CryptoPro CSP'; Desc = 'crypto provider for e-signatures, 90 days free' }
            'rutoken'   = @{ Name = 'Rutoken drivers'; Desc = 'so the PC sees a Rutoken key' }
            'vipnet'    = @{ Name = 'ViPNet CSP'; Desc = 'InfoTeCS crypto provider, on request' }
        }
        BuiltinTitle  = 'Built-in Windows apps'
        BuiltinLead   = @('Apps Windows installs by itself. They are removed for you only; other users on this PC keep them.',
                          'You can bring them back any time with r: the app is reinstalled from the Microsoft Store.')
        BuiltinActions = 'Numbers separated by spaces - remove    r - bring back removed    0 - back'
        BuiltinNone   = 'None of the listed apps are on this PC.'
        BuiltinCanBack = 'Removed here and can be brought back: {0}.'
        BuiltinDataWarn = 'The app data on this PC (notes, settings) is removed with the app.'
        BuiltinRemoveAsk = 'Remove these apps ({0})? (y/n)'
        BuiltinRemoved = '"{0}" removed.'
        BuiltinRemoveFail = 'Could not remove "{0}" - Windows did not allow it.'
        BuiltinHowBack = 'To bring removed apps back, press r on this screen.'
        BuiltinNoSnap = 'Nothing to bring back: nothing was removed here yet.'
        BuiltinNoWinget = 'winget (App Installer) was not found - apps cannot be brought back without it. You can get it from the Microsoft Store.'
        BuiltinRestoreAsk = 'Reinstall from the Microsoft Store ({0})? (y/n)'
        BuiltinRestored = '"{0}" is back.'
        BuiltinRestoreFail = 'Could not bring back "{0}", winget code {1}. Try again later: r repeats it.'
        CompTitle     = 'Windows features'
        CompLead      = 'Built-in parts of Windows that are off by default. Turning one on takes files from Windows Update.'
        CompActions   = 'Number - turn on    r and a number - turn off (r2)    0 - back'
        CompEnableAsk = 'Turn on "{0}"? A restart may be needed. (y/n)'
        CompDisableAsk = 'Turn off "{0}"? A restart may be needed. (y/n)'
        CompOn        = '"{0}" is on.'
        CompOff       = '"{0}" is off.'
        CompReboot    = 'Done. Restart the PC for "{0}" to work properly.'
        CompFail      = '"{0}" did not work, DISM code {1}.'
        Comp          = @{
            'netfx3'  = @{ Name = '.NET Framework 3.5'; Desc = 'for older programs, including accounting software' }
            'sandbox' = @{ Name = 'Windows Sandbox'; Desc = 'a clean Windows in a window, to open a suspicious file safely' }
            'hyperv'  = @{ Name = 'Hyper-V'; Desc = 'virtual machines from Microsoft' }
            'directplay' = @{ Name = 'DirectPlay'; Desc = 'for old games that will not start without it' }
            'recall'  = @{ Name = 'Recall'; Desc = 'screen snapshots for searching your history; r and a number turns it off' }
        }
        RepairTitle   = 'Repair Windows'
        RepairLead    = 'Built-in Windows tools. Each runs on its own and asks first.'
        RepairActions = 'Number - run    0 - back'
        RepairConfirm = 'Run it? (y/n)'
        RepairDeclined = 'The administrator window was not confirmed - nothing changed.'
        RepairFail    = 'It did not work - Windows returned an error.'
        Repair        = @{
            'sfc-verify' = @{ Name = 'Check system files (check only)'; Ask = 'Windows checks the system files and changes nothing. It takes 5-15 minutes.'; Done = 'System files are fine.'; Found = 'Some system files are damaged - run item 2.' }
            'sfc-fix'    = @{ Name = 'Repair system files'; Ask = 'Windows downloads good copies of system files and replaces damaged ones. Needs the internet, takes 15-40 minutes.'; Done = 'System files checked and repaired.'; Found = 'The component store could not be repaired. Details are in CBS.log in the Windows\Logs\CBS folder.' }
            'disk-scan'  = @{ Name = 'Check the Windows drive (check only)'; Ask = 'Windows checks the system drive while you keep working and changes nothing.'; Done = 'No errors on the drive.'; Found = 'The drive has errors. Windows offers to fix them on the next restart.' }
            'wu-reset'   = @{ Name = 'Reset Windows Update'; Ask = 'The Windows Update cache is reset: the SoftwareDistribution and catroot2 folders are renamed and the update services restart. Update history in Settings becomes empty.'; Done = 'Windows Update reset. The old folders are kept with a .bak mark.'; Found = 'The folders were reset, but an update service did not start - another "optimizer" probably turned it off. Updates will not arrive until it is turned back on.' }
            'time-sync'  = @{ Name = 'Sync the time'; Ask = 'Windows checks the clock against the time server.'; Done = 'Time synced.'; Found = 'The time server did not answer.' }
            'proxy'      = @{ Name = 'Reset the proxy'; Ask = 'Windows proxy servers are turned off, for you and for system services. If you need a proxy at work, do not run this.'; Done = 'Proxy turned off.'; Found = 'The proxy was not fully reset.' }
            'icons'      = @{ Name = 'Refresh icons'; Ask = 'Windows reloads the icon cache. Helps when files show blank or wrong icons.'; Done = 'Icons refreshed. If it did not help, restart the PC.'; Found = 'Could not refresh icons.' }
            'store'      = @{ Name = 'Reset the Microsoft Store cache'; Ask = 'A window opens that clears the Store cache, then the Store opens by itself.'; Done = 'Store cache reset started.'; Found = 'The Store cache reset did not start.' }
            'winget'     = @{ Name = 'Re-register winget'; Ask = 'Windows reconnects App Installer (winget). Helps when the winget command is not found.'; Done = 'winget re-registered. Open a new terminal window.'; Found = 'Could not re-register winget - install App Installer from Microsoft Store.' }
            'cleanmgr'   = @{ Name = 'Disk Cleanup'; Ask = 'The built-in Windows Disk Cleanup opens. You choose what to delete in its window.'; Done = 'Disk Cleanup opened.'; Found = 'Disk Cleanup did not open.' }
            'components' = @{ Name = 'Remove old update copies'; Ask = 'Windows deletes copies of system files left over from past updates. Installed updates can no longer be uninstalled afterwards. Takes 5-20 minutes.'; Done = 'Old update copies removed.'; Found = 'The cleanup did not finish completely.' }
            'unlock'     = @{ Name = 'Bring back Task Manager, Registry Editor and Run'; Ask = 'Blocks on Task Manager, Registry Editor and the Run box are removed if a program set them. On a work PC where an administrator set them, they come back on their own.'; Done = 'Blocks removed. Sign out and sign back in.'; Found = 'Blocks were not fully removed.' }
        }
        RpTitle      = 'Restore point'
        RpLead       = @('A restore point saves Windows system files, drivers and the registry.', 'If something breaks after changes, Windows goes back to this state. Your documents stay as they are.')
        RpActions    = '1 - create a point now    2 - open System Restore    0 - back'
        RpEnableAsk  = 'System protection is off on the Windows drive. Turn it on and create a point? (y/n)'
        RpDone       = 'Restore point created.'
        RpToday      = 'Windows did not create a new point: less than a day has passed since the last one. The last point is still there.'
        RpOff        = 'No point created: system protection is off on the Windows drive.'
        RpFail       = 'Could not create the restore point.'
        RpDeclined   = 'The administrator window was not confirmed - no point created.'
        RpNoRstrui   = 'System Restore was not found on this PC.'
        PresetModuleAsk = 'Set up now: {0}? (y/n)'
        OptionalTag  = '(optional, changes usual behavior)'
        OptionalNote = 'Items marked "optional" are not applied by "a" - pick them by number.'
        Effect       = @{ 'restart' = '(after a restart)'; 'signout' = '(after signing out)'; 'explorer' = '(after File Explorer restarts)'; 'install-only' = '(on the next install)' }
        AllOptional = 'Everything here is optional: "a" changes nothing. Enter the numbers you want.'
        Choice       = 'Choice'
        BadChoice    = 'Did not understand. Enter numbers from the list, a or r.'
        AppliedCount = 'Applied: {0} of {1}'
        SnapSaved    = "Just in case, we remembered how it was (restore with 'r')."
        SnapCopy     = 'Your copy (you can view it):'
        Oops         = 'That did not work:'
        Applied      = 'applied'
        Failed       = 'failed'
        ApplyDone    = 'Settings applied: {0} of {1}.'
        Magic        = @(
            'Magic in progress',
            'Casting a spell',
            'Brewing a potion',
            'Waving the wand',
            'Whispering to Windows',
            'Asking Windows nicely'
        )
        ResultTitle  = 'Result:'
        OutFailed    = 'Failed: {0}'
        ResultEmpty  = '(no details)'
        LogWhere     = 'Details are in the log: Documents, folder AutoSettings.win, logs.'
        ReadBack     = 'the value did not stick: the registry reads back something else'
        LiveUac      = 'Windows will ask for permission - click Yes'
        LiveLong     = 'large programs take a few minutes, keep this window open'
        OutNoSnap    = 'could not remember the previous state, so nothing was changed'
        OutMore      = 'and more that failed: {0}'
        OutDeclined  = 'Without administrator rights these settings were skipped: {0}. Try again and click Yes in the Windows prompt.'
        OutRestored  = 'Values restored: {0}.'
        OutRevertDeclined = 'Without administrator rights the machine-wide part was not restored. Try again and click Yes.'
        OutPartRevert = 'Not everything was restored. What failed:'
        TermOmpKept  = 'oh-my-posh could not be removed - you can remove it in Installed apps'
        NoSnapshot   = 'No snapshot to restore from. A snapshot is taken when you apply.'
        Restoring    = 'Restoring from the snapshot taken {0}'
        RestoreDone  = 'Values restored: {0}. Foreign entries skipped: {1}.'
        SkipType     = 'skipped (type {0} not allowed): {1}\{2}'
        SnapUnsafe   = "The snapshot folder '{0}' is not owned by an administrator or is too open. Stopped."
        ElevateApply = 'Machine-wide policies need administrator rights - Windows will now ask (UAC).'
        ElevateRevert = 'Reverting machine-wide policies needs administrator rights - Windows will ask (UAC).'
        ElevateDeclined = 'Administrator rights were not granted - the machine-wide part was skipped. User settings were applied.'
        HklmFailed   = 'Machine-wide policies that failed to apply: {0}.'
        PressEnter   = 'Press Enter to continue'
        TermsNote    = 'By continuing to use the service you confirm that you have read the terms of use and fully agree with them:'
        TermsUrl     = 'https://autosettings.win/en/legal/terms/'
        YandexNetCat      = 'Yandex DNS and Yandex search'
        CertCat           = 'Certificates for Gosuslugi and digital signature'
        TermCat           = 'Terminal: prompt and font'
        TermTitle         = 'Terminal: prompt and font'
        TermWarn          = @(
            'What will be done (after you confirm):',
            '- install oh-my-posh (a rich command prompt);',
            '- install the JetBrainsMono Nerd Font (Cyrillic, Latin, icons);',
            '- set that font for the console and Windows Terminal;',
            '- write the chosen theme into your PowerShell profile.',
            'Administrator rights were already granted at start - no separate prompt.',
            'Everything is saved to a snapshot and restored with "r". Declining changes nothing.'
        )
        TermFontManual    = 'Prefer to install the font yourself? Download, unzip, install the .ttf:'
        TermNoThemes      = 'No oh-my-posh themes in {0}. Run this item again: the themes will be downloaded again.'
        TermThemesDlFail  = 'Could not download the oh-my-posh themes from github.com: {0}. Check access to github.com and run this item again.'
        TermActions       = 'y - do it    r - restore previous    0 - back'
        TermInstalling    = 'Magic in progress: installing oh-my-posh...'
        TermOmpReady      = 'oh-my-posh is ready.'
        TermOmpFail       = 'Could not install oh-my-posh (winget required). Nothing changed.'
        TermPickTheme     = 'Choose a prompt theme:'
        TermMinimalHint   = 'Themes with "minimal" in the name work without a Nerd Font (no icons).'
        TermShowAll       = 'a - show all themes'
        TermPreviewHint   = 'p <number> - preview in a new window'
        TermBack          = '0 - back'
        TermPreviewWindow = 'Preview. You can close this window.'
        TermFontInstalling = 'Conjuring the JetBrainsMono Nerd Font...'
        TermFontOk        = 'Font installed.'
        TermFontFail      = 'Could not install the font - install it manually from this link:'
        TermApplied       = 'Theme "{0}" applied.'
        TermIconWarn      = 'Without a Nerd Font, icons show as boxes.'
        TermLiveOk        = 'The prompt is live in this window - you can see it right now.'
        TermFontNewWindow = 'Font icons will appear after you open a new terminal window.'
        TermOpenNew       = 'Open a new terminal to see the result.'
        TermReverted      = 'Restored to previous state.'
        AiCat             = 'Set up AI for terminal work'
        AiTitle           = 'Set up AI for terminal work'
        AiProviderClaude  = '[1] Claude Code - prompt and statusline'
        AiProviderCodex   = '[2] Codex - statusline with context and plan limits, AutoSettings theme, no usage statistics'
        AiWarn            = @(
            'What will be done (after you confirm):',
            '- install oh-my-posh, the JetBrainsMono Nerd Font and Python (if missing);',
            '- install a rich Claude Code statusline with an AutoSettings. badge;',
            '- install a PowerShell profile (predictions, file icons, common tools).',
            'For the other agents (items 2-7) only missing lines are added to their settings - yours stay as they are.',
            'Administrator rights were already granted at start - no separate prompt.',
            'Everything is saved to a snapshot and restored with "r". Declining changes nothing.'
        )
        AiActions         = '1-7 - pick an agent    r - restore previous    0 - back'
        AiProviderCopilot = '[3] Copilot CLI - AutoSettings statusline: model, context, tokens, premium requests'
        AiProviderGemini  = '[4] Gemini CLI - footer with context and the daily limit, AutoSettings theme, no usage statistics'
        AiProviderQwen    = '[5] Qwen Code - statusline with context and tokens, no usage statistics'
        AiAgentMissing    = '{0} is not installed. Install it in "AI agents: install" and come back.'
        AiAgentSkipJson   = '{0} settings contain comments or cannot be read - changing nothing so as not to lose yours.'
        AiAgentAlready    = '{0} is already set up - nothing to change.'
        AiAgentOpenNew    = 'Restart {0} to see the result.'
        AiCopilotDone     = 'Copilot CLI set up: AutoSettings statusline, sessions stay local, tips and banner off.'
        AiCopilotPrivacyOnly = 'Copilot CLI already has its own statusline - kept it. Turned off session export, tips and banner.'
        AiCopilotNoOmp    = 'oh-my-posh for the Copilot statusline was not found - changing nothing. Set up item 1 or "Terminal" first.'
        AiGeminiDone      = 'Gemini CLI set up: footer with context and the daily limit, AutoSettings theme, statistics off.'
        AiQwenDone        = 'Qwen Code set up: statusline with context and tokens, statistics off.'
        AiSnapForged      = 'Snapshot {0} points outside the agent folders - skipped, nothing touched.'
        AiProviderOpencode = '[6] opencode - sessions are never shared by public link'
        AiProviderCrush   = '[7] Crush - no usage statistics, no Crush signature in commits'
        AiAgentOwnFile    = '{0} reads settings from a file you chose yourself - leaving it alone.'
        AiOpencodeDone    = 'opencode set up: sessions are no longer shared by public link. Its statusline cannot be customized.'
        AiCrushDone       = 'Crush set up: statistics off, no more Crush signature in commits. Its statusline cannot be customized.'
        AiCodexMissing    = 'Codex is not installed. Install it in "AI agents: install" and come back.'
        AiCodexSkip       = 'Codex settings have an unusual layout (the tui table twice, or tui.x lines) - changing nothing so as not to break them.'
        AiCodexAlready    = 'Codex is already set up - nothing to change.'
        AiCodexDone       = 'Codex set up: statusline with context and plan limits, AutoSettings theme, statistics and feedback off.'
        AiCodexOpenNew    = 'Restart Codex. Change the statusline items with /statusline.'
        AiPyChecking      = 'Checking Python...'
        AiPyInstalling    = 'Magic in progress: installing Python. This can take a couple of minutes...'
        AiPyReady         = 'Python is ready.'
        AiPyFail          = 'Could not install Python. If an old Python is on this computer, remove it in Installed apps and try again. Nothing changed.'
        AiModules         = 'Conjuring file icons and autocompletion...'
        AiProfileDone     = 'PowerShell profile installed.'
        AiStatusDone      = 'Claude Code statusline configured.'
        AiOpenNew         = 'Open a new terminal and Claude Code to see the result.'
        AiSettingsSkip    = 'Claude Code settings.json is unreadable - statusline not written, the rest is done.'
        AiPwshOffer       = @(
            'You are on Windows PowerShell 5.1 - an older version.',
            'We recommend installing the latest PowerShell 7 (installed side by side; 5.1 stays).',
            'Docs: https://learn.microsoft.com/powershell/'
        )
        AiPwshAsk         = 'Install PowerShell 7? (y - yes, Enter - skip)'
        AiPwshInstalling  = 'Installing PowerShell 7...'
        AiPwshDone        = 'PowerShell 7 installed (open it as pwsh).'
        AiPwshSkip        = 'PowerShell 7 not installed - continuing on the current version.'
        AiNodeChecking    = 'Checking Node.js/npm (needed for Claude Code MCP servers)...'
        AiNodeInstalling  = 'Installing Node.js (LTS)...'
        AiNodeReady       = 'Node.js/npm present.'
        AiNodeFail        = 'Could not install Node.js - Claude Code MCP servers will not work.'

        WslTitle     = 'WSL 2 + Ubuntu (Linux on Windows - for tmux and Unix tools)'
        WslWarn      = @(
            'What will be done (with your confirmation):',
            '- Windows features enabled: WSL and Virtual Machine Platform;',
            '- WSL 2 (Linux kernel) and the Ubuntu distribution installed;',
            'This is NOT a registry edit: it needs administrator rights and a REBOOT.',
            'Revert (r) removes the Ubuntu distro (wsl --unregister, its data is erased); WSL itself stays.',
            'Installed by a single call to the Microsoft-signed wsl.exe. Declining changes nothing.'
        )
        WslActions   = 'y - install    r - remove Ubuntu    0 - back'
        WslInstalling = 'Magic in progress: installing WSL 2 and Ubuntu. Windows will ask for permission, this can take a few minutes...'
        WslDone      = 'WSL 2 and Ubuntu installed. After a reboot open Ubuntu, set a username and password, then: sudo apt install tmux'
        WslReboot    = 'A reboot is required to finish installing WSL 2.'
        WslFail      = 'Could not install WSL (needs administrator rights and Windows 10 2004+/11). See the window that opened.'
        WslNoWsl     = 'wsl.exe not found or its signature is not confirmed - installation cancelled.'
        WslPresent   = 'Ubuntu is already installed in WSL - nothing changed.'
        WslRevertAsk = 'Remove the Ubuntu distribution from WSL? Its data will be erased. (y/n)'
        WslRevertNone = 'Ubuntu was not installed by this tool - nothing to remove.'
        WslReverted  = 'Ubuntu removed from WSL. WSL itself was kept.'
        WslRevertFail = 'Could not remove Ubuntu. Close the WSL windows and try again.'

        DevCat       = 'Additional developer tools'
        DevTitle     = 'Additional developer tools (via winget)'
        DevWarn      = @(
            'Installed by the signed winget package manager - no Chocolatey, no network installers.',
            'WSL needs administrator rights and a reboot; Build Tools C++ is several GB.',
            'Pick numbers to install. [+] means already installed.'
        )
        DevActions   = 'numbers - install   a - all   u - update   x - remove   0 - back'
        DevLooking   = 'Looking at what is already installed...'
        DevHave      = 'Already installed: {0}'
        DevReboot    = 'Installed, a restart is needed to finish: {0}'
        DevUpdated   = 'Updated: {0}'
        DevFresh     = 'Nothing to update: {0}'
        DevOpened    = 'Opened in the browser: {0}'
        DevLinksOnly = 'These are links to vendor pages - pick a number.'
        DevInstalling = 'Magic in progress: installing {0}. This can take a few minutes...'
        DevOk        = 'Installed: {0}'
        DevFail      = 'That did not work: {0}. Try again; if it does not help, restart the computer.'
        DevRemoving  = 'Removing: {0}...'
        DevRemoved   = 'Removed: {0}'
        DevRemoveAsk = 'Numbers to remove (space or comma separated)'
        DevRemoveConfirm = 'Remove from this computer: {0}? (y/n)'
        DevNoWinget  = 'winget not found or its signature is not confirmed - install App Installer from the Microsoft Store.'
        DevNeedNode  = '"{0}" needs Node.js - the "Developer tools" item installs it.'
        DevNodeAsk   = '"{0}" needs Node.js. Install it now? (y/n)'
        DevNodeRestart = 'Node.js is installed, but this window does not see it yet. Open a new window and try again.'
        AgentsTitle  = 'Console AI agents: install'
        AgentsWarn   = @(
            'Claude Code, Codex and Crush come from winget; Gemini CLI, opencode and Qwen Code from npm (Node.js needed).',
            'This screen does not touch keys or sign-in: each agent asks for them itself on first run.',
            'Pick numbers to install. [+] - already installed.'
        )
        TermWtAction = 'w - install Windows Terminal'
    }
}
