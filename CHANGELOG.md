# Changelog

## Não lançado

### ✨ Novidades
- **Opções do editor (Definições → Editor):** quebra de linha automática em títulos e itens de lista, e rasura opcional dos itens de checklist marcados.
- **Reordenação de listas:** arrastar itens de checklist (handle `⋮≡`) para reordenar, com persistência automática.
- **Pré-visualização de links:** URLs no corpo da nota ficam sublinhados. Ao tocar num link: Pré-visualizar, Abrir ou Editar. A pré-visualização mostra miniatura, título e domínio (Open Graph).
  - Sem pedidos automáticos: os metadados só são obtidos após ação do utilizador.
  - Cache local por nota (não sincronizada); a pré-visualização reaparece ao reabrir a nota.
  - Menu do cartão: Abrir URL, Copiar URL, Remover (com ação **Anular**).
  - A home mostra a pré-visualização no fundo do cartão da nota.
- **Widget do ecrã principal:** a pré-visualização respeita as opções do editor (quebra de linha e rasura).

### 🛠️ Alterações
- **Adicionar link:** insere o URL no corpo da nota (deixa de usar os chips de links).
- **Comentários em inglês:** todos os comentários de código-fonte (Dart, Kotlin, XML, testes) traduzidos para inglês.

## 0.1.6
# 🚀 Novidades da Versão 0.1.6 — Primeira Release Pública

Esta versão marca o lançamento público do **kMemo**, uma aplicação de notas minimalista e focada na produtividade, desenvolvida em Flutter com persistência local SQLite (Drift).

### ✨ Novidades
- **Editor baseado em blocos:** Notas compostas por blocos de texto e listas de tarefas (checklists), manipuláveis individualmente.
- **Tema claro/escuro automático:** Suporte completo com paletas de cores customizadas para ambos os temas.
- **Home Screen Widget (4×3):** Widget nativo Android que exibe as últimas notas com fundo colorido por nota, pré-visualização de texto e ícones de caixas de verificação.
- **Sincronização remota com kDrive (Infomaniak):** Envio e descarga de notas para a nuvem com encriptação AES opcional no cliente.
- **Internacionalização:** Suporte a 6 idiomas (Português, Inglês, Francês, Alemão, Italiano, Espanhol) com opção "Sistema" para seguir o idioma do dispositivo.
- **Partilha de texto:** Recebe texto partilhado de outras aplicações e cria automaticamente uma nova nota.
- **Rejeição de notas vazias:** Notas criadas mas deixadas vazias são automaticamente eliminadas ao sair, evitando acumulação de notas sem conteúdo.
- **Detecção de checkboxes no texto partilhado:** Texto partilhado com itens `[ ]` / `[X]` é convertido automaticamente em modo checklist.
- **App links:** Suporte a abertura de notas via `kmemo://note/{uuid}`.

### 🛠️ Correções e Ajustes
- **Persistência inteligente:** A nota só é guardada se houver alterações reais (dirty-checking).
- **Widget click fix:** Clicar numa nota do widget abre diretamente essa nota em modo de edição.
- **Card de ajuda kDrive:** O card de instruções só aparece na aba kDrive, reservando espaço para WebDAV.
- **Correção de avisos de lint:** Todos os avisos do analisador estático resolvidos.
- **Comentários e logs em inglês:** Todos os comentários e mensagens de debug traduzidos para inglês.

### 🔒 Segurança e Privacidade
- **Encriptação AES opcional:** As notas podem ser encriptadas no cliente antes de serem enviadas para a nuvem.
- **Offline-first:** Todas as notas são armazenadas localmente em SQLite; a sincronização é assíncrona e não bloqueia a interface.
- **Sem telemetria:** A aplicação não recolhe nem envia dados de utilização.

### 📦 Build e Distribuição
- **Ícones gerados** para Android, iOS, Web, Windows e macOS via `flutter_launcher_icons`.
- **APK de release** disponível para instalação direta.

### ⚠️ Limitações conhecidas
- **Widget Android-only:** O widget do ecrã principal é exclusivo para Android.
- **Versão Web não suportada:** A aplicação usa SQLite via FFI, que não é compatível com web.
- **WebDAV em desenvolvimento:** O seletor de protocolo está disponível, mas a implementação WebDAV ainda não está concluída.
- **Features não implementadas:** Captura de foto, seleção de imagem da galeria, gravação de áudio, fixar nota (pin), notificações/lembretes e formatação de texto (negrito, itálico, etc.) estão comentadas no código como TODOs.

---

## 0.1.5
# 🚀 Novidades da Versão 0.1.5

### ✨ Novidades
- **Internacionalização:** Suporte a 6 idiomas (Português, Inglês, Francês, Alemão, Italiano, Espanhol) com 152 chaves de localização.
- **Seletor de idioma:** Disponível nas Definições para testar todos os locales.
- **Partilha de texto:** Recebe texto partilhado de outras aplicações e cria automaticamente uma nova nota.
- **Sanitização de texto partilhado:** Remoção de caracteres de controlo e normalização de espaços.
- **Preparação para release pública:** README e AGENTS.md consolidados para release.
- **Ícones atualizados:** Novo ícone da aplicação (cérebro + lâmpada + K) aplicado a todas as plataformas.

