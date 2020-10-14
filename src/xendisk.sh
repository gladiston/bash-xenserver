#!/bin/bash
# Nome do script : xendisk.sh
# Autor : Hamacker (sirhamacker [em] gmail.com)
# Licença : GPL-2
# Função : Script para procurar um disco valido para a realização
# de backup de maquinas virtuais.
#
# Abaixo alistamos todos os UUIDs de discos que serao aceitos para backup
# Dentro dos scripts de backup e limpeza, esta rotina retornará a UUID
# que foi encontrada e o script prosseguirá ou vazio e provavelmente
# o script interromperá o processo dizendo que o backup ou a limpeza
# nao poderá ser realizada porque nenhum disco valido de backup foi
# encontrado no sistema.
#
#Para criar um novo disco de backup, siga os passos:
#1- Sem nenhum disco inserido, execute o fdisk -l para ter conhecimento
#   dos discos existentes
#2- Insira o disco de backup, execute o fdisk -l e ter conhecimento do 
#   disco que foi inserido, digamos que tenha sido /dev/sdb
#3- Execute fdisk /dev/sdb e use o comando 'n' para criar uma nova 
#   particao primaria, depois 'w' para gravar e sair do fdisk
#4- Para formatar, execute  mkfs -t ext2 -L "nome-volume"  /dev/sdb1
#5- Use o 'blkid |grep "nome-volume" para listar o disco formatado e 
#   copie UUID dele para a relacao de discos aceitos para backup, ex:
#groupdisk=( "${groupdisk[@]}" "091e8f62-1f8a-4d33-bbdb-dd26ea41b16d" )  # "nome-volume"

#
# Programa 'blkid' é usado para detectar os discos pludados por UUID
# ele e' mais confiavel do que usar o diretorio /dev/disk/disk-by-uuid
BLKID="/sbin/blkid"
# Disco de Backup das VMs : Mencionar todos os UUID de discos que
# houverem. O Script só aceitará os UUIDs aqui mencionados
groupdisk=( "${groupdisk[@]}" "7bebcd03-2ff7-4fdc-b2f0-0df1d884f27b" )  # xena-01
groupdisk=( "${groupdisk[@]}" "6f6d746f-a42b-4c72-865d-54a1dc24b303" )  # xena-02
groupdisk=( "${groupdisk[@]}" "8708b8c3-b1e5-4f53-80b5-f7084b9cdd8c" )  # xenb-01
groupdisk=( "${groupdisk[@]}" "28ef906f-ced5-4c8c-a2a2-ea42430e8420" )  # xenb-02


# Procura se algum dos discos alistados para backup estao presentes no sistema
backup_dev_disk=""
tmpfile=$(mktemp "/tmp/xendisk.XXXXXXXXXX")
$BLKID |grep "UUID">$tmpfile
while read line ; do
  disk_device=""
  disk_label=""
  disk_uuid=""
  disk_type="" 
  disk_device=$(eval echo $line|cut -d ":" -f1) 
  [[ "$line" =~ "LABEL=" ]] && disk_label=$(eval echo ${line#*LABEL=}|cut -d " " -f1|tr -d "\"")
  [[ "$line" =~ "UUID=" ]] && disk_uuid=$(eval echo ${line#*UUID=}|cut -d " " -f1|tr -d "\"")
  [[ "$line" =~ "TYPE=" ]] && disk_type=$(eval echo ${line#*TYPE=}|cut -d " " -f1|tr -d "\"")    
  # _DEBUG :
  #echo "uuid=$disk_uuid,label=$disk_label,type=$disk_type,device=$disk_device"
  for uuid in "${groupdisk[@]}" ; do
    if [ "$uuid" = "$disk_uuid" ] ; then  
      backup_dev_disk="$disk_device"
      break
    fi
  done
done <$tmpfile
[ -f "$tmpfile" ] && rm -f "$tmpfile"
echo "$backup_dev_disk"

