unit AuroraMetadata;

{
  Modelo de metadados de entidade cacheado.

  RTTI e reflexao sobre atributos sao relativamente caros e, antes desta unit,
  eram refeitos em toda chamada de Insert/Update/Delete/Find (TAuroraRTTI<T>.New(nil)
  descartavel a cada operacao). Aqui o scan e feito uma unica vez por classe de
  entidade (analogo ao metamodel/SessionFactory do Hibernate) e o resultado fica
  cacheado em TAuroraMetadataRegistry para toda a vida do processo.

  Tambem e o unico lugar onde os atributos de relacionamento (HasOne/BelongsTo/
  HasMany/BelongsToMany) sao interpretados - antes eram declarados em
  AuroraAttributes.pas mas nunca lidos por nenhuma unit.
}

interface

uses
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  System.Generics.Collections,
  System.Generics.Defaults,
  Data.DB,
  AuroraAttributes;

type
  TAuroraRelationKind = (rkHasOne, rkBelongsTo, rkHasMany, rkBelongsToMany);

  // Representa um campo mapeado, seja via property published ([Campo] em property)
  // ou via field privado ([Campo] direto no field) - ambos os estilos existem no
  // codebase atual (ver AuroraDAO/AuroraRTTI originais).
  TAuroraFieldMeta = class
  private
    FRttiProp: TRttiProperty;
    FRttiField: TRttiField;
  public
    PropName: string;
    FieldName: string;
    IsPK: Boolean;
    IsAutoInc: Boolean;
    IsVersion: Boolean;
    IsIgnore: Boolean;
    IsNotNull: Boolean;
    IsUnique: Boolean;
    IsBlob: Boolean;
    IsNumberOnly: Boolean;
    IsEmail: Boolean;
    IsJsonIgnore: Boolean;
    JsonName: string;
    HasIndex: Boolean;
    IndexName: string;
    HasFK: Boolean;
    FKTable: string;
    FKColumn: string;
    HasFormat: Boolean;
    FormatMaxSize: Integer;
    FormatMinSize: Integer;
    FormatPrecision: Integer;
    FormatMask: string;
    DisplayName: string;
    constructor CreateFromProperty(aProp: TRttiProperty);
    constructor CreateFromField(aField: TRttiField);
    function TypeKind: TTypeKind;
    function RttiType: TRttiType;
    function GetValue(aInstance: TObject): TValue;
    procedure SetValue(aInstance: TObject; const aValue: TValue);
    // Nome usado na serializacao JSON: JsonCampo > Campo > nome da property/field.
    function ResolvedJsonName: string;
  end;

  TAuroraRelationMeta = class
  public
    Kind: TAuroraRelationKind;
    PropName: string;
    RttiProp: TRttiProperty;
    EntityName: string;
    LocalKey: string;
    ForeignKey: string;
    JoinTable: string;
    // Resolucao de TClass e preguicosa (evita depender de ordem de inicializacao
    // entre entidades que se referenciam mutuamente).
    function ResolveTargetClass: TClass;
  end;

  TAuroraEntityMeta = class
  private
    FFields: TObjectList<TAuroraFieldMeta>;
    FRelations: TObjectList<TAuroraRelationMeta>;
    FFieldsByColumn: TDictionary<string, TAuroraFieldMeta>;
    FFieldsByProp: TDictionary<string, TAuroraFieldMeta>;
  public
    EntityClass: TClass;
    RttiType: TRttiType;
    TableName: string;
    PKFields: TArray<TAuroraFieldMeta>;
    VersionField: TAuroraFieldMeta; // nil quando a entidade nao usa [Version]
    constructor Create;
    destructor Destroy; override;
    function PrimaryPK: TAuroraFieldMeta;
    function IsCompositeKey: Boolean;
    function FieldByProp(const aName: string): TAuroraFieldMeta;
    function FieldByColumn(const aName: string): TAuroraFieldMeta;
    function InsertableFields: TArray<TAuroraFieldMeta>;
    function UpdatableFields: TArray<TAuroraFieldMeta>;
    property Fields: TObjectList<TAuroraFieldMeta> read FFields;
    property Relations: TObjectList<TAuroraRelationMeta> read FRelations;
  end;

  TAuroraMetadataRegistry = class
  private
    class var FCacheByType: TObjectDictionary<Pointer, TAuroraEntityMeta>;
    class var FCacheByClassName: TDictionary<string, TAuroraEntityMeta>;
    class function Build(aTypeInfo: PTypeInfo): TAuroraEntityMeta; static;
    class function TableNameConvention(const aClassName: string): string; static;
    class function BaseNameConvention(const aClassName: string): string; static;
  public
    class constructor Create;
    class destructor Destroy;
    class function GetOrBuild<T: class>: TAuroraEntityMeta; static;
    class function GetOrBuildByTypeInfo(aTypeInfo: PTypeInfo): TAuroraEntityMeta; static;
    class function TryGetByClassName(const aClassName: string; out aMeta: TAuroraEntityMeta): Boolean; static;
    // Uso em testes: limpa o cache para isolar cenarios entre casos de teste.
    class procedure Clear; static;
  end;

