#!/bin/bash
# cabecalho.sh - Menu interativo para administrar o servidor Postfix
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>
# Uso: Cabeçalho padrão com informações do servidor para scripts Postfix
# Licença: Uso interno. Proibida a reprodução sem autorização prévia por escrito.
# Criado em: 2025-05-21
# Ult. Atualização: 2025-05-23

imprimir_titulo() {
  local titulo="$1"
  local largura=60
  local borda_superior=$(printf '═%.0s' $(seq 1 $((largura - 2))))
  local borda_lateral="║"
  local comprimento=${#titulo}
  local espacos=$(( (largura - 2 - comprimento) / 2 ))
  local resto=$(( (largura - 2 - comprimento) % 2 ))
  local linha=$(printf "%${espacos}s%s%$((espacos + resto))s" "" "$titulo" "")

  echo "╔$borda_superior╗"
  echo "$borda_lateral$linha$borda_lateral"
  echo "╚$borda_superior╝"
}

#clear
TITULO="$1"
if [ -z "$TITULO" ] ; then
  TITULO="Conferencia de servidor em uso"
fi

imprimir_titulo "$TITULO"
if [ "$2" == "off" ] ; then
  exit 0;
fi
echo "📌 Servidor: $(hostname)"
echo "🌐 IP: $(hostname -I | cut -d' ' -f1)"

# Informações de memória com ambiente padronizado
read -r MEM_TOTAL MEM_USADA <<< $(LC_ALL=C free -m | awk '/^Mem:/ {print $2, $3}')
echo "💾 Memória usada: $MEM_USADA MiB / $MEM_TOTAL MiB"

# Uptime formatado
UP=$(uptime)
HORA_ATUAL=$(date +%H:%M:%S)
TEMPO_UP=$(echo "$UP" | sed -E 's/^.*up (.*), +[0-9]+ user.*/\1/' | cut -d',' -f1-2)
USUARIOS=$(echo "$UP" | sed -E 's/^.* ([0-9]+) users?.*/\1/')
LOADAVG=$(echo "$UP" | awk -F'load average: ' '{print $2}')

echo "⏱ Hora atual: $HORA_ATUAL"
echo "🔌 Tempo no ar: $TEMPO_UP"
echo "👥 Usuários conectados: $USUARIOS"
echo "📈 Carga média (1m, 5m, 15m): $LOADAVG"
echo "════════════════════════════════════════════════════════════"
