#!/bin/bash
# Nome do script : xenbackup-all.sh
# Autor : Hamacker (sirhamacker [em] gmail.com)
# Licença : GPL-2
# Função : Script para a realização de backup completo de todas as VMs e
# tambem dispara o backup de outros servidores.
#
FILE_TEMP=$(mktemp /tmp/xenbackup-all-XXXXXXXX)
echo "Nome: ${0##*/}"| tee -a "$FILE_TEMP"
echo "Caminho: ${0%/*}"| tee -a "$FILE_TEMP"
echo "Nome completo: ${0}"  | tee -a "$FILE_TEMP"
echo "Argumentos: ${@}"| tee -a "$FILE_TEMP"

# XenA
/root/xenbackup.sh /root/xenbackup-list.txt | tee -a "$FILE_TEMP"
#/root/xenbackup.sh -local  | tee -a "$FILE_TEMP"

# XenB
/usr/bin/ssh root@192.168.1.4 "/root/xenbackup.sh /root/xenbackup-list.txt" | tee -a "$FILE_TEMP"
#/usr/bin/ssh root@192.168.1.4 "/root/xenbackup.sh -local"  | tee -a "$FILE_TEMP"


/root/enviar_email_admin.sh "<admin>" "Backup completo em $(date +%Y-%m-%d+%Hh%M)" "$FILE_TEMP" 
sleep 30s
[ -f "$FILE_TEMP" ] && rm -f "$FILE_TEMP"

