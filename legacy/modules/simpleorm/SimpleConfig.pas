unit SimpleConfig;

interface

type
  // Lightweight configuration holder for SimpleORM runtime options.
  // Currently only manages the default PostgreSQL schema to use.
  TSimpleConfig = class
  private
    class var FSchema: string;
  public
    // Define the schema to use. If empty or only whitespace, it defaults to 'public'.
    class procedure SetSchema(const ASchema: string); static;
    // Returns the configured schema or 'public' when none was set.
    class function Schema: string; static;
  end;

implementation

uses
  System.SysUtils;

{ TSimpleConfig }

class procedure TSimpleConfig.SetSchema(const ASchema: string);
var
  S: string;
begin
  S := Trim(ASchema);
  if S = '' then
    FSchema := 'public'
  else
    FSchema := S;
end;

class function TSimpleConfig.Schema: string;
begin
  if Trim(FSchema) = '' then
    Result := 'public'
  else
    Result := FSchema;
end;

end.