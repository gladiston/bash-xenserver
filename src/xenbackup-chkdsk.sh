#!/bin/bash
# Nome do script : xenbackup-stop.sh
# Autor : Hamacker (sirhamacker [em] gmail.com)
# Licença : GPL-2
# Função : Parar qualquer backup em andamento
# Identificando o pid de xenbackup-all.sh

# trap ctrl-c and call ctrl_c() trap ctrl_c INT
trap ctrl_c INT
function ctrl_c() { 
  echo "*** backup interrompido pelo usuario ***"  >&2
  exit 5;
}

#
# Inicio do Script
#
backup_dev_disk=$(/root/xendisk.sh)
is_mount_disk=0
mounted=0
tempfile=$(mktemp /tmp/check_inserted_midiabackup-XXXXXXXX)
if [ "$backup_dev_disk" != "" ] ; then 
  echo "Mídia de backup foi encontrada em:"
  echo -e "\t$backup_dev_disk"
else
  echo "Mídia de backup não foi encontrada no sistema."
  exit 2
fi

# Detectando se está montada ou nao
/bin/mount|grep "$backup_dev_disk"|grep -v "grep " |tee $tempfile
mounted=$(cat $tempfile|wc -l)
[ -f $tempfile ] && rm -f $tempfile
if [ $mounted -gt 0 ] ; then
  echo -e "\tMídia também está montada, enquanto estive em uso não posso prosseguir."
  exit 2;  
else
  echo -e "\tPronto para checagem e autoreparo, aguarde..."
fi

# Iniciando o scandisk
/sbin/fsck -vfy $backup_dev_disk
/sbin/e2label $backup_dev_disk xenbackup

exit $?

