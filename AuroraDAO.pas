unit AuroraDAO;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  System.Variants,
  Data.DB,
  AuroraInterface,
  AuroraAttributes,
  AuroraConfig;

type
  TAuroraDAOSQLAttribute<T: class, constructor> = class(TInterfacedObject, iAuroraDAOSQLAttribute<T>)
  private
    FOwner: TObject; // referência fraca ao DAO para evitar ciclo de interfaces
    FFields: string;
    FWhere: string;
    FOrderBy: string;
    FGroupBy: string;
    FJoin: string;
  public
    constructor Create(const AOwner: TObject);
    function Fields(aSQL: String): iAuroraDAOSQLAttribute<T>; overload;
    function Where(aSQL: String): iAuroraDAOSQLAttribute<T>; overload;
    function OrderBy(aSQL: String): iAuroraDAOSQLAttribute<T>; overload;
    function GroupBy(aSQL: String): iAuroraDAOSQLAttribute<T>; overload;
    function Join(aSQL: String): iAuroraDAOSQLAttribute<T>; overload;
    function Join: String; overload;
    function Fields: String; overload;
    function Where: String; overload;
    function OrderBy: String; overload;
    function GroupBy: String; overload;
    function Clear: iAuroraDAOSQLAttribute<T>;
    function &End: iAuroraDAO<T>;
  end;

  TAuroraDAO<T: class, constructor> = class(TInterfacedObject, iAuroraDAO<T>)
  private
    FQuery: iAuroraQuery;
    FDataSource: TDataSource;
    FSQLAttr: iAuroraDAOSQLAttribute<T>;
    FRttiContext: TRttiContext;
    function GetLocalValue(const AEntity: T; const ALocalKey: string; out V: Variant): Boolean;
  private
    function QualifiedTableName(const ATable: string): string;
    function RTTIType: TRttiType;
    function TableName: string;
    function PKFieldName: string;
    procedure BuildInsertParts(out FieldsCSV, ParamsCSV: string);
    procedure AssignParamsFromEntity(const AEntity: T);
    procedure AssignParam(const AName: string; const AValue: Variant);
    function NewInstance: T;
    procedure MapDataSetToEntity(ADataset: TDataSet; var AEntity: T);
  public
    constructor Create(aQuery: iAuroraQuery);
    destructor Destroy; override;
    class function New(aQuery: iAuroraQuery): iAuroraDAO<T>;
    class function NewAurora(aQuery: iAuroraQuery): iAuroraDAO<T>;
    // iAuroraDAO
    {$IFNDEF CONSOLE}
    function Insert: iAuroraDAO<T>; overload;
    function Update: iAuroraDAO<T>; overload;
    function Delete: iAuroraDAO<T>; overload;
    {$ENDIF}
    function Insert(var aValue: T): iAuroraDAO<T>; overload;
    function Update(var aValue: T): iAuroraDAO<T>; overload;
    function Delete(aValue: T): iAuroraDAO<T>; overload;
    function LastID: iAuroraDAO<T>;
    function LastRecord: iAuroraDAO<T>;
    function Delete(aField: String; aValue: String): iAuroraDAO<T>; overload;
    function DataSource(aDataSource: TDataSource): iAuroraDAO<T>;
    function Find(aBindList: Boolean = True): iAuroraDAO<T>; overload;
    function Find(var aList: TObjectList<T>): iAuroraDAO<T>; overload;
    function Find(aId: Integer): T; overload;
    function Find(aID: String): T; overload;
    function FindOneWhere(aKey: String; aValue: Variant): T;
    function FindWhere(aKey: String; aValue: Variant): TObjectList<T>;
    function Find(aKey: String; aValue: Variant): iAuroraDAO<T>; overload;
    function SQL: iAuroraDAOSQLAttribute<T>;
    {$IFNDEF CONSOLE}
    function BindForm(aForm: TForm): iAuroraDAO<T>;
    {$ENDIF}
    function LoadOne<R: class, constructor>(var aEntity: T; const aLocalKey, aForeignKey: string; out aRelated: R): iAuroraDAO<T>;
    function LoadMany<R: class, constructor>(var aEntity: T; const aLocalKey, aForeignKey: string; out aList: TObjectList<R>): iAuroraDAO<T>;
  end;

implementation

{ TAuroraDAOSQLAttribute<T> }

constructor TAuroraDAOSQLAttribute<T>.Create(const AOwner: TObject);
begin
  inherited Create;
  FOwner := AOwner;
  Clear;
