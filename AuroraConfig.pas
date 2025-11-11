unit AuroraConfig;

interface

uses
  System.SysUtils;

type
  TDatabaseDialect = (
    dbFirebird,
    dbPostgreSQL,
    dbSQLite,
    dbSQLServer,
    dbMySQL
  );

  TAuroraConfig = class
  private
    class var FSchema: string;
    class var FDialect: TDatabaseDialect;
  public
    class procedure SetSchema(const ASchema: string); static;
    class function Schema: string; static;
    class procedure SetDialect(const ADialect: TDatabaseDialect); static;
    class function Dialect: TDatabaseDialect; static;
    class function UseSchemaPrefix: Boolean; static;
  end;

implementation

{ TAuroraConfig }

class procedure TAuroraConfig.SetSchema(const ASchema: string);
var
  S: string;
begin
  S := Trim(ASchema);
  if S = '' then
    FSchema := ''
  else
    FSchema := S;
end;

class function TAuroraConfig.Schema: string;
var
  S: string;
begin
  S := Trim(FSchema);
  if S = '' then
    Result := 'public'
  else
    Result := S;
end;

class procedure TAuroraConfig.SetDialect(const ADialect: TDatabaseDialect);
begin
  FDialect := ADialect;
end;

class function TAuroraConfig.Dialect: TDatabaseDialect;
begin
  if FDialect = TDatabaseDialect(0) then
    Result := dbFirebird
  else
    Result := FDialect;
end;

class function TAuroraConfig.UseSchemaPrefix: Boolean;
begin
  Result := Dialect = dbPostgreSQL;
end;

end.