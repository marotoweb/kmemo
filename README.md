# kMemo

O **kMemo** é uma aplicação móvel de notas minimalista e ultra-focada na produtividade, desenvolvida em Flutter. A sua interface afasta-se dos editores de texto tradicionais, adotando uma estrutura inteiramente orientada a blocos dinâmicos, permitindo mutar e reordenar conteúdos de forma fluida e sem distrações visuais.

---

## 🚀 Características Principais

- **Escrita Sem Distrações:** Interface limpa, contínua e sem bordas mecânicas. Cada elemento integra-se como se fosse uma folha de papel única.
- **Estrutura Baseada em Blocos:** O conteúdo de cada nota é composto por blocos independentes (Texto, Listas de Tarefas, Cabeçalhos) que podem ser manipulados individualmente.
- **Persistência Offline-First:** Toda a gestão de dados é feita localmente através do SQLite (via Drift), garantindo velocidade instantânea e privacidade absoluta.
- **Tema Escuro Automático (Dark Mode):** Suporte completo e dinâmico adaptado às definições do sistema, incluindo paletas de cores escuras, profundas e dessaturadas para o fundo das notas e cartões em todas as vistas.
- **Ecossistema Reativo:** Utilização do ecossistema `Provider` combinado com streams nativos do Drift para atualizações em tempo real na interface e no widget do ecrã principal.
- **Integração com Home Screen Widget (muito verde em desenvolvimento):** Sincronização automática com um widget nativo do sistema para visualização rápida das últimas notas diretamente no ambiente de trabalho do dispositivo.

---

## 🛠️ Arquitetura e Tecnologias

- **Framework:** [Flutter](https://flutter.dev) (configurado com Material Design 3).
- **Base de Dados:** [Drift (SQLite)](https://drift.simonbinder.eu/) – Utiliza conversores customizados para serializar Enums (`BlockType`) e estruturas complexas em mapas JSON (`MapConverter`).
- **Gestão de Estado:** [Provider](https://pub.dev/packages/provider).
- **Comunicação Nativa:** [home_widget](https://pub.dev/packages/home_widget) para alimentação de dados do widget Android/iOS.
- **Segurança:** Preparado para cifragem local recorrendo a `encrypt` e `flutter_secure_storage`.

---

## 🗄️ Modelo de Dados (Drift)

A aplicação organiza a persistência através de duas tabelas relacionais com eliminação em cascata automática:

1. **Memos (Notas):**
   - `uuid` (Chave Primária)
   - `title` (Título da nota)
   - `createdAt` / `updatedAt` (Controlo temporal)
   - `isSynced` (Estado de sincronização remota)
   - `remoteFileId` (Identificador de ficheiro remoto opcional)
   - `colorIndex` (Índice numérico para a cor de fundo da nota)
   - `bgImageIndex` (Índice numérico para imagens de fundo predefinidas)
   - `imageAttachments` (Texto em formato JSON com os caminhos dos anexos de imagem)
   - `audioAttachments` (Texto em formato JSON com os anexos de áudio)
   - `linkAttachments` (Texto em formato JSON com os links associados)
   - `isArchived` (Booleano para o estado de arquivamento)
   - `isDeleted` (Booleano para o envio para a lixeira)

2. **Blocks (Componentes Dinâmicos):**
   - `id` (Chave Primária com Auto-Incremento)
   - `uuid` (Identificador único do bloco)
   - `memoUuid` (Chave Estrangeira ligada à tabela Memos)
   - `type` (Enum: `text`, `checklist`, `custom`, etc.)
   - `content` (Mapa JSON contendo propriedades flexíveis como texto e estado de conclusão)
   - `sortOrder` (Índice numérico de ordenação sequencial)

---

## 📦 Como Executar o Projeto

### Pré-requisitos
- Flutter SDK instalado (Compatível com a versão definida no ambiente: `^3.10.7`).
- Dispositivo ou Emulador Android/iOS configurado.

### Passos para inicialização

1. **Clonar o repositório:**
   ```bash
   git clone <url-do-repositorio>
   cd kmemo
    ```

2. **Obter as dependências do Pub:**
   ```bash
    flutter pub get
    ```

3. **Executar a geração de código (Drift/Build Runner):**
Como o projeto utiliza geração de código estática para as tabelas do SQLite, execute o comando abaixo para gerar o ficheiro database.g.dart:

   ```bash
    dart run build_runner build --delete-conflicting-outputs --force-jit
    ```

4. **Compilar e correr a aplicação:**

    ```bash
    flutter run
    ```

## 📝 Licença
Este projeto é distribuído sob a licença **GNU General Public License v3.0 (GPLv3)**. 