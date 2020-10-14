#!/bin/bash
# Nome do script : xenvmlist.sh
# Autor : Hamacker (sirhamacker [em] gmail.com)
# Licença : GPL-2
# Função : Script para a listagem das VMs de todas ou apenas
#          as VMs localizadas neste host.
# Parametros: (nenhum) fará uma série de perguntas de como deseja a listagem
#              halted=[0/1] incluir as VMs que talvez estejam desligadas?
#              local=[0/1] incluir apenas as VMs localizadas neste servidor?
#              edit=[0/1] Quer editar manualmente a lista que será gerada? 
#              update=[0/1] Gostaria de atualizar a lista de VMs para backup??
#              para listar todas as vms = basta combinar halted=1 e local=0 
#                 Ex: xenvmlist.sh halted=1 local=0 edit=0 update=0

# Funcoes importantes para este script
. /root/xenfunctions.sh
if [ $? -ne 0 ] ; then
  echo "Nao foi possivel importar o arquivo [/root/xenfunctions.sh] !"
  read espera
  exit 2;
fi

#
# Inicio do Script
#
init_vars
HALTED_YESNO=-1
EDIT_YESNO=-1
UPDATELIST_YESNO=-1
ONLY_LOCAL=-1
XEN_OPT=" resident-on=$_HOST_UUID is-control-domain=false is-a-snapshot=false "
_TMP_FILE="/tmp/xenvmlist-$$.txt"

for CURRENT_PARAM in "$@" ; do
  CURRENT_PARAM="${CURRENT_PARAM##*( )}"                                          # Trim
  if [[ "$CURRENT_PARAM" =~ "^halted=" ]] ; then
    HALTED_YESNO=$(eval echo "$CURRENT_PARAM"|cut -d'=' -f2)
    # Se nao retornar nenhum numero então...
    if ! [[ $HALTED_YESNO =~ '^[0-9]+$' ]] ; then
       HALTED_YESNO=-1
    fi  
  fi
  if [[ "$CURRENT_PARAM" =~ "^edit=" ]] ; then
    EDIT_YESNO=$(eval echo "$CURRENT_PARAM"|cut -d'=' -f2)
    # Se nao retornar nenhum numero então...
    if ! [[ $EDIT_YESNO =~ '^[0-9]+$' ]] ; then
       EDIT_YESNO=-1
    #else 
    #   [$EDIT_YESNO -gt 0 ] && UPDATELIST_YESNO=1    
    fi
  fi
  if [[ "$CURRENT_PARAM" =~ "^local=" ]] ; then
    ONLY_LOCAL=$(eval echo "$CURRENT_PARAM"|cut -d'=' -f2)
    # Se nao retornar nenhum numero então...
    if ! [[ $ONLY_LOCAL =~ '^[0-9]+$' ]] ; then
       ONLY_LOCAL=-1
    fi  
  fi  
  if [[ "$CURRENT_PARAM" =~ "^update=" ]] ; then
    UPDATELIST_YESNO=$(eval echo "$CURRENT_PARAM"|cut -d'=' -f2)
    # Se nao retornar nenhum numero então...
    if ! [[ $UPDATELIST_YESNO =~ '^[0-9]+$' ]] ; then
       UPDATELIST_YESNO=-1
    fi  
  fi   
done

if [ $UPDATELIST_YESNO -lt 0 ] ; then
  echo "Gostaria de atualizar a lista de VMs para backup, se sim "
  echo "uma nova lista será gravada, caso contrário apenas exibira a consulta atual."
  do_confirmar "Gostaria de atualizar a lista de VMs para backup? (sim ou nao)"
  if [[ $? -eq 0 ]]; then 
    UPDATELIST_YESNO=1
  fi  
fi

if [ $ONLY_LOCAL -lt 0 ] ; then
  echo "Posso incluir apenas as VMs localizadas neste servidor?"
  echo "Caso contrário, listarei VMs do pool inteiro."
  do_confirmar "Incluir apenas as VMs localizadas neste servidor? (sim ou nao)"
  if [[ $? -eq 0 ]]; then 
    ONLY_LOCAL=1
  fi
