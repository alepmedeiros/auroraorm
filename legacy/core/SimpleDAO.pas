unit SimpleDAO;

interface

uses
    SimpleInterface,
    System.RTTI,
    System.Generics.Collections,
    System.Classes,
    Data.DB,
{$IFNDEF CONSOLE}
{$IFDEF FMX}
    FMX.Forms,
{$ELSE}
    Vcl.Forms,
{$ENDIF}
{$ENDIF}
    SimpleDAOSQLAttribute,
    System.Threading,
    SimpleCommon;

Type
    TSimpleDAO<T: class, constructor> = class(TInterfacedObject, iSimpleDAO<T>)
    private
        FQuery: iSimpleQuery;
        FDataSource: TDataSource;
        FSQLAttribute: iSimpleDAOSQLAttribute<T>;
{$IFNDEF CONSOLE}
        FForm: TForm;
{$ENDIF}
        FList: TObjectList<T>;
        function FillParameter(aInstance: T): iSimpleDAO<T>; overload;
        function FillParameter(aInstance: T; aId: Variant)
          : iSimpleDAO<T>; overload;
        function FillParameterWhere(aInstance: T; var aWhere : String): iSimpleDAO<T>;
        procedure OnDataChange(Sender: TObject; Field: TField);
        procedure FilledObject(var aValue: T; aSQL: string);
    public
        constructor Create(aQuery: iSimpleQuery);
        destructor Destroy; override;
        class function New(aQuery: iSimpleQuery): iSimpleDAO<T>; overload;
        function DataSource(aDataSource: TDataSource): iSimpleDAO<T>;
        function Insert(var aValue: T): iSimpleDAO<T>; overload;
        function Update(var aValue: T): iSimpleDAO<T>; overload;
        function Delete(aValue: T): iSimpleDAO<T>; overload;
        function Delete(aField: String; aValue: String): iSimpleDAO<T>;
          overload;
        function LastID: iSimpleDAO<T>;
        function LastRecord: iSimpleDAO<T>;
{$IFNDEF CONSOLE}
        function Insert: iSimpleDAO<T>; overload;
        function Update: iSimpleDAO<T>; overload;
        function Delete: iSimpleDAO<T>; overload;
{$ENDIF}
        function Find(aBindList: Boolean = True): iSimpleDAO<T>; overload;
        function Find(var aList: TObjectList<T>): iSimpleDAO<T>; overload;
        function Find(aId: Integer): T; overload;
        function Find(aKey: String; aValue: Variant): iSimpleDAO<T>; overload;
        function Find(aID: String): T; overload;
        function FindOneWhere(aKey : String; aValue : Variant) : T;
        function FindWhere(aKey : String; aValue : Variant) : TObjectList<T>;
        function SQL: iSimpleDAOSQLAttribute<T>;
{$IFNDEF CONSOLE}
        function BindForm(aForm: TForm): iSimpleDAO<T>;
{$ENDIF}
    end;

implementation

uses
    System.SysUtils,
    SimpleAttributes,
    System.TypInfo,
    SimpleRTTI,
    SimpleSQL,
    Variants,
    SimpleLog;
{ TGenericDAO }
{$IFNDEF CONSOLE}

function TSimpleDAO<T>.BindForm(aForm: TForm): iSimpleDAO<T>;
begin
    Result := Self;
    FForm := aForm;
end;

{$ENDIF}

constructor TSimpleDAO<T>.Create(aQuery: iSimpleQuery);
begin
    FQuery := aQuery;
    FSQLAttribute := TSimpleDAOSQLAttribute<T>.New(Self);
    FList := TObjectList<T>.Create;
end;

function TSimpleDAO<T>.DataSource(aDataSource: TDataSource): iSimpleDAO<T>;
begin
    Result := Self;
    FDataSource := aDataSource;
    FDataSource.DataSet := FQuery.DataSet;
    FDataSource.OnDataChange := OnDataChange;
end;

function TSimpleDAO<T>.Delete(aValue: T): iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(aValue).Delete(aSQL);
    FQuery.SQL.Clear;
    FQuery.SQL.Add(aSQL);
    Self.FillParameter(aValue);
    FQuery.ExecSQL;
end;
{$IFNDEF CONSOLE}

function TSimpleDAO<T>.Delete: iSimpleDAO<T>;
var
    aSQL: String;
    Entity: T;
