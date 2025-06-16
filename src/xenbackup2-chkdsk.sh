#!/bin/bash
# Script: xenbackup2-chkdsk.sh
# Objetivo: Transformar partições ext2/3/4 não montadas em discos de backup
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Licença: Uso interno. Proibida a reprodução sem autorização prévia por escrito.
# Data: 16/05/2025

listar_particoes_ext_nao_montadas() {
  lsblk -nrpo NAME,FSTYPE,LABEL,TYPE | while read -r DEV FSTYPE LABEL TYPE; do
    if [ "$TYPE" = "part" ] && [[ "$FSTYPE" =~ ext[2-4] ]] && ! mount | grep -q "^$DEV "; then
      echo "$FSTYPE $DEV $LABEL"
    fi
  done
}

# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

$_XENPATH/cabecalho.sh "Criando ou reparando unidade de backup para o xen" "off";

while true; do
  echo "===== Escolha um disco para transformar em disco de backup ====="
  mapfile -t PARTICOES < <(listar_particoes_ext_nao_montadas)

  if [ ${#PARTICOES[@]} -eq 0 ]; then
    echo "❌ Nenhuma partição EXT2/3/4 não montada foi encontrada."
    break
  fi

  for i in "${!PARTICOES[@]}"; do
    PART_INFO=(${PARTICOES[$i]})
    echo "$((i+1)). ${PART_INFO[0]} ${PART_INFO[1]} ${PART_INFO[2]}"
  done
  echo "X. Sair"
  echo "==============================================================="

  read -p "Escolha uma opção: " OPCAO

  if [[ "$OPCAO" =~ ^[Xx]$ ]]; then
    echo "Saindo..."
    break
  elif [[ "$OPCAO" =~ ^[0-9]+$ ]] && [ "$OPCAO" -ge 1 ] && [ "$OPCAO" -le ${#PARTICOES[@]} ]; then
    PART_INFO=(${PARTICOES[$((OPCAO-1))]})
    FSTYPE="${PART_INFO[0]}"
    DEVICE="${PART_INFO[1]}"

    echo "🔧 Aplicando label 'xenbackup' e verificando disco..."
    /sbin/e2label "$DEVICE" xenbackup
    /sbin/fsck -vfy "$DEVICE"
  else
    echo "❌ Opção inválida."
  fi

  echo
done
