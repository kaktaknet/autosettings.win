# AutoSettings.win

[Русский](#русский) · [English](#english)

## Русский

Настройка Windows одной строкой. Вставь её в PowerShell - откроется меню, где ты сам выбираешь, что включить:

```powershell
irm https://get.autosettings.win | iex
```

Ничего не устанавливается и не запускается без твоего выбора. Каждое действие показано на экране до того, как оно выполнится.

**Что есть в меню - семь разделов**

1. Быстрая настройка - готовые наборы настроек.
2. Приватность и реклама - сбор данных, реклама, ИИ в Windows, доступ приложений, браузеры.
3. Windows: работа и вид - поиск, Проводник, панель задач, окна, игры, обновления, «Починить Windows», компоненты, виды папок, поиск вредных правок чужих «оптимизаторов».
4. Электронная подпись и госуслуги - сертификаты удостоверяющих центров, КриптоПро, Рутокен и другие программы с проверкой подписи производителя.
5. Интернет и сеть - DNS, поиск Яндекса, выбор DNS-провайдера, удалённый помощник.
6. Для разработчика - терминал, Git и VS Code, WSL, ИИ-агенты (Claude Code, Codex, Gemini CLI и другие) и их настройка.
7. Программы - браузеры, документы, связь, утилиты, игры, VPN-клиенты и перенос программ на другой компьютер. Всё ставится через winget из официального каталога.

**Что лежит в этом репозитории**

Те же файлы, которые получает твой компьютер при запуске, байт в байт:

- `index.txt` - короткий загрузчик, его и отдаёт `get.autosettings.win`;
- `r/<выпуск>/` - файлы выпуска и `manifest.json` с их контрольными суммами.

Код открытый и читаемый: без сжатия, без шифрования, без скрытых частей. Можно прочитать всё до запуска.

**Как проверяется целостность**

В загрузчик вписана контрольная сумма SHA-256 описания выпуска, а в описании - суммы всех файлов. Файл с несовпавшей суммой не используется, откуда бы он ни пришёл. Поэтому выпуск раздаётся сразу с нескольких независимых хранилищ: если одно недоступно, загрузчик берёт файл со следующего.

**Лицензия**

Код распространяется по лицензии [Apache 2.0](LICENSE). Его можно читать, использовать, менять и распространять. Условие одно: сохранить указание автора - файлы `LICENSE` и `NOTICE` - и отметить, что изменено.

© 2026 kaktak.net

Подробности и справка: [autosettings.win](https://autosettings.win)

## English

Windows setup in one line. Paste it into PowerShell and a menu opens where you choose what to turn on:

```powershell
irm https://get.autosettings.win | iex
```

Nothing is installed or run without your choice. Every action is shown on screen before it happens.

**What the menu offers - seven sections**

1. Quick setup - ready-made sets of settings.
2. Privacy and ads - data collection, ads, AI in Windows, app permissions, browsers.
3. Windows: behavior and look - search, File Explorer, taskbar, windows, gaming, updates, "Repair Windows", Windows features, folder views, a scan for harmful tweaks left by other "optimizers".
4. E-signature and government services - certificate authority certificates, CryptoPro, Rutoken and other programs with the vendor signature checked.
5. Internet and network - DNS, Yandex search, a DNS provider of your choice, Remote Assistance.
6. For developers - terminal, Git and VS Code, WSL, AI agents (Claude Code, Codex, Gemini CLI and more) and their setup.
7. Programs - browsers, documents, messaging, utilities, games, VPN clients and moving your programs to another PC. Everything installs through winget from the official catalog.

**What is in this repository**

The same files your computer receives at launch, byte for byte:

- `index.txt` - the short loader, the one `get.autosettings.win` serves;
- `r/<release>/` - the release files and `manifest.json` with their checksums.

The code is open and readable: not minified, not encrypted, no hidden parts. You can read all of it before you run it.

**How integrity is checked**

The loader carries the SHA-256 checksum of the release description, and the description carries the checksums of every file. A file whose checksum does not match is not used, wherever it came from. That is why the release is served from several independent storages at once: when one is unreachable, the loader takes the file from the next.

**License**

The code is distributed under the [Apache 2.0](LICENSE) license. You may read, use, change and redistribute it. One condition: keep the author's notice - the `LICENSE` and `NOTICE` files - and state what you changed.

© 2026 kaktak.net

Details and help: [autosettings.win](https://autosettings.win)
