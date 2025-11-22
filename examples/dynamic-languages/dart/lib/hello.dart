// Dart example demonstrating spec-based language support

void main() {
  print(greet());
  print(greet('Builder'));
  print('Language: Dart (spec-based)');
  print('Handler: SpecBasedHandler (automatic)');
}

String greet([String name = 'World']) {
  return 'Hello, $name!';
}

