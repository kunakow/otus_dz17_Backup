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
ssh borg@borg-server
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
sh backup_script.sh
Creating archive at "borg@borgserver:/var/backup/otus::etc_otus-{now:%Y-%m-%d@%H:%M}"
/etc/crypttab: open: [Errno 13] Permission denied: '/etc/crypttab'
/etc/shadow: open: [Errno 13] Permission denied: '/etc/shadow'
/etc/gshadow: open: [Errno 13] Permission denied: '/etc/gshadow'
/etc/securetty: open: [Errno 13] Permission denied: '/etc/securetty'
/etc/libaudit.conf: open: [Errno 13] Permission denied: '/etc/libaudit.conf'
/etc/cron.daily/logrotate: open: [Errno 13] Permission denied: '/etc/cron.daily/logrotate'
/etc/.pwd.lock: open: [Errno 13] Permission denied: '/etc/.pwd.lock'
/etc/gshadow-: open: [Errno 13] Permission denied: '/etc/gshadow-'
/etc/shadow-: open: [Errno 13] Permission denied: '/etc/shadow-'
/etc/anacrontab: open: [Errno 13] Permission denied: '/etc/anacrontab'
/etc/cron.deny: open: [Errno 13] Permission denied: '/etc/cron.deny'
/etc/tcsd.conf: open: [Errno 13] Permission denied: '/etc/tcsd.conf'
/etc/chrony.keys: open: [Errno 13] Permission denied: '/etc/chrony.keys'
/etc/sudo-ldap.conf: open: [Errno 13] Permission denied: '/etc/sudo-ldap.conf'
/etc/sudo.conf: open: [Errno 13] Permission denied: '/etc/sudo.conf'
/etc/sudoers: open: [Errno 13] Permission denied: '/etc/sudoers'
/etc/selinux/targeted/semanage.trans.LOCK: open: [Errno 13] Permission denied: '/etc/selinux/targeted/semanage.trans.LOCK'
/etc/selinux/targeted/semanage.read.LOCK: open: [Errno 13] Permission denied: '/etc/selinux/targeted/semanage.read.LOCK'
/etc/selinux/targeted/active: scandir: [Errno 13] Permission denied: '/etc/selinux/targeted/active'
/etc/selinux/final: scandir: [Errno 13] Permission denied: '/etc/selinux/final'
/etc/polkit-1/rules.d: scandir: [Errno 13] Permission denied: '/etc/polkit-1/rules.d'
/etc/polkit-1/localauthority: scandir: [Errno 13] Permission denied: '/etc/polkit-1/localauthority'
/etc/ssh/ssh_host_rsa_key: open: [Errno 13] Permission denied: '/etc/ssh/ssh_host_rsa_key'
/etc/ssh/ssh_host_ed25519_key: open: [Errno 13] Permission denied: '/etc/ssh/ssh_host_ed25519_key'
/etc/ssh/sshd_config: open: [Errno 13] Permission denied: '/etc/ssh/sshd_config'
/etc/ssh/ssh_host_ecdsa_key: open: [Errno 13] Permission denied: '/etc/ssh/ssh_host_ecdsa_key'
/etc/dhcp: scandir: [Errno 13] Permission denied: '/etc/dhcp'
/etc/audisp: scandir: [Errno 13] Permission denied: '/etc/audisp'
/etc/grub.d: scandir: [Errno 13] Permission denied: '/etc/grub.d'
/etc/sysconfig/ip6tables-config: open: [Errno 13] Permission denied: '/etc/sysconfig/ip6tables-config'
/etc/sysconfig/iptables-config: open: [Errno 13] Permission denied: '/etc/sysconfig/iptables-config'
/etc/sysconfig/network-scripts/ifcfg-eth1: open: [Errno 13] Permission denied: '/etc/sysconfig/network-scripts/ifcfg-eth1'
/etc/sysconfig/crond: open: [Errno 13] Permission denied: '/etc/sysconfig/crond'
/etc/sysconfig/ebtables-config: open: [Errno 13] Permission denied: '/etc/sysconfig/ebtables-config'
/etc/sysconfig/sshd: open: [Errno 13] Permission denied: '/etc/sysconfig/sshd'
/etc/wpa_supplicant/wpa_supplicant.conf: open: [Errno 13] Permission denied: '/etc/wpa_supplicant/wpa_supplicant.conf'
/etc/pki/rsyslog: scandir: [Errno 13] Permission denied: '/etc/pki/rsyslog'
/etc/pki/CA/private: scandir: [Errno 13] Permission denied: '/etc/pki/CA/private'
/etc/security/opasswd: open: [Errno 13] Permission denied: '/etc/security/opasswd'
/etc/openldap/certs/password: open: [Errno 13] Permission denied: '/etc/openldap/certs/password'
/etc/gssproxy/99-nfs-client.conf: open: [Errno 13] Permission denied: '/etc/gssproxy/99-nfs-client.conf'
/etc/gssproxy/gssproxy.conf: open: [Errno 13] Permission denied: '/etc/gssproxy/gssproxy.conf'
/etc/gssproxy/24-nfs-server.conf: open: [Errno 13] Permission denied: '/etc/gssproxy/24-nfs-server.conf'
/etc/firewalld: scandir: [Errno 13] Permission denied: '/etc/firewalld'
/etc/vmware-tools/GuestProxyData/server/key.pem: open: [Errno 13] Permission denied: '/etc/vmware-tools/GuestProxyData/server/key.pem'
/etc/vmware-tools/GuestProxyData/trusted: scandir: [Errno 13] Permission denied: '/etc/vmware-tools/GuestProxyData/trusted'
/etc/audit: scandir: [Errno 13] Permission denied: '/etc/audit'
/etc/sudoers.d: scandir: [Errno 13] Permission denied: '/etc/sudoers.d'
------------------------------------------------------------------------------
Archive name: etc_otus-2021-03-22@17:40
Archive fingerprint: 458949ea0f81056c646b8fd5bde898ab938ba41757815a36c2c9f565a6bb6e9f
Time (start): Mon, 2021-03-22 17:40:39
Time (end):   Mon, 2021-03-22 17:40:39
Duration: 0.09 seconds
Number of files: 413
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               17.45 MB              5.86 MB                570 B
All archives:               52.35 MB             17.58 MB              5.89 MB

                       Unique chunks         Total chunks
Chunk index:                     412                 1242
------------------------------------------------------------------------------
Keeping archive: etc_otus-2021-03-22@17:40            Mon, 2021-03-22 17:40:39 [458949ea0f81056c646b8fd5bde898ab938ba41757815a36c2c9f565a6bb6e9f]
Pruning archive: etc_otus-2021-03-22@17:37            Mon, 2021-03-22 17:37:05 [4983a6bf9ee5353b1ea4321e8e68c2dab08149f729aafa71fb563332e75ca25c] (1/1)
client-2021-03-22@17:34              Mon, 2021-03-22 17:34:47 [72f0a10dd836e17d9015f9c0a26e224d169501a6e0be93bcacf1f4162c9fa6ae]
etc_otus-2021-03-22@17:40            Mon, 2021-03-22 17:40:39 [458949ea0f81056c646b8fd5bde898ab938ba41757815a36c2c9f565a6bb6e9f]
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
