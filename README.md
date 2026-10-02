4make-hd-astra-installer.sh - скрипт по сборке загрузочного hdd носителя (в gpt и msdos)

Аргументы:
```
    -p          Путь к grub.cfg.
    -d          Путь к диску на который будет производиться установка (пример: -d /dev/sdb).
    -i          Перечислите образы iso для копирования на установочный диск (пример: -i isofile1.iso | /path1/*.iso)
    -g          Укажите таблицу разделов (msdos/gpt)
    -u          Размонтировать установочный диск (y/n)
    -cr         Запуск скрипта по копированию файлов с cdrom (y/n)

    -crh        Вывод help от скрипта по копированию файлов с cdrom
    -pcr        Путь к скрипту копирования с cdrom

    -h, --help  Показать эту справку и выйти

```

2iso_from_cdrom.sh - вспомогательный скрипт по созданию iso из cd диска астры

Аргументы:
```
    -o         Путь с названием файла на выходе (пример: /path1/path2/{filename} ).
    -l         Путь к cdrom
    -cp        Скопировать образ по стандартному пути - /tmp/isoroot/iso/{file.iso}? (y/n)

    -h, --help  Показать эту справку и выйти
```


grub.cfg - для 4make-hd-astra-installer.sh должен лежать рядом или указать путь к нему

Одна команда по установке с cdrom сразу в диск по пути /tmp/isoroot/iso/*.iso и перенос скрипта на диск в /tmp/scripts/2iso_from_cdrom 
--- `bash 4make-hd-astra-installer.sh -d /dev/sdX -g gpt/msdos -u n -cr y`

создать в $pwd образ с cdrom 
--- `bash 2iso_from_cdrom.sh -cp n`