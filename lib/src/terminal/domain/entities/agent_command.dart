typedef CommandAction = Future<int> Function(List<String> arguments);

class AgentCommand {
  final String name;
  final String description;
  final CommandAction action;

  const AgentCommand({required this.name, required this.description, required this.action});
}
