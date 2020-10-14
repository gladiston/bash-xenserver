#!/bin/bash
echo "CentOS Cenario"
echo "1. Habilitar os repositorios em /etc/yum.repos.d/CentOS-Base.repo"
echo "2. Executar este script"
echo "3. Editar o arquivo /etc/ssmtp/ssmtp.conf  e comentar as linhas :"
echo "    #mailhub=mail"
echo "    #rewriteDomain="
echo "    # hostname=_HOSTNAME_"
echo " em seu lugar, acrescentar as linhas :"
echo "    mailhub=192.168.1.13"
echo "    rewriteDomain=vidy.com.br"
echo "    hostname=[nomedohost].vidy.local   # ou"
echo "    hostname=_HOSTNAME_.vidy.local"

EXISTE=$(cat /etc/ssmtp/ssmtp.conf |grep "mailhub=192.168.1.13"|wc -l)
if $EXISTE -eq 0
 echo "mailhub=192.168.1.13" >>/etc/ssmtp/ssmtp.conf 
 echo "rewriteDomain=vidy.com.br" >>/etc/ssmtp/ssmtp.conf
 echo "hostname=_HOSTNAME_.vidy.local" >>/etc/ssmtp/ssmtp.conf
fi


yum install vim-enhanced
yum install ssmtp mailx
yum install mutt

