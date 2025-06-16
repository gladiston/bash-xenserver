#!/bin/bash
# xenbackup2-clean-temp-vm.sh - Limpa VMs temporárias contendo '_backup_' no nome
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Uso: ./xenbackup2-clean-temp-vm.sh
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

# Obter todas as VMs válidas e filtrar por nome contendo "_backup_"
echo "📋 Listando VMs com '_backup_' no nome..."
mapfile -t FILTRO_VMS < <(
  for uuid in $(xe vm-list is-control-domain=false is-a-template=false --minimal | tr ',' '\n'); do
    name=$(xe vm-param-get uuid="$uuid" param-name=name-label 2>/dev/null)
    if echo "$name" | grep -q "_backup_"; then
      echo "$uuid|$name"
    fi
  done
)

if [ ${#FILTRO_VMS[@]} -eq 0 ]; then
  echo "✅ Nenhuma VM com nome contendo '_backup_' foi encontrada."
  read -p "Pressione ENTER para retornar ao menu... " TEMP
  exit 0
fi

# Exibir lista numerada
$_XENPATH/cabecalho.sh "VMs temporarias usadas por backups" "off";
echo "VMs temporárias encontradas:"
for i in "${!FILTRO_VMS[@]}"; do
  UUID="${FILTRO_VMS[$i]%%|*}"
  NAME="${FILTRO_VMS[$i]#*|}"
  echo "  [$i] $NAME ($UUID)"
done

# Perguntar ao usuário
echo ""
read -p "❓ Deseja apagar alguma dessas VMs? Digite o número correspondente ou pressione ENTER para sair: " OPCAO

# Verificar entrada
if [[ "$OPCAO" =~ ^[0-9]+$ ]] && [ "$OPCAO" -ge 0 ] && [ "$OPCAO" -lt ${#FILTRO_VMS[@]} ]; then
  UUID="${FILTRO_VMS[$OPCAO]%%|*}"
  NAME="${FILTRO_VMS[$OPCAO]#*|}"

  read -p "⚠️ Tem certeza que deseja remover a VM '$NAME'? [s/N]: " CONFIRMA
  if [[ "$CONFIRMA" =~ ^[sS]$ ]]; then
    echo "🗑️ Removendo VM '$NAME' ($UUID)..."
    xe vm-destroy uuid="$UUID"
    if [ $? -eq 0 ]; then
      echo "✅ VM removida com sucesso."
    else
      echo "❌ Falha ao remover a VM."
    fi
  else
    echo "❎ Ação cancelada. Nenhuma VM foi removida."
  fi
else
  echo "👍 Nenhuma ação realizada. Saindo..."
fi
