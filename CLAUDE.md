# FFMPEG — Instruções do Projeto

Programa de uso pessoal do Ribamar para **baixar do YouTube** (vídeo até 1080p ou música MP3,
um link ou uma lista `.txt`) e **converter vídeos** para o formato mais compatível com
navegador (MP4 H.264 + AAC), para o site particular. Object Pascal / Lazarus, no padrão do
`LIVRO.md` (Parte VIII — projeto novo), na versão enxuta: sem banco, sem login, sem config.

Os comandos de origem estão em `exemplos/` (o `.bat` do vídeo, o comando do projetor, o
script dos hinos em MP3) — são a fonte de **escopo** dos presets.

Estas instruções valem para toda sessão de trabalho neste projeto.

---

## 1. Modo de operação: escrita DIRETA no fonte

- ⚠ **Diferente dos outros projetos RibaSoft**: aqui o assistente **escreve direto** nos `.pas`,
  `.lfm`, `.lpi`, `.lpr` e `.md`. Decisão do Ribamar em 03/10/2026, por ser projeto pessoal
  pequeno.
- **Layout e ancoragem são dele.** Componente novo entra no `.lfm` encadeado no padrão de
  ancoragem que já existe na tela (`AnchorSideLeft` no anterior, `asrBottom`,
  `BorderSpacing.Left = 10`), sem capricho de posição — ele ajusta na IDE.
- **Releia o arquivo do disco antes de editar**, mesmo já lido na sessão: ele mexe na IDE em
  paralelo (Ctrl+D reformata tudo — isso não é achado, não se reporta).
- Quando algum código for entregue **pelo chat** para ele aplicar à mão, valem as regras
  globais: linha numerada + âncora, de **baixo pra cima**, "APAGUE as linhas X a Y" em
  substituição.

---

## 2. Início de cada sessão

1. Leia o **`ESTADO.md`** — o painel.
2. Leia o **`DECISOES.md`** — o porquê, o que foi **recusado** e as armadilhas.
3. Abra só as units relevantes. Siga os padrões já existentes; não introduza convenção nova.

⚠ Não se lista como pendência: esqueleto de tela, nomenclatura por "fase", roteiro de teste.

---

## 3. Regras de ouro

- **Nunca responder por suposição.** Opção do yt-dlp/ffmpeg se confere no `--help` ou
  rodando; API da LCL/LazUtils se confere na fonte (`C:\lazarus\components\lazutils`,
  `C:\lazarus\lcl`).
- **Antes de afirmar que algo existe, `grep`.**
- **Comando que não foi rodado não se entrega.** Linha de comando nova do ffmpeg se prova com
  um vídeo de teste gerado pelo próprio ffmpeg (`-f lavfi -i testsrc...`) no scratchpad.
- Código em **português**, legível, comentário diz o **porquê**.

---

## 4. Arquitetura

| Pasta | Prefixo | Papel |
|---|---|---|
| `utils/` | `Riba*` | framework enxuto (seção 5) |
| `model/` | `model.` | **monta** a linha de comando e **lê** a saída do yt-dlp / ffmpeg / ffprobe. Não executa nada. |
| `thread/` | `thread.` | `TTarefaThread`: **executa** os programas (`TProcessUTF8`), lê a saída linha a linha, orquestra (baixar → sondar → converter) e manda log/progresso por `Synchronize` |
| `view/` | `view.` | `view.principal`, a tela única. Sem regra. |

Não há `dataObject/` nem `controller/`: não existe entidade nem banco, e quem orquestra é a
thread (como a `thread.inicio` do Varejo).

### ⚠ Interfaces centralizadas

Toda interface de model/serviço (`IRibaTools`, `IYtDlpModel`, `IFFmpegModel`) mora em
**`utils/RibaCore.pas`**, com a factory (`YtDlpModel`, `FFmpegModel` — instância NOVA a cada
chamada). **Método público novo = classe + interface**, no mesmo passo.

⚠ O `TFFmpegModel` guarda a última velocidade lida: a leitura de UMA conversão usa UMA
instância do começo ao fim.

---

## 5. Framework (`utils/`)

| Unit | Responsabilidade |
|---|---|
| `RibaTypes` | constantes (executáveis, formatos do yt-dlp, marcadores, filtros), enums (`TTipoBaixar`, `TPresetConversao`, `TTipoTarefa`, `TTipoLinha`), records (`TProgresso`, `TSonda`), `PRESET_NOME` |
| `RibaCore` | interfaces + global `Riba` + factories + `iif` + `AdicionaParametros` |
| `RibaTools` | `TRiba`: `Aviso`/`Erro`/`Confirma`, `AbrePasta`, `AbreArquivos`, `LocalizaExecutavel`, `PastaParaParametro`, `TextoParaNumero`, `FormataBytes`, `FormataTempo`, `VersaoApp`, `EstilizaComponentes` |

**Não existem aqui** (e não é esquecimento — `DECISOES.md § 2`): `RibaDB`, `RibaConfig`,
`RibaApi`, `RibaACBr`, `RibaProgresso`, `TPadraoView`, `Config.ini`.

---

## 6. Stack / build

- **Lazarus 4.8** (FPC 3.2.2), `{$mode objfpc}{$H+}`, UTF-8, **i386-win32**, DPI-aware.
- Pacote próprio `ribasoft` (`TBotao`, unit `libBotao`).
- Ferramentas externas no PATH (Chocolatey): `yt-dlp`, `ffmpeg`, `ffprobe`; e do Windows:
  `curl.exe`, `taskkill.exe`.
- Debug → `pFFMPEG_debug.exe` (checks + heaptrc). Release → `pFFMPEG.exe` (-O3).
- Conferir sem queimar versão: `lazbuild -B --no-write-project pFFMPEG.lpi > build.log 2>&1`
  e **ler o log** — saída limpa esperada: só `5023 Unit not used` e `5024 Parameter Sender`.

---

## 7. Finalizar a sessão

Dois passos (sem change log, sem publicação):

1. **Conferir**: `grep` do símbolo novo de cada mudança; `lazbuild -B --no-write-project`;
   evento declarado no `.pas` × ligado no `.lfm` (`On... = Handler`), nos dois sentidos.
2. **Enviar**: `Limpar.bash` (limpa os gerados, commit, push). Mensagem a partir do que foi
   conferido; incluir todos os pendentes do `git status`, revisando o que entra.
