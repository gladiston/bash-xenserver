#!/bin/bash
# Nome do script : xenbackup.sh
# Autor : Hamacker (sirhamacker [em] gmail.com)
# Licença : GPL-2
# Função : Script para a realização de backup de todas ou apenas
#          as VMs selecionadas de um servidor de Virtualização.
# Parametros:
#   <nomearq>   Nome do arquivo contendo a lista de VMs que serão copiadas
#   -local   	Copie todas as VMs locais, isto é, residentes neste host
#   -all   		Copie todas as VMs do pool
#   -no-email   Não envia email após a conclusão do backup
#   -no-fsck   	Não executa o fsck mesmo que seja necessário
#
# No caso de pane, bastara importar essas VMs do seguinte modo :
# Para desinstalar a VM defeituosa
# xe vm-uninstall uuid=<VM UUID> force=true
#     para saber a UUID de uma VM usamos  a instrução 'xe vm-list'
# Limpamos o repositório da storage :
# colasce-leaf -u <VM UUID>
# Por fim, restauramos o backup da VM
# xe vm-import filename=vm.xva preserve=true
#    a instrução 'preserve=true' mantém o MacAddr original da VM.
#
# Informacoes de como é o processo de backup no Xen podem ser obitidas em :
# http://www.slideshare.net/tkrampe/backup-virtual-machines-with-xenserver-5x
#
. /root/xenfunctions.sh
if [ $? -ne 0 ] ; then
  echo "Nao foi possivel importar o arquivo [/root/xenfunctions.sh] !"
  exit 2;
fi

#
# Inicio do Script
#
init_vars


# Quando debug ligado, o backup não será transferido, porém a limpeza do disco acabará ocorrendo
DEBUG=$_DEBUG
EXEC_SENDMAIL=1
EXEC_FSCK=0

#DEBUG=1
[ -z $_DATE_START ] && _DATE_START=$(date +%Y-%m-%d+%Hh%M)

# Confere se o backup já não está rodando e neste caso aborta a operação
LINHAS=$(ps ax|grep "xe *vm-export* vm=snapshot"|grep -v "grep"|wc -l)
if [ $LINHAS -gt 0 ] ; then
  echo "Há um backup em andamento, não posso executar novamente enquanto ele estiver em operação." 
  exit 2
fi


# confere se um dos parametros é uma especificacao de arquivo
ARQ_BACKUP_LISTA=""
for CURRENT_PARAM in "$@" ; do
  CURRENT_PARAM="${CURRENT_PARAM##*( )}"                                          # Trim
  if [ -f "$CURRENT_PARAM" ] ; then 
    if ! [[ "$CURRENT_PARAM" =~ "^-" ]] && [ "$ARQ_BACKUP_LISTA" == "" ] ; then
      ARQ_BACKUP_LISTA="$CURRENT_PARAM"
    fi
  fi
  if [[ "$CURRENT_PARAM" =~ "-local" ]] ; then
    ARQ_BACKUP_LISTA="/tmp/xenbackup-lista-local-$$.txt"
    $_SCRIPT_XENBACKUPESTIMATE -local |grep -v "Total estimado" | tee "$ARQ_BACKUP_LISTA"
  fi
  if [[ "$CURRENT_PARAM" =~ "-all" ]] ; then 
    ARQ_BACKUP_LISTA="/tmp/xenbackup-lista-todos-$$.txt"
    $_SCRIPT_XENBACKUPESTIMATE -all |grep -v "Total estimado" -f1 | tee "$ARQ_BACKUP_LISTA"
  fi
  if [[ "$CURRENT_PARAM" =~ "-no-email" ]] ; then 
    EXEC_SENDMAIL=0
  fi  
  if [[ "$CURRENT_PARAM" =~ "-no-fsck" ]] ; then 
    EXEC_FSCK=0
  fi    
done

