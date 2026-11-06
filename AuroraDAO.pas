unit AuroraDAO;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  System.Variants,
  Data.DB,
  {$IFNDEF CONSOLE}
    {$IFDEF FMX}
      FMX.Forms,
    {$ELSE}
      Vcl.Forms,
    {$ENDIF}
  {$ENDIF}
  AuroraInterface,
  AuroraAttributes,
  AuroraMetadata,
  AuroraConfig;

type
  // Levantada por Update quando a entidade usa [Version] e o UPDATE afeta 0
  // linhas - sinal de que outra transacao alterou (ou removeu) o registro
  // entre a leitura e esta escrita (analogo a OptimisticLockException do JPA).
  EAuroraOptimisticLockError = class(Exception);

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
    FMeta: TAuroraEntityMeta;
  private
    function QualifiedTableName(const ATable: string): string;
    procedure BuildInsertParts(out FieldsCSV, ParamsCSV: string);
    procedure AssignParamsFromEntity(const AEntity: T);
    procedure AssignParam(const AName: string; const AValue: Variant);
    function NewEntityInstance: T;
    procedure MapDataSetToEntity(ADataset: TDataSet; var AEntity: T);
    procedure PopulateEagerRelations(AEntity: T);
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
  FMeta := TAuroraMetadataRegistry.GetOrBuild<T>;
end;

destructor TAuroraDAO<T>.Destroy;
begin
  FSQLAttr := nil; // interface: libera por contagem de referência
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

procedure TAuroraDAO<T>.BuildInsertParts(out FieldsCSV, ParamsCSV: string);
var
  F: TAuroraFieldMeta;
begin
  FieldsCSV := '';
  ParamsCSV := '';
  for F in FMeta.InsertableFields do
  begin
    FieldsCSV := FieldsCSV + F.FieldName + ', ';
    ParamsCSV := ParamsCSV + ':' + F.FieldName + ', ';
  end;
  if FieldsCSV <> '' then
    FieldsCSV := Copy(FieldsCSV, 1, Length(FieldsCSV) - 2);
  if ParamsCSV <> '' then
    ParamsCSV := Copy(ParamsCSV, 1, Length(ParamsCSV) - 2);
end;

procedure TAuroraDAO<T>.AssignParamsFromEntity(const AEntity: T);
var
  F: TAuroraFieldMeta;
begin
  for F in FMeta.InsertableFields do
    AssignParam(F.FieldName, F.GetValue(TObject(AEntity)).AsVariant);
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

function TAuroraDAO<T>.NewEntityInstance: T;
begin
  Result := T.Create;
end;

procedure TAuroraDAO<T>.MapDataSetToEntity(ADataset: TDataSet; var AEntity: T);
var
  F: TAuroraFieldMeta;
  Field: TField;
  V: TValue;
begin
  if not Assigned(AEntity) then
    AEntity := NewEntityInstance;
  for F in FMeta.Fields do
  begin
    Field := ADataset.FindField(F.FieldName);
    if not Assigned(Field) then
      Continue;
    case F.TypeKind of
      tkInteger: V := Field.AsInteger;
      tkInt64: V := Field.AsLargeInt;
      tkFloat: V := Field.AsFloat;
      tkString, tkUString, tkWString: V := Field.AsString;
      tkEnumeration: V := Field.AsBoolean;
      else
        V := TValue.Empty;
    end;
    if not V.IsEmpty then
      F.SetValue(TObject(AEntity), V);
  end;
  PopulateEagerRelations(AEntity);
end;

procedure TAuroraDAO<T>.PopulateEagerRelations(AEntity: T);
var
  Rel: TAuroraRelationMeta;
  LocalField: TAuroraFieldMeta;
  TargetClass: TClass;
  TargetMeta: TAuroraEntityMeta;
  SubQuery: iAuroraQuery;
  LocalValue: Variant;
  Related: TObject;
  V: TValue;
