
#!/bin/bash
#Cкрипт позволяет автоматизировать создание клиентских конфигов OpenVPN На mikrotik. 
#В результате выполнения получаем папку users с конфигами и сертами пользователей раскиданными по папкам названным в соответствии с логином.
#Часть генерируемого файла конфига .ovpn - захардкожена. По мере необходимости поправить.
#Для работы требуется установленный scp и sshpass

#Использование:
#Подготовить файл со списком пользователей (Каждый логин с новой строки)
#Поправить секцию скрипта с генерацией конфига клиента (По необходимости)
#Сохранить текст скрипта в файл ovpn.sh например
#Запуск скрипта ./ovpn.sh <файл со списком пользователей>
#Ввести, запрошенные параметры

#Check if userlist has been provided
[ $# -eq 0 ] || [ $# -gt 1 ] && echo "Usage $0 <file that includes a users list>" && exit 1

# Setting variables
read -p "Enter Mikrotik IP: " IP
read -p "Enter MikroTik ssh port : " PORT
read -p "Enter Mikrotik ssh username : " LOGIN
read -p "Enter Mikrotik ssh PASSWORD: " PASSWORD
read -p "Enter CA name (Like it's named in MikroTik config) : " CA
read -p "Enter Passphrase for private keys : " PASSPHRASE
SERVICE=ovpn

#Getting some part of config from GW
sshpass -p $PASSWORD ssh $LOGIN@$IP 'interface ovpn-server server print' > serv.conf
OVPNPORT=$(awk '/port/ {print $2}' serv.conf | tr -d '\r')
DEV=$(awk '/mode/ {print $2}' serv.conf | tr -d '\r')
if [[ "$DEV" == "ip" ]]; then  DEV=tun; else DEV=tap; fi
AUTH=$(awk '/auth/ { print $2 }' serv.conf | tr -d '\r')
PROFILE=$(awk '/default-profile/ { print $2 }' serv.conf | tr -d '\r')
echo $PROFILE
#dir to save configs
mkdir users

#for all users stored in the provided file    
for var in $(cat $1)
do
# generating ppp profiles and certs
PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)
sshpass -p $PASSWORD ssh $LOGIN@$IP -p $PORT "ppp secret add name=$var profile=$PROFILE service=$SERVICE
password=$PASS"    
sshpass -p $PASSWORD ssh $LOGIN@$IP -p $PORT "certificate add name=$var common-name=$var days-valid=365
0 key-size=1024 trusted=no key-usage=tls-client"
sshpass -p $PASSWORD ssh $LOGIN@$IP -p $PORT "certificate sign $var ca=$CA"
sshpass -p $PASSWORD ssh $LOGIN@$IP -p $PORT "certificate export-certificate $var export-passphrase=$PA
SSPHRASE"

#create user config dir
mkdir ./users/$var

#Downloading certs
sshpass -p $PASSWORD scp $LOGIN@$IP:/cert_export_$var.crt ./users/$var
sshpass -p $PASSWORD scp $LOGIN@$IP:/cert_export_$var.key ./users/$var
sshpass -p $PASSWORD scp $LOGIN@$IP:/cert_export_$CA.crt ./users/$var

#Renaming certs to human readable style
mv ./users/$var/cert_export_$var.crt ./users/$var/$var.crt
mv ./users/$var/cert_export_$var.key ./users/$var/$var.key
mv ./users/$var/cert_export_$CA.crt ./users/$var/$CA.crt

#saving ppp user/pass to auth-cfg file
echo $var >> users/$var/$var.txt
echo $PASS >> users/$var/$var.txt

#saving config to file! Change it according to your needs.

echo "remote $IP $OVPNPORT" >> ./users/$var/$var.ovpn
echo "client" >> ./users/$var/$var.ovpn
echo "proto tcp" >> ./users/$var/$var.ovpn
echo "dev $DEV" >> ./users/$var/$var.ovpn
echo "ca $CA.crt" >> ./users/$var/$var.ovpn
echo "cert $var.crt" >> ./users/$var/$var.ovpn
echo "key $var.key" >> ./users/$var/$var.ovpn
echo "cipher AES-192-CBC" >> ./users/$var/$var.ovpn
echo "auth $AUTH" >> ./users/$var/$var.ovpn
echo "tun-mtu 1450" >> ./users/$var/$var.ovpn
echo "keepalive 10 120" >> ./users/$var/$var.ovpn
echo "persist-key" >> ./users/$var/$var.ovpn
echo "persist-tun" >> ./users/$var/$var.ovpn
echo "verb 3" >> ./users/$var/$var.ovpn
echo "route 192.168.0.0 255.255.255.0" >> ./users/$var/$var.ovpn
echo "auth-user-pass $var.txt" >> ./users/$var/$var.ovpn

done

