#!/bin/bash
#
# Este script testa a funcionalidade de envio de email por este computador.
# Para que essa funcionalidade funcione perfeitamente, o ssmtp deve estar 
# instalado no computador. No cenário com a distro CentOS:
# 1. Habilitar os repositorios base, updates em /etc/yum.repos.d/CentOS-Base.repo  
# 2. Instalar o ssmtp (acrescentar as vezes o mailx) :
#    yum install ssmtp
# 3. Editar o arquivo /etc/ssmtp/ssmtp.conf  e comentar as linhas :
#    #mailhub=mail
#    #rewriteDomain=
#    # hostname=_HOSTNAME_
# em seu lugar, acrescentar as linhas :
#    mailhub=192.168.1.13
#    rewriteDomain=vidy.com.br
#    hostname=[nomedohost].vidy.local   # ou
#    hostname=_HOSTNAME_.vidy.local

# /usr/bin/xenfunctions.sh
# Este script deve ser copiado para /usr/bin, pois outros script aguardam 
# carregá-lo a partir desse local. Pode usar um link simbolico se precisar


function init_vars() { 
  [ -z $_XENPATH ] && _XENPATH=/root
  [ -z $_SCRIPT_XENCLEAN ] && _SCRIPT_XENCLEAN="$_XENPATH/xenbackup-clean.sh"
  [ -z $_SCRIPT_XENCLEANSNAP ] && _SCRIPT_XENCLEANSNAP="$_XENPATH/xenbackup-cleansnapshots.sh"
  [ -z $_SCRIPT_XENDISK ] && _SCRIPT_XENDISK="$_XENPATH/xendisk.sh"
  [ -z $_SCRIPT_SENDMAIL ] && _SCRIPT_SENDMAIL="$_XENPATH/enviar_email_admin.sh"
  [ -z $_SCRIPT_XENBACKUP ] && _SCRIPT_XENBACKUP="$_XENPATH/xenbackup.sh"
  [ -z $_SCRIPT_XENRESTORE ] && _SCRIPT_XENRESTORE="$_XENPATH/xenrestore.sh"
  [ -z $_SCRIPT_XENVMLIST ] && _SCRIPT_XENVMLIST="$_XENPATH/xenvmlist.sh"  
  [ -z $_SCRIPT_XENBACKUP2EMAIL ] && _SCRIPT_XENBACKUP2EMAIL="$_XENPATH/xenbackup2email.sh"
  [ -z $_SCRIPT_XENBACKUPESTIMATE ] && _SCRIPT_XENBACKUPESTIMATE="$_XENPATH/xenbackup-estimate.sh"
  [ -z $_MAILTO ] && _MAILTO="suporte@vidy.com.br"
  [ -z $_HOST_UUID ] && _HOST_UUID=$(xe host-list params=uuid hostname=$HOSTNAME|cut -d':' -f2|grep -v '^$'|tr -d '^ ')
  [ -z $_POOL_UUID ] && _POOL_UUID=$(xe pool-list params=uuid|cut -d':' -f2|grep -v '^$'|tr -d '^ ')
  [ -z $_MEDIABACKUP ] && _MEDIABACKUP=/media/backup
  #### [ -z $_DATE_START ] && _DATE_START=$(date +%Y-%m-%d+%Hh%M)
  [ -z $_WANT_SPACE ] && _WANT_SPACE=150
  # "1" para exibir todos os comandos executados
  [ -z $_DEBUG ] && _DEBUG="0"

  # No caso de backups seletivos, os nomes das VMs devem estar no arquivo-texto :
  # /etc/xenbackup-list.txt ou /$USER/xenbackup-list.txt
  [ -z $_BACKUP_LIST ] && _BACKUP_LIST="/$USER/xenbackup-list.txt" 
  [ -f "/etc/xenbackup-list.txt" ] && _BACKUP_LIST="/etc/xenbackup-list.txt" 
  [ -f "/$USER/xenbackup-list.txt" ] && _BACKUP_LIST="/$USER/xenbackup-list.txt" 
  # Arquivo de log
  #[ -z $_LOG_FILE ] && _LOG_FILE="/var/log/xen/xenbackup-$_DATE_START.log"
  
}

function wecho() { 
  local msg
	msg=$1
  echo -ne "$msg"
	echo -ne "$msg"|/usr/bin/wall  
}


