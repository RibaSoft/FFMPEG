unit RibaCore; {$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Controls, RibaTypes;

type

  //=========================================================== INTERFACE ======================================================\\
  //================ UTILS

  { IRibaTools }

  IRibaTools = interface
    ['{3F0B6C1E-8D52-4A47-9E61-2C7B9A0D4E15}']

    //Dialogos
    procedure Aviso(ATitulo, AMensagem: string);
    procedure Erro(ATitulo, AMensagem: string);
    function Confirma(ATitulo, AMensagem: string): boolean;
    function AbrePasta(ATitulo: string; out ALocal: string): boolean;
    function AbreArquivos(ATitulo, AFiltro: string; AVarios: boolean; AArquivos: TStrings): boolean;

    //Funções
    function StringVazia(ATexto: string): boolean;
    function VersaoApp: string;
    function LocalizaExecutavel(const ANome: string; out ACaminho: string): boolean;
    function PastaParaParametro(const APasta: string): string;

    //Formatadores
    function TextoParaNumero(const ATexto: string; out AValor: double): boolean;
    function FormataBytes(ABytes: double): string;
    function FormataTempo(ASegundos: double): string;
    procedure EstilizaComponentes(AContainer: TWinControl);
  end;

  //================ MODELS

  // O yt-dlp: monta a linha de comando e lê a saída. Não executa nada — quem roda o processo é
  // a thread.tarefa. Assim a regra (formato, opções, leitura) fica num lugar só e a thread só
  // orquestra.
  IYtDlpModel = interface
    ['{8C2E4F71-5B9D-4E0A-A3C6-71D0F2B84E93}']
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
  end;

  // O ffmpeg e o ffprobe: mesma divisão do IYtDlpModel.
  IFFmpegModel = interface
    ['{D4A97B30-1E6C-4F28-8B5D-93E0C6A1F702}']
    //Funções
    function Executavel: string;
    function ExecutavelSonda: string;
    function ParametrosConverter(const AEntrada, ASaida: string; APreset: TPresetConversao): TStringArray;
    function ParametrosSonda(const AArquivo: string): TStringArray;
    function LeSonda(ASaida: TStrings): TSonda;
    function PrecisaConverter(const ASonda: TSonda): boolean;
    function NomeSaida(const AEntrada, APasta: string): string;
    function LeLinha(const ALinha: string; ADuracao: double; out AProgresso: TProgresso; out ATexto: string): TTipoLinha;
  end;

  //================================================== INSTANCIAS PRINCIPAIS ===================================================\\
var
  Riba: IRibaTools;

//============================================================ FACTORY =========================================================\\
procedure NewRiba;
function YtDlpModel: IYtDlpModel;
function FFmpegModel: IFFmpegModel;

//=============================================================== IIF ==========================================================\\
function iif(AValue: boolean; ATrue, AFalse: string): string; overload;

//======================================================== LINHA DE COMANDO ====================================================\\
procedure AdicionaParametros(var AParametros: TStringArray; const AValores: array of string);

implementation

uses
  RibaTools,
  model.ytdlp,
  model.ffmpeg;

//============================================================== NEW RIBA ======================================================\\
procedure NewRiba;
begin
  Riba := TRiba.Create;
end;

//============================================================= YTDLP MODEL ====================================================\\
function YtDlpModel: IYtDlpModel;
begin
  Result := TYtDlpModel.Create;
end;

//============================================================= FFMPEG MODEL ===================================================\\
function FFmpegModel: IFFmpegModel;
begin
  Result := TFFmpegModel.Create;
end;

//=============================================================== IIF ==========================================================\\
function iif(AValue: boolean; ATrue, AFalse: string): string;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

//====================================================== ADICIONA PARAMETROS ===================================================\\
// Acrescenta parâmetros no fim da lista, um por posição, como o TProcess quer.
// ⚠ Parâmetro VAZIO não pode entrar: o TProcess não põe aspas em texto vazio, e ele some da
// linha de comando — o parâmetro seguinte vira o valor da opção anterior.
procedure AdicionaParametros(var AParametros: TStringArray; const AValores: array of string);
var
  I, auxN: integer;
begin
  for I := 0 to High(AValores) do
  begin
    if (AValores[I] = EmptyStr) then
      raise Exception.Create('AdicionaParametros: parâmetro vazio na linha de comando');

    auxN := Length(AParametros);
    SetLength(AParametros, auxN + 1);
    AParametros[auxN] := AValores[I];
  end;
end;

//==============================================================================================================================\\
end.
