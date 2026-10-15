$AllStrings = @{
    ru = @{
        AppTitle     = 'autosettings.win - настройка приватности Windows'
        OsLine       = '{0}, сборка {1}'
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
        MenuExit     = '0 - выход'
        MenuAsk      = 'Номер пункта'
        NeedBuild    = '{0} - нужна сборка Windows от {1}'
        NotForWin    = 'Этот пункт не подходит для вашей версии Windows.'
        PickHint     = 'Введите номера пунктов через пробел, чтобы применить (например: 1 3).'
        PickActions  = 'a - применить все    r - вернуть как было    0 - назад'
        OptionalTag  = '(необязательно, меняет привычное поведение)'
        OptionalNote = 'Пункты с пометкой «необязательно» по кнопке «a» не применяются - выберите их номером.'
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
        LiveUac      = 'Windows спросит разрешение - ответьте «Да»'
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
        AiProviderCodex   = '[2] Codex - скоро'
        AiWarn            = @(
            'Что будет сделано (по вашему подтверждению):',
            '- установлены oh-my-posh, шрифт JetBrainsMono Nerd Font и Python (если нет);',
            '- установлен красивый статус-бар Claude Code с плашкой AutoSettings.;',
            '- установлен профиль PowerShell (подсказки, значки файлов, общие инструменты).',
            'Права администратора уже получены на старте - отдельного запроса не будет.',
            'Всё сохраняется в снимок и возвращается пунктом "r". Отказ ничего не меняет.'
        )
        AiActions         = '1 - настроить Claude Code    r - вернуть как было    0 - назад'
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
        OsLine       = '{0}, build {1}'
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
        MenuExit     = '0 - exit'
        MenuAsk      = 'Item number'
        NeedBuild    = '{0} - needs Windows build {1} or newer'
        NotForWin    = 'This item does not fit your version of Windows.'
        PickHint     = 'Enter item numbers separated by spaces to apply (for example: 1 3).'
        PickActions  = 'a - apply all    r - restore previous    0 - back'
        OptionalTag  = '(optional, changes usual behavior)'
        OptionalNote = 'Items marked "optional" are not applied by "a" - pick them by number.'
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
        LiveUac      = 'Windows will ask for permission - click Yes'
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
        AiProviderCodex   = '[2] Codex - coming soon'
        AiWarn            = @(
            'What will be done (after you confirm):',
            '- install oh-my-posh, the JetBrainsMono Nerd Font and Python (if missing);',
            '- install a rich Claude Code statusline with an AutoSettings. badge;',
            '- install a PowerShell profile (predictions, file icons, common tools).',
            'Administrator rights were already granted at start - no separate prompt.',
            'Everything is saved to a snapshot and restored with "r". Declining changes nothing.'
        )
        AiActions         = '1 - set up Claude Code    r - restore previous    0 - back'
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
