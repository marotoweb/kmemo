# kMemo

O **kMemo** é uma aplicação móvel de notas minimalista e focada na produtividade, criada na Europa e desenvolvida em Flutter. A sua interface afasta-se dos editores de texto tradicionais, adotando uma estrutura inteiramente orientada a blocos dinâmicos, permitindo mutar e reordenar conteúdos de forma fluida e sem distrações visuais. O **kMemo** nasceu da necessidade de mantemos as nossas notas soberanas sem sermos o produto e depender das grandes tecnológicas.

**Versão atual: 0.1.6+7**

---

## 🚀 Características Principais

- **Escrita sem distrações:** Interface limpa, contínua e sem bordas mecânicas. Cada elemento integra-se como se fosse uma folha de papel única.
- **Estrutura baseada em blocos:** O conteúdo de cada nota é composto por blocos independentes (Texto, Listas de Tarefas, Cabeçalhos) que podem ser manipulados individualmente.
- **Persistência offline-first:** Toda a gestão de dados é feita localmente através do SQLite (via Drift), garantindo velocidade instantânea e privacidade absoluta.
- **Tema escuro automático (Dark Mode):** Suporte completo e dinâmico adaptado às definições do sistema, incluindo paletas de cores escuras, profundas e dessaturadas para o fundo das notas e cartões em todas as vistas.
- **Ecossistema reativo:** Utilização do ecossistema `Provider` combinado com streams nativos do Drift para atualizações em tempo real na interface e no widget do ecrã principal.
- **Home screen widget (4×3):** Widget nativo Android que exibe as últimas notas diretamente no ecrã principal, com fundo colorido por nota, pré-visualização de texto e ícones de caixas de verificação para listas.
- **Internacionalização:** Suporte a português, inglês, francês, alemão, italiano e espanhol, com opção "Sistema" para seguir o idioma do dispositivo.
- **Partilha de texto:** Recebe texto partilhado de outras aplicações (Share Plus) e cria automaticamente uma nova nota ou partilhe as suas notas com outras aplicações externas
- **Rejeição de notas vazias:** Notas criadas mas deixadas vazias são automaticamente eliminadas ao sair, evitando acumulação de notas sem conteúdo.
- **Sincronização com kDrive (Infomaniak):** Envio e descarga de notas para a nuvem com encriptação opcional AES no cliente.
- **Integração com Home Screen Widget:** Sincronização automática com um widget nativo do sistema para visualização rápida das últimas notas e respetiva edição rápida diretamente a partir do ambiente de trabalho do dispositivo.
- **APP link**: Suporte a abertura de notas via APP link  *kmemo://*
- **Opções do editor:** quebra de linha automática em títulos e itens de lista, e tachado opcional para itens de checklist marcados (configurável nas Definições). O widget do ecrã principal respeita estas opções na pré-visualização.
- **Reordenação de listas:** arrastar itens de checklist para reordenar, com persistência automática.

---

## 🛠️ Arquitetura e Tecnologias

