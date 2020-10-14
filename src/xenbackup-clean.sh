#!/bin/bash
#
# Script para a limpeza de Maquinas Virtuais contidos nas midias de backups.
# Parametros:
# /nome/da/lista/de/backup.txt -> especifica a lista de backups que será usada para
#       estimar o espaço a ser limpo no disco atual de backup
# -dev:/dev/sdNN ->especifica o device de backup, quando nao mencionado ele fará a 
#    detecção automatica
# -local -> estima o tamanho a ser liberado no disco de backup baseado no tamanho
#   das VMs locais armazenadas no host.
# -all ->estima o tamanho a ser liberado no disco de backup baseado no tamanho das
#   VMs existentes no pool.
# -no-sendmail -> Nao enviará um email sobre essa liberação de espaço no disco de backup
# -no-snapshots ->Nao limpará os snapshots estacionarios, isto é, que apenas residem no
#   servidor ocupando espaço, mas nao esta em uso por ninguém.
# -min:NNNN Espaço minimo (em GB) para ser considerado, se houver menos espaço disponivel 
# menor do que esse então libera o tamanho minimo 
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
[ -z $_DATE_START ] && _DATE_START=$(date +%Y-%m-%d+%Hh%M)
_MIN_SIZE=0
clean_snapshots=1
temp_file="/tmp/lista-xenbackup-estimate-clean-$$.txt"

# Diretorio onde é feito o backup
backup_dev_disk=$($_SCRIPT_XENDISK)
#_HOST_UUID=$(xe host-list params=uuid hostname=$HOSTNAME|cut -d':' -f2|grep -v '^$'|tr -d '^ ')

PARAM_LISTA_VMS=""
for CURRENT_PARAM in "$@" ; do
  #CURRENT_PARAM=$(echo "$CURRENT_PARAM" | xargs)
  CURRENT_PARAM="${CURRENT_PARAM##*( )}"                                          # Trim
  if [ -f "$CURRENT_PARAM" ] ; then 
    if ! [[ "$CURRENT_PARAM" =~ "^-" ]] && [ "$PARAM_LISTA_VMS" == "" ] ; then
      PARAM_LISTA_VMS="$CURRENT_PARAM"
    fi
  fi
  if [[ "$CURRENT_PARAM" =~ "^-local" ]] ; then
    PARAM_LISTA_VMS="/tmp/xenbackup-lista-local-$$.txt"
    $_SCRIPT_XENBACKUPESTIMATE -local |grep -v "Total estimado" 2>&1 | tee "$PARAM_LISTA_VMS"
  fi
  if [[ "$CURRENT_PARAM" =~ "^-all" ]] ; then 
    PARAM_LISTA_VMS="/tmp/xenbackup-lista-todos-$$.txt"
    $_SCRIPT_XENBACKUPESTIMATE -all |grep -v "Total estimado" -f1 2>&1 | tee "$PARAM_LISTA_VMS"
  fi
  if [ -f "$CURRENT_PARAM" ] && [[ "$CURRENT_PARAM" =~ "^-dev" ]] ; then 
    backup_dev_disk=$(echo "$CURRENT_PARAM"|cut -d':' -f2)
  fi
  if [[ "$CURRENT_PARAM" =~ "^-no-snapshots" ]] ; then 
    clean_snapshots=0
  fi
  if [[ "$CURRENT_PARAM" =~ "^-min:" ]] ; then 
    _MIN_SIZE=$(eval echo "$CURRENT_PARAM"|cut -d':' -f2)
    # Se nao retornar nenhum numero então...
    if ! [[ $_MIN_SIZE =~ '^[0-9]+$' ]] ; then
       echo "Não foi possivel entender o parametro: $CURRENT_PARAM" >&2
       echo "Variavel _MIN_SIZE não é um numero." >&2
       exit 2
    fi    
  fi  
done
if [ "$PARAM_LISTA_VMS" == "" ] ; then
  PARAM_LISTA_VMS="/tmp/xenbackup-lista-local-$$.txt"
  echo "Debug: $_SCRIPT_XENBACKUPESTIMATE -local |grep -v \"Total estimado\" 2>&1 | tee \"$PARAM_LISTA_VMS\"   " 1>&2;
  $_SCRIPT_XENBACKUPESTIMATE -local |grep -v "Total estimado" 2>&1 | tee "$PARAM_LISTA_VMS"
