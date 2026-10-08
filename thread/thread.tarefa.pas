unit thread.tarefa; {$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math, SyncObjs, process, UTF8Process, RibaCore, RibaTypes;

type
  TLinhaEvent = procedure(const ALinha: string) of object;
  TLogEvent = procedure(const ATexto: string) of object;
  TProgressoEvent = procedure(const ATitulo: string; const AProgresso: TProgresso) of object;

  { TTarefaThread }

  // Uma tarefa de fundo: baixar, converter ou atualizar o yt-dlp. Roda os programas externos
  // um de cada vez, lê a saída linha a linha e manda log e progresso para a tela pelos
  // eventos OnLog/OnProgresso (sempre no thread principal, via Synchronize).

  // Ciclo de vida: Create -> preencher as propriedades -> Start. Libera-se sozinha
  // (FreeOnTerminate); quem a criou é avisado pelo OnTerminate, que roda no thread principal
  // ANTES da liberação — é a última hora em que Cancelado/Erros podem ser lidos.
  TTarefaThread = class(TThread)
  private
    //Configuração (preenchida antes do Start)
    FTipo: TTipoTarefa;
    FItens: TStringList;
    FPasta: string;
    FTipoBaixar: TTipoBaixar;
    FConverteSeNecessario: boolean;
    FPreset: TPresetConversao;
    FCorteInicio: double;   // segundos eliminados do começo de cada vídeo (0 = nada)
    FCorteFim: double;      // segundos eliminados do fim de cada vídeo (0 = nada)
    FOnLog: TLogEvent;
    FOnProgresso: TProgressoEvent;

    //Resultado
    FCancelado: boolean;
    FErros: integer;

    // O processo em andamento (nil entre um e outro). Só se mexe dentro da FTrava: o Cancela
    // vem do thread principal e precisa matar exatamente o processo que está rodando.
    FTrava: TCriticalSection;
    FProcesso: TProcessUTF8;

    //Leitura em andamento
    FYtDlp: IYtDlpModel;
    FFFmpeg: IFFmpegModel;
    FTitulo: string;
    FDuracao: double;
    FArquivosBaixados: TStringList;
    FSaidaComando: TStringList;

    //O que vai para a tela (lido pelos Sinc*, no thread principal)
    FSincTexto: string;
    FSincTitulo: string;
    FSincProgresso: TProgresso;

    procedure SincLog;
    procedure SincProgresso;
    procedure Log(const ATexto: string);
    procedure Progresso(const ATitulo: string; APercentual: double; const ADetalhe: string);

    function Executa(const AExe: string; const AParametros: TStringArray; ALinha: TLinhaEvent): integer;
    procedure MataArvore(AProcesso: TProcessUTF8);

    procedure LinhaYtDlp(const ALinha: string);
    procedure LinhaFFmpeg(const ALinha: string);
    procedure LinhaGuarda(const ALinha: string);
    procedure LinhaLog(const ALinha: string);

    procedure Baixa;
    procedure Converte;
    procedure Atualiza;
    procedure ConverteBaixados;
    function Sonda(const AArquivo: string; out ASonda: TSonda): boolean;
    function ConverteArquivo(const AEntrada, ASaida: string; APreset: TPresetConversao; const ATitulo: string;
      AInicio, AManter, ADuracao: double): boolean;
    function ContaPedacos(const ASaida: string): integer;
    procedure ApagaSaida(const ASaida: string; APreset: TPresetConversao);
  protected
    procedure Execute; override;
  public
    constructor Create(ATipo: TTipoTarefa);
    destructor Destroy; override;
    procedure Cancela;

    property Itens: TStringList read FItens;
    property Pasta: string read FPasta write FPasta;
    property TipoBaixar: TTipoBaixar read FTipoBaixar write FTipoBaixar;
    property ConverteSeNecessario: boolean read FConverteSeNecessario write FConverteSeNecessario;
    property Preset: TPresetConversao read FPreset write FPreset;
    property CorteInicio: double read FCorteInicio write FCorteInicio;
    property CorteFim: double read FCorteFim write FCorteFim;
    property OnLog: TLogEvent read FOnLog write FOnLog;
    property OnProgresso: TProgressoEvent read FOnProgresso write FOnProgresso;

    property Tipo: TTipoTarefa read FTipo;
    property Cancelado: boolean read FCancelado;
    property Erros: integer read FErros;
  end;

implementation

//================================================================ CREATE ======================================================\\
constructor TTarefaThread.Create(ATipo: TTipoTarefa);
begin
  inherited Create(True);
  FreeOnTerminate := True;

  FTipo := ATipo;
  FItens := TStringList.Create;
  FPasta := EmptyStr;
  FTipoBaixar := tbVideo;
  FConverteSeNecessario := False;
  FPreset := pcSite1080;
  FCorteInicio := 0;
  FCorteFim := 0;
  FCancelado := False;
  FErros := 0;
  FTrava := TCriticalSection.Create;
  FProcesso := nil;
  FTitulo := EmptyStr;
  FDuracao := 0;
  FArquivosBaixados := TStringList.Create;
  FSaidaComando := TStringList.Create;
end;

//=============================================================== DESTROY ======================================================\\
destructor TTarefaThread.Destroy;
begin
  FreeAndNil(FItens);
  FreeAndNil(FArquivosBaixados);
  FreeAndNil(FSaidaComando);
  FreeAndNil(FTrava);
  inherited Destroy;
end;

//=============================================================== EXECUTE ======================================================\\
procedure TTarefaThread.Execute;
begin
  try
    case FTipo of
      ttBaixar: Baixa;
      ttConverter: Converte;
      ttAtualizar: Atualiza;
    end;
  except
    // Exceção dentro de thread não chega a lugar nenhum sozinha: some, e a tela fica
    // esperando. Aqui ela vira linha de log e erro contado.
    on E: Exception do
    begin
      Inc(FErros);
      Log('ERRO: ' + E.Message);
    end;
  end;
end;

//=============================================================== CANCELA ======================================================\\
// Chamado do thread principal. Marca o cancelamento (nenhum processo novo começa) e mata o
// que estiver rodando — a leitura da saída acaba sozinha quando o processo morre.
procedure TTarefaThread.Cancela;
begin
  FCancelado := True;

  FTrava.Enter;
  try
    if Assigned(FProcesso) and FProcesso.Running then
      MataArvore(FProcesso);
  finally
    FTrava.Leave;
  end;
end;

//============================================================= MATA ARVORE ====================================================\\
// ⚠ Matar só o processo que nós abrimos NÃO basta: o yt-dlp.exe e o ffmpeg.exe do PATH são
// "shims" do Chocolatey, que abrem o programa de verdade como filho — e o yt-dlp ainda abre
// o ffmpeg para juntar áudio e vídeo. O taskkill /T derruba a árvore inteira.
procedure TTarefaThread.MataArvore(AProcesso: TProcessUTF8);
var
  auxKill: TProcessUTF8;
  auxExe: string;
begin
  if not Riba.LocalizaExecutavel(TASKKILL_EXE, auxExe) then
  begin
    AProcesso.Terminate(1);
    Exit;
  end;

  auxKill := nil;
  try
    auxKill := TProcessUTF8.Create(nil);
    auxKill.Executable := auxExe;
    auxKill.Parameters.Add('/PID');
    auxKill.Parameters.Add(IntToStr(AProcesso.ProcessID));
    auxKill.Parameters.Add('/T');
    auxKill.Parameters.Add('/F');
    auxKill.Options := [poWaitOnExit, poNoConsole];
    auxKill.ShowWindow := swoHide;
    auxKill.Execute;
  finally
    FreeAndNil(auxKill);
  end;
end;

//=============================================================== EXECUTA ======================================================\\
// Roda um programa e entrega cada linha da saída (stdout + stderr juntos) ao ALinha, ainda
// dentro desta thread. Devolve o código de saída do programa (-1 = nem começou).

// A quebra de linha vale tanto para o LF quanto para o CR: a barra de progresso de programa
// de console se redesenha com CR sozinho, e cada redesenho é uma linha para nós.
// O texto é juntado byte a byte e só é cortado no CR/LF, que são ASCII — então um acento
// (2 bytes em UTF-8) que chegue partido entre duas leituras é remontado inteiro.
function TTarefaThread.Executa(const AExe: string; const AParametros: TStringArray; ALinha: TLinhaEvent): integer;
const
  TAM_BLOCO = 4096;
var
  auxProc: TProcessUTF8;
  auxBloco, auxPendente: string;
  auxDisponivel, auxLidos, I: integer;
  auxC: char;
begin
  Result := -1;
  if FCancelado then Exit;

  auxProc := nil;
  auxPendente := EmptyStr;
  auxBloco := StringOfChar(#0, TAM_BLOCO);

  try
    auxProc := TProcessUTF8.Create(nil);
    auxProc.Executable := AExe;
    for I := 0 to High(AParametros) do
      auxProc.Parameters.Add(AParametros[I]);
    auxProc.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
    auxProc.ShowWindow := swoHide;

    // Publicar e iniciar DENTRO da trava: assim o Cancela ou chega antes (e o processo nem
    // começa) ou chega depois (e encontra o processo rodando para matar) — nunca no meio.
    FTrava.Enter;
    try
      FProcesso := auxProc;
      if not FCancelado then
        auxProc.Execute;
    finally
      FTrava.Leave;
    end;

    if FCancelado then Exit;

    while True do
    begin
      auxDisponivel := auxProc.Output.NumBytesAvailable;

      if (auxDisponivel > 0) then
      begin
        auxLidos := auxProc.Output.Read(auxBloco[1], Min(auxDisponivel, TAM_BLOCO));

        for I := 1 to auxLidos do
        begin
          auxC := auxBloco[I];
          if (auxC = #10) or (auxC = #13) then
          begin
            if (auxPendente <> EmptyStr) then
              ALinha(auxPendente);
            auxPendente := EmptyStr;
          end
          else
            auxPendente += auxC;
        end;
      end
      else if auxProc.Running then
        Sleep(50)
      // Processo acabou: confere o cano DE NOVO antes de sair — o que ele escreveu logo
      // antes de terminar pode ter chegado entre a primeira olhada e o Running.
      else if (auxProc.Output.NumBytesAvailable = 0) then
        Break;
    end;

    if (auxPendente <> EmptyStr) then
      ALinha(auxPendente);

    Result := auxProc.ExitCode;
  finally
    FTrava.Enter;
    try
      FProcesso := nil;
    finally
      FTrava.Leave;
    end;
    FreeAndNil(auxProc);
  end;
end;

//================================================================ BAIXA =======================================================\\
procedure TTarefaThread.Baixa;
var
  auxExe, auxLista: string;
  auxCodigo, auxErrosAntes: integer;
begin
  FYtDlp := YtDlpModel;
  auxExe := FYtDlp.Executavel;
  if (auxExe = EmptyStr) then
  begin
    Inc(FErros);
    Log('yt-dlp não encontrado. Use o botão "Atualizar yt-dlp" para baixar uma cópia na pasta do programa.');
    Exit;
  end;

  // Os links vão num arquivo temporário (-a), e não na linha de comando: uma lista grande
  // passaria do limite de tamanho da linha de comando do Windows.
  auxLista := GetTempFileName(GetTempDir, 'ffmpeg_lista_');
  FItens.SaveToFile(auxLista);
  try
    FTitulo := EmptyStr;
    FArquivosBaixados.Clear;
    auxErrosAntes := FErros;

    Log(Format('Baixando %d link(s) para %s', [FItens.Count, FPasta]));
    Log('Usando ' + auxExe);
    Progresso('Baixando', 0, 'iniciando o yt-dlp...');

    auxCodigo := Executa(auxExe, FYtDlp.ParametrosBaixar(auxLista, FPasta, FTipoBaixar, FConverteSeNecessario), @LinhaYtDlp);
  finally
    DeleteFile(auxLista);
  end;

  if FCancelado then Exit;

  // Com --ignore-errors o yt-dlp segue a lista e sai com 1 se QUALQUER item falhou. Cada
  // "ERROR:" já foi contado no LinhaYtDlp; só conta aqui a falha que não deixou mensagem.
  if (auxCodigo <> 0) and (FErros = auxErrosAntes) then
  begin
    Inc(FErros);
    Log(Format('O yt-dlp terminou com o código %d.', [auxCodigo]));
  end;

  Log(Format('%d arquivo(s) baixado(s).', [FArquivosBaixados.Count]));

  if FConverteSeNecessario and (FTipoBaixar = tbVideo) then
    ConverteBaixados;
end;

//========================================================== CONVERTE BAIXADOS =================================================\\
// O "converter se não for H.264" do download: o que veio em outro codec é convertido com o
// preset do projetor e TOMA O LUGAR do original (mesmo nome, .mp4). O que já é H.264 + AAC
// fica como está.
procedure TTarefaThread.ConverteBaixados;
var
  I: integer;
  auxArquivo, auxTemp, auxFinal, auxNome: string;
  auxSonda: TSonda;
begin
  FFFmpeg := FFmpegModel;

  for I := 0 to Pred(FArquivosBaixados.Count) do
  begin
    if FCancelado then Exit;

    auxArquivo := FArquivosBaixados[I];
    auxNome := ExtractFileName(auxArquivo);

    if not Sonda(auxArquivo, auxSonda) then
    begin
      Inc(FErros);
      Continue;
    end;

    if not FFFmpeg.PrecisaConverter(auxSonda) then
    begin
      Log(Format('Já está em H.264 + AAC: %s', [auxNome]));
      Continue;
    end;

    Log(Format('Convertendo para H.264 (veio %s + %s): %s', [auxSonda.CodecVideo, iif(auxSonda.CodecAudio = '', 'sem áudio', auxSonda.CodecAudio), auxNome]));

    auxTemp := ChangeFileExt(auxArquivo, SUFIXO_TEMPORARIO);
    auxFinal := ChangeFileExt(auxArquivo, '.mp4');

    if not ConverteArquivo(auxArquivo, auxTemp, pcProjetor, 'Convertendo ' + auxNome, 0, 0, auxSonda.Duracao) then
      Continue;

    if DeleteFile(auxArquivo) and RenameFile(auxTemp, auxFinal) then
      Log('Convertido: ' + ExtractFileName(auxFinal))
    else
    begin
      Inc(FErros);
      Log(Format('Convertido, mas não foi possível substituir o original. O convertido ficou em %s', [auxTemp]));
    end;
  end;
end;

//=============================================================== CONVERTE =====================================================\\
// A conversão pedida pela tela: cada arquivo vira "conv_<nome>.mp4" na pasta escolhida (no
// WhatsApp, "conv_<nome>_parte001.mp4", "_parte002"...). Um arquivo que falha não para a fila.
// O corte do início/fim vale para todos os arquivos da fila.
procedure TTarefaThread.Converte;
var
  I, auxPedacos: integer;
  auxEntrada, auxSaida, auxTitulo, auxNome: string;
  auxSonda: TSonda;
  auxDuracao, auxManter: double;
begin
  FFFmpeg := FFmpegModel;
  if (FFFmpeg.Executavel = EmptyStr) or (FFFmpeg.ExecutavelSonda = EmptyStr) then
  begin
    Inc(FErros);
    Log('ffmpeg/ffprobe não encontrados no PATH.');
    Exit;
  end;

  Log(Format('Convertendo %d arquivo(s) para %s - %s', [FItens.Count, FPasta, PRESET_NOME[FPreset]]));
  if (FCorteInicio > 0) or (FCorteFim > 0) then
    Log(Format('Eliminando %s s do início e %s s do fim de cada vídeo.',
      [FormatFloat('0.###', FCorteInicio), FormatFloat('0.###', FCorteFim)]));

  for I := 0 to Pred(FItens.Count) do
  begin
    if FCancelado then Exit;

    auxEntrada := FItens[I];
    auxNome := ExtractFileName(auxEntrada);
    auxTitulo := Format('%d/%d: %s', [I + 1, FItens.Count, auxNome]);
    Log('Convertendo ' + auxTitulo);

    if not Sonda(auxEntrada, auxSonda) then
    begin
      Inc(FErros);
      Continue;
    end;

    if (auxSonda.CodecVideo = EmptyStr) then
    begin
      Inc(FErros);
      Log('Não tem trilha de vídeo: ' + auxNome);
      Continue;
    end;

    // O corte do fim é contado a partir da duração (o ffmpeg só sabe "quanto manter"): sem
    // ela, não há como saber onde parar.
    if (FCorteFim > 0) and (auxSonda.Duracao <= 0) then
    begin
      Inc(FErros);
      Log('Duração desconhecida, não dá para cortar o fim: ' + auxNome);
      Continue;
    end;

    // auxDuracao = o que sobra depois dos cortes (o percentual é sobre ela; 0 = desconhecida).
    // auxManter = o -t do ffmpeg: só quando há corte no fim (0 = vai até o fim do arquivo).
    auxDuracao := 0;
    if (auxSonda.Duracao > 0) then
    begin
      auxDuracao := auxSonda.Duracao - FCorteInicio - FCorteFim;
      if (auxDuracao <= 0) then
      begin
        Inc(FErros);
        Log(Format('O corte é maior que o vídeo (%s): %s', [Riba.FormataTempo(auxSonda.Duracao), auxNome]));
        Continue;
      end;
    end;

    auxManter := 0;
    if (FCorteFim > 0) then
      auxManter := auxDuracao;

    auxSaida := FFFmpeg.NomeSaida(auxEntrada, FPasta, FPreset);
    if not ConverteArquivo(auxEntrada, auxSaida, FPreset, auxTitulo, FCorteInicio, auxManter, auxDuracao) then
      Continue;

    if (FPreset = pcWhatsApp) then
    begin
      auxPedacos := ContaPedacos(auxSaida);
      Log(Format('Salvo em %d pedaço(s): %s até %s', [auxPedacos, FFFmpeg.NomePedaco(auxSaida, 1),
        ExtractFileName(FFFmpeg.NomePedaco(auxSaida, auxPedacos))]));
    end
    else
      Log('Salvo: ' + auxSaida);
  end;
end;

//=============================================================== ATUALIZA =====================================================\\
// Com cópia local: o próprio yt-dlp se atualiza (--update). Sem cópia local: baixa o
// executável oficial do GitHub para a pasta do programa — a partir daí é ele que o programa
// usa, e as próximas atualizações são pelo --update (DECISOES.md § 3).
procedure TTarefaThread.Atualiza;
var
  auxCodigo: integer;
  auxCurl, auxDestino, auxTemp: string;
begin
  FYtDlp := YtDlpModel;
  Progresso('Atualizando o yt-dlp', 0, 'aguarde...');

  if FYtDlp.TemCopiaLocal then
  begin
    Log('Atualizando ' + FYtDlp.Executavel);
    auxCodigo := Executa(FYtDlp.Executavel, FYtDlp.ParametrosAtualizar, @LinhaLog);
  end
  else
  begin
    if not Riba.LocalizaExecutavel(CURL_EXE, auxCurl) then
    begin
      Inc(FErros);
      Log('curl.exe não encontrado (ele vem com o Windows 10 desde a versão 1803).');
      Exit;
    end;

    auxDestino := ExpandFileName(YTDLP_LOCAL);
    // Baixa com outro nome e só renomeia no fim: download interrompido não deixa um
    // yt-dlp.exe pela metade, que passaria a vencer o do PATH.
    auxTemp := auxDestino + '.baixando';
    Log('Baixando o yt-dlp oficial para ' + auxDestino);
    auxCodigo := Executa(auxCurl, FYtDlp.ParametrosInstalar(auxTemp), @LinhaLog);

    if (auxCodigo = 0) and FileExists(auxTemp) and RenameFile(auxTemp, auxDestino) then
      Log('yt-dlp instalado na pasta do programa.')
    else if FileExists(auxTemp) then
      DeleteFile(auxTemp);
  end;

  if FCancelado then Exit;

  if (auxCodigo <> 0) then
  begin
    Inc(FErros);
    Log(Format('A atualização terminou com o código %d.', [auxCodigo]));
  end;

  FSaidaComando.Clear;
  if (FYtDlp.Executavel <> EmptyStr) and (Executa(FYtDlp.Executavel, FYtDlp.ParametrosVersao, @LinhaGuarda) = 0) and
    (FSaidaComando.Count > 0) then
    Log(Format('Versão em uso: %s (%s)', [FSaidaComando[0], FYtDlp.Executavel]));

  Progresso('Atualizando o yt-dlp', 100, 'concluído');
end;

//================================================================= SONDA ======================================================\\
// O ffprobe do arquivo: duração (para o percentual) e codecs (para saber se precisa converter).
function TTarefaThread.Sonda(const AArquivo: string; out ASonda: TSonda): boolean;
var
  auxExe: string;
  I: integer;
begin
  ASonda.Duracao := 0;
  ASonda.CodecVideo := EmptyStr;
  ASonda.CodecAudio := EmptyStr;

  auxExe := FFFmpeg.ExecutavelSonda;
  if (auxExe = EmptyStr) then
  begin
    Log('ffprobe não encontrado no PATH.');
    Exit(False);
  end;

  FSaidaComando.Clear;
  Result := (Executa(auxExe, FFFmpeg.ParametrosSonda(AArquivo), @LinhaGuarda) = 0);

  if Result then
    ASonda := FFFmpeg.LeSonda(FSaidaComando)
  else if not FCancelado then
  begin
    Log('Não foi possível ler o arquivo: ' + AArquivo);
    for I := 0 to Pred(FSaidaComando.Count) do
      Log('  ' + FSaidaComando[I]);
  end;
end;

//=========================================================== CONVERTE ARQUIVO =================================================\\
// Uma conversão. Falhou ou foi cancelada: apaga a saída pela metade.
//   AInicio  = segundos pulados no começo (0 = nenhum)
//   AManter  = segundos que ficam a partir dali (0 = até o fim)
//   ADuracao = duração do que vai sair, para o percentual (0 = desconhecida)
function TTarefaThread.ConverteArquivo(const AEntrada, ASaida: string; APreset: TPresetConversao; const ATitulo: string;
  AInicio, AManter, ADuracao: double): boolean;
var
  auxExe: string;
  auxCodigo: integer;
begin
  Result := False;

  // Instância nova a cada conversão: o model guarda a última velocidade lida, e ela não pode
  // passar de um arquivo para o outro.
  FFFmpeg := FFmpegModel;
  auxExe := FFFmpeg.Executavel;
  if (auxExe = EmptyStr) then
  begin
    Inc(FErros);
    Log('ffmpeg não encontrado no PATH.');
    Exit;
  end;

  FTitulo := ATitulo;
  FDuracao := ADuracao;
  Progresso(FTitulo, 0, 'iniciando o ffmpeg...');

  auxCodigo := Executa(auxExe, FFFmpeg.ParametrosConverter(AEntrada, ASaida, APreset, AInicio, AManter), @LinhaFFmpeg);
  Result := (auxCodigo = 0) and not FCancelado;

  if Result then
    Progresso(FTitulo, 100, 'concluído')
  else
  begin
    ApagaSaida(ASaida, APreset);

    if not FCancelado then
    begin
      Inc(FErros);
      Log(Format('A conversão falhou (código %d): %s', [auxCodigo, ExtractFileName(AEntrada)]));
    end;
  end;
end;

//============================================================ CONTA PEDACOS ===================================================\\
// Quantos pedaços do WhatsApp a conversão deixou: o segment numera em sequência a partir do 1.
function TTarefaThread.ContaPedacos(const ASaida: string): integer;
begin
  Result := 0;
  while FileExists(FFFmpeg.NomePedaco(ASaida, Result + 1)) do
    Inc(Result);
end;

//============================================================= APAGA SAIDA ====================================================\\
// A saída pela metade de uma conversão que falhou ou foi cancelada. No WhatsApp a saída são os
// pedaços (o arquivo ASaida em si nunca existe).
procedure TTarefaThread.ApagaSaida(const ASaida: string; APreset: TPresetConversao);
var
  I: integer;
begin
  if (APreset = pcWhatsApp) then
  begin
    for I := ContaPedacos(ASaida) downto 1 do
      DeleteFile(FFFmpeg.NomePedaco(ASaida, I));
  end
  else if FileExists(ASaida) then
    DeleteFile(ASaida);
end;

//============================================================= LINHA YTDLP ====================================================\\
procedure TTarefaThread.LinhaYtDlp(const ALinha: string);
var
  auxProgresso: TProgresso;
  auxTexto: string;
begin
  case FYtDlp.LeLinha(ALinha, auxProgresso, auxTexto) of
    tlItem:
    begin
      FTitulo := auxTexto;
      Log('Baixando: ' + auxTexto);
      Progresso(FTitulo, 0, 'iniciando...');
    end;

    tlProgresso:
      Progresso(FTitulo, auxProgresso.Percentual, auxProgresso.Detalhe);

    tlArquivo:
    begin
      FArquivosBaixados.Add(auxTexto);
      Log('Salvo: ' + auxTexto);
    end;

    tlLog:
    begin
      if auxTexto.StartsWith('ERROR') then
        Inc(FErros);
      Log(auxTexto);
    end;
  end;
end;

//============================================================ LINHA FFMPEG ====================================================\\
procedure TTarefaThread.LinhaFFmpeg(const ALinha: string);
var
  auxProgresso: TProgresso;
  auxTexto: string;
begin
  case FFFmpeg.LeLinha(ALinha, FDuracao, auxProgresso, auxTexto) of
    tlProgresso:
      Progresso(FTitulo, auxProgresso.Percentual, auxProgresso.Detalhe);

    tlLog:
      Log(auxTexto);
  end;
end;

//============================================================= LINHA GUARDA ===================================================\\
// Para saída que é lida inteira depois (ffprobe, --version): só guarda.
procedure TTarefaThread.LinhaGuarda(const ALinha: string);
begin
  FSaidaComando.Add(ALinha);
end;

//============================================================== LINHA LOG =====================================================\\
procedure TTarefaThread.LinhaLog(const ALinha: string);
begin
  Log(ALinha);
end;

//================================================================== LOG =======================================================\\
procedure TTarefaThread.Log(const ATexto: string);
begin
  if not Assigned(FOnLog) then Exit;
  FSincTexto := ATexto;
  Synchronize(@SincLog);
end;

//=============================================================== PROGRESSO ====================================================\\
// APercentual = -1 deixa a barra onde está e só troca o texto.
procedure TTarefaThread.Progresso(const ATitulo: string; APercentual: double; const ADetalhe: string);
begin
  if not Assigned(FOnProgresso) then Exit;
  FSincTitulo := ATitulo;
  FSincProgresso.Percentual := APercentual;
  FSincProgresso.Detalhe := ADetalhe;
  Synchronize(@SincProgresso);
end;

//=============================================================== SINC LOG =====================================================\\
procedure TTarefaThread.SincLog;
begin
  FOnLog(FSincTexto);
end;

//============================================================ SINC PROGRESSO ==================================================\\
procedure TTarefaThread.SincProgresso;
begin
  FOnProgresso(FSincTitulo, FSincProgresso);
end;

//==============================================================================================================================\\
end.
