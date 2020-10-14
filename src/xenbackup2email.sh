#!/bin/bash
# Esse script cria um relatorio e envia por email contendo as VMs contidas na midia atual de backup
#
#
. /root/xenfunctions.sh
if [ $? -ne 0 ] ; then
  echo "Nao foi possivel importar o arquivo [/usr/bin/xenfunctions.sh] !"
  exit 2;
fi

#
# Inicio do Script
#
init_vars
date_start="`date +%Y-%m-%d+%H:%M`"
backup_title="Relatório do servidor [$HOSTNAME] em $date_start"
tempfile="/tmp/xenbackup-disco-conteudo-$$.txt"

# Diretorio onde esta feito o backup. Pode ser via NFS...
_MEDIABACKUP=/media/backup
backup_dev_disk=$($_SCRIPT_XENDISK)

echo "==============================================================\n"
echo "Lista das máquinas virtuais existentes no pool:\n"
$_SCRIPT_XENVMLIST halted=1 local=0 edit=0 update=0

echo "==============================================================\n"
already_mount=0
is_mount_disk "$_MEDIABACKUP"
[ $? -gt 0 ] && already_mount=1
# Montando a midia de backup
if [ $already_mount -le 0 ] ; then
  mount_disk
  if [ $? -gt 0 ] ; then 
    echo "Foi detectado midia de backup montada em $_MEDIABACKUP...\n"
  else 
    echo "Nao foi detectado midia de backup montada em $_MEDIABACKUP...\n"
    exit 2;  
  fi
fi
echo "==============================================================\n"
echo "Midia de backup inserida no servidor em $backup_dev_disk:\n"

# Listando todas os backups contidos no disco
find $_MEDIABACKUP -maxdepth 1 -type d -regex '.*/20[0-9][0-9]-[0-9][0-9]-[0-9][0-9].*' |sort -r  > "$tempfile"
while read folder ; do
  echo "Observando: $folder"
  ls -lRh "$folder" 
done <"$tempfile"

# Desmontando a midia de backup, se eu tive de montá-lo antes
if [ $already_mount -le 0 ] ; then
  umount_disk
fi
echo "==============================================================\n"
# Finalizando o script
[ -f "$tempfile" ] && rm -f "$tempfile"

exit 0