end;

function TAuroraDAOSQLAttribute<T>.Fields(aSQL: String): iAuroraDAOSQLAttribute<T>;
begin
  FFields := aSQL;
  Result := Self;
end;

function TAuroraDAOSQLAttribute<T>.Where(aSQL: String): iAuroraDAOSQLAttribute<T>;
begin
  FWhere := aSQL;
  Result := Self;
end;

function TAuroraDAOSQLAttribute<T>.OrderBy(aSQL: String): iAuroraDAOSQLAttribute<T>;
begin
  FOrderBy := aSQL;
  Result := Self;
end;

function TAuroraDAOSQLAttribute<T>.GroupBy(aSQL: String): iAuroraDAOSQLAttribute<T>;
begin
  FGroupBy := aSQL;
  Result := Self;
end;

function TAuroraDAOSQLAttribute<T>.Join(aSQL: String): iAuroraDAOSQLAttribute<T>;
begin
  FJoin := aSQL;
  Result := Self;
end;

function TAuroraDAOSQLAttribute<T>.Join: String;
begin
  Result := FJoin;
end;

function TAuroraDAOSQLAttribute<T>.Fields: String;
begin
  Result := FFields;
end;

function TAuroraDAOSQLAttribute<T>.Where: String;
begin
  Result := FWhere;
end;

function TAuroraDAOSQLAttribute<T>.OrderBy: String;
begin
  Result := FOrderBy;
end;

function TAuroraDAOSQLAttribute<T>.GroupBy: String;
begin
  Result := FGroupBy;
end;

function TAuroraDAOSQLAttribute<T>.Clear: iAuroraDAOSQLAttribute<T>;
begin
  FFields := '';
  FWhere := '';
  FOrderBy := '';
  FGroupBy := '';
  FJoin := '';
  Result := Self;
end;

function TAuroraDAOSQLAttribute<T>.&End: iAuroraDAO<T>;
begin
  // Retorna o DAO dono (cast seguro para a classe, com conversão implícita para interface)
  Result := TAuroraDAO<T>(FOwner);
end;

{ TAuroraDAO<T> }

constructor TAuroraDAO<T>.Create(aQuery: iAuroraQuery);
begin
  inherited Create;
  FQuery := aQuery;
  FSQLAttr := TAuroraDAOSQLAttribute<T>.Create(Self);
  FRttiContext := TRttiContext.Create;
end;

destructor TAuroraDAO<T>.Destroy;
begin
  FSQLAttr := nil; // interface: libera por contagem de referência
  FRttiContext.Free;
  inherited;
end;

class function TAuroraDAO<T>.New(aQuery: iAuroraQuery): iAuroraDAO<T>;
begin
  Result := Self.Create(aQuery);
end;

class function TAuroraDAO<T>.NewAurora(aQuery: iAuroraQuery): iAuroraDAO<T>;
begin
  Result := Self.Create(aQuery);
end;

function TAuroraDAO<T>.QualifiedTableName(const ATable: string): string;
begin
  if TAuroraConfig.UseSchemaPrefix then
    Result := System.SysUtils.Format('%s.%s', [TAuroraConfig.Schema, ATable])
  else
    Result := ATable;
end;

function TAuroraDAO<T>.RTTIType: TRttiType;
begin
  Result := FRttiContext.GetType(TypeInfo(T));
end;

function TAuroraDAO<T>.TableName: string;
var
  Typ: TRttiType;
  Attr: TCustomAttribute;
  Base: string;
begin
  Result := '';
  Typ := RTTIType;
  for Attr in Typ.GetAttributes do
    if Attr is Tabela then
      Exit(Tabela(Attr).Name);
  // fallback
  Base := Typ.Name;
  if (Length(Base) > 0) and (Base[1] = 'T') then
    Base := Copy(Base, 2, Length(Base) - 1);
  Base := LowerCase(Base);
  if (Length(Base) = 0) then
    Result := LowerCase(Typ.Name)
  else if (Base[Length(Base)] <> 's') then
    Result := Base + 's'
  else
    Result := Base;
end;

function TAuroraDAO<T>.PKFieldName: string;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  InnerAttr: TCustomAttribute;
  FieldName: string;
