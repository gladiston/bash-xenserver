#!/bin/bash
# Script: xenbackup2-lista.sh
# Objetivo: Executar backups de VMs Xen conforme lista, para NFS ou local com montagem
# Autor: Gladiston Santana <gladiston@vidycorp.com.br>

#set -euo pipefail

# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

SCRIPT_BACKUP="$_XENPATH/xenbackup2.sh"
LISTA_VMS="$_XENPATH/xenbackup-list.txt"
WALL_MSG=false
PROGRAMA_LIMPAR_MEDIA=$_XENPATH/xenbackup2-clean.sh
BACKUP_COUNT=0

# Horário de início
INICIO=$(date '+%d/%m/%Y %H:%M:%S')
$_XENPATH/cabecalho.sh "⌛ Iniciando backups em $INICIO" "off";
 
[[ $WALL_MSG == true ]] && wall "Iniciando processo de backup Xen em $INICIO"

# Ponto de montagem genérico
MOUNTED=0

# Monta disco local se necessário
if grep -v '^[[:space:]]*#' "$LISTA_VMS" | awk '{print $2}' | grep -qx "$MOUNT_LOCAL"; then
  echo "Verificando disco com label "xenbackup"..."
  DEVICE=$(lsblk -o NAME,LABEL -nr | awk '$2=="xenbackup"{print $1;exit}')
  if [ -z "$DEVICE" ]; then
    echo "❌ Disco com label xenbackup não encontrado. Abortando."
    [[ $WALL_MSG == true ]] && wall "Backup Xen cancelado: disco com label xenbackup não encontrado."
    exit 2
  fi
  
  if [ ! -d "$MOUNT_LOCAL" ]; then
    echo "📁 Criando ponto de montagem: $MOUNT_LOCAL"
    mkdir -p "$MOUNT_LOCAL" || {
        echo "❌ Erro ao criar diretório $MOUNT_LOCAL"
        exit 1
    }
  fi  

  # Verifica se já está montado o mesmo dispositivo no ponto de montagem
  echo "🔗 Montando /dev/$DEVICE em $MOUNT_LOCAL..."
  if ! mountpoint -q "$MOUNT_LOCAL" || ! findmnt -n --source "/dev/$DEVICE" --target "$MOUNT_LOCAL" >/dev/null 2>&1; then
    mount "/dev/$DEVICE" "$MOUNT_LOCAL"
    if [ $? -ne 0 ]; then
      echo "❌ Falha ao montar /dev/$DEVICE em $MOUNT_LOCAL. Abortando."
      [[ $WALL_MSG == true ]] && wall "Backup Xen cancelado: falha na montagem local."
      exit 3
    fi

  fi
  MOUNTED=1
fi

# Processa cada entrada do arquivo de lista
while IFS= read -r line; do
  # Remove comentários e faz trim de espaços
  line="${line%%#*}"
  line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  [ -z "$line" ] && continue

  # Extrai VM e destino
  VM=$(awk '{print $1}' <<< "$line")
  DEST=$(awk '{print $2}' <<< "$line")

  echo "⌛ Iniciando backup da VM $VM para $DEST..."
    # Verifica se outro processo de backup está em andamento
  if pgrep -f "$SCRIPT_BACKUP" > /dev/null; then
    echo "⚠️ Outro processo de backup ($SCRIPT_BACKUP) já está em execução. Interrompendo."
    exit 1
  fi
  "$SCRIPT_BACKUP" "$VM" "$DEST"
  if [ $? -eq 0 ]; then
    BACKUP_COUNT=$((BACKUP_COUNT + 1))
  fi  
  echo "⌛ Esperando uns 15 segundos antes de prosseguir..."
  sleep 15
done < "$LISTA_VMS"

# Desmonta e limpa se local montado
if [ "$MOUNTED" -eq 1 ]; then
  if [ "$BACKUP_COUNT" -gt 0 ]; then
    "$PROGRAMA_LIMPAR_MEDIA" "$MOUNT_LOCAL"
  fi  
  echo "⌛ Desmontando $MOUNT_LOCAL..."
  umount "$MOUNT_LOCAL" && rmdir "$MOUNT_LOCAL"
  echo "⌛ Executando limpeza de backups antigos no destino local..."
fi

# Horário de término
FIM=$(date '+%d/%m/%Y %H:%M:%S')
echo "Todos os backups agendados foram processados."
echo "Finalizado em $FIM"
[[ $WALL_MSG == true ]] && wall "Backup Xen finalizado em $FIM"
