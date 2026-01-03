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
  Winapi.Windows,
  AuroraJSON in '..\..\AuroraJSON.pas',
  AuroraValidator in '..\..\AuroraValidator.pas',
  AuroraInterface in '..\..\AuroraInterface.pas',
  AuroraDAO in '..\..\AuroraDAO.pas',
  AuroraConfig in '..\..\AuroraConfig.pas',
  AuroraQueryFiredac in '..\..\AuroraQueryFiredac.pas',
  AuroraEntity in '..\..\AuroraEntity.pas',
  AuroraAttributes in '..\..\AuroraAttributes.pas',
  Entities.User in 'Entities\Entities.User.pas',
  AuroraRTTI in '..\..\AuroraRTTI.pas';

var
  Conn: TFDConnection;
  Query: iAuroraQuery;
  DAOUser: iAuroraDAO<TUser>;
  U: TUser;
  Users: TObjectList<TUser>;
  Item: TUser;
  Errs: TList<TAuroraValidationError>;
  InvalidJSON, ValidJSON, OutJSON: string;

procedure WriteColor(const S: string; Color: Word);
var
  h: THandle;
  csbi: TConsoleScreenBufferInfo;
begin
  h := GetStdHandle(STD_OUTPUT_HANDLE);
  GetConsoleScreenBufferInfo(h, csbi);
  SetConsoleTextAttribute(h, Color);
  Writeln(S);
  SetConsoleTextAttribute(h, csbi.wAttributes);
end;
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

      // Fluxo linear: JSON -> validação -> JSON -> (opcional) insert
      WriteColor('== Serialização e Validação JSON ==', FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_INTENSITY);

      // Exemplo inválido
      InvalidJSON := '{"id": null, "name": "", "email": "alice#example"}';
      U := TAuroraJSON.FromJSON<TUser>(InvalidJSON);
      try
        Errs := TAuroraValidator.Validate<TUser>(U);
        try
          if Errs.Count > 0 then
          begin
            WriteColor('Entrada inválida:', FOREGROUND_RED or FOREGROUND_INTENSITY);
            for var E in Errs do
              WriteColor(System.SysUtils.Format('- %s: %s', [E.Field, E.Message]), FOREGROUND_RED);
          end;
        finally
          Errs.Free;
        end;
      finally
        U.Free;
      end;

      // Exemplo válido
      ValidJSON := '{"name": "Alice", "email": "alice@example.com"}';
      U := TAuroraJSON.FromJSON<TUser>(ValidJSON);
      try
        Errs := TAuroraValidator.Validate<TUser>(U);
        try
          if Errs.Count = 0 then
          begin
            WriteColor('Entrada válida!', FOREGROUND_GREEN or FOREGROUND_INTENSITY);
            OutJSON := TAuroraJSON.ToJSON<TUser>(U);
            WriteColor('JSON gerado: ' + OutJSON, FOREGROUND_GREEN);
            // Opcional: persistir após validar
            DAOUser.Insert(U);
          end
          else
          begin
            WriteColor('Entrada válida esperada, mas houve erros:', FOREGROUND_RED or FOREGROUND_INTENSITY);
            for var E in Errs do
              WriteColor(System.SysUtils.Format('- %s: %s', [E.Field, E.Message]), FOREGROUND_RED);
          end;
        finally
          Errs.Free;
        end;
      finally
        U.Free;
      end;
      // Listar e imprimir
      Users := TObjectList<TUser>.Create(True);
      try
        DAOUser.SQL.OrderBy('id desc').&End.Find(Users);
        for Item in Users do
          WriteColor(System.SysUtils.Format('%d %s %s', [Item.Id, Item.Name, Item.Email]),
                     FOREGROUND_BLUE or FOREGROUND_GREEN or FOREGROUND_INTENSITY);
      finally
        Users.Free;
      end;
    finally
      Conn.Free;
    end;
    Readln;
  except
    on E: Exception do
      Writeln('Erro: ' + E.Message);
  end;
end.