// Mapeia a linha atual de um DataSet para uma instancia ja existente, usando os
// campos descritos no metadado. Generic-free por design: e o que permite montar
// o lado "alvo" de um relacionamento (HasOne/BelongsTo) a partir apenas de um
// TClass resolvido em tempo de execucao, sem precisar de um parametro generico.
procedure AuroraMapDataSetIntoInstance(aMeta: TAuroraEntityMeta; aDataSet: TDataSet; aInstance: TObject);

// Cria a instancia (via construtor virtual TObject.Create) e ja mapeia a linha atual.
function AuroraMapDataSetToInstance(aMeta: TAuroraEntityMeta; aDataSet: TDataSet): TObject;

implementation

{ TAuroraFieldMeta }

constructor TAuroraFieldMeta.CreateFromProperty(aProp: TRttiProperty);
var
  Attr: TCustomAttribute;
  Fmt: Format;
  FkAttr: FK;
  Idx: Index;
  Jc: JsonCampo;
  Disp: Display;
begin
  inherited Create;
  FRttiProp := aProp;
  FRttiField := nil;
  PropName := aProp.Name;
  FieldName := '';
  for Attr in aProp.GetAttributes do
  begin
    if Attr is Campo then
      FieldName := Campo(Attr).Name
    else if Attr is PK then
      IsPK := True
    else if Attr is AutoInc then
      IsAutoInc := True
    else if Attr is Version then
      IsVersion := True
    else if Attr is Ignore then
      IsIgnore := True
    else if Attr is NotNull then
      IsNotNull := True
    else if Attr is Unique then
      IsUnique := True
    else if Attr is Blob then
      IsBlob := True
    else if Attr is NumberOnly then
      IsNumberOnly := True
    else if Attr is Email then
      IsEmail := True
    else if Attr is JsonIgnore then
      IsJsonIgnore := True
    else if Attr is JsonCampo then
    begin
      Jc := JsonCampo(Attr);
      JsonName := Jc.Name;
    end
    else if Attr is Index then
    begin
      Idx := Index(Attr);
      HasIndex := True;
      IndexName := Idx.Name;
    end
    else if Attr is FK then
    begin
      FkAttr := FK(Attr);
      HasFK := True;
      FKTable := FkAttr.Table;
      FKColumn := FkAttr.Column;
    end
    else if Attr is Format then
    begin
      Fmt := Format(Attr);
      HasFormat := True;
      FormatMaxSize := Fmt.MaxSize;
      FormatMinSize := Fmt.MinSize;
      FormatPrecision := Fmt.Precision;
      FormatMask := Fmt.Mask;
    end
    else if Attr is Display then
    begin
      Disp := Display(Attr);
      DisplayName := Disp.Name;
    end;
  end;
  if FieldName = '' then
    FieldName := PropName;
end;

constructor TAuroraFieldMeta.CreateFromField(aField: TRttiField);
var
  Attr: TCustomAttribute;
  Fmt: Format;
  FkAttr: FK;
  Idx: Index;
  Jc: JsonCampo;
  Disp: Display;
begin
  inherited Create;
  FRttiProp := nil;
  FRttiField := aField;
  PropName := aField.Name;
  FieldName := '';
  for Attr in aField.GetAttributes do
  begin
    if Attr is Campo then
      FieldName := Campo(Attr).Name
    else if Attr is PK then
      IsPK := True
    else if Attr is AutoInc then
      IsAutoInc := True
    else if Attr is Version then
      IsVersion := True
    else if Attr is Ignore then
      IsIgnore := True
    else if Attr is NotNull then
      IsNotNull := True
    else if Attr is Unique then
      IsUnique := True
    else if Attr is Blob then
      IsBlob := True
    else if Attr is NumberOnly then
      IsNumberOnly := True
    else if Attr is Email then
      IsEmail := True
    else if Attr is JsonIgnore then
      IsJsonIgnore := True
    else if Attr is JsonCampo then
    begin
      Jc := JsonCampo(Attr);
      JsonName := Jc.Name;
    end
    else if Attr is Index then
    begin
      Idx := Index(Attr);
      HasIndex := True;
      IndexName := Idx.Name;
    end
    else if Attr is FK then
    begin
      FkAttr := FK(Attr);
      HasFK := True;
      FKTable := FkAttr.Table;
      FKColumn := FkAttr.Column;
    end
    else if Attr is Format then
    begin
      Fmt := Format(Attr);
      HasFormat := True;
      FormatMaxSize := Fmt.MaxSize;
      FormatMinSize := Fmt.MinSize;
      FormatPrecision := Fmt.Precision;
      FormatMask := Fmt.Mask;
    end
    else if Attr is Display then
    begin
      Disp := Display(Attr);
      DisplayName := Disp.Name;
    end;
  end;
  if FieldName = '' then
    FieldName := PropName;
