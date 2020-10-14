#!/bin/bash
#
# Nome:     xenbackup-cleansnapshots.sh
# Autor:    Hamacker (sirhamacker [em] gmail.com)
# Licença:  GPL-2
# Função:   Script para apagar snapshots velhos no sistema
#   --not-today: Apaga todos os snapshots, menos os que tiverem em sua 
#           descrição que foram criados hoje
# Os logs por padrão serao mantidos por pelo menos 30 dias, depois disso
# serão apagados.
. /root/xenfunctions.sh
if [ $? -ne 0 ] ; then
  echo "Nao foi possivel importar o arquivo [/root/xenfunctions.sh] !"
  exit 2;
fi

#
# Inicio do Script
#
init_vars
[ -z $_DATE_START ] && _DATE_START=$(date +%Y-%m-%d+%Hh%M)
NOT_CLEAN_DATE="apagar todos os snapshosts incluindo os criados em $_DATE_START"
if [ "$1" == "--not-today" ] ; then
  NOT_CLEAN_DATE=$(date +%Y-%m-%d)
fi

temp_file="/tmp/lista-xentemp-$$.txt"
echo "Limpeza de snapshots e logs em $HOSTNAME"

# Identificando o pid de vm_export, se existir entao nao poderá iniciar a limpeza
vm_export=$(ps ax|grep "xe *vm-export* vm=snapshot"|grep -v "grep"|wc -l)
# Se nao retornar nenhum numero para a variavel então...
if [ $vm_export -gt 0 ] ; then
   echo "Existe um snapshot em andamento, por isso não posso realizar limpeza incluindo as que foram criadas hoje." >&2
   NOT_CLEAN_DATE=$(date +%Y-%m-%d)
fi


# Informações se o backup está em andamento
echo -e "Iniciando o processo de limpeza de snapshots em  $_DATE_START"
xe snapshot-list is-control-domain=false  power-state=halted is-a-snapshot=true params=uuid|cut -d":" -f2|grep -v "^$"|grep -v "$NOT_CLEAN_DATE"|tr -d '^ ' > "$temp_file"
while read SNAP_UUID ; do  
  NAME_LABEL=$(xe snapshot-param-get param-name=name-label uuid=$SNAP_UUID)
  NAME_LABEL="${NAME_LABEL##*( )}" # Trim
  SNAP_EM_ANDAMENTO=$(ps axwwww|grep "$NAME_LABEL"|grep -v "grep "|wc -l)
  if [ $SNAP_EM_ANDAMENTO -eq 0 ] ; then
    if [[ "$NAME_LABEL" =~ "^snapshot-$HOSTNAME" ]] ; then
      echo -e "Eliminando o snapshot $NAME_LABEL [$SNAP_UUID]" 
      xe snapshot-destroy uuid=$SNAP_UUID
      ERRO=$?
      if [ $ERRO -eq 0 ] ; then
         echo -e "\t\tOK" 
      else
         echo -e "\t\tFALHOU" 
      fi
    fi
  fi
done <"$temp_file"

#
# Limpando arquivos de logs mais velhos que 30 dias
# "/var/log/xen/xenclean_backup-$HOSTNAME-$_DATE_START.log"
#
CURRENT_MONTH=$(date +%Y-%m)
find /var/log/xen/ -type f -mtime +30 -name xen*$HOSTNAME*.log  2>&1 | tee "$temp_file"
while read THIS_LOG ; do
  delete_file=1
  # apenas confirmando que o nome do arquivo nao coincida com ano-mes corrente. 
  if [[ "$THIS_LOG" =~ "$CURRENT_MONTH" ]] ; then
    delete_file=0
  fi
  if [ $delete_file -gt 0 ] ; then
      rm -f "$THIS_LOG" 
      echo -e "\tEliminando o log $THIS_LOG" 
      ERRO=$?
      if [ $ERRO -eq 0 ] ; then
          echo -e "\t\tOK" 
      else
          echo -e "\t\tFALHOU"
      fi
  fi
done <"$temp_file"

# Finalizando o backup
date_finish=$(date +%Y-%m-%d+%Hh%M)
echo "Limpeza de snapshots e logs encerrado em $date_finish"

exit 0
