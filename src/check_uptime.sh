#!/bin/bash
# Exibe informações de uptime do servidor com cabeçalho comum
# Autor: Gladiston Santana
_XENPATH="$(dirname "$0")"  # ou /root
TITULO="Conferencia de servidor em uso"
echo "════════════════════════════════════════════════════════════"
echo "⏱️ Uptime do servidor (dados sem formatação):"
uptime
echo "E a seguir, formatados para maior clareza:"

if [ -f "$_XENPATH/cabecalho.sh" ] ; then
  "$_XENPATH/cabecalho.sh" "$TITULO"
fi
read -p "Pressione ENTER para continuar..."
