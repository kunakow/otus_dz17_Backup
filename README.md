## Домашнее задание
### Настраиваем бэкапы

Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client

Настроить удаленный бекап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:

    - Директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB.
    - Репозиторий для резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение
    - Имя бекапа должно содержать информацию о времени снятия бекапа
    - Глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех. Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов
    - Резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации.
    - Написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение.

В приложенном Vagrantfile поднимаются 2 машины:
1. Borgserver. Директория /var смонтирована на отдельный диск. ip: 192.168.0.10
2. Client. ip: 192.168.0.20

На сервер и на клиент произвести установку Borgbackup:
```
sudo yum install epel-release -y
yum install borgbackup -y
```
На обеих машинах создать пользователя borg:
```
sudo useradd -m borg
```
Далее, настроить авторизацию по ssh-ключам, для этого генерируем на клиенте ssh-ключ:
```
su - borg
ssh-keygen
```
В каталоге ```~/.ssh``` создать файл ```config``` cо следующим содержимым:
```
Host borgserver            #  - имя сервера бэкапов
IdentityFile ~/.ssh/id_rsa             # - путь до зкарытого ключа
```
Затем, необходимо скопировать открытый ключ (id_rsa.pub), сгенерированный на клиенте, на сервер в файл ```/home/borg/.ssh/authorized_keys``` и привести его (файл) к виду (в данном примере использован рандомный публичный ключ):
```
'command="/usr/local/bin/borg serve" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9lDdaaNnAMrcmQOgh5sN4U6CCKu5D2Yjb64KHeMB+TW1a3qcqj4iVwm7134DjwhfkZXKq7BCxyQIw9A7i6EGTg08Q2St8w4jECO9JqQk2b0qh4uoDMRtRbRZymvOgNTSxjyyfkcpa8D5sv6uMDVyqtwSxsKcVmMn6/qtylV1l/LBhEZAovhudXDBZHkdRpm6G03shyZYsSd7mEhL/Umosf2QdWJXkw+aTr/Pqb06qGTXbJTehMYSAbZtgdYeYBlbPsalrYftwfGOWA4uD0/byl3IWsrfpk1LopducOLjpHAnt0Y1iiFa6r+U849ckyskcNYFnQIN60rOpDufK6aSx borg@client'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9lDdaaNnAMrcmQOgh5sN4U6CCKu5D2Yjb64KHeMB+TW1a3qcqj4iVwm7134DjwhfkZXKq7BCxyQIw9A7i6EGTg08Q2St8w4jECO9JqQk2b0qh4uoDMRtRbRZymvOgNTSxjyyfkcpa8D5sv6uMDVyqtwSxsKcVmMn6/qtylV1l/LBhEZAovhudXDBZHkdRpm6G03shyZYsSd7mEhL/Umosf2QdWJXkw+aTr/Pqb06qGTXbJTehMYSAbZtgdYeYBlbPsalrYftwfGOWA4uD0/byl3IWsrfpk1LopducOLjpHAnt0Y1iiFa6r+U849ckyskcNYFnQIN60rOpDufK6aSx borg@client
```
Это два одинаковых публичных ключа, первый дает возможность программе Borg Backup подключаться по ssh по ключу, второй дает возможность подключиться администратору через обычный ssh сеанс. 
ВАЖНО! Необходимо чтобы и на сервере и на клиенте в директориях /home/borg/.ssh для папок были права 700, а для файлов 600. Задается утилитой chmod.