if [ "$ARQ_BACKUP_LISTA" == "" ] ; then
  ARQ_BACKUP_LISTA="/tmp/xenbackup-lista-local-$$.txt"
  echo "$_SCRIPT_XENBACKUPESTIMATE -local |grep -v 'Total estimado' | tee '$ARQ_BACKUP_LISTA'" >&2;
  $_SCRIPT_XENBACKUPESTIMATE -local |grep -v "Total estimado" | tee "$ARQ_BACKUP_LISTA"
fi

#
# Considerando a possibilidade de executar uma checagem de disco
# A mesma só é executada nos sabados(6) ou domingos(7) ou após as 20h
try_fsck=0
if [ $EXEC_FSCK -gt 0 ] ; then
  REQUER_FSCK=$(date +%u)
  [ $REQUER_FSCK -ge 6 ] && try_fsck=1

  # Tambem o FSCK pode ser executado após as 20h da noite, não importa o dia
  # da semana.
  if [ $try_fsck -eq 0 ] ; then
    REQUER_FSCK=$(date +%H)
    [ "$REQUER_FSCK" -ge 08 ] && try_fsck=1
    [ $try_fsck -gt 0 ] && echo "A checagem de disco será realizado no final de execução desse programa."
  fi
fi

erro=0
backup_title="Backup das maquinas virtuais em $HOSTNAME-$_DATE_START ($ARQ_BACKUP_LISTA)" 

# Arquivo de log
_XENBACKUP_LOGFILE="/var/log/xen/xenbackup-$HOSTNAME-$_DATE_START.log" 
[ -f "$_XENBACKUP_LOGFILE" ] && rm -f "$_XENBACKUP_LOGFILE"

# Avisando os terminais, que talvez se estiverem abertos de que o backup está se iniciando
cab_msg="========== inicio do backup [ $HOSTNAME ] em $_DATE_START =============="
cab_msg="$cab_msg\n$backup_title"
cab_msg="$cab_msg\nLog: $_XENBACKUP_LOGFILE"
echo -ne "$cab_msg\n"

# Diretorio onde sera feito o backup. Pode ser via NFS...
_BACKUP_FOLDER="$_MEDIABACKUP/$_DATE_START"
backup_dev_disk=$($_SCRIPT_XENDISK)
# Desmontando a midia de backup, se a mesma estiver montada.
is_mount_disk "$_MEDIABACKUP"
if [ $? -gt 0 ] ; then
  umount_disk "$_MEDIABACKUP"
fi

# Desmontando a midia de backup, se a mesma estiver montada.
is_mount_disk "$_MEDIABACKUP"
if [ $? -gt 0 ] ; then
  echo "Mídia de backup já estava montada e provavelmente em uso, não posso prosseguir."=
  sair 2
fi

if [ $try_fsck -gt 0 ] ; then
  echo "Executando checagem de disco em $backup_dev_disk..." | tee -a "$_XENBACKUP_LOGFILE"
  /sbin/fsck -vfy $backup_dev_disk | tee -a "$_XENBACKUP_LOGFILE"
  if [ $? -eq 0 ] ; then
    echo "Checagem de disco (fsck) foi executado em $backup_dev_disk e não encontrou nenhum problema."
  else
    echo "Checagem de disco (fsck) foi executado em $backup_dev_disk e fez reparos." 
  fi
fi


# Montando a midia de backup
mount_disk
if [ $? -gt 0 ] ; then 
  echo "Foi detectado midia de backup montada em $_MEDIABACKUP..."
else 
  echo "Nao foi detectado midia de backup montada em $_MEDIABACKUP..."
  sair 2;  
fi


echo -ne "Debug:\n$_SCRIPT_XENBACKUPESTIMATE \"$ARQ_BACKUP_LISTA\"\n"  >&2;
_WANT_SPACE=$($_SCRIPT_XENBACKUPESTIMATE "$ARQ_BACKUP_LISTA")

echo -ne "Retornou:\n$_WANT_SPACE\n" >&2;
if [[ "$_WANT_SPACE" =~ "Total estimado" ]] ; then
  _WANT_SPACE=$(echo "$_WANT_SPACE"|grep 'Total estimado'|cut -d':' -f2|cut -d'G' -f1|tr -d '[:alpha:]'|tr -d '[:space:]')
