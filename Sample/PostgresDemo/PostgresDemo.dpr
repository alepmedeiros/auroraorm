program PostgresDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  AuroraConfig,
  AuroraInterface,
  AuroraQueryFiredac,
  AuroraDAO,
  Entities.User in '..\Sample\AuroraHeadless\Entities\Entities.User.pas';

var
  Conn: TFDConnection;
  Q: iAuroraQuery;
  DAO: iAuroraDAO<TUser>;
  U: TUser;
begin
  Conn := TFDConnection.Create(nil);
  Conn.Params.Values['DriverID'] := 'PG';
  Conn.Params.Values['Server'] := 'localhost';
  Conn.Params.Values['Database'] := 'postgres';
  Conn.Params.Values['User_Name'] := 'postgres';
  Conn.Params.Values['Password'] := 'postgres';
  Conn.Open;

  TAuroraConfig.SetDialect(dbPostgreSQL);
  TAuroraConfig.SetSchema('public');
  Q := TAuroraQueryFiredac.New(Conn);

  U := TUser.Create; U.Name := 'Alice'; U.Email := 'alice@example.com';
  DAO := TAuroraDAO<TUser>.NewAurora(Q);
  DAO.Insert(U);
  DAO.LastRecord;
  Writeln('OK Postgres Demo');
end.
