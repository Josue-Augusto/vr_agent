---
name: clean-architecture
description: Organiza projetos Dart puro com Clean Architecture, baixo acoplamento e injeção de dependências, sem Flutter.
---

# Clean Architecture — Dart puro

Use esta estrutura como padrão, adaptando apenas quando necessário:

````
vr_agent
   ├─ .agents
   │  └─ skills
   │     ├─ clean-architecture
   │     └─ project-tree
   ├─ bin
   │  └─ main.dart
   ├─ lib
   │  ├─ src
   │  │  ├─ connection
   │  │  │  ├─ data
   │  │  │  │  ├─ datasources
   │  │  │  │  │  └─ postgres_connection_datasource.dart
   │  │  │  │  ├─ models
   │  │  │  │  │  └─ connection_model.dart
   │  │  │  │  └─ repositories
   │  │  │  │     └─ connection_repository_impl.dart
   │  │  │  └─ domain
   │  │  │     ├─ entitie
   │  │  │     │  └─ connection_config.dart
   │  │  │     └─ repositories
   │  │  │        └─ connection_repository.dart
   │  │  ├─ core
   │  │  │  ├─ extensions
   │  │  │  │  └─ string_extension.dart
   │  │  │  └─ tools
   │  │  │     ├─ encrypt.dart
   │  │  │     └─ platform_info.dart
   │  │  ├─ di
   │  │  │  └─ injection.dart
   │  │  ├─ filePath
   │  │  │  ├─ data
   │  │  │  │  ├─ datasources
   │  │  │  │  │  └─ local_file_path_datasource.dart
   │  │  │  │  └─ repositories
   │  │  │  │     └─ file_path_repository_impl.dart
   │  │  │  └─ domain
   │  │  │     ├─ entities
   │  │  │     └─ repositories
   │  │  │        └─ file_path_repository.dart
   │  │  └─ terminal
   │  │     ├─ data
   │  │     │  ├─ constants
   │  │     │  │  └─ app_constants.dart
   │  │     │  └─ repositories
   │  │     │     └─ power_tools_repository_impl.dart
   │  │     ├─ domain
   │  │     │  ├─ entities
   │  │     │  │  ├─ agent_command.dart
   │  │     │  │  ├─ agent_info.dart
   │  │     │  │  └─ power_tools_result.dart
   │  │     │  ├─ repositories
   │  │     │  │  └─ power_tools_repository.dart
   │  │     │  └─ usecases
   │  │     │     ├─ close_agent.dart
   │  │     │     ├─ get_agent_info.dart
   │  │     │     ├─ run_power_tools_command.dart
   │  │     │     └─ start_agent.dart
   │  │     └─ presentation
   │  │        └─ cli
   │  │           ├─ command_registry.dart
   │  │           ├─ help_command.dart
   │  │           ├─ info_command.dart
   │  │           ├─ power_tools_command.dart
   │  │           └─ version_command.dart
   │  └─ vr_agent.dart
   ├─ LICENCE
   └─ pubspec.yaml
test/
````

## Responsabilidades

- **data:** implementações dos repositórios, models, datasources e constantes de infraestrutura.
- **domain:** entidades, contratos dos repositórios, casos de uso e regras de negócio.
- **presentation:** interface de terminal/CLI, argumentos, comandos e formatação da saída.
- **di:** instancia e conecta as dependências da aplicação.
- **bin:** ponto de entrada que inicia a aplicação.

## Regras

1. Dart puro: não usar Flutter nem dependências específicas dele.
2. O domínio não depende de `data`, `presentation` ou bibliotecas externas de infraestrutura.
3. `data/repositories` implementa os contratos definidos em `domain/repositories`.
4. Casos de uso recebem suas dependências por construtor; não criam implementações concretas internamente.
5. A CLI chama casos de uso; não contém regras de negócio nem acessa datasources diretamente.
6. Mantenha baixo acoplamento e responsabilidade única, sem criar abstrações desnecessárias.
7. Use null safety e tratamento de erros consistente.
8. Teste entidades e casos de uso separadamente dos recursos externos.
9. Respeite a versão do Dart declarada no `pubspec.yaml`.
10. Ao finalizar alterações, execute `dart format .`, `dart analyze` e `dart test`, quando disponíveis.
