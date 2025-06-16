#!/bin/bash
# Programa: xenbackup2-clean.sh
# Objetivo: Limpar backups antigos baseados em data de modificação,
#           mas garantir sempre os 3 últimos backups de cada conjunto.
#
# Variáveis principais:
# RETAIN_DAYS  - Dias para considerar um arquivo "antigo" e elegível à remoção.
# KEEP_COUNT   - Número mínimo de subpastas datadas de cada conjunto que
#                NUNCA podem ser removidas, mesmo que mais antigas que RETAIN_DAYS.
#
# Regras especiais:
# - Pastas cujo nome começa com "_" ou "$" são totalmente ignoradas.
# - A pasta "lost+found" (ext4) será processada normalmente.
# - Diretórios vazios serão eliminados após remover arquivos.
# - Relatório por e-mail só é enviado se algo for efetivamente removido.
#
# Data: 10/06/2025
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# ============================
# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

IFS=$'\n\t'

declare -a REMOVED_ITEMS=()

_send_report() {
  [ "${#REMOVED_ITEMS[@]}" -eq 0 ] && return 0
  local subject body end
  end=$(date '+%d/%m/%Y %H:%M:%S')
  subject="[sucesso] Limpeza de backups: $BASE_DIR"
  body="Limpeza concluída em $end\nItens removidos (total: ${#REMOVED_ITEMS[@]}):\n"
  for item in "${REMOVED_ITEMS[@]}"; do
    body+="- $item\n"
  done
  body+="\nEspaço FS antes: $DISK_BEFORE"
  body+="\nEspaço FS depois: $DISK_AFTER"
  body+="\nTamanho após: $SIZE_AFTER"
  printf '%b' "$body" | mail -s "$subject" $EMAILS_OK
}

# Validações iniciais
[ $# -eq 1 ] || { echo "Uso: $0 <DIR_BASE>"; exit 1; }
BASE_DIR="$1"
[[ "$BASE_DIR" = /* && -d "$BASE_DIR" ]] || { echo "ERRO: '$BASE_DIR' inválido"; exit 2; }

# Métricas antes
DISK_BEFORE=$(df -h "$BASE_DIR" | awk 'NR==2 {print "Usado: "$3", Disponível: "$4}')
SIZE_BEFORE=$(du -sh "$BASE_DIR" | cut -f1)

echo "🔍 Início: $(date '+%d/%m/%Y %H:%M:%S')"
echo "   Removendo arquivos >${RETAIN_DAYS}d, preservando $KEEP_COUNT últimos"
echo "💾 Espaço FS antes: $DISK_BEFORE"
echo "📦 Tamanho antes: $SIZE_BEFORE"

# Para cada conjunto de backup (subpasta em BASE_DIR)
for conjunto in "$BASE_DIR"/*; do
  [ -d "$conjunto" ] || continue
  name=$(basename "$conjunto")

  # Ignora symlinks e pastas protegidas _* e $*
  if [ -L "$conjunto" ] || [[ "$name" == _* || "$name" == \$* ]]; then
    echo "⏭️  Ignorando: $name"
    continue
  fi

  # Lista subpastas datadas, ordena e guarda as últimas KEEP_COUNT
  mapfile -t all_dirs < <(
    find "$conjunto" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
  )
  KEEP_DIRS=("${all_dirs[@]: -$KEEP_COUNT}")
  echo "📁 Processando conjunto: $name (preservando: ${KEEP_DIRS[*]:-nenhum})"

  if [ "${#KEEP_DIRS[@]}" -gt 0 ]; then
    # Constroi expressão de prune corretamente
    PRUNE_EXPR=()
    for k in "${KEEP_DIRS[@]}"; do
      PRUNE_EXPR+=( -path "$conjunto/$k" -o )
    done
    # Remove o último '-o'
    unset 'PRUNE_EXPR[${#PRUNE_EXPR[@]}-1]'

    # Remove arquivos antigos, exceto dentro de KEEP_DIRS
    while IFS= read -r file; do
      echo "🗑️ Removendo arquivo: $file"
      REMOVED_ITEMS+=("$file")
      rm -f "$file"
    done < <(
      find "$conjunto" \
        \( "${PRUNE_EXPR[@]}" \) -prune -o \
        -type f -mtime +$RETAIN_DAYS -print
    )

    # Remove diretórios vazios, exceto KEEP_DIRS
    while IFS= read -r dir; do
      echo "🗑️ Removendo diretório vazio: $dir"
      REMOVED_ITEMS+=("$dir")
      rmdir "$dir"
    done < <(
      find "$conjunto" \
        \( "${PRUNE_EXPR[@]}" \) -prune -o \
        -type d -empty -print
    )
  else
    # Se não há KEEP_DIRS, limpa todos os arquivos antigos e diretórios vazios
    while IFS= read -r file; do
      echo "🗑️ Removendo arquivo: $file"
      REMOVED_ITEMS+=("$file")
      rm -f "$file"
    done < <(find "$conjunto" -type f -mtime +$RETAIN_DAYS -print)

    while IFS= read -r dir; do
      echo "🗑️ Removendo diretório vazio: $dir"
      REMOVED_ITEMS+=("$dir")
      rmdir "$dir"
    done < <(find "$conjunto" -type d -empty -print)
  fi
done

# Métricas depois
DISK_AFTER=$(df -h "$BASE_DIR" | awk 'NR==2 {print "Usado: "$3", Disponível: "$4}')
SIZE_AFTER=$(du -sh "$BASE_DIR" | cut -f1)

echo "✅ Fim: $(date '+%d/%m/%Y %H:%M:%S')"
echo "💾 Espaço FS depois: $DISK_AFTER"
echo "📦 Tamanho após: $SIZE_AFTER"

_send_report

# Por fim, esvazia lost+found se algo foi removido
if [ "${#REMOVED_ITEMS[@]}" -gt 0 ] && [ -d "$BASE_DIR/lost+found" ]; then
  echo "🧹 Esvaziando lost+found"
  find "$BASE_DIR/lost+found" -mindepth 1 -exec rm -rf {} +
fi

exit 0
