#!/bin/bash
#####################################################################################
# Nome: xenstart-on-boot.sh                                                         #
# Autor: Gladiston (Hamacker) Santana <sirhamacker[em]gmail.com>                    #
# Proposito: Modificar as propriedades de uma VM para que ela inicie                #
#            automaticamente após o boot do host                                    #
#            do_pool=0 entao funcionaria as atualizacoes apenas para o host em que  #
# Instalacao: Coloque este script em /usr/bin ou crie um link simbolico para ele    #
#             de qualquer lugar do disco.                                           #
# Como de usar:                                                                     # 
# Use 'xe vm-list' para listas as VMs instaladas e então decida pegar o name-label  #
# por exemplo, WinXP_Financeiro e então execute assim:                              #
# xenstart-on-boot.sh WinXP_Financeiro true                                         #
# "true" (default) coloca em boot automatico e "false" desliga-o                    #
# ATENCAO: Depois de aplicada a atualizacao, reinicie o host para observar se       #
#          funcionou adequadamente                                                  # 
#####################################################################################
function fill()
{
    # fill string to width of count from string chars 
    #
    # usage:
    #      fill count [chars]
    #
    # if count is zero a blank string is output
    # chars is optional, spaces used if missing
    #
    local FILL="${2:- }"
    for ((c=0; c<=$1; c+=${#FILL}))
    do
        echo -n "${FILL:0:$1-$c}"
    done
}
function pad()
{
    # Pad to right of string to required width, using chars.
    # Chars is repeated, as required, until width is reached.
    #
    # usage:
    #      pad width string [chars]
    #
    # if chars not specified spaces are used
    #
    BACK=$(fill $1 "$3")
    let PAD=$1-${#2}
    if [ $PAD -lt 1 ] 
    then
        echo -n ${2:0:$1-1}
    else
        echo -n "$2${BACK:${#2}}"
    fi
}

#
# Inicio do script
#


vm_name=$1
vm_name=$(echo -e "${vm_name}" | tr -d '[:space:]')
vm_boot=$2
vm_boot=$(echo -e "${vm_boot}" | tr -d '[:space:]')
vm_boot_old=""
vm_uuid=""
_HOST_UUID=$(xe host-list params=uuid hostname=$HOSTNAME|cut -d':' -f2|grep -v '^$'|tr -d '^ ')
_POOL_UUID=$(xe pool-list params=uuid|cut -d':' -f2|grep -v '^$'|tr -d '^ ')

#####################################################################################
# Nao mude nada no script desse ponto em diante                                     #
#####################################################################################
if [ -z $vm_name ] ; then
  echo "Voce precisa especificar o nome da VM."
  exit 2;
fi
if [ -z $vm_boot ] ; then
  vm_boot="status"
fi

if [ $vm_boot != "true" ] && [ $vm_boot != "false" ] && [ $vm_boot != "status" ] ; then
  echo "O segundo parametro deve ser true ou false para ligar ou desligar o auto_poweron."
  echo "Voce tentou:"
  echo "$0 $vm_name $vm_boot"
  exit 2;
fi
#
# Confere se a VM existe e captura o UUID dela
#
existe=`xe vm-list name-label=$vm_name|wc -l`
if [ $existe -eq 0 ] ; then
  echo "O nome da VM [$vm_name] não existe!"
  exit 2;
fi
vm_uuid=`xe vm-list name-label=$vm_name|grep uuid|cut -d ':' -f2| tr -d ' '`
if [ -z $vm_uuid ] ; then
  echo "Nao foi possivel capturar o uuid da VM [$vm_name]."
  exit 2;
fi

#
# Pega o antigo parametro para descobrir como era antes
#
erro=0
vm_boot_old=`xe vm-param-get uuid=$vm_uuid param-name=other-config param-key=auto_poweron`
echo "################################################################################"
echo "# Modificando propriedades da VM abaixo para o seguinte                        #"
echo "# comportamento apos o boot:                                                   #"
echo "# VM : $vm_name"
echo "# VM UUID : $vm_uuid"
COUNT=$(xe vm-list other-config:auto_poweron=$vm_boot params=name-label|grep "name-label"|wc -l)
echo "# auto_poweron atual: $vm_boot_old (de um total de $COUNT VMs com a mesma definição)"
if [ "$vm_boot" == "true" ] || [ "$vm_boot" == "false" ] ; then
  echo "# auto_poweron requisitado para: $vm_boot"
  if [ $COUNT -eq 0 ] && [ "$vm_boot" == "false" ]; then
    echo "Não existem VMs que iniciam junto ao boot, então estou desligando parametro que concede essa opção ao pool."
    xe pool-param-set uuid=$_POOL_UUID other-config:auto_poweron=false
  else
    echo "Como existem algumas VMs que iniciam junto ao boot, então estou ligando parametro que concede essa opção ao pool."
    xe pool-param-set uuid=$_POOL_UUID other-config:auto_poweron=true
  fi

  xe vm-param-set uuid=$vm_uuid other-config:auto_poweron=$vm_boot
  erro=$?
fi
echo "################################################################################"
if [  $erro -gt 0 ] ; then
   echo "# modificacao falhou ($erro)                                                   #"
else
   echo "# modificacao realizada com sucesso                                            #"
fi

# Finaliza
exit 0