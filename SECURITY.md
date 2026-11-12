# Security Policy

[English](#english) · [Русский](#русский)

## English

### Supported versions

AutoSettings has no installed versions. Every run of `irm https://get.autosettings.win | iex` downloads the current release, so only the **latest release** is supported. The release in use is the one named in [`index.txt`](index.txt); older folders under `r/` are kept for verification only and are not patched.

### Reporting a vulnerability

Please report privately, not in a public issue:

- **GitHub:** [Report a vulnerability](https://github.com/kaktaknet/autosettings.win/security/advisories/new) (private advisory);
- **Email:** [security@kaktak.net](mailto:security@kaktak.net).

Reports in English or Russian are welcome. Please include:

- what an attacker can do and under which conditions;
- the release ID (the folder name under `r/`) and the Windows version and edition;
- steps to reproduce, the menu item used, and the output or a screenshot;
- whether the issue is already public.

We acknowledge a report within three working days, keep you informed while we work on it, and publish the fix as a new release. With your permission, we credit you in the advisory.

### Scope

In scope:

- the loader [`index.txt`](index.txt) served by `get.autosettings.win`, and every file under `r/`;
- the integrity chain: the SHA-256 of `manifest.json` written into the loader and the per-file checksums in the manifest;
- every download mirror the loader uses;
- privilege handling: the menu runs as the user, and only the steps that need administrator rights ask for elevation;
- snapshots and rollback, which must restore exactly what was there before a change;
- any path that weakens Windows protection. By design, AutoSettings never turns off Microsoft Defender, UAC or Smart App Control; anything that does is a vulnerability.

Out of scope:

- third-party programs installed from the winget catalog or from their vendors' installers; please report those to their vendors;
- the behavior of DNS providers listed in the DNS menu;
- issues that require an already compromised computer or administrator rights the attacker already has;
- automated scanner reports without a demonstrated impact.

### Safe harbor

We will not take legal action against research done in good faith that stays on your own computers, avoids harm to other people's data and systems, and gives us reasonable time to fix the issue before disclosure.

## Русский

### Поддерживаемые версии

AutoSettings не устанавливается на компьютер. Каждый запуск `irm https://get.autosettings.win | iex` скачивает текущий выпуск, поэтому поддерживается только **последний выпуск**. Действующий выпуск назван в [`index.txt`](index.txt). Старые папки в `r/` хранятся только для сверки и не исправляются.

### Как сообщить об уязвимости

Сообщи закрыто, не в публичной задаче:

- **GitHub:** [Report a vulnerability](https://github.com/kaktaknet/autosettings.win/security/advisories/new) - закрытое сообщение;
- **Почта:** [security@kaktak.net](mailto:security@kaktak.net).

Можно писать по-русски или по-английски. Укажи:

- что может сделать злоумышленник и при каких условиях;
- номер выпуска (имя папки в `r/`), версию и редакцию Windows;
- как повторить, какой пункт меню, что вывелось на экран или снимок экрана;
- известно ли о проблеме публично.

Мы подтверждаем получение в течение трёх рабочих дней, сообщаем, как идёт работа, и выпускаем исправление новым выпуском. С твоего согласия называем тебя в описании уязвимости.

### Что входит

Входит:

- загрузчик [`index.txt`](index.txt), который отдаёт `get.autosettings.win`, и все файлы в `r/`;
- цепочка целостности: сумма SHA-256 файла `manifest.json` в загрузчике и суммы каждого файла в описании выпуска;
- все источники загрузки, к которым обращается загрузчик;
- права: меню работает от пользователя, права администратора просят только те шаги, которым они нужны;
- снимки и откат: возврат обязан вернуть ровно то, что было до правки;
- любой путь, ослабляющий защиту Windows. AutoSettings по замыслу никогда не выключает Защитник Microsoft, UAC и Smart App Control; всё, что их выключает, - уязвимость.

Не входит:

- сторонние программы из каталога winget и из установщиков производителей - о них сообщай производителю;
- работа DNS-провайдеров из меню DNS;
- проблемы, для которых компьютер уже должен быть взломан или у злоумышленника уже есть права администратора;
- отчёты автоматических сканеров без показанного вреда.

### Добросовестное исследование

Мы не преследуем исследования, сделанные добросовестно: на своих компьютерах, без вреда чужим данным и системам и с разумным сроком на исправление до огласки.
