---
name: project-tree
description: Generates a complete directory tree of the workspace, respecting ignore patterns. Useful for AI context and project onboarding.
risk: low
source: local
date_added: '2026-10-09'
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
   │  ├─ connection
   │  │  ├─ data
   │  │  │  ├─ datasources
   │  │  │  │  └─ local_connection_datasource_impl.dart
   │  │  │  ├─ models
   │  │  │  │  └─ connection_model.dart
   │  │  │  └─ repositories
   │  │  │     └─ connection_repository_impl.dart
   │  │  └─ domain
   │  │     ├─ entitie
   │  │     │  └─ connection_entity.dart
   │  │     └─ repositories
   │  │        └─ connection_repository.dart
   │  ├─ core
   │  │  ├─ extensions
   │  │  │  └─ string_extension.dart
   │  │  ├─ feature
   │  │  │  └─ filePath
   │  │  │     ├─ data
   │  │  │     │  ├─ datasources
   │  │  │     │  │  └─ local_file_path_datasource.dart
   │  │  │     │  └─ repositories
   │  │  │     │     └─ file_path_repository_impl.dart
   │  │  │     └─ domain
   │  │  │        └─ repositories
   │  │  │           └─ file_path_repository.dart
   │  │  └─ tools
   │  │     ├─ clip_drop.dart
   │  │     ├─ constants.dart
   │  │     └─ encrypt.dart
   │  └─ vr_agent.dart
   ├─ LICENCE
   └─ pubspec.yaml
````
