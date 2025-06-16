#!/bin/bash
#===============================================================================
# Script: xenbackup2-menu-boot.sh
# Autor: Gladiston Santana <gladiston.santana[ARROBA]gmail.com>
# Data : 16/05/2025
# Descrição: Lista as VMs no XenServer e permite alternar o estado de
#            inicialização automática (auto_poweron) de forma interativa.
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

while true; do
  echo "📋 Listando VMs e status de boot automático..."

  # Prepara arrays
  VM_UUIDS=()
  VM_LABELS=()

  # Lista todas as VMs e armazena apenas UUIDs válidos
  while IFS= read -r uuid; do
    if [[ "$uuid" =~ ^[a-f0-9-]{36}$ ]]; then
      label=$(xe vm-param-get uuid="$uuid" param-name=name-label)
      VM_UUIDS+=("$uuid")
      VM_LABELS+=("$label")
    fi
  done < <(xe vm-list is-control-domain=false is-a-template=false params=uuid --minimal | tr ',' '\n')

  # Exibe menu
  clear
  $_XENPATH/cabecalho.sh "Lista de VMs" "off";  
  for i in "${!VM_UUIDS[@]}"; do
    uuid="${VM_UUIDS[$i]}"
    label="${VM_LABELS[$i]}"
    autostart=$(xe vm-param-get uuid="$uuid" param-name=other-config param-key=auto_poweron 2>/dev/null)
    status="desligado"
    if [ "$autostart" = "true" ]; then
      status="ligado"
    fi
    printf "%2d. %s : %s\n" "$((i + 1))" "$label" "$status"
  done

  echo " X. Sair"
  echo
  read -rp "Digite o número da VM para alternar auto-start (ou X para sair): " opcao

  if [[ "$opcao" =~ ^[Xx]$ ]]; then
    echo "Encerrando script."
    exit 0
  fi

  # Verifica se é número válido
  if [[ "$opcao" =~ ^[0-9]+$ ]] && [ "$opcao" -ge 1 ] && [ "$opcao" -le "${#VM_UUIDS[@]}" ]; then
    idx=$((opcao - 1))
    uuid="${VM_UUIDS[$idx]}"
    label="${VM_LABELS[$idx]}"
    autostart=$(xe vm-param-get uuid="$uuid" param-name=other-config param-key=auto_poweron 2>/dev/null)

    if [ "$autostart" = "true" ]; then
      novo_status="desligar"
    else
      novo_status="ligar"
    fi

    echo
    read -rp "Tem certeza que deseja $novo_status o auto-start da VM '$label'? (s/N): " confirma
    confirma="${confirma,,}"

    if [[ "$confirma" == "s" ]]; then
      if [ "$autostart" = "true" ]; then
        xe vm-param-remove uuid="$uuid" param-name=other-config param-key=auto_poweron
        echo "Auto-start de '$label' foi DESLIGADO com sucesso."
      else
        xe vm-param-set uuid="$uuid" other-config:auto_poweron=true
        echo "Auto-start de '$label' foi LIGADO com sucesso."
      fi
    else
      echo "Ação cancelada."
    fi
  else
    echo "Opção inválida. Tente novamente."
  fi
done