# funcao sair EXIT_CODE ARQUIVO_LOG
# Objetivo: Padroniza as saidas de scripts
# Parametros EXIT_CODE  Se >0 entao estará indicando uma saida prematura talvez motivada por um erro
#            ARQUIVO_LOG Se indicado, enviará um email para notificar os administradores quer tenha dado erro ou nao
function sair() {
  # Desmontando a midia de backup
  if [ "$_MEDIABACKUP" != "" ] ; then
    mounted=$(mount|grep "$_MEDIABACKUP"|wc -l)  
    [ $mounted -gt 0 ] && umount_disk "$_MEDIABACKUP"
  fi
  #
  local EXIT_STATUS=$1
  [ -z $1 ] || [ "$1" == "" ] && EXIT_STATUS=0
  _LOG_FILE="$2"
  # Finalizando o backup
  local date_finish=$(date +%Y-%m-%d+%H_%M)
  local msg_subject=""
  local	msg_text="Encerrado com sinal [$EXIT_STATUS] em $date_finish"
	msg_text="$msg_text\nNome: ${0##*/}"
	msg_text="$msg_text\nCaminho: ${0%/*}"
  msg_text="$msg_text\nNome completo: ${0}"  
  msg_text="$msg_text\nArgumentos: ${@}"
  msg_text="$msg_text\nPoderá consultar o log de backup no arquivo:"
  msg_text="$msg_text\n$_LOG_FILE"
  wecho $msg_text
  # Finalizando com uma limpeza da midia
  # removendo cópias velhas
  if [ -f "$_LOG_FILE" ] ; then
    if [ -z $EXIT_STATUS ] || [ $EXIT_STATUS = "" ] ; then
      EXIT_STATUS=0 
    fi
    
    if [ $EXIT_STATUS -gt 0 ] ; then
      msg_subject="Conclusão com saída prematura em ${0}";
    else
      msg_subject="Concluído o script ${0}."
    fi
    if [ "$_SCRIPT_SENDMAIL" != "" ] && [ "$_MAILTO" != "" ] && [ -f "$_LOG_FILE" ] ; then
      # Ex: ./enviar_email_admin.sh "gladiston@vidy.com.br" "teste de envio de mensagem" "corpo da mensagem ou indicação de arquivo que servira de corpo da mensagem" /var/log/xen/xenbackup-2014-11-18+11_25.log
      # Parametros :
      # (1) Email do destinatario
      # (2) Assunto
      # (3) Mensagem ou Arquivo que contém a Mensagem
      # (4) Arquivo a ser anexado (opcional)
      #$_SCRIPT_SENDMAIL "$_MAILTO" "$msg_subject" "$msg_subject\nO arquivo em anexo exibirá sucesso ou falha na execução do script indicado.\n" "$_LOG_FILE" 
      $_SCRIPT_SENDMAIL "$_MAILTO" "$msg_subject" "$_LOG_FILE" 
    fi
    echo $msg_text;
  fi  
  unset _XENPATH
  unset _SCRIPT_XENCLEAN ;
  unset _SCRIPT_XENCLEANSNAP;
  unset _SCRIPT_XENDISK ;
  unset _SCRIPT_SENDMAIL ;
  unset _SCRIPT_XENBACKUP ;
  unset _SCRIPT_XENRESTORE;
  unset _SCRIPT_XENVMLIST ;
  unset _SCRIPT_XENBACKUP2EMAIL;
  unset _SCRIPT_XENBACKUPESTIMATE ;
  unset _MAILTO ;
  unset _HOST_UUID;
  unset _MEDIABACKUP;
  unset _DATE_START ;
  unset _WANT_SPACE ;
  unset _BACKUP_LIST ;
  exit $errorcode
}


# function log() {
  # local log_date="`date +%Y-%m-%d+%H:%M`"
  # local frase="$1"
  # if [ -z "$_LOG_FILE" ] || [ "$_LOG_FILE" == "" ] ; then
     # _LOG_FILE="/var/logs/xen"
     # if ! [ -d "$LOGS" ] ; then
       # mkdir -p "$LOGS"
     # fi
     # _LOG_FILE="/var/log/xen/xenbackup-$log_date.log"
  # fi

  # if [ -z "$1" ] || [ "$1" == "" ] ; then
    # echo "Parametro para log esta vazio"
    # return
  # fi
  
  # local temp_log="$2"
  # if [ -z "$temp_log" ] || [ "$temp_log" == "" ] ; then
    # temp_log="$_LOG_FILE"
  # fi
  
  # if ! [ -f "$temp_log" ] ; then
    # echo "Arquivo para registrar log [$temp_log]  não existe !"
    # echo -ne "Criando um arquivo vazio..."
    # touch "$temp_log"
    # echo "[OK]"
  # fi
  # local echo_opt="-e "  
  # if [[ $frase = *$"\n"* ]] ; then
    # echo_opt="-ne " 
  # fi
  # echo $echo_opt "$frase" 2>&1 | tee -a "$temp_log"
# }

