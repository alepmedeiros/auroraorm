unit AuroraRTTI;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.Generics.Collections,
  System.Variants,
  Data.DB,
  AuroraInterface,
  AuroraAttributes,
  AuroraMetadata
  {$IFNDEF CONSOLE}, Vcl.Forms{$ENDIF};

type
  // Fachada fina sobre TAuroraMetadataRegistry: preserva a interface iAuroraRTTI<T>
  // (usada diretamente por consumidores externos) sem reescanear RTTI a cada chamada.
  TAuroraRTTI<T: class, constructor> = class(TInterfacedObject, iAuroraRTTI<T>)
  private
    FInstance: T;
    FMeta: TAuroraEntityMeta;
  public
    constructor Create(aInstance: T);
    class function New(aInstance: T): iAuroraRTTI<T>;

    function TableName(var aTableName: String): iAuroraRTTI<T>;
    function ClassName(var aClassName: String): iAuroraRTTI<T>;
    function DictionaryFields(var aDictionary: TDictionary<string, variant>): iAuroraRTTI<T>;
    function DictionaryTypeFields(var aDictionary: TDictionary<string, TFieldType>): iAuroraRTTI<T>;
    function ListFields(var List: TList<String>): iAuroraRTTI<T>;
    function Update(var aUpdate: String): iAuroraRTTI<T>;
    function Where(var aWhere: String): iAuroraRTTI<T>;
    function Fields(var aFields: String): iAuroraRTTI<T>;
    function FieldsInsert(var aFields: String): iAuroraRTTI<T>;
    function Param(var aParam: String): iAuroraRTTI<T>;
    function DataSetToEntity(aDataSet: TDataSet; var aEntity: T): iAuroraRTTI<T>;
    function DataSetToEntityList(aDataSet: TDataSet; var aList: TObjectList<T>): iAuroraRTTI<T>;
    function PrimaryKey(var aPK: String): iAuroraRTTI<T>;
    function GetDataType(aCampo: String; var aType: TFieldType): iAuroraRTTI<T>;
    {$IFNDEF CONSOLE}
    function BindClassToForm(aForm: TForm; const aEntity: T): iAuroraRTTI<T>;
    function BindFormToClass(aForm: TForm; var aEntity: T): iAuroraRTTI<T>;
    {$ENDIF}
  end;

implementation

{ TAuroraRTTI<T> }

constructor TAuroraRTTI<T>.Create(aInstance: T);
begin
  inherited Create;
  FInstance := aInstance;
  FMeta := TAuroraMetadataRegistry.GetOrBuild<T>;
end;

class function TAuroraRTTI<T>.New(aInstance: T): iAuroraRTTI<T>;
begin
  Result := Self.Create(aInstance);
end;

function TAuroraRTTI<T>.TableName(var aTableName: String): iAuroraRTTI<T>;
begin
  Result := Self;
  aTableName := FMeta.TableName;
end;

function TAuroraRTTI<T>.ClassName(var aClassName: String): iAuroraRTTI<T>;
begin
  Result := Self;
  aClassName := FMeta.RttiType.Name;
end;

function TAuroraRTTI<T>.DictionaryFields(var aDictionary: TDictionary<string, variant>): iAuroraRTTI<T>;
var
  F: TAuroraFieldMeta;
begin
  Result := Self;
  if aDictionary = nil then
    aDictionary := TDictionary<string, variant>.Create;
  for F in FMeta.Fields do
  begin
    if F.IsIgnore or F.IsJsonIgnore or F.IsAutoInc then
      Continue;
    if Assigned(FInstance) then
      aDictionary.AddOrSetValue(F.FieldName, F.GetValue(TObject(FInstance)).AsVariant)
    else
      aDictionary.AddOrSetValue(F.FieldName, Null);
  end;
end;

function TAuroraRTTI<T>.DictionaryTypeFields(var aDictionary: TDictionary<string, TFieldType>): iAuroraRTTI<T>;
var
  F: TAuroraFieldMeta;
  FT: TFieldType;
begin
  Result := Self;
  if aDictionary = nil then
    aDictionary := TDictionary<string, TFieldType>.Create;
  for F in FMeta.Fields do
  begin
    if F.IsIgnore then
      Continue;
    case F.TypeKind of
      tkInteger: FT := ftInteger;
      tkInt64: FT := ftLargeint;
      tkFloat: FT := ftFloat; // inclui DateTime como float; pode ser ajustado se necessário
      tkString, tkUString, tkWString: FT := ftWideString;
      tkVariant: FT := ftVariant;
      tkEnumeration: FT := ftBoolean;
      tkClass, tkDynArray: FT := ftBlob;
    else
      FT := ftString;
    end;
    aDictionary.AddOrSetValue(F.FieldName, FT);
  end;
end;

