#!/bin/bash
#===============================================================================
# Script: xenbackup2-check-exec.sh
# Autor: Gladiston Santana <gladiston.santana[ARROBA]gmail.com>
# Data : 16/05/2025
# Descrição: Verifica se há uma exportação ativa via xe vm-export, exibe PID e
#            os parâmetros do comando (vm e filename), permite encerrar PID.
#===============================================================================
# CARREGAR ARQUIVO DE CONFIGURAÇÃO
CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo "Falta o arquivo de configuração: $CONF_FILE"
  exit 2;
fi

# carregando o arquivo de configuração dos EMAILS de notificação de sucesso e falha
source "$CONF_FILE"

while true; do
  clear
  $_XENPATH/cabecalho.sh "Verifica se há uma exportação de VM em atividade" "off";  
  # Busca por processos xe com vm-export
  processos=$(ps -eo pid,cmd | grep '[x]e vm-export')

  if [ -n "$processos" ]; then
    echo
    echo "✅ Há exportação de snapshot em andamento:"
    echo

    while IFS= read -r linha; do
      pid=$(echo "$linha" | awk '{print $1}')
      cmd=$(echo "$linha" | cut -d' ' -f2-)

      # Extrai parâmetros vm= e filename= se existirem
      vm=$(echo "$cmd" | grep -oE 'vm="[^"]+"' || echo "vm=<não identificado>")
      filename=$(echo "$cmd" | grep -oE 'filename="[^"]+"' || echo "filename=<não identificado>")

      echo "──────────────────────────────────────────────"
      echo "🔄 PID: $pid"
      echo "🖥️  $vm"
      echo "📁 $filename"
      echo "❌ Para encerrar manualmente:"
      echo "   kill $pid     # Tente isso primeiro"
      echo "   kill -9 $pid  # Use isso apenas se o anterior não funcionar"
      echo
    done <<< "$processos"

    echo -n "Deseja encerrar alguma transferência? Nesse caso, informe o PID (ou pressione ENTER para sair): "
    read pid_informado

    if [ -z "$pid_informado" ]; then
      echo
      echo "Saindo."
      exit 0
    elif [[ "$pid_informado" =~ ^[0-9]+$ ]]; then
      if ps -p "$pid_informado" > /dev/null; then
        echo
        echo "Enviando sinal para encerrar PID $pid_informado..."
        kill "$pid_informado"
        echo
        read -p "Pressione [ENTER] para continuar..."
      else
        echo
        echo "PID $pid_informado não encontrado ou já finalizado."
        read -p "Pressione [ENTER] para continuar..."
      fi
    else
      echo
      echo "Entrada inválida. Digite apenas o número do PID."
      read -p "Pressione [ENTER] para continuar..."
    fi
  else
    echo
    echo "ℹ️  Nenhuma exportação de snapshot (xe vm-export) está em andamento no momento."
    break
  fi
done
