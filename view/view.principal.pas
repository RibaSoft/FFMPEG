unit view.principal; {$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, ComCtrls,
  Buttons, libBotao, RibaCore, RibaTypes, thread.tarefa;

type

  { TPrincipalView }

  TPrincipalView = class(TForm)
    btnAtualizar: TBotao;
    btnBaixar: TBotao;
    btnCancelar: TBotao;
    btnConverter: TBotao;
    btnImportarLista: TBotao;
    CheckBoxConverter: TCheckBox;
    ComboBoxTipo: TComboBox;
    EditElimIni: TEdit;
    EditElimFim: TEdit;
    EditLocal: TEdit;
    EditLink: TEdit;
    GroupBoxAndamento: TGroupBox;
    GroupBoxConverter: TGroupBox;
    GroupBoxBaixarYoutube: TGroupBox;
    ImageList24: TImageList;
    LabelElimIni: TLabel;
    LabelElimFim: TLabel;
    LabelStatus: TLabel;
    LabelTipo: TLabel;
    LabelArquivo: TLabel;
    LabelLink: TLabel;
    MemoLog: TMemo;
    ProgressBar: TProgressBar;
    RadioGroupTipo: TRadioGroup;
    btnBusca: TSpeedButton;
    procedure btnAtualizarClick(Sender: TObject);
    procedure btnBaixarClick(Sender: TObject);
    procedure btnBuscaClick(Sender: TObject);
    procedure btnCancelarClick(Sender: TObject);
    procedure btnConverterClick(Sender: TObject);
    procedure btnImportarListaClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure RadioGroupTipoClick(Sender: TObject);
  private
    // Os vídeos escolhidos no btnBusca — o EditLocal só MOSTRA a escolha (é ReadOnly).
    FArquivos: TStringList;
    // A tarefa em andamento; nil = nada rodando. Quem zera é o TarefaTerminou.
    FTarefa: TTarefaThread;
    // Fechar com tarefa rodando: cancela, espera ela terminar, e o TarefaTerminou fecha.
    FFechando: boolean;
    procedure Baixa(ALinks: TStrings);
    procedure IniciaTarefa(ATarefa: TTarefaThread);
    function LeCorte(AEdit: TEdit; out ASegundos: double): boolean;
    procedure ModoOcupado(AOcupado: boolean);
    procedure MostraFerramentas;
    procedure TarefaLog(const ATexto: string);
    procedure TarefaProgresso(const ATitulo: string; const AProgresso: TProgresso);
    procedure TarefaTerminou(Sender: TObject);
  public

  end;

var
  PrincipalView: TPrincipalView;

implementation

{$R *.lfm}

//================================================================= FORM CREATE ================================================\\
procedure TPrincipalView.FormCreate(Sender: TObject);
var
  auxPreset: TPresetConversao;
begin
  FArquivos := TStringList.Create;
  FTarefa := nil;
  FFechando := False;

  NewRiba;
  Riba.EstilizaComponentes(Self);

  // Exceção ao maiúsculas do estilizador: link do YouTube e caminho de arquivo diferenciam
  // maiúscula de minúscula ("?v=dQw4w9WgXcQ").
  EditLink.CharCase := ecNormal;
  EditLocal.CharCase := ecNormal;

  ComboBoxTipo.Items.Clear;
  for auxPreset := Low(TPresetConversao) to High(TPresetConversao) do
    ComboBoxTipo.Items.Add(PRESET_NOME[auxPreset]);
  ComboBoxTipo.ItemIndex := Ord(pcSite1080);

  // ⚠ ItemIndex igual ao do .lfm não dispara o OnClick (LIVRO cap. 11.3): o handler é
  // chamado na mão.
  RadioGroupTipo.ItemIndex := Ord(tbVideo);
  RadioGroupTipoClick(RadioGroupTipo);

  Caption := 'FFMPEG - Baixar e Converter Vídeos - ' + Riba.VersaoApp;
  ProgressBar.Min := 0;
  ProgressBar.Max := 100;
  ProgressBar.Position := 0;
  LabelStatus.Caption := 'Pronto.';

  ModoOcupado(False);
  MostraFerramentas;
end;

//================================================================ FORM DESTROY ================================================\\
procedure TPrincipalView.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FArquivos);
end;

