#!/bin/bash
# Crie uma conta administrador com grupo 'root':
# useradd administrador -m -g root
# passwd administrador
#
# Acrescente ao arquivo /etc/sudoers
# administrador   ALL=(ALL)       NOPASSWD:ALL
#
# Permissoes em /root
# /root/update-scripts.sh
#
# Depois acrescente no final do /home/administrador/.bashrc
# exec /usr/bin/menuasroot.sh

#
# Inicio do Script
#
ERRO=0
if [ -f /root/xenmenu.sh ] ; then
  sudo /root/xenmenu.sh
  [ $? -gt 0 ] && ERRO=1
else
  echo "Arquivo não encontrado:"
  echo /root/xenmenu.sh
  ERRO=1
fi
if [ $ERRO -gt 0 ] ; then
  bash --noprofile --norc
fi
