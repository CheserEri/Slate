List<String> parseDiskShares(String output) {
  return output
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('Disk|'))
      .map((line) => line.split('|'))
      .where((parts) => parts.length >= 2)
      .map((parts) => parts[1].trim().replaceAll(r'\$', r'$'))
      .where((name) => name.isNotEmpty)
      .toList();
}

String normalizeRelativeSmbPath(String value) {
  var normalized = value.trim().replaceAll('\\', '/');
  normalized = normalized.replaceAll(RegExp('/+'), '/');
  normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
  normalized = normalized.replaceFirst(RegExp(r'/+$'), '');
  return normalized;
}
