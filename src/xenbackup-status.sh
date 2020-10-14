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
WHEN_START=""
# Identificando o pid de xenbackup_all.sh
# Se nao retornar numero entao assume 0
#xenbackup_all=$(ps -eo pid,etime,cmd|grep "xenbackup-all.sh"|grep -v "grep")
xenbackup_all=$(ps ax|grep "xenbackup-all.sh"|grep -v "grep")
xenbackup_all="${xenbackup_all##*( )}"                                          # Trim
xenbackup_all_pid=$(eval echo "$xenbackup_all"|cut -d " " -f1)
# Se nao retornar numero entao assume 0
if ! [[ $xenbackup_all_pid =~ '^[0-9]+$' ]] ; then
   xenbackup_all_pid=0
else 
   xenbackup_all=$(ps -p $xenbackup_all_pid -o start,etime,cmd|tail -n1)
fi

# Identificando o pid de xenbackup.sh
# Se nao retornar numero entao assume 0
#xenbackup=$(ps -eo pid,etime,cmd|grep "/root/xenbackup.sh"|grep -v "grep")
xenbackup=$(ps ax|grep "xenbackup.sh"|grep -v "grep")
xenbackup="${xenbackup##*( )}"                                          # Trim
xenbackup_pid=$(eval echo "$xenbackup"|cut -d " " -f1)
if ! [[ $xenbackup_pid =~ '^[0-9]+$' ]] ; then
   xenbackup_pid=0
else 
   xenbackup=$(ps -p $xenbackup_pid -o start,etime,cmd|tail -n1)
fi

# Identificando o pid de vm_export
# Se nao retornar numero entao assume 0
vm_export=$(ps ax|grep "xe *vm-export* vm=snapshot"|grep -v "grep")
vm_export="${vm_export##*( )}"      
vm_export_pid=$(eval echo "$vm_export"|cut -d " " -f1)
if ! [[ $vm_export_pid =~ '^[0-9]+$' ]] ; then
   vm_export_pid=0
else 
   vm_export=$(ps -p $vm_export_pid -o start,etime,cmd|tail -n1)
fi

# Identificando o pid de fsck (se em execução)
# Se nao retornar numero entao assume 0
fsck=$(ps ax|grep "fsck"|grep -e ".ext[2-5]"|grep "$backup_dev_disk")
fsck="${fsck##*( )}"      
fsck_pid=$(eval echo "$fsck"|cut -d " " -f1)
if ! [[ $fsck_pid =~ '^[0-9]+$' ]] ; then
   fsck_pid=0
else 
   fsck=$(ps -p $fsck_pid -o start,etime,cmd|tail -n1)
fi
mounted=$(mount|grep "$backup_dev_disk"|wc -l)
running=$((xenbackup_all_pid+xenbackup_pid+vm_export_pid+fsck_pid+mounted))

if [ $running -gt 0 ] ; then
  if ! [ -z $_DATE_START ] && [ "$_DATE_START" != "" ] ; then
    echo "Backup iniciado provavelmente em $_DATE_START" 
  fi
  echo -e "(PID)\tData de Inicio\tRodando\tCMD"
  echo -e "($xenbackup_all_pid)\t $xenbackup_all"
  echo -e "($fsck_pid)\t $fsck"
  echo -e "($xenbackup_pid)\t $xenbackup"
  echo -e "($vm_export_pid)\t $vm_export"
  [ $mounted -gt 0 ] && echo "Midia de backup inserida em $backup_dev_disk"
else
  echo "Exibe informações do backup em atividade."
  echo "Nao ha nenhum processo de backup em execucao"
  echo "Use os parametros:"
  echo "  -k para parar o backup."
  echo "  -f para observar a execução do backup em atividade." 
fi


#
# Parar o backup?
#
if [ $running -gt 0 ] ; then
  if [ "$1" == "-k" ] ; then
    # matando os processos e fazendo eject da midia
    [ $fsck_pid -gt 0 ] && kill -9 $fsck_pid
    [ $xenbackup_all_pid -gt 0 ] && kill -9 $xenbackup_all_pid
    [ $xenbackup_pid -gt 0 ] && kill -9 $xenbackup_pid
    [ $vm_export_pid -gt 0 ] && kill -9 $vm_export_pid
    [ $mounted -gt 0 ] && umount "$backup_dev_disk"
    echo "Backup foi cancelado."
  fi
  logfile=$(ls -1t /var/log/xen/*.log |head -n1)
  echo "Para observar o andamento do processo de backup, observe o arquivo:"
  echo -e "\t$logfile"
  if [ "$1" == "-f" ] ; then
    tail -f "$logfile"
  fi
  echo "Use os parametros:"
  echo "  -k para parar o backup."
  echo "  -f para observar a execução do backup em atividade."  
else
  if [ $mounted -gt 0 ] ; then
    umount "$backup_dev_disk"
  fi
fi
