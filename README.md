# bash-xenserver
<p>Conjunto de scripts bash para adminstrar servidores XENSERVER.</p>
<p>Backup em discos externos, onde cada disco é inicializado e não pode um disco ser <p>usado para outro servidor xen, se isso acontecer o disco será rejeitado.</p>
<p>As operações completas capaz de faxer são:</p>
  Realizar o backup completo agora
  Observar se há backup em andamento
  Observar se a mídia de backup está online
  Listar as VMs existentes
  Editar as VMs que serão copiadas para a mídia de backup
  Editar lista de discos aceitos como mídia de backup
  Limpar Backups antigos
  Limpar snaphosts
  Checar o disco de backup e corrigir
  Enviar listagem da mídia de backup por email
  Editar agendamentos
  Testar o acesso a internet
  Testar o envio de email
<p>Mais importante que as funcionalidades do menu acima, são as funções contidas na biblioteca.</p>
