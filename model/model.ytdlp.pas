unit model.ytdlp; {$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math, RibaCore, RibaTypes;

type

  { TYtDlpModel }

  TYtDlpModel = class(TInterfacedObject, IYtDlpModel)
  public
    //Funções
    function Executavel: string;
    function TemCopiaLocal: boolean;
    function ParametrosBaixar(const AArquivoLista, APasta: string; ATipo: TTipoBaixar;
      AAceitaQualquerCodec: boolean): TStringArray;
    function ParametrosAtualizar: TStringArray;
    function ParametrosVersao: TStringArray;
    function ParametrosInstalar(const ADestino: string): TStringArray;
    function LimpaLista(ALinhas: TStrings): integer;
    function LeLinha(const ALinha: string; out AProgresso: TProgresso; out ATexto: string): TTipoLinha;
  private
    function LeProgresso(const ADados: string): TProgresso;
  end;

implementation

//============================================================== EXECUTAVEL ====================================================\\
// A cópia da pasta do programa vence a do PATH: é ela que o "Atualizar yt-dlp" mantém em dia
// (DECISOES.md § 3). Vazio = não há yt-dlp nenhum.
function TYtDlpModel.Executavel: string;
begin
  if TemCopiaLocal then
    Result := ExpandFileName(YTDLP_LOCAL)
  else if not Riba.LocalizaExecutavel(YTDLP_EXE, Result) then
    Result := EmptyStr;
end;

//=========================================================== TEM COPIA LOCAL ==================================================\\
function TYtDlpModel.TemCopiaLocal: boolean;
begin
  Result := FileExists(YTDLP_LOCAL);
end;

//========================================================== PARAMETROS BAIXAR =================================================\\
// A linha de comando do download. Base: o baixar_Video_projetor.bat (vídeo) e o
// baixar_hinos.sh (MP3), com o que a leitura pela tela precisa:
//   --print / --progress-template .. cada linha útil sai com um marcador ([ITEM], [PROG],
//                                    [POS], [ARQ]) que o LeLinha separa do resto;
//   --print implica --quiet ......... por isso o --progress, que devolve a barra, e o
//                                    --no-simulate, que garante o download de verdade;
//   --newline ....................... cada atualização da barra numa linha (sem \r);
//   --progress-delta ................ no máximo duas atualizações por segundo na tela;
//   --encoding utf-8 ................ título com acento chega certo pelo cano;
//   --no-playlist ................... link de vídeo com "&list=" baixa só o vídeo (link de
//                                    playlist pura continua baixando a playlist inteira);
//   -P pasta + -o "%(title)s..." .... a pasta vai separada do modelo de nome, então um "%"
//                                    no nome da pasta não é lido como campo do modelo.
function TYtDlpModel.ParametrosBaixar(const AArquivoLista, APasta: string; ATipo: TTipoBaixar;
  AAceitaQualquerCodec: boolean): TStringArray;
var
  auxPasta: string;
begin
  Result := nil;
  auxPasta := Riba.PastaParaParametro(APasta);

  AdicionaParametros(Result, [
    '--encoding', 'utf-8',
    '--newline',
    '--progress',
    '--progress-delta', '0.5',
    '--no-simulate',
    '--no-playlist',
    '--ignore-errors',
    '--no-overwrites',
    '--progress-template', 'download:' + MARCA_PROGRESSO +
      '%(progress.downloaded_bytes)s|%(progress.total_bytes,progress.total_bytes_estimate)s|' +
      '%(progress.speed)s|%(progress.eta)s',
    '--progress-template', 'postprocess:' + MARCA_POS_PROCESSO + '%(progress.postprocessor)s',
    '--print', 'before_dl:' + MARCA_ITEM + '%(playlist_index|)s|%(title)s',
    '--print', 'after_move:' + MARCA_ARQUIVO + '%(filepath)s',
    '-P', auxPasta,
    '-o', '%(title)s.%(ext)s']);

  case ATipo of
    tbVideo:
      AdicionaParametros(Result, [
        '-f', YTDLP_FORMATO_H264 + iif(AAceitaQualquerCodec, YTDLP_FORMATO_QUALQUER, ''),
        '--merge-output-format', 'mp4']);

    tbMP3:
      // O histórico fica na pasta de destino: baixar a mesma lista de novo na mesma pasta
      // pula o que já veio (é o --download-archive do baixar_hinos.sh).
      AdicionaParametros(Result, [
        '-x', '--audio-format', 'mp3', '--audio-quality', '0',
        '--download-archive', IncludeTrailingPathDelimiter(APasta) + YTDLP_HISTORICO]);
  end;

  AdicionaParametros(Result, ['-a', AArquivoLista]);
end;

//========================================================= PARAMETROS ATUALIZAR ===============================================\\
// Só serve para a cópia da pasta do programa: o yt-dlp do Chocolatey fica em
// C:\ProgramData, que pede administrador, e quem atualiza aquele é o "choco upgrade".
function TYtDlpModel.ParametrosAtualizar: TStringArray;
begin
  Result := nil;
  AdicionaParametros(Result, ['--update']);
end;

//========================================================== PARAMETROS VERSAO =================================================\\
function TYtDlpModel.ParametrosVersao: TStringArray;
begin
  Result := nil;
  AdicionaParametros(Result, ['--version']);
end;

//========================================================= PARAMETROS INSTALAR ================================================\\
// A primeira cópia local vem pelo curl.exe do próprio Windows, direto do GitHub oficial.
//   -L ..... segue o redirecionamento do "latest" para o arquivo de verdade;
//   --fail . erro HTTP vira código de saída (sem isso a página de erro seria salva como .exe);
//   -sS .... sem barra de progresso, mas com a mensagem de erro.
function TYtDlpModel.ParametrosInstalar(const ADestino: string): TStringArray;
begin
  Result := nil;
  AdicionaParametros(Result, ['-L', '--fail', '-sS', '-o', ADestino, YTDLP_URL_DOWNLOAD]);
end;

//============================================================= LIMPA LISTA ====================================================\\
// O awk 'NF && !visto[$0]++' do baixar_hinos.sh: tira espaço das pontas, linha vazia,
// comentário ("#", ";" e "]", os mesmos que o próprio yt-dlp ignora) e repetido, mantendo a
// ordem. Repetido compara EXATO — link do YouTube diferencia maiúscula de minúscula.
// Devolve quantos links sobraram.
function TYtDlpModel.LimpaLista(ALinhas: TStrings): integer;
var
  auxVistos: TStringList;
  auxLimpa: TStringList;
  auxLinha: string;
  I: integer;
begin
  auxVistos := nil;
  auxLimpa := nil;
  try
    auxVistos := TStringList.Create;
    auxVistos.Sorted := True;
    auxVistos.CaseSensitive := True;
    auxVistos.Duplicates := dupIgnore;
    auxLimpa := TStringList.Create;

    for I := 0 to Pred(ALinhas.Count) do
    begin
      auxLinha := Trim(ALinhas[I]);
      if (auxLinha = EmptyStr) then Continue;
      if (auxLinha[1] in ['#', ';', ']']) then Continue;
      if (auxVistos.IndexOf(auxLinha) >= 0) then Continue;

      auxVistos.Add(auxLinha);
      auxLimpa.Add(auxLinha);
    end;

    ALinhas.Assign(auxLimpa);
    Result := ALinhas.Count;
  finally
    FreeAndNil(auxVistos);
    FreeAndNil(auxLimpa);
  end;
end;

//=============================================================== LE LINHA =====================================================\\
// Uma linha da saída do yt-dlp:
//   [ITEM]índice|título ... começou um vídeo (ATexto = título, com o nº quando é playlist);
//   [PROG]dados ........... progresso do download;
//   [POS]nome ............. pós-processamento (junção de áudio e vídeo, extração do MP3);
//   [ARQ]caminho .......... arquivo pronto na pasta de destino (ATexto = caminho completo);
//   o resto ............... mensagem (ERROR:/WARNING:, ou a saída do --update).
function TYtDlpModel.LeLinha(const ALinha: string; out AProgresso: TProgresso; out ATexto: string): TTipoLinha;
var
  auxLinha, auxIndice: string;
  auxP: integer;
begin
  AProgresso.Percentual := -1;
  AProgresso.Detalhe := EmptyStr;
  ATexto := EmptyStr;
  auxLinha := Trim(ALinha);

  if (auxLinha = EmptyStr) then
    Exit(tlIgnorar);

  if auxLinha.StartsWith(MARCA_PROGRESSO) then
  begin
    AProgresso := LeProgresso(Copy(auxLinha, Length(MARCA_PROGRESSO) + 1, MaxInt));
    Exit(tlProgresso);
  end;

  if auxLinha.StartsWith(MARCA_POS_PROCESSO) then
  begin
    AProgresso.Detalhe := Format('processando (%s)...', [Copy(auxLinha, Length(MARCA_POS_PROCESSO) + 1, MaxInt)]);
    Exit(tlProgresso);
  end;

  if auxLinha.StartsWith(MARCA_ITEM) then
  begin
    // Só o PRIMEIRO "|" separa: o título pode ter outros.
    auxLinha := Copy(auxLinha, Length(MARCA_ITEM) + 1, MaxInt);
    auxP := Pos('|', auxLinha);
    auxIndice := Copy(auxLinha, 1, auxP - 1);
    ATexto := Copy(auxLinha, auxP + 1, MaxInt);
    if (auxIndice <> EmptyStr) then
      ATexto := Format('#%s %s', [auxIndice, ATexto]);
    Exit(tlItem);
  end;

  if auxLinha.StartsWith(MARCA_ARQUIVO) then
  begin
    ATexto := Copy(auxLinha, Length(MARCA_ARQUIVO) + 1, MaxInt);
    Exit(tlArquivo);
  end;

  ATexto := auxLinha;
  Result := tlLog;
end;

//============================================================= LE PROGRESSO ===================================================\\
// "baixado|total|velocidade|eta", como montado no --progress-template do ParametrosBaixar.
// Qualquer campo pode vir "NA" (o total, em transmissão por fragmentos, é estimado e às vezes
// nem isso): o que faltar só some do texto; sem total a barra não anda.
function TYtDlpModel.LeProgresso(const ADados: string): TProgresso;
var
  auxPartes: TStringArray;
  auxBaixado, auxTotal, auxVelocidade, auxEta: double;
  auxTemBaixado, auxTemTotal: boolean;
  auxTexto: string;
begin
  Result.Percentual := -1;
  Result.Detalhe := EmptyStr;

  auxPartes := ADados.Split(['|']);
  if (Length(auxPartes) < 4) then Exit;

  auxTemBaixado := Riba.TextoParaNumero(auxPartes[0], auxBaixado);
  auxTemTotal := Riba.TextoParaNumero(auxPartes[1], auxTotal) and (auxTotal > 0);

  auxTexto := EmptyStr;
  if auxTemBaixado and auxTemTotal then
  begin
    Result.Percentual := Min(100, auxBaixado * 100 / auxTotal);
    auxTexto := Format('%.0f%% - %s de %s', [Result.Percentual, Riba.FormataBytes(auxBaixado), Riba.FormataBytes(auxTotal)]);
  end
  else if auxTemBaixado then
    auxTexto := Riba.FormataBytes(auxBaixado);

  if Riba.TextoParaNumero(auxPartes[2], auxVelocidade) and (auxVelocidade > 0) then
    auxTexto := auxTexto + ' - ' + Riba.FormataBytes(auxVelocidade) + '/s';

  if Riba.TextoParaNumero(auxPartes[3], auxEta) then
    auxTexto := auxTexto + ' - faltam ' + Riba.FormataTempo(auxEta);

  Result.Detalhe := auxTexto;
end;

//==============================================================================================================================\\
end.