begin
    Result := Self;
    Entity := T.Create;
    try
        TSimpleSQL<T>.New(Entity).Delete(aSQL);
        FQuery.SQL.Clear;
        FQuery.SQL.Add(aSQL);
        TSimpleRTTI<T>.New(nil).BindFormToClass(FForm, Entity);
        Self.FillParameter(Entity);
        FQuery.ExecSQL;
    finally
        FreeAndNil(Entity);
    end;
end;
{$ENDIF}

function TSimpleDAO<T>.Delete(aField, aValue: String): iSimpleDAO<T>;
var
    aSQL: String;
    Entity: T;
    aTableName: string;
begin
    Result := Self;
    Entity := T.Create;
    try
        TSimpleSQL<T>.New(Entity).Delete(aSQL);
        TSimpleRTTI<T>.New(Entity).TableName(aTableName);
        // Use a parameterized value to avoid SQL injection and allow sanitization
        aSQL := 'DELETE FROM ' + aTableName + ' WHERE ' + aField + ' = :__val';
        FQuery.SQL.Clear;
        FQuery.SQL.Add(aSQL);
        // Ensure parameter exists before assignment
        if FQuery.Params.FindParam('__val') = nil then
          FQuery.Params.CreateParam(ftString, '__val', ptInput);
        // Inline sanitization of possible NUL characters in aValue
        if aValue <> '' then
        begin
          if Pos(#0, aValue) > 0 then
            aValue := StringReplace(aValue, #0, '', [rfReplaceAll]);
          // Normalize empty string to NULL
          if aValue = '' then
            FQuery.Params.ParamByName('__val').Clear
          else
            FQuery.Params.ParamByName('__val').AsString := aValue;
        end
        else
          FQuery.Params.ParamByName('__val').Clear;
        FQuery.ExecSQL;
    finally
        FreeAndNil(Entity);
    end;
end;

destructor TSimpleDAO<T>.Destroy;
begin
    FreeAndNil(FList);
    inherited;
end;

function TSimpleDAO<T>.Find(aBindList: Boolean = True): iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(nil).Fields(FSQLAttribute.Fields).Join(FSQLAttribute.Join)
      .Where(FSQLAttribute.Where).GroupBy(FSQLAttribute.GroupBy)
      .OrderBy(FSQLAttribute.OrderBy).Select(aSQL);
    FQuery.DataSet.DisableControls;
    FQuery.Open(aSQL);
    if aBindList then
        TSimpleRTTI<T>.New(nil).DataSetToEntityList(FQuery.DataSet, FList);
    FSQLAttribute.Clear;
    FQuery.DataSet.EnableControls;
end;

function TSimpleDAO<T>.Find(aId: Integer): T;
var
    aSQL: String;
begin
    Result := T.Create;
    TSimpleSQL<T>.New(nil).SelectId(aSQL);
    FQuery.SQL.Clear;
    FQuery.SQL.Add(aSQL);
    Self.FillParameter(Result, aId);
    FQuery.Open;
    TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, Result);
end;
{$IFNDEF CONSOLE}

function TSimpleDAO<T>.Insert: iSimpleDAO<T>;
var
    aSQL: String;
    Entity: T;
    PK: String;
    aSQLReturning: String;
begin
    Result := Self;
    Entity := T.Create;
    try
        TSimpleSQL<T>.New(Entity).Insert(aSQL);
        TSimpleRTTI<T>.New(nil).BindFormToClass(FForm, Entity);
        // Tenta usar RETURNING <PK> quando suportado
        TSimpleRTTI<T>.New(Entity).PrimaryKey(PK);
        aSQLReturning := TrimRight(aSQL);
        if (Length(aSQLReturning) > 0) and (aSQLReturning[Length(aSQLReturning)] = ';') then
          aSQLReturning := Copy(aSQLReturning, 1, Length(aSQLReturning) - 1);
        if PK <> '' then
          aSQLReturning := aSQLReturning + ' returning ' + PK;
        try
          FQuery.SQL.Clear;
          FQuery.SQL.Add(aSQLReturning);
          Self.FillParameter(Entity);
          FQuery.Open; // deve retornar a linha com PK
          TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, Entity);
        except
          FQuery.SQL.Clear;
          FQuery.SQL.Add(aSQL);
          Self.FillParameter(Entity);
          FQuery.ExecSQL;
        end;
    finally
        FreeAndNil(Entity);
    end;
