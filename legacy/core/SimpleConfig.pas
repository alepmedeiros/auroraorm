unit SimpleConfig;

interface

type
  // Supported database dialects for SQL generation and features.
  TDatabaseDialect = (
    dbFirebird,
    dbPostgreSQL,
    dbSQLite,
    dbSQLServer,
    dbMySQL
  );

  // Lightweight configuration holder for SimpleORM runtime options.
  // Manages default schema and dialect for SQL generation.
  TSimpleConfig = class
  private
    class var FSchema: string; // runtime override
    class var FDialect: TDatabaseDialect; // runtime override (defaults to Firebird for backward compatibility)
  public
    // Define the schema to use at runtime. If empty or only whitespace, it defaults to 'public'.
    class procedure SetSchema(const ASchema: string); static;
    // Returns the configured schema. Precedence:
    // 1) Runtime override via SetSchema
    // 2) Compile-time constant from SimpleConfig.inc (SIMPLEORM_COMPILETIME_SCHEMA)
    // 3) 'public'
    class function Schema: string; static;
    // Dialect controls SQL nuances (LIMIT/TOP/FIRST, RETURNING support, identifier quoting, etc.)
    class procedure SetDialect(const ADialect: TDatabaseDialect); static;
    class function Dialect: TDatabaseDialect; static;
    // Whether to use schema prefix (schema.table) when generating SQL
    class function UseSchemaPrefix: Boolean; static;
    // Returns whether FireDAC monitor is enabled at compile-time
    class function MonitorEnabled: Boolean; static;
    // Timeout getters (compile-time, in seconds)
    class function StatementTimeoutSecs: Integer; static;
    class function LockTimeoutSecs: Integer; static;
  end;

implementation

uses
  System.SysUtils;

{$I SimpleConfig.inc}

{ TSimpleConfig }

class procedure TSimpleConfig.SetSchema(const ASchema: string);
var
  S: string;
begin
  S := Trim(ASchema);
  if S = '' then
    FSchema := '' // clear runtime override to allow compile-time to apply
  else
    FSchema := S;
end;

class function TSimpleConfig.Schema: string;
var
  S: string;
begin
  S := Trim(FSchema);
  if S = '' then
  begin
    {$IF Declared(SIMPLEORM_COMPILETIME_SCHEMA)}
    S := Trim(string(SIMPLEORM_COMPILETIME_SCHEMA));
    {$IFEND}
  end;

  if S = '' then
    Result := 'public'
  else
    Result := S;
end;

class procedure TSimpleConfig.SetDialect(const ADialect: TDatabaseDialect);
begin
  FDialect := ADialect;
end;

class function TSimpleConfig.Dialect: TDatabaseDialect;
begin
  // default dialect for backward compatibility with existing samples (Firebird)
  if FDialect = TDatabaseDialect(0) then
    Result := dbFirebird
  else
    Result := FDialect;
end;

class function TSimpleConfig.UseSchemaPrefix: Boolean;
begin
  // PostgreSQL commonly uses schema qualifiers; SQLite typically does not.
  Result := Dialect = dbPostgreSQL;
end;

class function TSimpleConfig.MonitorEnabled: Boolean;
begin
  {$IF Declared(SIMPLEORM_ENABLE_MONITOR)}
  Result := SIMPLEORM_ENABLE_MONITOR;
  {$ELSE}
  Result := False;
  {$IFEND}
end;

class function TSimpleConfig.StatementTimeoutSecs: Integer;
begin
  {$IF Declared(SIMPLEORM_STATEMENT_TIMEOUT_SECS)}
  Result := SIMPLEORM_STATEMENT_TIMEOUT_SECS;
  {$ELSE}
  Result := 5; // default
  {$IFEND}
end;

class function TSimpleConfig.LockTimeoutSecs: Integer;
begin
  {$IF Declared(SIMPLEORM_LOCK_TIMEOUT_SECS)}
  Result := SIMPLEORM_LOCK_TIMEOUT_SECS;
  {$ELSE}
  Result := 3; // default
  {$IFEND}
end;

end.