### 🛠️ Correções e Ajustes
- **Dirty-checking:** A nota não é marcada como modificada ao ser aberta; só persiste se houver alterações reais.
- **Sync business logic:** A sincronização não inicia automaticamente quando o token é inserido; o utilizador deve selecionar a pasta de destino e clicar em "Sincronizar agora".
- **Comentários e logs traduzidos:** Todos os comentários e mensagens de debug corrigidos para inglês.
- **Paleta de cores:** Alinhamento da paleta de cores escuras entre editor e cartão de nota.

---

## 0.1.4
# 🚀 Novidades da Versão 0.1.4

### ✨ Novidades
- **Sincronização remota com kDrive (Infomaniak):** Envio e descarga de notas para a nuvem.
- **Encriptação AES opcional:** As notas podem ser encriptadas no cliente antes de serem enviadas para a nuvem.
- **Navegação hierárquica de pastas:** O utilizador pode navegar e criar pastas dentro do kDrive.
- **Push + Pull:** Notas criadas/editadas/arquivadas/eliminadas são enviadas; notas remotas não presentes localmente são baixadas.
- **Resolução de conflitos:** Last-write-wins com base na data de atualização (`updatedAt`).
- **Rate limit:** Respeito do limite de 60 pedidos por minuto da API Infomaniak.

### 🛠️ Correções e Ajustes
- **Pasta Private (id=5) como root efetivo:** A API kDrive não permite escrita na raiz (id=1).
- **Debounce de 3 segundos:** Evita chamadas excessivas à API.
- **Notas encriptadas na cloud:** Diálogo de passphrase com até 2 tentativas; opção de ignorar ou eliminar nota remota.
- **Re-encriptação:** Notas desencriptadas são regravadas conforme a configuração geral de encriptação.

---

## 0.1.3
# 🚀 Novidades da Versão 0.1.3

### ✨ Novidades
- **Home Screen Widget (4×3):** Widget nativo Android com fundo colorido por nota, pré-visualização de texto e ícones de caixas de verificação.
- **Click-to-open:** Clicar numa nota do widget abre diretamente essa nota em modo de edição.
- **App links:** Suporte a abertura de notas via `kmemo://note/{uuid}`.
- **Ícone personalizado:** Cérebro com lâmpada e K, aplicado a Android, iOS, Web, Windows e macOS.

### 🛠️ Correções e Ajustes
- **Widget click fix:** Uso de `FLAG_MUTABLE` para `PendingIntentTemplate` e extração de `note_uuid` do `data` URI.
- **Prevenção de abertura duplicada:** Flag `_isOpeningNote` para evitar navegação duplicada.

---

## 0.1.2
# 🚀 Novidades da Versão 0.1.2

### ✨ Novidades
- **Tema escuro automático:** Suporte completo com paletas de cores customizadas para ambos os temas.
- **Undo/redo:** Histórico de edições no editor de notas.
- **Barra de pesquisa:** Pesquisa inline no editor de notas.
- **Arquivo de notas:** Gestão completa de notas arquivadas.
- **Lixeira (Trash):** Soft delete com restauro e eliminação permanente.
- **Pré-visualização de conteúdos:** No MemoCard, com indicador de reticências.

### 🛠️ Correções e Ajustes
- **Persistência e foco:** Correção de perda de foco com IDs persistentes por bloco.
- **Quebra de linha:** Correção de quebra de linha/foco ao digitar.
- **Capitalização automática:** Por frase no título e itens da checklist.

---

## 0.1.1
# 🚀 Novidades da Versão 0.1.1

### ✨ Novidades
- **Editor de notas baseado em blocos:** Texto e listas de tarefas (checklists).
- **Gestão de cores:** 16 cores de fundo por nota.
- **Anexos:** Imagens, áudio e links associados à nota.
- **Arquivar notas:** Estado de arquivamento com restauro.

### 🛠️ Correções e Ajustes
- **Migração Isar → Drift:** Mudança do motor de persistência de Isar para Drift (SQLite).
- **Correção de parâmetros:** BottomAppBar e opacidade de cores na UI.
- **API withValues:** Atualização para a API `withValues` no Material 3.

---

## 0.1.0
# 🎉 Lançamento inicial do kMemo! (v0.1.0)

É com grande entusiasmo que anunciamos a primeira versão do **kMemo**, uma aplicação de notas minimalista e focada na produtividade!

O objetivo desta aplicação é proporcionar uma experiência de escrita sem distrações, com uma estrutura baseada em blocos dinâmicos e persistência offline-first.

## ✨ Funcionalidades Principais Nesta Versão:

*   **Persistência offline-first:** Toda a gestão de dados é feita localmente através do SQLite (via Drift).
*   **Estrutura baseada em blocos:** Texto e listas de tarefas manipuláveis individualmente.
*   **Gestão de estado reativa:** Utilização do ecossistema `Provider` combinado com streams nativos do Drift.
*   **Tema claro/escuro:** Suporte completo com paletas de cores customizadas.
*   **Licença GPLv3:** Distribuído sob a licença GNU General Public License v3.0.

---

Este é apenas o começo! O futuro do kMemo será moldado pelo feedback da comunidade. Se encontrar algum problema ou tiver sugestões, por favor, abra uma [Issue](https://github.com/marotoweb/kmemo/issues).

Obrigado por experimentar o kMemo!