end;

{$ENDIF}

function TSimpleDAO<T>.LastID: iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(nil).LastID(aSQL);
    FQuery.Open(aSQL);
end;

function TSimpleDAO<T>.LastRecord: iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(nil).LastRecord(aSQL);
    FQuery.Open(aSQL);
end;

function TSimpleDAO<T>.Find(var aList: TObjectList<T>): iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(nil).Fields(FSQLAttribute.Fields).Join(FSQLAttribute.Join)
      .Where(FSQLAttribute.Where).GroupBy(FSQLAttribute.GroupBy)
      .OrderBy(FSQLAttribute.OrderBy).Select(aSQL);
    FQuery.Open(aSQL);
    TSimpleRTTI<T>.New(nil).DataSetToEntityList(FQuery.DataSet, aList);
    FSQLAttribute.Clear;
end;

function TSimpleDAO<T>.Insert(var aValue: T): iSimpleDAO<T>;
var
    aSQL: String;
    PK: String;
    aSQLReturning: String;
begin
    Result := Self;
    TSimpleSQL<T>.New(aValue).Insert(aSQL);
    // Tenta RETURNING <PK>, com fallback para ExecSQL + recarga
    TSimpleRTTI<T>.New(aValue).PrimaryKey(PK);
    aSQLReturning := TrimRight(aSQL);
    if (Length(aSQLReturning) > 0) and (aSQLReturning[Length(aSQLReturning)] = ';') then
      aSQLReturning := Copy(aSQLReturning, 1, Length(aSQLReturning) - 1);
    if PK <> '' then
      aSQLReturning := aSQLReturning + ' returning ' + PK;

    try
      FQuery.SQL.Clear;
      FQuery.SQL.Add(aSQLReturning);
      Self.FillParameter(aValue);
      FQuery.Open; // retorna ao menos o PK
      Debug('SimpleORM: INSERT ... RETURNING path used');
      TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, aValue);
    except
      FQuery.SQL.Clear;
      FQuery.SQL.Add(aSQL);
      Self.FillParameter(aValue);
      FQuery.ExecSQL;
      Debug('SimpleORM: INSERT fallback used (ExecSQL)');
    end;

    // Recarrega para refletir defaults/triggers
    aSQL := '';
    FilledObject(aValue, aSQL);
end;

class function TSimpleDAO<T>.New(aQuery: iSimpleQuery): iSimpleDAO<T>;
begin
    Result := Self.Create(aQuery);
end;

procedure TSimpleDAO<T>.OnDataChange(Sender: TObject; Field: TField);
begin
    if (FList.Count > 0) and (FDataSource.DataSet.RecNo - 1 <= FList.Count) then
    begin
{$IFNDEF CONSOLE}
        if Assigned(FForm) then
            TSimpleRTTI<T>.New(nil).BindClassToForm(FForm,
              FList[FDataSource.DataSet.RecNo - 1]);
{$ENDIF}
    end;
end;

function TSimpleDAO<T>.SQL: iSimpleDAOSQLAttribute<T>;
begin
    Result := FSQLAttribute;
end;
{$IFNDEF CONSOLE}

function TSimpleDAO<T>.Update: iSimpleDAO<T>;
var
    aSQL: String;
    Entity: T;
begin
    Result := Self;
    Entity := T.Create;
    try
        TSimpleSQL<T>.New(Entity).Update(aSQL);
        FQuery.SQL.Clear;
        FQuery.SQL.Add(aSQL);
        TSimpleRTTI<T>.New(nil).BindFormToClass(FForm, Entity);
        Self.FillParameter(Entity);
        FQuery.ExecSQL;
    finally
        FreeAndNil(Entity)
    end;
end;
{$ENDIF}

function TSimpleDAO<T>.Update(var aValue: T): iSimpleDAO<T>;
var
    aSQL: String;
    aPK: String;
    aPkValue: Integer;