fi



echo "Limpeza de backups velhos de VMs iniciado em  $_DATE_START" 

# Montando a midia de backup
already_mount=0
is_mount_disk "$_MEDIABACKUP"
[ $? -gt 0 ] && already_mount=1
if [ $already_mount -eq 0 ] ; then
  echo "Montando $_MEDIABACKUP..."
  mount_disk
fi

# Pastas a serem removidas do backup
# houverem. O Script só aceitará os UUIDs aqui mencionados
lixo=( "${lixo[@]}" "$_MEDIABACKUP/lixo" )

[ -f "$temp_file" ] && rm -f "$temp_file"
echo "Debug: space_estimate \"$PARAM_LISTA_VMS\""  1>&2;
_WANT_SPACE=$(space_estimate "$PARAM_LISTA_VMS")

# Se nao retornar nenhum numero então...
if ! [[ $_WANT_SPACE =~ '^[0-9]+$' ]] ; then
   if [ $_MIN_SIZE -gt 0 ] ; then
     _WANT_SPACE=$_MIN_SIZE
   else
     echo "Não foi possivel estimar o tamanho necessário para o backup: $_WANT_SPACE" 1>&2;
     echo "Variavel _WANT_SPACE não é um numero." 1>&2;
     exit 2
   fi
fi


if [ $_WANT_SPACE -lt $_MIN_SIZE ] ; then
  _WANT_SPACE=$_MIN_SIZE
fi

#_WANT_SPACE=$($_SCRIPT_XENBACKUPESTIMATE "$ESTIM_PARAM" "GB"|grep "Total estimado"|cut -d':' -f2|cut -d'G' -f1|tr -d ' ')
echo "Tamanho estimado para backup $ESTIM_PARAM: $_WANT_SPACE GB" 

if [ -z $_WANT_SPACE ] || [ "$_WANT_SPACE" == "" ] ; then
  echo "Espaço arbitrado nao pode ser calculado, por essa razao a limpeza será abortada." 
  exit 2;
fi

# Listando todos os backups em ordem de data
find "$_MEDIABACKUP"  -type f -regex ".*/.*\.\(xva\)"|sort > "$temp_file"

# Iniciando a fase de excluir os backups antigos até que sobre $_WANT_SPACE Gigabytes

COUNT=0
EXISTE_ESPACO=0
echo "Debug: space_free \"$_MEDIABACKUP\" \"GB\""
space_free "$_MEDIABACKUP" "GB"
DevFilesystem1=$DevFilesystem
DevBlocks1k1=$DevBlocks1k
DevUsed1=$DevUsed
DevAvailable1=$DevAvailable
DevUsePerc1=$DevUsePerc
DevMountedOn1=$DevMountedOn
if [ "$DevFilesystem1" == "-" ] || [ "$DevFilesystem1" == "" ] ; then
  echo "Processo interrompido porque nao pude observar espaço livre em $backup_dev_disk..."  
  exit 2;  
fi
echo -e "Espaço no disco de backup antes da limpeza em $DevFilesystem1:"
echo -e "\tEspaço usado: $DevUsed1 GB ($DevUsePerc1%)"
echo -e "\tEspaço disp.: $DevAvailable1 GB"
echo -e "\tEspaço  req.: $_WANT_SPACE GB"
espaco_disponivel=$DevAvailable1
# Se nao retornar nenhum numero para a variavel então...
if ! [[ $espaco_disponivel =~ '^[0-9]+$' ]] ; then
   echo "Não foi possivel calcular o espaço disponivel no disco para realização do backup: $espaco_disponivel GB" >&2
   echo "Variavel [espaco_disponivel] não é um numero." >&2
   exit 2
fi

echo "Espaço arbitrado como sendo necessário para realizar backup: $_WANT_SPACE GB." 
if [ $espaco_disponivel -gt $_WANT_SPACE ]; then
  EXISTE_ESPACO=1
  echo "Espaço no disco de backup suficiente para o próximo backup, ignorando limpeza." 
fi

