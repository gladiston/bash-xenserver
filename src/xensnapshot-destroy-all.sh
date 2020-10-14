#!/bin/bash

#
# Inicio do Script
#
_HOST_UUID=$(xe host-list params=uuid hostname=$HOSTNAME|cut -d':' -f2|grep -v '^$'|tr -d '^ ')
_POOL_UUID=$(xe pool-list params=uuid|cut -d':' -f2|grep -v '^$'|tr -d '^ ')
FILE_TMP1=$(mktemp /tmp/list-snapshots-XXXXXXX)
# listando todos os discos virtuais que sejam snapshots
xe vdi-list  is-a-snapshot=true params=uuid|cut -d':' -f2|grep -v '^$'|tr -d '^ '>  "$FILE_TMP1"
while read VDI_UUID ; do  
  VDI_NAME=$(xe vdi-list uuid=$VDI_UUID params=name-label|cut -d':' -f2|grep -v '^$'|tr -d '^ ')
  VBD_UUID=$(xe vbd-list vdi-uuid=$VDI_UUID  unpluggable=true params=uuid|cut -d':' -f2|grep -v '^$'|tr -d '^ ')
  if [ "$VBD_UUID" == "" ] ; then
    VBD_UUID="nenhum"  
  fi
  if [ "$VDI_NAME" != "" ] ; then  
    echo -e "VDI Name:\t $VDI_NAME"
    echo -e "VDI UUID:\t $VDI_UUID"
    echo -e "VBD UUID:\t $VBD_UUID"
    # unplug - libera o snapshot da VM/Objeto que a criou
    xe vbd-unplug uuid=$VBD_UUID
    return_status=$?
    UNPLUG="UNPLUGED"
    if [ $return_status -eq 0 ] ; then
      echo -e "VBD PLUGGED:\t $UNPLUG (xe vbd-destroy uuid=$VBD_UUID)"
    else
      echo -e "VBD PLUGGED:\t NOT UNPLUGGED (xe vbd-unplug uuid=$VBD_UUID)"  
    fi
  fi
done < "$FILE_TMP1"

[ -f "$FILE_TMP1" ] && rm -f "$FILE_TMP1"

