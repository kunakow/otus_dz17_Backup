
#!/usr/bin/env bash

#Задание переменных окружения для Borg.
export BORG_RSH='ssh -i /home/borg/.ssh/id_rsa'
export BORG_PASSPHRASE="otus"
REPOSITORY="borg@borgserver:/var/backup/otus"

# Бэкап каталога /etc.
borg create -v --stats $REPOSITORY::'etc_otus-{now:%Y-%m-%d@%H:%M}' /etc

# Удаление лишних бэкапов. Глубина бекапа год, храним по последней копии на конец месяца, кроме последних трех. Последние три месяца содержат копии на каждый день.

borg prune -v $REPOSITORY --prefix 'etc_otus-' --list --keep-daily=90 --keep-monthly=12  

#Вывод информации о репозитории
borg list $REPOSITORY
