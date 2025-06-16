#!/bin/bash
# Programa: xenbackup2.sh
# Objetivo: Fazer backup de VMs para um disco local ou unidade NFS na rede
# Data: 15/05/2025
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>

# ============================
# CONFIGURAÇÕES INICIAIS
# ============================
# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

COMPRIMIR_BACKUP=true
TESTAR_BACKUP=true
PROGRAMA_XVA_TESTE_MIDIA=$_XENPATH/xenbackup2-xva-teste-midia.sh
PROGRAMA_LIMPAR_MEDIA=$_XENPATH/xenbackup2-clean.sh
BACKUP_TRANSFERIDO=false
# se estivermos durante o expediene entao desligamos a opcao
# de compressao e teste.
HORA_AGORA=$(date +%H)
if [ "$HORA_AGORA" -ge 6 ] && [ "$HORA_AGORA" -lt 18 ]; then
  COMPRIMIR_BACKUP=false
  TESTAR_BACKUP=false
fi

SNAP_UUID=""
MOUNT_LOCAL=""
AUTO_UNMOUNT="0"
DATA_ATUAL=$(date '+%F-%Hh%M')
LOG_TEMP="/tmp/backup_${1}_$$.log"
exec > >(tee "$LOG_TEMP") 2>&1

# ============================
# FUNÇÕES AUXILIARES
# ============================
listar_vms() {
  xe vm-list is-control-domain=false is-a-template=false \
     | grep "name-label" | awk -F": " '{print $2}'
}

enviar_email() {
  local status="$1"
  local assunto="$2"
  local corpo="$3"
  local destinatarios="$4"
  echo -e "$corpo" | mail -s "$assunto" $destinatarios
}

cleanup() {
  echo "⚠️ Interrupção detectada. Limpando..."
  if [ -n "$SNAP_UUID" ] ; then
    xe snapshot-uninstall snapshot-uuid="$SNAP_UUID" force=true
    if [ $? -eq 0 ]; then
      SNAP_UUID=""
    fi
  fi  
  [ "$AUTO_UNMOUNT" = "1" -a -n "$MOUNT_LOCAL" ] && {
    echo "🔌 Desmontando $MOUNT_LOCAL"
    umount "$MOUNT_LOCAL" && rmdir "$MOUNT_LOCAL"
  }
  MENSAGEM=$(<"$LOG_TEMP")
  enviar_email "falha" "[falha] Backup interrompido: $VM_NAME - $DATA_ATUAL" \
                "$MENSAGEM" "$EMAILS_FAIL"
  rm -f "$LOG_TEMP"
  exit 99
}

trap cleanup INT TERM

# ============================
# PARÂMETROS
# ============================
if [ -z "${1:-}" ]; then
  echo "Uso: $0 <NOME_DA_VM> [DESTINO]"
  echo "Exemplo NFS: $0 Linux_QProxy nfs:$NFS_SERVER_IP@$NFS_SERVER_PATH"
  echo "Exemplo local: $0 Linux_QProxy $MOUNT_LOCAL"
  listar_vms
  exit 1
fi

VM_NAME="$1"
DESTINO_PARAM="$NFS_SERVER_IP@$NFS_SERVER_PATH"

# Determina DATA (já com hora e minuto)
DATA_ATUAL=$(date '+%F-%Hh%M')

# ============================
# DESTINO (NFS ou local)
# ============================
if [[ "$DESTINO_PARAM" == nfs:*@* ]]; then
  NFS_IP="$NFS_SERVER_IP"
  NFS_IP="${NFS_IP%@*}"
  NFS_PATH="${DESTINO_PARAM#*@}"
  MOUNT_LOCAL="/mnt/nfs-${NFS_IP}"
  echo "🔗 Montando NFS ${NFS_IP}:${NFS_PATH} em $MOUNT_LOCAL..."
  if [ ! -d "$MOUNT_LOCAL" ]; then
    echo "Criando ponto de montagem: $MOUNT_LOCAL"
    if [ ! -d "$MOUNT_LOCAL" ]; then
      mkdir -p "$MOUNT_LOCAL" || {
        echo "Erro ao criar diretório $MOUNT_LOCAL"
        exit 1
      }
    fi
  fi
  mount -t nfs "${NFS_IP}:${NFS_PATH}" "$MOUNT_LOCAL"
  if [ $? -ne 0 ]; then
    MENSAGEM=$(<"$LOG_TEMP")
    enviar_email "falha" "[falha] NFS não montado: $VM_NAME - $DATA_ATUAL" \
                  "$MENSAGEM" "$EMAILS_FAIL"
    rm -f "$LOG_TEMP"
    exit 2
  fi
  DESTINO_FINAL="${MOUNT_LOCAL}/${VM_NAME}/${DATA_ATUAL}"
  AUTO_UNMOUNT=1
