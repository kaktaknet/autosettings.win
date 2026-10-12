# AutoSettings.win

[Русский](#русский) · [English](#english)

## Русский

Настройка Windows одной строкой. Вставь её в PowerShell - откроется меню, где ты сам выбираешь, что включить:

```powershell
irm https://get.autosettings.win | iex
```

Ничего не устанавливается и не запускается без твоего выбора. Каждое действие показано на экране до того, как оно выполнится.

**Что есть в меню**

- приватность: телеметрия, реклама и рекомендации Windows;
- удобный терминал: строка приглашения, шрифт, значки файлов;
- терминал для работы с ИИ;
- сеть, сертификаты и инструменты разработчика.

**Что лежит в этом репозитории**

Те же файлы, которые получает твой компьютер при запуске, байт в байт:

- `index.txt` - короткий загрузчик, его и отдаёт `get.autosettings.win`;
- `r/<выпуск>/` - файлы выпуска и `manifest.json` с их контрольными суммами.

Код открытый и читаемый: без сжатия, без шифрования, без скрытых частей. Можно прочитать всё до запуска.

**Как проверяется целостность**

В загрузчик вписана контрольная сумма SHA-256 описания выпуска, а в описании - суммы всех файлов. Файл с несовпавшей суммой не используется, откуда бы он ни пришёл. Поэтому выпуск раздаётся сразу с нескольких независимых хранилищ: если одно недоступно, загрузчик берёт файл со следующего.

Подробности и справка: [autosettings.win](https://autosettings.win)

## English

Windows setup in one line. Paste it into PowerShell and a menu opens where you choose what to turn on:

```powershell
irm https://get.autosettings.win | iex
```

Nothing is installed or run without your choice. Every action is shown on screen before it happens.

**What the menu offers**

- privacy: Windows telemetry, ads and suggestions;
- a comfortable terminal: prompt, font, file icons;
- a terminal set up for work with AI;
- network, certificates and developer tools.

**What is in this repository**

The same files your computer receives at launch, byte for byte:

- `index.txt` - the short loader, the one `get.autosettings.win` serves;
- `r/<release>/` - the release files and `manifest.json` with their checksums.

The code is open and readable: not minified, not encrypted, no hidden parts. You can read all of it before you run it.

**How integrity is checked**

The loader carries the SHA-256 checksum of the release description, and the description carries the checksums of every file. A file whose checksum does not match is not used, wherever it came from. That is why the release is served from several independent storages at once: when one is unreachable, the loader takes the file from the next.

Details and help: [autosettings.win](https://autosettings.win)
