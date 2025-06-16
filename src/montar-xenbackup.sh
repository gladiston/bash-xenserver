#!/bin/bash
# ------------------------------------------------------------
# Script: montar-xenbackup.sh
# Autor: Gladiston Santana <gladiston.santana@gmail.com> (ofuscado)
# Data: 2025-05-14
# Descrição: Monta ou desmonta (com -u) o primeiro dispositivo
#            com LABEL iniciando em 'xenbackup' no ponto /mnt/xenbackup.
# Uso:
#   sudo ./montar-xenbackup.sh         # para montar
#   sudo ./montar-xenbackup.sh -u      # para desmontar
# Licença: GPL-3.0
# ------------------------------------------------------------
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

# Se for para desmontar
if [ "$1" = "-u" ]; then
  echo "Procurando dispositivos montados com label iniciando por 'xenbackup'..."

  # Pega todos dispositivos montados com seus LABELs
  while IFS= read -r line; do
    DEV=$(echo "$line" | cut -d: -f1)
    LABEL=$(echo "$line" | grep -o 'LABEL="[^"]*"' | cut -d= -f2 | tr -d '"')

    if [[ "$LABEL" == xenbackup* ]]; then
      # Verifica se está montado em /mnt/xenbackup
      MONTADO_EM=$(findmnt -n -o TARGET --source "$DEV")
      if [ "$MONTADO_EM" = "$MOUNT_LOCAL" ]; then
        echo "Desmontando $DEV de $MOUNT_LOCAL..."
        umount "$MOUNT_LOCAL"
        if [ $? -eq 0 ]; then
          echo "Desmontado com sucesso."
          exit 0
        else
          echo "Erro ao desmontar $DEV."
          exit 1
        fi
      fi
    fi
  done < <(blkid | grep 'LABEL="xenbackup"')

  echo "Nenhum dispositivo montado com label 'xenbackup*' encontrado em $MOUNT_LOCAL."
  exit 1
fi

# Cria ponto de montagem se necessário
if [ ! -d "$MOUNT_LOCAL" ]; then
  echo "Criando ponto de montagem: $MOUNT_LOCAL"
  mkdir -p "$MOUNT_LOCAL" || {
      echo "Erro ao criar diretório $MOUNT_LOCAL"
      exit 1
  }
fi

# Verifica se já está montado
if mountpoint -q "$MOUNT_LOCAL"; then
  echo "Já está montado: $MOUNT_LOCAL"
  exit 0
fi

# Procura por dispositivo com label que começa com "xenbackup"
DISPOSITIVO=$(blkid | grep 'LABEL="xenbackup' | cut -d: -f1 | head -n1)

if [ -z "$DISPOSITIVO" ]; then
  echo "Nenhum disco com label iniciando por 'xenbackup' encontrado."
  exit 1
fi

echo "Dispositivo encontrado: $DISPOSITIVO"

# Monta
echo "Montando $DISPOSITIVO em $MOUNT_LOCAL..."
mount "$DISPOSITIVO" "$MOUNT_LOCAL"

if [ $? -eq 0 ]; then
  echo "Montagem realizada com sucesso."
else
  echo "Erro ao montar o dispositivo $DISPOSITIVO."
  exit 1
fi

