#!/bin/bash
#
# Script para a realização de restore de um diretorio inteiro
# de máquinas virtuais
#
# No caso de pane, bastara montar o disco de backup e executar
# este script da seguinte forma :
# xenrestore.sh /media/backup/2011-02-25
# todos os arquivos *.bak serão recriados como maquinas virtuais
#

# trap ctrl-c and call ctrl_c() trap ctrl_c INT
trap ctrl_c INT
function ctrl_c() { 
  logger -t "XenRestore" -s "*** backup interrompido pelo usuario ***" ;
  exit 1;
}

function log() {
  # Exibe e Registra mensagens
  logger -t "XenRestore" -s "$1"  
  echo "$1" >>$arquivo_log
  echo "$1"
}

function aguarda_confirmacao_dupla() {
  read resposta
  if [ "$resposta" != "Sim" ] ; then
    echo "Abortando a operação."
    exit 1;
  fi 

  echo "Digite a senha do suporte :"
  read -s resposta
  if [ "$resposta" != "kubic2vidy" ] ; then
    echo "Abortando a operação. A senha não confere."
    exit 1;
  fi 
}
function vm_destroy_all() {
  # Destroi todas as VMs existentes neste servidor
  # Preciso de um arquivo temporario para conter os nomes das VMs
  tempfile=`mktemp`
  xe vm-list | grep "name-label" | grep -v "Control domain" | tr -s " " | cut -d " " -f 5 >$tempfile
  # Lê o arquivo temporario contendo os nomes das VMs e faz restore
  # de uma vm de cada vez, linha por linha.
  while read current_vm ; do
    vm_date_start="`date +%Y-%m-%d+%H:%M`"
    log "$vm_date_start : Eliminando VM [$current_vm]."
    # Removendo a VM
    xe vm-uninstall vm="$current_vm" force=true
    erro="$?" 
    vm_date_finish="`date +%Y-%m-%d+%H:%M`"
    if [ "$erro" -eq 0 ] ; then
      log "$vm_date_finish : Remoção da VM [$current_vm] concluída com sucesso." 
    else
      log "$vm_date_finish : Remoção da VM [$current_vm] falhou." 
    fi
  done <$tempfile
  [ -f "$tempfile" ] && rm -f "$tempfile"
}

#
# Inicio do Script
#
# Disco de Backup das VMs : Mencionar todos os UUID de discos que
# houverem. O Script só aceitará os UUIDs aqui mencionados
clear
date_start="`date +%Y-%m-%d+%H:%M`"
folder_restore="$1"
# Sistemas em poll requisitam que se identifique o SR-UUID
# caso contrario o restore nao funcionará 
pool=""
host=`hostname`
sr_uuid=""
xe_opt=""
pool=`xe pool-list |grep name-label|cut -d ":" -f2| tr -d ' '`
#if [ "$pool" != "" ] ; then
  sr_uuid=`xe sr-list name-label="Local storage" host=$host|grep "uuid"|cut -d":" -f2|tr -d " "`
  xe_opt="$xe_opt sr-uuid=$sr_uuid"  
#fi

# Arquivo de log
arquivo_log="/var/log/xenrestore-`date +%Y-%m-%d+%H_%M`.log"
touch "$arquivo_log"
log "Restauraçao de backup geral das maquinas virtuais em $date_start"
log "Pool: $pool"
log "SR: $sr_uuid"
log "Options: $xe_opt"

if [ "$pool" == "" ] && [ "$sr_uuid" == "" ]  ; then
  log "Parametros de pool e/ou uuid não foram detectados."
  exit 2;
fi

echo "Atençao :"
echo "A restauraçao indevida dos backups numa máquina que está funcionando"
echo "perfeitamente irá sobregrava-los resultando na perda definitiva dos"
echo "dados correntes existentes."
echo "Voce deseja realmente estaurar backups de :"
echo "  $folder_restore"
echo "Para este servidor de virtualização ?"
echo "Responda [Sim]"
aguarda_confirmacao_dupla

# Destruir todas as VMs atuais instaladas neste servidor ?
if [ "$2" = "--vm-destroy-all" ] ; then
  clear
  echo "Atençao :"
  echo "Foi mencionada a opçao [--vm-destroy-all]."
  echo "Esta opçao elimina todas as VMs instaladas neste servidor 
antes"
  echo "de proceder com a restauraçao dos backups."
  echo "Essa operaçao nao poderá ser desfeita."
  echo "Voce deseja realmente destruir todas as VMs instaladas neste servidor ?"
  echo "Responda [Sim]"
  aguarda_confirmacao_dupla
  vm_destroy_all
  echo "fim do teste"
  exit 2;
fi


# Preciso de um arquivo temporario para conter os nomes das VMs
tempfile=`mktemp`
#find $folder_restore -maxdepth 1 -name *.xva >$tempfile
find $folder_restore -maxdepth 1 >$tempfile

# Lê o arquivo temporario contendo os nomes das VMs e faz restore
# de uma vm de cada vez, linha por linha.
while read bakfilename ; do
  if [[ "$bakfilename" =~ ".xva" ]] ; then
    vm_date_start="`date +%Y-%m-%d+%H:%M`"
    log "$vm_date_start : Restaurando o backup [$bakfilename]."
    vm_date_finish="`date +%Y-%m-%d+%H:%M`"
    # Restaurando a VM
    xe vm-import $xe_opt filename=$bakfilename 
    if [ "$?" -eq 0 ] ; then
      log "$vm_date_finish : Restauração de [$bakfilename] concluída com sucesso." 
    else
      log "$vm_date_finish : Restauração de [$bakfilename] falhou." 
    fi
  fi  
done <$tempfile

[ -f "$tempfile" ] && rm -f "$tempfile"

# Finalizando o backup
date_finish="`date +%Y-%m-%d+%H:%M`"
log "Restauração geral das maquinas virtuais concluído em $date_finish"
echo "Poderá consultar o log de restauração dos backups no arquivo :"
echo "$arquivo_log"

exit 0