else
  DESTINO_FINAL="${DESTINO_PARAM}/${VM_NAME}/${DATA_ATUAL}"
  AUTO_UNMOUNT=0
  MOUNT_LOCAL="${DESTINO_PARAM}"
fi

ARQUIVO_FINAL="${VM_NAME}_backup_${DATA_ATUAL}.xva"
ARQUIVO_FULL="${DESTINO_FINAL}/${ARQUIVO_FINAL}"
SCRIPT_RESTORE="restore_vm-${VM_NAME}.sh"

# ============================
# VERIFICAÇÕES INICIAIS
# ============================
if [ ! -d "$DESTINO_FINAL" ]; then
  echo "Criando pasta: $DESTINO_FINAL"
  mkdir -p "$DESTINO_FINAL" 
  if [ ! -d "$DESTINO_FINAL" ]; then
    echo "Erro ao criar diretório $DESTINO_FINAL"
    exit 1
  else
    chmod 777 "$DESTINO_FINAL"
  fi
fi

touch "$DESTINO_FINAL/.teste_write" && rm -f "$DESTINO_FINAL/.teste_write"
if [ $? -ne 0 ]; then
  MENSAGEM=$(<"$LOG_TEMP")
  enviar_email "falha" "[falha] Falha ao escrever em $DESTINO_FINAL: $VM_NAME" \
                "$MENSAGEM" "$EMAILS_FAIL"
  [ "$AUTO_UNMOUNT" = 1 ] && { umount "$MOUNT_LOCAL"; rmdir "$MOUNT_LOCAL"; }
  rm -f "$LOG_TEMP"
  exit 3
fi

# ============================
# CHECK ESPAÇO LIVRE X TAMANHO DA VM
# ============================

# 1) Obtém tamanho total dos discos da VM (bytes)
# Obtém o tamanho total dos discos da VM (em bytes)
VM_UUID=$(xe vm-list name-label="$VM_NAME" --minimal)
VBD_UUIDS=$(xe vbd-list vm-uuid="$VM_UUID" type=Disk --minimal | tr ',' '\n')

VM_SIZE_BYTES=0
for VBD_UUID in $VBD_UUIDS; do
  VDI_UUID=$(xe vbd-param-get uuid=$VBD_UUID param-name=vdi-uuid)
  SIZE=$(xe vdi-param-get uuid=$VDI_UUID param-name=virtual-size)
  VM_SIZE_BYTES=$((VM_SIZE_BYTES + SIZE))
done

# 2) Espaço livre na partição de destino (em blocos de 1K)
if [ -z "$MOUNT_LOCAL" ]; then
  echo "❌ Erro interno: variável MOUNT_LOCAL não definida."
  exit 98
fi

FREE_KB=$(df -Pk "$MOUNT_LOCAL" | tail -1 | awk '{print $4}')
FREE_BYTES=$(( FREE_KB * 1024 ))
FREE_GB=$(( FREE_BYTES / 1073741824 ))

echo "🛈 VM ocupa aproximadamente $(echo "scale=2; $VM_SIZE_BYTES/1073741824" | bc) GB ($VM_SIZE_BYTES bytes)"
echo "🛈 Espaço livre em $MOUNT_LOCAL: $FREE_GB"
echo "🛈 Compressão ligada: $COMPRIMIR_BACKUP"
echo "🛈 Testar arquivo de backup: $TESTAR_BACKUP"

if [ "$FREE_BYTES" -lt "$VM_SIZE_BYTES" ]; then
  echo "⚠️ Espaço insuficiente. Rodando limpeza, liberando espaço..."
  "$PROGRAMA_LIMPAR_MEDIA" "$MOUNT_LOCAL"
  # Recalcula
  FREE_KB=$(df -Pk "$MOUNT_LOCAL" | tail -1 | awk '{print $4}')
  FREE_BYTES=$(( FREE_KB * 1024 ))
  FREE_GB=$(( FREE_BYTES / 1073741824 ))
  echo "🔍 Após limpeza: $FREE_GB GB livres"
  if [ "$FREE_BYTES" -lt "$VM_SIZE_BYTES" ]; then
    echo "❌ Ainda insuficiente. Cancelando backup."
    MENSAGEM=$(<"$LOG_TEMP")
    enviar_email "falha" "[falha] Espaço insuficiente após limpeza: $VM_NAME" \
                  "$MENSAGEM" "$EMAILS_FAIL"
    [ "$AUTO_UNMOUNT" = 1 ] && { umount "$MOUNT_LOCAL"; rmdir "$MOUNT_LOCAL"; }
    rm -f "$LOG_TEMP"
    exit 4
  fi
