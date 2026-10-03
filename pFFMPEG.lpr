program pFFMPEG;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  // framework RibaSoft
  RibaTypes,
  RibaCore,
  RibaTools,
  // regra de negócio (montagem e leitura da linha de comando do yt-dlp e do ffmpeg)
  model.ytdlp,
  model.ffmpeg,
  // tarefas de fundo
  thread.tarefa,
  // telas
  view.principal;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'FFMPEG';
  Application.Scaled := True;
  {$PUSH}
  {$WARN 5044 OFF}
  Application.MainFormOnTaskbar := True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TPrincipalView, PrincipalView);
  Application.Run;
end.