begin
  Result := 'id';
  Typ := RTTIType;
  for Prop in Typ.GetProperties do
  begin
    for Attr in Prop.GetAttributes do
    begin
      if Attr is PK then
      begin
        // Se houver [Campo], usa o nome do campo; caso contrário, usa o nome da propriedade
        FieldName := '';
        for InnerAttr in Prop.GetAttributes do
          if InnerAttr is Campo then
            FieldName := Campo(InnerAttr).Name;
        if FieldName <> '' then
          Exit(FieldName)
        else
          Exit(Prop.Name);
      end;
    end;
  end;
end;

procedure TAuroraDAO<T>.BuildInsertParts(out FieldsCSV, ParamsCSV: string);
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldRtti: TRttiField;
  HasIgnore, HasAutoInc: Boolean;
  Attr: TCustomAttribute;
  FieldName: string;
begin
  FieldsCSV := '';
  ParamsCSV := '';
  Typ := RTTIType;
  if Typ = nil then Exit;
  for Prop in Typ.GetProperties do
  begin
    HasIgnore := False;
    HasAutoInc := False;
    FieldName := '';
    for Attr in Prop.GetAttributes do
    begin
      if Attr is Ignore then HasIgnore := True;
      if Attr is AutoInc then HasAutoInc := True;
      if Attr is Campo then FieldName := Campo(Attr).Name;
    end;
    if HasIgnore or HasAutoInc then
      Continue;
    if FieldName = '' then
      Continue;
    FieldsCSV := FieldsCSV + FieldName + ', ';
    ParamsCSV := ParamsCSV + ':' + FieldName + ', ';
  end;
  // Também suporta atributos em fields (ex.: [Campo] no FId/FName/FEmail)
  for FieldRtti in Typ.GetFields do
  begin
    HasIgnore := False;
    HasAutoInc := False;
    FieldName := '';
    for Attr in FieldRtti.GetAttributes do
    begin
      if Attr is Ignore then HasIgnore := True;
      if Attr is AutoInc then HasAutoInc := True;
      if Attr is Campo then FieldName := Campo(Attr).Name;
    end;
    if HasIgnore or HasAutoInc then
      Continue;
    if FieldName = '' then
      Continue;
    FieldsCSV := FieldsCSV + FieldName + ', ';
    ParamsCSV := ParamsCSV + ':' + FieldName + ', ';
  end;
  if FieldsCSV <> '' then
    FieldsCSV := Copy(FieldsCSV, 1, Length(FieldsCSV) - 2);
  if ParamsCSV <> '' then
    ParamsCSV := Copy(ParamsCSV, 1, Length(ParamsCSV) - 2);
end;

procedure TAuroraDAO<T>.AssignParamsFromEntity(const AEntity: T);
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldRtti: TRttiField;
  Attr: TCustomAttribute;
  FieldName: string;
  HasIgnore, HasAutoInc: Boolean;
  V: TValue;
begin
  Typ := RTTIType;
  if Typ = nil then Exit;
  for Prop in Typ.GetProperties do
  begin
    FieldName := '';
    HasIgnore := False;
    HasAutoInc := False;
    for Attr in Prop.GetAttributes do
    begin
      if Attr is Ignore then HasIgnore := True;
      if Attr is AutoInc then HasAutoInc := True;
      if Attr is Campo then FieldName := Campo(Attr).Name;
    end;
    if HasIgnore or HasAutoInc then
      Continue;
    if FieldName = '' then
      Continue;
    V := Prop.GetValue(TObject(AEntity));
    AssignParam(FieldName, V.AsVariant);
  end;
  // Também suporta atributos em fields
  for FieldRtti in Typ.GetFields do
  begin
    FieldName := '';
    HasIgnore := False;
    HasAutoInc := False;
    for Attr in FieldRtti.GetAttributes do
    begin
      if Attr is Ignore then HasIgnore := True;
      if Attr is AutoInc then HasAutoInc := True;
      if Attr is Campo then FieldName := Campo(Attr).Name;
    end;
    if HasIgnore or HasAutoInc then
      Continue;
    if FieldName = '' then
      Continue;
    V := FieldRtti.GetValue(TObject(AEntity));
    AssignParam(FieldName, V.AsVariant);
  end;
end;

procedure TAuroraDAO<T>.AssignParam(const AName: string; const AValue: Variant);
var
  P: TParam;
begin
  // Garante que o parâmetro exista mesmo quando usando TParams desacoplado do provider
  P := FQuery.Params.FindParam(AName);
  if P = nil then
    P := FQuery.Params.CreateParam(ftUnknown, AName, ptInput);
  P.Value := AValue;