fi

# ============================
# CRIA SNAPSHOT
# ============================
echo "📸 Criando snapshot da VM '$VM_NAME'..."
SNAP_UUID=$(xe vm-snapshot vm="$VM_NAME" new-name-label="${VM_NAME}_backup_${DATA_ATUAL}")
if [ -z "$SNAP_UUID" ]; then
  MENSAGEM=$(<"$LOG_TEMP")
  enviar_email "falha" "[falha] Erro ao criar snapshot: $VM_NAME" \
                "$MENSAGEM" "$EMAILS_FAIL"
  [ "$AUTO_UNMOUNT" = 1 ] && { umount "$MOUNT_LOCAL"; rmdir "$MOUNT_LOCAL"; }
  rm -f "$LOG_TEMP"
  exit 5
fi
xe template-param-set is-a-template=false ha-always-run=false uuid="$SNAP_UUID"

# ============================
# EXPORTA VM PARA O DESTINO
# ============================
echo "⌛ Início da exportação: $(date '+%F %T')"
if [ -z "$DESTINO_FINAL" ]; then
  echo "❌ Erro interno: variável DESTINO_FINAL não definida."
  exit 99
fi

ESPACO_LIVRE_ANTES=0
if [ -d "$MOUNT_LOCAL" ]; then
  ESPACO_LIVRE_ANTES=$(df -Pk "$MOUNT_LOCAL" | tail -1 | awk '{print $4}')
  ESPACO_LIVRE_ANTES_GB=$(df -h "$MOUNT_LOCAL" | awk 'NR==2 {print $4}')
fi

echo "📦 Exportando VM para $ARQUIVO_FULL..."
if [ "$COMPRIMIR_BACKUP" = "true" ]; then
  echo "🛈 Compressão ligada: $COMPRIMIR_BACKUP, comprimindo..."
  xe vm-export vm="$SNAP_UUID" filename="$ARQUIVO_FULL" --compress &
else
  echo "🛈 Compressão ligada: $COMPRIMIR_BACKUP, ignorando compressão..."
  xe vm-export vm="$SNAP_UUID" filename="$ARQUIVO_FULL" &
fi
XPID=$!

# Monitoramento do tamanho do arquivo exportado
while kill -0 $XPID 2>/dev/null; do
  if [ -f "$ARQUIVO_FULL" ]; then
    TAMANHO="?"
    if [ -f "$ARQUIVO_FULL" ]; then
      TAMANHO=$(du -b "$ARQUIVO_FULL" | cut -f1)
    fi
    echo "📈 Tamanho atual do export: $(echo "scale=2; $TAMANHO/1073741824" | bc) GB"
  else
    echo "⌛ Aguardando criação do arquivo..."
  fi
  sleep 10
done

wait $XPID
echo "✅ Exportação concluída."
EXPORT_RESULT=$?
echo "✅ Fim da exportação: $(date '+%F %T')"

if [ -f "$ARQUIVO_FULL" ]; then
  BACKUP_TRANSFERIDO=true
  chmod 666 "$ARQUIVO_FULL"
  echo "🔍 Testar arquivo de backup: $TESTAR_BACKUP"
  if [ "$TESTAR_BACKUP" = "true" ] ; then
    echo "$PROGRAMA_XVA_TESTE_MIDIA" "$ARQUIVO_FULL"
    "$PROGRAMA_XVA_TESTE_MIDIA" "$ARQUIVO_FULL" 
    if [ $? -eq 0 ]; then
      echo "✅ Backup validado com sucesso."
    else
      echo "❌ Erro: Backup inválido. O arquivo .xva está corrompido ou incompleto!"
      MENSAGEM=$(<"$LOG_TEMP")
      enviar_email "falha" "[falha] Erro no teste de backup: $VM_NAME - $DATA_ATUAL" "$MENSAGEM" "$EMAILS_FAIL"
      exit 96
    fi
  else
    echo "🛈 Opção de teste de arquivo de backup esta desligado. Ignorando..."  
  fi
