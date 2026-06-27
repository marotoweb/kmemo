// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kmemo/database/database.dart';
import 'package:kmemo/providers/memo_provider.dart';
import 'package:kmemo/main.dart';

void main() {
  testWidgets('kMemo smoke test', (WidgetTester tester) async {
    // Cria uma instância isolada em memória do Drift exclusiva para o ambiente de testes
    final database = AppDatabase();

    // Constrói a aplicação injetando os mocks necessários para simular a árvore do main.dart
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          ChangeNotifierProvider<MemoProvider>(
            create: (_) => MemoProvider(database),
          ),
        ],
        child:
            const MyApp(), // Correção: Uso da classe correta definida no main.dart
      ),
    );

    // Aguarda o processamento dos frames iniciais e carregamento assíncrono da BD
    await tester.pump();

    // Verificar se o título da app aparece no AppBar
    expect(find.text('kMemo'), findsOneWidget);

    // Verificar se o botão de adicionar (+) existe no ecrã principal
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