begin
    Result := Self;
    TSimpleSQL<T>.New(aValue).Update(aSQL);
    // Para PostgreSQL, tentar UPDATE ... RETURNING * para recarregar sem SELECT extra
    var aSQLReturning := TrimRight(aSQL);
    if (Length(aSQLReturning) > 0) and (aSQLReturning[Length(aSQLReturning)] = ';') then
      aSQLReturning := Copy(aSQLReturning, 1, Length(aSQLReturning) - 1);
    aSQLReturning := aSQLReturning + ' returning *';

    try
      FQuery.SQL.Clear;
      FQuery.SQL.Add(aSQLReturning);
      Self.FillParameter(aValue);
      // Se o driver suportar RETURNING (PostgreSQL), abrimos e mapeamos direto
      FQuery.Open;
      // Log caminho com RETURNING
      Debug('SimpleORM: UPDATE ... RETURNING path used');
      TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, aValue);
    except
      // Fallback: executa UPDATE normal e recarrega com SELECT
      FQuery.SQL.Clear;
      FQuery.SQL.Add(aSQL);
      Self.FillParameter(aValue);
      FQuery.ExecSQL;
      Debug('SimpleORM: Fallback path used (ExecSQL + SELECT reload)');
      aSQL := '';
      FilledObject(aValue, aSQL);
    end;
end;

function TSimpleDAO<T>.FillParameter(aInstance: T): iSimpleDAO<T>;
var
    Key: String;
    DictionaryFields: TDictionary<String, Variant>;
    DictionaryTypeFields: TDictionary<String, TFieldType>;
    FieldType: TFieldType;
