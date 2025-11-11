unit AuroraJSON.GBJson;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.JSON,
  System.Generics.Collections,
  AuroraRTTI,
  AuroraAttributes,
  GBJSON.Helper,
  GBJSON.Config;

type
  // Adapter para usar GBJSON por baixo, mantendo chaves conforme [Campo]
  TAuroraJSONGB = class
  private
    class function PropToCampoMap<T: class, constructor>: TDictionary<string, string>; static;
    class function CampoToPropMap<T: class, constructor>: TDictionary<string, string>; static;
    class function TransformKeys(const Src: TJSONObject; const Map: TDictionary<string, string>): TJSONObject; static;
  public
    class procedure ToJSON<T: class, constructor>(const AEntity: T; var AJSON: string); static;
    class function ToJSON<T: class, constructor>(const AEntity: T): string; static;
    class function ToJSONArray<T: class, constructor>(const AList: TObjectList<T>): string; static;
    class procedure FromJSON<T: class, constructor>(const AJSON: string; var AEntity: T); static;
    class function FromJSON<T: class, constructor>(const AJSON: string): T; static;
    class function FromJSONArray<T: class, constructor>(const AJSON: string): TObjectList<T>; static;
  end;

implementation

class function TAuroraJSONGB.PropToCampoMap<T>: TDictionary<string, string>;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  CampoName: string;
begin
  Result := TDictionary<string, string>.Create;
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(TypeInfo(T));
  for Prop in Typ.GetProperties do
  begin
    CampoName := '';
    for Attr in Prop.GetAttributes do
      if Attr is Campo then
        CampoName := Campo(Attr).Name;
    if CampoName <> '' then
      Result.AddOrSetValue(Prop.Name.ToLower, CampoName);
  end;
end;

class function TAuroraJSONGB.CampoToPropMap<T>: TDictionary<string, string>;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  CampoName: string;
begin
  Result := TDictionary<string, string>.Create;
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(TypeInfo(T));
  for Prop in Typ.GetProperties do
  begin
    CampoName := '';
    for Attr in Prop.GetAttributes do
      if Attr is Campo then
        CampoName := Campo(Attr).Name;
    if CampoName <> '' then
      Result.AddOrSetValue(CampoName.ToLower, Prop.Name);
  end;
end;

class function TAuroraJSONGB.TransformKeys(const Src: TJSONObject; const Map: TDictionary<string, string>): TJSONObject;
var
  Pair: TJSONPair;
  KeyLower, NewKey: string;
begin
  Result := TJSONObject.Create;
  for Pair in Src do
  begin
    KeyLower := Pair.JsonString.Value.ToLower;
    if Map.TryGetValue(KeyLower, NewKey) then
      Result.AddPair(NewKey, Pair.JsonValue.Clone as TJSONValue)
    else
      Result.AddPair(Pair.JsonString.Value, Pair.JsonValue.Clone as TJSONValue);
  end;
end;

class procedure TAuroraJSONGB.ToJSON<T>(const AEntity: T; var AJSON: string);
var
  Raw: string;
  Obj, ObjOut: TJSONObject;
  Map: TDictionary<string, string>; // prop -> campo
begin
  // Usa GBJSON para gerar JSON de propriedades
  Raw := AEntity.ToJSONString;
  Obj := TJSONObject.ParseJSONValue(Raw) as TJSONObject;
  Map := PropToCampoMap<T>;
  try
    if Assigned(Obj) then
    begin
      ObjOut := TransformKeys(Obj, Map);
      try
        AJSON := ObjOut.ToJSON;
      finally
        ObjOut.Free;
      end;
    end
    else
      AJSON := Raw;
  finally
    Map.Free;
    Obj.Free;
  end;
end;

class function TAuroraJSONGB.ToJSON<T>(const AEntity: T): string;
begin
  ToJSON<T>(AEntity, Result);
end;

class function TAuroraJSONGB.ToJSONArray<T>(const AList: TObjectList<T>): string;
var
  Arr: TJSONArray;
  I: Integer;
  ItemJSON: string;
begin
  Arr := TJSONArray.Create;
  try
    if Assigned(AList) then
      for I := 0 to AList.Count - 1 do
      begin
        ItemJSON := ToJSON<T>(AList.Items[I]);
        Arr.Add(TJSONObject.ParseJSONValue(ItemJSON) as TJSONObject);
      end;
    Result := Arr.ToJSON;
  finally
    Arr.Free;
  end;
end;

class procedure TAuroraJSONGB.FromJSON<T>(const AJSON: string; var AEntity: T);
var
  ObjIn, ObjProp: TJSONObject;
  Map: TDictionary<string, string>; // campo -> prop
begin
  if not Assigned(AEntity) then
    AEntity := T.Create;
  ObjIn := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  if not Assigned(ObjIn) then Exit;
  Map := CampoToPropMap<T>;
  try
    ObjProp := TransformKeys(ObjIn, Map);
    try
      AEntity.FromJSONObject(ObjProp);
    finally
      ObjProp.Free;
    end;
  finally
    Map.Free;
    ObjIn.Free;
  end;
end;

class function TAuroraJSONGB.FromJSON<T>(const AJSON: string): T;
begin
  Result := nil;
  FromJSON<T>(AJSON, Result);
end;

class function TAuroraJSONGB.FromJSONArray<T>(const AJSON: string): TObjectList<T>;
var
  Val: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  ItemObj: TJSONObject;
  Item: T;
begin
  Result := TObjectList<T>.Create(True);
  Val := TJSONObject.ParseJSONValue(AJSON);
  if not Assigned(Val) then Exit;
  try
    Arr := Val as TJSONArray;
    for I := 0 to Arr.Count - 1 do
    begin
      ItemObj := Arr.Items[I] as TJSONObject;
      Item := T.Create;
      Item.FromJSONObject(ItemObj);
      Result.Add(Item);
    end;
  finally
    Val.Free;
  end;
end;

end.