end;

function TAuroraDAO<T>.NewInstance: T;
begin
  Result := T.Create;
end;

procedure TAuroraDAO<T>.MapDataSetToEntity(ADataset: TDataSet; var AEntity: T);
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldRtti: TRttiField;
  Attr: TCustomAttribute;
  FieldName: string;
  Field: TField;
  V: TValue;
begin
  if not Assigned(AEntity) then
    AEntity := NewInstance;
  Typ := RTTIType;
  if Typ = nil then Exit;
  for Prop in Typ.GetProperties do
  begin
    FieldName := '';
    for Attr in Prop.GetAttributes do
      if Attr is Campo then
        FieldName := Campo(Attr).Name;
    if FieldName = '' then
      Continue;
    Field := ADataset.FieldByName(FieldName);
    if not Assigned(Field) then
      Continue;
    case Prop.PropertyType.TypeKind of
      tkInteger: V := Field.AsInteger;
      tkInt64: V := Field.AsLargeInt;
      tkFloat: V := Field.AsFloat;
      tkString, tkUString, tkWString: V := Field.AsString;
      tkEnumeration: V := Field.AsBoolean;
      else
        V := TValue.Empty;
    end;
    if not V.IsEmpty then
      Prop.SetValue(TObject(AEntity), V);
  end;
  // Também suporta atributos em fields
  for FieldRtti in Typ.GetFields do
  begin
    FieldName := '';
    for Attr in FieldRtti.GetAttributes do
      if Attr is Campo then
        FieldName := Campo(Attr).Name;
    if FieldName = '' then
      Continue;
    Field := ADataset.FieldByName(FieldName);
    if not Assigned(Field) then
      Continue;
    // Mapeia usando o tipo de destino (FieldRtti.FieldType), garantindo conversão correta
    case FieldRtti.FieldType.TypeKind of
      tkInteger:
        V := TValue.From<Integer>(Field.AsInteger);
      tkInt64:
        V := TValue.From<Int64>(Field.AsLargeInt);
      tkFloat:
        V := TValue.From<Double>(Field.AsFloat);
      tkString, tkUString, tkWString:
        V := TValue.From<string>(Field.AsString);
      tkEnumeration:
        // Suporta booleanos simples
        V := TValue.From<Boolean>(Field.AsBoolean);
      else
        V := TValue.Empty;
    end;
    if not V.IsEmpty then
      FieldRtti.SetValue(TObject(AEntity), V);
  end;
end;

{$IFNDEF CONSOLE}
function TAuroraDAO<T>.Insert: iAuroraDAO<T>;
var
  Entity: T;
begin
  Result := Self;
  Entity := NewInstance;
  try
    Insert(Entity);
  finally
    Entity.Free;
  end;
end;

function TAuroraDAO<T>.Update: iAuroraDAO<T>;
begin
  Result := Self;
  // Not implemented in headless tests
end;

function TAuroraDAO<T>.Delete: iAuroraDAO<T>;
begin
  Result := Self;
  // Not implemented in headless tests
end;
{$ENDIF}

function TAuroraDAO<T>.Insert(var aValue: T): iAuroraDAO<T>;
var
  FieldsCSV, ParamsCSV, SQLText: string;
begin
  Result := Self;
  BuildInsertParts(FieldsCSV, ParamsCSV);
  SQLText := System.SysUtils.Format('INSERT INTO %s (%s) VALUES (%s)', [QualifiedTableName(TableName), FieldsCSV, ParamsCSV]);
  FQuery.SQL.Text := SQLText;
  AssignParamsFromEntity(aValue);
  FQuery.ExecSQL;
end;

function TAuroraDAO<T>.Update(var aValue: T): iAuroraDAO<T>;
var
  SetExpr, WhereExpr, SQLText: string;
begin
  Result := Self;
  SetExpr := '';
  WhereExpr := '';
  TAuroraRTTI<T>.New(nil).Update(SetExpr);
  TAuroraRTTI<T>.New(nil).Where(WhereExpr);
  SQLText := System.SysUtils.Format('UPDATE %s SET %s WHERE %s', [QualifiedTableName(TableName), Trim(SetExpr), Trim(WhereExpr)]);
  FQuery.SQL.Text := SQLText;
  AssignParamsFromEntity(aValue);
  FQuery.ExecSQL;
end;

