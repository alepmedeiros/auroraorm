unit AuroraJSON;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.JSON,
  System.Generics.Collections,
  System.Variants,
  AuroraAttributes,
  AuroraRTTI
  {$IFDEF USE_GBJSON}, AuroraJSON.GBJson{$ENDIF};

type
  // Utilitários de serialização JSON nativos para AuroraORM.
  // Se desejar usar GBJson, podemos incluir uma unidade adapter futuramente
  // (ex.: AuroraJSON.GBJson) e redirecionar chamadas via diretiva de compilação.
  TAuroraJSON = class
  private
    class function SanitizeString(const S: string): string; static;
  public
    // Entidade -> JSON (objeto)
    class function ToJSON<T: class, constructor>(const AEntity: T): string; static;
    class procedure ToJSON<T: class, constructor>(const AEntity: T; var AJSON: string); static;
    // Lista de entidades -> JSON (array)
    class function ToJSONArray<T: class, constructor>(const AList: TObjectList<T>): string; static;
    // JSON (objeto) -> Entidade
    class function FromJSON<T: class, constructor>(const AJSON: string): T; static;
    class procedure FromJSON<T: class, constructor>(const AJSON: string; var AEntity: T); static;
    // JSON (array) -> Lista de entidades
    class function FromJSONArray<T: class, constructor>(const AJSON: string): TObjectList<T>; static;
  end;

implementation

class function TAuroraJSON.SanitizeString(const S: string): string;
begin
  // Remove NUL chars que podem causar problemas
  Result := S.Replace(#0, '');
end;

class procedure TAuroraJSON.ToJSON<T>(const AEntity: T; var AJSON: string);
var
  Dict: TDictionary<string, Variant>;
  Obj: TJSONObject;
  PairName: string;
  V: Variant;
begin
  {$IFDEF USE_GBJSON}
  TAuroraJSONGB.ToJSON<T>(AEntity, AJSON);
  Exit;
  {$ENDIF}
  Obj := TJSONObject.Create;
  Dict := nil;
  try
    TAuroraRTTI<T>.New(AEntity).DictionaryFields(Dict);
    for PairName in Dict.Keys do
    begin
      V := Dict.Items[PairName];
      if VarIsNull(V) then
        Obj.AddPair(PairName, TJSONNull.Create)
      else if VarIsNumeric(V) then
        Obj.AddPair(PairName, TJSONNumber.Create(VarAsType(V, varDouble)))
      else if VarIsStr(V) then
        Obj.AddPair(PairName, TJSONString.Create(SanitizeString(VarToStr(V))))
      else if VarIsBool(V) then
      begin
        if VarAsType(V, varBoolean) then
          Obj.AddPair(PairName, TJSONTrue.Create)
        else
          Obj.AddPair(PairName, TJSONFalse.Create);
      end
      else
        Obj.AddPair(PairName, TJSONString.Create(VarToStr(V)));
    end;
    AJSON := Obj.ToJSON;
  finally
    Dict.Free;
    Obj.Free;
  end;
end;

class function TAuroraJSON.ToJSON<T>(const AEntity: T): string;
begin
  {$IFDEF USE_GBJSON}
  Result := TAuroraJSONGB.ToJSON<T>(AEntity);
  Exit;
  {$ENDIF}
  ToJSON<T>(AEntity, Result);
end;

class function TAuroraJSON.ToJSONArray<T>(const AList: TObjectList<T>): string;
var
  Arr: TJSONArray;
  I: Integer;
  ItemJSON: string;
begin
  {$IFDEF USE_GBJSON}
  Result := TAuroraJSONGB.ToJSONArray<T>(AList);
  Exit;
  {$ENDIF}
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

class function TAuroraJSON.FromJSON<T>(const AJSON: string): T;
begin
  {$IFDEF USE_GBJSON}
  Result := TAuroraJSONGB.FromJSON<T>(AJSON);
  Exit;
  {$ENDIF}
  Result := nil;
  FromJSON<T>(AJSON, Result);
end;

class procedure TAuroraJSON.FromJSON<T>(const AJSON: string; var AEntity: T);
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldName: string;
  Obj: TJSONObject;
  Val: TJSONValue;
  Num: TJSONNumber;
  S: string;
  Ctx: TRttiContext;
  B: Boolean;
  Attr: TCustomAttribute;
begin
  {$IFDEF USE_GBJSON}
  TAuroraJSONGB.FromJSON<T>(AJSON, AEntity);
  Exit;
  {$ENDIF}
  if not Assigned(AEntity) then
    AEntity := T.Create;

  Obj := TJSONObject.ParseJSONValue(SanitizeString(AJSON)) as TJSONObject;
  if not Assigned(Obj) then
    Exit;
  try
    Ctx := TRttiContext.Create;
    Typ := Ctx.GetType(TypeInfo(T));
    for Prop in Typ.GetProperties do
    begin
      FieldName := '';
      // pega nome do campo mapeado [Campo]
      for Attr in Prop.GetAttributes do
        if Attr is Campo then
          FieldName := Campo(Attr).Name;
      if FieldName = '' then Continue;

      Val := Obj.Values[FieldName];
      if not Assigned(Val) then Continue;

      case Prop.PropertyType.TypeKind of
        tkInteger:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              Prop.SetValue(TObject(AEntity), Num.AsInt);
            end;
          end;
        tkInt64:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              Prop.SetValue(TObject(AEntity), Round(Num.AsDouble));
            end;
          end;
        tkFloat:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              Prop.SetValue(TObject(AEntity), Num.AsDouble);
            end
            else if Val is TJSONString then
            begin
              // permite parse de datas como ISO 8601 se vier em string
              S := TJSONString(Val).Value;
              // se necessário, você pode aplicar um parser de data aqui
              // por ora, mantém como string/float conforme tipo da propriedade
            end;
          end;
        tkString, tkUString, tkWString:
          begin
            if Val is TJSONString then
              Prop.SetValue(TObject(AEntity), TJSONString(Val).Value)
            else
              Prop.SetValue(TObject(AEntity), Val.ToString);
          end;
        tkEnumeration:
          begin
            if Val is TJSONTrue then B := True
            else if Val is TJSONFalse then B := False
            else if Val is TJSONString then B := SameText(TJSONString(Val).Value, 'true')
            else B := Val.ToString = 'true';
            Prop.SetValue(TObject(AEntity), B);
          end;
      end;
    end;
  finally
    Obj.Free;
  end;
end;

class function TAuroraJSON.FromJSONArray<T>(const AJSON: string): TObjectList<T>;
var
  Val: TJSONValue;
  Arr: TJSONArray;
  I: Integer;
  ItemObj: TJSONObject;
  Item: T;
begin
  {$IFDEF USE_GBJSON}
  Result := TAuroraJSONGB.FromJSONArray<T>(AJSON);
  Exit;
  {$ENDIF}
  Result := TObjectList<T>.Create(True);
  Val := TJSONObject.ParseJSONValue(SanitizeString(AJSON));
  if not Assigned(Val) then Exit;
  try
    Arr := Val as TJSONArray;
    for I := 0 to Arr.Count - 1 do
    begin
      ItemObj := Arr.Items[I] as TJSONObject;
      Item := FromJSON<T>(ItemObj.ToJSON);
      Result.Add(Item);
    end;
  finally
    Val.Free;
  end;
end;

end.