end;

function TAuroraFieldMeta.TypeKind: TTypeKind;
begin
  Result := RttiType.TypeKind;
end;

function TAuroraFieldMeta.RttiType: TRttiType;
begin
  if Assigned(FRttiProp) then
    Result := FRttiProp.PropertyType
  else
    Result := FRttiField.FieldType;
end;

function TAuroraFieldMeta.GetValue(aInstance: TObject): TValue;
begin
  if Assigned(FRttiProp) then
    Result := FRttiProp.GetValue(aInstance)
  else
    Result := FRttiField.GetValue(aInstance);
end;

procedure TAuroraFieldMeta.SetValue(aInstance: TObject; const aValue: TValue);
begin
  if Assigned(FRttiProp) then
    FRttiProp.SetValue(aInstance, aValue)
  else
    FRttiField.SetValue(aInstance, aValue);
end;

function TAuroraFieldMeta.ResolvedJsonName: string;
begin
  if JsonName <> '' then
    Result := JsonName
  else
    Result := FieldName;
end;

{ TAuroraRelationMeta }

function TAuroraRelationMeta.ResolveTargetClass: TClass;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
begin
  Result := nil;
  Ctx := TRttiContext.Create;
  Typ := Ctx.FindType(EntityName);
  if (Typ = nil) and (Length(EntityName) > 0) and (EntityName[1] <> 'T') then
    Typ := Ctx.FindType('T' + EntityName);
  if Assigned(Typ) and (Typ is TRttiInstanceType) then
    Result := TRttiInstanceType(Typ).MetaclassType;
end;

{ TAuroraEntityMeta }

constructor TAuroraEntityMeta.Create;
begin
  inherited Create;
  FFields := TObjectList<TAuroraFieldMeta>.Create(True);
  FRelations := TObjectList<TAuroraRelationMeta>.Create(True);
  FFieldsByColumn := TDictionary<string, TAuroraFieldMeta>.Create(TIStringComparer.Ordinal);
  FFieldsByProp := TDictionary<string, TAuroraFieldMeta>.Create(TIStringComparer.Ordinal);
end;

destructor TAuroraEntityMeta.Destroy;
begin
  FFieldsByColumn.Free;
  FFieldsByProp.Free;
  FRelations.Free;
  FFields.Free;
  inherited;
end;

function TAuroraEntityMeta.PrimaryPK: TAuroraFieldMeta;
begin
  if Length(PKFields) > 0 then
    Result := PKFields[0]
  else
    Result := nil;
end;

function TAuroraEntityMeta.IsCompositeKey: Boolean;
begin
  Result := Length(PKFields) > 1;
end;

function TAuroraEntityMeta.FieldByProp(const aName: string): TAuroraFieldMeta;
begin
  if not FFieldsByProp.TryGetValue(aName, Result) then
    Result := nil;
end;

function TAuroraEntityMeta.FieldByColumn(const aName: string): TAuroraFieldMeta;
begin
  if not FFieldsByColumn.TryGetValue(aName, Result) then
    Result := nil;
end;

function TAuroraEntityMeta.InsertableFields: TArray<TAuroraFieldMeta>;
var
  F: TAuroraFieldMeta;
  L: TList<TAuroraFieldMeta>;
begin
  L := TList<TAuroraFieldMeta>.Create;
  try
    for F in FFields do
      if not (F.IsIgnore or F.IsAutoInc) then
        L.Add(F);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

function TAuroraEntityMeta.UpdatableFields: TArray<TAuroraFieldMeta>;
var
  F: TAuroraFieldMeta;
  L: TList<TAuroraFieldMeta>;
begin
  L := TList<TAuroraFieldMeta>.Create;
  try
    for F in FFields do
      if not (F.IsIgnore or F.IsAutoInc or F.IsPK) then
        L.Add(F);
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

{ TAuroraMetadataRegistry }

