unit MainForm;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.ListView, FMX.Layouts,
  Data.DB,
  FireDAC.Comp.Client,
  AuroraConfig, AuroraInterface, AuroraDAO, AuroraQueryFiredac,
  Entities.User in '..\AuroraHeadless\Entities\Entities.User.pas',
  Entities.Order in '..\AuroraHeadless\Entities\Order.pas',
  Entities.Profile in '..\AuroraHeadless\Entities\Profile.pas';

type
  TFormMain = class(TForm)
    BtnLoadUsers: TButton;
    BtnInsertUser: TButton;
    BtnLoadRelations: TButton;
    ListView1: TListView;
    procedure FormCreate(Sender: TObject);
    procedure BtnLoadUsersClick(Sender: TObject);
    procedure BtnInsertUserClick(Sender: TObject);
    procedure BtnLoadRelationsClick(Sender: TObject);
  private
    Conn: TFDConnection;
    Q: iAuroraQuery;
    DAOUser: iAuroraDAO<TUser>;
  end;

var
  FormMain: TFormMain;

implementation

procedure TFormMain.FormCreate(Sender: TObject);
begin
  Width := 800; Height := 600;
  BtnLoadUsers := TButton.Create(Self); BtnLoadUsers.Parent := Self; BtnLoadUsers.Position.X := 10; BtnLoadUsers.Position.Y := 10; BtnLoadUsers.Text := 'Load Users'; BtnLoadUsers.OnClick := BtnLoadUsersClick;
  BtnInsertUser := TButton.Create(Self); BtnInsertUser.Parent := Self; BtnInsertUser.Position.X := 120; BtnInsertUser.Position.Y := 10; BtnInsertUser.Text := 'Insert User'; BtnInsertUser.OnClick := BtnInsertUserClick;
  BtnLoadRelations := TButton.Create(Self); BtnLoadRelations.Parent := Self; BtnLoadRelations.Position.X := 240; BtnLoadRelations.Position.Y := 10; BtnLoadRelations.Text := 'Load Relations'; BtnLoadRelations.OnClick := BtnLoadRelationsClick;
  ListView1 := TListView.Create(Self); ListView1.Parent := Self; ListView1.Position.Y := 60; ListView1.Width := 760; ListView1.Height := 520;

  TAuroraConfig.SetDialect(dbSQLite);
  Conn := TFDConnection.Create(Self);
  Conn.Params.Values['DriverID'] := 'SQLite';
  Conn.Params.Database := 'aurora.db';
  Conn.Open;
  Q := TAuroraQueryFiredac.New(Conn);
  DAOUser := TAuroraDAO<TUser>.NewAurora(Q);
end;

procedure TFormMain.BtnLoadUsersClick(Sender: TObject);
var
  L: TObjectList<TUser>;
  U: TUser;
begin
  L := TObjectList<TUser>.Create(True);
  try
    DAOUser.SQL.OrderBy('id desc').&End.Find(L);
    ListView1.Items.Clear;
    for U in L do
      with ListView1.Items.Add do
        Text := U.Name + ' - ' + U.Email;
  finally
    L.Free;
  end;
end;

procedure TFormMain.BtnInsertUserClick(Sender: TObject);
var
  U: TUser;
begin
  U := TUser.Create;
  U.Name := 'User ' + FormatDateTime('hh:nn:ss', Now);
  U.Email := 'user'+IntToStr(Random(1000))+'@example.com';
  DAOUser.Insert(U);
end;

procedure TFormMain.BtnLoadRelationsClick(Sender: TObject);
var
  U: TUser;
  P: TProfile;
  Orders: TObjectList<TOrder>;
begin
  U := DAOUser.Find(1);
  if Assigned(U) then
  begin
    DAOUser.LoadOne<TProfile>(U, 'id', 'user_id', P);
    DAOUser.LoadMany<TOrder>(U, 'id', 'user_id', Orders);
    ListView1.Items.Clear;
    if Assigned(P) then with ListView1.Items.Add do Text := 'Profile: ' + P.Bio;
    if Assigned(Orders) then
      for var O in Orders do with ListView1.Items.Add do Text := 'Order: ' + FormatFloat('#,##0.00', O.Total);
    Orders.Free;
    P.Free;
  end;
end;

end.
