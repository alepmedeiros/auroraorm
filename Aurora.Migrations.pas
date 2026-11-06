unit Aurora.Migrations;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Generics.Defaults, System.IOUtils,
  Data.DB,
  AuroraInterface, AuroraConfig;

type
  EAuroraMigrationError = class(Exception);

  TAuroraMigrationRunner = class
  private
    FQuery: iAuroraQuery;
    FMigrationsPath: String;
    function EnsureMigrationsTableSQL: String;
    function InsertVersionSQL(const Version: Int64): String;
    function SelectAppliedSQL: String;
    procedure ExecStatement(const SQL: String);
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
  public
    constructor Create(const aQuery: iAuroraQuery; const aPath: String);
    procedure ApplyPending;
  end;

implementation

function ParseVersionFromFileName(const FileName: String): Int64;
var
  Base, NumStr: String;
  I: Integer;
begin
  Base := TPath.GetFileNameWithoutExtension(FileName);
  NumStr := '';
  for I := 1 to Length(Base) do
  begin
    if CharInSet(Base[I], ['0'..'9']) then
      NumStr := NumStr + Base[I]
    else
      Break;
  end;
  if NumStr = '' then
    Result := 0
  else
    Result := StrToInt64(NumStr);
end;

{ TAuroraMigrationRunner }

constructor TAuroraMigrationRunner.Create(const aQuery: iAuroraQuery; const aPath: String);
begin
  FQuery := aQuery;
  FMigrationsPath := aPath;
end;

function TAuroraMigrationRunner.EnsureMigrationsTableSQL: String;
begin
  case TAuroraConfig.Dialect of
    dbPostgreSQL:
      Result := 'CREATE TABLE IF NOT EXISTS schema_migrations (' +
                '  version BIGINT PRIMARY KEY,' +
                '  applied_at TIMESTAMP NOT NULL DEFAULT now()' +
                ');';
    dbSQLite:
      Result := 'CREATE TABLE IF NOT EXISTS schema_migrations (' +
                '  version INTEGER PRIMARY KEY,' +
                '  applied_at DATETIME NOT NULL DEFAULT (datetime(''now''))' +
                ');';
  else
      Result := 'CREATE TABLE IF NOT EXISTS schema_migrations (' +
                '  version BIGINT PRIMARY KEY,' +
                '  applied_at TIMESTAMP NOT NULL' +
                ');';
  end;
end;

function TAuroraMigrationRunner.InsertVersionSQL(const Version: Int64): String;
begin
  case TAuroraConfig.Dialect of
    dbPostgreSQL:
      Result := 'INSERT INTO schema_migrations(version, applied_at) VALUES (:v, now())';
    dbSQLite:
      Result := 'INSERT INTO schema_migrations(version, applied_at) VALUES (:v, datetime(''now''))';
  else
      Result := 'INSERT INTO schema_migrations(version, applied_at) VALUES (:v, CURRENT_TIMESTAMP)';
  end;
end;

function TAuroraMigrationRunner.SelectAppliedSQL: String;
begin
  Result := 'SELECT version FROM schema_migrations ORDER BY version';
end;

procedure TAuroraMigrationRunner.ExecStatement(const SQL: String);
begin
  FQuery.SQL.Text := SQL;
  FQuery.ExecSQL;
end;

procedure TAuroraMigrationRunner.BeginTransaction;
begin
  case TAuroraConfig.Dialect of
    dbPostgreSQL, dbSQLite:
      ExecStatement('BEGIN');
  else
      ExecStatement('BEGIN');
  end;
end;

procedure TAuroraMigrationRunner.CommitTransaction;
begin
  ExecStatement('COMMIT');
end;

procedure TAuroraMigrationRunner.RollbackTransaction;
begin
  ExecStatement('ROLLBACK');
end;

procedure TAuroraMigrationRunner.ApplyPending;
var
  Files: TArray<String>;
  FileName: String;
  VersionsApplied: TList<Int64>;
  Pending: TList<String>;
  // removed legacy DS interface usage
  Version: Int64;
  SQLText, Statement: String;
  Lines: TStringList;
  I: Integer;
begin
  // Ensure table exists
  ExecStatement(EnsureMigrationsTableSQL);

  // Load applied versions
  VersionsApplied := TList<Int64>.Create;
  try
    FQuery.SQL.Text := SelectAppliedSQL;
    FQuery.Open;
    while not FQuery.DataSet.Eof do
    begin
      VersionsApplied.Add(FQuery.DataSet.FieldByName('version').AsLargeInt);
      FQuery.DataSet.Next;
    end;

    // Collect migration files
    Files := TDirectory.GetFiles(FMigrationsPath, '*.sql');
    Pending := TList<String>.Create;
    try
      for FileName in Files do
      begin
        Version := ParseVersionFromFileName(FileName);
        if (Version > 0) and (VersionsApplied.IndexOf(Version) = -1) then
          Pending.Add(FileName);
      end;

      // Sort by version
      Pending.Sort(TComparer<String>.Construct(
        function(const L, R: String): Integer
        var VL, VR: Int64;
        begin
          VL := ParseVersionFromFileName(L);
          VR := ParseVersionFromFileName(R);
          Result := VL - VR;
        end));

      // Apply each migration inside a transaction
      for FileName in Pending do
      begin
        Version := ParseVersionFromFileName(FileName);
        Lines := TStringList.Create;
        try
          Lines.Text := TFile.ReadAllText(FileName);
          BeginTransaction;
          try
            // Naive split by ';' – assumes one statement per line/block
            SQLText := Lines.Text;
            Statement := '';
            for I := 1 to Length(SQLText) do
            begin
              if SQLText[I] = ';' then
              begin
                if Trim(Statement) <> '' then
                  ExecStatement(Statement);
                Statement := '';
              end
              else
                Statement := Statement + SQLText[I];
            end;
            if Trim(Statement) <> '' then
              ExecStatement(Statement);

            // Record version
            FQuery.SQL.Text := InsertVersionSQL(Version);
            FQuery.Params.Clear;
            if FQuery.Params.FindParam('v') = nil then
              FQuery.Params.CreateParam(ftLargeint, 'v', ptInput);
            FQuery.Params.ParamByName('v').AsLargeInt := Version;
            FQuery.ExecSQL;
            CommitTransaction;
          except
            on E: Exception do
            begin
              RollbackTransaction;
              raise EAuroraMigrationError.CreateFmt('Migration failed for %s: %s', [FileName, E.Message]);
            end;
          end;
        finally
          Lines.Free;
        end;
      end;
    finally
      Pending.Free;
    end;
  finally
    VersionsApplied.Free;
  end;
end;

end.
