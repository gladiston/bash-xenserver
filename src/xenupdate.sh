#!/bin/bash
#####################################################################################
# Nome: xenupdate.sh                                                                #
# Autor: Gladiston (Hamacker) Santana <sirhamacker[em]gmail.com>                    #
# Proposito: Aplicar atualizacoes da citrix em servidores XenServer                 #
#            O script só foi testando em sistemas de pool, mas se mudar a variavel  #
#            do_pool=0 entao funcionaria as atualizacoes apenas para o host em que  #
#            o script fosse executado (isso ainda nao foi testado)                  #
# Instalacao: Coloque este script em /usr/bin ou crie um link simbolico para ele    #
#             de qualquer lugar do disco, porem nunca coloque este script no mesmo  #
#             diretorio que também ficarao as atualizacoes                          #
# Como de usar: Va ate o diretorio onde estao as atualizacoes e digite:             # 
# xenupdate.sh XS62E000.zip ou                                                      #
# xenupdate.sh XS62E000.xsupdate                                                    #
# ATENCAO: Depois de aplicada a atualizacao o script remove o arquivo patch         #
#          usado para aplicar a atualizacao. Se deseja que o script mantenha estes  #
#          arquivos entao mude a variavel remove_files_after_sucess=0               # 
#####################################################################################
# do_pool=1 (default) para atualizar o pool de servidores ou 0 para apenas este host
do_pool=1
# remove_files_after_sucess=1 (default)  para remover o arquivo de patch quando a 
# instalacao terminar bem sucedida ou 0 para manter o arquivo do patch
remove_files_after_sucess=1
# O primeiro parametro deve fornecer o nome do arquivo do patch
xe_file=$1

#####################################################################################
# Nao mude nada no script desse ponto em diante                                     #
#####################################################################################
if [ -z $xe_file ] ; then
  echo "Voce precisa especificar o arquivo contendo o patch."
  exit 2;
fi

xe_patch_name=${xe_file%%.*}
xe_file_ext="${xe_file##*.}"
host_uuid=""
patch_uuid=""
xe_sucess=0


#
# Descobrindo o host_uuid
#
host_uuid=`xe host-list name-label=$HOSTNAME|grep 'uuid'|cut -d':' -f2|tr -d ' '`
echo "Formato detectado: $xe_file_ext"
if [ "$xe_file_ext" = "zip" ] ; then
  unzip -u $xe_file
  xe_file=$xe_patch_name.xsupdate
  xe_file_ext=xsupdate
fi

if ! [  "$xe_file_ext" = "xsupdate" ] ; then
  echo "Formato incompativel: $xe_file ($xe_file_ext)"
  exit 2
fi

if ! [ -f "$xe_file" ] ; then
  echo "Arquivo nao encontrado: $xe_file"
  exit 2
fi
echo "--------------------------------------------------------------------------"
echo "Antes de prosseguir, confira:"
echo "- Nunca regredir uma atualização, se o ultimo foi XS62E012, não tente XS62E011, XS62E010,..."
echo "- Se todas as VMs estão com o CDROM virtualizado ejetado antes de prosseguir"
echo "- Não há nenhum backup em execução neste instante."
echo "- Embora seja possivel aplicar varias atualizacoes em fileira e reiniciar no final, a boa pratica seria reiniciar o servidor após cada atualização aplicada."
if [ $do_pool -gt 0 ] ; then
  echo "- Este script esta configurado para atualizar o pool, então certifique-se"
  echo "  de que este servidor seja o MASTER, caso contrario o pool não será atualizado."
  echo "  Além disso, as dicas anteriores se aplicam a todos os servidores no mesmo pool."
fi
echo "Tecle [ENTER] para prosseguir ou CTRL+C para cancelar esta operação"
read espera
echo "--------------------------------------------------------------------------"

#
# Se /var/xen/xc-install estiver montado estão desmonta-o...
#

#mount_exist=`mount|grep /var/xen/xc-install|wc -l`
#if [ $mount_exist -gt 0 ] ; then
#  umount /var/xen/xc-install
#fi

#
# Observando se o patch ja existe e envia-o
#

echo "Patch detectado: $xe_file"
echo "Enviando o arquivo $xe_file para o servidor..."
xe_sucess=`xe patch-list name-label=$xe_patch_name|grep "name-label"|grep "$xe_patch_name"|wc -l`
do_upload=1
if [  $xe_sucess -gt 0 ] ; then
   do_upload=0
   echo "Aparentemente o patch já está no servidor e não será necessário fazer o upload novamente."  
fi

if [  $do_upload -gt 0 ] ; then
    xe patch-upload file-name=$xe_file
	erro=$?
    if [  $erro -gt 0 ] ; then
       echo "Erro ao executar:"
       echo "xe patch-upload file-name=$xe_file"
       echo "Prosseguir assim mesmo?"  
       echo "Tecle [ENTER] para prosseguir ou CTRL+C para cancelar esta operação"
       read espera
       erro=$?
   fi
fi

#
# Verificando se o patch foi enviado
#
xe_sucess=`xe patch-list name-label=$xe_patch_name|grep "name-label"|grep "$xe_patch_name"|wc -l`
if [  $xe_sucess -eq 0 ] ; then
   echo "Patch não foi encontrado no servidor:"
   echo "nome do patch (name-label)=$xe_patch_name"
   echo "Tecle [ENTER] para abandonar."
   read espera
   exit 2;
fi

#
# Aplicando o patch
#
patch_uuid=`xe patch-list name-label=$xe_patch_name|grep uuid|cut -d':' -f2|tr -d ' '`
if [ -z $patch_uuid ] ; then
   echo "UUID do patch não foi encontrado:"
   echo "nome do patch (name-label)=$xe_patch_name"
   echo "Tecle [ENTER] para abandonar."
   read espera
   exit 2;
fi

echo "Aplicando o patch $xe_patch_name UUID=$patch_uuid "
if [ $do_pool -eq 0 ] ; then
  cmd_exec="xe patch-apply uuid=$patch_uuid host-uuid=$host_uuid"
  xe patch-apply uuid=$patch_uuid host-uuid=$host_uuid
  erro=$?
else
  cmd_exec="xe patch-pool-apply uuid=$patch_uuid"
  xe patch-pool-apply uuid=$patch_uuid
  erro=$?
fi
if [ $erro -gt 0 ] ; then
  echo "Falha ao aplicar patch ($xe_patch_name) UUID=$patch_uuid."
  echo "Comando:"
  echo "$cmd_exec"
  exit 1;
fi

# Se deu tudo certo, reiniciar a pilha toolstack
echo "Patch foi aplicado com sucesso!"
echo "Pressione [ENTER] para reiniciar o toolstack"
echo "ou CTRL+C para aborta-la."
read espera
xe-toolstack-restart
erro=$?
if [ $erro -gt 0 ] ; then
   echo "Erro ao aplicar patch ($xe_patch_name) UUID=$patch_uuid."
   exit 1;
fi

# Sucesso
echo "Patch $xe_patch_name foi instalado com sucesso."
echo "Quando for conveniente, é recomendavel reiniciar o(s) host(s) envolvidos."
if [ $remove_files_after_sucess -gt 0 ] ; then
  rm -f $xe_patch_name*
fi

# Finaliza com sucesso
exit 0;
