import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmemo/models/search_highlight.dart';

void main() {
  const base = TextStyle(fontSize: 13, color: Colors.black);

  group('buildHighlightedSpans', () {
    test('empty query returns a single span', () {
      final spans = buildHighlightedSpans(text: 'Hello World', query: '', baseStyle: base);
      expect(spans.length, 1);
      expect(spans.first.text, 'Hello World');
    });

    test('whitespace-only query returns a single span', () {
      final spans = buildHighlightedSpans(text: 'Hello World', query: '   ', baseStyle: base);
      expect(spans.length, 1);
    });

    test('single match is split into three spans', () {
      final spans = buildHighlightedSpans(text: 'abc def ghi', query: 'def', baseStyle: base);
      expect(spans.length, 3);
      expect(spans[0].text, 'abc ');
      expect(spans[1].text, 'def');
      expect(spans[2].text, ' ghi');
    });

    test('highlights every occurrence (case-insensitive)', () {
      final spans = buildHighlightedSpans(text: 'Foo bar foo Foo', query: 'foo', baseStyle: base);
      // Foo |  bar  |  |  |  (4 spans: match, gap, match, gap, match)
      final matched = spans.where((s) => s.text == 'Foo' || s.text == 'foo').toList();
      expect(matched.length, 3);
    });

    test('no match returns the whole text as one span', () {
      final spans = buildHighlightedSpans(text: 'abcdef', query: 'zzz', baseStyle: base);
      expect(spans.length, 1);
      expect(spans.first.text, 'abcdef');
    });

    test('match at the very start', () {
      final spans = buildHighlightedSpans(text: 'hello world', query: 'hello', baseStyle: base);
      expect(spans[0].text, 'hello');
      expect(spans[1].text, ' world');
    });

    test('match at the very end', () {
      final spans = buildHighlightedSpans(text: 'hello world', query: 'world', baseStyle: base);
      expect(spans[0].text, 'hello ');
      expect(spans[1].text, 'world');
    });
  });
}