function TAuroraDAO<T>.Delete(aValue: T): iAuroraDAO<T>;
var
  WhereExpr, SQLText: string;
  PKField: string;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  CampoName: string;
  V: TValue;
begin
  Result := Self;
  WhereExpr := '';
  TAuroraRTTI<T>.New(nil).Where(WhereExpr);
  SQLText := System.SysUtils.Format('DELETE FROM %s WHERE %s', [QualifiedTableName(TableName), Trim(WhereExpr)]);
  FQuery.SQL.Text := SQLText;
  PKField := PKFieldName;
  Typ := RTTIType;
  for Prop in Typ.GetProperties do
  begin
    CampoName := '';
    for Attr in Prop.GetAttributes do
      if Attr is Campo then CampoName := Campo(Attr).Name;
    if (CampoName = PKField) or SameText(Prop.Name, PKField) then
    begin
      V := Prop.GetValue(TObject(aValue));
      AssignParam(PKField, V.AsVariant);
      Break;
    end;
  end;
  FQuery.ExecSQL;
end;

function TAuroraDAO<T>.LastID: iAuroraDAO<T>;
begin
  Result := Self;
  // Minimal implementation omitted
end;

function TAuroraDAO<T>.LastRecord: iAuroraDAO<T>;
var
  SQLText, PKName, Tbl: string;
begin
  Result := Self;
  Tbl := QualifiedTableName(TableName);
  PKName := PKFieldName;
  case TAuroraConfig.Dialect of
    dbSQLite: SQLText := System.SysUtils.Format('SELECT * FROM %s ORDER BY %s DESC LIMIT 1', [Tbl, PKName]);
    dbPostgreSQL, dbMySQL: SQLText := System.SysUtils.Format('SELECT * FROM %s ORDER BY %s DESC LIMIT 1', [Tbl, PKName]);
    dbSQLServer: SQLText := System.SysUtils.Format('SELECT TOP 1 * FROM %s ORDER BY %s DESC', [Tbl, PKName]);
    else // Firebird and default
      SQLText := System.SysUtils.Format('SELECT FIRST 1 * FROM %s ORDER BY %s DESC', [Tbl, PKName]);
  end;
  FQuery.SQL.Text := SQLText;
  FQuery.Open;
end;

function TAuroraDAO<T>.Delete(aField, aValue: String): iAuroraDAO<T>;
var
  SQLText: string;
begin
  Result := Self;
  SQLText := System.SysUtils.Format('DELETE FROM %s WHERE %s = :%s', [QualifiedTableName(TableName), aField, aField]);
  FQuery.SQL.Text := SQLText;
  AssignParam(aField, aValue);
  FQuery.ExecSQL;
end;

function TAuroraDAO<T>.DataSource(aDataSource: TDataSource): iAuroraDAO<T>;
begin
  Result := Self;
  FDataSource := aDataSource;
  if Assigned(FDataSource) then
    FDataSource.DataSet := FQuery.DataSet;
end;

function TAuroraDAO<T>.Find(aBindList: Boolean): iAuroraDAO<T>;
var
  SQLText: string;
begin
  Result := Self;
  SQLText := System.SysUtils.Format('SELECT * FROM %s', [QualifiedTableName(TableName)]);
  if FSQLAttr.OrderBy <> '' then
    SQLText := SQLText + System.SysUtils.Format(' ORDER BY %s', [FSQLAttr.OrderBy]);
  FQuery.SQL.Text := SQLText;
  FQuery.Open;
end;

function TAuroraDAO<T>.Find(var aList: TObjectList<T>): iAuroraDAO<T>;
var
  SQLText: string;
  E: T;
begin
  Result := Self;
  SQLText := System.SysUtils.Format('SELECT * FROM %s', [QualifiedTableName(TableName)]);
  if FSQLAttr.OrderBy <> '' then
    SQLText := SQLText + System.SysUtils.Format(' ORDER BY %s', [FSQLAttr.OrderBy]);
  FQuery.SQL.Text := SQLText;
  FQuery.Open;
  while not FQuery.DataSet.Eof do
  begin
    E := nil;
    MapDataSetToEntity(FQuery.DataSet, E);
    if Assigned(E) then
      aList.Add(E);
    FQuery.DataSet.Next;
  end;
end;

function TAuroraDAO<T>.Find(aId: Integer): T;
var
  SQLText, PKName: string;
