#!/bin/bash
# xenbackup2-montar-unidades.sh - Monta unidade local ou remota de backup
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Uso: ./xenbackup2-montar-unidades.sh
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

HOSTNAME=$(hostname)
MOUNT_REMOTO="/mnt/nfs-$NFS_SERVER_IP"

$_XENPATH/cabecalho.sh "Montar ou desmontar unidades de backup" "off";
echo "Selecione a opção:"
echo "1) Montar unidade local de backup"
echo "2) Montar unidade remota NFS de backup"
read -p "Opção [1/2]: " OPCAO

if [ "$OPCAO" != "1" ] && [ "$OPCAO" != "2" ]; then
  echo "❌ Nenhuma opção válida selecionada. Encerrando."
  exit 1
fi

if [ "$OPCAO" == "1" ]; then
  echo "Preparando montagem local..."
  PONTO="$MOUNT_LOCAL"
  echo "Procurando dispositivo com LABEL xenbackup..."
  DISPOSITIVO=$(blkid -o device -t LABEL="xenbackup" | head -n 1)
  if [ -z "$DISPOSITIVO" ]; then
    echo "🚫 Dispositivo com LABEL 'xenbackup' não encontrado."
    exit 1
  fi

  echo "Verificando se já está montado..."
  mountpoint -q "$PONTO"
  if [ $? -eq 0 ]; then
    echo "🔍 Ponto já montado: $PONTO"
    echo "📄 Conteúdo montado:"
    mount | grep "on $PONTO"
    read -p "⚠️ Deseja desmontar $PONTO? (s/n): " RESP
    if [[ "$RESP" =~ ^[Ss]$ ]]; then
      umount "$PONTO" && echo "✅ Desmontado."
    fi
  else  
    # conferindo nao esta montado, então monta
    mountpoint -q "$PONTO"
    if [ $? -ne 0 ]; then
      echo "Criando ponto de montagem $PONTO..."
      mkdir -p "$PONTO"
      echo "Montando dispositivo $DISPOSITIVO em $PONTO..."
      if mount "$DISPOSITIVO" "$PONTO"; then
        echo "✅ Unidade local montada em $PONTO"
      else
        echo "❌ Falha ao montar."
      fi
    fi
  fi
elif [ "$OPCAO" == "2" ]; then
  echo "Preparando montagem remota..."
  PONTO="$MOUNT_REMOTO"
  echo "Verificando se já está montado..."
  mountpoint -q "$PONTO"
  if [ $? -eq 0 ]; then
    echo "🔍 Ponto já montado: $PONTO"
    echo "📄 Conteúdo montado:"
    mount | grep "on $PONTO"
    read -p "⚠️ Deseja desmontar $PONTO? (s/n): " RESP
    if [[ "$RESP" =~ ^[Ss]$ ]]; then
      umount "$PONTO" && rmdir "$PONTO" && echo "✅ Desmontado."
    fi
  else
    # conferindo se já esta montado, se nao esta, então monta
    mountpoint -q "$PONTO"
    if [ $? -ne 0 ]; then
      echo "Criando ponto de montagem $PONTO..."
      mkdir -p "$PONTO"
      echo "Montando NFS $NFS_SERVER_IP:$NFS_SERVER_PATH em $PONTO..."
      if mount -t nfs "$NFS_SERVER_IP:$NFS_SERVER_PATH" "$PONTO"; then
        echo "✅ Unidade remota montada em $PONTO"
      else
        echo "❌ Falha ao montar."
      fi
    fi
  fi
fi

# Se esta montado entao mostra um meio de acesso via sftp
mountpoint -q "$PONTO"
if [ $? -eq 0 ]; then
    $_XENPATH/cabecalho.sh "Acesso SFTP: sftp://$HOSTNAME/$PONTO" "off";
fi