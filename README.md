# VR Agent

Agente responsável por gerenciar o PowerTools. Sem argumentos, inicia o ciclo
de vida do agente. Os comandos abaixo formam a paleta CLI:

```text
vr_agent -a -version
vr_agent -a -info
vr_agent -p -check
vr_agent -p -update
vr_agent -a -update -powertools
vr_agent -a -update -crontab
vr_agent -a -crontab
vr_agent -a -install -powertools
vr_agent -a -install -service
vr_agent -p -backup
vr_agent -a -help
vr_agent --service
```

Todos os comandos CLI devem indicar o destino: `-a` executa um comando nativo
do agente e `-p` encaminha a flag e os argumentos seguintes ao PowerTools. Por
exemplo, `vr_agent -a -info` exibe nome, versão e plataforma detectada, enquanto
`vr_agent -p -info` encaminha `-info` ao PowerTools. As plataformas suportadas
são Windows e Linux. O PowerTools é sempre localizado em
`C:\vr\agent\PowerTools.exe` no Windows ou `/vr/agent/PowerTools` no Linux; sua
saída e seu código de retorno são repassados pelo agente.
`-a -update -powertools` atualiza o PowerTools; `-a -update -crontab` sincroniza as tarefas
do servidor configurado em `.env` para o arquivo criptografado `.crontab`;
`-a -crontab` lista as tarefas locais. No modo contínuo (sem argumentos), o agente executa as
tarefas habilitadas no `.crontab` conforme expressões cron de cinco campos e
seus fusos IANA. O comando da tarefa começa com `-a` para comandos nativos
suportados pelo agente (`-a -version`, `-a -info`) ou `-p` para encaminhar a flag
ao PowerTools (`-p -backup`). Cada tentativa e suas saídas são registradas em
`agent_task_runs` quando iniciadas pelo agendador; estado e erros recentes são
atualizados em `agent_tasks`. Os horários dos logs usam o fuso configurado na
tarefa, e cada registro em `agent_task_runs` guarda esse identificador na coluna
`timezone`; `started_at` e `finished_at` continuam como `TIMESTAMPTZ` (instantes
absolutos) e podem ser exibidos no fuso da tarefa usando essa coluna. Em bancos
existentes, adicione a coluna antes de atualizar o agente:

```sql
ALTER TABLE agent_task_runs
    ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) NOT NULL DEFAULT 'UTC';
```

Chamadas `-p` feitas diretamente na CLI exibem a resposta do PowerTools, mas não
criam um registro de tarefa agendada.
Sincronize o arquivo com `-a -update -crontab` antes de iniciar o modo contínuo.
Sem argumentos, ou com `--service`, o agente permanece ativo e aguarda os próximos
minutos agendados; quando não há tarefas habilitadas, permanece ocioso. As tarefas
são verificadas no limite de cada minuto, e alterações no `.crontab` são carregadas
sem reiniciar o serviço. Minutos em que o agente estava parado não são reprocessados.
Tarefas com `run_as_user` definido falham explicitamente, pois essa opção ainda
não é suportada.
O sistema operacional é identificado centralmente por `PlatformInfo`, no
serviço de plataforma da camada `data`.

## Executar como serviço

Compile/distribua o executável Dart AOT como `vr_agent` (Linux) ou
`vr_agent.exe` (Windows) no diretório `/vr/agent` ou `C:\vr\agent`, junto dos
arquivos de configuração necessários. O diretório de trabalho do serviço deve
ser esse diretório; a aplicação lê `.env` e `.crontab` dali.

### Linux com systemd

O serviço executa como `root` para poder iniciar as tarefas com o usuário indicado
em `run_as_user` por meio de `runuser`. Isso concede privilégios elevados ao
agente: restrinja quem pode alterar as tarefas e os arquivos `.env`/`.crontab`.
Instale a unidade incluída no repositório:

```sh
sudo install -m 0644 deploy/systemd/vr-agent.service /etc/systemd/system/vr-agent.service
sudo systemctl daemon-reload
sudo systemctl enable --now vr-agent.service
```

O serviço reinicia após uma falha e encerra de forma graciosa em `SIGTERM`.
Garanta que `runuser` esteja instalado e que cada usuário configurado exista no
sistema. Sem `run_as_user`, as tarefas herdam a identidade root do serviço.
Consulte os logs com `sudo journalctl -u vr-agent.service -f`. A unidade usa
`/vr/agent/vr_agent`; ajuste `ExecStart` se o executável estiver em outro local.

### Windows 10/11 com NSSM

No diretório raiz do projeto, compile o executável e execute-o em um terminal
PowerShell como administrador:

```powershell
New-Item -ItemType Directory -Path C:\vr\agent -Force
dart compile exe bin\main.dart -o C:\vr\agent\vr_agent.exe
C:\vr\agent\vr_agent.exe -a -install -service
```

O comando cria `C:\vr\agent\install-service.ps1`, instala NSSM pelo `winget`
se ele ainda não estiver disponível, registra/inicia `VRAgent` e configura
inicialização automática, reinício após falha, parada por Ctrl+C e rotação de
logs em `C:\vr\agent\logs`. O script gerado também pode ser executado diretamente
como administrador. Se não houver `winget`, instale NSSM manualmente e use
`.\install-service.ps1 -NssmPath <caminho-do-nssm.exe>`.
Uma agenda `.crontab` vazia é iniciada como uma lista sem tarefas.
Se a inicialização falhar, o instalador informa o estado do serviço e as últimas
linhas dos logs `service-error.log` e `service-out.log`. Para consultar o NSSM
com o comando `nssm` após instalá-lo pelo `winget`, abra um novo PowerShell para
carregar a alteração de `PATH`.

No Linux, compile o executável, copie-o para `/vr/agent/vr_agent` e instale/inicie
com:

```sh
dart compile exe bin/main.dart -o /tmp/vr_agent
sudo install -D -m 0755 /tmp/vr_agent /vr/agent/vr_agent
sudo /vr/agent/vr_agent -a -install -service
```

O comando grava `/etc/systemd/system/vr-agent.service`, recarrega o systemd,
habilita o serviço para iniciar com o sistema e inicia/reinicia o processo.
Consulte os logs com
`sudo journalctl -u vr-agent.service -f`. O processo do serviço executa
`vr_agent --service`; esta forma continua sendo a usada pelo próprio NSSM e
systemd para iniciar o agente. No Windows, `run_as_user` não
altera a identidade de execução: configure a conta do serviço nas propriedades
de Log on do Windows Services/NSSM. Recomenda-se deixar `run_as_user` vazio nas
tarefas Windows. O serviço executa
`vr_agent.exe --service`; os comandos manuais existentes continuam disponíveis
sem alteração, por exemplo `vr_agent.exe -a -version` e
`vr_agent.exe -p -backup`.

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
