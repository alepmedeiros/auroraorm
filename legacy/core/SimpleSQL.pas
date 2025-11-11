unit SimpleSQL;
interface
uses
  SimpleInterface;
Type
  TSimpleSQL<T : class, constructor> = class(TInterfacedObject, iSimpleSQL<T>)
    private
      FInstance : T;
      FFields : String;
      FWhere : String;
      FOrderBy : String;
      FGroupBy : String;
      FJoin : String;
      function QualifiedTableName(const aClassName: String): String;
    public
      constructor Create(aInstance : T);
      destructor Destroy; override;
      class function New(aInstance : T) : iSimpleSQL<T>;
      function Insert (var aSQL : String) : iSimpleSQL<T>;
      function Update (var aSQL : String) : iSimpleSQL<T>;
      function Delete (var aSQL : String) : iSimpleSQL<T>;
      function Select (var aSQL : String) : iSimpleSQL<T>;
      function SelectId(var aSQL: String): iSimpleSQL<T>;
      function Fields (aSQL : String) : iSimpleSQL<T>;
      function Where (aSQL : String) : iSimpleSQL<T>;
      function OrderBy (aSQL : String) : iSimpleSQL<T>;
      function GroupBy (aSQL : String) : iSimpleSQL<T>;
      function Join (aSQL : String) : iSimpleSQL<T>;
      function LastID (var aSQL : String) : iSimpleSQL<T>;
      function LastRecord (var aSQL : String) : iSimpleSQL<T>;
  end;
implementation

uses
  SimpleRTTI, System.Generics.Collections, System.SysUtils, SimpleConfig;
{ TSimpleSQL<T> }

constructor TSimpleSQL<T>.Create(aInstance : T);
begin
  FInstance := aInstance;
end;

function TSimpleSQL<T>.Delete(var aSQL: String): iSimpleSQL<T>;
var
  aClassName, aWhere, TableFull : String;
begin
  Result := Self;
  TSimpleRTTI<T>.New(FInstance)
    .TableName(aClassName)
    .Where(aWhere);
  TableFull := QualifiedTableName(aClassName);
  aSQL := aSQL + 'DELETE FROM ' + TableFull;
  aSQL := aSQL + ' WHERE ' + aWhere;
end;

destructor TSimpleSQL<T>.Destroy;
begin
  inherited;
end;

function TSimpleSQL<T>.Fields(aSQL: String): iSimpleSQL<T>;
begin
  Result := Self;
  if Trim(aSQL) <> '' then
    FFields := aSQL;
end;

function TSimpleSQL<T>.GroupBy(aSQL: String): iSimpleSQL<T>;
begin
  Result := Self;
  if Trim(aSQL) <> '' then
    FGroupBy := aSQL;
end;

function TSimpleSQL<T>.Insert(var aSQL: String): iSimpleSQL<T>;
var
  aClassName, aFields, aParam, TableFull : String;
begin
  Result := Self;
    TSimpleRTTI<T>.New(FInstance)
      .TableName(aClassName)
      .FieldsInsert(aFields)
      .Param(aParam);
    TableFull := QualifiedTableName(aClassName);
    aSQL := aSQL + 'INSERT INTO ' + TableFull;
    aSQL := aSQL + ' (' + aFields + ') ';
    aSQL := aSQL + ' VALUES (' + aParam + ');';
end;

function TSimpleSQL<T>.Join(aSQL: String): iSimpleSQL<T>;
begin
  Result := Self;
  FJoin := aSQL;
end;

function TSimpleSQL<T>.LastID(var aSQL: String): iSimpleSQL<T>;
var
  aClassName, aPK, aFields, TableFull : String;
begin
  Result := Self;
  TSimpleRTTI<T>.New(FInstance)
    .TableName(aClassName)
    .PrimaryKey(aPK);
  TableFull := QualifiedTableName(aClassName);
  case TSimpleConfig.Dialect of
    dbPostgreSQL, dbSQLite:
      begin
        aSQL := aSQL + 'select ' + aPK;
        aSQL := aSQL + ' from ' + TableFull;
        aSQL := aSQL + ' order by ' + aPK + ' desc limit 1';
      end;
    dbFirebird:
      begin
        aSQL := aSQL + 'select first(1) ' + aPK;
        aSQL := aSQL + ' from ' + TableFull;
        aSQL := aSQL + ' order by ' + aPK + ' desc';
      end;
  else
      begin
        aSQL := aSQL + 'select ' + aPK;
        aSQL := aSQL + ' from ' + TableFull;
        aSQL := aSQL + ' order by ' + aPK + ' desc';
      end;
  end;
