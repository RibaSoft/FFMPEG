unit model.ffmpeg; {$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math, RibaCore, RibaTypes;

type

  { TFFmpegModel }

  // ⚠ Guarda estado entre linhas (a última velocidade lida): quem lê a saída de UMA conversão
  // usa UMA instância do começo ao fim, guardada em variável — a factory devolve outra a cada
  // chamada.
  TFFmpegModel = class(TInterfacedObject, IFFmpegModel)
  private
    FVelocidade: double;   // o "speed=2.5x" da -progress; 0 = ainda não veio
  public
    constructor Create;
    //Funções
    function Executavel: string;
    function ExecutavelSonda: string;
    function ParametrosConverter(const AEntrada, ASaida: string; APreset: TPresetConversao;
      AInicio, ADuracao: double): TStringArray;
    function ParametrosSonda(const AArquivo: string): TStringArray;
    function LeSonda(ASaida: TStrings): TSonda;
    function PrecisaConverter(const ASonda: TSonda): boolean;
    function NomeSaida(const AEntrada, APasta: string; APreset: TPresetConversao): string;
    function NomePedaco(const ASaida: string; ANumero: integer): string;
    function LeLinha(const ALinha: string; ADuracao: double; out AProgresso: TProgresso; out ATexto: string): TTipoLinha;
  private
    function EhChaveProgresso(const AChave: string): boolean;
    function Segundos(AValor: double): string;
  end;

implementation

const
  // O "parte001" dos pedaços do WhatsApp: o padrão que o muxer segment do ffmpeg numera, e o
  // mesmo nome no Format do Pascal (que não conhece o "%03d", mas o "%.3d" zera igual).
  PEDACO_PADRAO_FFMPEG = '_parte%03d.mp4';
  PEDACO_PADRAO_PASCAL = '_parte%.3d.mp4';

//================================================================ CREATE ======================================================\\
constructor TFFmpegModel.Create;
begin
  inherited Create;
  FVelocidade := 0;
end;

//============================================================== EXECUTAVEL ====================================================\\
function TFFmpegModel.Executavel: string;
begin
  if not Riba.LocalizaExecutavel(FFMPEG_EXE, Result) then
    Result := EmptyStr;
end;

//=========================================================== EXECUTAVEL SONDA =================================================\\
function TFFmpegModel.ExecutavelSonda: string;
begin
  if not Riba.LocalizaExecutavel(FFPROBE_EXE, Result) then
    Result := EmptyStr;
end;

//======================================================== PARAMETROS CONVERTER ================================================\\
// Todos os presets saem MP4 com H.264 (yuv420p) + AAC e +faststart — a combinação que todo
// navegador toca, e o faststart põe o índice no começo do arquivo para o vídeo começar a
// tocar no site antes de baixar inteiro.

// A escala: altura no máximo 1080 (ou 720), nunca aumenta, largura proporcional e par (-2).
// ⚠ O "trunc(.../2)*2" não estava no comando do projetor: vídeo com altura ÍMPAR (721, 1081)
// fazia o libx264 recusar o yuv420p ("height not divisible by 2"). Provado em 03/10/2026 com
// um 1281x721 de teste, que saiu 1280x720.

// Site: sem -level (o x264 escolhe o certo; 4.1 fixo seria pouco para 1080p60), áudio estéreo
// (-ac 2) e só a primeira trilha de áudio. Projetor: o comando do exemplos\para projetor.txt,
// sem tirar nada.

// WhatsApp: o lado MENOR no máximo 720 (vídeo de celular é em pé — limitar a altura, como no
// site, o deixaria estreito); o resto igual ao site. Sai em pedaços de PEDACO_SEGUNDOS pelo
// muxer segment, que só corta em keyframe: o -force_key_frames põe um keyframe a cada 30s
// exatos. ⚠ Sem o -segment_time_delta o corte NÃO sai exato: o keyframe forçado chega ao
// muxer um fio antes dos 30s (arredondamento) e o corte pula para o keyframe natural seguinte
// (deu um pedaço de 38s no teste). 0.01 é menos que um quadro até 100 fps. O faststart vai para
// cada pedaço pelo -segment_format_options. Provado em 08/10/2026: pedaços de 30,00s com
// 1080x1920 30fps (saiu 720x1280), 1281x721 29,97fps (saiu 1278x720) e 640x360 25fps.

// Corte (AInicio / ADuracao em segundos; 0 = não corta): o -ss ANTES do -i pula o começo e,
// recodificando, o ffmpeg acerta o quadro exato (provado: com -ss 3 começou no quadro 75 de um
// 25fps). O tempo da saída recomeça do zero — os keyframes de 30s contam do novo começo, e o
// out_time da -progress também (o percentual usa a duração já cortada). O -t depois do -i é
// quanto da entrada fica.

// Na leitura: -v error deixa só os erros no log, e a -progress pipe:1 manda o andamento no
// formato chave=valor (o LeLinha separa um do outro).
function TFFmpegModel.ParametrosConverter(const AEntrada, ASaida: string; APreset: TPresetConversao;
  AInicio, ADuracao: double): TStringArray;
begin
  Result := nil;
  AdicionaParametros(Result, ['-hide_banner', '-nostdin', '-y', '-v', 'error', '-progress', 'pipe:1', '-nostats']);

  if (AInicio > 0) then
    AdicionaParametros(Result, ['-ss', Segundos(AInicio)]);

  AdicionaParametros(Result, ['-i', AEntrada]);

  if (ADuracao > 0) then
    AdicionaParametros(Result, ['-t', Segundos(ADuracao)]);

  case APreset of
    pcSite1080:
      AdicionaParametros(Result, ['-map', '0:v:0', '-map', '0:a:0?',
        '-vf', 'scale=-2:''trunc(min(1080,ih)/2)*2''',
        '-c:v', 'libx264', '-preset', 'medium', '-profile:v', 'high', '-pix_fmt', 'yuv420p', '-crf', '23',
        '-c:a', 'aac', '-b:a', '128k', '-ac', '2']);

    pcSite720:
      AdicionaParametros(Result, ['-map', '0:v:0', '-map', '0:a:0?',
        '-vf', 'scale=-2:''trunc(min(720,ih)/2)*2''',
        '-c:v', 'libx264', '-preset', 'medium', '-profile:v', 'high', '-pix_fmt', 'yuv420p', '-crf', '23',
        '-c:a', 'aac', '-b:a', '128k', '-ac', '2']);

    pcProjetor:
      AdicionaParametros(Result, ['-map', '0:v:0', '-map', '0:a?',
        '-vf', 'scale=-2:''trunc(min(1080,ih)/2)*2''',
        '-c:v', 'libx264', '-profile:v', 'high', '-level', '4.1', '-pix_fmt', 'yuv420p', '-crf', '20',
        '-c:a', 'aac', '-b:a', '160k']);

    pcWhatsApp:
      AdicionaParametros(Result, ['-map', '0:v:0', '-map', '0:a:0?',
        '-vf', 'scale=''trunc(iw*min(1,720/min(iw,ih))/2)*2'':''trunc(ih*min(1,720/min(iw,ih))/2)*2''',
        '-c:v', 'libx264', '-preset', 'medium', '-profile:v', 'high', '-pix_fmt', 'yuv420p', '-crf', '23',
        '-force_key_frames', Format('expr:gte(t,n_forced*%d)', [PEDACO_SEGUNDOS]),
        '-c:a', 'aac', '-b:a', '128k', '-ac', '2']);
  end;

  if (APreset = pcWhatsApp) then
    // ⚠ O nome vira PADRÃO do segment: um "%" que já esteja no nome do arquivo vai dobrado.
    AdicionaParametros(Result, ['-f', 'segment', '-segment_time', IntToStr(PEDACO_SEGUNDOS),
      '-segment_time_delta', '0.01', '-segment_start_number', '1', '-reset_timestamps', '1',
      '-segment_format_options', 'movflags=+faststart',
      StringReplace(ChangeFileExt(ASaida, ''), '%', '%%', [rfReplaceAll]) + PEDACO_PADRAO_FFMPEG])
  else
    AdicionaParametros(Result, ['-movflags', '+faststart', ASaida]);
end;

//=========================================================== PARAMETROS SONDA =================================================\\
// Saída no formato "chave=valor", uma por linha, na ordem do ffprobe: para cada trilha vem o
// codec_name e depois o codec_type; a duration do arquivo vem por último.
function TFFmpegModel.ParametrosSonda(const AArquivo: string): TStringArray;
begin
  Result := nil;
  AdicionaParametros(Result, ['-v', 'error', '-show_entries', 'format=duration:stream=codec_type,codec_name',
    '-of', 'default=noprint_wrappers=1', AArquivo]);
end;

//=============================================================== LE SONDA =====================================================\\
// Fica com a PRIMEIRA trilha de vídeo e a PRIMEIRA de áudio — as mesmas que a conversão usa
// (-map 0:v:0 / 0:a:0).
function TFFmpegModel.LeSonda(ASaida: TStrings): TSonda;
var
  I, auxP: integer;
  auxChave, auxValor, auxUltimoCodec: string;
  auxDuracao: double;
begin
  Result.Duracao := 0;
  Result.CodecVideo := EmptyStr;
  Result.CodecAudio := EmptyStr;
  auxUltimoCodec := EmptyStr;

  for I := 0 to Pred(ASaida.Count) do
  begin
    auxP := Pos('=', ASaida[I]);
    if (auxP = 0) then Continue;

    auxChave := Trim(Copy(ASaida[I], 1, auxP - 1));
    auxValor := Trim(Copy(ASaida[I], auxP + 1, MaxInt));

    if (auxChave = 'codec_name') then
      auxUltimoCodec := auxValor
    else if (auxChave = 'codec_type') then
    begin
      if (auxValor = 'video') and (Result.CodecVideo = EmptyStr) then
        Result.CodecVideo := auxUltimoCodec
      else if (auxValor = 'audio') and (Result.CodecAudio = EmptyStr) then
        Result.CodecAudio := auxUltimoCodec;
    end
    else if (auxChave = 'duration') and Riba.TextoParaNumero(auxValor, auxDuracao) then
      Result.Duracao := auxDuracao;
  end;
end;

//=========================================================== PRECISA CONVERTER ================================================\\
// Para a conversão automática depois do download: só converte o que NÃO é H.264 + AAC. Sem
// trilha de áudio também serve (vídeo mudo). Sem trilha de vídeo não há o que converter.
function TFFmpegModel.PrecisaConverter(const ASonda: TSonda): boolean;
begin
  if (ASonda.CodecVideo = EmptyStr) then
    Exit(False);

  Result := not ((ASonda.CodecVideo = 'h264') and ((ASonda.CodecAudio = 'aac') or (ASonda.CodecAudio = EmptyStr)));
end;

//=============================================================== NOME SAIDA ===================================================\\
// "D:\Vídeos\festa.mkv" + pasta "E:\Site" -> "E:\Site\conv_festa.mp4". Se já existir, numera:
// "conv_festa (2).mp4", "(3)", ... — nunca sobrescreve um convertido anterior.
// WhatsApp: o nome devolvido não chega a existir — é a base dos pedaços (NomePedaco), e o que
// se confere é se o PRIMEIRO pedaço já existe.
function TFFmpegModel.NomeSaida(const AEntrada, APasta: string; APreset: TPresetConversao): string;
var
  auxPasta, auxBase: string;
  I: integer;
begin
  auxPasta := IncludeTrailingPathDelimiter(APasta);
  auxBase := PREFIXO_CONVERTIDO + ChangeFileExt(ExtractFileName(AEntrada), '');
  Result := auxPasta + auxBase + '.mp4';

  I := 2;
  while FileExists(iif(APreset = pcWhatsApp, NomePedaco(Result, 1), Result)) do
  begin
    Result := Format('%s%s (%d).mp4', [auxPasta, auxBase, I]);
    Inc(I);
  end;
end;

//============================================================== NOME PEDACO ===================================================\\
// "E:\Site\conv_festa.mp4", 2 -> "E:\Site\conv_festa_parte002.mp4": o nome que o segment dá ao
// pedaço número ANumero (o primeiro é o 1, -segment_start_number).
function TFFmpegModel.NomePedaco(const ASaida: string; ANumero: integer): string;
begin
  Result := ChangeFileExt(ASaida, '') + Format(PEDACO_PADRAO_PASCAL, [ANumero]);
end;

//=============================================================== LE LINHA =====================================================\\
// Uma linha da saída do ffmpeg. A -progress manda blocos "chave=valor", com a chave só em
// minúsculas, dígitos e "_"; o resto é mensagem de erro (-v error), que começa com "[" ou
// com palavra seguida de espaço.
// ⚠ Não dá para separar pelo espaço: a própria -progress manda "bitrate= 284.1kbits/s".
// Do bloco interessam duas chaves: out_time_us (onde a conversão está, em microssegundos) e
// speed ("2.5x", quantas vezes mais rápido que o tempo real) — com elas sai o percentual e
// a estimativa do que falta. O speed chega DEPOIS do out_time_us no mesmo bloco; o texto
// usa o do bloco anterior, e meio segundo de atraso não aparece para ninguém.
function TFFmpegModel.LeLinha(const ALinha: string; ADuracao: double; out AProgresso: TProgresso; out ATexto: string): TTipoLinha;
var
  auxLinha, auxChave, auxValor, auxTexto: string;
  auxP: integer;
  auxTempo: double;
begin
  AProgresso.Percentual := -1;
  AProgresso.Detalhe := EmptyStr;
  ATexto := EmptyStr;
  auxLinha := Trim(ALinha);

  if (auxLinha = EmptyStr) then
    Exit(tlIgnorar);

  auxP := Pos('=', auxLinha);
  auxChave := Copy(auxLinha, 1, auxP - 1);
  if (auxP > 1) and EhChaveProgresso(auxChave) then
  begin
    Result := tlIgnorar;
    auxValor := Trim(Copy(auxLinha, auxP + 1, MaxInt));

    if (auxChave = 'speed') then
    begin
      if not Riba.TextoParaNumero(StringReplace(auxValor, 'x', '', []), FVelocidade) then
        FVelocidade := 0;
    end
    else if (auxChave = 'out_time_us') and Riba.TextoParaNumero(auxValor, auxTempo) then
    begin
      auxTempo := Max(0, auxTempo / 1000000);

      if (ADuracao > 0) then
      begin
        AProgresso.Percentual := Min(100, auxTempo * 100 / ADuracao);
        auxTexto := Format('%.0f%% - %s de %s', [AProgresso.Percentual, Riba.FormataTempo(auxTempo), Riba.FormataTempo(ADuracao)]);
      end
      else
        auxTexto := Riba.FormataTempo(auxTempo);

      if (FVelocidade > 0) then
      begin
        auxTexto := auxTexto + Format(' - %.1fx', [FVelocidade]);
        if (ADuracao > auxTempo) then
          auxTexto := auxTexto + ' - faltam ' + Riba.FormataTempo((ADuracao - auxTempo) / FVelocidade);
      end;

      AProgresso.Detalhe := auxTexto;
      Result := tlProgresso;
    end;

    Exit;
  end;

  ATexto := auxLinha;
  Result := tlLog;
end;

//========================================================== EH CHAVE PROGRESSO ================================================\\
// "out_time_us", "stream_0_0_q", "bitrate"... — só [a-z0-9_].
function TFFmpegModel.EhChaveProgresso(const AChave: string): boolean;
var
  I: integer;
begin
  Result := (AChave <> EmptyStr);
  for I := 1 to Length(AChave) do
    if not (AChave[I] in ['a'..'z', '0'..'9', '_']) then
      Exit(False);
end;

//================================================================ SEGUNDOS ====================================================\\
// Número para a linha de comando do ffmpeg: sempre com PONTO decimal, nunca a vírgula do
// Windows em português.
function TFFmpegModel.Segundos(AValor: double): string;
var
  auxFS: TFormatSettings;
begin
  auxFS := DefaultFormatSettings;
  auxFS.DecimalSeparator := '.';
  Result := FormatFloat('0.###', AValor, auxFS);
end;

//==============================================================================================================================\\
end.