fi

# Se nao retornar nenhum numero então...
echo "_WANT_SPACE=$_WANT_SPACE"   >&2;
if ! is_number $_WANT_SPACE; then
   echo "Não foi possivel calcular o tamanho estimado para o backup: $_WANT_SPACE"  
   echo "Variavel _WANT_SPACE não é um numero."  
   sair 2
fi



# Limpeza de backup aumentará o espaço em disco para os novos backups, 
# Mas a limpeza só ocorrerá se o disco estiver com menos de $_WANT_SPACE Gigas disponiveis
do_clean=0
space_free "$backup_dev_disk" "GB"
DevFilesystem1=$DevFilesystem
DevBlocks1k1=$DevBlocks1k
DevUsed1=$DevUsed
DevAvailable1=$DevAvailable
DevUsePerc1=$DevUsePerc
DevMountedOn1=$DevMountedOn
if [ "$DevFilesystem1" == "-" ] || [ "$DevFilesystem1" == "" ] ; then
  echo "Processo interrompido porque nao pude observar espaço livre em $backup_dev_disk..." 
  sair 2;  
fi
echo "Espaço no disco de backup antes da limpeza em $DevFilesystem1:"  
echo -e "\tEspaço usado: $DevUsed1 GB ($DevUsePerc1%)"  
echo -e "\tEspaço disp.: $DevAvailable1 GB" 
echo -e "\tEspaço req.: $_WANT_SPACE GB" 
espaco_disponivel=$DevAvailable1

# Se nao retornar nenhum numero para a variavel então...
#if ! [[ $espaco_disponivel =~ '^[0-9]+$' ]] ; then
if ! is_number $espaco_disponivel ; then
   echo "Não foi possivel calcular o espaço estimado no disco para realização do backup: $espaco_disponivel"  
   echo "Variavel [espaco_disponivel] não é um numero."  
   sair 2
fi  

if [ $espaco_disponivel -lt $_WANT_SPACE ] ; then
  do_clean=1
  echo "A limpeza do disco esta sendo exigida porque há $espaco_disponivel GB disponíveis (requer $_WANT_SPACE GB)." 
else
  echo "A limpeza do disco não será necessária porque há $espaco_disponivel GB disponíveis (requer $_WANT_SPACE GB)." 
fi

if [ $do_clean -gt 0 ] ; then
  if [ -f "$_SCRIPT_XENCLEAN" ] ; then
    if [ $DEBUG -le 0 ] ; then
      echo "Debug: $_SCRIPT_XENCLEAN \"$ARQ_BACKUP_LISTA\" \"-log:$_XENBACKUP_LOGFILE\"" 
      $_SCRIPT_XENCLEAN "$ARQ_BACKUP_LISTA" "-min:$_WANT_SPACE"
    fi
    is_mount_disk "$_MEDIABACKUP"
    if [ $? -le 0 ] ; then 
      echo "disco $_MEDIABACKUP esta desmontado, montando-o..." 
      mount_disk
    fi
    space_free "$backup_dev_disk" "GB"
    DevFilesystem2=$DevFilesystem
    DevBlocks1k2=$DevBlocks1k
    DevUsed2=$DevUsed
    DevAvailable2=$DevAvailable
    DevUsePerc2=$DevUsePerc
    DevMountedOn2=$DevMountedOn
    if [ "$DevFilesystem2" == "-" ] ; then
      echo "Processo interrompido porque nao pude observar espaço livre em $backup_dev_disk..."  
      sair 2;  
    fi
    echo "Espaço no disco de backup antes da limpeza em $DevFilesystem1:" 
    echo -e "\tEspaço usado: $DevUsed1 GB ($DevUsePerc1%) para $DevUsed2 GB ($DevUsePerc2%)" 
    echo -e "\tEspaço disp.: $DevAvailable1 GB para $DevAvailable2 GB" 
    echo -e "\tEspaço req.: $_WANT_SPACE GB" 
    espaco_disponivel=$DevAvailable2
    if [ $espaco_disponivel -lt $_WANT_SPACE ] ; then
      echo "A limpeza do disco não foi suficiente para iniciar a execução do backup." 
      echo "2021-01-12 alteração para prosseguir assim mesmo." 
      #sair 2;
    fi
  else
    echo "Limpeza nao foi realizada porque nao achei o script $_SCRIPT_XENCLEAN" 
  fi
