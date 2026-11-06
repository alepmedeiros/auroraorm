unit AuroraSQL;

interface

uses
  System.SysUtils,
  System.Rtti,
  AuroraInterface,
  AuroraAttributes,
  AuroraMetadata,
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
    FMeta: TAuroraEntityMeta;
    function QualifiedTableName: string;
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

{ TAuroraSQL<T> }

constructor TAuroraSQL<T>.Create;
begin
  inherited Create;
  FFields := '';
  FWhere := '';
  FOrderBy := '';
  FGroupBy := '';
  FJoin := '';
  FMeta := TAuroraMetadataRegistry.GetOrBuild<T>;
end;

class function TAuroraSQL<T>.New: iAuroraSQL<T>;
begin
  Result := Self.Create;
end;

function TAuroraSQL<T>.QualifiedTableName: string;
begin
  if TAuroraConfig.UseSchemaPrefix then
    Result := System.SysUtils.Format('%s.%s', [TAuroraConfig.Schema, FMeta.TableName])
  else
    Result := FMeta.TableName;
end;

function TAuroraSQL<T>.PKFieldName: string;
begin
  if FMeta.PrimaryPK <> nil then
    Result := FMeta.PrimaryPK.FieldName
  else
    Result := 'id';
end;

function TAuroraSQL<T>.DefaultFields: string;
var
  F: TAuroraFieldMeta;
  S: string;
begin
  S := '';
  for F in FMeta.Fields do
    if not F.IsIgnore then
      S := S + F.FieldName + ', ';
  if S <> '' then
    S := Copy(S, 1, Length(S) - 2)
  else
    S := '*';
  Result := S;
end;

function TAuroraSQL<T>.UpdateSet: string;
var
  F: TAuroraFieldMeta;
  S: string;
begin
  S := '';
  for F in FMeta.UpdatableFields do
    S := S + System.SysUtils.Format('%s = :%s, ', [F.FieldName, F.FieldName]);
  if S <> '' then
    S := Copy(S, 1, Length(S) - 2);
  Result := S;
end;

function TAuroraSQL<T>.InsertFields: string;
var
  F: TAuroraFieldMeta;
  S: string;
begin
  S := '';
  for F in FMeta.InsertableFields do
    S := S + F.FieldName + ', ';
  if S <> '' then
    S := Copy(S, 1, Length(S) - 2);
  Result := S;
end;

function TAuroraSQL<T>.InsertParams: string;
var
  F: TAuroraFieldMeta;
  S: string;
begin
  S := '';
  for F in FMeta.InsertableFields do
    S := S + ':' + F.FieldName + ', ';
  if S <> '' then
    S := Copy(S, 1, Length(S) - 2);
  Result := S;
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
begin
  Result := Self;
  aSQL := System.SysUtils.Format('INSERT INTO %s (%s) VALUES (%s)', [QualifiedTableName, InsertFields, InsertParams]);
end;

function TAuroraSQL<T>.Update(var aSQL: String): iAuroraSQL<T>;
var
  SetExpr, WhereExpr: string;
  F: TAuroraFieldMeta;
begin
  Result := Self;
  SetExpr := UpdateSet;
  if FWhere <> '' then
    WhereExpr := FWhere
  else
  begin
    WhereExpr := '';
    for F in FMeta.PKFields do
      WhereExpr := WhereExpr + System.SysUtils.Format('%s = :%s AND ', [F.FieldName, F.FieldName]);
    if WhereExpr <> '' then
      WhereExpr := Copy(WhereExpr, 1, Length(WhereExpr) - 5);
  end;
  WhereExpr := Trim(WhereExpr);
  if WhereExpr <> '' then
    aSQL := System.SysUtils.Format('UPDATE %s SET %s WHERE %s', [QualifiedTableName, SetExpr, WhereExpr])
  else
    aSQL := System.SysUtils.Format('UPDATE %s SET %s', [QualifiedTableName, SetExpr]);
end;

function TAuroraSQL<T>.Delete(var aSQL: String): iAuroraSQL<T>;
var
  WhereExpr: string;
  F: TAuroraFieldMeta;
begin
  Result := Self;
  if FWhere <> '' then
    WhereExpr := FWhere
  else
  begin
    WhereExpr := '';
    for F in FMeta.PKFields do
      WhereExpr := WhereExpr + System.SysUtils.Format('%s = :%s AND ', [F.FieldName, F.FieldName]);
    if WhereExpr <> '' then
      WhereExpr := Copy(WhereExpr, 1, Length(WhereExpr) - 5);
  end;
  WhereExpr := Trim(WhereExpr);
  if WhereExpr <> '' then
    aSQL := System.SysUtils.Format('DELETE FROM %s WHERE %s', [QualifiedTableName, WhereExpr])
  else
    aSQL := System.SysUtils.Format('DELETE FROM %s', [QualifiedTableName]);
end;

function TAuroraSQL<T>.Select(var aSQL: String): iAuroraSQL<T>;
var
  Flds: string;
begin
  Result := Self;
  if FFields <> '' then Flds := FFields else Flds := DefaultFields;
  aSQL := System.SysUtils.Format('SELECT %s FROM %s', [Flds, QualifiedTableName]);
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
  aSQL := System.SysUtils.Format('SELECT %s FROM %s WHERE %s = :%s', [DefaultFields, QualifiedTableName, PK, PK]);
end;

function TAuroraSQL<T>.LastID(var aSQL: String): iAuroraSQL<T>;
var
  PK: string;
begin
  Result := Self;
  PK := PKFieldName;
  aSQL := System.SysUtils.Format('SELECT MAX(%s) AS last_id FROM %s', [PK, QualifiedTableName]);
end;

function TAuroraSQL<T>.LastRecord(var aSQL: String): iAuroraSQL<T>;
var
  PK, Tbl: string;
begin
  Result := Self;
  PK := PKFieldName;
  Tbl := QualifiedTableName;
  case TAuroraConfig.Dialect of
    dbSQLite, dbPostgreSQL, dbMySQL:
      aSQL := System.SysUtils.Format('SELECT %s FROM %s ORDER BY %s DESC LIMIT 1', [DefaultFields, Tbl, PK]);
    dbSQLServer:
      aSQL := System.SysUtils.Format('SELECT TOP 1 %s FROM %s ORDER BY %s DESC', [DefaultFields, Tbl, PK]);
  else
      aSQL := System.SysUtils.Format('SELECT FIRST 1 %s FROM %s ORDER BY %s DESC', [DefaultFields, Tbl, PK]);
  end;
end;

end.
