#!/bin/bash
# Este script copia os arquivos em /root que são scripts administrativos
# para um local mais adequado
if [ ! "$USER" = "root" ] ; then
  echo "Script para ser usado apenas pelo usuario root."
  exit 2
fi
echo "Modificando permissoes de arquivos em /root"
chmod a+x -vR /root/*.sh
chmod 664 -vR /root/*.txt
echo "Preparando o menu principal /usr/bin/menuasroot.sh"
cp /root/menuasroot.sh /usr/bin/menuasroot.sh
chmod a+x /usr/bin/menuasroot.sh
echo "Criando alguns links simbolicos em /usr/bin"

! [ -f /usr/bin/xenmenu.sh ] && ln -s /root/xenmenu.sh /usr/bin/xenmenu.sh
! [ -f /usr/bin/xenbackup.sh ] && ln -s /root/xenbackup.sh /usr/bin/xenbackup.sh
! [ -f /usr/bin/xenbackup-status.sh ] && ln -s /root/xenbackup-status.sh /usr/bin/xenbackup-status.sh
! [ -f /usr/bin/xenbackup-chkdsk.sh ] && ln -s /root/xenbackup-chkdsk.sh /usr/bin/xenbackup-chkdsk.sh
! [ -f /usr/bin/xenbackup-all.sh ] && ln -s /root/xenbackup.sh /usr/bin/xenbackup-all.sh
! [ -f /usr/bin/xenbackup-estimate.sh ] && ln -s /root/xenbackup-estimate.sh /usr/bin/xenbackup-estimate.sh
! [ -f /usr/bin/xenbackup-clean.sh ] && ln -s /root/xenbackup-clean.sh /usr/bin/xenbackup-clean.sh
! [ -f /usr/bin/xenbackup-cleansnapshots.sh ] && ln -s /root/xenbackup-cleansnapshots.sh /usr/bin/xenbackup-cleansnapshots.sh
! [ -f /usr/bin/xenrestore.sh ] && ln -s /root/xenrestore.sh /usr/bin/xenrestore.sh
! [ -f /usr/bin/xenstart-on-boot.sh ] && ln -s /root/xenstart-on-boot.sh /usr/bin/xenstart-on-boot.sh
! [ -f /usr/bin/xenupdate.sh ] && ln -s /root/xenupdate.sh /usr/bin/xenupdate.sh
! [ -f /usr/bin/xenvmlist.sh ] && ln -s /root/xenvmlist.sh /usr/bin/xenvmlist.sh
! [ -f /usr/bin/enviar_email_admin.sh ] && ln -s /root/enviar_email_admin.sh /usr/bin/enviar_email_admin.sh
! [ -f /usr/bin/xenbackup2email.sh ] && ln -s /root/xenbackup2email.sh /usr/bin/xenbackup2email.sh

#
#
#
if [ "$HOSTNAME" == "xena" ] ; then
  echo "Atualizando scripts no servidor xenb(192.168.1.4)..."
  scp /root/*.sh root@192.168.1.4:/root
fi

echo "Fim"