else
  echo "❌ Erro: Arquivo de backup $ARQUIVO_FULL não foi criado!"
  MENSAGEM=$(<"$LOG_TEMP")
  enviar_email "falha" "[falha] Arquivo ausente: $VM_NAME - $DATA_ATUAL" "$MENSAGEM" "$EMAILS_FAIL"
  exit 97
fi

if [ $EXPORT_RESULT -ne 0 ]; then 
  MENSAGEM=$(<"$LOG_TEMP")
  enviar_email "falha" "[falha] Erro na exportação: $VM_NAME" \
                "$MENSAGEM" "$EMAILS_FAIL"
  [ "$AUTO_UNMOUNT" = 1 ] && { umount "$MOUNT_LOCAL"; rmdir "$MOUNT_LOCAL"; }
  rm -f "$LOG_TEMP"
  exit 6
fi

# ============================
# CRIA SCRIPT DE RESTAURAÇÃO
# ============================
cat <<EOF > "${DESTINO_FINAL}/${SCRIPT_RESTORE}"
#!/bin/bash
VM_ORIGINAL="${VM_NAME}"
ARQUIVO_BACKUP="${ARQUIVO_FINAL}"
VM_BACKUP_NOME="\${VM_ORIGINAL}_backup_${DATA_ATUAL}"

echo "🌀 Restaurando VM '\$VM_ORIGINAL'..."
EXISTE=\$(xe vm-list --minimal name-label="\$VM_ORIGINAL")
[ -n "\$EXISTE" ] && { echo "❌ VM '\$VM_ORIGINAL' já existe. Cancelando."; exit 1; }

xe vm-import filename="\$ARQUIVO_BACKUP"
UUID=\$(xe vm-list --minimal name-label="\$VM_BACKUP_NOME")
[ -n "\$UUID" ] && xe vm-param-set uuid="\$UUID" name-label="\$VM_ORIGINAL"
echo "✅ Restauração concluída."
EOF

if [ -f "${DESTINO_FINAL}/${SCRIPT_RESTORE}" ] ; then
  chmod +x "${DESTINO_FINAL}/${SCRIPT_RESTORE}"
fi

# ============================
# FINALIZAÇÃO
# ============================

# Calcula tamanho e hash
BACKUP_TAMANHO=""
BACKUP_MD5_HASH=""

if [ -f "$ARQUIVO_FULL" ]; then
  BACKUP_TAMANHO=$(du -h "$ARQUIVO_FULL" | awk '{print $1}')
  BACKUP_MD5_HASH=$(md5sum "$ARQUIVO_FULL" | awk '{print $1}')
  if [ ! -z "$BACKUP_MD5_HASH" ] ; then
    echo "${ARQUIVO_FINAL} ${BACKUP_MD5_HASH}">$ARQUIVO_FULL.md5sum
  fi  
fi

# Calcular espaço livre no destino
ESPACO_LIVRE_DEPOIS=""
if mountpoint -q "$MOUNT_LOCAL"; then
  ESPACO_LIVRE_DEPOIS=$(df -h "$MOUNT_LOCAL" | awk 'NR==2 {print $4}')
fi

MENSAGEM="Backup da VM $VM_NAME concluído com sucesso em $(date '+%d/%m/%Y %H:%M').

Arquivo: $ARQUIVO_FULL
Tamanho: $BACKUP_TAMANHO
Hash MD5: $BACKUP_MD5_HASH
Script de restauração: ${DESTINO_FINAL}/${SCRIPT_RESTORE}

Espaço livre antes do backup: $ESPACO_LIVRE_ANTES_GB
Espaço livre após backup: $ESPACO_LIVRE_DEPOIS

Este é um e-mail automático."

# Atualizar conteúdo do e-mail de sucesso com essas variáveis


# Destruir o snapshot após sucesso
if [ -n "$SNAP_UUID" ] ; then
   xe snapshot-uninstall snapshot-uuid="$SNAP_UUID" force=true
   if [ $? -eq 0 ]; then
     SNAP_UUID=""
   fi
fi

enviar_email "sucesso" "[sucesso] Backup concluído: $VM_NAME - $DATA_ATUAL" \
              "$MENSAGEM" "$EMAILS_OK"

rm -f "$LOG_TEMP"

if [ "$AUTO_UNMOUNT" = 1 ]; then
  umount "$MOUNT_LOCAL"
  rmdir "$MOUNT_LOCAL"
fi

echo "✅ Backup da VM '$VM_NAME' concluído com sucesso!"
