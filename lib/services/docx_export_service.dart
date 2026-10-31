// lib/services/docx_export_service.dart

import 'dart:convert';
import 'package:archive/archive.dart';

/// A single note section inside the exported document.
class DocxSection {
  final String title;
  final String body;
  const DocxSection({required this.title, required this.body});
}

/// Builds minimal but valid .docx (OOXML) files from note content.
///
/// The structure follows the parts Word expects: content types, package
/// relationships, document, styles and doc properties. All XML is encoded as
/// UTF-8 bytes so accented characters are preserved.
class DocxExportService {
  static List<int> buildDocx({required List<DocxSection> sections}) {
    final archive = Archive();

    void addXml(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addXml('[Content_Types].xml', _contentTypesXml());
    addXml('_rels/.rels', _relsXml());
    addXml('docProps/core.xml', _corePropsXml(sections));
    addXml('docProps/app.xml', _appXml());
    addXml('word/_rels/document.xml.rels', _documentRelsXml());
    addXml('word/document.xml', _documentXml(sections));
    addXml('word/styles.xml', _stylesXml());

    final zipBytes = ZipEncoder().encode(archive);
    return zipBytes ?? [];
  }

  static String _contentTypesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
  }

  static String _relsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';
  }

  static String _documentRelsXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
  }

  static String _corePropsXml(List<DocxSection> sections) {
    final now = DateTime.now().toUtc().toIso8601String();
    final title = _escapeXml(
      sections.length == 1 && sections.first.title.isNotEmpty
          ? sections.first.title
          : 'kMemo',
    );
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>$title</dc:title>
  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>
</cp:coreProperties>''';
  }

  static String _appXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>kMemo</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <LinksUpToDate>false</LinksUpToDate>
  <SharedDoc>false</SharedDoc>
  <HyperlinksChanged>false</HyperlinksChanged>
  <AppVersion>1.0</AppVersion>
</Properties>''';
  }

  static String _stylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="200" w:line="276" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
    <w:name w:val="Normal"/>
    <w:pPr><w:spacing w:after="200" w:line="276" w:lineRule="auto"/></w:pPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:pPr><w:spacing w:after="200" w:line="276" w:lineRule="auto"/></w:pPr>
    <w:rPr><w:sz w:val="40"/><w:b/></w:rPr>
  </w:style>
</w:styles>''';
  }

  static String _documentXml(List<DocxSection> sections) {
    final buffer = StringBuffer();
    for (final section in sections) {
      buffer.write('<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t xml:space="preserve">${_escapeXml(section.title)}</w:t></w:r></w:p>');
      for (final line in _escapeXml(section.body).split('\n')) {
        buffer.write('<w:p><w:r><w:t xml:space="preserve">${line.isEmpty ? ' ' : line}</w:t></w:r></w:p>');
      }
      // Blank separator paragraph between notes.
      if (sections.length > 1) {
        buffer.write('<w:p><w:r><w:t xml:space="preserve"> </w:t></w:r></w:p>');
      }
    }

    final bodyXml = buffer.toString();
    const sectPr = '<w:sectPr><w:type w:val="nextPage"/><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1800" w:bottom="1440" w:left="1800"/></w:sectPr>';

    // sectPr must live inside the w:pPr of the final paragraph.
    String bodyWithSectPr;
    final lastIdx = bodyXml.lastIndexOf('<w:p>');
    if (lastIdx >= 0) {
      const openTag = '<w:p>';
      final insertAt = lastIdx + openTag.length;
      bodyWithSectPr = bodyXml.replaceRange(
        insertAt,
        insertAt,
        '<w:pPr>$sectPr</w:pPr>',
      );
    } else {
      bodyWithSectPr = '<w:p><w:pPr>$sectPr</w:pPr><w:r><w:t xml:space="preserve"></w:t></w:r></w:p>';
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $bodyWithSectPr
  </w:body>
</w:document>''';
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
