program AuroraHeadless;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  AuroraInterface in '..\..\AuroraInterface.pas',
  AuroraDAO in '..\..\AuroraDAO.pas',
  AuroraConfig in '..\..\AuroraConfig.pas',
  AuroraQueryFiredac in '..\..\AuroraQueryFiredac.pas',
  AuroraEntity in '..\..\AuroraEntity.pas',
  AuroraAttributes in '..\..\AuroraAttributes.pas',
  Entities.User in 'Entities\Entities.User.pas';

var
  Conn: TFDConnection;
  Query: iAuroraQuery;
  DAOUser: iAuroraDAO<TUser>;
  U: TUser;
  Users: TObjectList<TUser>;
  Item: TUser;
begin
  try
    // Configura dialeto para SQLite
    TAuroraConfig.SetDialect(dbSQLite);
    // Em SQLite, o prefixo de schema não é utilizado; UseSchemaPrefix é calculado a partir do Dialeto
    // TAuroraConfig.UseSchemaPrefix(False); // chamada inválida, método não recebe parâmetros
    Conn := TFDConnection.Create(nil);
    try
      Conn.DriverName := 'SQLite';
      Conn.Params.Values['Database'] := ExtractFilePath(ParamStr(0)) + 'aurora.db';
      Conn.Connected := True;
      
      // Adapter Aurora para FireDAC
      Query := TAuroraQueryFiredac.New(Conn);

      // Cria tabela users se não existir (SQLite)
      Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS users (' +
                        '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
                        '  name TEXT NOT NULL,' +
                        '  email TEXT NOT NULL' +
                        ');';
      Query.ExecSQL;

      // DAO Aurora
      DAOUser := TAuroraDAO<TUser>.NewAurora(Query);

      // Insert exemplo
      U := TUser.Create;
      try
        U.Name := 'Alice';
        U.Email := 'alice@example.com';
        DAOUser.Insert(U);
      finally
        U.Free;
      end;
      // Listar e imprimir
      Users := TObjectList<TUser>.Create;
      try
        DAOUser.SQL.OrderBy('id desc').&End.Find(Users);
        for Item in Users do
          Writeln(System.SysUtils.Format('%d %s %s', [Item.Id, Item.Name, Item.Email]));
      finally
        Users.Free;
      end;
    finally
      Conn.Free;
    end;
  except
    on E: Exception do
      Writeln('Erro: ' + E.Message);
  end;
end.