//============================================================== FORM CLOSE QUERY ==============================================\\
// Fechar no meio de uma tarefa deixaria a thread mandando log para uma tela que não existe
// mais (e o yt-dlp/ffmpeg rodando sozinho). Então: cancela, e quem fecha é o TarefaTerminou.
procedure TPrincipalView.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if not Assigned(FTarefa) then Exit;

  CanClose := False;
  if FFechando then Exit;

  if Riba.Confirma('Tarefa em andamento', 'Cancelar o que está rodando e fechar o programa?') then
  begin
    FFechando := True;
    LabelStatus.Caption := 'Cancelando para fechar...';
    if Assigned(FTarefa) then
      FTarefa.Cancela;
  end;
end;

//============================================================ RADIO GROUP TIPO CLICK ==========================================\\
// A conversão automática só existe para vídeo.
procedure TPrincipalView.RadioGroupTipoClick(Sender: TObject);
begin
  CheckBoxConverter.Enabled := (RadioGroupTipo.ItemIndex = Ord(tbVideo)) and not Assigned(FTarefa);
end;

//================================================================= BTN BAIXAR =================================================\\
procedure TPrincipalView.btnBaixarClick(Sender: TObject);
var
  auxLinks: TStringList;
begin
  if Riba.StringVazia(EditLink.Text) then
  begin
    Riba.Aviso('Baixar', 'Cole o link do YouTube no campo Link.');
    EditLink.SetFocus;
    Exit;
  end;

  auxLinks := TStringList.Create;
  try
    auxLinks.Add(Trim(EditLink.Text));
    Baixa(auxLinks);
  finally
    FreeAndNil(auxLinks);
  end;
end;

//============================================================= BTN IMPORTAR LISTA =============================================\\
// Um .txt com um link por linha. Linha vazia, comentário e link repetido são descartados
// antes (YtDlpModel.LimpaLista).
procedure TPrincipalView.btnImportarListaClick(Sender: TObject);
var
  auxArquivos, auxLinks: TStringList;
  auxQtd: integer;
begin
  auxArquivos := nil;
  auxLinks := nil;
  try
    auxArquivos := TStringList.Create;
    auxLinks := TStringList.Create;

    if not Riba.AbreArquivos('Lista de links para baixar', FILTRO_LISTA, False, auxArquivos) then Exit;

    auxLinks.LoadFromFile(auxArquivos[0]);
    auxQtd := YtDlpModel.LimpaLista(auxLinks);

    if (auxQtd = 0) then
    begin
      Riba.Aviso('Importar lista', 'O arquivo não tem nenhum link.');
      Exit;
    end;

    MemoLog.Lines.Add(Format('Lista %s: %d link(s).', [ExtractFileName(auxArquivos[0]), auxQtd]));
    Baixa(auxLinks);
  finally
    FreeAndNil(auxArquivos);
    FreeAndNil(auxLinks);
  end;
end;

//=================================================================== BAIXA ====================================================\\
// O que o btnBaixar e o btnImportarLista têm em comum: pede a pasta e solta a tarefa.
procedure TPrincipalView.Baixa(ALinks: TStrings);
var
  auxPasta: string;
  auxTarefa: TTarefaThread;
begin
  if not Riba.AbrePasta('Pasta onde salvar os downloads', auxPasta) then Exit;

  auxTarefa := TTarefaThread.Create(ttBaixar);
  auxTarefa.Itens.Assign(ALinks);
  auxTarefa.Pasta := auxPasta;
  auxTarefa.TipoBaixar := TTipoBaixar(RadioGroupTipo.ItemIndex);
  auxTarefa.ConverteSeNecessario := CheckBoxConverter.Checked and (auxTarefa.TipoBaixar = tbVideo);
  IniciaTarefa(auxTarefa);
end;

//================================================================== BTN BUSCA =================================================\\
procedure TPrincipalView.btnBuscaClick(Sender: TObject);
var
  auxArquivos: TStringList;