function semremarks() {
  local PARAMLINHA="$1"
  PARAMLINHA=${PARAMLINHA%% }
  PARAMLINHA=${PARAMLINHA## }
  #if [ `echo $PARAMLINHA|grep ^#|wc -l` -gt 0 ] ; then 
  #  echo "" 
  #  return
  #fi
  RESULT_VALUE=$(echo $PARAMLINHA|cut -d "#" -f1)
  echo "$RESULT_VALUE"
}

# função: folder_contents
# objetivo: Exibe o conteudo de uma pasta de arquivos de uma maneira mais humana do que a saída do 'ls' ou 'find'
# Parametros: (1) /local/da/pasta
#             (2) mascara de nomes de arquivo, por exemplo '.txt' e listará apenas os que contiverem '.txt' no nome.
function folder_contents() {
  local FILE_TMP=$(mktemp "/tmp/folder_contents-XXXXXXXX")
  local WHEREIS=$1
  local PARTIAL_NAME=$2
  local NCOUNT_FILES=0
  local LINE
  if [ -z PARTIAL_NAME ] || [ "$PARTIAL_NAME" == "" ] ; then
    PARTIAL_NAME=" "
  fi
  if  ! [ -d "$WHEREIS" ] ; then
    echo "Pasta inexistente: $WHEREIS"
    return 2
  fi
  ls -RtlhgG "$WHEREIS" | awk 'BEGIN{OFS="\t"}{print $5" "$4,$6,$3,$7}'|sort > "$FILE_TMP" 
  echo -ne "Conteúdo da pasta [$WHEREIS] "
  if [ "$PARTIAL_NAME" != " " ] ; then
    echo -ne "[$PARTIAL_NAME]" 
  fi
  echo -ne ":\n"
  while read LINE ; do
    if [[ "$LINE" =~ "$PARTIAL_NAME" ]] ; then
      echo -e "  $LINE"
      NCOUNT_FILES=$((NCOUNT_FILES+1))
    fi
  done < "$FILE_TMP"
  if [ $NCOUNT_FILES -gt 0 ] ; then
    echo -ne "\n-\n$NCOUNT_FILES arquivos "
    if [ "$PARTIAL_NAME" != " " ] ; then
      echo -ne "[$PARTIAL_NAME]" 
    fi
  echo -ne ".\n"
  fi
}

#if is_integer $1; then
#    echo "$1 is an integer"
#else
#    echo "$1 is not an integer"
#fi
function is_integer() {
re='^[0-9]+$'  # Inteiro
re='^[0-9]+([.][0-9]+)?$'  # numero
re='^-?[0-9]+([.][0-9]+)?$' # numero negativo
if ! [[ $1 =~ $re ]] ; then
  return 1
else 
  return 0
fi

}


function is_mount_disk() {
  # Retorna >0 se uma pasta estiver montada, ex:
  #  is_mount_disk "$1"
  #  if [ $? -gt 0 ]; then 
  #    echo "disco $1 esta montado"
  #  else
  #    echo "disco $1 esta desmontado."
  #  fi
  local check_point="$1"
  if [ "$check_point" = "" ] ; then 
    return 0
  fi
  # Verifica novamente se persiste montada
  local lastchar=$(echo "${check_point: -1}")
  if [ "$lastchar" == "/" ] ; then
    check_point=$(echo "${check_point%?}")
  fi
  #echo "Testando a montagem de $check_point"
  local mounted=$(/bin/mount|grep "$check_point"|grep -v "grep "|wc -l)
  if [ $mounted -gt 0 ] ; then
    #echo "Testando a montagem de $check_point [ \$? -gt 0 ]" >&2
    is_mount_disk=1 
    return 1
  else
    #echo "Testando a montagem de $check_point [ \$? -le 0 ]" >&2
    is_mount_disk=0
    return 0
  fi
}

function mount_disk() {
  local mounted
  # Criando a pasta de montagem da unidade de backup
  if ! [ -d "$_MEDIABACKUP" ] ; then
    mkdir -p "$_MEDIABACKUP" 
  fi

  # Testa se _MEDIABACKUP nao esta montado, se estiver desmonta-o !
  is_mount_disk "$_MEDIABACKUP"
  if [ $? -gt 0 ]; then 
    echo "A pasta [$_MEDIABACKUP] encontra-se montada. tentando desmonta-la." >&2
    umount "$_MEDIABACKUP"
  fi

  # Verifica novamente se persiste montada
  is_mount_disk "$_MEDIABACKUP"
  mounted=$?
  if [ $mounted -gt 0 ]; then 
      echo "A pasta [$_MEDIABACKUP] encontra-se montada e não consigo desmontada. Chame o administrador para verificar este problema." >&2
      echo "Teste a instrução : umount $_MEDIABACKUP" >&2
      return $mounted;
  fi

  # Procura se algum dos discos alistados para backup estao presentes no sistema
  [ "$backup_dev_disk" = "" ] && backup_dev_disk=$($_SCRIPT_XENDISK)
  
  if [ "$backup_dev_disk" = "" ] ; then
    echo "Disco de Backup nao foi localizado no sistema." >&2
    return $mounted;
  else
    echo "Achei a midia de backup : $backup_dev_disk" >&2
  fi

  # Monta o destino do backup  
  /bin/mount -t auto "$backup_dev_disk" "$_MEDIABACKUP"
  is_mount_disk "$_MEDIABACKUP"
  mounted=$?
  if [ $? -gt 0 ]; then 
    echo "Midia montada com sucesso : $backup_dev_disk em $_MEDIABACKUP  [ \$? -gt 0 ]" >&2
  else
    echo "Unidade [$backup_dev_disk] em [$_MEDIABACKUP] não foi montada corretamente. [ \$? -le 0 ]" >&2
  fi
  mount_disk=$mounted
  return $mounted  
}

function umount_disk() {
  # Retorna 0 se conseguiu desmontar corretamente o disco, >0 entao falhou a desmontagem
  # Desmonta o destino do backup, tenta desmontar 5 vezes com intervalos de 5s
  # antes de desistir no caso da unidade estiver em uso
  # 
  local mounted=1
  local try=0
  /bin/umount "$_MEDIABACKUP"
  while [ $mounted -gt 0 ] && [ $try -lt 5 ]; do
    mounted=$(/bin/mount|grep $_MEDIABACKUP|grep -v "grep "|wc -l)
    try=$((try+1))
    # Se estiver montado...
    if [ $mounted -gt 0 ] ; then
      echo "\tTentativa de desmontagem $try de 5...\n" >&2
      umount $backup_dev_disk
      sleep 5s
    fi
  done
  mounted=$(/bin/mount|grep $_MEDIABACKUP|wc -l)
  if [ $mounted -gt 0 ] ; then
    echo "Unidade não foi desmontada corretamente, faça a desmontagem manualmente com o comando :" >&2
    echo "umount $_MEDIABACKUP" >&2
    umount_disk=0
    return 0
  else
    umount_disk=1 
    return 1
  fi
}

function editar() {
  local arquivo="$1"
  if ! [ -f "$arquivo" ] ; then
    echo "Nao achei o arquivo :"
    echo "$arquivo"
    press_enter_to_continue;
    return 2
  fi
  
  MD5SUM_ANTES=`md5sum "$arquivo"`
  nano "$arquivo"
  MD5SUM_DEPOIS=`md5sum "$arquivo"`
  if [ "$MD5SUM_ANTES" != "$MD5SUM_DEPOIS" ] ; then
    return 0
  else 
    return 1
  fi
}

function do_confirmar() {
  # Uso :
  #      do_confirmar "Confirma ? (sim ou nao)"
  #      if [[ $? -eq 0 ]]; then echo OK; else echo FALHOU; fi
  #   OR
  #      if do_confirmar; then echo OK; else echo FALHOU; fi
  local MSG="$1"
  local CONFIRMA
  [ "$MSG" = "" ] && MSG="Confirma ? (sim ou nao)"
  echo "$MSG" 
  read CONFIRMA
  DO_CONFIRMAR_VALUE="nao"
  if [ "$CONFIRMA" = "SIM" ] || [ "$CONFIRMA" = "sim" ] || [ "$CONFIRMA" = "S" ] || [ "$CONFIRMA" = "s" ] ; then
    return 0
  else 
    return 1
  fi
}

function press_enter_to_continue() {
  local ESPERAR_TEMPO="$1"
  if [ -z "$ESPERAR_TEMPO" ] || [ "$ESPERAR_TEMPO" = "" ] ; then
   read -p "Pressione [ENTER] para prosseguir..." -n1 -s
  else
    echo "Aguarde $ESPERAR_TEMPO antes de prosseguir..."
    sleep $ESPERAR_TEMPO
  fi
}

function do_montar_confere() {
  local check="$1"
  if [ "$check" = "" ] ; then
     echo "Nao foi especificado o parametro para a função do_montar_confere." >&2
     return
  fi 

  do_montar_confere=`mount |grep "$check"|wc -l`
}

function do_pasta_vazia() {
  # Uso :
  #      do_pasta_vazia "/tmp/dir"
  #      if [[ $? -eq 0 ]]; then echo OK; else echo FALHOU; fi
  #   OR
  #      if do_pasta_vazia "/tmp/dir" ; then echo Vazia; else echo Possui arquivos; fi
  if [ "$(ls -A $1)" ] ; then
     do_pasta_vazia=0
     return 0
  else
    do_pasta_vazia=1
    return 1
  fi
}

function do_montar_dev() {
  local alvo_device="$1"
  local alvo_pasta="$2"
  local alvo_tipo="auto"
  RESULT_VALUE="FALHOU"
  if [ "$alvo_device" = "" ] ; then 
     echo "Erro na montagem de dispositivo : O nome do dispositivo não foi informado." >&2
     return 0
  fi  
  if [ "$alvo_pasta" = "" ] ; then
     echo "Erro na montagem de dispositivo : O nome do pasta onde seria montado o dispositivo não foi informado." >&2
     return 0
  fi 
  if ! [ -d  "$alvo_pasta" ] ; then
    mkdir -p "$alvo_pasta"
  fi
  # desmonta, caso a mesma se encontra montada
  do_montar_confere "$alvo_pasta"
  if [ $do_montar_confere -gt 0 ] ; then
    do_desmontar $alvo_pasta
  fi

  # Verifica se a pasta esta fazia antes de prosseguir
  do_pasta_vazia "$alvo_pasta"
  if [ "$do_pasta_vazia" -eq 0 ] ; then 
     echo "A pasta [$alvo_pasta] nao esta vazia." >&2
     return 0
  fi

  # 
  # montando a unidade de destino, normalmente o usbdisk
  mount -t $alvo_tipo $alvo_device $alvo_pasta -o sync,nosuid,nouser,rw,dirsync,users
  if [ $? -ne 0 ] ; then
    echo "A montagem da unidade de destino-backup falhou !" >&2
    echo "Tentativa : mount -t $alvo_tipo $ponto_device $ponto_destino -o sync,nosuid,nouser,rw,dirsync,users" >&2
    echo "Certifique-se que :" >&2
    echo "- tenha ligado a unidade numa porta USB deste servidor;" >&2
    echo "- o dispositivo USB esteja ligado com o led de funcionamento piscando." >&2
    echo "Desligue o aparelho, aguarde alguns instantes e ligue-o novamente" >&2
    echo "e repita a operacao, se insistir o problema contate" >&2
    echo "imediatamente o supervidor."  >&2
  fi
  RESULT_VALUE="OK"  
} 

function do_desmontar() {
  local alvo="$1"
  RESULT_VALUE="FAIL"
  if [ "$alvo" = "" ] || \
     ! [ -d "$alvo" ] ; then
     echo "alvo para desmontar nao existe : [$alvo]"
     return
  fi
  # so posso desmontar unidades em /mnt ou /media
  dir_to_unmount=$(mount |grep "$alvo"|cut -d" " -f 3|cut -d"/" -f 2)
  #if [ "$dir_to_unmount" != "media" ] && [ "$dir_to_unmount" != "mnt" ] ; then
  #  return
  #fi

  local n=0
  local EXISTE=1
  while [ $EXISTE -gt 0 ] ; do
    EXISTE=`mount |grep $alvo|wc -l`
    if [ "$EXISTE" -gt 0 ] ; then
      umount $alvo
      [ -d "$alvo" ] && rmdir $alvo
    fi
    # depois de 32 tentativas, desiste
    n=$(( $n +1 ))
    if [ $n -gt 32 ] ; then
      return
    fi
  done
  # se o diretorio montado estiver vazio e estiver localizado em /mnt entao remove-lo
  if ! [[ "$alvo" =~ "/media" ]] ; then
    if [ -d "$alvo" ] && [ "$dir_to_unmount" = "mnt" ] ; then
      if [ "$alvo/*" = "$alvo/*" ] ; then
        echo "Removendo diretorio vazio [$alvo]"
        rmdir $alvo
      fi
    fi
  fi
  RESULT_VALUE="OK"
  sleep 5s
}

# Fill e Pad fazem um echo com tamanho delimitado, ex:
# pad 37 "[Description]" "- "
# echo "[win]"
# pad 37 "[decription damn long]" "- "
# echo "[lose]"
# resultará em :
# [Description] - - - - - - - - - - - -[win]
# [decription damn long]- - - - - - - -[lose]
function fill()
{
    # fill string to width of count from string chars 
    #
    # usage:
    #      fill count [chars]
    #
    # if count is zero a blank string is output
    # chars is optional, spaces used if missing
    #
    local FILL="${2:- }"
    for ((c=0; c<=$1; c+=${#FILL}))
    do
        echo -n "${FILL:0:$1-$c}"
    done
}
function pad()
{
    # Pad to right of string to required width, using chars.
    # Chars is repeated, as required, until width is reached.
    #
    # usage:
    #      pad width string [chars]
    #
    # if chars not specified spaces are used
    #
    BACK=$(fill $1 "$3")
    let PAD=$1-${#2}
    if [ $PAD -lt 1 ] 
    then
        echo -n ${2:0:$1-1}
    else
        echo -n "$2${BACK:${#2}}"
    fi
}

# Funcao space_free /dev/sdNN [gb]
# Observar espaço livre numk dispositivo montado, se não estiver montando não funcionará.
# Retorna as variaveis:
#  DevFilesystem  device onde o espaço livre foi pesquisado
#  DevBlocks1k->Quantdade de blocos de 1k
#  DevUsed->espaço ocupado
#  DevAvailable=0->espaço disponivel
#  DevUsePerc=0-> percentual em uso
#  DevMountedOn ->onde esse dispositivo está montado(se estiver)
function space_free() {
  local try_dev=$1
  local unit="MB" 
  DevFilesystem="-"
  DevBlocks1k=0
  DevUsed=0
  DevAvailable=0
  DevUsePerc=0
  DevMountedOn="-"
  if [ -z $1 ] ; then
    return
  fi
  [ "$2" == "gb" ] && unit="GB"
  [ "$2" == "GB" ] && unit="GB"
  is_mount_disk "$try_dev"
  if [ $? -le 0 ]; then   
    return
  fi 

  # Filesystem           1K-blocks      Used Available Use% Mounted on
  # /dev/sdb1            1922858352 1909153628         0 100% /media/backup
  local lastline=$(/bin/df "$try_dev"|tail -n1)
  DevFilesystem=$(eval echo "$lastline"|cut -d ' ' -f 1)
  DevBlocks1k=$(eval echo "$lastline"|cut -d ' ' -f 2|tr  -d '[:alpha:]')
  DevUsed=$(eval echo "$lastline"|cut -d ' ' -f 3|tr  -d '[:alpha:]')
  DevUsed=$(echo "((($DevUsed/1024)))" | bc -l)                                       # DevUsed em MB
  [[ "$DevUsed" =~ "." ]] && DevUsed=$(eval echo "$DevUsed"|cut -d'.' -f1)            # Trunca a parte inteira se estiver fracionado
  # DevUse em GB se for essa a necessidade
  if [ "$unit" == "GB" ] ; then
    DevUsed=$(echo "((($DevUsed/1024)))" | bc -l)                
    [[ "$DevUsed" =~ "." ]] && DevUsed=$(eval echo "$DevUsed"|cut -d'.' -f1)          # Trunca a parte inteira se estiver fracionado
  fi
  if ! [[ $DevUsed =~ '^[0-9]+$' ]] ; then
     DevUsed=0
     echo "Variavel [DevUsed] não é um numero." >&2
  fi  
  
  DevAvailable=$(eval echo "$lastline"|cut -d ' ' -f 4|tr  -d '[:alpha:]')
  DevAvailable=$(echo "((($DevAvailable/1024)))" | bc -l)                             # DevAvailable em MB
  [[ "$DevAvailable" =~ "." ]] && DevAvailable=$(eval echo "$DevAvailable"|cut -d'.' -f1)     # Trunca a parte inteira se estiver fracionado
  # DevAvailable em GB se for essa a necessidade
  if [ "$unit" == "GB" ] ; then
    DevAvailable=$(echo "((($DevAvailable/1024)))" | bc -l)      
    [[ "$DevAvailable" =~ "." ]] && DevAvailable=$(eval echo "$DevAvailable"|cut -d'.' -f1)   # Trunca a parte inteira se estiver fracionado
  fi
  if ! [[ $DevAvailable =~ '^[0-9]+$' ]] ; then
     DevAvailable=0
     echo "Variavel [DevAvailable] não é um numero." >&2
  fi  
  DevUsePerc=$(eval echo "$lastline"|cut -d ' ' -f 5|tr  -d '[:alpha:]'|tr -d '%')
  DevMountedOn=$(eval echo "$lastline"|cut -d ' ' -f 6)
}

# Estima o espaço total que uma lista de VMs podem ocupar em GBs
# O primeiro parametro deve ser um arquivo contendo uma lista de VMs
# O segundo parametro (-v) é opcional e quando usado exibe o espaço de cada VM
#texto=$(space_estimate "/root/xenbackup-list.txt" "-v")
#echo "texto: $texto"
# Ou se quiser apenas a estimativa:
# ESTIMATIVE=$(space_estimate "/root/xenbackup-list.txt")
function space_estimate() {
local FILE_VM_LIST="$1"
local VERBOSE=0
local VM_NAME=""
local VM_SIZE=0
local VM_EXISTE=0
local DEFAULT_RETURN=0
local NCOUNT=0
ESTIMATIVE=0
[ "$2" == "-v" ] && VERBOSE=1

if ! [ -f "$FILE_VM_LIST" ] ; then
   echo "Arquivo inexistente: $FILE_VM_LIST" 1>&2;
   echo $DEFAULT_RETURN
   return
fi

NCOUNT=$(cat "$FILE_VM_LIST"|grep -v "^#"|wc -l)
if [ $NCOUNT -eq 0 ] ; then
   echo "Arquivo indicado está vazio: $FILE_VM_LIST" 1>&2;
   echo $DEFAULT_RETURN
   return
fi

while read LINHA ; do
  VM_NAME=$(semremarks "$LINHA")
  if [ "$VM_NAME" != "" ] ; then
    # Testa a existencia da VM_NAME e se a mesma possui um disco 
    VM_EXISTE=$(xe vm-disk-list vbd-params=virtual-size vm=$VM_NAME --multiple|wc -l)
    if [ $VM_EXISTE -gt 0 ] ; then 
      #echo "xe vm-disk-list vbd-params=virtual-size vm=$VM_NAME --multiple|grep virtual-size|cut -d':' -f2"
      VM_SIZE=$(xe vm-disk-list vbd-params=virtual-size vm=$VM_NAME --multiple|grep virtual-size|cut -d':' -f2)
      VM_SIZE=$(echo "((($VM_SIZE/1024)/1024)/1024)" | bc -l)
      VM_SIZE=$(echo "$VM_SIZE"|cut -d'.' -f1)
      # Se o campo numero for invalido então...
      if ! [[ $VM_SIZE =~ '^[0-9]+$' ]] ; then
         VM_SIZE=0
         echo "Variavel [VM_SIZE] não é um numero." >&2
      fi  
      ESTIMATIVE=$(echo "$ESTIMATIVE + $VM_SIZE" | bc -l)
      #echo "debug mark #1 ESTIMATIVE=$ESTIMATIVE" 1>&2;
      if [ $VERBOSE -gt 0 ] ; then
        pad 50 "$VM_NAME" "." 
        echo ": $VM_SIZE GB"
      fi  
      SIZE_BYTES=$((SIZE_BYTES+VM_SIZE))
    fi
  fi
done <"$FILE_VM_LIST"
if [ $VERBOSE -gt 0 ] ; then
  #echo "debug mark #1 ESTIMATIVE=$ESTIMATIVE" 1>&2;
  pad 50 "Total estimado" "."  
  echo ": $ESTIMATIVE GB"
else
  echo "$ESTIMATIVE"
fi
}

# Nome: TransfVM2Disk_Online
# Objetivo: Transfere uma VM que estiver online (rodando) para o disco.
#   Util para o proposito de backup
# Parametros: (1) Nome da VM, ex: WinXP_Financeiro
#             (2) Destino, ex: /media/backup/
#                 A propria funcao cria um nome de arquivo no local de destino 
#                 com o seguinte nome [NomeDaVM]-YYYY-MM-DD+HHhMM.xva
function TransfVM2Disk_Online() {
  # Cria uma variavel data com o formato da data que quero pra compor
  # o nome do arquivo de backup
  # Agora componho o nome do arquivo de backup
  local VM_NAME="$1"
  local DEST_FOLDER="$2"
  local VM_BACKUP_START=$(date +%Y-%m-%d+%Hh%M)   
  local VM_BACKUP_FINISH=$(date +%Y-%m-%d+%Hh%M)  
  local snapName="snapshot-$HOSTNAME-$VM_NAME-$VM_BACKUP_START"
  local bkpName="$VM_NAME-$VM_BACKUP_START.xva"
 
  local snapcreate=0
  local erro=0
  local vm_existe=0
  local UUID=""

  # VM existe?
  [ "$VM_NAME" != "" ] && vm_existe=$(xe vm-list|grep "$VM_NAME"|wc -l)
  if [ "$vm_existe" -le 0 ] ; then
    echo "VM [%VM_NAME] não existe."  
    return 2
  fi
  if ! [ -d "$DEST_FOLDER" ] ; then
    echo "Pasta [%DEST_FOLDER] não existe."  
    return 2
  fi
  
  # Aqui crio um snapshot. Ele é necessario para não precisar
  # parar a VM. O backup é realizado online a partir dum
  # snapshot que será criado agora.
  # O UUID do snapshot criado será reutilizado para outras operações
  # Para snapshot do tipo quiesced use :
  # xe vm-snapshot vm-snapshot-with-quiesce vm="$VM_NAME" new-name-label="$snapName"
  echo "Backup online da VM [$VM_NAME] iniciado em $VM_BACKUP_START"  
  echo -e "\t$VM_NAME - Criando snapshot (sem quiesce) temporario (1/5)"
  [ "$_DEBUG" = "1" ] && echo -e "\t\txe vm-snapshot vm=\"$VM_NAME\" new-name-label=\"$snapName\" "
  UUID=`xe vm-snapshot vm="$VM_NAME" new-name-label="$snapName"`

  # Se houver falhas na criação do snapshot então o UUID será 1 e as 
  # etapas seguintes serão puladas, forçando o backup da VM seguinte
  if [ "$UUID" == "1" ] || [ "$UUID" == "" ]; then
    erro=-1
    echo -e "\t\t[ERRO] Falha ao criar o snapshot"
  else
    snapcreate=1 
    echo -e "\t\t[OK] Sucesso ao criar snapshot"
  fi

  if [ "$erro" -eq 0 ] ; then
    # Pra essa tarefa, uso o ID obtido no passo anterior.
    echo -e "\tRemovendo 'Template flag' do snapshot temporario (2/5)"
    [ $DEBUG -gt 0 ] && echo -e "\t\txe template-param-set is-a-template=false uuid=\"$UUID\" "
    if [ $DEBUG -le 0 ] ; then 
      xe template-param-set is-a-template=false uuid="$UUID"
      if [ $? -eq 0 ] ; then
         echo -e "\t\t[OK]"
      else
         echo -e "\t\t[ERRO]"
         erro=-2
      fi
    fi
  fi

  if [ "$erro" -eq 0 ] ; then
    echo -e "\tPreenchendo uma descricao ao snapshot temporario (3/5)"
    [ $DEBUG -gt 0 ] && echo -e "\t\txe template-param-set name-description=\"Backup da VM [$VM_NAME] iniciado em $_DATE_START\" uuid=\"$UUID\" "
    if [ $DEBUG -le 0 ] ; then 
      xe template-param-set name-description="Backup da VM [$VM_NAME] iniciado em $_DATE_START" uuid="$UUID" 
      if [ $? -eq 0 ] ; then
         echo -e "\t\t[OK]"
      else
         echo -e "\t\t[ERRO]"
         erro=-3
      fi
    fi
  fi
  # Exportando o snapshot para o disco, esta será a cópia de segurança
  if [ "$erro" -le 0 ] ; then
    echo -e "\tExportando VM para o disco (4/5)"
    [ $DEBUG -gt 0 ] && echo -e "\t\tvm-export vm=\"$snapName\"  filename=\"$DEST_FOLDER/$bkpName\" "
    if [ $DEBUG -le 0 ] ; then 
      xe vm-export vm="$snapName" filename="$DEST_FOLDER/$bkpName" 
      os_error=$?
      if [ $os_error -eq 0 ] ; then
         echo -e "\t\t[OK] Backup exportado com sucesso :$DEST_FOLDER/$bkpName"
      else
         echo -e "\t\t[ERRO] Falha ao exportar para o disco(os error $os_error)."
         # Se deu erro na transferencia para a mídia então, se o arquivo estiver 
         # na midia, provavelmente estará corrompido e portanto deverá ser removido
         # para não termos a sensação posterior que o backup foi bem sucedido.
         [ -f "$DEST_FOLDER/$bkpName" ] && rm -f "$DEST_FOLDER/$bkpName"
         erro=-4
      fi
    fi
  fi

  # Destruo o snapshot que está no servidor, pois a cópia de segurança já foi feita.
  if [ "$snapcreate" -gt 0 ] ; then
    echo -e "\tRemovendo snapshot temporario (5/5)"
    [ $DEBUG -gt 0 ] && echo -e "\t\txe vm-uninstall vm=\"$snapName\" force=true"
    if [ $DEBUG -le 0 ] ; then
      xe vm-uninstall vm="$snapName" force=true 
      if [ $? -eq 0 ] ; then
         echo -e "\t\t[OK] Snapshot removido com sucesso."
      else
         echo -e "\t\t[ERRO] Snapshot não pôde ser removido (xe vm-uninstall vm=\"$snapName\" force=true)"
         erro=-5
      fi
    fi
  fi
  # Observo se não há outras snapshots vivas no sistema que precisem ser destruidas
  #existe=$(xe vm-list resident-on="<not in database>" is-control-domain=false  power-state=halted is-a-snapshot=true params=name-label|grep "$snapName"|wc -l)
  #if [ $existe -gt 0 ] ; then
  #  existe=$(xe vm-list resident-on="<not in database>" is-control-domain=false  power-state=halted is-a-snapshot=true params=name-label|grep "$snapName"|wc -l)
  #  VM_NAME=$(xe vm-list uuid=$VM_UUID params=name-label|cut -d':' -f2|grep -v '^$'|tr -d '^ ')
  #  echo "\tEliminando o snapshot $VM_UUID [$VM_NAME]" 
  #  xe vm-uninstall uuid=$VM_UUID force=true | tee -a "$_XENBACKUP_LOGFILE"
  #fi
  
  VM_BACKUP_FINISH=$(date +%Y-%m-%d+%Hh%M)
  if [ $erro -eq 0 ] ; then
    if [ -f "$DEST_FOLDER/$bkpName" ] ; then 
      echo "Backup da VM [$VM_NAME] completado com sucesso em $VM_BACKUP_FINISH"            
    else 
      erro=-2
    fi      
  fi  
  
  if ! [ "$erro" -eq 0 ] ; then
    echo "Backup da VM [$VM_NAME] falhou, operação cancelada em $VM_BACKUP_FINISH na etapa $erro" 
  fi
  
  # Retorna
  return $erro

}

# Nome: TransfVM2Disk_Offline
# Objetivo: Transfere uma VM que estiver online (rodando) para o disco.
#   Util para o proposito de backup
# Parametros: (1) Nome da VM, ex: WinXP_Financeiro
#             (2) Destino, ex: /media/backup/
#                 A propria funcao cria um nome de arquivo no local de destino 
#                 com o seguinte nome [NomeDaVM]-YYYY-MM-DD+HHhMM.xva
function TransfVM2Disk_Offline() {
  # Cria uma variavel data com o formato da data que quero pra compor
  # o nome do arquivo de backup
  # Agora componho o nome do arquivo de backup
  local VM_NAME="$1"
  local DEST_FOLDER="$2"
  local VM_BACKUP_START=$(date +%Y-%m-%d+%Hh%M)   
  local VM_BACKUP_FINISH=$(date +%Y-%m-%d+%Hh%M)  
  local bkpName="$VM_NAME-$VM_BACKUP_START.xva"
 
  local snapcreate=0
  local erro=0
  local vm_existe=0
  local UUID=""

  # VM existe?
  [ "$VM_NAME" != "" ] && vm_existe=$(xe vm-list|grep "$VM_NAME"|wc -l)
  if [ "$vm_existe" -le 0 ] ; then
    echo "VM [%VM_NAME] não existe."  
    return 2
  fi
  if ! [ -d "$DEST_FOLDER" ] ; then
    echo "Pasta [%DEST_FOLDER] não existe."  
    return 2
  fi
  # VM Está offline?
  vm_existe=$(xe vm-list name-label="$VM_NAME" params=power-state|grep "halted"|wc -l)
  if ! [ $vm_existe -gt 0 ] ; then
    echo "VM [%VM_NAME] não está offline."  
    return 2
  fi  
  
  echo "Backup offline da VM [$VM_NAME] iniciado em $VM_BACKUP_START" 
  xe vm-export vm="$VM_NAME" filename="$DEST_FOLDER/$bkpName" 
  erro=$?

  VM_BACKUP_FINISH=$(date +%Y-%m-%d+%Hh%M)
  
  if [ $erro -eq 0 ] ; then
    if [ -f "$DEST_FOLDER/$bkpName" ] ; then 
      echo "\t\t[OK] Backup da VM [$VM_NAME] completado com sucesso em $VM_BACKUP_FINISH"            
    else 
      erro=-2
    fi      
  fi
  if ! [ "$erro" -eq 0 ] ; then
    echo "\t\t[ERRO] Backup da VM [$VM_NAME] falhou, operação cancelada em $VM_BACKUP_FINISH na etapa $erro" 
  fi

  # Retorna
  return $erro

}
