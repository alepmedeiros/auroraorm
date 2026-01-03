unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Data.DB, Vcl.DBGrids,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Intf, FireDAC.Phys,
  FireDAC.DApt,
  AuroraInterface, AuroraDAO, AuroraQueryFiredac, AuroraConfig,
  Sample.AuroraHeadless.Entities.Entities.User;

type
  TFormMain = class(TForm)
    FDConnection1: TFDConnection;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    ButtonLoad: TButton;
    ButtonInsert: TButton;
    procedure FormCreate(Sender: TObject);
    procedure ButtonLoadClick(Sender: TObject);
    procedure ButtonInsertClick(Sender: TObject);
  private
    FQuery: iAuroraQuery;
    DAOUser: iAuroraDAO<TUser>;
  end;

var
  FormMain: TFormMain;

implementation

procedure TFormMain.FormCreate(Sender: TObject);
begin
  TAuroraConfig.SetDialect(dbSQLite);
  FDConnection1.Params.Values['DriverID'] := 'SQLite';
  FDConnection1.Params.Database := 'aurora.db';
  FDConnection1.Open;
  FQuery := TAuroraQueryFiredac.New(FDConnection1);
  DAOUser := TAuroraDAO<TUser>.NewAurora(FQuery).DataSource(DataSource1);
end;

procedure TFormMain.ButtonLoadClick(Sender: TObject);
var
  L: TObjectList<TUser>;
begin
  L := TObjectList<TUser>.Create(True);
  try
    DAOUser.SQL.OrderBy('id desc').&End.Find(L);
  finally
    L.Free;
  end;
end;

procedure TFormMain.ButtonInsertClick(Sender: TObject);
var
  U: TUser;
begin
  U := TUser.Create;
  U.Name := 'Novo';
  U.Email := 'novo@example.com';
  DAOUser.Insert(U);
end;

end.
