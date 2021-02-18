#!/bin/bash
mailhub="192.168.1.xxx"  # IP do SMTP
maildom="dominio.local" # Dominio da rede local
maildom_to="dominio.com.br" # Dominio externo
repository_update=1
time_zone_new="America/Recife"
sshd_config="/etc/ssh/sshd_config"
user_new="administrador"
sudoers_file=/etc/sudoers
cronbak="$HOME/crontab.bak"
echo "CentOS Cenario"
echo "1. Habilitar os repositorios em /etc/yum.repos.d/CentOS-Base.repo"
echo "2. Executar este script"
echo "3. Editar o arquivo /etc/ssmtp/ssmtp.conf  e comentar as linhas :"
echo "    #mailhub=mail"
echo "    #rewriteDomain="
echo "    # hostname=_HOSTNAME_"
echo " em seu lugar, acrescentar as linhas :"
echo "    mailhub=$mailhub"
echo "    rewriteDomain=$maildom_to"
echo "    hostname=[nomedohost].$maildom   # ou"
echo "    hostname=_HOSTNAME_.$maildom"
if [ $repository_update -gt 0 ] ; then
  if [ -f "/etc/yum.repos.d/CentOS-Base.repo" ] ; then
    # para listar os repositorios habilitados
    #yum repolist enabled
    # para listar os repositorios deshabilitados
    echo "Repositorios desabilitados:"
    yum repolist disabled
    echo "Habilitando alguns:"
    # yum-config-manager parece não existir no XenServer
    #yum-config-manager --enable base #base/7/x86_64
    if ! [ -f /etc/yum.repos.d/CentOS-Base.repo ] ; then
      echo "Criando um backup '/etc/yum.repos.d/CentOS-Base.repo.ori'..."
      cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.ori
    fi
    sed -i 's/^enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-Base.repo
    sed -i 's/^#baseurl=/baseurl=/' /etc/yum.repos.d/CentOS-Base.repo
  
    echo "Atualizando os indices de pacotes nos repositorios..."
    yum repolist all
    yum install vim-enhanced
    yum install ssmtp mailx
    yum install mutt
  fi
fi

if [ -f /etc/ssmtp/ssmtp.conf ] ; then
  echo "Configurando /etc/ssmtp/ssmtp.conf..."
  EXISTE=$(cat /etc/ssmtp/ssmtp.conf |grep "mailhub=$mailhub"|wc -l)
  if [ $EXISTE -eq 0 ] ; then
   echo "mailhub=$mailhub" >>/etc/ssmtp/ssmtp.conf 
   echo "rewriteDomain=$maildom_to" >>/etc/ssmtp/ssmtp.conf
   echo "hostname=_HOSTNAME_.$maildom" >>/etc/ssmtp/ssmtp.conf
  fi
fi

echo "faça o label dos discos de backup mudando-os para *xenbackup*:"
echo "/sbin/e2label /dev/sdc1 xenbackup"
echo "Onde /dev/sdc1 é o disco de backup."
echo "Use os comandos lsblk ou blkid para listar os discos que foram espetados ao sistema."
echo "Será acrescido a linha ao /etc/fstab:"
echo "LABEL=xenbackup    /media/backup         ext2     defaults   0  0"
echo "Para facilitar a montagem e inspeção desses discos com o comando:"
echo "mount /media/backup"
echo "sem precisar especificar outros parametros."
EXISTE=$(cat /etc/fstab |grep "/media/backup"|wc -l)
if [ $EXISTE -eq 0 ] ; then
  echo "Modificando /etc/fstab..."
  echo "LABEL=xenbackup    /media/backup         ext2     defaults   0  0" >>/etc/fstab
  mkdir -p /media/backup
fi

