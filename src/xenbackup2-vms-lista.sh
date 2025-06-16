#!/bin/bash
#===============================================================================
# Script: xenbackup2-vms-lista.sh
# Autor: Gladiston Santana <gladiston.santana[ARROBA]gmail.com>
# Data : 16/05/2025
# Descrição: Lista as VMs do XenServer com status de auto-start e tamanho total
#            dos discos virtuais (em GB), de forma clara e formatada.
# Licença: Este script é de uso restrito e não pode ser redistribuído
#          sem autorização prévia e por escrito do autor.
#===============================================================================
# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

# Verifica se o comando 'xe' está disponível
if ! command -v xe >/dev/null; then
  echo "Erro: o comando 'xe' não foi encontrado. Você está rodando este script no XenServer?"
  exit 1
fi

clear
$_XENPATH/cabecalho.sh "Lista de VMs no Pool" "off";

# Inicializa contador de exibição
index=1

# Lista todas as VMs válidas
while IFS= read -r uuid; do
  # Verifica se é UUID válido
  if [[ "$uuid" =~ ^[a-f0-9-]{36}$ ]]; then
    label=$(xe vm-param-get uuid="$uuid" param-name=name-label)

    # Verifica se auto_poweron está ativo
    autostart=$(xe vm-param-get uuid="$uuid" param-name=other-config param-key=auto_poweron 2>/dev/null)
    status="desligado"
    if [ "$autostart" = "true" ]; then
      status="ligado"
    fi

    # Soma o tamanho total dos discos
    total_bytes=0
    while IFS= read -r vbd_uuid; do
      if [[ "$vbd_uuid" =~ ^[a-f0-9-]{36}$ ]]; then
        vdi_uuid=$(xe vbd-param-get uuid="$vbd_uuid" param-name=vdi-uuid 2>/dev/null)
        if [[ "$vdi_uuid" =~ ^[a-f0-9-]{36}$ ]]; then
          vdi_size=$(xe vdi-param-get uuid="$vdi_uuid" param-name=virtual-size 2>/dev/null)
          total_bytes=$((total_bytes + vdi_size))
        fi
      fi
    done < <(xe vbd-list vm-uuid="$uuid" type=Disk --minimal | tr ',' '\n')

    tamanho_gb=$(( (total_bytes + 1073741823) / 1073741824 )) # arredonda pra cima

    printf " %2d. %s : %s [%dGB]\n" "$index" "$label" "$status" "$tamanho_gb"
    index=$((index + 1))
  fi
done < <(xe vm-list is-control-domain=false is-a-template=false params=uuid --minimal | tr ',' '\n')

echo
read -rp "Pressione [ENTER] para encerrar..."
