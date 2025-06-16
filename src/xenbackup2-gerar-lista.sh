#!/bin/bash
# Script: xenbackup2-gerar-lista.sh
# Objetivo: Gerar um arquivo com a lista das VMs disponíveis para backup
# Autor: Gladiston Santana <gladiston@vidycorp.com.br>

set -euo pipefail
trap 'echo "❌ Erro durante geração da lista. Abortando."; exit 1' ERR

# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

ARQUIVO_LISTA="$_XENPATH/xenbackup-list.txt"
TMP=$(mktemp)
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

# Pergunta ao usuário
clear
$_XENPATH/cabecalho.sh "Criar ou editar as VMs para backup" "off";
echo "Deseja gerar a lista de VMs para backup?"
echo "1 - Criar nova lista com VMs locais ($MOUNT_LOCAL)"
echo "2 - Criar nova lista com VMs remotas (nfs:$NFS_SERVER_IP@$NFS_SERVER_PATH)"
echo "3 - Editar lista atual ($_XENPATH/xenbackup-list.txt)"
read -rp "Escolha uma opção (1-3): " OPCAO
case "$OPCAO" in
  1) DESTINO="$MOUNT_LOCAL" ;;  
  2) DESTINO="nfs:$NFS_SERVER_IP@$NFS_SERVER_PATH" ;;  
  3) nano "$ARQUIVO_LISTA"; exit 0 ;;  
  *) echo "❌ Opção inválida. Cancelando."; exit 1 ;;  
esac

echo "🔍 Coletando VMs disponíveis..."
# Extrai UUID e name-label
xe vm-list is-control-domain=false is-a-template=false params=uuid,name-label > "$TMP"
declare -a VM_HOST_PAIRS=()
# Inicializa variáveis para evitar unbound errors
uuid=""
name=""
host_uuid=""
host=""
while IFS= read -r line; do
  # Se linha vazia, limpa variáveis e continua
  if [[ -z "$line" ]]; then
    uuid=""; name=""; host_uuid=""; host=""
    continue
  fi

  if [[ "$line" =~ ^uuid ]]; then
    uuid=${line##*: }
    # Valida o formato do UUID: não deve conter espaços
    if [[ "$uuid" == *" "* ]]; then
      uuid=""
    fi
  elif [[ "$line" =~ name-label ]]; then
    name=${line##*: }
    # Somente processa se tiver UUID e nome válidos
    if [[ -n "${uuid:-}" && -n "${name:-}" ]]; then
      # Obtém host onde a VM reside
      host_uuid=$(xe vm-param-get uuid="$uuid" param-name=resident-on)
      # Valida o formato de host_uuid: não deve conter espaços
      if [[ "$host_uuid" == *" "* ]]; then
        host_uuid=""
      fi
      # Se host_uuid válido, obtém o name-label do host
      if [[ -n "$host_uuid" ]]; then
        host=$(xe host-param-get uuid="$host_uuid" param-name=name-label)
      fi
      # Adiciona apenas entradas completas
      if [[ -n "${host:-}" && -n "${name:-}" ]]; then
        VM_HOST_PAIRS+=("$name;$host")
      fi
    fi
  fi
done < "$TMP"

# Gera arquivo de lista comentada
echo "#" > "$ARQUIVO_LISTA"
echo "# Descomente as linhas de backup que lhe interessem:" >> "$ARQUIVO_LISTA"
echo "#" >> "$ARQUIVO_LISTA"
for pair in "${VM_HOST_PAIRS[@]}"; do
  IFS=';' read -r vm host <<< "$pair"
  echo "#${vm} ${DESTINO}  #${host}" >> "$ARQUIVO_LISTA"
done

chmod 600 "$ARQUIVO_LISTA"
echo "✅ Lista gerada com sucesso em: $ARQUIVO_LISTA"
nano "$ARQUIVO_LISTA" 