# criando um crontab.bak para facilitar a criaçao de um novo crontab
if [ ! -f "$cronbak" ] ; then
   
  echo "Criando um $HOME/crontab.bak para servir de base ">$cronbak
  echo "caso nao haja um crontab atual.">>$cronbak
  echo "SHELL=/bin/bash">>$cronbak
  echo "PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin">>$cronbak
  echo "# *    *    *    *    *  comando para executar">>$cronbak
  echo "# .    .    .    .    .">>$cronbak
  echo "# .    .    .    .    .">>$cronbak
  echo "# .    .    .    .    .">>$cronbak
  echo "# .    .    .    .    ...... dia da semana (0-6) 0=domingo">>$cronbak
  echo "# .    .    .    ........... mes (1 - 12)">>$cronbak
  echo "# .    .    ................ dia do mes (1 - 31)">>$cronbak
  echo "# .    ..................... hora (0 - 23)">>$cronbak
  echo "# .......................... min (0 - 59)">>$cronbak
  echo "15 12 * * 1-5 /root/xenbackup.sh">>$cronbak
  echo "00 20 * * 1-5 /root/xenbackup.sh">>$cronbak
  echo " ">>$cronbak
  echo "# Desligamento para manutencao programada">>$cronbak
  echo "# tente programar sempre as 06h00 para garantir que">>$cronbak
  echo "# que os backups foram concluidos">>$cronbak
  echo "# min hor diadomes mes * programada">>$cronbak
  echo "#00 06 31 08 * /sbin/poweroff">>$cronbak
  echo " ">>$cronbak
  echo "# Fim de semana - reinicia">>$cronbak
  echo "# Este horario deve estar sincronizado com o xen ">>$cronbak
  echo "# com 15 minutos a mais, assim se o xena reiniciar as 06h00 ">>$cronbak
  echo "# entao este devera reiniciar as 06h15 ">>$cronbak
  echo "#15 06 * * 0 /sbin/reboot ">>$cronbak
  echo " ">>$cronbak
  echo "# Sincronizando o relogio em dois horarios diferentes">>$cronbak
  echo "#00 12 * * * /usr/sbin/ntpdate -u pool.ntp.br ">>$cronbak
  echo "#00 07 * * * /usr/sbin/ntpdate -u pool.ntp.br ">>$cronbak
  echo "Foi criado um arquivo de backup para o crontab:"
  echo "  $cronbak"
  echo "Se nao tiver nenhum crontab, poderá usá-lo como referencia:"
  echo "crontab -u $USERNAME $cronbak "
  echo
fi



crontab_check_time=$(crontab -l|grep "00 12 \* \* \* /usr/sbin/ntpdate"|wc -l)
if [ $crontatab_check_time -eq 0 ] ; then
  echo "Modificando crontab, por gentileza acrescente ao crontab..."
  echo "#00 12 * * * /usr/sbin/ntpdate -u pool.ntp.br #192.168.1.6"
  crontab_check_time=$(crontab -l|grep "00 06 \* \* \* /usr/sbin/ntpdate"|wc -l)
  if [ $crontatab_check_time -eq 0 ] ; then
    echo "#00 06 * * * /usr/sbin/ntpdate -u pool.ntp.br #192.168.1.6"
  fi
  echo "Se estiver usando NTP, mantenha o # para ignorar a atualização manual nestes horarios."
fi

# SSH configurado para permitir edições via streamming
if [ -f "$sshd_config" ] ; then
  # Para acesso por estacoes windows, instale o OpenSSH, inicie as Configurações 
  # e vá para Aplicativos > Aplicativos e Recursos > Gerenciar Recursos Opcionais
  # Pode usar tambem o putty, mas ele nao será compativel com o vscode caso
  # pretenda usa-lo. A partir de uma atualização do Windows10 o cliente ssh
  # já vem preinstalado, execute 'ssh' no terminal e descobrirá
  # instruções para vscode podem ser encontradas em:
  # https://www.digitalocean.com/community/tutorials/how-to-use-visual-studio-code-for-remote-development-via-the-remote-ssh-plugin-pt
  EXISTE=$(cat $sshd_config |grep "#PasswordAuthentication yes"|wc -l)
  if [ $EXISTE -eq 0 ] ; then
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' $sshd_config
    service sshd restart
  fi
fi