- **Framework:** [Flutter](https://flutter.dev) (configurado com Material Design 3).
- **Base de Dados:** [Drift (SQLite)](https://drift.simonbinder.eu/) – Utiliza conversores customizados para serializar Enums (`BlockType`) e estruturas complexas em mapas JSON (`MapConverter`).
- **Gestão de Estado:** [Provider](https://pub.dev/packages/provider).
- **Internacionalização:** `flutter_gen_l10n` com ficheiros ARB em `lib/l10n/`.
- **Comunicação Nativa:** [home_widget](https://pub.dev/packages/home_widget) para alimentação de dados do widget Android/iOS.
- **Icones:** [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) para geração automática de ícones em todas as plataformas.
- **Segurança:** Cifragem local opcional recorrendo a `encrypt` e `flutter_secure_storage`.

---

## 🗄️ Modelo de Dados (Drift)

A aplicação organiza a persistência através de duas tabelas relacionais com eliminação em cascata automática:

### 1. Memos (Notas)
| Campo | Tipo | Descrição |
|-------|------|-----------|
| `uuid` | String (PK) | Chave primária |
| `title` | String | Título da nota |
| `createdAt` / `updatedAt` | DateTime | Controlo temporal |
| `isSynced` | Boolean | Estado de sincronização remota (local apenas) |
| `remoteFileId` | String | Identificador de ficheiro remoto opcional (local apenas) |
| `colorIndex` | Int | Índice da cor de fundo |
| `bgImageIndex` | Int | Índice da imagem de fundo |
| `imageAttachments` | String (JSON) | Caminhos dos anexos de imagem |
| `audioAttachments` | String (JSON) | Anexos de áudio |
| `linkAttachments` | String (JSON) | Links associados |
| `isArchived` | Boolean | Estado de arquivamento |
| `isDeleted` | Boolean | Estado de lixeira (soft delete) |


### 2. Blocks (Componentes Dinâmicos)
| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | Int (PK) | Auto-incremento |
| `uuid` | String | Identificador único do bloco |
| `memoUuid` | String (FK) | Ligação à tabela Memos |
| `type` | Enum | `text`, `checklist`, `custom`, etc. |
| `content` | Map<String, dynamic> | Conteúdo flexível (texto, checked, etc.) |
| `sortOrder` | Int | Ordem de apresentação |

> **Nota sobre sincronização remota:** Os campos `isSynced` e `remoteFileId` são estado local do Drift e não são enviados no payload JSON para o kDrive.


---

## 📱 Widget do Ecrã Principal

O widget nativo Android exibe as notas ativas diretamente no ecrã principal:

- **Tamanho:** 4×3 células.
- **Conteúdo:** Título da nota e pré-visualização do conteúdo
- **Cores:** Cada cartão usa a cor de fundo definida em cada nota respeitando a palete de cores em cada tema definido nas definições (Claro e Escuro)
- **Edição:** Clicar numa nota do widget abre a aplicação em modo edição da nota selecionada

---

## ☁️ Sincronização Remota (kDrive / Infomaniak)

A partir da versão 0.1.3+, o kMemo suporta sincronização remota de notas através do **kDrive**, o serviço de armazenamento soberano em nuvem da Infomaniak.

### Modelo de negócio
1. **Colocar token:** O utilizador insere o token de API Infomaniak.
2. **Descobrir drives:** A aplicação tenta encontrar as drives disponíveis; caso exista apenas uma, pré-seleciona essa drive.
3. **Navegar pastas:** O utilizador navega sobre a pasta privada onde pode criar novas pastas.
4. **Encriptação:** Define se pretende encriptação ou não.
5. **Sincronizar:** Carrega em "Sincronizar agora"; todas as configurações são guardadas e tenta o primeiro sincronismo com a cloud.
6. **Notas encriptadas na cloud:** Se existirem notas na cloud encriptadas, o utilizador será informado e questionado pela passphrase da nota em questão por um novo diálogo. Após duas tentativas falhadas de desencriptação, pode escolher ignorar ou eliminar a nota remota.
7. **Re-encriptação:** Se for possível desencriptar uma nota anteriormente encriptada, ela será regravada conforme a configuração geral de encriptação (sem encriptação se desativada, ou com nova passphrase se ativada).
8. **Alterar encriptação:** Quando o utilizador desativa/reactiva a encriptação, todas as notas são marcadas como não sincronizadas localmente e o utilizador é questionado se pretende reenviar todas as notas locais para a nuvem encriptadas ou desencriptadas conforme a configuração geral.

### Como funciona

- **Offline-first:** Todas as notas continuam a ser armazenadas localmente em SQLite havendo o risco de perda de notas se acidentalmente desinstalar a aplicação. A sincronização é uma camada assíncrona que não bloqueia a interface e permite que as suas notas sejam salvas de forma soberana num servidor remoto.
- **Push:** Notas criadas, editadas, arquivadas ou eliminadas são enviadas para o kDrive
- **Pull:** Notas existentes no kDrive mas não no dispositivo são baixadas automaticamente.
- **Conflitos:** Resolvidos por "last-write-wins" com base na data de atualização (`updatedAt`).
- **Encriptação opcional:** Pode ativar encriptação AES no cliente com uma passphrase definida por si. Sem essa passphrase, não é possível recuperar os dados encriptados.
- **Pasta de destino:** As notas são guardadas dentro de uma pasta específica (não na raiz), navegável hierarquicamente. A pasta "Private" (id=5) é usada como raiz efetiva, pois a API kDrive não permite escrita na raiz (id=1).

### Configuração

1. Vá a **Definições → Sincronização**.
2. Gere um token de API em [manager.infomaniak.com](https://manager.infomaniak.com/v3/ng/accounts/token/list) com os escopos `drive`, `user_info`, `accounts`.
3. Cole o token na aplicação;
4. Selecione o drive kDrive onde deseja guardar as notas, a drive é descoberta e pré-selecionada se for a única.
5. Escolha o local onde deseja guardar as notas, pode criar novas pastas.
6. (Opcional) Ative a encriptação e defina uma passphrase.
7. Clique em **"Sincronizar agora"** para guardar a configuração e executar o primeiro sincronismo.

### Limitações conhecidas

- O rate limit da API Infomaniak é de 60 pedidos por minuto.
- A sincronização requer ligação à internet.
- A pasta de destino deve ser selecionada antes do primeiro sincronismo.

---

## ☁️ Sincronização Remota (WebDAV)

- Protocolo WebDAV em desenvolvimento. O seletor de protocolo está disponível nas Definições → Sincronização, mas a implementação do protocolo WebDAV ainda não está concluída. Atualmente, apenas o kDrive (Infomaniak) está funcional. 

---

### ⚠️ Aviso Importante

O kMemo **não é afiliado, endossado ou patrocinado pela Infomaniak**. O serviço **kDrive** é uma marca registada da **Infomaniak**. A utilização da API do kDrive é feita através de tokens gerados pelo próprio utilizador no gestor de conta da Infomaniak, de acordo com os termos de serviço dessa empresa.

---

## 📦 Como Executar o Projeto

### Pré-requisitos
- Flutter SDK instalado (versão `^3.10.7` ou superior).
- Dispositivo ou Emulador Android/iOS configurado.
- Android SDK com API nível 21+.

> [Veja o meu artigo de instalação em Linux](https://medium.com/@marotoweb/how-to-install-flutter-on-ubuntu-24-04-3-lts-without-android-studio-17a41ee29468)

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
   ```bash
   flutter pub run build_runner build --force-jit
   ```

4. **Gerar ícones da aplicação (opcional, se alterar o ícone):**
   ```bash
   flutter pub run flutter_launcher_icons
   ```

5. **Compilar e correr a aplicação:**
   ```bash
   flutter run
   ```
---

## 🧭 Navegação Rápida

| Ficheiro | Descrição |
|----------|-----------|
| `lib/main.dart` | Ponto de entrada, MultiProvider, tema, locale |
| `lib/database/database.dart` | Schema Drift (Memos + Blocks) |
| `lib/l10n/` | Ficheiros de localização (PT, EN, FR, DE, IT, ES) |
| `lib/providers/memo_provider.dart` | Lógica de memos, streams, bulk actions, sync |
| `lib/services/widget_service.dart` | Sincronização de dados para o widget |
| `lib/services/kdrive_storage.dart` | Implementação kDrive (upload/download/list/delete) |
| `lib/services/encryption_service.dart` | Encriptação AES opcional no cliente |
| `lib/services/storage_repository.dart` | Interface abstrata de armazenamento remoto |
| `lib/ui/screens/memo_detail_screen.dart` | Editor de notas (texto + checklist, guarda apenas se alterado) |
| `lib/ui/screens/home_screen.dart` | Ecrã principal com lista de notas ativas + partilha de texto |
| `lib/ui/screens/trash_screen.dart` | Lixeira (restaurar / eliminar permanentemente) |
| `lib/ui/screens/archive_screen.dart` | Notas arquivadas |
| `lib/ui/screens/settings_screen.dart` | Definições, tema, idioma, sincronização, info open-source |
| `lib/ui/screens/sync_settings_screen.dart` | Configuração kDrive: token, drive, pasta, encriptação |
| `lib/models/block.dart` | Definição de BlockType e Block model |
| `android/app/src/main/kotlin/com/marotoweb/kmemo/MainActivity.kt` | Tratamento de intents (widget + shared text) |
| `android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetService.kt` | Fábrica de views do widget nativo |
| `android/app/src/main/kotlin/com/marotoweb/kmemo/KMemoWidgetProvider.kt` | Lifecycle do AppWidget |
| `assets/icon/icon.png` | Ícone da aplicação |
| `assets/backgrounds/` | Pasta para imagens de fundo das notas |

---

## 📝 Licença

Este projeto é distribuído sob a licença **GNU General Public License v3.0 (GPLv3)**.

## 📄 Isenção de responsabilidade
A aplicação kMemo é fornecida "COMO ESTÁ", sem garantias de qualquer tipo. O autor não se responsabiliza por qualquer mau funcionamento, perda de dados ou erros  que possam surgir do uso desta aplicação.
