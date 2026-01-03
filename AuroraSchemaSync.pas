unit AuroraSchemaSync;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Data.DB, System.Rtti,
  AuroraInterface, AuroraAttributes, AuroraRTTI, AuroraConfig;

type
  TAuroraSchemaSync = class
  private
    class function TableExists(const Q: iAuroraQuery; const TableName: string): Boolean; static;
    class function ExistingColumns(const Q: iAuroraQuery; const TableName: string): TDictionary<string,string>; static;
    class function SQLTypeForField(const FieldType: TFieldType; const MaxSize: Integer): string; static;
    class function ColumnConstraintsFromAttrs(const Attrs: TArray<TCustomAttribute>): string; static;
    class function PrimaryKeyFor<T: class, constructor>: string; static;
    class function FieldsInfoFor<T: class, constructor>(out Fields: TArray<string>; out Types: TArray<TFieldType>; out Sizes: TArray<Integer>): Boolean; static;
  public
    class procedure Ensure<T: class, constructor>(const Q: iAuroraQuery); static;
  end;

implementation

class function TAuroraSchemaSync.TableExists(const Q: iAuroraQuery; const TableName: string): Boolean;
begin
  case TAuroraConfig.Dialect of
    dbSQLite:
      Q.Open('SELECT name FROM sqlite_master WHERE type=''table'' AND name='''+TableName+'''');
    dbPostgreSQL:
      Q.Open('SELECT to_regclass('''+TableName+''') AS reg');
  else
      Q.Open('');
  end;
  Result := (Q.DataSet <> nil) and not Q.DataSet.IsEmpty;
end;

class function TAuroraSchemaSync.ExistingColumns(const Q: iAuroraQuery; const TableName: string): TDictionary<string,string>;
begin
  Result := TDictionary<string,string>.Create;
  case TAuroraConfig.Dialect of
    dbSQLite:
      Q.Open('PRAGMA table_info('+TableName+')');
    dbPostgreSQL:
      Q.Open('SELECT column_name, data_type FROM information_schema.columns WHERE table_name='''+TableName+'''');
  else
      Q.Open('');
  end;
  while not Q.DataSet.Eof do
  begin
    if TAuroraConfig.Dialect = dbSQLite then
      Result.AddOrSetValue(Q.DataSet.FieldByName('name').AsString, Q.DataSet.FieldByName('type').AsString)
    else
      Result.AddOrSetValue(Q.DataSet.FieldByName('column_name').AsString, Q.DataSet.FieldByName('data_type').AsString);
    Q.DataSet.Next;
  end;
end;

class function TAuroraSchemaSync.SQLTypeForField(const FieldType: TFieldType; const MaxSize: Integer): string;
begin
  case TAuroraConfig.Dialect of
    dbSQLite:
      case FieldType of
        ftInteger, ftLargeint: Result := 'INTEGER';
        ftFloat, ftDateTime: Result := 'REAL';
        ftWideString, ftString: Result := 'TEXT';
        ftBlob: Result := 'BLOB';
      else Result := 'TEXT'; end;
    dbPostgreSQL:
      case FieldType of
        ftInteger: Result := 'INTEGER';
        ftLargeint: Result := 'BIGINT';
        ftFloat: Result := 'DOUBLE PRECISION';
        ftDateTime: Result := 'TIMESTAMP';
        ftWideString, ftString: if MaxSize>0 then Result := 'VARCHAR('+IntToStr(MaxSize)+')' else Result := 'TEXT';
        ftBlob: Result := 'BYTEA';
      else Result := 'TEXT'; end;
  else
    Result := 'TEXT';
  end;
end;

class function TAuroraSchemaSync.ColumnConstraintsFromAttrs(const Attrs: TArray<TCustomAttribute>): string;
var
  HasNotNull: Boolean;
  Fmt: Format;
  FKAttr: FK;
  HasUnique: Boolean;
begin
  Result := '';
  HasNotNull := False;
  Fmt := nil;
  FKAttr := nil;
  HasUnique := False;
  for var A in Attrs do
  begin
    if A is NotNull then HasNotNull := True;
    if A is Format then Fmt := Format(A);
    if A is FK then FKAttr := FK(A);
    if A is Unique then HasUnique := True;
  end;
  if HasNotNull then
    Result := Result + ' NOT NULL';
  if HasUnique then
    Result := Result + ' UNIQUE';
  if FKAttr <> nil then
    if TAuroraConfig.Dialect = dbPostgreSQL then
      Result := Result + ' REFERENCES ' + FKAttr.Table + '(' + FKAttr.Column + ')'
    else if TAuroraConfig.Dialect = dbSQLite then
      Result := Result + ' REFERENCES ' + FKAttr.Table + '(' + FKAttr.Column + ')';
end;

class function TAuroraSchemaSync.PrimaryKeyFor<T>: string;
var
  PK: string;
begin
  PK := '';
  TAuroraRTTI<T>.New(nil).PrimaryKey(PK);
  Result := PK;
end;

class function TAuroraSchemaSync.FieldsInfoFor<T>(out Fields: TArray<string>; out Types: TArray<TFieldType>; out Sizes: TArray<Integer>): Boolean;
var
  DictTypes: TDictionary<string, TFieldType>;
  List: TList<string>;
  I: Integer;
begin
  DictTypes := nil;
  List := nil;
  TAuroraRTTI<T>.New(nil).ListFields(List);
  TAuroraRTTI<T>.New(nil).DictionaryTypeFields(DictTypes);
  SetLength(Fields, List.Count);
  SetLength(Types, List.Count);
  SetLength(Sizes, List.Count);
  for I := 0 to List.Count-1 do
  begin
    Fields[I] := List[I];
    Types[I] := DictTypes.Items[Fields[I]];
    Sizes[I] := 0;
  end;
  Result := List.Count>0;
  List.Free;
  DictTypes.Free;
end;

class procedure TAuroraSchemaSync.Ensure<T>(const Q: iAuroraQuery);
var
  Tbl: string;
  PK: string;
  Fields: TArray<string>;
  Types: TArray<TFieldType>;
  Sizes: TArray<Integer>;
  PropConstraints: TDictionary<string,string>;
  PropTypeOverrides: TDictionary<string,string>;
  Cols: TDictionary<string,string>;
  I: Integer;
  CreateSQL: TStringList;
begin
  Tbl := '';
  TAuroraRTTI<T>.New(nil).TableName(Tbl);
  if TAuroraConfig.UseSchemaPrefix then Tbl := TAuroraConfig.Schema+'.'+Tbl;
  PK := PrimaryKeyFor<T>;
  FieldsInfoFor<T>(Fields, Types, Sizes);
  // Build property constraints map (NotNull)
  PropConstraints := TDictionary<string,string>.Create;
  PropTypeOverrides := TDictionary<string,string>.Create;
  try
    var Typ := TRttiContext.Create.GetType(TypeInfo(T));
    for var Prop in Typ.GetProperties do
    begin
      var CampoName := '';
      for var A in Prop.GetAttributes do
        if A is Campo then CampoName := Campo(A).Name;
      if CampoName <> '' then
        PropConstraints.AddOrSetValue(CampoName, ColumnConstraintsFromAttrs(Prop.GetAttributes));
      if CampoName <> '' then
      begin
        var Fmt: Format := nil;
        for var A in Prop.GetAttributes do
          if A is Format then Fmt := Format(A);
        if (TAuroraConfig.Dialect = dbPostgreSQL) and Assigned(Fmt) then
        begin
          case Prop.PropertyType.TypeKind of
            tkString, tkUString, tkWString:
              if Fmt.MaxSize > 0 then
                PropTypeOverrides.AddOrSetValue(CampoName, 'VARCHAR(' + IntToStr(Fmt.MaxSize) + ')');
            tkFloat:
              if (Fmt.MaxSize > 0) and (Fmt.Precision > 0) then
                PropTypeOverrides.AddOrSetValue(CampoName, 'NUMERIC(' + IntToStr(Fmt.MaxSize) + ',' + IntToStr(Fmt.Precision) + ')');
          end;
        end;
      end;
    end;
  if not TableExists(Q, Tbl) then
  begin
    CreateSQL := TStringList.Create;
    try
      case TAuroraConfig.Dialect of
        dbSQLite:
          begin
            CreateSQL.Add('CREATE TABLE '+Tbl+' (');
            for I := 0 to High(Fields) do
              if SameText(Fields[I], PK) then
                CreateSQL.Add(Fields[I]+' INTEGER PRIMARY KEY AUTOINCREMENT,')
              else
                CreateSQL.Add(Fields[I]+' ' + PropTypeOverrides.GetValueOrDefault(Fields[I], SQLTypeForField(Types[I], Sizes[I])) +
                  PropConstraints.GetValueOrDefault(Fields[I], '') + ',');
            if CreateSQL.Count>0 then
              CreateSQL[CreateSQL.Count-1] := TrimRight(CreateSQL[CreateSQL.Count-1].TrimRight([',']));
            CreateSQL.Add(')');
          end;
        dbPostgreSQL:
          begin
            CreateSQL.Add('CREATE TABLE '+Tbl+' (');
            for I := 0 to High(Fields) do
              if SameText(Fields[I], PK) then
                CreateSQL.Add(Fields[I]+' BIGSERIAL PRIMARY KEY,')
              else
                CreateSQL.Add(Fields[I]+' ' + PropTypeOverrides.GetValueOrDefault(Fields[I], SQLTypeForField(Types[I], Sizes[I])) +
                  PropConstraints.GetValueOrDefault(Fields[I], '') + ',');
            if CreateSQL.Count>0 then
              CreateSQL[CreateSQL.Count-1] := TrimRight(CreateSQL[CreateSQL.Count-1].TrimRight([',']));
            CreateSQL.Add(')');
          end;
      else
        CreateSQL.Add('');
      end;
      Q.SQL.Text := CreateSQL.Text;
      Q.ExecSQL;
      var Typ := TRttiContext.Create.GetType(TypeInfo(T));
      for var Prop in Typ.GetProperties do
      begin
        var CampoName := '';
        var IxName := '';
        for var A in Prop.GetAttributes do
        begin
          if A is Campo then CampoName := Campo(A).Name;
          if A is Index then IxName := Index(A).Name;
        end;
        if CampoName <> '' then
        begin
          if IxName = '' then IxName := 'idx_' + Tbl + '_' + CampoName;
          if TAuroraConfig.Dialect = dbPostgreSQL then
          begin
            Q.SQL.Text := 'CREATE INDEX IF NOT EXISTS ' + IxName + ' ON ' + Tbl + '(' + CampoName + ')';
            Q.ExecSQL;
          end
          else if TAuroraConfig.Dialect = dbSQLite then
          begin
            Q.SQL.Text := 'CREATE INDEX IF NOT EXISTS ' + IxName + ' ON ' + Tbl + '(' + CampoName + ')';
            Q.ExecSQL;
          end;
        end;
      end;
    finally
      CreateSQL.Free;
    end;
  end
  else
  begin
    Cols := ExistingColumns(Q, Tbl);
    try
      for I := 0 to High(Fields) do
        if not Cols.ContainsKey(Fields[I]) then
        begin
          // SQLite limita ADD COLUMN sem NOT NULL; aplicamos apenas tipo
          if TAuroraConfig.Dialect = dbPostgreSQL then
            Q.SQL.Text := 'ALTER TABLE '+Tbl+' ADD COLUMN '+Fields[I]+' ' + PropTypeOverrides.GetValueOrDefault(Fields[I], SQLTypeForField(Types[I], Sizes[I])) +
              PropConstraints.GetValueOrDefault(Fields[I], '')
          else
            Q.SQL.Text := 'ALTER TABLE '+Tbl+' ADD COLUMN '+Fields[I]+' ' + PropTypeOverrides.GetValueOrDefault(Fields[I], SQLTypeForField(Types[I], Sizes[I]));
          Q.ExecSQL;
        end;
      var Typ := TRttiContext.Create.GetType(TypeInfo(T));
      for var Prop in Typ.GetProperties do
      begin
        var CampoName := '';
        var IxName := '';
        for var A in Prop.GetAttributes do
        begin
          if A is Campo then CampoName := Campo(A).Name;
          if A is Index then IxName := Index(A).Name;
        end;
        if CampoName <> '' then
        begin
          if IxName = '' then IxName := 'idx_' + Tbl + '_' + CampoName;
          if TAuroraConfig.Dialect = dbPostgreSQL then
          begin
            Q.SQL.Text := 'CREATE INDEX IF NOT EXISTS ' + IxName + ' ON ' + Tbl + '(' + CampoName + ')';
            Q.ExecSQL;
          end
          else if TAuroraConfig.Dialect = dbSQLite then
          begin
            Q.SQL.Text := 'CREATE INDEX IF NOT EXISTS ' + IxName + ' ON ' + Tbl + '(' + CampoName + ')';
            Q.ExecSQL;
          end;
        end;
      end;
    finally
      Cols.Free;
    end;
  end;
  finally
    PropConstraints.Free;
    PropTypeOverrides.Free;
  end;
end;

end.