fi


# As linhas abaixo com respeito a sintaxe foi baseado noutro script
# que pode ser obtido no site :
# http://olamundo.org/posts/xenserver-backup-automatico-de-vms
# Porém reformulei o script e ele se tornou bem diferente do original

# Use remark (#) precedendo o nome da VM para comentar
# Pontos comentario não serão executados
if ! [ -f "$ARQ_BACKUP_LISTA" ] ; then
  echo "# Lista das VMs que fará backup" | tee "$ARQ_BACKUP_LISTA"
  echo "# Inclua remarks # para que qualquer linha seja ignorada" | tee -a "$ARQ_BACKUP_LISTA"
  echo "# transformada em comentario, como eu fiz com essas 3 linhas iniciais." | tee -a "$ARQ_BACKUP_LISTA"
  echo "# Apague este arquivo e um novo será criado com o nome de todas as VMs existentes" | tee -a "$ARQ_BACKUP_LISTA"
  echo "# Ou se preferir execute [ xe vm-list |grep name-label]" | tee -a "$ARQ_BACKUP_LISTA"
  xe vm-list | grep "name-label" | grep -v "Control domain" | tr -s " " | cut -d " " -f 5 | tee -a "$ARQ_BACKUP_LISTA"
  echo "Arquivo contendo a lista das VMs que serão copiadas não existe:"
  echo -e "\t$ARQ_BACKUP_LISTA"
  echo "Assim, criei uma lista contendo o nome de todas as  VMs."
  echo "Nao farei o backup agora, na expectativa que você edite o arquivo acima."
  echo "Caso não faça a edição, todas as VMs serão copiadas para a midia de backup."
  sair 2;
fi

is_mount_disk "$_MEDIABACKUP"
if [ $? -le 0 ]; then 
  echo "Disco $_MEDIABACKUP esta desmontado, não posso prosseguir com o backup..." 
  sair 2
fi

# Diretorio onde serao colocados o backup dentro da midia
if ! [ -d "$_BACKUP_FOLDER" ] ; then
  /bin/mkdir -p "$_BACKUP_FOLDER" 
fi

# Lê o arquivo temporario contendo os nomes das VMs e faz backup de uma vm de cada vez
# linha por linha.
while read LINHA ; do
  erro=0
  vm_existe=0
  VM_NAME=`semremarks "$LINHA"`

  [ "$_DEBUG" = "1" ] && echo "Processando : $LINHA ($VM_NAME)"
  [ "$VM_NAME" != "" ] && vm_existe=$(xe vm-list|grep "$VM_NAME"|wc -l)
  if [ "$vm_existe" -gt 0 ] ; then
    # VM Está offline?
    vm_existe=$(xe vm-list name-label="$VM_NAME" params=power-state|grep "halted"|wc -l)
    if [ $vm_existe -gt 0 ] ; then
      # VM Offline
      TransfVM2Disk_Offline "$VM_NAME" "$_BACKUP_FOLDER"
      erro=$?   
    else
      # VM Está Online
      TransfVM2Disk_Online "$VM_NAME" "$_BACKUP_FOLDER"
      erro=$?
    fi
  else
    [ "$_DEBUG" = "1" ] && echo -e "\tLinha ignorada : $LINHA"
  fi
done <"$ARQ_BACKUP_LISTA"

