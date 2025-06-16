#!/bin/bash
# Script: xenbackup2-xva-teste-midia.sh
# Objetivo: Importar .xva, testar e destruir VM temporária
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

ARQUIVO_XVA="$1"
$_XENPATH/cabecalho.sh "Testar arquivo de backup" "off";

echo "📄 Arquivo selecionado: $ARQUIVO_XVA"
if [ -f "$ARQUIVO_XVA" ]; then
  TAMANHO_BYTES=$(du -b "$ARQUIVO_XVA" | cut -f1)
  TAMANHO_GB=$(echo "scale=2; $TAMANHO_BYTES/1073741824" | bc)
  echo "📦 Tamanho do arquivo: $TAMANHO_GB GB"
fi

if [ ! -f "$ARQUIVO_XVA" ]; then
  echo "❌ Arquivo não encontrado: $ARQUIVO_XVA"
  exit 1
fi

VM_TEMP_NAME="teste-de-$(basename "$ARQUIVO_XVA" .xva)"
echo "📥 Importando com nome temporário: $VM_TEMP_NAME..."

IMPORTED_UUID=$(xe vm-import filename="$ARQUIVO_XVA" new-name-label="$VM_TEMP_NAME" --quiet)
if [ $? -eq 0 ]; then
  echo "✅ Importação concluída com sucesso."
  UUID_TO_DESTROY="$IMPORTED_UUID"
  if [ -n "$UUID_TO_DESTROY" ]; then
    xe vm-uninstall uuid="$UUID_TO_DESTROY" force=true

if [ $? -eq 0 ]; then
  echo "🗑️ VM de teste removida: $VM_TEMP_NAME"
else
  echo "⚠️ Não foi possível remover a VM de teste: $VM_TEMP_NAME"
  TAMANHO_BYTES=$(du -b "$ARQUIVO_XVA" | cut -f1)
  TAMANHO_GB=$(echo "scale=2; $TAMANHO_BYTES/1073741824" | bc)
  echo -e "Subject: [falha] Não foi possível excluir VM de teste ($VM_TEMP_NAME)
\
Data/Hora: 2025-05-20 19:30
\
Nome da VM: $VM_TEMP_NAME
\
UUID: $UUID_TO_DESTROY
\
Arquivo: $ARQUIVO_XVA
\
Tamanho: $TAMANHO_GB GB
\
A exclusão da VM de teste deverá ser feita manualmente." | sendmail gladiston@vidycorp.com.br suporte@vidycorp.com.br
fi

fi
  fi
  exit 0
else
  echo "❌ Erro ao importar o arquivo .xva"
  exit 1
fi
