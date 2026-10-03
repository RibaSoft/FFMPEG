# FFMPEG — Decisões

O porquê de cada escolha, o que foi recusado e as armadilhas que não quebram compilação.
Decisão implementada está no código; **decisão recusada só está aqui**.

---

## 1. Escopo

Uso pessoal, um PC só, com `yt-dlp`, `ffmpeg` e `ffprobe` já instalados pelo Chocolatey.
Fonte de escopo dos comandos: `exemplos/` (`baixar_Video_projetor.bat`, `para projetor.txt`,
`Music Downloads/baixar_hinos.sh`).

## 2. O que NÃO existe (recusado no levantamento de 03/10/2026)

- **Banco de dados, login/usuário, `Config.ini`** — "coisa simples para uso pessoal". Por isso
  não há `RibaDB`, `RibaConfig`, `dataObject/`, `controller/`.
- **Pasta padrão de destino** — a pasta é pedida num diálogo **a cada** download e a cada
  conversão (sem config, não há onde lembrar).
- **Atualização automática do programa, change log, ativação, relatórios.**
- **Saída MP3 na conversão** — a conversão é para o site; MP3 só no download.
- **Plataforma x64** — mantém o padrão da casa (i386-win32), mesmo sem o `fbclient.dll` que o
  justificava no Varejo.

## 3. yt-dlp: a cópia da pasta do programa vence a do PATH

O `yt-dlp` quebra quando o YouTube muda, então atualizar tem de ser um clique. O do Chocolatey
fica em `C:\ProgramData\chocolatey\lib\...` (pede administrador) e quem o atualiza é o
`choco upgrade`, não o `yt-dlp -U`.

Saída adotada: o botão **Atualizar yt-dlp**

- sem cópia local → baixa o executável **oficial** do GitHub
  (`releases/latest/download/yt-dlp.exe`) com o `curl.exe` do Windows para `.\yt-dlp.exe`
  (baixa como `.baixando` e só renomeia no fim — download interrompido não deixa um exe pela
  metade vencendo o do PATH);
- com cópia local → `yt-dlp.exe --update` nela.

A partir da primeira cópia local, o programa **só usa ela** (`YtDlpModel.Executavel`). O
`Limpar.bash` não a apaga; o `*.exe` do `.gitignore` a deixa fora do git. A abertura da tela
mostra no log qual yt-dlp/ffmpeg/ffprobe está em uso.

Caminho relativo ao diretório corrente (`.\yt-dlp.exe`), como todo caminho RibaSoft.

## 4. Formatos

### 4.1 Download

- **Vídeo**: o formato do `.bat` — `bv*[height<=1080][vcodec^=avc1]+ba[acodec^=mp4a]/b[...]`,
  `--merge-output-format mp4`. Sem H.264 disponível, o yt-dlp **falha** (comportamento do `.bat`).
- **MP3**: o do script — `-x --audio-format mp3 --audio-quality 0`, com
  `--download-archive <pasta>\.baixados.txt` (baixar a mesma lista de novo na mesma pasta pula
  o que já veio).
- Em comum: `--ignore-errors` (um link ruim não para a lista), `--no-overwrites`,
  `--no-playlist` (link de vídeo com `&list=` baixa só o vídeo; link de playlist pura baixa a
  playlist inteira), nome `%(title)s.%(ext)s`.

### 4.2 "Converter se não for H.264" (checkbox, só vídeo)

Marcado, o formato ganha um fallback (`YTDLP_FORMATO_QUALQUER`: o melhor até 1080p). Depois do
download, cada arquivo passa pelo `ffprobe`; o que não for H.264 + AAC (ou H.264 mudo) é
convertido com o **preset do projetor** e **toma o lugar do original** (mesmo nome, `.mp4`).

### 4.3 Conversão (para o site)

Pedido do Ribamar: "o formato mais compatível com navegadores". Todos os presets: **MP4,
H.264 `yuv420p` + AAC, `-movflags +faststart`** (o vídeo começa a tocar antes de baixar
inteiro), nunca aumenta a resolução.

| Preset | Vídeo | Áudio |
|---|---|---|
| Site 1080p | altura ≤1080, `-preset medium -profile:v high -crf 23`, **sem `-level`** | 1ª trilha, AAC 128k **estéreo** |
| Site 720p | igual, altura ≤720 | igual |
| Projetor 1080p | o comando de `exemplos\para projetor.txt` (`-level 4.1 -crf 20`) | todas as trilhas, AAC 160k |

- Sem `-level` no site: o x264 escolhe; 4.1 fixo é pouco para 1080p60.
- ⚠ **Altura ímpar**: o `scale=-2:'min(1080,ih)'` original deixava passar altura ímpar (721) e
  o libx264 recusa `yuv420p` assim. Todos os presets usam `trunc(min(N,ih)/2)*2`. Provado com
  um 1281×721 → 1280×720 (03/10/2026).