end;

function TSimpleSQL<T>.LastRecord(var aSQL: String): iSimpleSQL<T>;
var
  aClassName, aPK, aFields, TableFull : String;
begin
  Result := Self;
  TSimpleRTTI<T>.New(FInstance)
    .TableName(aClassName)
    .Fields(aFields)
    .PrimaryKey(aPK);
  TableFull := QualifiedTableName(aClassName);
  case TSimpleConfig.Dialect of
    dbPostgreSQL, dbSQLite:
      begin
        aSQL := aSQL + 'select ' + aFields;
        aSQL := aSQL + ' from ' + TableFull;
        aSQL := aSQL + ' order by ' + aPK + ' desc limit 1';
      end;
    dbFirebird:
      begin
        aSQL := aSQL + 'select first(1) ' + aFields;
        aSQL := aSQL + ' from ' + TableFull;
        aSQL := aSQL + ' order by ' + aPK + ' desc';
      end;
  else
      begin
        aSQL := aSQL + 'select ' + aFields;
        aSQL := aSQL + ' from ' + TableFull;
        aSQL := aSQL + ' order by ' + aPK + ' desc';
      end;
  end;
end;

class function TSimpleSQL<T>.New(aInstance : T): iSimpleSQL<T>;
begin
  Result := Self.Create(aInstance);
end;

function TSimpleSQL<T>.OrderBy(aSQL: String): iSimpleSQL<T>;
begin
  Result := Self;
  FOrderBy := aSQL;
end;

function TSimpleSQL<T>.Select (var aSQL : String) : iSimpleSQL<T>;
var
  aFields, aClassName, TableFull : String;
begin
  Result := Self;
  TSimpleRTTI<T>.New(nil)
    .Fields(aFields)
    .TableName(aClassName);
  TableFull := QualifiedTableName(aClassName);
  if Trim(FFields) <> '' then
    aSQL := aSQL + ' SELECT ' + FFields
  else
    aSQL := aSQL + ' SELECT ' + aFields;
  aSQL := aSQL + ' FROM ' + TableFull;
  if Trim(FJoin) <> '' then
    aSQL := aSQL + ' ' + FJoin + ' ';
  if Trim(FWhere) <> '' then
    aSQL := aSQL + ' WHERE ' + FWhere;
  if Trim(FGroupBy) <> '' then
    aSQL := aSQL + ' GROUP BY ' + FGroupBy;  
  if Trim(FOrderBy) <> '' then
    aSQL := aSQL + ' ORDER BY ' + FOrderBy;
end;

function TSimpleSQL<T>.SelectId(var aSQL: String): iSimpleSQL<T>;
var
  aFields, aClassName, aWhere, TableFull : String;
begin
  Result := Self;
  TSimpleRTTI<T>.New(FInstance)
    .Fields(aFields)
    .TableName(aClassName)
    .Where(aWhere);
  if Trim(FWhere) <> '' then
    aSQL := aSQL + ' WHERE ' + FWhere;
  TableFull := QualifiedTableName(aClassName);
  aSQL := aSQL + ' SELECT ' + aFields;
  aSQL := aSQL + ' FROM ' + TableFull;
  aSQL := aSQL + ' WHERE ' + aWhere;
end;

function TSimpleSQL<T>.Update(var aSQL: String): iSimpleSQL<T>;
var
  ClassName, aUpdate, aWhere, TableFull : String;
begin
  Result := Self;
  TSimpleRTTI<T>.New(FInstance)
    .TableName(ClassName)
    .Update(aUpdate)
    .Where(aWhere);
  TableFull := QualifiedTableName(ClassName);
  aSQL := aSQL + 'UPDATE ' + TableFull;
  aSQL := aSQL + ' SET ' + aUpdate;
  aSQL := aSQL + ' WHERE ' + aWhere;
end;

function TSimpleSQL<T>.Where(aSQL: String): iSimpleSQL<T>;
begin
  Result := Self;
  FWhere := aSQL;
end;

function TSimpleSQL<T>.QualifiedTableName(const aClassName: String): String;
begin
  if TSimpleConfig.UseSchemaPrefix and (Trim(TSimpleConfig.Schema) <> '') then
    Result := TSimpleConfig.Schema + '.' + aClassName
  else
    Result := aClassName;
end;
end.