# Copia o script de backup e restauracao para dentro da midia
# Assim se mudanças no script forem realizadas, voce saberá que
# cada pasta de backup contém a versão original do script com o
# qual aquele backup foi realizado.
is_mount_disk "$_MEDIABACKUP"
if [ $? -le 0 ] ; then
  echo "Mídia de backup já estava desmontada quase na parte conclusiva do script, por isso não posso prosseguir com o backup de scripts e envio de emails para os gestores." | tee -a "$_XENBACKUP_LOGFILE"
  sair 2
fi
FILE_TMP=$(mktemp "/tmp/xenbackup-copy-scripts-XXXXXXXX")
echo "Copiando scripts utilizados para a unidade de backup $_BACKUP_FOLDER"

find "$(dirname $_SCRIPT_XENBACKUP)/"*.sh > "$FILE_TMP"
while read THIS_SCRIPT ; do
  [ -f "$_BACKUP_FOLDER/$(basename $THIS_SCRIPT)" ] && mv -f "$_BACKUP_FOLDER/$(basename $THIS_SCRIPT)" "$_BACKUP_FOLDER/$(basename $THIS_SCRIPT).$_DATE_START"
  cp -f "$THIS_SCRIPT" "$_BACKUP_FOLDER/"
done < "$FILE_TMP"
[ -f "$_BACKUP_FOLDER/$(basename $ARQ_BACKUP_LISTA)" ] && mv -f "$_BACKUP_FOLDER/$(basename $ARQ_BACKUP_LISTA)" "$_BACKUP_FOLDER/$(basename $ARQ_BACKUP_LISTA).$_DATE_START"
cp -f "$ARQ_BACKUP_LISTA" "$_BACKUP_FOLDER/$(basename $ARQ_BACKUP_LISTA)"
[ -f "$_BACKUP_FOLDER/$(basename $_XENBACKUP_LOGFILE)" ] && mv -f "$_BACKUP_FOLDER/$(basename $_XENBACKUP_LOGFILE)" "$_BACKUP_FOLDER/$(basename $_XENBACKUP_LOGFILE).$_DATE_START"
cp -f "$_XENBACKUP_LOGFILE" "$_BACKUP_FOLDER/$(basename $_XENBACKUP_LOGFILE)"
[ -f "$FILE_TMP" ] && rm -f "$FILE_TMP"

# Lista o conteudo do disco de backup e o põe no log
is_mount_disk "$_MEDIABACKUP"
if [ $? -gt 0 ] ; then 
  echo "========== Conteúdo de $_BACKUP_FOLDER ==============" | tee -a "$_XENBACKUP_LOGFILE"
  contents=$(folder_contents "$_BACKUP_FOLDER" ".xva")
  echo "$contents" | tee -a "$_XENBACKUP_LOGFILE"
  echo "Espaço no disco de backup:" | tee -a "$_XENBACKUP_LOGFILE"
  /bin/df -h $backup_dev_disk | tee -a "$_XENBACKUP_LOGFILE"
  echo "========== Fim da listagem do conteúdo de $_BACKUP_FOLDER ==============" | tee -a "$_XENBACKUP_LOGFILE"  
fi

# Eliminando snapshots antigos
$_SCRIPT_XENCLEANSNAP | tee -a "$_XENBACKUP_LOGFILE"

date_finish=$(date +%Y-%m-%d+%Hh%M)
rod_msg="========== fim do backup [ $HOSTNAME ] em $date_finish =============="
rod_msg="$rod_msg\n$backup_title"
rod_msg="$rod_msg\n$backup_title\nLog: $_XENBACKUP_LOGFILE"
echo "$rod_msg"

# Enviando mensagem por email
if [ $EXEC_SENDMAIL -gt 0 ] ; then
  #echo "Debug: $_SCRIPT_SENDMAIL \"$_MAILTO\" \"$backup_title\" \"$_XENBACKUP_LOGFILE\""
  $_SCRIPT_SENDMAIL "$_MAILTO" "$backup_title" "$_XENBACKUP_LOGFILE" 
  echo "Este log foi enviado por email para: $_MAILTO" | tee -a "$_XENBACKUP_LOGFILE"
fi

# Fim do programa

sair 1 "$_XENBACKUP_LOGFILE";