begin
  if not Assigned(AEntity) then
    Exit;
  for Rel in FMeta.Relations do
  begin
    if not (Rel.Kind in [rkHasOne, rkBelongsTo]) then
      Continue; // HasMany/BelongsToMany sao lazy - ver AuroraRelations.LoadMany<R>
    TargetClass := Rel.ResolveTargetClass;
    if TargetClass = nil then
      Continue; // entidade relacionada ainda nao foi vinculada em RTTI (unit nao usada no escopo)
    TargetMeta := TAuroraMetadataRegistry.GetOrBuildByTypeInfo(TargetClass.ClassInfo);
    LocalField := FMeta.FieldByColumn(Rel.LocalKey);
    if LocalField = nil then
      Continue;
    LocalValue := LocalField.GetValue(TObject(AEntity)).AsVariant;
    if VarIsNull(LocalValue) or VarIsEmpty(LocalValue) then
      Continue;

    SubQuery := FQuery.Clone;
    SubQuery.SQL.Text := System.SysUtils.Format('SELECT * FROM %s WHERE %s = :%s',
      [QualifiedTableName(TargetMeta.TableName), Rel.ForeignKey, Rel.ForeignKey]);
    SubQuery.Params.CreateParam(ftUnknown, Rel.ForeignKey, ptInput).Value := LocalValue;
    SubQuery.Open;
    if not SubQuery.DataSet.Eof then
    begin
      // Apenas um nivel de profundidade: o mapeamento aqui e puramente por coluna,
      // sem recursao em PopulateEagerRelations do lado relacionado (evita ciclos
      // em relacionamentos bidirecionais, ex.: User HasOne Profile / Profile BelongsTo User).
      Related := AuroraMapDataSetToInstance(TargetMeta, SubQuery.DataSet);
      TValue.Make(@Related, Rel.RttiProp.PropertyType.Handle, V);
      Rel.RttiProp.SetValue(TObject(AEntity), V);
    end;
  end;
end;

{$IFNDEF CONSOLE}
function TAuroraDAO<T>.Insert: iAuroraDAO<T>;
var
  Entity: T;
begin
  Result := Self;
  Entity := NewEntityInstance;
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
  SQLText := System.SysUtils.Format('INSERT INTO %s (%s) VALUES (%s)', [QualifiedTableName(FMeta.TableName), FieldsCSV, ParamsCSV]);
  FQuery.SQL.Text := SQLText;
  AssignParamsFromEntity(aValue);
  FQuery.ExecSQL;
end;

function TAuroraDAO<T>.Update(var aValue: T): iAuroraDAO<T>;
var
  SetExpr, WhereExpr, SQLText: string;
  F: TAuroraFieldMeta;
  OldVersion: TValue;
  NewVersion: TValue;
begin
  Result := Self;
  SetExpr := '';
  for F in FMeta.UpdatableFields do
  begin
    if F = FMeta.VersionField then
      Continue; // versao e incrementada explicitamente abaixo, nunca via valor do chamador
    SetExpr := SetExpr + System.SysUtils.Format('%s = :%s, ', [F.FieldName, F.FieldName]);
  end;
  if Assigned(FMeta.VersionField) then
    SetExpr := SetExpr + System.SysUtils.Format('%s = %s + 1, ', [FMeta.VersionField.FieldName, FMeta.VersionField.FieldName]);
  if SetExpr <> '' then
    SetExpr := Copy(SetExpr, 1, Length(SetExpr) - 2);

  WhereExpr := '';
  for F in FMeta.PKFields do
    WhereExpr := WhereExpr + System.SysUtils.Format('%s = :%s AND ', [F.FieldName, F.FieldName]);
  if Assigned(FMeta.VersionField) then
    WhereExpr := WhereExpr + System.SysUtils.Format('%s = :%s AND ', [FMeta.VersionField.FieldName, FMeta.VersionField.FieldName]);
  if WhereExpr <> '' then
    WhereExpr := Copy(WhereExpr, 1, Length(WhereExpr) - 5);

  if WhereExpr <> '' then
    SQLText := System.SysUtils.Format('UPDATE %s SET %s WHERE %s', [QualifiedTableName(FMeta.TableName), SetExpr, WhereExpr])
  else
    SQLText := System.SysUtils.Format('UPDATE %s SET %s', [QualifiedTableName(FMeta.TableName), SetExpr]);

  FQuery.SQL.Text := SQLText;
  AssignParamsFromEntity(aValue);
  for F in FMeta.PKFields do
    AssignParam(F.FieldName, F.GetValue(TObject(aValue)).AsVariant);
  if Assigned(FMeta.VersionField) then
  begin
    OldVersion := FMeta.VersionField.GetValue(TObject(aValue));
    AssignParam(FMeta.VersionField.FieldName, OldVersion.AsVariant);
  end;

  FQuery.ExecSQL;

  if Assigned(FMeta.VersionField) then
  begin
    if FQuery.RowsAffected = 0 then
      raise EAuroraOptimisticLockError.CreateFmt(
        'Registro de %s (versao %s) foi alterado por outra transacao antes deste UPDATE.',
        [FMeta.TableName, OldVersion.ToString]);
    // Mantem a entidade em memoria sincronizada com o novo valor de versao no banco.
    NewVersion := TValue.FromOrdinal(FMeta.VersionField.RttiType.Handle, OldVersion.AsOrdinal + 1);
    FMeta.VersionField.SetValue(TObject(aValue), NewVersion);
  end;
