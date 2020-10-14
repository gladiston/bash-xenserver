# bash-xenserver
Conjunto de scripts bash para adminstrar servidores XENSERVER.
Backup em discos externos, onde cada disco é inicializado e não pode um disco ser usado para outro servidor xen, se isso acontecer o disco será rejeitado.
As operações completas capaz de faxer são:
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
Mais importante que as funcionalidades do menu acima, são as funções contidas na biblioteca.
