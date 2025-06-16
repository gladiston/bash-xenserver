#!/bin/bash
# Programa: xenmenu.sh
# Objetivo: Menu para uma série de operações com o servidor XEN
# Criacão: 15/05/2025
# Atualização: 23/05/2025
# Autor: Gladiston Santana <gladiston.santana[em]gmail.com>

#
# Funcoes
#

executar_script() {
  local script="$1"
  if [ -x "$script" ]; then
    sudo "$script"
  else
    echo "❌ Script não encontrado: $script"
  fi
}

pausar() {
  read -p "Pressione ENTER para continuar..."
}


#
# Inicio do Script
#
# CARREGAR ARQUIVO DE CONFIGURAÇÃO

CONF_FILE="/etc/xenbackup2.conf"
if [ ! -f "$CONF_FILE" ]; then
  echo '# Onde estao os scripts para o xen' >"$CONF_FILE"
  echo '_XENPATH=/root' >>"$CONF_FILE"
  echo '# Quando gerar SUCESSO para quem devo enviar uma notificação por email:' >>"$CONF_FILE"
  echo 'EMAILS_OK="ficticio-ok1@exemplo.com.br ficticio-ok2@exemplo.com.br"' >> "$CONF_FILE"
  echo '# Quando gerar FALHA para quem devo enviar uma notificação por email:' >>"$CONF_FILE"
  echo 'EMAILS_FAIL="ficticio-fail1@exemplo.com.br ficticio-fail2@exemplo.com.br"' >> "$CONF_FILE"
  echo '# Dominio padrao para e-mails quando omitido' >> "$CONF_FILE"
  echo 'EMAILS_DOMAIN="exemplo.com.br"' >> "$CONF_FILE"
  echo '# Pasta para preferir as montagens de discos de backup:' >>"$CONF_FILE"
  echo 'MOUNT_LOCAL="/mnt/xenbackup"' >>"$CONF_FILE"
  echo '# No Backup quantos dias serão retidos' >>"$CONF_FILE"
  echo 'RETAIN_DAYS=10' >>"$CONF_FILE"
  echo '# Manter sempre os ultimos N backups independente da data' >>"$CONF_FILE"
  echo 'KEEP_COUNT=3' >>"$CONF_FILE"  
fi

clear
while :
do
  clear
  $_XENPATH/cabecalho.sh "Servidor $(hostname) - Menu de operações" "off";
  echo "1- Realizar o backup completo agora"
  echo "2- Observar se há backup em andamento"
  echo "3- Observar se a mídia de backup está presente(e desmontar)"
  echo "4- Listar as VMs existentes"
  echo "5- Criar ou editar as VMs para backup"
  echo "6- Testar arquivo de backup xva"
  echo "7- Limpar backups antigos"
  echo "8- Limpar snaphosts"
  echo "9- Adicionar ou corrigir disco de backup"
  echo "10-Relatorio de backup por email"
  echo "11-Montar ou desmontar unidades de backup"  
  echo "12-VMs com inicio automatico apos boot do xenserver"
  echo "13-VMs temporarias usadas por backups"
  echo "90-Testar o acesso a internet"
  echo "91-Testar o envio de email"
  echo "92-Corrigir e atualizar scripts de outros servidores"
  echo "94-Editar configuração"  
  echo "95-Editar agendamentos"
  echo "96-Ver uso de espaço em disco"
  echo "97-Uptime do servidor"
  echo "99-Sair"
  echo -n "Escolha uma opcao [1-99] :"
  read opcao
  case $opcao in
  1)
    executar_script "$_XENPATH/xenbackup2-lista.sh"
    pausar
    ;;
  2)
    executar_script "$_XENPATH/xenbackup2-check-exec.sh"
    pausar
    ;;  
  3)
    executar_script "$_XENPATH/xenbackup2-disco-presente.sh"
    pausar
    ;;
  4)
    executar_script "$_XENPATH/xenbackup2-vms-lista.sh"
    ;;
  5)
    executar_script "$_XENPATH/xenbackup2-gerar-lista.sh"
    pausar
    ;;
  6)
    executar_script "$_XENPATH/xenbackup2-xva-menu-teste.sh"
    ;;
  7)
    executar_script "$_XENPATH/xenbackup2-clean-menu.sh"
    pausar
    ;;
  8)
    executar_script "$_XENPATH/xenbackup2-clean-snaps.sh"
    #pausar
    ;;
  9)
    executar_script "$_XENPATH/xenbackup2-chkdsk.sh"
    pausar
    ;;
  10)
    executar_script "$_XENPATH/xenbackup2-relatorio.sh"
    pausar
    ;;
  11)
    executar_script "$_XENPATH/xenbackup2-montar-unidades.sh"
    pausar
    ;;
  12)
    executar_script "$_XENPATH/xenbackup2-menu-boot.sh"
    ;;
  13)
    executar_script "$_XENPATH/xenbackup2-clean-temp-vm.sh"
    pausar
    ;;
  90)
    executar_script "$_XENPATH/testar_internet_basic.sh"
    pausar
    ;;
  91)$_XENPATH/testar_email.sh;
    pausar
    ;;
  92)
    executar_script "$_XENPATH/update-scripts.sh"
    pausar
    ;;
  94)
    sudo nano /etc/xenbackup2.conf
    ;;
  95)
    sudo crontab -e
    ;;
  96)
    executar_script "$_XENPATH/check_disco.sh"
    ;;
  97)
    bash "$_XENPATH/check_uptime.sh"      
    ;;
  98)
    bash
    ;;
  99)
    exit
    ;;
  *) 
    echo "Opcao invalida !!!"
    echo "Tecle [ENTER] para retornar."
    read espera
    ;;
  esac
done
}



# Fim do Programa
