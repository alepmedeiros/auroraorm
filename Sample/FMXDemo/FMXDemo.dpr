program FMXDemo;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.ListView,
  FMX.Layouts,
  MainForm in 'MainForm.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
