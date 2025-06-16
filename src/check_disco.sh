#!/bin/bash
# smtp_disco.sh - Mostra o uso de disco no sistema
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Uso: Executado manualmente ou por outro script para verificar espaço em disco
# Licença: Uso interno. Proibida a reprodução sem autorização prévia por escrito.
# Criado em: 2025-05-23
# Ult. Atualização: 2025-05-23

CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

TITULO="Conferência de espaço em disco"

# Executa cabeçalho se existir
if [ -f "$_XENPATH/cabecalho.sh" ]; then
  "$_XENPATH/cabecalho.sh" "$TITULO"
else
  echo "⚠️  Arquivo de cabeçalho não encontrado: $_XENPATH/cabecalho.sh"
fi

echo "💾 Espaço em disco disponível:"
df -h --output=source,size,used,avail,pcent,target | grep -v "^tmpfs"

echo
read -p "🔄 Pressione ENTER para continuar..."