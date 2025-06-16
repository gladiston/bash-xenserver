#!/bin/bash
# Script: xenbackup2-clean-menu.sh
# Objetivo: Menu para limpeza de backups em disco local ou unidade NFS
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

NFS_SERVER="$NFS_SERVER_IP:$NFS_SERVER_PATH"
PROGRAMA_LIMPAR_MEDIA=$_XENPATH/xenbackup2-clean.sh

# Função para montar disco local com label xenbackup
montar_disco_local() {
  DESTINO="$MOUNT_LOCAL"
  DEVICE=$(blkid -o device -t LABEL="xenbackup" | head -n1)
  if [ -z "$DEVICE" ]; then
    echo "❌ Nenhum disco com label 'xenbackup' foi encontrado."
    return 1
  fi

  if [ ! -d "$DESTINO" ]; then
    echo "Criando pasta: $DESTINO"
    mkdir -p "$DESTINO" || {
      echo "Erro ao criar diretório $DESTINO"
      exit 1
    }
  fi

  mount "$DEVICE" $DESTINO
  if [ $? -eq 0 ]; then
    echo "✅ Disco montado em $DESTINO"
    $PROGRAMA_LIMPAR_MEDIA "$DESTINO"
    umount $DESTINO
    rmdir $DESTINO
  else
    echo "❌ Falha ao montar $DEVICE em $DESTINO"
    return 1
  fi
}

# Função para montar unidade NFS
montar_nfs() {
  DESTINO="/mnt/nfs-$NFS_SERVER_IP"
  if [ ! -d "$DESTINO" ]; then
    echo "Criando pasta: $DESTINO"
    mkdir -p "$DESTINO" || {
      echo "Erro ao criar diretório $DESTINO"
      exit 1
    }
  fi
  mount -t nfs $NFS_SERVER $DESTINO
  if [ $? -eq 0 ]; then
    echo "✅ Unidade NFS montada em $DESTINO"
    $PROGRAMA_LIMPAR_MEDIA "$DESTINO"
    umount $DESTINO
    rmdir $DESTINO
  else
    echo "❌ Falha ao montar unidade NFS"
    return 1
  fi
}

# Menu
clear
_XENPATH=/root
$_XENPATH/cabecalho.sh "Menu de Limpeza de Backup" "off";
echo "===== Menu de Limpeza de Backup ====="
echo "1) Limpar disco local de backup"
echo "2) Limpar unidade NFS de backup"
echo "====================================="
read -p "Escolha uma opção [1-2]: " OPCAO

case "$OPCAO" in
  1) montar_disco_local ;;
  2) montar_nfs ;;
  *) echo "❌ Opção inválida." ;;
esac