begin
    DictionaryFields := TDictionary<String, Variant>.Create;
    DictionaryTypeFields := TDictionary<String, TFieldType>.Create;
    TSimpleRTTI<T>.New(aInstance).DictionaryFields(DictionaryFields);
    TSimpleRTTI<T>.New(aInstance).DictionaryTypeFields(DictionaryTypeFields);
    try
        for Key in DictionaryFields.Keys do
        begin
            if FQuery.Params.FindParam(Key) <> nil then
            begin
                if DictionaryTypeFields.TryGetValue(Key, FieldType ) then
                  FQuery.Params.ParamByName(Key).DataType := FieldType;
                var V := DictionaryFields.Items[Key];
                // Trata valores nulos/empties e sanitiza strings contendo NUL (#0) para PostgreSQL UTF-8
                if VarIsNull(V) or VarIsEmpty(V) then
                begin
                  FQuery.Params.ParamByName(Key).Clear;
                end
                else
                begin
                  var P := FQuery.Params.ParamByName(Key);
                  case FieldType of
                    ftString, ftWideString, ftMemo, ftWideMemo:
                      begin
                        var S := VarToStr(V);
                        if Pos(#0, S) > 0 then
                        begin
                          var I: Integer;
                          var SB: TStringBuilder := TStringBuilder.Create;
                          try
                            for I := 1 to Length(S) do
                              if S[I] <> #0 then
                                SB.Append(S[I]);
                            S := SB.ToString;
                          finally
                            SB.Free;
                          end;
                        end;
                        // Bind explicitly as WideString to force Unicode-safe handling
                        P.DataType := ftWideString;
                        P.AsWideString := S;
                        if S <> '' then
                          P.Size := Length(S);
                      end;
                  else
                    begin
                      var VT := VarType(V);
                      if (VT = varUString) or (VT = varOleStr) then
                      begin
                        var S := VarToStr(V);
                        if Pos(#0, S) > 0 then
                        begin
                          var I: Integer;
                          var SB: TStringBuilder := TStringBuilder.Create;
                          try
                            for I := 1 to Length(S) do
                              if S[I] <> #0 then
                                SB.Append(S[I]);
                            S := SB.ToString;
                          finally
                            SB.Free;
                          end;
                        end;
                        P.Value := S;
                      end
                      else
                        P.Value := V;
                    end;
                  end;
                end;
            end;
        end;
    finally
        FreeAndNil(DictionaryFields);
        FreeAndNil(DictionaryTypeFields);
    end;
end;

procedure TSimpleDAO<T>.FilledObject(var aValue: T; aSQL: string);
var
  aWhere: string;
begin
  Self.FillParameterWhere(aValue, aWhere);
  TSimpleSQL<T>.New(nil).Where(aWhere).Select(aSQL);
  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  FQuery.Open;
  TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, aValue);
  FSQLAttribute.Clear;
end;

function TSimpleDAO<T>.FillParameter(aInstance: T; aId: Variant): iSimpleDAO<T>;
var
    I: Integer;
    ListFields: TList<String>;
begin
    ListFields := TList<String>.Create;
    TSimpleRTTI<T>.New(aInstance).ListFields(ListFields);
    try
        for I := 0 to Pred(ListFields.Count) do
        begin
            if FQuery.Params.FindParam(ListFields[I]) <> nil then
            begin
                if VarIsNull(aId) or VarIsEmpty(aId) then
                  FQuery.Params.ParamByName(ListFields[I]).Clear
                else
                  FQuery.Params.ParamByName(ListFields[I]).Value := aId;
            end;
        end;
    finally
        FreeAndNil(ListFields);
    end;
end;

function TSimpleDAO<T>.FillParameterWhere(aInstance: T;
  var aWhere: String): iSimpleDAO<T>;
var
    Key, PK: String;
    DictionaryFields: TDictionary<String, Variant>;
    DictionaryTypeFields: TDictionary<String, TFieldType>;
    FieldType: TFieldType;
begin
    DictionaryFields := TDictionary<String, Variant>.Create;
    DictionaryTypeFields := TDictionary<String, TFieldType>.Create;
    TSimpleRTTI<T>.New(aInstance).DictionaryFields(DictionaryFields).PrimaryKey(PK);
    TSimpleRTTI<T>.New(aInstance).DictionaryTypeFields(DictionaryTypeFields);
    try
        for Key in DictionaryFields.Keys do
        begin
          if Key <> PK then
          begin
            var V := DictionaryFields.Items[Key];
            // Descobre o tipo do campo
            if not DictionaryTypeFields.TryGetValue(Key, FieldType) then
              FieldType := ftWideString;

            // Determina se o valor é nulo ou string vazia (normalizar comportamento)
            var IsNull := VarIsNull(V) or VarIsEmpty(V);
            var IsEmptyStr := False;
            var S: string := '';
            if (FieldType in [ftString, ftWideString, ftMemo, ftWideMemo]) or VarIsStr(V) then
            begin
              S := VarToStr(V);
              // remove NULs
              if Pos(#0, S) > 0 then
                S := StringReplace(S, #0, '', [rfReplaceAll]);
              IsEmptyStr := S = '';
            end;

            // Constrói cláusula WHERE com tratamento de NULL/strings vazias
            if IsNull or IsEmptyStr then
            begin
              // para valores nulos ou string vazia, usar IS NULL
              if not aWhere.IsEmpty then
                aWhere := aWhere + ' and ' + Key + ' is null'
              else
                aWhere := Key + ' is null';
              // não cria parâmetro para IS NULL
            end
            else
            begin
              // valor presente: usar parâmetro
              if not aWhere.IsEmpty then
                aWhere := aWhere + ' and ' + Key + ' = :' + Key
              else
                aWhere := Key + ' = :' + Key;

              // garante existência do parâmetro temporário e atribui o valor
              var ParamType := FieldType;
              if ParamType in [ftString, ftMemo] then
                ParamType := ftWideString; // força Unicode

              if FQuery.Params.FindParam(Key) = nil then
                FQuery.Params.CreateParam(ParamType, Key, ptInput);

              var P := FQuery.Params.ParamByName(Key);
              P.DataType := ParamType;

              case ParamType of
                ftWideString, ftString, ftMemo, ftWideMemo:
                  begin
                    P.AsWideString := S;
                    if S <> '' then
                      P.Size := Length(S);
                  end;
              else
                begin
                  P.Value := V;
                end;
              end;
            end;
          end;
        end;

    finally
        FreeAndNil(DictionaryFields);
    end;
end;

function TSimpleDAO<T>.Find(aKey: String; aValue: Variant): iSimpleDAO<T>;
var
    aSQL: String;
begin
    Result := Self;
    // Decide entre IS NULL e comparação por parâmetro
    var IsNull := VarIsNull(aValue) or VarIsEmpty(aValue);
    var IsEmptyStr := VarIsStr(aValue) and (VarToStr(aValue) = '');
    if IsNull or IsEmptyStr then
      TSimpleSQL<T>.New(nil).Where(aKey + ' is null').Select(aSQL)
    else
      TSimpleSQL<T>.New(nil).Where(aKey + ' = :' + aKey).Select(aSQL);
    FQuery.SQL.Clear;
    FQuery.SQL.Add(aSQL);
    if not (IsNull or IsEmptyStr) then
    begin
      // Sanitiza strings antes de atribuir
      var P := FQuery.Params.ParamByName(aKey);
      if (P.DataType in [ftString, ftWideString, ftMemo, ftWideMemo]) or VarIsStr(aValue) then
      begin
        var S := VarToStr(aValue);
        if Pos(#0, S) > 0 then
        begin
          var I: Integer;
          var SB: TStringBuilder := TStringBuilder.Create;
          try
            for I := 1 to Length(S) do
              if S[I] <> #0 then SB.Append(S[I]);
            S := SB.ToString;
          finally
            SB.Free;
          end;
        end;
        P.DataType := ftWideString;
        P.AsWideString := S;
        if S <> '' then
          P.Size := Length(S);
      end
      else
        P.Value := aValue;
    end;
    FQuery.Open;
end;

function TSimpleDAO<T>.Find(aID: String): T;
begin
  var aSQL: String;
  Result := T.Create;
  TSimpleSQL<T>.New(nil).SelectId(aSQL);
  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  // Preenche o parâmetro da chave primária com o ID informado
  Self.FillParameter(Result, aID);
  FQuery.Open;
  TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, Result);
end;

function TSimpleDAO<T>.FindOneWhere(aKey: String; aValue: Variant): T;
begin
  var aSQL: String;
  var IsNull := VarIsNull(aValue) or VarIsEmpty(aValue);
  var IsEmptyStr := VarIsStr(aValue) and (VarToStr(aValue) = '');
  if IsNull or IsEmptyStr then
    TSimpleSQL<T>.New(nil).Where(aKey + ' is null').Select(aSQL)
  else
    TSimpleSQL<T>.New(nil).Where(aKey + ' = :' + aKey).Select(aSQL);
  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  if not (IsNull or IsEmptyStr) then
  begin
    var P := FQuery.Params.ParamByName(aKey);
    if (P.DataType in [ftString, ftWideString, ftMemo, ftWideMemo]) or VarIsStr(aValue) then
    begin
      var S := VarToStr(aValue);
      if Pos(#0, S) > 0 then
      begin
        var I: Integer;
        var SB: TStringBuilder := TStringBuilder.Create;
        try
          for I := 1 to Length(S) do
            if S[I] <> #0 then SB.Append(S[I]);
          S := SB.ToString;
        finally
          SB.Free;
        end;
      end;
      P.DataType := ftWideString;
      P.AsWideString := S;
      if S <> '' then
        P.Size := Length(S);
    end
    else
      P.Value := aValue;
  end;
  FQuery.Open;
  TSimpleRTTI<T>.New(nil).DataSetToEntity(FQuery.DataSet, Result);
  FSQLAttribute.Clear;
end;

function TSimpleDAO<T>.FindWhere(aKey: String; aValue: Variant): TObjectList<T>;
begin
  REsult := TObjectList<T>.Create;
  var aSQL: String;
  var IsNull := VarIsNull(aValue) or VarIsEmpty(aValue);
  var IsEmptyStr := VarIsStr(aValue) and (VarToStr(aValue) = '');
  if IsNull or IsEmptyStr then
    TSimpleSQL<T>.New(nil).Where(aKey + ' is null').Select(aSQL)
  else
    TSimpleSQL<T>.New(nil).Where(aKey + ' = :' + aKey).Select(aSQL);
  FQuery.SQL.Clear;
  FQuery.SQL.Add(aSQL);
  if not (IsNull or IsEmptyStr) then
  begin
    var P := FQuery.Params.ParamByName(aKey);
    if (P.DataType in [ftString, ftWideString, ftMemo, ftWideMemo]) or VarIsStr(aValue) then
    begin
      var S := VarToStr(aValue);
      if Pos(#0, S) > 0 then
      begin
        var I: Integer;
        var SB: TStringBuilder := TStringBuilder.Create;
        try
          for I := 1 to Length(S) do
            if S[I] <> #0 then SB.Append(S[I]);
          S := SB.ToString;
        finally
          SB.Free;
        end;
      end;
      P.DataType := ftWideString;
      P.AsWideString := S;
      if S <> '' then
        P.Size := Length(S);
    end
    else
      P.Value := aValue;
  end;
  FQuery.Open;
  TSimpleRTTI<T>.New(nil).DataSetToEntityList(FQuery.DataSet, Result);
    FSQLAttribute.Clear;
end;

end.
