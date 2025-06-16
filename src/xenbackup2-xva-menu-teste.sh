#!/bin/bash
# Script: xenbackup2-xva-teste.sh
# Objetivo: Interface de seleção de arquivos .xva e chamada ao validador
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

VALIDADOR="$_XENPATH/xenbackup2-xva-teste-midia.sh"

DEVICE=$(blkid -o device -t LABEL="xenbackup")
if [ -z "$DEVICE" ]; then
  echo "💾 Disco com label 'xenbackup' não encontrado. Insira o disco e pressione ENTER para continuar..."
  read
  DEVICE=$(blkid -o device -t LABEL="xenbackup")
  if [ -z "$DEVICE" ]; then
    echo "❌ Disco ainda não encontrado. Encerrando."
    exit 1
  fi
fi

if ! mountpoint -q "$MOUNT_LOCAL"; then
  mkdir -p "$MOUNT_LOCAL"
  mount "$DEVICE" "$MOUNT_LOCAL"
  if [ $? -ne 0 ]; then
    echo "❌ Falha ao montar $DEVICE em $MOUNT_LOCAL"
    exit 2
  fi
fi

$_XENPATH/cabecalho.sh "Testar arquivo de backup xva" "off";

echo "🔍 Listando os 18 arquivos .xva mais recentes em $MOUNT_LOCAL..."
mapfile -t XVA_FILES < <(find "$MOUNT_LOCAL" -type f -name "*.xva" -printf "%T@ %p\n" | sort -nr | head -n 18 | cut -d' ' -f2-)

if [ ${#XVA_FILES[@]} -eq 0 ]; then
  echo "⚠️ Nenhum arquivo .xva encontrado."
  exit 3
fi

for i in "${!XVA_FILES[@]}"; do
  echo "$((i+1)). ${XVA_FILES[$i]}"
done

echo -n "Digite o número do arquivo que deseja testar ou 'X' para informar o caminho manualmente: "
read ESCOLHA

if [[ "$ESCOLHA" =~ ^[Xx]$ ]]; then
  read -p "Informe o caminho completo para o arquivo .xva: " ARQUIVO_XVA
else
  INDEX=$((ESCOLHA-1))
  ARQUIVO_XVA="${XVA_FILES[$INDEX]}"
fi

if [ ! -f "$ARQUIVO_XVA" ]; then
  echo "❌ Arquivo não encontrado: $ARQUIVO_XVA"
  exit 4
fi

read -p "Deseja que eu verifique este arquivo com importação real? (S/n): " RESP
RESP=${RESP,,}
if [ "$RESP" = "n" ]; then
  echo "🚫 Verificação cancelada."
  exit 0
fi

# Chama o validador externo
$VALIDADOR "$ARQUIVO_XVA"
RET=$?

if [ $RET -eq 0 ]; then
  echo "✅ Arquivo testado com sucesso."
else
  echo "❌ Falha na validação do arquivo."
fi
