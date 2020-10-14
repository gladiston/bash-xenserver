#!/bin/bash
# Objetivo : Envia uma mensagem/anexo por email contendo informações
#            uteis.
# Ex: ./enviar_email_admin.sh "gladiston@vidy.com.br" "teste de envio de mensagem" "corpo da mensagem ou indicação de arquivo que servira de corpo da mensagem" /var/log/xen/xenbackup-2014-11-18+11_25.log
# Parametros :
# (1) Email do destinatario
# (2) Assunto
# (3) Mensagem ou arquivo contendo a mensagem
# (4) Arquivo a ser anexado (opcional)
#
# CentOS Cenario
# 1. Habilitar os repositorios em /etc/yum.repos.d/CentOS-Base.repo  
# 2. Instalar o postfix :
#    yum install ssmtp mailx
# 3. Editar o arquivo /etc/ssmtp/ssmtp.conf  e comentar as linhas :
#    #mailhub=mail
#    #rewriteDomain=
#    # hostname=_HOSTNAME_
# em seu lugar, acrescentar as linhas :
#    mailhub=192.168.1.13
#    rewriteDomain=vidy.com.br
#    hostname=[nomedohost].vidy.local   # ou
#    hostname=_HOSTNAME_.vidy.local


function log() {
  msg="$1"
  [ $VERBOSE -gt 0 ] && echo -e "$msg"
  [ -f "/tmp/message" ] && echo -e "$msg" >>"/tmp/message"
}


#
# Inicio
#
VERBOSE=0
BIN="/bin/mail"
UUENCODE="/usr/bin/uuencode"
if ! [ -f "$BIN" ] ; then
  echo "Nao posso notificar por email por falta do programa : $BIN"
  exit 2;  
fi  
if ! [ -f "$UUENCODE" ] ; then
  echo "Nao posso notificar por email por falta do programa : $UUENCODE"
  exit 2;  
fi 
dt_agora="`date +%Y-%m-%d+%H:%M`"
_MAILTO="$1"
COPYTO="registros@vidy.com.br"
if [ "$_MAILTO" = "<admin>" ] ; then
  _MAILTO="informatica@vidy.com.br"  # suporte@vidy.com.br
fi

SUBJECT="$2"
MESSAGE="$3"
if [ -f "$MESSAGE" ] ; then
  MENSAGEM=$(cat "$MESSAGE")
fi
ARQ_ANEXO="$4"
ARQ_MAIL_BODY="/tmp/mail-body-$$.txt"
ARQ_ANEXO_ENCODE="/tmp/mail-encode-$$.txt"
ARQ_ANEXO_COMBINADO="/tmp/mail-combinado-$$.txt"
ARQ_ANEXO_COMBINADO="/tmp/mail-combinado-$$.txt"
ARQ_SENDMAIL="/tmp/mail-send-$$.sh"

echo "criando mensagem $ARQ_MAIL_BODY"

if [ "$MESSAGE" = "$ARQ_ANEXO" ] && [ -f "$MESSAGE" ] ; then
  ARQ_ANEXO=""
fi

if [ -f "$MESSAGE" ] ; then
  echo "=> $SUBJECT" >"$ARQ_MAIL_BODY"
  cat "$MESSAGE" >>"$ARQ_MAIL_BODY"
fi

if [ "$SUBJECT" = "" ];  then
  SUBJECT="[$HOSTNAME] Tarefa administrativa executada"
else
  SUBJECT="[$HOSTNAME] $SUBJECT"
fi

if [ ! -f "$ARQ_MAIL_BODY" ] ; then
  echo "=> $SUBJECT" >"$ARQ_MAIL_BODY"
  echo "$MESSAGE" >>"$ARQ_MAIL_BODY"  
  echo "-------------------------------------------------------------------------------">>"$ARQ_MAIL_BODY"
  echo "Esta mensagem foi enviada de nosso servidor $HOSTNAME em $dt_agora.">>"$ARQ_MAIL_BODY"
  echo "Com o proposito de notifica-lo sobre a execução de alguma tarefa." >>"$ARQ_MAIL_BODY"
  echo "Observe a mensagem com cuidado, ele descreve sobre a falha ou sucesso de alguma tarefa executada no servidor [$HOSTNAME]." >>"$ARQ_MAIL_BODY"
  echo "Se esta msg estiver longe do seu entendimento, por favor contate o administrador da rede" >>"$ARQ_MAIL_BODY"
  echo "-------------------------------------------------------------------------------" 
fi

# Permissao publica para este arquivo que será tocado por outros programas
chmod 666 "$ARQ_MAIL_BODY"

# Se houver uma variavel de "_LOG_FILE" entao acrescenta-o na mensagem
if [ ! -z "$_LOG_FILE" ] && [ -f "$_LOG_FILE" ]; then
  echo "Acrescentando $_LOG_FILE"
  cat "$_LOG_FILE" >>"$ARQ_MAIL_BODY"
fi

# Se houver anexo entao anexa-o na mensagem
if [ -f "$ARQ_ANEXO" ]; then
  echo "Anexando $ARQ_ANEXO"
  $UUENCODE "$ARQ_ANEXO" "$ARQ_ANEXO" > "$ARQ_ANEXO_ENCODE"
  # CONCATENA ARQ_MAIL_BODY E ARQ_ANEXO_ENCODE num unico "$ARQ_ANEXO_COMBINADO"
  cat "$ARQ_MAIL_BODY" "$ARQ_ANEXO_ENCODE" > "$ARQ_ANEXO_COMBINADO"
  # "$ARQ_MAIL_BODY" é um merge de anexo e mensagem
  mv -f "$ARQ_ANEXO_COMBINADO" "$ARQ_MAIL_BODY"
fi


CMD="$BIN -s \"$SUBJECT\""
if [ "$COPYTO" != "" ] ; then
   CMD="$CMD -c \"$COPYTO\""
fi
CMD="$CMD \"$_MAILTO\"" 
echo "#!/bin/bash">"$ARQ_SENDMAIL"
echo "$CMD < \"$ARQ_MAIL_BODY\"">>"$ARQ_SENDMAIL"
chmod a+x "$ARQ_SENDMAIL"
echo "Enviando mensagem $ARQ_SENDMAIL" 
$ARQ_SENDMAIL
RESULT_VALUE=$?

# Eliminnado temporario
[ -f "$ARQ_MAIL_BODY" ] && rm -f "$ARQ_MAIL_BODY"
if [ $RESULT_VALUE -eq 0 ] ; then
   echo "mensagem enviada."
else
   echo "[$RESULT_VALUE] $CMD"
   echo "falha no envio da mensagem ($RESULT_VALUE) !"
fi

echo "Removendo $ARQ_MAIL_BODY" 
[ -f "$ARQ_MAIL_BODY" ] && rm -f "$ARQ_MAIL_BODY" 
echo "Removendo $ARQ_ANEXO_ENCODE" 
[ -f "$ARQ_ANEXO_ENCODE" ] && rm -f "$ARQ_ANEXO_ENCODE" 
echo "Removendo $ARQ_ANEXO_COMBINADO" 
[ -f "$ARQ_ANEXO_COMBINADO" ] && rm -f "$ARQ_ANEXO_COMBINADO" 
echo "Removendo $ARQ_SENDMAIL" 
[ -f "$ARQ_SENDMAIL" ] && rm -f "$ARQ_SENDMAIL" 
exit $RESULT_VALUE
