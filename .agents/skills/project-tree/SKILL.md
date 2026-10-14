---
name: project-tree
description: Generates a complete directory tree of the workspace, respecting ignore patterns. Useful for AI context and project onboarding.
risk: low
source: local
date_added: '2026-10-14'
---

````
vr_agent
   ├─ .agents
   │  └─ skills
   │     ├─ clean-architecture
   │     └─ project-tree
   ├─ bin
   │  ├─ main.dart
   │  └─ vr_agent.exe
   ├─ deploy
   │  └─ systemd
   │     └─ vr-agent.service
   ├─ lib
   │  ├─ core
   │  │  └─ constants
   │  │     └─ app_constants.dart
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
   │  │  ├─ crontab
   │  │  │  ├─ data
   │  │  │  │  ├─ repositories
   │  │  │  │  │  ├─ agent_task_command_runner.dart
   │  │  │  │  │  └─ postgres_crontab_repository.dart
   │  │  │  │  └─ scheduler
   │  │  │  │     ├─ cron_expression.dart
   │  │  │  │     └─ local_crontab_scheduler.dart
   │  │  │  ├─ domain
   │  │  │  │  ├─ entities
   │  │  │  │  │  ├─ agent_task.dart
   │  │  │  │  │  └─ task_run_result.dart
   │  │  │  │  ├─ repositories
   │  │  │  │  │  ├─ crontab_repository.dart
   │  │  │  │  │  └─ task_command_runner.dart
   │  │  │  │  └─ usecases
   │  │  │  │     ├─ run_crontab_task.dart
   │  │  │  │     └─ sync_crontab.dart
   │  │  │  └─ presentation
   │  │  │     └─ cli
   │  │  │        ├─ crontab_command.dart
   │  │  │        └─ update_crontab_command.dart
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
   │  │  ├─ install
   │  │  │  ├─ domain
   │  │  │  │  ├─ entities
   │  │  │  │  │  └─ power_tools_install_result.dart
   │  │  │  │  └─ usecases
   │  │  │  │     └─ install_power_tools.dart
   │  │  │  └─ presentation
   │  │  │     └─ cli
   │  │  │        └─ install_power_tools_command.dart
   │  │  ├─ terminal
   │  │  │  ├─ data
   │  │  │  │  └─ repositories
   │  │  │  │     └─ power_tools_repository_impl.dart
   │  │  │  ├─ domain
   │  │  │  │  ├─ entities
   │  │  │  │  │  ├─ agent_command.dart
   │  │  │  │  │  ├─ agent_info.dart
   │  │  │  │  │  └─ power_tools_result.dart
   │  │  │  │  ├─ repositories
   │  │  │  │  │  └─ power_tools_repository.dart
   │  │  │  │  └─ usecases
   │  │  │  │     ├─ close_agent.dart
   │  │  │  │     ├─ get_agent_info.dart
   │  │  │  │     ├─ run_power_tools_command.dart
   │  │  │  │     └─ start_agent.dart
   │  │  │  └─ presentation
   │  │  │     └─ cli
   │  │  │        ├─ command_registry.dart
   │  │  │        ├─ help_command.dart
   │  │  │        ├─ info_command.dart
   │  │  │        ├─ power_tools_command.dart
   │  │  │        └─ version_command.dart
   │  │  └─ update
   │  │     ├─ data
   │  │     │  └─ repositories
   │  │     │     ├─ google_drive_power_tools_binary_installer.dart
   │  │     │     └─ postgres_power_tools_update_repository.dart
   │  │     ├─ domain
   │  │     │  ├─ entities
   │  │     │  │  ├─ power_tools_release.dart
   │  │     │  │  └─ power_tools_update_result.dart
   │  │     │  ├─ repositories
   │  │     │  │  ├─ power_tools_binary_installer.dart
   │  │     │  │  └─ power_tools_update_repository.dart
   │  │     │  └─ usecases
   │  │     │     └─ update_power_tools.dart
   │  │     └─ presentation
   │  │        └─ cli
   │  │           └─ update_power_tools_command.dart
   │  └─ vr_agent.dart
   ├─ LICENCE
   ├─ power_tools
   └─ pubspec.yaml
````
