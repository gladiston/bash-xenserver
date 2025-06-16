#!/bin/bash
# xenbackup2-clean-snaps.sh - Limpa snapshots que contêm um termo no nome
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Uso: ./xenbackup2-clean-snaps.sh
# Licença: Uso interno. Proibida a reprodução sem autorização prévia por escrito.
# Criado em: 23/05/2025
# Ult. Atualização: 23/05/2025

# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

# Palavra-chave a ser buscada nos nomes dos snapshots
FILTRO="_backup_"
$_XENPATH/cabecalho.sh "Limpeza de snapshots" "off";

echo "📋 Buscando snapshots com '$FILTRO' no nome..."
mapfile -t TODOS_SNAPSHOTS < <(xe snapshot-list --minimal | tr ',' '\n' | grep -v '^$')

SNAPSHOTS=()
for uuid in "${TODOS_SNAPSHOTS[@]}"; do
  NAME=$(xe snapshot-param-get uuid="$uuid" param-name=name-label 2>/dev/null)
  if echo "$NAME" | grep -q "$FILTRO"; then
    SNAPSHOTS+=("$uuid")
  fi
done

if [ ${#SNAPSHOTS[@]} -eq 0 ]; then
  echo "✅ Nenhum snapshot com nome contendo '$FILTRO' foi encontrado."
  read -p "Pressione ENTER para retornar ao menu... " TEMP
  exit 0
fi

# Exibir lista numerada
echo ""
echo "Snapshots encontrados:"
for i in "${!SNAPSHOTS[@]}"; do
  NAME=$(xe snapshot-param-get uuid="${SNAPSHOTS[$i]}" param-name=name-label 2>/dev/null)
  echo "  [$i] $NAME (${SNAPSHOTS[$i]})"
done

# Perguntar ao usuário
echo ""
read -p "❓ Deseja apagar algum deles? Digite o número correspondente ou pressione ENTER para sair: " OPCAO

# Verificar entrada
if [[ "$OPCAO" =~ ^[0-9]+$ ]] && [ "$OPCAO" -ge 0 ] && [ "$OPCAO" -lt ${#SNAPSHOTS[@]} ]; then
  UUID="${SNAPSHOTS[$OPCAO]}"
  NAME=$(xe snapshot-param-get uuid="$UUID" param-name=name-label)

  # Verificar se está sendo exportado
  processos=$(ps -eo pid,cmd | grep '[x]e vm-export')
  if echo "$processos" | grep -q "$UUID"; then
    echo "⛔ O snapshot '$NAME' está atualmente em uso (exportação em andamento). Não será removido."
    exit 2
  fi

  # Confirmar e apagar
  echo "🗑️ Apagando snapshot '$NAME' ($UUID)..."
  xe snapshot-uninstall snapshot-uuid="$UUID" force=true
  if [ $? -eq 0 ]; then
    echo "✅ Snapshot removido com sucesso."
  else
    echo "❌ Falha ao remover o snapshot."
  fi
else
  echo "👍 Nenhuma ação realizada. Saindo..."
fi