# Usuario administrador nao root
admin_is_here=$(cat /etc/passwd|grep $user_new|wc -l)
if [ $admin_is_here -eq 0 ] ; then
  useradd -m $user_new
  if [ $? -eq 0 ] ; then
    echo "Digite a senha para o $user_new:"
    passwd $user_new
    if [ $? -gt 0 ] ; then
      userdel -r $user_new
    fi
  fi
fi

admin_is_here=$(cat /etc/passwd|grep $user_new|wc -l)  
if [ $admin_is_here -gt 0 ] ; then
  ##########################################
  echo "Acrescendo $user_new ao group root..."
  ##########################################
  EXISTE=$(groups administrador|grep root|wc -l)
  if [ $EXISTE -eq 0 ] ; then
    usermod -a -G root $user_new
    [ $? -eq 0 ] && echo "Agora o usuario $user_new está no grupo root"
  fi
fi

if [ $admin_is_here -gt 0 ] ; then
  ##########################################
  echo "Acrescendo $user_new ao sudoers..."
  ##########################################
  if [ -f "$sudoers_file" ] ; then    
    EXISTE=$(cat "$sudoers_file" |grep "$user_new"|wc -l)
    if [ $EXISTE -eq 0 ] ; then
      echo " " >>$sudoers_file
      echo "# Usuario $user_new é um admin restrito ao menu" >>$sudoers_file
      echo "$user_new   ALL=(ALL)       NOPASSWD:ALL" >>$sudoers_file
      echo "Agora o usuario $user_new está inscrito no sudoers"
    fi
  fi
fi

if [ $admin_is_here -gt 0 ] ; then
  ##########################################
  echo "Conferindo a necessidade de fixar $user_new restrito ao menu principal"
  ##########################################
  if ! [ -f /usr/bin/menuasroot.sh ] ; then
    cp -f /root/menuasroot.sh /usr/bin/menuasroot.sh
    chmod a+x /usr/bin/menuasroot.sh
  fi    
  bashrc_file="/home/$user_new/.bashrc"
  EXISTE=$(cat "$bashrc_file" |grep /usr/bin/menuasroot.sh|wc -l)
  if [ $EXISTE -eq 0 ] ; then
    echo " " >>$bashrc_file
    echo "# Usuario $user_new esta restrito ao menu" >>$bashrc_file
    echo "exec /usr/bin/menuasroot.sh" >>$bashrc_file
    echo "Agora o usuario $user_new restrito esta restrito ao menu principal"
  fi    
fi

inet_date=$(ntpdate -q time.google.com | sed -n 's/ ntpdate.*//p') #18 Feb 14:06:04
inet_day=$(echo $inet_date|cut -d" " -f1)
inet_month=$(echo $inet_date|cut -d" " -f2)
inet_time=$(echo $inet_date|cut -d" " -f3)
cur_date=$(date)
cur_year=$(echo $cur_date|rev|cut -d" " -f1|rev)
echo "A data na internet é $inet_date."
echo "A data no sistema é $cur_date."
echo "Se a data acima estiver incorreta então siga as instruções:"
echo "Para corrigir para o horario certo:"
echo "date -s \"$inet_day $inet_month $cur_year $inet_time\""
echo "hwclock --systohc --utc # para salvar na BIOS"
echo "3) Para evitar essas situações é bom instalar o XenServer"
echo "sem o suporte ao NTP e colocar no crontab algo assim:"
<<<<<<< HEAD
echo "00 12 * * * /usr/sbin/ntpdate -u pool.ntp.br"
echo "00 07 * * * /usr/sbin/ntpdate -u pool.ntp.br"
echo "Assim a hora atual será atualizada conforme a referencia NTP."
=======
echo "00 12 * * * /usr/sbin/ntpdate -u pool.ntp.br "
echo "00 07 * * * /usr/sbin/ntpdate -u pool.ntp.br "
echo "Assim em horarios programados o horario será atualizado "
echo "conforme o padrao local."
>>>>>>> 4e1081cfbe7bfdf82b391a7f021108f37280f49e
