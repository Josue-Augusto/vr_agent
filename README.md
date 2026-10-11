# VR Agent

Agente responsável por gerenciar o PowerTools. Sem argumentos, inicia o ciclo
de vida do agente. Os comandos abaixo formam a paleta CLI:

```text
vr_agent -a -version
vr_agent -a -info
vr_agent -p -check
vr_agent -p -update
vr_agent -a -update -crontab
vr_agent -a -crontab
vr_agent -p -backup [argumentos adicionais]
vr_agent -a -help
```

Todos os comandos CLI devem indicar o destino: `-a` executa um comando nativo
do agente e `-p` encaminha a flag e os argumentos seguintes ao PowerTools. Por
exemplo, `vr_agent -a -info` exibe nome, versão e plataforma detectada, enquanto
`vr_agent -p -info` encaminha `-info` ao PowerTools. As plataformas suportadas
são Windows e Linux. O PowerTools é sempre localizado em
`C:\vr\agent\PowerTools.exe` no Windows ou `/vr/agent/PowerTools` no Linux; sua
saída e seu código de retorno são repassados pelo agente. `-a -update -crontab` sincroniza as tarefas
do servidor configurado em `.env` para o arquivo criptografado `.crontab`;
`-a -crontab` lista as tarefas locais. No modo contínuo (sem argumentos), o agente executa as
tarefas habilitadas no `.crontab` conforme expressões cron de cinco campos e
seus fusos IANA. O comando da tarefa começa com `-a` para comandos nativos
suportados pelo agente (`-a -version`, `-a -info`) ou `-p` para encaminhar a flag
ao PowerTools (`-p -backup`). Cada tentativa e suas saídas são registradas em
`agent_task_runs`; estado e erros recentes são atualizados em `agent_tasks`.
Sincronize o arquivo com `-a -update -crontab` antes de iniciar o modo contínuo.
Tarefas com `run_as_user` definido falham explicitamente, pois essa opção ainda
não é suportada.
O sistema operacional é identificado centralmente por `PlatformInfo`, no
serviço de plataforma da camada `data`.

A camada de conexão solicita `.env` pelo contrato `FilePathRepository`; a
implementação do repositório determina o diretório base e encapsula leitura,
descriptografia e decodificação JSON.

## Adicionar um comando

1. Implemente regras de aplicação em um caso de uso em `lib/src/domain/usecases/`
   e declare as dependências necessárias por interfaces em
   `lib/src/domain/repositories/`.
2. Implemente essas interfaces em `lib/src/data/repositories/`; injete
   datasources e serviços por construtor.
3. Adicione a ação de apresentação em `lib/src/presentation/cli/agent_command.dart`
   e registre um `AgentCommand` em `createDefaultCommandPalette`, em
   `lib/src/presentation/cli/command_registry.dart`.
4. Os comandos da CLI recebem `-a` para execução nativa ou `-p` para
   encaminhamento ao PowerTools; neste último caso, passe explicitamente a flag
   do comando ao executável.
5. Conecte o caso de uso e as implementações no composition root
   `lib/src/di/injection.dart`; a CLI não deve criar dependências concretas.
6. Adicione testes de roteamento, casos de uso e implementação em `test/`.

O código da aplicação segue a estrutura `lib/src/{domain,data,presentation,di}`.
O domínio define entidades, contratos e casos de uso sem depender de
infraestrutura; `data` implementa os contratos; `presentation` cuida da saída e
do roteamento CLI; `di` conecta as implementações. As ações do PowerTools
recebem argumentos separados (sem interpretação por shell), e seu código de
saída é preservado.