begin
  auxArquivos := TStringList.Create;
  try
    // Cancelar o diálogo mantém a escolha anterior.
    if not Riba.AbreArquivos('Vídeos para converter', FILTRO_VIDEOS, True, auxArquivos) then Exit;

    FArquivos.Assign(auxArquivos);
    if (FArquivos.Count = 1) then
      EditLocal.Text := FArquivos[0]
    else
      EditLocal.Text := Format('%d arquivos (%s, ...)', [FArquivos.Count, ExtractFileName(FArquivos[0])]);
    EditLocal.Hint := FArquivos.Text;
  finally
    FreeAndNil(auxArquivos);
  end;
end;

//================================================================ BTN CONVERTER ===============================================\\
procedure TPrincipalView.btnConverterClick(Sender: TObject);
var
  auxPasta: string;
  auxTarefa: TTarefaThread;
  auxInicio, auxFim: double;
begin
  if (FArquivos.Count = 0) then
  begin
    Riba.Aviso('Converter', 'Escolha o(s) vídeo(s) na lupa ao lado do campo de arquivo.');
    Exit;
  end;

  if (ComboBoxTipo.ItemIndex < 0) then
  begin
    Riba.Aviso('Converter', 'Escolha o tipo de saída.');
    Exit;
  end;

  if not LeCorte(EditElimIni, auxInicio) then Exit;
  if not LeCorte(EditElimFim, auxFim) then Exit;

  if not Riba.AbrePasta('Pasta onde salvar os vídeos convertidos', auxPasta) then Exit;

  auxTarefa := TTarefaThread.Create(ttConverter);
  auxTarefa.Itens.Assign(FArquivos);
  auxTarefa.Pasta := auxPasta;
  auxTarefa.Preset := TPresetConversao(ComboBoxTipo.ItemIndex);
  auxTarefa.CorteInicio := auxInicio;
  auxTarefa.CorteFim := auxFim;
  IniciaTarefa(auxTarefa);
end;

//=================================================================== LE CORTE =================================================\\
// Os segundos de um campo de corte. Vazio = 0 (não corta). Aceita vírgula ou ponto ("2,5").
// Se o corte passar do tamanho de algum vídeo, quem avisa é a conversão (só ela sabe a duração).
function TPrincipalView.LeCorte(AEdit: TEdit; out ASegundos: double): boolean;
var
  auxTexto: string;
begin
  ASegundos := 0;
  auxTexto := StringReplace(Trim(AEdit.Text), ',', '.', []);
  if (auxTexto = EmptyStr) then
    Exit(True);

  Result := Riba.TextoParaNumero(auxTexto, ASegundos) and (ASegundos >= 0);
  if not Result then
  begin
    Riba.Aviso('Converter', 'O corte é em segundos (ex.: 5 ou 2,5). Deixe vazio para não cortar.');
    AEdit.SetFocus;
  end;
end;

//================================================================ BTN ATUALIZAR ===============================================\\
procedure TPrincipalView.btnAtualizarClick(Sender: TObject);
begin
  IniciaTarefa(TTarefaThread.Create(ttAtualizar));
end;

//================================================================ BTN CANCELAR ================================================\\
procedure TPrincipalView.btnCancelarClick(Sender: TObject);
begin
  if not Assigned(FTarefa) then Exit;

  LabelStatus.Caption := 'Cancelando...';
  FTarefa.Cancela;
end;

//================================================================ INICIA TAREFA ===============================================\\
// A tarefa roda na thread; o clique termina na hora. Por isso o btnCancelar funciona — o
// TBotao não aceita segundo clique enquanto o OnClick do primeiro não volta (LIVRO cap. 7.4).
procedure TPrincipalView.IniciaTarefa(ATarefa: TTarefaThread);
begin
  ATarefa.OnLog := @TarefaLog;
  ATarefa.OnProgresso := @TarefaProgresso;
  ATarefa.OnTerminate := @TarefaTerminou;

  FTarefa := ATarefa;
  ModoOcupado(True);

  if (MemoLog.Lines.Count > 0) then
    MemoLog.Lines.Add(EmptyStr);
  MemoLog.Lines.Add(FormatDateTime('dd/mm/yyyy hh:nn:ss', Now) + ' ' + StringOfChar('-', 60));
  ProgressBar.Position := 0;
  LabelStatus.Caption := 'Iniciando...';

  ATarefa.Start;