function TAuroraRTTI<T>.ListFields(var List: TList<String>): iAuroraRTTI<T>;
var
  F: TAuroraFieldMeta;
begin
  Result := Self;
  if List = nil then
    List := TList<string>.Create;
  for F in FMeta.Fields do
    List.Add(F.FieldName);
end;

function TAuroraRTTI<T>.Update(var aUpdate: String): iAuroraRTTI<T>;
var
  F: TAuroraFieldMeta;
begin
  Result := Self;
  aUpdate := '';
  for F in FMeta.UpdatableFields do
    aUpdate := aUpdate + System.SysUtils.Format('%s = :%s, ', [F.FieldName, F.FieldName]);
  if aUpdate <> '' then
    aUpdate := Copy(aUpdate, 1, Length(aUpdate) - 2) + ' ';
end;

function TAuroraRTTI<T>.Where(var aWhere: String): iAuroraRTTI<T>;
var
  F: TAuroraFieldMeta;
begin
  Result := Self;
  aWhere := '';
  for F in FMeta.PKFields do
    aWhere := aWhere + System.SysUtils.Format('%s = :%s AND ', [F.FieldName, F.FieldName]);
  if aWhere <> '' then
    aWhere := Copy(aWhere, 1, Length(aWhere) - 4) + ' ';
end;

function TAuroraRTTI<T>.Fields(var aFields: String): iAuroraRTTI<T>;
var
  F: TAuroraFieldMeta;
begin
  Result := Self;
  aFields := '';
  for F in FMeta.Fields do
  begin
    if F.IsIgnore then
      Continue;
    aFields := aFields + F.FieldName + ', ';
  end;
  if aFields <> '' then
    aFields := Copy(aFields, 1, Length(aFields) - 2) + ' ';
end;

function TAuroraRTTI<T>.FieldsInsert(var aFields: String): iAuroraRTTI<T>;
var
  F: TAuroraFieldMeta;
begin
  Result := Self;
  aFields := '';
  for F in FMeta.InsertableFields do
    aFields := aFields + F.FieldName + ', ';
  if aFields <> '' then
    aFields := Copy(aFields, 1, Length(aFields) - 2) + ' ';
end;

function TAuroraRTTI<T>.Param(var aParam: String): iAuroraRTTI<T>;
var
  F: TAuroraFieldMeta;
begin
  Result := Self;
  aParam := '';
  for F in FMeta.InsertableFields do
    aParam := aParam + ':' + F.FieldName + ', ';
  if aParam <> '' then
    aParam := Copy(aParam, 1, Length(aParam) - 2) + ' ';
end;

function TAuroraRTTI<T>.PrimaryKey(var aPK: String): iAuroraRTTI<T>;
begin
  Result := Self;
  if FMeta.PrimaryPK <> nil then
    aPK := FMeta.PrimaryPK.FieldName
  else
    aPK := '';
end;

function TAuroraRTTI<T>.GetDataType(aCampo: String; var aType: TFieldType): iAuroraRTTI<T>;
var
  F: TAuroraFieldMeta;
begin
  Result := Self;
  aType := ftUnknown;
  F := FMeta.FieldByColumn(aCampo);
  if F = nil then
    Exit;
  case F.TypeKind of
    tkFloat: aType := ftDateTime; // assumindo DateTime
    tkString, tkUString, tkWString: aType := ftWideString;
    tkInteger: aType := ftInteger;
    tkInt64: aType := ftLargeint;
  else
    aType := ftString;
  end;
end;

function TAuroraRTTI<T>.DataSetToEntity(aDataSet: TDataSet; var aEntity: T): iAuroraRTTI<T>;
begin
  Result := Self;
  if not Assigned(aEntity) then
    aEntity := T.Create;
  AuroraMapDataSetIntoInstance(FMeta, aDataSet, aEntity);
end;

function TAuroraRTTI<T>.DataSetToEntityList(aDataSet: TDataSet; var aList: TObjectList<T>): iAuroraRTTI<T>;
var
  Item: T;
begin
  Result := Self;
  if aList = nil then
    aList := TObjectList<T>.Create(True);
  if not aDataSet.Active then Exit;
  aDataSet.First;
  while not aDataSet.Eof do
  begin
    Item := nil;
    DataSetToEntity(aDataSet, Item);
    aList.Add(Item);
    aDataSet.Next;
  end;
end;

{$IFNDEF CONSOLE}
function TAuroraRTTI<T>.BindClassToForm(aForm: TForm; const aEntity: T): iAuroraRTTI<T>;
begin
  Result := Self; // não implementado para headless
end;

function TAuroraRTTI<T>.BindFormToClass(aForm: TForm; var aEntity: T): iAuroraRTTI<T>;
begin
  Result := Self; // não implementado para headless
end;
{$ENDIF}

end.