while read current_file ; do
  current_dir=$(dirname "$current_file")
  current_log="$current_dir/xenbackup.log"
  if [ $EXISTE_ESPACO -eq 0 ] && [ -f "$current_file" ]  ; then
    COUNT=$((COUNT+1))
    echo "Backup eliminado: $current_file" 
    echo "[$_DATE_START] Backup eliminado: $current_file" 2>&1 | tee -a "$current_log"
    rm -f "$current_file"
    space_free "$_MEDIABACKUP" "GB"
    DevFilesystem2=$DevFilesystem
    DevBlocks1k2=$DevBlocks1k
    DevUsed2=$DevUsed
    DevAvailable2=$DevAvailable
    DevUsePerc2=$DevUsePerc
    DevMountedOn2=$DevMountedOn
    espaco_disponivel=$DevAvailable
	#echo -e "Calculando novo espaço no disco $DevFilesystem2:"
	#echo -e "\tEspaço usado: $DevUsed2 GB ($DevUsePerc2%)"
	#echo -e "\tEspaço disp.: $DevAvailable2 GB"
	#echo -e "\tEspaço  req.: $_WANT_SPACE GB"
    # Se nao retornar nenhum numero para a variavel então...
    if ! [[ $espaco_disponivel =~ '^[0-9]+$' ]] ; then
       echo "Não foi possivel calcular o espaço disponivel no disco para realização do backup: $espaco_disponivel" >&2
       echo "Variavel [espaco_disponivel] não é um numero." >&2
       exit 2
    fi
    if [ $espaco_disponivel -gt $_WANT_SPACE ]; then
      EXISTE_ESPACO=1
    fi
  fi
done <$temp_file

# remove pastas e logs com mais de 30 dias de pastas desde que a pasta não possua nenhum backup contido
find "$_MEDIABACKUP"  -type f -mtime +30|sort  > "$temp_file"
while read current_file ; do
  current_dir=$(dirname "$current_file")
  current_log="$current_dir/xenbackup.log"
  # Observando se a pasta esta sem arquivos de backup (.xva)
  # e se estiver então apagará .sh e .txt
  existe=$(find "$current_dir"  -type f -regex ".*/.*\.\(xva\)"|wc -l)  
  if [ $existe -eq 0 ] ; then
    # Se a pasta esta sem backup (.xva) entao apago todos .log, .sh e .txt nela
    rm -f "$current_dir/*.txt"
    rm -f "$current_dir/*.sh"
    rm -f "$current_dir/*.log"
  fi  
done <$temp_file

[ -f "$temp_file" ] && rm -f "$temp_file"

space_free "$_MEDIABACKUP" "GB"
DevFilesystem2=$DevFilesystem
DevBlocks1k2=$DevBlocks1k
DevUsed2=$DevUsed
DevAvailable2=$DevAvailable
DevUsePerc2=$DevUsePerc
DevMountedOn2=$DevMountedOn
if [ $COUNT -gt 0 ] ; then
  echo -e "Espaço no disco de backup depois da limpeza em $DevFilesystem2:"
else
  echo -e "Não foi necessario realizar a limpeza em $DevFilesystem2:"
fi
echo -e "\tEspaço usado: $DevUsed2 GB ($DevUsePerc2%)" 
echo -e "\tEspaço disp.: $DevAvailable2 GB"
echo -e "\tEspaço  req.: $_WANT_SPACE GB"

# Removendo diretorios vazios
find "$_MEDIABACKUP" -type d -empty|sort  >> "$temp_file"
while read backup_dir ; do
  if [ -d "$backup_dir" ] ; then
    if ! [[ "$backup_dir" =~ "lost+found" ]] ; then
      rmdir "$backup_dir"
    fi
  fi
done <$temp_file
[ -f "$temp_file" ] && rm -f "$temp_file"

# Desmontando a midia para voltar ao estagio de montagem que se encontrava antes de iniciar o script
if ! [ $already_mount -gt 0 ] ; then
  echo "Desmontando $_MEDIABACKUP..."
  umount_disk
fi

# removendo snapshots antigos
if [ $clean_snapshots -gt 0 ] ; then
  #echo "Debug: /root/xenbackup-cleansnapshots.sh   " 1>&2;
  /root/xenbackup-cleansnapshots.sh
fi

# Finalizando o limpeza do backup
date_finish="`date +%Y-%m-%d+%H:%M`"

exit 0