class constructor TAuroraMetadataRegistry.Create;
begin
  FCacheByType := TObjectDictionary<Pointer, TAuroraEntityMeta>.Create([doOwnsValues]);
  FCacheByClassName := TDictionary<string, TAuroraEntityMeta>.Create(TIStringComparer.Ordinal);
end;

class destructor TAuroraMetadataRegistry.Destroy;
begin
  FCacheByClassName.Free;
  FCacheByType.Free;
end;

class procedure TAuroraMetadataRegistry.Clear;
begin
  TMonitor.Enter(FCacheByType);
  try
    FCacheByType.Clear;
    FCacheByClassName.Clear;
  finally
    TMonitor.Exit(FCacheByType);
  end;
end;

class function TAuroraMetadataRegistry.BaseNameConvention(const aClassName: string): string;
var
  Base: string;
begin
  Base := aClassName;
  if (Length(Base) > 0) and (Base[1] = 'T') then
    Base := Copy(Base, 2, Length(Base) - 1);
  Result := LowerCase(Base);
end;

class function TAuroraMetadataRegistry.TableNameConvention(const aClassName: string): string;
var
  Base: string;
begin
  Base := BaseNameConvention(aClassName);
  if Base = '' then
    Result := LowerCase(aClassName)
  else if Base[Length(Base)] <> 's' then
    Result := Base + 's'
  else
    Result := Base;
end;

class function TAuroraMetadataRegistry.Build(aTypeInfo: PTypeInfo): TAuroraEntityMeta;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldRtti: TRttiField;
  Attr: TCustomAttribute;
  Meta: TAuroraEntityMeta;
  FieldMeta: TAuroraFieldMeta;
  RelMeta: TAuroraRelationMeta;
  PKList: TList<TAuroraFieldMeta>;
  Rel: Relationship;
  Kind: TAuroraRelationKind;
  PkMeta: TAuroraFieldMeta;
begin
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(aTypeInfo);
  Meta := TAuroraEntityMeta.Create;
  Meta.RttiType := Typ;
  if Typ is TRttiInstanceType then
    Meta.EntityClass := TRttiInstanceType(Typ).MetaclassType
  else
    Meta.EntityClass := nil;

  Meta.TableName := '';
  for Attr in Typ.GetAttributes do
    if Attr is Tabela then
      Meta.TableName := Tabela(Attr).Name;
  if Meta.TableName = '' then
    Meta.TableName := TableNameConvention(Typ.Name);

  PKList := TList<TAuroraFieldMeta>.Create;
  try
    // Fields privados primeiro (estilo "headless": [Campo] no field, property e so
    // um passthrough "read FX write FX" sem atributos proprios - ex.: TUser do
    // sample AuroraHeadless). Precisa vir antes do loop de properties para que a
    // property correspondente possa ser detectada como alias em vez de gerar uma
    // segunda entrada (errada, sem o nome de coluna real) para o mesmo campo.
    for FieldRtti in Typ.GetFields do
    begin
      FieldMeta := nil;
      for Attr in FieldRtti.GetAttributes do
        if Attr is Campo then
        begin
          FieldMeta := TAuroraFieldMeta.CreateFromField(FieldRtti);
          Break;
        end;
      if not Assigned(FieldMeta) then
        Continue;
      Meta.FFields.Add(FieldMeta);
      Meta.FFieldsByProp.AddOrSetValue(FieldMeta.PropName, FieldMeta);
      Meta.FFieldsByColumn.AddOrSetValue(FieldMeta.FieldName, FieldMeta);
      if FieldMeta.IsPK then
        PKList.Add(FieldMeta);
    end;

    for Prop in Typ.GetProperties do
    begin
      // Propriedades herdadas de TObject (ex.: RefCount em TInterfacedObject) nao sao campos.
      if not Prop.IsWritable then
        Continue;

      // Property e so um alias para um field ja mapeado acima (ex.: property Id
      // read FId write FId, com [Campo] em FId) - reusa o mesmo TAuroraFieldMeta
      // em vez de criar uma entrada duplicada com o nome da property.
      if Meta.FFieldsByProp.TryGetValue('F' + Prop.Name, FieldMeta) then
      begin
        Meta.FFieldsByProp.AddOrSetValue(Prop.Name, FieldMeta);
        Continue;
      end;

      FieldMeta := TAuroraFieldMeta.CreateFromProperty(Prop);
      Meta.FFields.Add(FieldMeta);
      Meta.FFieldsByProp.AddOrSetValue(FieldMeta.PropName, FieldMeta);
      Meta.FFieldsByColumn.AddOrSetValue(FieldMeta.FieldName, FieldMeta);
      if FieldMeta.IsPK then
        PKList.Add(FieldMeta);

      for Attr in Prop.GetAttributes do
        if Attr is Relationship then
        begin
          Rel := Relationship(Attr);
          if Rel is HasOne then Kind := rkHasOne
          else if Rel is BelongsTo then Kind := rkBelongsTo
          else if Rel is HasMany then Kind := rkHasMany
          else if Rel is BelongsToMany then Kind := rkBelongsToMany
          else Continue;
          RelMeta := TAuroraRelationMeta.Create;
          RelMeta.Kind := Kind;
          RelMeta.PropName := Prop.Name;
          RelMeta.RttiProp := Prop;
          RelMeta.EntityName := Rel.EntityName;
          RelMeta.LocalKey := Rel.LocalKey;
          RelMeta.ForeignKey := Rel.ForeignKey;
          RelMeta.JoinTable := Rel.JoinTable;
          Meta.FRelations.Add(RelMeta);
        end;
    end;

    Meta.PKFields := PKList.ToArray;
  finally
    PKList.Free;
  end;

  Meta.VersionField := nil;
  for FieldMeta in Meta.FFields do
    if FieldMeta.IsVersion then
    begin
      Meta.VersionField := FieldMeta;
      Break;
    end;

  // Convencao de LocalKey/ForeignKey quando nao informados explicitamente no atributo.
  for RelMeta in Meta.FRelations do
  begin
    case RelMeta.Kind of
      rkHasOne, rkHasMany:
        begin
          if RelMeta.LocalKey = '' then
          begin
            PkMeta := Meta.PrimaryPK;
            if Assigned(PkMeta) then
              RelMeta.LocalKey := PkMeta.FieldName
            else
              RelMeta.LocalKey := 'id';
          end;
          if RelMeta.ForeignKey = '' then
            RelMeta.ForeignKey := BaseNameConvention(Typ.Name) + '_id';
        end;
      rkBelongsTo, rkBelongsToMany:
        begin
          if RelMeta.LocalKey = '' then
            RelMeta.LocalKey := BaseNameConvention(RelMeta.EntityName) + '_id';
          if RelMeta.ForeignKey = '' then
            RelMeta.ForeignKey := 'id';
        end;
    end;
  end;

  Result := Meta;
