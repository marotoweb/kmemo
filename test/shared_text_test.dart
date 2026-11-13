// test/shared_text_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/models/shared_text.dart';

void main() {
  group('parseSharedText', () {
    test('plain text without markers is not turned into a checklist', () {
      const text =
          'O tipo de transação Deposito pode ter as seguintes tags: '
          'Reword, Mining, Airdrop, Fork, Cashback, Lending Interest, Salary,\n'
          'Other income, Realized P&L, Margin Loan, Loan, Fee Refound.\n'
          '\n'
          'O tipo withawall pode ter as seguintes tags: Gift, Donation, Lost, '
          'Loan fee, Margin fee, Costa, Tax, Loan Repayment, Margin Repaiment, '
          'Realized P&L\n'
          '\n'
          'O tipo trade apenas tem a tag: Swap\n'
          '\n'
          'O filtro de período personalizado de data não faz qualquer efeito '
          'na APP quando selecionado';

      final note = parseSharedText(text, fallbackTitle: 'Nota partilhada');

      expect(
        note.title,
        'O tipo de transação Deposito pode ter as seguintes tags: Reword, '
        'Mining, Airdrop, Fork, Cashback, Lending Interest, Salary,',
      );
      expect(
        note.blocks.every((b) => b.type == SharedTextBlockType.text),
        isTrue,
      );
      expect(note.blocks.length, 4);
      expect(
        note.blocks.first.text,
        'Other income, Realized P&L, Margin Loan, Loan, Fee Refound.',
      );
      expect(
        note.blocks.last.text,
        'O filtro de período personalizado de data não faz qualquer efeito '
        'na APP quando selecionado',
      );
    });

    test('checklist markers produce checklist blocks and keep checked state', () {
      const text =
          '[X] Traduzir walletTypes\n'
          '[ ] Opção 1: Solidificar a experiência\n'
          'A lógica de backend está pronta.\n'
          '\n'
          '\t[ ] Acção 1.1: Validação de formulário\n'
          'Compra de BTC com 100 EUR\n'
          '[x] Importações CSV Coinbase\n'
          '[X]  ';

      final note = parseSharedText(text, fallbackTitle: 'Nota partilhada');

      expect(note.title, 'Nota partilhada');
      expect(note.blocks.length, 4);
      expect(note.blocks[0].type, SharedTextBlockType.checklist);
      expect(note.blocks[0].text, 'Traduzir walletTypes');
      expect(note.blocks[0].checked, isTrue);
      expect(note.blocks[1].checked, isFalse);
      // Lines without a marker continue the previous item instead of
      // becoming a new checkbox.
      expect(
        note.blocks[1].text,
        'Opção 1: Solidificar a experiência\nA lógica de backend está pronta.',
      );
      expect(
        note.blocks[2].text,
        'Acção 1.1: Validação de formulário\nCompra de BTC com 100 EUR',
      );
      expect(note.blocks[3].text, 'Importações CSV Coinbase');
      expect(note.blocks[3].checked, isTrue);
    });

    test('title line is kept when the checklist starts later', () {
      const text = 'Lista de tarefas\n\n[ ] Primeira\n[ ] Segunda';

      final note = parseSharedText(text, fallbackTitle: 'Nota partilhada');

      expect(note.title, 'Lista de tarefas');
      expect(note.blocks.length, 2);
      expect(note.blocks[0].type, SharedTextBlockType.checklist);
      expect(note.blocks[0].text, 'Primeira');
      expect(note.blocks[1].text, 'Segunda');
    });

    test('plain multi-line paragraph keeps its line breaks in one block', () {
      const text = 'Título\nlinha um\nlinha dois\n\nnovo parágrafo';

      final note = parseSharedText(text, fallbackTitle: 'Nota partilhada');

      expect(note.title, 'Título');
      expect(note.blocks.length, 2);
      expect(note.blocks[0].text, 'linha um\nlinha dois');
      expect(note.blocks[1].text, 'novo parágrafo');
    });

    test('empty input falls back to the shared-note title', () {
      final note = parseSharedText('   ', fallbackTitle: 'Nota partilhada');

      expect(note.title, 'Nota partilhada');
      expect(note.blocks, isEmpty);
    });
  });
}