end;

function TAuroraDAO<T>.Delete(aValue: T): iAuroraDAO<T>;
var
  WhereExpr, SQLText: string;
  F: TAuroraFieldMeta;
begin
  Result := Self;
  WhereExpr := '';
  for F in FMeta.PKFields do
    WhereExpr := WhereExpr + System.SysUtils.Format('%s = :%s AND ', [F.FieldName, F.FieldName]);
  if WhereExpr <> '' then
    WhereExpr := Copy(WhereExpr, 1, Length(WhereExpr) - 5);

  SQLText := System.SysUtils.Format('DELETE FROM %s WHERE %s', [QualifiedTableName(FMeta.TableName), WhereExpr]);
  FQuery.SQL.Text := SQLText;
  // Atribui parametro para CADA campo de PK (chave composta inclusive) - o codigo
  // anterior so atribuia o primeiro e quebrava o loop, deixando params sem valor
  // em chaves compostas mesmo com WHERE pedindo todos.
  for F in FMeta.PKFields do
    AssignParam(F.FieldName, F.GetValue(TObject(aValue)).AsVariant);
  FQuery.ExecSQL;
end;

function TAuroraDAO<T>.LastID: iAuroraDAO<T>;
var
  SQLText: string;
  PK: TAuroraFieldMeta;
begin
  Result := Self;
  PK := FMeta.PrimaryPK;
  if PK = nil then
    Exit;
  SQLText := System.SysUtils.Format('SELECT MAX(%s) AS last_id FROM %s', [PK.FieldName, QualifiedTableName(FMeta.TableName)]);
  FQuery.SQL.Text := SQLText;
  FQuery.Open;
end;

function TAuroraDAO<T>.LastRecord: iAuroraDAO<T>;
var
  SQLText, PKName, Tbl: string;
begin
  Result := Self;
  Tbl := QualifiedTableName(FMeta.TableName);
  if FMeta.PrimaryPK <> nil then
    PKName := FMeta.PrimaryPK.FieldName
  else
    PKName := 'id';
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
  SQLText := System.SysUtils.Format('DELETE FROM %s WHERE %s = :%s', [QualifiedTableName(FMeta.TableName), aField, aField]);
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
  SQLText := System.SysUtils.Format('SELECT * FROM %s', [QualifiedTableName(FMeta.TableName)]);
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
  SQLText := System.SysUtils.Format('SELECT * FROM %s', [QualifiedTableName(FMeta.TableName)]);
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
  if FMeta.PrimaryPK = nil then
    Exit;
  PKName := FMeta.PrimaryPK.FieldName;
  SQLText := System.SysUtils.Format('SELECT * FROM %s WHERE %s = :%s', [QualifiedTableName(FMeta.TableName), PKName, PKName]);
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
  if FMeta.PrimaryPK = nil then
    Exit;
  PKName := FMeta.PrimaryPK.FieldName;
  SQLText := System.SysUtils.Format('SELECT * FROM %s WHERE %s = :%s', [QualifiedTableName(FMeta.TableName), PKName, PKName]);
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
  SQLText := System.SysUtils.Format('SELECT * FROM %s WHERE %s = :%s', [QualifiedTableName(FMeta.TableName), aKey, aKey]);
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
  SQLText := System.SysUtils.Format('SELECT * FROM %s WHERE %s = :%s', [QualifiedTableName(FMeta.TableName), aKey, aKey]);
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
