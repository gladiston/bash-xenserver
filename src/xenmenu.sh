#!/bin/bash


# Funcoes importantes para este script
. /root/xenfunctions.sh
if [ $? -ne 0 ] ; then
  echo "Nao foi possivel importar o arquivo [/root/xenfunctions.sh] !"
  read espera
  exit 2;
fi

function read_backup_disk() {
  local slogfile="/tmp/read-backup-content-$$.log"
  
  $_SCRIPT_XENBACKUP2EMAIL  2>&1 | tee - "$slogfile"
  $_SCRIPT_SENDMAIL "$_MAILTO" "Conteúdo do disco inserido em $HOSTNAME em $(date +%Y-%m-%d+%Hh%M)" "$slogfile" 
  echo "Tecle [ENTER] para retornar."
  read espera
  [ -f "$slogfile" ] && rm -f "$slogfile"  
}

function check_inserted_midiabackup() {
  local backup_dev_disk=$(/root/xendisk.sh)
  local is_mount_disk=0
  local tempfile=$(mktemp /tmp/check_inserted_midiabackup-XXXXXXXX)
  if [ "$backup_dev_disk" != "" ] ; then 
    echo "Mídia de backup foi encontrada em:"
    echo -e "\t$backup_dev_disk"
  else
    echo "Mídia de backup não foi encontrada no sistema."
    return 2
  fi
  # Detectando se está montada ou nao
  /bin/mount|grep "$backup_dev_disk"|grep -v "grep " |tee $tempfile
  local mounted=$(cat $tempfile|wc -l)
  [ -f $tempfile ] && rm -f $tempfile
  if [ $mounted -gt 0 ] ; then
    echo -e "\tMídia também está montada, se persistir assim, o próximo backup falhará."
    echo -e "\tObservando se há um backup em andamento, isso poderia explicar porque a midia está montada..."
    $_XENPATH/xenbackup-status.sh;
    echo -e "\tSe for observado um backup em andamento acima, então aguarde."
    echo -e "\tCaso contrário, contate o administrador para desmontar a unidade antes que o agendamento do próximo backup falhe."
    return 2;  
  else
    echo -e "\tEstá pronto para o próximo backup agendado."
  fi
  

}

#
# Inicio do Script
#

init_vars

clear
while :
do
  clear
  echo "-------------------------------------------------------------"
  echo " Servidor: $HOSTNAME"
  echo "-------------------------------------------------------------"
  echo "1- Realizar o backup completo agora"
  echo "2- Observar se há backup em andamento"
  echo "3- Observar se a mídia de backup está online"
  echo "4- Listar as VMs existentes"
  echo "5- Editar as VMs que serão copiadas para a mídia de backup"
  echo "6- Editar lista de discos aceitos como mídia de backup "
  echo "7- Limpar Backups antigos"
  echo "8- Limpar snaphosts"
  echo "9- Checar e conferir o disco de backup"
  echo "10-Enviar listagem da mídia de backup por email"
  echo "11-Editar agendamentos"
  echo "12-VMs com inicio automatico apos boot do xenserver"
  echo "90-Testar o acesso a internet"
  echo "91-Testar o envio de email"
  echo "97-Desligar"
  echo "99-Sair"
  echo -n "Escolha uma opcao [1-99] :"
  read opcao
  case $opcao in
  1)$_SCRIPT_XENBACKUP;
    press_enter_to_continue;;
  2)$_XENPATH/xenbackup-status.sh;
    echo "Tecle [ENTER] para retornar.";
    read espera;;
  3)check_inserted_midiabackup;
    echo "Tecle [ENTER] para retornar.";
    read espera;;
  4)$_SCRIPT_XENVMLIST;
    echo "Tecle [ENTER] para retornar.";
    read espera;;
  5)editar $_XENPATH/xenbackup-list.txt;;
  6)editar $_XENPATH/xendisk.sh;;
  7)$_SCRIPT_XENCLEAN
    echo "Tecle [ENTER] para retornar.";
    read espera;;
  8)$_SCRIPT_XENCLEANSNAP
    press_enter_to_continue;;
  9)$_XENPATH/xenbackup-chkdsk.sh;
    echo "Tecle [ENTER] para retornar.";
    read espera;;
  10)read_backup_disk;;
  11)crontab -e;;
  12) if [ -f "/etc/xenboot-lista.txt" ] ; then
	      editar "/etc/xenboot-lista.txt"
        $_SCRIPT_XENSTART_VM	"/etc/xenboot-lista.txt"		
      else
		    echo "# Lista das VMs que poderao ter inicio automatico" >"/etc/xenboot-lista.txt"
		    echo "# apos o boot do xenserver." >>"/etc/xenboot-lista.txt"
		    echo "# Formato:" >>"/etc/xenboot-lista.txt"
		    echo "# VM_NAME [true/false]" >>"/etc/xenboot-lista.txt"
     fi	 
     press_enter_to_continue;;
  90)$_XENPATH/testar_internet_basic.sh;
    echo "Tecle [ENTER] para retornar.";
    read espera;;
  91)$_XENPATH/testar_email.sh;
    echo "Tecle [ENTER] para retornar.";
    read espera;;
  97)sudo poweroff;;
  98)sudo bash --noprofile --norc;;
  99)exit 0;;
  *) echo "Opcao invalida !!!"; sleep 1;;
  esac
done
}



# Fim do Programa
