unit RibaTools; {$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, RibaCore, StdCtrls, Controls, Dialogs, ExtCtrls, Forms, Graphics, LCLType, RibaTypes,
  ComCtrls, fileinfo, FileUtil;

type

  { TRiba }

  TRiba = class(TInterfacedObject, IRibaTools)
  public
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
  private
    procedure FormTeclasPadrao(Sender: TObject; var Key: word; Shift: TShiftState);
  end;

implementation

{ TRibaTools }

//================================================================ AVISO =======================================================\\
procedure TRiba.Aviso(ATitulo, AMensagem: string);
var
  auxT: TTaskDialog;
begin
  // nil ANTES do try: se o Create falhar, o FreeAndNil do finally recebe nil (que não faz nada)
  // em vez de lixo de memória — que daria um segundo erro escondendo o verdadeiro.
  auxT := nil;
  try
    auxT := TTaskDialog.Create(nil);
    auxT.Caption := 'Aviso:';
    auxT.Title := ATitulo;
    auxT.Text := AMensagem;
    auxT.MainIcon := tdiWarning;
    auxT.CommonButtons := [tcbOk];
    auxT.Execute;
  finally
    FreeAndNil(auxT);
  end;
end;

//================================================================== ERRO ======================================================\\
procedure TRiba.Erro(ATitulo, AMensagem: string);
var
  auxT: TTaskDialog;
begin
  auxT := nil;   // segurança antes do "try" - ver explicação no Aviso
  try
    auxT := TTaskDialog.Create(nil);
    auxT.Caption := 'Erro:';
    auxT.Title := ATitulo;
    auxT.Text := AMensagem;
    auxT.MainIcon := tdiError;
    auxT.CommonButtons := [tcbOk];
    auxT.Execute;
  finally
    FreeAndNil(auxT);
  end;
end;

//============================================================== CONFIRMA ======================================================\\
function TRiba.Confirma(ATitulo, AMensagem: string): boolean;
var
  auxT: TTaskDialog;
begin
  auxT := nil;   // segurança antes do "try" - ver explicação no Aviso
  try
    auxT := TTaskDialog.Create(nil);
    auxT.Caption := 'Confirmação:';
    auxT.Title := ATitulo;
    auxT.Text := AMensagem;
    auxT.MainIcon := tdiQuestion;
    auxT.CommonButtons := [tcbNo, tcbYes];
    auxT.DefaultButton := tcbNo;
    auxT.Execute;
    Result := (auxT.ModalResult = mrYes);
  finally
    FreeAndNil(auxT);
  end;
end;

//============================================================ ABRE PASTA ======================================================\\
function TRiba.AbrePasta(ATitulo: string; out ALocal: string): boolean;
var
  auxP: TSelectDirectoryDialog;
begin
  auxP := nil;   // segurança antes do "try" - ver explicação no Aviso
  Result := False;
  ALocal := EmptyStr;

  try
    auxP := TSelectDirectoryDialog.Create(nil);
    auxP.Title := ATitulo;
    auxP.Options := auxP.Options + [ofPathMustExist, ofEnableSizing];

    if (auxP.Execute) then
    begin
      Result := True;
      ALocal := auxP.FileName;
    end;
  finally
    FreeAndNil(auxP);
  end;
end;

//=========================================================== ABRE ARQUIVOS ====================================================\\
// Irmão do AbrePasta: devolve em AArquivos os escolhidos (um só, ou vários com AVarios).
// AArquivos é limpo antes, então False sempre volta com a lista vazia.
function TRiba.AbreArquivos(ATitulo, AFiltro: string; AVarios: boolean; AArquivos: TStrings): boolean;
var
  auxD: TOpenDialog;
begin
  auxD := nil;   // segurança antes do "try" - ver explicação no Aviso
  Result := False;
  AArquivos.Clear;

  try
    auxD := TOpenDialog.Create(nil);
    auxD.Title := ATitulo;
    auxD.Filter := AFiltro;
    auxD.Options := auxD.Options + [ofFileMustExist, ofEnableSizing];
    if AVarios then
      auxD.Options := auxD.Options + [ofAllowMultiSelect];

    if (auxD.Execute) then
    begin
      AArquivos.AddStrings(auxD.Files);
      Result := (AArquivos.Count > 0);
    end;
  finally
    FreeAndNil(auxD);
  end;
end;

//=========================================================== STRING VAZIA =====================================================\\
function TRiba.StringVazia(ATexto: string): boolean;
begin
  Result := (ATexto.Trim.Length = 0);
end;

//========================================================= VERSAO APP =========================================================\\
// Versão gravada no PRÓPRIO executável (Opções do Projeto > Informações da Versão). Sem
// informação de versão no .exe, cai na data do arquivo.
function TRiba.VersaoApp: string;
var
  auxVersao: TProgramVersion;
  auxD: TDateTime;
begin
  if GetProgramVersion(auxVersao) then
    Result := Format('%d.%d.%d.%d', [auxVersao.Major, auxVersao.Minor, auxVersao.Revision, auxVersao.Build])
  else
  begin
    FileAge(ParamStr(0), auxD);
    Result := FormatDateTime('yy.mm.dd', auxD);
  end;
end;

//======================================================= LOCALIZA EXECUTAVEL ==================================================\\
// Caminho COMPLETO de um executável do PATH. Completo de propósito: o CreateProcess procura
// primeiro na pasta do próprio programa, e um nome solto pode achar outra coisa lá.
function TRiba.LocalizaExecutavel(const ANome: string; out ACaminho: string): boolean;
begin
  ACaminho := FindDefaultExecutablePath(ANome);
  Result := (ACaminho <> EmptyStr);
end;

//======================================================= PASTA PARA PARAMETRO =================================================\\
// Pasta pronta para ir como parâmetro de linha de comando.
// ⚠ Barra no FIM quebra o parâmetro: o TProcess põe aspas em quem tem espaço, e "D:\Meus
// Vídeos\" vira \" — que o Windows lê como aspa escapada, colando o parâmetro seguinte no
// caminho. Sem a barra final não há esse \". A raiz do drive é o caso especial: "D:" sozinho
// é "a pasta corrente do drive D", então ela vai como "D:\.".
function TRiba.PastaParaParametro(const APasta: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(APasta);
  if (Result.EndsWith(':')) then
    Result := Result + '\.';
end;

//========================================================= TEXTO PARA NUMERO ==================================================\\
// Número escrito por programa de linha de comando: SEMPRE com ponto decimal ("1234.5"),
// qualquer que seja o Windows — por isso não dá para usar o StrToFloat da configuração
// regional (que no Brasil espera vírgula). "NA", "N/A", "None" e vazio devolvem False.
function TRiba.TextoParaNumero(const ATexto: string; out AValor: double): boolean;
var
  auxFS: TFormatSettings;
begin
  auxFS := DefaultFormatSettings;
  auxFS.DecimalSeparator := '.';
  auxFS.ThousandSeparator := #0;
  Result := TryStrToFloat(Trim(ATexto), AValor, auxFS);
  if not Result then
    AValor := 0;
end;

//=========================================================== FORMATA BYTES ====================================================\\
function TRiba.FormataBytes(ABytes: double): string;
begin
  if (ABytes < 1024) then
    Result := Format('%.0f B', [ABytes])
  else if (ABytes < 1024 * 1024) then
    Result := Format('%.1f KB', [ABytes / 1024])
  else if (ABytes < 1024 * 1024 * 1024) then
    Result := Format('%.1f MB', [ABytes / (1024 * 1024)])
  else
    Result := Format('%.2f GB', [ABytes / (1024 * 1024 * 1024)]);
end;

//=========================================================== FORMATA TEMPO ====================================================\\
// 75 -> "01:15"; 3725 -> "1:02:05". Negativo vira zero.
function TRiba.FormataTempo(ASegundos: double): string;
var
  auxTotal: int64;
begin
  auxTotal := Round(ASegundos);
  if (auxTotal < 0) then
    auxTotal := 0;

  if (auxTotal >= 3600) then
    Result := Format('%d:%.2d:%.2d', [auxTotal div 3600, (auxTotal mod 3600) div 60, auxTotal mod 60])
  else
    Result := Format('%.2d:%.2d', [auxTotal div 60, auxTotal mod 60]);
end;

//==================================================== ESTILIZA COMPONENTES ====================================================\\
procedure TRiba.EstilizaComponentes(AContainer: TWinControl);
var
  I: integer;
  C: TComboBox;
  L: TLabel;
  CK: TCheckBox;
  P: TPanel;
  PG: TPageControl;
  TS: TTabSheet;
  E: TEdit;
  F: TForm;
  GB: TGroupBox;
begin
  //PrincipalView
  if (AContainer is TForm) then
  begin
    F := TForm(AContainer);
    F.Color := COR_FUNDO;

    //TForm
    if F.Name <> 'PrincipalView' then
    begin
      F.Position := poMainFormCenter;
      F.BorderIcons := [biSystemMenu];
      F.BorderStyle := bsSingle;
      F.KeyPreview := True;
      // Teclado padrão (Esc fecha / Enter = Tab) — só quando o form não define o próprio
      // OnKeyDown.
      if not Assigned(F.OnKeyDown) then
        F.OnKeyDown := @FormTeclasPadrao;
    end;
  end;

  for I := Pred(AContainer.ControlCount) downto 0 do
  begin
    //Combobox
    if AContainer.Controls[I] is TComboBox then
    begin
      C := TComboBox(AContainer.Controls[I]);
      C.ParentFont := False;
      C.Cursor := crHandPoint;
      C.Color := COR_FUNDO_COMPONENT;
      C.Font.Quality := fqCleartype;
      C.ItemHeight := 17;
      C.Style := csOwnerDrawFixed;
    end;

    //Label
    if AContainer.Controls[I] is TLabel then
    begin
      L := TLabel(AContainer.Controls[I]);
      L.ParentFont := False;
      L.ParentColor := False;
      L.Font.Name := 'Segoe UI';
      L.Font.Color := COR_FONTE;

      if L.Name = 'LabelTitulo' then
      begin
        L.Font.Size := 12;
        L.Font.Name := 'Segoe UI Semibold';
      end;
    end;

    //CheckBox
    if AContainer.Controls[I] is TCheckBox then
    begin
      CK := TCheckBox(AContainer.Controls[I]);
      CK.TabStop := False;
    end;

    //Edit
    if AContainer.Controls[I] is TEdit then
    begin
      E := TEdit(AContainer.Controls[I]);
      E.CharCase := ecUppercase;
    end;

    //Panel
    if AContainer.Controls[I] is TPanel then
    begin
      P := TPanel(AContainer.Controls[I]);
      EstilizaComponentes(P);
    end;

    //Page Controls
    if AContainer.Controls[I] is TPageControl then
    begin
      PG := TPageControl(AContainer.Controls[I]);
      EstilizaComponentes(PG);
    end;

    //TabSheet
    if AContainer.Controls[I] is TTabSheet then
    begin
      TS := TTabSheet(AContainer.Controls[I]);
      EstilizaComponentes(TS);
    end;

    //GroupBox
    if AContainer.Controls[I] is TGroupBox then
    begin
      GB := TGroupBox(AContainer.Controls[I]);
      EstilizaComponentes(GB);
    end;
  end;
end;

//========================================================= FORM TECLAS PADRÃO =================================================\\
// Teclado padrão dos forms, anexado pelo EstilizaComponentes só quando o form NÃO define o
// próprio OnKeyDown:
//   ESC   -> fecha o form.
//   ENTER -> faz papel de Tab, mas SÓ num campo de edição de uma linha.
procedure TRiba.FormTeclasPadrao(Sender: TObject; var Key: word; Shift: TShiftState);
var
  auxForm: TCustomForm;
begin
  {$WARN 5024 OFF}// o "Shift" não é usado aqui, e tudo bem
  if not (Sender is TCustomForm) then Exit;
  auxForm := TCustomForm(Sender);

  case Key of
    VK_ESCAPE:
    begin
      Key := 0;
      auxForm.Close;
    end;

    VK_RETURN:
    begin
      if (auxForm.ActiveControl is TCustomEdit) and not (auxForm.ActiveControl is TCustomMemo) then
      begin
        Key := 0;
        auxForm.SelectNext(auxForm.ActiveControl, True, True);
      end;
    end;
  end;
end;

//==============================================================================================================================\\
end.
