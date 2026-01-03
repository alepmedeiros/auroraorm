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
    // Helpers para resolver nome e visibilidade no JSON a partir de atributos
    class function GetJSONFieldNameFromProp(const Prop: TRttiProperty; out AName: string; const IncludeAutoInc, IncludeWithoutCampo: Boolean): Boolean; static;
    class function GetJSONFieldNameFromField(const FieldRtti: TRttiField; out AName: string; const IncludeAutoInc, IncludeWithoutCampo: Boolean): Boolean; static;
  public
    // Entidade -> JSON (objeto)
    class function ToJSON<T: class, constructor>(const AEntity: T): string; static;
    // Versão configurável: controla inclusão de AutoInc e de membros sem [Campo]
    class function ToJSONWithOptions<T: class, constructor>(const AEntity: T; const IncludeAutoInc: Boolean = False; const IncludeNulls: Boolean = True; const IncludeWithoutCampo: Boolean = False): string; static;
    // Lista de entidades -> JSON (array)
    class function ToJSONArray<T: class, constructor>(const AList: TObjectList<T>): string; static;
    // Versão configurável para arrays
    class function ToJSONArrayWithOptions<T: class, constructor>(const AList: TObjectList<T>; const IncludeAutoInc: Boolean = False; const IncludeNulls: Boolean = True; const IncludeWithoutCampo: Boolean = False): string; static;
    // JSON (objeto) -> Entidade
    class function FromJSON<T: class, constructor>(const AJSON: string): T; static;
    // Versão configurável: controla se aceita nomes sem [Campo] e atribuição em AutoInc
    class function FromJSONWithOptions<T: class, constructor>(const AJSON: string; const AcceptWithoutCampo: Boolean = False; const AllowAutoIncAssign: Boolean = False): T; static;
    // JSON (array) -> Lista de entidades
    class function FromJSONArray<T: class, constructor>(const AJSON: string): TObjectList<T>; static;
  end;

implementation

