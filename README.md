# bash-xenserver
<p>Conjunto de scripts bash para adminstrar servidores XENSERVER.<br/>
Backup em discos externos, onde cada disco é inicializado e não pode um disco ser usado para outro servidor xen, se isso acontecer o disco será rejeitado.<br/>
As operações completas capaz de faxer são:</p>
*  Realizar o backup completo agora<br/>
*  Observar se há backup em andamento<br/>
*  Observar se a mídia de backup está online<br/>
*  Listar as VMs existentes<br/>
*  Editar as VMs que serão copiadas para a mídia de backup<br/>
*  Editar lista de discos aceitos como mídia de backup<br/>
*  Limpar Backups antigos<br/>
*  Limpar snaphosts<br/>
*  Checar o disco de backup e corrigir<br/>
*  Enviar listagem da mídia de backup por email<br/>
*  Editar agendamentos<br/>
*  Testar o acesso a internet<br/>
*  Testar o envio de email<br/>
<p>Mais importante que as funcionalidades do menu acima, são as funções contidas na biblioteca.</p>