end;

//================================================================ TAREFA LOG ==================================================\\
procedure TPrincipalView.TarefaLog(const ATexto: string);
begin
  MemoLog.Lines.Add(ATexto);
  MemoLog.SelStart := Length(MemoLog.Text);
end;

//============================================================== TAREFA PROGRESSO ==============================================\\
procedure TPrincipalView.TarefaProgresso(const ATitulo: string; const AProgresso: TProgresso);
begin
  if (AProgresso.Percentual >= 0) then
    ProgressBar.Position := Round(AProgresso.Percentual);

  if (AProgresso.Detalhe = EmptyStr) then
    LabelStatus.Caption := ATitulo
  else
    LabelStatus.Caption := ATitulo + ' - ' + AProgresso.Detalhe;
end;

//============================================================== TAREFA TERMINOU ===============================================\\
// OnTerminate: roda no thread principal, com a thread ainda viva — é aqui que se lê o
// resultado. Depois daqui ela se libera sozinha.
procedure TPrincipalView.TarefaTerminou(Sender: TObject);
var
  auxTarefa: TTarefaThread;
begin
  auxTarefa := TTarefaThread(Sender);
  FTarefa := nil;
  ModoOcupado(False);

  if auxTarefa.Cancelado then
  begin
    LabelStatus.Caption := 'Cancelado.';
    MemoLog.Lines.Add('Cancelado pelo usuário.');
  end
  else if (auxTarefa.Erros > 0) then
  begin
    LabelStatus.Caption := Format('Concluído com %d erro(s) - veja o log abaixo.', [auxTarefa.Erros]);
    MemoLog.Lines.Add(LabelStatus.Caption);
  end
  else
  begin
    ProgressBar.Position := 100;
    LabelStatus.Caption := 'Concluído.';
    MemoLog.Lines.Add('Concluído.');
  end;
  MemoLog.SelStart := Length(MemoLog.Text);

  if FFechando then
    Close;
end;

//================================================================= MODO OCUPADO ===============================================\\
// Dono único do Enabled dos controles: com tarefa rodando, só o Cancelar funciona.
procedure TPrincipalView.ModoOcupado(AOcupado: boolean);
begin
  btnBaixar.Enabled := not AOcupado;
  btnImportarLista.Enabled := not AOcupado;
  btnAtualizar.Enabled := not AOcupado;
  btnConverter.Enabled := not AOcupado;
  btnBusca.Enabled := not AOcupado;
  EditLink.Enabled := not AOcupado;
  RadioGroupTipo.Enabled := not AOcupado;
  ComboBoxTipo.Enabled := not AOcupado;
  EditElimIni.Enabled := not AOcupado;
  EditElimFim.Enabled := not AOcupado;
  btnCancelar.Enabled := AOcupado;
  RadioGroupTipoClick(RadioGroupTipo);
end;

//============================================================== MOSTRA FERRAMENTAS ============================================\\
// Na abertura, o log diz QUAL yt-dlp/ffmpeg vai ser usado — e avisa o que falta.
procedure TPrincipalView.MostraFerramentas;
var
  auxCaminho: string;
begin
  auxCaminho := YtDlpModel.Executavel;
  MemoLog.Lines.Add('yt-dlp:  ' + iif(auxCaminho = EmptyStr, 'NÃO ENCONTRADO - use "Atualizar yt-dlp"', auxCaminho));

  auxCaminho := FFmpegModel.Executavel;
  MemoLog.Lines.Add('ffmpeg:  ' + iif(auxCaminho = EmptyStr, 'NÃO ENCONTRADO no PATH', auxCaminho));

  auxCaminho := FFmpegModel.ExecutavelSonda;
  MemoLog.Lines.Add('ffprobe: ' + iif(auxCaminho = EmptyStr, 'NÃO ENCONTRADO no PATH', auxCaminho));
end;

//==============================================================================================================================\\
end.