- Saída: `conv_<nome>.mp4` na pasta escolhida; se existir, `conv_<nome> (2).mp4`, `(3)`... —
  nunca sobrescreve.

## 5. Execução dos programas externos (`thread.tarefa`)

- `TProcessUTF8` (LazUtils), não `TProcess`: caminho e parâmetro com acento chegam certos
  (`CreateProcessW`).
- ⚠ **Executável sempre com caminho COMPLETO** (`Riba.LocalizaExecutavel`): o `CreateProcess`
  procura primeiro na pasta do próprio programa. **Nunca nomear o exe do projeto como
  `ffmpeg.exe` ou `yt-dlp.exe`** — ele se chamaria a si mesmo.
- ⚠ **Pasta com barra no fim quebra a linha de comando**: o TProcess põe aspas em quem tem
  espaço e `"D:\Meus Vídeos\"` vira `\"`, aspa escapada. Toda pasta passa por
  `Riba.PastaParaParametro` (tira a barra; raiz vira `D:\.`).
- ⚠ **Parâmetro vazio some** da linha de comando (sem aspas) e desloca os seguintes:
  `AdicionaParametros` levanta exceção.
- stdout + stderr juntos (`poStderrToOutPut`); linha cortada em LF **e** CR.
- Lista de links vai num arquivo temporário (`-a`), não na linha de comando (limite de tamanho).
- ⚠ **Cancelar mata a ÁRVORE** (`taskkill /PID n /T /F`): `yt-dlp.exe` e `ffmpeg.exe` do
  PATH são *shims* do Chocolatey que abrem o programa real como filho, e o yt-dlp ainda abre o
  ffmpeg. Matar só o processo aberto deixaria o filho rodando.
- Publicar o processo e iniciá-lo acontecem **dentro da mesma trava** que o `Cancela` usa:
  ou o cancelamento chega antes (o processo nem começa) ou depois (e o encontra para matar).
- Thread com `FreeOnTerminate`; o resultado (`Cancelado`, `Erros`) se lê no `OnTerminate`, que
  roda no thread principal antes da liberação.

## 6. Leitura da saída

- **yt-dlp**: tudo que interessa sai com marcador, por `--print` / `--progress-template`:
  `[ITEM]índice|título` (before_dl), `[PROG]baixado|total|velocidade|eta`, `[POS]nome` (pós-
  processamento), `[ARQ]caminho` (after_move). O resto é mensagem (`ERROR:` conta erro).
  ⚠ `--print` implica `--quiet`: por isso `--progress` (devolve a barra) e `--no-simulate`.
  `--encoding utf-8` para o título com acento chegar certo pelo cano. Total pode vir `NA`
  (fragmentos): a barra não anda, o texto mostra só o baixado.
- **ffmpeg**: `-v error -progress pipe:1 -nostats`. Do bloco chave=valor interessam
  `out_time_us` e `speed`; o percentual usa a duração do `ffprobe`.
  ⚠ Linha de progresso **não** se separa de mensagem pelo espaço — a própria `-progress` manda
  `bitrate= 284.1kbits/s`. A regra é a chave antes do `=` ter só `[a-z0-9_]`.
- **ffprobe**: `-show_entries format=duration:stream=codec_type,codec_name -of
  default=noprint_wrappers=1` — por trilha vem `codec_name` e depois `codec_type`.
- Número de programa de linha de comando vem com **ponto** decimal: `Riba.TextoParaNumero`,
  nunca o `StrToFloat` regional.

## 7. Tela

- `EditLink` e `EditLocal` são exceção ao maiúsculas do `EstilizaComponentes` (link e caminho
  diferenciam caixa). O `EstilizaComponentes` deste projeto reconhece o principal pelo nome
  `PrincipalView`.
- `EditLocal` é só vitrine (`ReadOnly`): a escolha de verdade é a `FArquivos` (lupa, seleção
  múltipla; cancelar a lupa mantém a escolha anterior).
- `RadioGroupTipo.ItemIndex` igual ao do `.lfm` não dispara o `OnClick` (LIVRO 11.3): o
  `FormCreate` chama o handler na mão.
- Toda tarefa roda na thread e o clique volta na hora — é o que deixa o **Cancelar** funcionar
  (o `TBotao` não aceita outro clique enquanto o primeiro não volta, LIVRO 7.4).
- `ModoOcupado` é o dono único do `Enabled` dos controles.
- Fechar com tarefa rodando: confirma, cancela, e quem fecha é o `TarefaTerminou` (a thread não
  pode mandar log para uma tela já destruída).
