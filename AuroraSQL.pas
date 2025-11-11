unit AuroraSQL;

interface

uses
  System.SysUtils,
  System.Rtti,
  AuroraInterface,
  AuroraAttributes,
  AuroraConfig;

type
  // Implementação nativa de builder SQL para Aurora
  TAuroraSQL<T: class, constructor> = class(TInterfacedObject, iAuroraSQL<T>)
  private
    FFields: string;
    FWhere: string;
    FOrderBy: string;
    FGroupBy: string;
    FJoin: string;
    function QualifiedTableName(const ATable: string): string;
    function TableName: string;
    function PKFieldName: string;
    function DefaultFields: string;
    function UpdateSet: string;
    function InsertFields: string;
    function InsertParams: string;
  public
    constructor Create;
    class function New: iAuroraSQL<T>;

    // setters de partes do SQL
    function Fields(aSQL: String): iAuroraSQL<T>;
    function Where(aSQL: String): iAuroraSQL<T>;
    function OrderBy(aSQL: String): iAuroraSQL<T>;
    function GroupBy(aSQL: String): iAuroraSQL<T>;
    function Join(aSQL: String): iAuroraSQL<T>;

    // builders
    function Insert(var aSQL: String): iAuroraSQL<T>;
    function Update(var aSQL: String): iAuroraSQL<T>;
    function Delete(var aSQL: String): iAuroraSQL<T>;
    function Select(var aSQL: String): iAuroraSQL<T>;
    function SelectId(var aSQL: String): iAuroraSQL<T>;
    function LastID(var aSQL: String): iAuroraSQL<T>;
    function LastRecord(var aSQL: String): iAuroraSQL<T>;
  end;

implementation

uses
  AuroraRTTI;

{ TAuroraSQL<T> }

constructor TAuroraSQL<T>.Create;
begin
  inherited Create;
  FFields := '';
  FWhere := '';
  FOrderBy := '';
  FGroupBy := '';
  FJoin := '';
end;

class function TAuroraSQL<T>.New: iAuroraSQL<T>;
begin
  Result := Self.Create;
end;

function TAuroraSQL<T>.QualifiedTableName(const ATable: string): string;
begin
  if TAuroraConfig.UseSchemaPrefix then
    Result := Format('%s.%s', [TAuroraConfig.Schema, ATable])
  else
    Result := ATable;
end;

function TAuroraSQL<T>.TableName: string;
var
  Tbl: string;
begin
  Tbl := '';
  TAuroraRTTI<T>.New(nil).TableName(Tbl);
  Result := QualifiedTableName(Tbl);
end;

function TAuroraSQL<T>.PKFieldName: string;
var
  PK: string;
begin
  PK := '';
  TAuroraRTTI<T>.New(nil).PrimaryKey(PK);
  if PK = '' then
    PK := 'id';
  Result := PK;
end;

function TAuroraSQL<T>.DefaultFields: string;
var
  S: string;
begin
  S := '';
  TAuroraRTTI<T>.New(nil).Fields(S);
  S := Trim(S);
  if S = '' then
    S := '*';
  Result := S;
end;

function TAuroraSQL<T>.UpdateSet: string;
var
  S: string;
begin
  S := '';
  TAuroraRTTI<T>.New(nil).Update(S);
  Result := Trim(S);
end;

function TAuroraSQL<T>.InsertFields: string;
var
  S: string;
begin
  S := '';
  TAuroraRTTI<T>.New(nil).FieldsInsert(S);
  Result := Trim(S);
end;

function TAuroraSQL<T>.InsertParams: string;
var
  S: string;
begin
  S := '';
  TAuroraRTTI<T>.New(nil).Param(S);
  Result := Trim(S);
end;

function TAuroraSQL<T>.Fields(aSQL: String): iAuroraSQL<T>;
begin
  FFields := Trim(aSQL);
  Result := Self;
end;

function TAuroraSQL<T>.Where(aSQL: String): iAuroraSQL<T>;
begin
  FWhere := Trim(aSQL);
  Result := Self;
end;

function TAuroraSQL<T>.OrderBy(aSQL: String): iAuroraSQL<T>;
begin
  FOrderBy := Trim(aSQL);
  Result := Self;
