---
name: project-tree
description: Generates a complete directory tree of the workspace, respecting ignore patterns. Useful for AI context and project onboarding.
risk: low
source: local
date_added: '2026-10-10'
---

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
````
