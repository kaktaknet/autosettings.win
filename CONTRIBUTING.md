# Contributing

[English](#english) · [Русский](#русский)

## English

### Pull requests are not accepted

This repository is the published copy of each release, byte for byte: the loader [`index.txt`](index.txt) and the release folders under `r/`. The code is developed and tested elsewhere, and every file here is pinned by a SHA-256 checksum that the loader verifies. A change made in this repository could not be released, so pull requests are closed without review.

### How you can help

- **Found a bug?** Open an [issue](https://github.com/kaktaknet/autosettings.win/issues) with the release ID (the folder name under `r/`), the Windows version and edition, the menu item you used, and what appeared on the screen.
- **Found a vulnerability?** Do not open an issue. Follow [SECURITY.md](SECURITY.md).
- **Have an idea?** Describe it in an issue. Suggestions are welcome; whether and how one is built is decided by the author.

### Using the code

The code is licensed under [Apache 2.0](LICENSE). You may fork it and build on it in your own project, provided you keep [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE) and state what you changed.

## Русский

### Правки (pull request) не принимаются

Этот репозиторий - опубликованная копия каждого выпуска, байт в байт: загрузчик [`index.txt`](index.txt) и папки выпусков в `r/`. Код пишется и проверяется в другом месте, а каждый файл здесь закреплён суммой SHA-256, которую сверяет загрузчик. Правку, сделанную в этом репозитории, выпустить нельзя, поэтому pull request закрываются без рассмотрения.

### Чем можно помочь

- **Нашёл ошибку?** Открой [задачу](https://github.com/kaktaknet/autosettings.win/issues): номер выпуска (имя папки в `r/`), версия и редакция Windows, пункт меню и что вывелось на экран.
- **Нашёл уязвимость?** Задачу не открывай, следуй [SECURITY.md](SECURITY.md).
- **Есть идея?** Опиши её в задаче. Предложениям мы рады; делать ли и как - решает автор.

### Использование кода

Код распространяется по лицензии [Apache 2.0](LICENSE). Его можно взять и развивать в своём проекте, если сохранить [`LICENSE`](LICENSE) и [`NOTICE`](NOTICE) и отметить, что изменено.
