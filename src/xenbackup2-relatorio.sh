#!/bin/bash
# Script: xenbackup2-relatorio.sh
# Objetivo: Gerar e enviar por e-mail uma lista hierárquica de todos os arquivos e pastas no backup local ou NFS
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

DESTINO=""
RELATORIO="/tmp/relatorio_xva_$$.txt"
NOME_HOST=$(hostname)

gerar_relatorio() {
  DESTINO="$1"
  EMAIL="$2"

  echo "📦 Gerando relatório de arquivos e diretórios em $DESTINO ..."
  BASELEN=${#DESTINO}

  {
    find "$DESTINO" | sort | while read -r ITEM; do
      RELPATH="${ITEM:$BASELEN}"
      [[ "$RELPATH" == "" ]] && continue
      DEPTH=$(grep -o "/" <<< "$RELPATH" | wc -l)
      PREFIX=$(printf '|  %.0s' $(seq 1 $((DEPTH-1))))
      NOME=$(basename "$ITEM")
      echo "${PREFIX}|-- $NOME"
    done

    TAMANHO_OCUPADO=$(du -sb "$DESTINO" | awk '{printf "%.2f", $1 / 1073741824}')
    ESPACO_LIVRE=$(df -BG "$DESTINO" | awk 'NR==2 {gsub("G",""); print $4}')

    echo
    echo "📁 Tamanho total ocupado: ${TAMANHO_OCUPADO} GB"
    echo "🧩 Espaço livre disponível: ${ESPACO_LIVRE} GB"
  } > "$RELATORIO"

  echo "✉️ Enviando relatório para: $EMAIL"
  mail -s "Relatório do conteúdo do disco xenbackup em $NOME_HOST" "$EMAIL" < "$RELATORIO"

  rm -f "$RELATORIO"
}

montar_local() {
  DEVICE=$(blkid -o device -t LABEL="xenbackup" | head -n1)
  if [ -z "$DEVICE" ]; then
    echo "❌ Nenhum disco com label 'xenbackup' foi encontrado."
    return 1
  fi

  DESTINO="/mnt/xenbackup"
  mkdir -p "$DESTINO"
  mount "$DEVICE" "$DESTINO"
  if [ $? -eq 0 ]; then
    echo "✅ Disco montado em $DESTINO"
    gerar_relatorio "$DESTINO" "$EMAIL_DESTINO"
    umount "$DESTINO"
    rmdir "$DESTINO"
  else
    echo "❌ Falha ao montar $DEVICE em $DESTINO"
    return 1
  fi
}

montar_nfs() {
  DESTINO="/mnt/bak-virt"
  mkdir -p "$DESTINO"
  mount -t nfs "$NFS_SERVER" "$DESTINO"
  if [ $? -eq 0 ]; then
    echo "✅ Unidade NFS montada em $DESTINO"
    gerar_relatorio "$DESTINO" "$EMAIL_DESTINO"
    umount "$DESTINO"
    rmdir "$DESTINO"
  else
    echo "❌ Falha ao montar unidade NFS"
    return 1
  fi
}

# Menu
clear
$_XENPATH/cabecalho.sh "Menu de Relatório de Backups" "off";
echo "1) Enviar relatório do disco local de backup"
echo "2) Enviar relatório da unidade NFS de backup"
echo "========================================"
read -p "Escolha uma opção [1-2]: " OPCAO

read -p "Digite o e-mail de destino [suporte@$EMAILS_DOMAIN]: " EMAIL_DESTINO
EMAIL_DESTINO="${EMAIL_DESTINO:-suporte@$EMAILS_DOMAIN}"
if [[ "$EMAIL_DESTINO" != *@* ]]; then
  EMAIL_DESTINO="${EMAIL_DESTINO}@${EMAILS_DOMAIN}"
fi

case "$OPCAO" in
  1) montar_local ;;
  2) montar_nfs ;;
  *) echo "❌ Opção inválida." ;;
esac