end;

class function TAuroraMetadataRegistry.GetOrBuildByTypeInfo(aTypeInfo: PTypeInfo): TAuroraEntityMeta;
begin
  TMonitor.Enter(FCacheByType);
  try
    if not FCacheByType.TryGetValue(aTypeInfo, Result) then
    begin
      Result := Build(aTypeInfo);
      FCacheByType.Add(aTypeInfo, Result);
      FCacheByClassName.AddOrSetValue(Result.RttiType.Name, Result);
    end;
  finally
    TMonitor.Exit(FCacheByType);
  end;
end;

class function TAuroraMetadataRegistry.GetOrBuild<T>: TAuroraEntityMeta;
begin
  Result := GetOrBuildByTypeInfo(TypeInfo(T));
end;

class function TAuroraMetadataRegistry.TryGetByClassName(const aClassName: string; out aMeta: TAuroraEntityMeta): Boolean;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Name: string;
begin
  TMonitor.Enter(FCacheByType);
  try
    Result := FCacheByClassName.TryGetValue(aClassName, aMeta);
  finally
    TMonitor.Exit(FCacheByType);
  end;
  if Result then Exit;

  Name := aClassName;
  Ctx := TRttiContext.Create;
  Typ := Ctx.FindType(Name);
  if (Typ = nil) and (Length(Name) > 0) and (Name[1] <> 'T') then
    Typ := Ctx.FindType('T' + Name);
  if not Assigned(Typ) then
  begin
    aMeta := nil;
    Result := False;
    Exit;
  end;
  aMeta := GetOrBuildByTypeInfo(Typ.Handle);
  Result := True;
end;

procedure AuroraMapDataSetIntoInstance(aMeta: TAuroraEntityMeta; aDataSet: TDataSet; aInstance: TObject);
var
  F: TAuroraFieldMeta;
  Field: TField;
  V: TValue;
begin
  for F in aMeta.Fields do
  begin
    Field := aDataSet.FindField(F.FieldName);
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
      F.SetValue(aInstance, V);
  end;
end;

function AuroraMapDataSetToInstance(aMeta: TAuroraEntityMeta; aDataSet: TDataSet): TObject;
begin
  Result := aMeta.EntityClass.Create;
  try
    AuroraMapDataSetIntoInstance(aMeta, aDataSet, Result);
  except
    Result.Free;
    raise;
  end;
end;

end.
