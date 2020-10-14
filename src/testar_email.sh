#!/bin/bash
#
# Este script testa a funcionalidade de envio de email por este computador
#
if ! [ -f "/usr/bin/mutt" ] ; then
  echo "Nao posso notificar por email por falta do arquivo : /usr/bin/mutt"
  exit 2;  
fi  
dt_agora="`date +%Y-%m-%d+%H:%M`"
anexo="/var/log/dmesg"
echo "criando mensagem /tmp/message"
#MAILTO="gladiston@vidy.com.br"
MAILTO="informatica@vidy.com.br"
COPYTO="gladiston.santana@gmail.com"
SUBJECT="[$HOSTNAME-teste] testando o sistema de email a partir de $HOSTNAME"
echo "=> $SUBJECT" >/tmp/message
echo "----------------------------------------------------------------------------------" >>/tmp/message
echo "Esta mensagem foi enviada de nosso servidor $HOSTNAME em $dt_agora." >>/tmp/message
echo "Com o proposito de debugar erros ocorridos em nosso servidor." >>/tmp/message
echo "Se voce SysAdmin, estiver vendo essa mensagem não se trata dum SPAM." >>/tmp/message
echo "Se esta msg estiver se repetindo em sua rede é porque estamos sofrendo" >>/tmp/message
echo "avarias em nosso sistema e muito provavelmente ja estamos trabalhando na resoluçao." >>/tmp/message
echo "Somos muito gratos por sua colaboração." >>/tmp/message
echo "----------------------------------------------------------------------------------" >>/tmp/message
cat "$anexo" >>/tmp/message
chmod 666 /tmp/message
echo "formalizando sintaxe com o comando mutt"
mutt_cmd=""
[ "$COPYTO" != "" ] && mutt_cmd="$mutt_cmd -c $COPYTO"
[ -f "$anexo" ] && mutt_cmd="$mutt_cmd -a $anexo"
echo "[exec] sudo mutt -s "$SUBJECT" $MAILTO $mutt_cmd </tmp/message"
# enviando e-mail
mutt -s "$SUBJECT" $MAILTO $mutt_cmd </tmp/message
RESULT_VALUE=$?
if [ $RESULT_VALUE -eq 0 ] ; then
   [ -f /tmp/message ] && rm -f /tmp/message
   echo "mensagem enviada."
else
   echo "[$RESULT_VALUE] sudo $mutt_cmd </tmp/message"
   echo "falha no envio da mensagem ($RESULT_VALUE) !"
fi

