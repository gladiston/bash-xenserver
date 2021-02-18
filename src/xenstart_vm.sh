#!/bin/bash
# Nome do script : xenboot-lista.sh
# Autor : Hamacker (sirhamacker [em] gmail.com)
# Licença : GPL-2
# Função : Script para a determinar quais as VMs que terão boot automatico
#          assim que o XenServer completa o boot.
# Este script lê o arquivo xenboot-start.txt e as VMs indicadas neste
#   arquivo terá o XenServer ajustado para iniciar elas assim que o boot
#   de si proprio estiver completo
. /root/xenfunctions.sh
if [ $? -ne 0 ] ; then
  echo "Nao foi possivel importar o arquivo [/root/xenfunctions.sh] !"
  exit 2;
fi

#
# Inicio do Script
#
init_vars


# Quando debug ligado, mostra mais mensagens
#_DEBUG=1

[ -z $_DATE_START ] && _DATE_START=$(date +%Y-%m-%d+%Hh%M)

# confere se um dos parametros é uma especificacao de arquivo
ARQ_BOOT_LISTA=$1

if ! [ -f "$ARQ_BOOT_LISTA" ] ; then
   echo "Arquivo nao existe: $ARQ_BOOT_LISTA"
   exit 2;
fi

erro=0
my_title="Iniciando as VMs indicadas em $ARQ_BOOT_LISTA" 

# Arquivo de log
_XENBACKUP_LOGFILE="/var/log/xen/xenbackup-$HOSTNAME-$_DATE_START.log" 
[ -f "$_XENBACKUP_LOGFILE" ] && rm -f "$_XENBACKUP_LOGFILE"

# Avisando os terminais, que talvez se estiverem abertos de que o backup está se iniciando
cab_msg="$my_title"
cab_msg="$cab_msg\nLog: $_XENBACKUP_LOGFILE"
echo -ne "$cab_msg\n"


# Lê o arquivo temporario contendo os nomes das VMs e faz backup de uma vm de cada vez
# linha por linha.
while read LINHA ; do
  erro=0
  vm_existe=0
	[ "$_DEBUG" = "1" ] && echo "Processando: $LINHA" 1>&2;
  LINHA_TMP=$(semremarks "$LINHA")
  VM_NAME=$(echo "$LINHA_TMP"|cut -d' ' -f1)  
  VM_START=false

  if [ "$VM_NAME" != "" ] ; then
	  count=$(echo "$LINHA_TMP"|grep " true"|wc -l);
	  if [ "$count" -eq 0 ] ; then
		  count=$(echo "$LINHA_TMP"|grep " false"|wc -l);
	  fi
	  if [ "$count" -gt 0 ] ; then
		  VM_NAME=$(echo "$LINHA_TMP"|cut -d' ' -f1)
		  VM_START=$(echo "$LINHA_TMP"|cut -d' ' -f2)
	  fi
	  [ "$_DEBUG" = "1" ] && echo "Processando: $VM_NAME($VM_START)"
    if [ "$VM_START" == "true" ] ; then
      [ "$_DEBUG" = "1" ] && echo "Processando: Disparando o comando para iniciar a $VM_NAME($VM_START)" 1>&2;
      if xen_vm_exist "$VM_NAME"; then
        [ "$_DEBUG" = "1" ] && echo "Processando: Conferindo se $VM_NAME existe: Sim" 1>&2;
        if xen_vm_running "$VM_NAME"; then
          echo "$VM_NAME: Já esta rodando"
        else
          echo "$VM_NAME: Iniciando..."
        fi
      else
        [ "$_DEBUG" = "1" ] && echo "Processando: Conferindo se $VM_NAME existe: Nao" 1>&2;
      fi
    fi
  fi
done <"$ARQ_BOOT_LISTA"

# Fim do programa

sair 1 "$_XENBACKUP_LOGFILE";
