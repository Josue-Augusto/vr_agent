# VR Agent

Agente responsável por gerenciar o PowerTools. Sem argumentos, inicia o ciclo
de vida do agente. Os comandos abaixo formam a paleta CLI:

```text
vr_agent -version
vr_agent -info
vr_agent -check
vr_agent -update
vr_agent -backup [argumentos adicionais]
vr_agent -help
```

`-version` exibe o nome e a versão do agente. `-info` exibe nome, versão e
plataforma detectada (Windows ou Linux). A plataforma não é impressa
automaticamente nos demais comandos. `-check`, `-update` e `-backup` encaminham
a própria flag, além de quaisquer argumentos adicionais, ao executável
PowerTools localizado junto ao executável do VR Agent (`PowerTools.exe` no
Windows e `PowerTools` no Linux). O VR Agent repassa a saída e o código de
retorno do PowerTools. As rotinas de atualização/agenda ainda não estão
implementadas; por enquanto, esses comandos apenas delegam a execução.
O sistema operacional é identificado centralmente por `PlatformInfo`, no
serviço de plataforma da camada `data`.

A camada de conexão recebe a configuração como objeto JSON pelo contrato
`FilePathRepository`; a localização do `.env`, leitura, descriptografia e
decodificação ficam encapsuladas na implementação em `data`.

## Adicionar um comando

1. Implemente regras de aplicação em um caso de uso em `lib/src/domain/usecases/`
   e declare as dependências necessárias por interfaces em
   `lib/src/domain/repositories/`.
2. Implemente essas interfaces em `lib/src/data/repositories/`; injete
   datasources e serviços por construtor.
3. Adicione a ação de apresentação em `lib/src/presentation/cli/agent_command.dart`
   e registre um `AgentCommand` em `createDefaultCommandPalette`, em
   `lib/src/presentation/cli/command_registry.dart`.
4. Se o comando for encaminhado ao PowerTools, inclua explicitamente a flag do
   comando nos argumentos encaminhados, como nos comandos `-check`, `-update`
   e `-backup`.
5. Conecte o caso de uso e as implementações no composition root
   `lib/src/di/injection.dart`; a CLI não deve criar dependências concretas.
6. Adicione testes de roteamento, casos de uso e implementação em `test/`.

O código da aplicação segue a estrutura `lib/src/{domain,data,presentation,di}`.
O domínio define entidades, contratos e casos de uso sem depender de
infraestrutura; `data` implementa os contratos; `presentation` cuida da saída e
do roteamento CLI; `di` conecta as implementações. As ações do PowerTools
recebem argumentos separados (sem interpretação por shell), e seu código de
saída é preservado.
