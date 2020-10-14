#!/bin/bash
# Nome: testar_internet.sh
# Funcao: testar se a internet está presente
# Parametros: 
#   Param1 Velocidade de download, inteiro, opcional
#   Param2 Velocidade de upload, inteiro, opcional
# Dependencias: dig

# Funcoes importantes para este script
#. /home/administrador/fw-scripts/firewall.functions

function semremarks() {
  PARAMLINHA="$1"
  PARAMLINHA=${PARAMLINHA%% }
  PARAMLINHA=${PARAMLINHA## }
  #if [ `echo $PARAMLINHA|grep ^#|wc -l` -gt 0 ] ; then
  #  echo ""
  #  return
  #fi
  RESULT_VALUE=$(echo $PARAMLINHA|cut -d "#" -f1)
  echo "$RESULT_VALUE"
}

function convert_url2site() {
  PARAM=`semremarks "$1"`
  SEMHTTP=${PARAM##"http://"}
  RESULT_VALUE=`expr "$SEMHTTP" |cut -d "/" -f1`
  [ "$RESULT_VALUE" == "" ] || [ -z "$RESULT_VALUE" ] && RESULT_VALUE="$SEMHTTP"
  OLDSITE="$RESULT_VALUE"
  RESULT_VALUE=`expr "$OLDSITE" |cut -d ":" -f1`
  [ "$RESULT_VALUE" == "" ] || [ -z "$RESULT_VALUE" ] && RESULT_VALUE="$OLDSITE"
  echo "$RESULT_VALUE"
}

function getip_from_line() {
  PARAM=`semremarks "$1"`
  IP=`expr "$PARAM" |cut -d "/" -f1`
  MASK=`expr "$PARAM" |cut -d "/" -f2`
  if [ "$IP" == "" ] || [ -z "$IP" ] ; then
     IP="$PARAM"
     MASK="32"
  fi
  _getip_from_line="$IP/$MASK"
  echo "$_getip_from_line"
}


#
# Inicio do script
#
DOWNLOAD="$1"
UPLOAD="$2"
tempfile1="/tmp/testar_internet1-$$.tmp"
tempfile2="/tmp/testar_internet2-$$.tmp"
bind_conf_file=/etc/bind/named.conf.options
squid_conf_file=/etc/squid3/squid.conf.dns
#IP_EXTERNAL=$(lwp-request -o text checkip.dyndns.org | awk '{ print $NF }')
IP_EXTERNAL=$(dig +short  myip.opendns.com @resolver1.opendns.com)
IP_EXTERNAL_NAME=$(dig +short -x $IP_EXTERNAL|cut -d'.' -f2-)
IP_PING_BASETIME="8.8.4.4"
ping_opt=" -c5"
#ping_opt=" -c1"
qtde=0
if [ -f "$bind_conf_file" ] ; then
  sed -n '/forwarders[[:space:]]{/,/};/p' $bind_conf_file|\
    sed -n '/\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}/p'|\
    tr -d '\t'|\
    tr -d '//'|\
    tr -d ';'|\
    tr -d ' '|grep -v "^//">$tempfile1
else
  touch "$tempfile1"  
fi
# Pegando os DNSs usados pelo squid
#cat $squid_conf_file |\
#  sed -n '/\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}/p'|\
#  sed 's/^#dns_nameservers//g'|\
#  tr ' ' '\n'|\
#  sed -n '/\([0-9]\{1,3\}\.\)\{3\}[0-9]\{1,3\}/p'>>$tempfile1

# Lista de sites que não filtram pings
echo "speedtest.net">>$tempfile2
echo "www.pingtest.net">>$tempfile2
echo "checkip.dyndns.org">>$tempfile2
echo "mail.google.com">>$tempfile2

# Removendo alguns IPs que não são pingáveis
sed -i '/0.0.0.0/d' $tempfile1
sed -i '/208.67.222.222/d' $tempfile1
sed -i '/208.67.220.220/d' $tempfile1
sed -i "/$IP_PING_BASETIME/d" $tempfile1

# removendo duplicacoes
qtde=0
while read linha ; do
  site=`convert_url2site $linha`
  existe=`cat $tempfile2|grep "$site"|wc -l`
  if [ $existe -le 0 ] ; then
    echo $site>>$tempfile2
	qtde=$((qtde+1))  
  fi
done <$tempfile1

echo "----------------------------------------------------------------------"
echo "Iniciando testes de conectividade com $qtde sites e/ou DNS(s)..."
echo "Sua conexao de internet usa o IP: $IP_EXTERNAL ($IP_EXTERNAL_NAME)"
echo "----------------------------------------------------------------------"
#echo "A linha base para comparação é:"
#echo "O tempo médio para os sites testados em nossa LP de DADOS de 4Mb/s é de 4000ms"
#echo "rtt min/avg/max/mdev = 4.034/9.829/29.538/9.925 ms"
#echo "Obs: Se apenas alguns obtêm 100% de perda de pacotes, pode ser"
#echo "     que eles estejam configurados para não responder testes."

START=$(date +%s.%N)
qtde=0

echo "Lista de sites/ips que que não filtram pings e são otimos para testes:"
cat "$tempfile2"
while read site ; do
  ping $ping_opt $site|tail -n4
  qtde=$((qtde+1))  
done <$tempfile2

# Calculando numeros para comparar com linha base
ping $ping_opt $IP_PING_BASETIME|tail -n4 2>&1 | tee "$tempfile2"
PACKET_TRANSMITED=$(cat "$tempfile2"|grep "packets transmitted"|cut -d' ' -f1|tr -d '[:alpha:]')
PACKET_RECEIVED=$(cat "$tempfile2"|grep "packets transmitted"|cut -d',' -f2|tr -d '[:alpha:]'|tr -d '[:space:]')
PACKET_TIME=$(cat "$tempfile2"|grep "packets transmitted"|cut -d',' -f4|cut -d' ' -f3)
RTT_MIN=$(cat "$tempfile2"|grep "rtt min/avg/max/mdev"|cut -d'=' -f2|cut -d'/' -f1|tr -d '[:space:]')
RTT_AVG=$(cat "$tempfile2"|grep "rtt min/avg/max/mdev"|cut -d'=' -f2|cut -d'/' -f2)
RTT_MAX=$(cat "$tempfile2"|grep "rtt min/avg/max/mdev"|cut -d'=' -f2|cut -d'/' -f3)
RTT_MDEV=$(cat "$tempfile2"|grep "rtt min/avg/max/mdev"|cut -d'=' -f2|cut -d'/' -f4)

# Calculando tempo decorrido
END=$(date +%s.%N)
elap_time1=$(echo "$END - $START" | bc)
echo "----------------------------------------------------------------------"
echo "Uma linha base serve para comparar o tempo de resposta original"
echo "com o atual e se for notada uma grande diferença então pode"
echo "significar problemas com o nosso ISP $IP_EXTERNAL_NAME."
echo "Os valores atuais estão entre parenteses."

if [[ "$IP_EXTERNAL_NAME" =~ "virtua" ]] ; then
  [ "$DOWNLOAD" == "" ] && DOWNLOAD="120"
  [ "$UPLOAD" == "" ] && UPLOAD="4"
  DOWNLOAD=$(echo "$DOWNLOAD"|tr -d '[:alpha:]')
  DOWNLOAD="${DOWNLOAD##*( )}"                                          # Trim
  UPLOAD=$(echo "$UPLOAD"|tr -d '[:alpha:]')
  UPLOAD="${UPLOAD##*( )}"                                              # Trim
  echo ">>>Linha base usando NET Virtua com link de 120/4Mbit(Down:$DOWNLOAD/Up:$UPLOAD):"
  echo ">>>Linha base para pingar 6 sites($qtde) é de 28 segundos($elap_time1)."
  echo ">>>Linha base de ping para $IP_PING_BASETIME:"
  echo ">>>5 packets transmitted($PACKET_TRANSMITED), 5 received($PACKET_RECEIVED), 0% packet loss, time 4005ms($PACKET_TIME)"
  echo ">>>rtt min/avg/max/mdev = 8.509($RTT_MIN)/8.748($RTT_AVG)/9.121($RTT_MAX)/0.238 ms($RTT_MDEV)"
fi
if [[ "$IP_EXTERNAL_NAME" =~ "ipwave" ]] ; then
  [ "$DOWNLOAD" == "" ] && DOWNLOAD="1"
  [ "$UPLOAD" == "" ] && UPLOAD="1"
  DOWNLOAD=$(echo "$DOWNLOAD"|tr -d '[:alpha:]')
  DOWNLOAD="$(echo -e "${DOWNLOAD}" | sed -e 's/^[[:space:]]*//')"  # Trim
  UPLOAD=$(echo "$UPLOAD"|tr -d '[:alpha:]')
  UPLOAD="$(echo -e "${UPLOAD}" | sed -e 's/^[[:space:]]*//')"      # Trim
  echo ">>>Linha base usando IPWave com link de 1/1Mbit (Down:$DOWNLOAD/Up:$UPLOAD):"
  echo ">>>Linha base para pingar 6 sites($qtde) é de 36 segundos($elap_time1)."
  echo ">>>Linha base de ping para $IP_PING_BASETIME:"
  echo ">>>5 packets transmitted($PACKET_TRANSMITED), 5 received($PACKET_RECEIVED), 0% packet loss, time 4001ms($PACKET_TIME)"
  echo ">>>rtt min/avg/max/mdev = 103.096($RTT_MIN)/255.470($RTT_AVG)/410.076($RTT_MAX)/123.611 ms($RTT_MDEV)"
fi
echo "----------------------------------------------------------------------"



echo "Se não houver acesso, ou ocasionar perda de pacotes significativo então contate o ISP ($IP_EXTERNAL_NAME)."
#echo "A linha base para comparação é:"
#echo "O tempo médio para os sites testados em nossa LP de DADOS de 4Mb/s é de 4000ms"
#echo "rtt min/avg/max/mdev = 4.034/9.829/29.538/9.925 ms"
echo "Obs: Se apenas alguns sites/ips obtêm 100% de perda de pacotes, pode ser"
echo "     que eles estejam configurados para filtrarem respostas ao ping e "
echo "     devem ser removidos desse script, contate o adminstrador para essa tarefa."

exit 0;
