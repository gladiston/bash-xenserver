#!/bin/bash
# Nome:     xenbackup-estimate.sh
# Autor:    Hamacker (sirhamacker [em] gmail.com)
# Licença:  GPL-2
# Função:   Script para calcular o espaço usado por VMs
# Params:   -local faz o calculo de todas as VMs armazenadas no host local
#           -all faz o calculo de todas as VMs armazenadas no pool
#           /caminho/para/arquivo.txt faz o calculo das VMs contidas neste arquivo
#           -v verbose, mostra maiores detalhes
. /root/xenfunctions.sh
if [ $? -ne 0 ] ; then
  echo "Nao foi possivel importar o arquivo [/usr/bin/xenfunctions.sh] !"
  exit 2;
fi

#
# Inicio do Script
#
init_vars
TMP_BACKUP_LIST=""
OPTIONS=""
VERBOSE=0
ESTIMATE_TYPE=0  # 1=-local, 2=-all, 3=file
ESTIMATE_MSG=""
# confere se um dos parametros é uma especificacao de arquivo
for CURRENT_PARAM in "$@" ; do
  if [ -f "$CURRENT_PARAM" ] ; then 
    if ! [[ "$CURRENT_PARAM" =~ "^-" ]] ; then
      TMP_BACKUP_LIST="$CURRENT_PARAM"
      ESTIMATE_TYPE=3
      ESTIMATE_MSG="Estimativa: Todas mencionadas no arquivo auxiliar"
    fi
  fi
  if [ $ESTIMATE_TYPE -eq 0 ] && [[ "$CURRENT_PARAM" =~ "^-local" ]] ; then 
    ESTIMATE_TYPE=1
    ESTIMATE_MSG="Estimativa: Todas as VMs no host $HOST ($_HOST_UUID)"
    TMP_BACKUP_LIST="/tmp/xenbackup-estimativa-local-$$.txt"
  fi
  if [ $ESTIMATE_TYPE -eq 0 ] && [[ "$CURRENT_PARAM" =~ "^-all" ]] ; then 
    ESTIMATE_TYPE=2
    ESTIMATE_MSG="Estimativa: Todas as VMs do pool"
    TMP_BACKUP_LIST="/tmp/xenbackup-estimativa-todos-$$.txt"
  fi
  [[ "$CURRENT_PARAM" =~ "^-v" ]] && VERBOSE=1
done

#Se o tipo de estimativa não for especificado então assume apenas as VMs locais
[ $ESTIMATE_TYPE -le 0 ] && ESTIMATE_TYPE=1

if [ $VERBOSE -gt 0 ] ; then
  echo "# Opcoes de execução:" 1>&2;
  echo "# Verbose: $VERBOSE" 1>&2;
  echo "# $ESTIMATE_MSG ($ESTIMATE_TYPE)" 1>&2;
  echo "# Arquivo auxiliar: $TMP_BACKUP_LIST" 1>&2;
fi

if [ $ESTIMATE_TYPE -eq 1 ] || [ $ESTIMATE_TYPE -eq 2 ] ; then
  [ -f "$TMP_BACKUP_LIST" ] && rm -f "$TMP_BACKUP_LIST"
  echo "# Lista das VMs que fará estimativa de espaço em disco" 2>&1 | tee "$TMP_BACKUP_LIST"
  echo "# $ESTIMATE_MSG" 2>&1 | tee -a "$TMP_BACKUP_LIST"
  if [ $ESTIMATE_TYPE -eq 1 ] ; then
    # Captura VMs locais que estejam rodando  
    xe vm-list resident-on=$_HOST_UUID is-control-domain=false is-a-snapshot=false params=name-label,uuid \
      |grep "name-label" |uniq| tr -s " " | cut -d " " -f 5 2>&1 | tee -a "$TMP_BACKUP_LIST"
  	# e adiciona também VMs locais que não estejam rodando
    xe vm-list resident-on="<not in database>" is-control-domain=false is-a-snapshot=false params=name-label,uuid \
      |grep "name-label" |uniq| tr -s " " | cut -d " " -f 5 2>&1 | tee -a "$TMP_BACKUP_LIST"
  fi  
  if [ $ESTIMATE_TYPE -eq 2 ] ; then
    xe vm-list is-control-domain=false is-a-snapshot=false params=name-label,uuid \
      |grep "name-label" |uniq| tr -s " " | cut -d " " -f 5 2>&1 | tee -a "$TMP_BACKUP_LIST"
  fi

fi
#if [ $VERBOSE -gt 0 ] && [ -f "$TMP_BACKUP_LIST" ] ; then
#  cat "$TMP_BACKUP_LIST"
#fi
opc_verb=""
[ $VERBOSE -gt 0 ] && opc_verb="-v"
ESTIMATIVE=$(space_estimate "$TMP_BACKUP_LIST" "$opc_verb")
#if [[ "$ESTIMATIVE" =~ "GB" ]] ; then
  #ESTIMATIVE=$(echo "$ESTIMATIVE"|cut -d':' -f2|tr -d '[:alpha:]'|tr -d '[:space:]')
  #echo "debug mark #1 ESTIMATIVE=$ESTIMATIVE" 1>&2;
#fi
#  echo "debug mark #2 ESTIMATIVE=$ESTIMATIVE" 1>&2;
if [ "$VERBOSE" -le 0 ] ; then
  pad 50 "Total estimado" "." 
  echo ": $ESTIMATIVE GB"
fi
# Fim do programa
exit 0;