fi

if [ $HALTED_YESNO -lt 0 ] ; then
  do_confirmar "Posso incluir as VMs que talvez estejam desligadas? (sim ou nao)"
  if [[ $? -eq 0 ]]; then 
    HALTED_YESNO=1
  fi
fi

if [ $UPDATELIST_YESNO -lt 0 ] ; then
  do_confirmar "Quer editar a lista que será gerada? (sim ou nao)"
  if [[ $? -eq 0 ]]; then 
    EDIT_YESNO=1
  fi  
fi

# determinando o espaço necessário para guardar o backup das VMs
xe_param=" is-control-domain=false is-a-snapshot=false power-state=running params=name-label "
[ $ONLY_LOCAL -gt 0 ] && xe_param="$xe_param resident-on=$_HOST_UUID " 
xe vm-list $xe_param |cut -d':' -f2|grep -v '^$'|tr -d '^ ' > "$_TMP_FILE"
[ $HALTED_YESNO -gt 0 ] && xe vm-list is-control-domain=false is-a-snapshot=false power-state=halted params=name-label|cut -d':' -f2|grep -v '^$'|tr -d '^ ' >> "$_TMP_FILE"
# editando previamente a lista para remover/adicionar VMs
if [ $EDIT_YESNO -gt 0 ] ; then
  echo "===================================================================="
  echo "Vou apresentar a lista atual de VMs, mantenha apenas as VMs"
  echo "que deseja a manutenção dos backups."
  echo "===================================================================="  
  press_enter_to_continue;
  nano "$_TMP_FILE"
fi
space_required=0
space_required=$(space_estimate "$_BACKUP_LIST")
#space_required=$($_SCRIPT_XENBACKUPESTIMATE "$_BACKUP_LIST"|grep "Total estimado"|cut -d':' -f2|cut -d'G' -f1|tr -d ' ')
# Se nao retornar nenhum numero então...
if ! [[ $space_required =~ '^[0-9]+$' ]] ; then
   echo "Não foi possivel calcular o tamanho requerido: $space_required" >&2
   echo "Variavel [space_required] não é um numero." >&2
   exit 2
fi  
echo "===================================================================="
echo "Espaço necessário para cada sessão de backup: $space_required GB."
echo "===================================================================="
if [ $UPDATELIST_YESNO -gt 0 ]; then
  [ -f "$_BACKUP_LIST" ] && rm -f "$_BACKUP_LIST" 
  echo "teste"
  echo "# O tamanho do backup para a lista abaixo foi estimado em $space_required GB" 2>&1 | tee "$_BACKUP_LIST"
  echo "# O sistema se encarregará de limpar os backups mais antigos" 2>&1 | tee -a "$_BACKUP_LIST"
  echo "# do disco de backup para que haja espaço suficiente para o" 2>&1 | tee -a "$_BACKUP_LIST"
  echo "# backup seguinte" 2>&1 | tee -a "$_BACKUP_LIST"
  echo "# Portanto, sempre verifique que haja espaço suficiente para" 2>&1 | tee -a "$_BACKUP_LIST"
  echo "# manter pelo menos 2 sessoes." 2>&1 | tee "$_BACKUP_LIST"
  echo "# Pois se o ultimo backup falhar, a sessao anterior seria mantida." 2>&1 | tee -a "$_BACKUP_LIST"
  while read LINHA ; do
    vm_existe=0
    vm_name=`semremarks "$LINHA"`
    [ "$vm_name" != "" ] && vm_existe=$(xe vm-list|grep "$vm_name"|wc -l)
    [ "$vm_existe" -gt 0 ] && echo "$vm_name"  2>&1 | tee -a "$_BACKUP_LIST"
  done < "$_TMP_FILE"
else
  cat "$_TMP_FILE"  
fi
[ -f "$_TMP_FILE" ] && rm -f "$_TMP_FILE"

