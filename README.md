# VR Agent

Agente responsável por gerenciar o PowerTools. Sem argumentos, inicia o ciclo
de vida atual do agente. Os comandos abaixo formam a paleta CLI:

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
O sistema operacional é identificado centralmente em `PlatformInfo` no módulo
`filePath`.

A camada de conexão recebe a configuração como objeto JSON pelo repositório
`filePath`; a identificação da plataforma, a localização do `.env`, a leitura e
a descriptografia ficam encapsuladas nesse módulo.

## Adicionar um comando

1. Implemente a ação como uma função `Future<int> Function(List<String>)`,
   preferencialmente numa classe em `lib/cli/agent_command.dart` ou em um
   arquivo dedicado em `lib/cli/`.
2. Registre um `AgentCommand` em `createDefaultCommandPalette`, em
   `lib/cli/command_registry.dart`, definindo nome, descrição e ação.
3. Se o comando for encaminhado ao PowerTools, inclua explicitamente a flag do
   comando nos argumentos encaminhados, como nos comandos `-check`, `-update`
   e `-backup`.
4. Adicione testes de roteamento/ação em `test/command_registry_test.dart`.

O registro centralizado mantém despacho, ajuda e expansão da CLI em um só
lugar. As ações recebem argumentos separados (sem interpretação por shell), e
o seu código de saída é preservado.