begin
  Result := nil;
  PKName := PKFieldName;
  SQLText := System.SysUtils.Format('SELECT * FROM %s WHERE %s = :%s', [QualifiedTableName(TableName), PKName, PKName]);
  FQuery.SQL.Text := SQLText;
  AssignParam(PKName, aId);
  FQuery.Open;
  MapDataSetToEntity(FQuery.DataSet, Result);
end;

function TAuroraDAO<T>.Find(aID: String): T;
var
  SQLText, PKName: string;
begin
  Result := nil;
  PKName := PKFieldName;
  SQLText := System.SysUtils.Format('SELECT * FROM %s WHERE %s = :%s', [QualifiedTableName(TableName), PKName, PKName]);
  FQuery.SQL.Text := SQLText;
  AssignParam(PKName, aID);
  FQuery.Open;
  MapDataSetToEntity(FQuery.DataSet, Result);
end;

function TAuroraDAO<T>.FindOneWhere(aKey: String; aValue: Variant): T;
var
  SQLText: string;
begin
  Result := nil;
  SQLText := System.SysUtils.Format('SELECT * FROM %s WHERE %s = :%s', [QualifiedTableName(TableName), aKey, aKey]);
  FQuery.SQL.Text := SQLText;
  AssignParam(aKey, aValue);
  FQuery.Open;
  MapDataSetToEntity(FQuery.DataSet, Result);
end;

function TAuroraDAO<T>.FindWhere(aKey: String; aValue: Variant): TObjectList<T>;
var
  SQLText: string;
  E: T;
begin
  Result := TObjectList<T>.Create(True);
  SQLText := System.SysUtils.Format('SELECT * FROM %s WHERE %s = :%s', [QualifiedTableName(TableName), aKey, aKey]);
  FQuery.SQL.Text := SQLText;
  AssignParam(aKey, aValue);
  FQuery.Open;
  while not FQuery.DataSet.Eof do
  begin
    E := nil;
    MapDataSetToEntity(FQuery.DataSet, E);
    if Assigned(E) then
      Result.Add(E);
    FQuery.DataSet.Next;
  end;
end;

function TAuroraDAO<T>.GetLocalValue(const AEntity: T; const ALocalKey: string; out V: Variant): Boolean;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  CampoName: string;
begin
  Result := False;
  V := Null;
  Typ := RTTIType;
  if Typ = nil then Exit;
  for Prop in Typ.GetProperties do
  begin
    if SameText(Prop.Name, ALocalKey) then
    begin
      V := Prop.GetValue(TObject(AEntity)).AsVariant;
      Exit(True);
    end;
    CampoName := '';
    for Attr in Prop.GetAttributes do
      if Attr is Campo then
        CampoName := Campo(Attr).Name;
    if (CampoName <> '') and SameText(CampoName, ALocalKey) then
    begin
      V := Prop.GetValue(TObject(AEntity)).AsVariant;
      Exit(True);
    end;
  end;
end;

function TAuroraDAO<T>.LoadOne<R>(var aEntity: T; const aLocalKey, aForeignKey: string; out aRelated: R): iAuroraDAO<T>;
var
  V: Variant;
  D: iAuroraDAO<R>;
begin
  Result := Self;
  aRelated := nil;
  if not GetLocalValue(aEntity, aLocalKey, V) then Exit;
  D := TAuroraDAO<R>.NewAurora(FQuery);
  aRelated := D.FindOneWhere(aForeignKey, V);
end;

function TAuroraDAO<T>.LoadMany<R>(var aEntity: T; const aLocalKey, aForeignKey: string; out aList: TObjectList<R>): iAuroraDAO<T>;
var
  V: Variant;
  D: iAuroraDAO<R>;
begin
  Result := Self;
  aList := nil;
  if not GetLocalValue(aEntity, aLocalKey, V) then Exit;
  D := TAuroraDAO<R>.NewAurora(FQuery);
  aList := D.FindWhere(aForeignKey, V);
end;

function TAuroraDAO<T>.Find(aKey: String; aValue: Variant): iAuroraDAO<T>;
begin
  Result := Self;
  // Minimal implementation omitted
end;

function TAuroraDAO<T>.SQL: iAuroraDAOSQLAttribute<T>;
begin
  Result := FSQLAttr;
end;

{$IFNDEF CONSOLE}
function TAuroraDAO<T>.BindForm(aForm: TForm): iAuroraDAO<T>;
begin
  Result := Self;
  // Not implemented in headless tests
end;
{$ENDIF}

end.
