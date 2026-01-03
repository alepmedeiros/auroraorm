program AuroraSchemaAudit;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  AuroraConfig,
  AuroraInterface,
  AuroraQueryFiredac,
  System.JSON,
  Entities.User in '..\Sample\AuroraHeadless\Entities\Entities.User.pas',
  Entities.Order in '..\Sample\AuroraHeadless\Entities\Order.pas',
  Entities.Profile in '..\Sample\AuroraHeadless\Entities\Profile.pas',
  System.Rtti;

function GetColumns(const Q: iAuroraQuery; const TableName: string): TList<string>;
begin
  Result := TList<string>.Create;
  case TAuroraConfig.Dialect of
    dbSQLite:
      begin
        Q.Open('PRAGMA table_info('+TableName+')');
        while not Q.DataSet.Eof do
        begin
          Result.Add(Q.DataSet.FieldByName('name').AsString);
          Q.DataSet.Next;
        end;
      end;
    dbPostgreSQL:
      begin
        Q.Open('SELECT column_name FROM information_schema.columns WHERE table_name='''+TableName+'''');
        while not Q.DataSet.Eof do
        begin
          Result.Add(Q.DataSet.FieldByName('column_name').AsString);
          Q.DataSet.Next;
        end;
      end;
  end;
end;

procedure AuditEntity<T: class, constructor>(const Q: iAuroraQuery);
var
  Tbl: string;
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Fields: TList<string>;
  DBCols: TList<string>;
  Obj: TJSONObject;
  MissingDB, MissingEntity: TJSONArray;
begin
  Tbl := '';
  TAuroraRTTI<T>.New(nil).TableName(Tbl);
  Obj := TJSONObject.Create;
  MissingDB := TJSONArray.Create;
  MissingEntity := TJSONArray.Create;
  Fields := TList<string>.Create;
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(TypeInfo(T));
  for Prop in Typ.GetProperties do
    for var A in Prop.GetAttributes do
      if A is Campo then Fields.Add(Campo(A).Name);
  DBCols := GetColumns(Q, Tbl);
  try
    for var F in Fields do
      if DBCols.IndexOf(F) = -1 then MissingDB.Add(F);
    for var C in DBCols do
      if Fields.IndexOf(C) = -1 then MissingEntity.Add(C);
    Obj.AddPair('table', Tbl);
    Obj.AddPair('missing_in_db', MissingDB);
    Obj.AddPair('missing_in_entity', MissingEntity);
    Writeln(Obj.ToJSON);
  finally
    Fields.Free;
    DBCols.Free;
    Obj.Free;
  end;
end;

var
  Conn: TFDConnection;
  Q: iAuroraQuery;
begin
  Conn := TFDConnection.Create(nil);
  Conn.Params.Values['DriverID'] := 'SQLite';
  Conn.Params.Database := 'aurora.db';
  Conn.Open;
  TAuroraConfig.SetDialect(dbSQLite);
  Q := TAuroraQueryFiredac.New(Conn);
  AuditEntity<TUser>(Q);
  AuditEntity<TOrder>(Q);
  AuditEntity<TProfile>(Q);
end.