end;

function TAuroraSQL<T>.GroupBy(aSQL: String): iAuroraSQL<T>;
begin
  FGroupBy := Trim(aSQL);
  Result := Self;
end;

function TAuroraSQL<T>.Join(aSQL: String): iAuroraSQL<T>;
begin
  FJoin := Trim(aSQL);
  Result := Self;
end;

function TAuroraSQL<T>.Insert(var aSQL: String): iAuroraSQL<T>;
var
  Flds, Prms: string;
begin
  Result := Self;
  Flds := InsertFields;
  Prms := InsertParams;
  aSQL := Format('INSERT INTO %s (%s) VALUES (%s)', [TableName, Flds, Prms]);
end;

function TAuroraSQL<T>.Update(var aSQL: String): iAuroraSQL<T>;
var
  SetExpr, WhereExpr: string;
begin
  Result := Self;
  SetExpr := UpdateSet;
  if FWhere <> '' then
    WhereExpr := FWhere
  else
    TAuroraRTTI<T>.New(nil).Where(WhereExpr);
  WhereExpr := Trim(WhereExpr);
  if WhereExpr <> '' then
    aSQL := Format('UPDATE %s SET %s WHERE %s', [TableName, SetExpr, WhereExpr])
  else
    aSQL := Format('UPDATE %s SET %s', [TableName, SetExpr]);
end;

function TAuroraSQL<T>.Delete(var aSQL: String): iAuroraSQL<T>;
var
  WhereExpr: string;
begin
  Result := Self;
  if FWhere <> '' then
    WhereExpr := FWhere
  else
    TAuroraRTTI<T>.New(nil).Where(WhereExpr);
  WhereExpr := Trim(WhereExpr);
  if WhereExpr <> '' then
    aSQL := Format('DELETE FROM %s WHERE %s', [TableName, WhereExpr])
  else
    aSQL := Format('DELETE FROM %s', [TableName]);
end;

function TAuroraSQL<T>.Select(var aSQL: String): iAuroraSQL<T>;
var
  Flds: string;
  Add: string;
begin
  Result := Self;
  if FFields <> '' then Flds := FFields else Flds := DefaultFields;
  aSQL := Format('SELECT %s FROM %s', [Flds, TableName]);
  if FJoin <> '' then aSQL := aSQL + ' ' + FJoin;
  if FWhere <> '' then aSQL := aSQL + ' WHERE ' + FWhere;
  if FGroupBy <> '' then aSQL := aSQL + ' GROUP BY ' + FGroupBy;
  if FOrderBy <> '' then aSQL := aSQL + ' ORDER BY ' + FOrderBy;
end;

function TAuroraSQL<T>.SelectId(var aSQL: String): iAuroraSQL<T>;
var
  PK: string;
begin
  Result := Self;
  PK := PKFieldName;
  aSQL := Format('SELECT %s FROM %s WHERE %s = :%s', [DefaultFields, TableName, PK, PK]);
end;

function TAuroraSQL<T>.LastID(var aSQL: String): iAuroraSQL<T>;
var
  PK: string;
begin
  Result := Self;
  PK := PKFieldName;
  aSQL := Format('SELECT MAX(%s) AS last_id FROM %s', [PK, TableName]);
end;

function TAuroraSQL<T>.LastRecord(var aSQL: String): iAuroraSQL<T>;
var
  PK, Tbl: string;
begin
  Result := Self;
  PK := PKFieldName;
  Tbl := TableName;
  case TAuroraConfig.Dialect of
    dbSQLite, dbPostgreSQL, dbMySQL:
      aSQL := Format('SELECT %s FROM %s ORDER BY %s DESC LIMIT 1', [DefaultFields, Tbl, PK]);
    dbSQLServer:
      aSQL := Format('SELECT TOP 1 %s FROM %s ORDER BY %s DESC', [DefaultFields, Tbl, PK]);
  else
      aSQL := Format('SELECT FIRST 1 %s FROM %s ORDER BY %s DESC', [DefaultFields, Tbl, PK]);
  end;
end;

end.