class function TAuroraJSON.SanitizeString(const S: string): string;
begin
  // Remove NUL chars que podem causar problemas
  Result := S.Replace(#0, '');
end;

class function TAuroraJSON.GetJSONFieldNameFromProp(const Prop: TRttiProperty; out AName: string; const IncludeAutoInc, IncludeWithoutCampo: Boolean): Boolean;
var
  Attr: TCustomAttribute;
  HasIgnore, HasAutoInc: Boolean;
begin
  Result := False;
  AName := '';
  HasIgnore := False;
  HasAutoInc := False;
  for Attr in Prop.GetAttributes do
  begin
    if Attr is JsonIgnore then HasIgnore := True;
    if Attr is AutoInc then HasAutoInc := True;
    if (AName = '') and (Attr is JsonCampo) then AName := JsonCampo(Attr).Name;
    if (AName = '') and (Attr is Campo) then AName := Campo(Attr).Name;
  end;
  if HasIgnore then Exit(False);
  if HasAutoInc and not IncludeAutoInc then Exit(False);
  if AName = '' then
  begin
    if IncludeWithoutCampo then
      AName := Prop.Name
    else
      Exit(False);
  end;
  Result := True;
end;

class function TAuroraJSON.GetJSONFieldNameFromField(const FieldRtti: TRttiField; out AName: string; const IncludeAutoInc, IncludeWithoutCampo: Boolean): Boolean;
var
  Attr: TCustomAttribute;
  HasIgnore, HasAutoInc: Boolean;
begin
  Result := False;
  AName := '';
  HasIgnore := False;
  HasAutoInc := False;
  for Attr in FieldRtti.GetAttributes do
  begin
    if Attr is JsonIgnore then HasIgnore := True;
    if Attr is AutoInc then HasAutoInc := True;
    if (AName = '') and (Attr is JsonCampo) then AName := JsonCampo(Attr).Name;
    if (AName = '') and (Attr is Campo) then AName := Campo(Attr).Name;
  end;
  if HasIgnore then Exit(False);
  if HasAutoInc and not IncludeAutoInc then Exit(False);
  if AName = '' then
  begin
    if IncludeWithoutCampo then
      AName := FieldRtti.Name
    else
      Exit(False);
  end;
  Result := True;
end;

class function TAuroraJSON.ToJSON<T>(const AEntity: T): string;
var
  Dict: TDictionary<string, Variant>;
  Obj: TJSONObject;
  PairName: string;
  V: Variant;
  NumExt: Extended;
begin
  {$IFDEF USE_GBJSON}
  Result := TAuroraJSONGB.ToJSON<T>(AEntity);
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
      begin
        NumExt := VarAsType(V, varDouble);
        Obj.AddPair(PairName, TJSONNumber.Create(NumExt));
      end
      else if VarIsStr(V) then
        Obj.AddPair(PairName, TJSONString.Create(SanitizeString(VarToStr(V))))
      else if VarIsType(V, varBoolean) then
      begin
        if VarAsType(V, varBoolean) then
          Obj.AddPair(PairName, TJSONTrue.Create)
        else
          Obj.AddPair(PairName, TJSONFalse.Create);
      end
      else
        Obj.AddPair(PairName, TJSONString.Create(VarToStr(V)));
    end;
    Result := Obj.ToJSON;
  finally
    Dict.Free;
    Obj.Free;
  end;
end;

// (removido overload procedure; função acima contém a implementação)

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

class function TAuroraJSON.ToJSONWithOptions<T>(const AEntity: T; const IncludeAutoInc, IncludeNulls, IncludeWithoutCampo: Boolean): string;
var
  Obj: TJSONObject;
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldRtti: TRttiField;
  Name: string;
  V: TValue;
  NumExt: Extended;
begin
  {$IFDEF USE_GBJSON}
  Result := TAuroraJSONGB.ToJSON<T>(AEntity);
  Exit;
  {$ENDIF}
  Obj := TJSONObject.Create;
  try
    Ctx := TRttiContext.Create;
    Typ := Ctx.GetType(TypeInfo(T));
    // Propriedades
    for Prop in Typ.GetProperties do
    begin
      if not GetJSONFieldNameFromProp(Prop, Name, IncludeAutoInc, IncludeWithoutCampo) then Continue;
      if Assigned(AEntity) then
        V := Prop.GetValue(TObject(AEntity))
      else
        V := TValue.Empty;
      if V.IsEmpty or VarIsNull(V.AsVariant) then
      begin
        if IncludeNulls then
          Obj.AddPair(Name, TJSONNull.Create);
        Continue;
      end;
      if VarIsNumeric(V.AsVariant) then
      begin
        NumExt := VarAsType(V.AsVariant, varDouble);
        Obj.AddPair(Name, TJSONNumber.Create(NumExt));
      end
      else if VarIsStr(V.AsVariant) then
        Obj.AddPair(Name, TJSONString.Create(SanitizeString(V.ToString)))
      else if VarIsType(V.AsVariant, varBoolean) then
      begin
        if VarAsType(V.AsVariant, varBoolean) then
          Obj.AddPair(Name, TJSONTrue.Create)
        else
          Obj.AddPair(Name, TJSONFalse.Create);
      end
      else
        Obj.AddPair(Name, TJSONString.Create(V.ToString));
    end;
    // Fields privados
    for FieldRtti in Typ.GetFields do
    begin
      if not GetJSONFieldNameFromField(FieldRtti, Name, IncludeAutoInc, IncludeWithoutCampo) then Continue;
      if Assigned(AEntity) then
        V := FieldRtti.GetValue(TObject(AEntity))
      else
        V := TValue.Empty;
      if V.IsEmpty or VarIsNull(V.AsVariant) then
      begin
        if IncludeNulls then
          Obj.AddPair(Name, TJSONNull.Create);
        Continue;
      end;
      if VarIsNumeric(V.AsVariant) then
      begin
        NumExt := VarAsType(V.AsVariant, varDouble);
        Obj.AddPair(Name, TJSONNumber.Create(NumExt));
      end
      else if VarIsStr(V.AsVariant) then
        Obj.AddPair(Name, TJSONString.Create(SanitizeString(V.ToString)))
      else if VarIsType(V.AsVariant, varBoolean) then
      begin
        if VarAsType(V.AsVariant, varBoolean) then
          Obj.AddPair(Name, TJSONTrue.Create)
        else
          Obj.AddPair(Name, TJSONFalse.Create);
      end
      else
        Obj.AddPair(Name, TJSONString.Create(V.ToString));
    end;
    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

class function TAuroraJSON.ToJSONArrayWithOptions<T>(const AList: TObjectList<T>; const IncludeAutoInc, IncludeNulls, IncludeWithoutCampo: Boolean): string;
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
        ItemJSON := ToJSONWithOptions<T>(AList.Items[I], IncludeAutoInc, IncludeNulls, IncludeWithoutCampo);
        Arr.Add(TJSONObject.ParseJSONValue(ItemJSON) as TJSONObject);
      end;
    Result := Arr.ToJSON;
  finally
    Arr.Free;
  end;
end;

class function TAuroraJSON.FromJSON<T>(const AJSON: string): T;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldRtti: TRttiField;
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
  Result := TAuroraJSONGB.FromJSON<T>(AJSON);
  Exit;
  {$ENDIF}
  Result := T.Create;

  Obj := TJSONObject.ParseJSONValue(SanitizeString(AJSON)) as TJSONObject;
  if not Assigned(Obj) then
    Exit(Result);
  try
    Ctx := TRttiContext.Create;
    Typ := Ctx.GetType(TypeInfo(T));
    // Primeiro, atribui por propriedades com [Campo]
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
              Prop.SetValue(TObject(Result), Num.AsInt);
            end;
          end;
        tkInt64:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              Prop.SetValue(TObject(Result), Round(Num.AsDouble));
            end;
          end;
        tkFloat:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              Prop.SetValue(TObject(Result), Num.AsDouble);
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
              Prop.SetValue(TObject(Result), TJSONString(Val).Value)
            else
              Prop.SetValue(TObject(Result), Val.ToString);
          end;
        tkEnumeration:
          begin
            if Val is TJSONTrue then B := True
            else if Val is TJSONFalse then B := False
            else if Val is TJSONString then B := SameText(TJSONString(Val).Value, 'true')
            else B := Val.ToString = 'true';
            Prop.SetValue(TObject(Result), B);
          end;
      end;
    end;

    // Em seguida, atribui por fields (suporte a [Campo] aplicado nos fields privados)
    for FieldRtti in Typ.GetFields do
    begin
      FieldName := '';
      for Attr in FieldRtti.GetAttributes do
        if Attr is Campo then
        begin
          FieldName := Campo(Attr).Name;
          Break;
        end;
      if FieldName = '' then Continue;

      Val := Obj.Values[FieldName];
      if not Assigned(Val) then Continue;

      case FieldRtti.FieldType.TypeKind of
        tkInteger:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              FieldRtti.SetValue(TObject(Result), Num.AsInt);
            end;
          end;
        tkInt64:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              FieldRtti.SetValue(TObject(Result), Round(Num.AsDouble));
            end;
          end;
        tkFloat:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              FieldRtti.SetValue(TObject(Result), Num.AsDouble);
            end
            else if Val is TJSONString then
            begin
              S := TJSONString(Val).Value;
              // se precisar, parse de datas pode ser tratado aqui
            end;
          end;
        tkString, tkUString, tkWString:
          begin
            if Val is TJSONString then
              FieldRtti.SetValue(TObject(Result), TJSONString(Val).Value)
            else
              FieldRtti.SetValue(TObject(Result), Val.ToString);
          end;
        tkEnumeration:
          begin
            if Val is TJSONTrue then B := True
            else if Val is TJSONFalse then B := False
            else if Val is TJSONString then B := SameText(TJSONString(Val).Value, 'true')
            else B := Val.ToString = 'true';
            FieldRtti.SetValue(TObject(Result), B);
          end;
      end;
    end;
  finally
    Obj.Free;
  end;
end;

class function TAuroraJSON.FromJSONWithOptions<T>(const AJSON: string; const AcceptWithoutCampo, AllowAutoIncAssign: Boolean): T;
var
  Typ: TRttiType;
  Prop: TRttiProperty;
  FieldRtti: TRttiField;
  Name: string;
  Obj: TJSONObject;
  Val: TJSONValue;
  Num: TJSONNumber;
  S: string;
  Ctx: TRttiContext;
  B: Boolean;
  HasAutoInc: Boolean;
begin
  {$IFDEF USE_GBJSON}
  Result := TAuroraJSONGB.FromJSON<T>(AJSON);
  Exit;
  {$ENDIF}
  Result := T.Create;

  Obj := TJSONObject.ParseJSONValue(SanitizeString(AJSON)) as TJSONObject;
  if not Assigned(Obj) then
    Exit(Result);
  try
    Ctx := TRttiContext.Create;
    Typ := Ctx.GetType(TypeInfo(T));
    // Propriedades
    for Prop in Typ.GetProperties do
    begin
      Name := '';
      HasAutoInc := False;
      for var Attr in Prop.GetAttributes do
      begin
        if (Name = '') and (Attr is JsonCampo) then Name := JsonCampo(Attr).Name;
        if (Name = '') and (Attr is Campo) then Name := Campo(Attr).Name;
        if Attr is JsonIgnore then Name := ''; // força pular
        if Attr is AutoInc then HasAutoInc := True;
      end;
      if (Name = '') and AcceptWithoutCampo then
        Name := Prop.Name;
      if Name = '' then Continue;
      if HasAutoInc and not AllowAutoIncAssign then Continue;

      Val := Obj.Values[Name];
      if not Assigned(Val) then Continue;

      case Prop.PropertyType.TypeKind of
        tkInteger:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              Prop.SetValue(TObject(Result), Num.AsInt);
            end;
          end;
        tkInt64:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              Prop.SetValue(TObject(Result), Round(Num.AsDouble));
            end;
          end;
        tkFloat:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              Prop.SetValue(TObject(Result), Num.AsDouble);
            end
            else if Val is TJSONString then
            begin
              S := TJSONString(Val).Value;
            end;
          end;
        tkString, tkUString, tkWString:
          begin
            if Val is TJSONString then
              Prop.SetValue(TObject(Result), TJSONString(Val).Value)
            else
              Prop.SetValue(TObject(Result), Val.ToString);
          end;
        tkEnumeration:
          begin
            if Val is TJSONTrue then B := True
            else if Val is TJSONFalse then B := False
            else if Val is TJSONString then B := SameText(TJSONString(Val).Value, 'true')
            else B := Val.ToString = 'true';
            Prop.SetValue(TObject(Result), B);
          end;
      end;
    end;

    // Fields privados
    for FieldRtti in Typ.GetFields do
    begin
      Name := '';
      HasAutoInc := False;
      for var Attr in FieldRtti.GetAttributes do
      begin
        if (Name = '') and (Attr is JsonCampo) then Name := JsonCampo(Attr).Name;
        if (Name = '') and (Attr is Campo) then Name := Campo(Attr).Name;
        if Attr is JsonIgnore then Name := ''; // pular
        if Attr is AutoInc then HasAutoInc := True;
      end;
      if (Name = '') and AcceptWithoutCampo then
        Name := FieldRtti.Name;
      if Name = '' then Continue;
      if HasAutoInc and not AllowAutoIncAssign then Continue;

      Val := Obj.Values[Name];
      if not Assigned(Val) then Continue;

      case FieldRtti.FieldType.TypeKind of
        tkInteger:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              FieldRtti.SetValue(TObject(Result), Num.AsInt);
            end;
          end;
        tkInt64:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              FieldRtti.SetValue(TObject(Result), Round(Num.AsDouble));
            end;
          end;
        tkFloat:
          begin
            if Val is TJSONNumber then
            begin
              Num := TJSONNumber(Val);
              FieldRtti.SetValue(TObject(Result), Num.AsDouble);
            end
            else if Val is TJSONString then
            begin
              S := TJSONString(Val).Value;
            end;
          end;
        tkString, tkUString, tkWString:
          begin
            if Val is TJSONString then
              FieldRtti.SetValue(TObject(Result), TJSONString(Val).Value)
            else
              FieldRtti.SetValue(TObject(Result), Val.ToString);
          end;
        tkEnumeration:
          begin
            if Val is TJSONTrue then B := True
            else if Val is TJSONFalse then B := False
            else if Val is TJSONString then B := SameText(TJSONString(Val).Value, 'true')
            else B := Val.ToString = 'true';
            FieldRtti.SetValue(TObject(Result), B);
          end;
      end;
    end;
  finally
    Obj.Free;
  end;
end;

// (removido overload procedure; função acima contém a implementação)

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