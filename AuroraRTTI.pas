unit AuroraRTTI;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.Generics.Collections,
  System.Variants,
  Data.DB,
  AuroraInterface,
  AuroraAttributes
  {$IFNDEF CONSOLE}, Vcl.Forms{$ENDIF};

type
  TAuroraRTTI<T: class, constructor> = class(TInterfacedObject, iAuroraRTTI<T>)
  private
    FInstance: T;
    function RttiType: TRttiType;
    function PropertyFieldName(const Prop: TRttiProperty): string;
    function HasAttribute<A: TCustomAttribute>(const Attrs: TArray<TCustomAttribute>): Boolean;
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
end;

class function TAuroraRTTI<T>.New(aInstance: T): iAuroraRTTI<T>;
begin
  Result := Self.Create(aInstance);
end;

function TAuroraRTTI<T>.RttiType: TRttiType;
var
  Ctx: TRttiContext;
begin
  Ctx := TRttiContext.Create;
  Result := Ctx.GetType(TypeInfo(T));
end;

function TAuroraRTTI<T>.HasAttribute<A>(const Attrs: TArray<TCustomAttribute>): Boolean;
var
  Attr: TCustomAttribute;
begin
  Result := False;
  for Attr in Attrs do
    if Attr is A then
      Exit(True);
end;

function TAuroraRTTI<T>.PropertyFieldName(const Prop: TRttiProperty): string;
var
  Attr: TCustomAttribute;
begin
  Result := '';
  for Attr in Prop.GetAttributes do
    if Attr is Campo then
      Exit(Campo(Attr).Name);
end;

function TAuroraRTTI<T>.TableName(var aTableName: String): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Attr: TCustomAttribute;
  Base: string;
begin
  Result := Self;
  aTableName := '';
  Typ := RttiType;
  for Attr in Typ.GetAttributes do
    if Attr is Tabela then
    begin
      aTableName := Tabela(Attr).Name;
      Exit(Self);
    end;
  if aTableName = '' then
  begin
    // Convenção: remover prefixo 'T' e pluralizar com 's'
    Base := Typ.Name;
    if (Length(Base) > 0) and (Base[1] = 'T') then
      Base := Copy(Base, 2, Length(Base) - 1);
    Base := LowerCase(Base);
    if (Length(Base) = 0) then
      aTableName := LowerCase(Typ.Name)
    else if (Base[Length(Base)] <> 's') then
      aTableName := Base + 's'
    else
      aTableName := Base;
  end;
end;

function TAuroraRTTI<T>.ClassName(var aClassName: String): iAuroraRTTI<T>;
begin
  Result := Self;
  aClassName := RttiType.Name;
end;

function TAuroraRTTI<T>.DictionaryFields(var aDictionary: TDictionary<string, variant>): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldRtti: TRttiField;
  FieldName: string;
  V: TValue;
begin
  Result := Self;
  if aDictionary = nil then
    aDictionary := TDictionary<string, variant>.Create;
  Typ := RttiType;
  for Prop in Typ.GetProperties do
  begin
    // Ignore/AutoInc skip
    if HasAttribute<Ignore>(Prop.GetAttributes) or HasAttribute<JsonIgnore>(Prop.GetAttributes) or HasAttribute<AutoInc>(Prop.GetAttributes) then
      Continue;
    FieldName := PropertyFieldName(Prop);
    if FieldName = '' then
      Continue;
    if Assigned(FInstance) then
    begin
      V := Prop.GetValue(TObject(FInstance));
      aDictionary.AddOrSetValue(FieldName, V.AsVariant);
    end
    else
      aDictionary.AddOrSetValue(FieldName, Null);
  end;
  // Suporte a atributos aplicados diretamente nos fields privados
  for FieldRtti in Typ.GetFields do
  begin
    if HasAttribute<Ignore>(FieldRtti.GetAttributes) or HasAttribute<JsonIgnore>(FieldRtti.GetAttributes) or HasAttribute<AutoInc>(FieldRtti.GetAttributes) then
      Continue;
    FieldName := '';
    for var Attr in FieldRtti.GetAttributes do
      if Attr is Campo then
      begin
        FieldName := Campo(Attr).Name;
        Break;
      end;
    if FieldName = '' then
      Continue;
    if Assigned(FInstance) then
    begin
      V := FieldRtti.GetValue(TObject(FInstance));
      aDictionary.AddOrSetValue(FieldName, V.AsVariant);
    end
    else
      aDictionary.AddOrSetValue(FieldName, Null);
  end;
end;

function TAuroraRTTI<T>.DictionaryTypeFields(var aDictionary: TDictionary<string, TFieldType>): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldName: string;
  FT: TFieldType;
begin
  Result := Self;
  if aDictionary = nil then
    aDictionary := TDictionary<string, TFieldType>.Create;
  Typ := RttiType;
  for Prop in Typ.GetProperties do
  begin
    if HasAttribute<Ignore>(Prop.GetAttributes) then
      Continue;
    FieldName := PropertyFieldName(Prop);
    if FieldName = '' then
      Continue;
    case Prop.PropertyType.TypeKind of
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
    aDictionary.AddOrSetValue(FieldName, FT);
  end;
end;

function TAuroraRTTI<T>.ListFields(var List: TList<String>): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldName: string;
begin
  Result := Self;
  if List = nil then
    List := TList<string>.Create;
  Typ := RttiType;
  for Prop in Typ.GetProperties do
  begin
    FieldName := PropertyFieldName(Prop);
    if FieldName <> '' then
      List.Add(FieldName);
  end;