Если в конфигурации отсутствует DNS, как в текущем примере, то на сервере и на клиенте в файле /etc/hosts необходимо явно указать и сопоставить ip-адреса и имена машин:
```
192.168.0.10 borgserver
192.168.0.20 client
```
На этом этапе авторизацию можно считать настроенной. Выполнить проверку можно командой (на клиенте от пользователя borg):
```
ssh borg@borgserver
```
Можно приступать к созданию первого бэкапа.
На сервере в каталоге /var создать папку backup где будет храниться репозиторий и выставить на неё соответствующие права:
```
sudo mkdir /var/backup
sudo chmod 700 /var/backup
sudo chown borg:borg /var/backup
```
Если используется SSH-ключ и это не ключ по умолчанию, то потребуется дополнительно задать использование конкретного ключа при помощи переменной окружения BORG_RSH. В ней можно задать команду SSH, которая будет использовать при работе Borg. По умолчанию это просто 'ssh':
```
export BORG_RSH='ssh -i /home/borg/.ssh/id_rsa'
```
При инициализации Borg будет запрошен пароль для репозитория. Доступ к репозиторию будет возможен только с этим паролем. Этот пароль будет требоваться как при операциях чтения, так и при операциях записи в репозиторий. Необходимо запомнить пароль, так как его невозможно восстановить! Для того чтобы не вводить пароль при каждом запуске Borg, можно задать переменную окружения BORG_PASSPHRASE:
```
export BORG_PASSPHRASE="otus"
```
С клиента инициализировать репозиторий на сервере командой:
```
borg init --encryption=repokey borg@borg:/var/backup/otus
```
Далее создать скрипт в /home/borg/backup_script.sh, отвечающий условиям задания:
```
#!/usr/bin/env bash

#Задание переменных окружения для Borg.
export BORG_RSH='ssh -i /home/borg/.ssh/id_rsa'
export BORG_PASSPHRASE="otus"
REPOSITORY="borg@borgserver:/var/backup/otus"

# Бэкап каталога /etc.
borg create -v --stats $REPOSITORY::'etc_otus-{now:%Y-%m-%d@%H:%M}' /etc

# Удаление лишних бэкапов. Глубина бекапа год, храним по последней копии на конец месяца, кроме последних трех. Последние три месяца содержат копии на каждый день.

borg prune -v $REPOSITORY --prefix 'etc_otus-' --list --keep-daily=90 --keep-monthly=12  

#Добавим вывод информации о репозитории
borg list $REPOSITORY


```
Сделать скрипт исполняемым:
```
chmod +x /home/borg/backup_script.sh
```
Запустить скрипт:
```
Creating archive at "borg@borgserver:/var/backup/otus::etc_otus-{now:%Y-%m-%d@%H:%M}"
------------------------------------------------------------------------------
Archive name: etc_otus-2021-04-20@09:18
Archive fingerprint: fcaf4a100ba3349d24beae388e6506b91c2e4985c00d4831d89edabb5e230215
Time (start): Tue, 2021-04-20 09:18:32
Time (end):   Tue, 2021-04-20 09:18:32
Duration: 0.28 seconds
Number of files: 1700
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               28.43 MB             13.49 MB            126.07 kB
All archives:               56.85 MB             26.99 MB             11.97 MB

                       Unique chunks         Total chunks
Chunk index:                    1288                 3396
------------------------------------------------------------------------------
Keeping archive: etc_otus-2021-04-20@09:18            Tue, 2021-04-20 09:18:32 [fcaf4a100ba3349d24beae388e6506b91c2e4985c00d4831d89edabb5e230215]
Pruning archive: etc_otus-2021-04-20@09:17            Tue, 2021-04-20 09:17:57 [fdb3f2ddaec0b430cb7cce3bdf9f72cc90ee27e3f2d643b7ee5a1593c5631730] (1/1)
etc_otus-2021-04-20@09:18            Tue, 2021-04-20 09:18:32 [fcaf4a100ba3349d24beae388e6506b91c2e4985c00d4831d89edabb5e230215]
```

Для того, чтобы скрипт отрабатывал каждые 5 минут, выполнить команду ```crontab -e``` и добавить следующую строку:
```
0/5 * * * * /home/borg/backup_script.sh
```



Ссылки на материалы:

  https://borgbackup.readthedocs.io/en/stable/usage/prune.html
  
  https://habr.com/ru/company/flant/blog/420055/
  
  https://community.hetzner.com/tutorials/install-and-configure-borgbackup/ru
  
  https://blog.andrewkeech.com/posts/170719_borg.html
