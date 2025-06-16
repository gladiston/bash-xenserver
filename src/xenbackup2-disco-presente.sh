#!/bin/bash
# Script: xenbackup2-disco-presente.sh
# Objetivo: Verificar se a mídia de backup com label 'xenbackup' está presente e montada
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Licença: Uso interno. Proibida a reprodução sem autorização prévia por escrito.
# Data: 16/05/2025

# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

# Procurar dispositivos com label xenbackup
DISPOSITIVOS=$(blkid -o device -t LABEL="xenbackup")
MONTADOS=()
NAO_MONTADOS=()
$_XENPATH/cabecalho.sh "Verifica se há mídia de backup presente" "off";

if [ -z "$DISPOSITIVOS" ]; then
  echo "❌ Nenhum dispositivo com label 'xenbackup' foi encontrado."
else
  echo "✅ Dispositivos com label 'xenbackup' encontrados:"
  echo "$DISPOSITIVOS"
  echo

  # Verificar se estão montados ou não
  for DEV in $DISPOSITIVOS; do
    MONTADO=$(mount | grep "$DEV" | awk '{print $3}')
    if [ -n "$MONTADO" ]; then
      echo "📂 O dispositivo $DEV está montado em: $MONTADO"
      MONTADOS+=("$DEV")
    else
      echo "⚠️  O dispositivo $DEV não está montado."
      NAO_MONTADOS+=("$DEV")
    fi
  done

  # Desmontar os que estão montados
  if [ ${#MONTADOS[@]} -gt 0 ]; then
    echo
    read -rp "🔽 Gostaria de desmontar o(s) dispositivo(s) montado(s)? (s/N) " RESP
    if [[ "$RESP" =~ ^[Ss] ]]; then
      for DEV in "${MONTADOS[@]}"; do
        PONTO=$(mount | grep "$DEV" | awk '{print $3}')
        echo "🔽 Desmontando $DEV de $PONTO..."
        umount "$DEV"
        if [ $? -eq 0 ]; then
          echo "✅ Dispositivo $DEV desmontado com sucesso."
        else
          echo "❌ Falha ao desmontar $DEV."
        fi
      done
    else
      echo "ℹ️  Nenhum dispositivo foi desmontado."
    fi
  fi

  # Montar os que estão presentes mas ainda não montados
  if [ ${#NAO_MONTADOS[@]} -gt 0 ]; then
    echo
    read -rp "📦 Deseja montar o(s) dispositivo(s) não montado(s)? (s/N) " RESP
    if [[ "$RESP" =~ ^[Ss] ]]; then
      for DEV in "${NAO_MONTADOS[@]}"; do
        MOUNT_POINT="/mnt/$(basename "$DEV")"
        mkdir -p "$MOUNT_POINT"
        echo "📦 Montando $DEV em $MOUNT_POINT..."
        mount "$DEV" "$MOUNT_POINT"
        if [ $? -eq 0 ]; then
          echo "✅ Dispositivo $DEV montado com sucesso em $MOUNT_POINT."
        else
          echo "❌ Falha ao montar $DEV."
        fi
      done
    else
      echo "ℹ️  Nenhum dispositivo foi montado."
    fi
  fi
fi
