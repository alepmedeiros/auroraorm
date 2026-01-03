program AuroraAPIConsole;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  AuroraConfig,
  AuroraInterface,
  AuroraDAO,
  AuroraJSON,
  AuroraValidator,
  AuroraQueryFiredac,
  AuroraSchemaSync,
  Aurora.Migrations,
  Entities.User in '..\Sample\AuroraHeadless\Entities\Entities.User.pas',
  Entities.Order in '..\Sample\AuroraHeadless\Entities\Order.pas',
  Entities.Profile in '..\Sample\AuroraHeadless\Entities\Profile.pas';

var
  Conn: TFDConnection;
  Q: iAuroraQuery;

procedure SetupSQLite;
var Runner: TAuroraMigrationRunner;
begin
  TAuroraConfig.SetDialect(dbSQLite);
  Conn := TFDConnection.Create(nil);
  Conn.Params.Values['DriverID'] := 'SQLite';
  Conn.Params.Database := 'aurora.db';
  Conn.Open;
  Q := TAuroraQueryFiredac.New(Conn);
  Runner := TAuroraMigrationRunner.Create(Q, ExtractFilePath(ParamStr(0))+'..\Sample\AuroraHeadless\migrations\sqlite');
  Runner.ApplyPending;
end;

procedure SetupPostgres;
var Runner: TAuroraMigrationRunner;
begin
  TAuroraConfig.SetDialect(dbPostgreSQL);
  Conn := TFDConnection.Create(nil);
  Conn.Params.Values['DriverID'] := 'PG';
  Conn.Params.Values['Server'] := 'localhost';
  Conn.Params.Values['Database'] := 'postgres';
  Conn.Params.Values['User_Name'] := 'postgres';
  Conn.Params.Values['Password'] := 'postgres';
  Conn.Open;
  Q := TAuroraQueryFiredac.New(Conn);
  Runner := TAuroraMigrationRunner.Create(Q, ExtractFilePath(ParamStr(0))+'..\Sample\AuroraHeadless\migrations\postgres');
  Runner.ApplyPending;
end;

procedure HandleCommand(const Line: string);
var
  Parts: TArray<string>;
  Cmd, Arg: string;
  DAOUser: iAuroraDAO<TUser>;
  DAOOrder: iAuroraDAO<TOrder>;
  DAOProfile: iAuroraDAO<TProfile>;
  U: TUser;
  O: TOrder;
  P: TProfile;
  LOrders: TObjectList<TOrder>;
  J: string;
begin
  Parts := Line.Split([' '], 2);
  if Length(Parts)=0 then Exit;
  Cmd := Parts[0];
  Arg := ''; if Length(Parts)>1 then Arg := Parts[1];
  DAOUser := TAuroraDAO<TUser>.NewAurora(Q);
  DAOOrder := TAuroraDAO<TOrder>.NewAurora(Q);
  DAOProfile := TAuroraDAO<TProfile>.NewAurora(Q);

  if SameText(Cmd,'user.create') then
  begin
    U := TAuroraJSON.FromJSON<TUser>(Arg);
    DAOUser.Insert(U);
    Writeln(TAuroraJSON.ToJSON<TUser>(U));
  end
  else if SameText(Cmd,'user.get') then
  begin
    U := DAOUser.Find(StrToIntDef(Arg,0));
    if Assigned(U) then Writeln(TAuroraJSON.ToJSON<TUser>(U));
  end
  else if SameText(Cmd,'user.update') then
  begin
    U := TAuroraJSON.FromJSON<TUser>(Arg);
    DAOUser.Update(U);
    Writeln(TAuroraJSON.ToJSON<TUser>(U));
  end
  else if SameText(Cmd,'orders.create') then
  begin
    O := TAuroraJSON.FromJSON<TOrder>(Arg);
    DAOOrder.Insert(O);
    Writeln(TAuroraJSON.ToJSON<TOrder>(O));
  end
  else if SameText(Cmd,'orders.list') then
  begin
    LOrders := DAOOrder.FindWhere('user_id', StrToIntDef(Arg,0));
    Writeln(TAuroraJSON.ToJSONArray<TOrder>(LOrders));
    LOrders.Free;
  end
  else if SameText(Cmd,'profile.upsert') then
  begin
    P := TAuroraJSON.FromJSON<TProfile>(Arg);
    if DAOProfile.FindOneWhere('user_id', P.UserId)=nil then
      DAOProfile.Insert(P)
    else
      DAOProfile.Update(P);
    Writeln(TAuroraJSON.ToJSON<TProfile>(P));
  end
  else if SameText(Cmd,'migrate.sqlite') then
  begin
    SetupSQLite;
    Writeln('migrations applied');
  end
  else if SameText(Cmd,'help') then
  begin
    Writeln('Commands:');
    Writeln('migrate.sqlite');
    Writeln('user.create {"name":"Alice","email":"alice@example.com"}');
    Writeln('user.get 1');
    Writeln('user.update {"id":1,"name":"Alice","email":"alice@new.com"}');
    Writeln('orders.create {"user_id":1,"total":100.00}');
    Writeln('orders.list 1');
    Writeln('profile.upsert {"user_id":1,"bio":"bio text"}');
    Writeln('seed.sqlite');
    Writeln('migrate.auto');
    Writeln('migrate.postgres');
    Writeln('migrate.auto.postgres');
  end;
end;

var Line: string;
begin
  try
    SetupSQLite;
    Writeln('AuroraAPIConsole ready. Type help. Ctrl+C to exit.');
    while True do
    begin
      Write('> ');
      Readln(Line);
      if SameText(Line,'seed.sqlite') then
      begin
        var DAOUser := TAuroraDAO<TUser>.NewAurora(Q);
        var DAOOrder := TAuroraDAO<TOrder>.NewAurora(Q);
        var DAOProfile := TAuroraDAO<TProfile>.NewAurora(Q);
        var U := TUser.Create; U.Name := 'Demo'; U.Email := 'demo@example.com'; DAOUser.Insert(U);
        var P := TProfile.Create; P.UserId := 1; P.Bio := 'Demo bio'; DAOProfile.Insert(P);
        var O := TOrder.Create; O.UserId := 1; O.Total := 123.45; DAOOrder.Insert(O);
        Writeln('seed done');
      end
      else if SameText(Line,'migrate.auto') then
      begin
        TAuroraSchemaSync.Ensure<TUser>(Q);
        TAuroraSchemaSync.Ensure<TOrder>(Q);
        TAuroraSchemaSync.Ensure<TProfile>(Q);
        Writeln('auto migration done');
      end
      else if SameText(Line,'migrate.postgres') then
      begin
        SetupPostgres;
        Writeln('migrations applied (postgres)');
      end
      else if SameText(Line,'migrate.auto.postgres') then
      begin
        SetupPostgres;
        TAuroraSchemaSync.Ensure<TUser>(Q);
        TAuroraSchemaSync.Ensure<TOrder>(Q);
        TAuroraSchemaSync.Ensure<TProfile>(Q);
        Writeln('auto migration done (postgres)');
      end
      else
        HandleCommand(Line);
    end;
  except
    on E: Exception do Writeln(E.ClassName+': '+E.Message);
  end;
end.
