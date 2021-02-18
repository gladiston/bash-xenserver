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

# Confere se o backup já não está rodando e neste caso aborta a operação
LINHAS=$(ps ax|grep "xe *vm-export* vm=snapshot"|grep -v "grep"|wc -l)
if [ $LINHAS -gt 0 ] ; then
  echo "Há um backup em andamento, não posso executar novamente enquanto ele estiver em operação." 
  exit 2
fi


# confere se um dos parametros é uma especificacao de arquivo
ARQ_BOOT_LISTA=$1

if ! [ -f "$ARQ_BOOT_LISTA" ] ; then
   echo "Arquivo nao existe: $ARQ_BOOT_LISTA"
   exit 2;
fi

erro=0
backup_title="Ajustando VMs indicadas em $ARQ_BOOT_LISTA para inicio automatico" 

# Arquivo de log
_XENBACKUP_LOGFILE="/var/log/xen/xenbackup-$HOSTNAME-$_DATE_START.log" 
[ -f "$_XENBACKUP_LOGFILE" ] && rm -f "$_XENBACKUP_LOGFILE"

# Avisando os terminais, que talvez se estiverem abertos de que o backup está se iniciando
cab_msg="==== VMs para iniciar automaticamente [ $HOSTNAME ] em $_DATE_START ===="
cab_msg="$cab_msg\n$backup_title"
cab_msg="$cab_msg\nLog: $_XENBACKUP_LOGFILE"
echo -ne "$cab_msg\n"


# Lê o arquivo temporario contendo os nomes das VMs e faz backup de uma vm de cada vez
# linha por linha.
while read LINHA ; do
  erro=0
  vm_existe=0
	[ "$_DEBUG" = "1" ] && echo "Processando : $LINHA"
  LINHA_TMP=$(semremarks "$LINHA")
  VM_NAME=$(echo "$LINHA_TMP"|cut -d' ' -f1)  
  #VM_NAME=`semremarks "$LINHA_TMP"`
  VM_START=false

  if [ "$VM_NAME" != "" ] ; then
	  [ "$_DEBUG" = "1" ] && echo "Processando : $LINHA_TMP(trim)"
	  count=$(echo "$LINHA_TMP"|grep " true"|wc -l);
	  if [ "$count" -eq 0 ] ; then
		  count=$(echo "$LINHA_TMP"|grep " false"|wc -l);
	  fi
	  if [ "$count" -gt 0 ] ; then
		  VM_NAME=$(echo "$LINHA_TMP"|cut -d' ' -f1)
		  VM_START=$(echo "$LINHA_TMP"|cut -d' ' -f2)
	  fi

	  vm_existe=$(xe vm-list|grep "$VM_NAME"|wc -l)
	  if [ "$vm_existe" -gt 0 ] ; then
		  [ "$_DEBUG" = "1" ] && echo $_SCRIPT_XENSTARTONBOOT "$VM_NAME" "$VM_START"
      $_SCRIPT_XENSTARTONBOOT "$VM_NAME" "$VM_START"
		  erro=$?   
	  else
		  [ "$_DEBUG" = "1" ] && echo -e "\tLinha ignorada : $LINHA_TMP\n"
	  fi
  fi
done <"$ARQ_BOOT_LISTA"

# Fim do programa

sair 1 "$_XENBACKUP_LOGFILE";