end;

function TAuroraRTTI<T>.Update(var aUpdate: String): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldName: string;
begin
  Result := Self;
  aUpdate := '';
  Typ := RttiType;
  for Prop in Typ.GetProperties do
  begin
    if HasAttribute<Ignore>(Prop.GetAttributes) or HasAttribute<AutoInc>(Prop.GetAttributes) then
      Continue;
    FieldName := PropertyFieldName(Prop);
    if FieldName = '' then
      Continue;
    aUpdate := aUpdate + System.SysUtils.Format('%s = :%s, ', [FieldName, FieldName]);
  end;
  if aUpdate <> '' then
    aUpdate := Copy(aUpdate, 1, Length(aUpdate) - 2) + ' ';
end;

function TAuroraRTTI<T>.Where(var aWhere: String): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldName: string;
  Attr: TCustomAttribute;
begin
  Result := Self;
  aWhere := '';
  Typ := RttiType;
  for Prop in Typ.GetProperties do
  begin
    FieldName := '';
    for Attr in Prop.GetAttributes do
      if Attr is PK then
      begin
        FieldName := PropertyFieldName(Prop);
        if FieldName = '' then FieldName := Prop.Name;
        aWhere := aWhere + System.SysUtils.Format('%s = :%s AND ', [FieldName, FieldName]);
        Break;
      end;
  end;
  if aWhere <> '' then
    aWhere := Copy(aWhere, 1, Length(aWhere) - 4) + ' ';
end;

function TAuroraRTTI<T>.Fields(var aFields: String): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldName: string;
begin
  Result := Self;
  aFields := '';
  Typ := RttiType;
  for Prop in Typ.GetProperties do
  begin
    if HasAttribute<Ignore>(Prop.GetAttributes) then
      Continue;
    FieldName := PropertyFieldName(Prop);
    if FieldName = '' then
      Continue;
    aFields := aFields + FieldName + ', ';
  end;
  if aFields <> '' then
    aFields := Copy(aFields, 1, Length(aFields) - 2) + ' ';
end;

function TAuroraRTTI<T>.FieldsInsert(var aFields: String): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldName: string;
begin
  Result := Self;
  aFields := '';
  Typ := RttiType;
  for Prop in Typ.GetProperties do
  begin
    if HasAttribute<Ignore>(Prop.GetAttributes) or HasAttribute<AutoInc>(Prop.GetAttributes) then
      Continue;
    FieldName := PropertyFieldName(Prop);
    if FieldName = '' then
      Continue;
    aFields := aFields + FieldName + ', ';
  end;
  if aFields <> '' then
    aFields := Copy(aFields, 1, Length(aFields) - 2) + ' ';
end;

function TAuroraRTTI<T>.Param(var aParam: String): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldName: string;
begin
  Result := Self;
  aParam := '';
  Typ := RttiType;
  for Prop in Typ.GetProperties do
  begin
    if HasAttribute<Ignore>(Prop.GetAttributes) or HasAttribute<AutoInc>(Prop.GetAttributes) then
      Continue;
    FieldName := PropertyFieldName(Prop);
    if FieldName = '' then
      Continue;
    aParam := aParam + ':' + FieldName + ', ';
  end;
  if aParam <> '' then
    aParam := Copy(aParam, 1, Length(aParam) - 2) + ' ';
end;

function TAuroraRTTI<T>.PrimaryKey(var aPK: String): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
begin
  Result := Self;
  aPK := '';
  Typ := RttiType;
  for Prop in Typ.GetProperties do
    for Attr in Prop.GetAttributes do
      if Attr is PK then
      begin
        aPK := PropertyFieldName(Prop);
        if aPK = '' then aPK := Prop.Name;
        Exit(Self);
      end;
end;

function TAuroraRTTI<T>.GetDataType(aCampo: String; var aType: TFieldType): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
begin
  Result := Self;
  aType := ftUnknown;
  Typ := RttiType;
  for Prop in Typ.GetProperties do
    if SameText(PropertyFieldName(Prop), aCampo) then
    begin
      case Prop.PropertyType.TypeKind of
        tkFloat: aType := ftDateTime; // assumindo DateTime
        tkString, tkUString, tkWString: aType := ftWideString;
        tkInteger: aType := ftInteger;
        tkInt64: aType := ftLargeint;
      else
        aType := ftString;
      end;
      Exit(Self);
    end;
end;

function TAuroraRTTI<T>.DataSetToEntity(aDataSet: TDataSet; var aEntity: T): iAuroraRTTI<T>;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldName: string;
  Field: TField;
  V: TValue;
begin
  Result := Self;
  if not Assigned(aEntity) then
    aEntity := T.Create;
  Typ := RttiType;
  for Prop in Typ.GetProperties do
  begin
    FieldName := PropertyFieldName(Prop);
    if FieldName = '' then
      Continue;
    Field := aDataSet.FindField(FieldName);
    if not Assigned(Field) then
      Continue;
    case Prop.PropertyType.TypeKind of
      tkInteger: V := Field.AsInteger;
      tkInt64: V := Field.AsLargeInt;
      tkFloat: V := Field.AsFloat; // DateTime também mapeado
      tkString, tkUString, tkWString: V := Field.AsString;
      tkEnumeration: V := Field.AsBoolean;
    else
      V := TValue.Empty;
    end;
    if not V.IsEmpty then
      Prop.SetValue(TObject(aEntity), V);
  end;
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