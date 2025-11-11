unit SimpleQueryFiredac;

interface

uses
  SimpleInterface, FireDAC.Comp.Client, System.Classes, Data.DB,
  FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet
  {$IFDEF SIMPLEORM_FD_MONITOR}
  , FireDAC.Moni.FlatFile
  {$ELSE}
    {$IFDEF DEBUG}
    , FireDAC.Moni.FlatFile
    {$ENDIF}
  {$ENDIF};

Type
  TSimpleQueryFiredac = class(TInterfacedObject, iSimpleQuery)
    private
      FConnection : TFDConnection;
      FQuery : TFDQuery;
      FParams : TParams;
      {$IFDEF SIMPLEORM_FD_MONITOR}
      FMonFlat : TFDMoniFlatFileClientLink;
      {$ELSE}
        {$IFDEF DEBUG}
        FMonFlat : TFDMoniFlatFileClientLink;
        {$ENDIF}
      {$ENDIF}
      // Remove any NUL (\x00) characters from SQL text and string params
      // to satisfy PostgreSQL UTF-8 requirements and avoid EPgNativeException.
      procedure SanitizeInputs;
    public
      constructor Create(aConnection : TFDConnection);
      destructor Destroy; override;
      class function New(aConnection : TFDConnection) : iSimpleQuery;
      function SQL : TStrings;
      function Params : TParams;
      function ExecSQL : iSimpleQuery;
      function DataSet : TDataSet;
      function Open(aSQL : String) : iSimpleQuery; overload;
      function Open : iSimpleQuery; overload;
  end;

implementation

uses
  System.SysUtils, System.Variants, System.IOUtils, SimpleConfig;

{ TSimpleQuery<T> }

constructor TSimpleQueryFiredac.Create(aConnection : TFDConnection);
begin
  FQuery := TFDQuery.Create(nil);
  FConnection := aConnection;
  FQuery.Connection := FConnection;
  // Schema configuration is applied at connection level (OnAfterConnect).
  // Enable FireDAC FlatFile monitor only when compiled for it
  {$IFDEF SIMPLEORM_FD_MONITOR}
  try
    {$MESSAGE WARN 'SimpleORM FD Monitor ENABLED (directive SIMPLEORM_FD_MONITOR)'}
    FMonFlat := TFDMoniFlatFileClientLink.Create(nil);
    var DestDir := TPath.GetDirectoryName(ParamStr(0));
    var EnvDir := GetEnvironmentVariable('SIMPLEORM_FD_MONITOR_DIR');
    if not EnvDir.IsEmpty then
      DestDir := EnvDir;
    FMonFlat.FileName := TPath.Combine(DestDir, 'fd_monitor.log');
    var EnvMon := GetEnvironmentVariable('SIMPLEORM_FD_MONITOR');
    var HasEnv := not EnvMon.IsEmpty;
    var Enabled := False;
    if HasEnv then
      Enabled := SameText(EnvMon, '1') or SameText(EnvMon, 'true') or SameText(EnvMon, 'on');
    if not HasEnv then
      Enabled := True; // directive enables by default when no env override
    FMonFlat.Tracing := Enabled;
  except
    // continue without monitor if activation fails
  end;
  {$ELSE}
    {$IFDEF DEBUG}
    try
      {$MESSAGE WARN 'SimpleORM FD Monitor ENABLED (DEBUG build)'}
      FMonFlat := TFDMoniFlatFileClientLink.Create(nil);
      var DestDir := TPath.GetDirectoryName(ParamStr(0));
      var EnvDir := GetEnvironmentVariable('SIMPLEORM_FD_MONITOR_DIR');
      if not EnvDir.IsEmpty then
        DestDir := EnvDir;
      FMonFlat.FileName := TPath.Combine(DestDir, 'fd_monitor.log');
      var EnvMon := GetEnvironmentVariable('SIMPLEORM_FD_MONITOR');
      var HasEnv := not EnvMon.IsEmpty;
      var Enabled := False;
      if HasEnv then
        Enabled := SameText(EnvMon, '1') or SameText(EnvMon, 'true') or SameText(EnvMon, 'on');
      if not HasEnv then
        Enabled := True; // debug enables by default when no env override
      FMonFlat.Tracing := Enabled;
    except
      // continue without monitor if activation fails
    end;
    {$ENDIF}
  {$ENDIF}
end;

function TSimpleQueryFiredac.DataSet: TDataSet;
begin
  Result := TDataSet(FQuery);
end;

destructor TSimpleQueryFiredac.Destroy;
begin
  FreeAndNil(FQuery);
  if Assigned(FParams) then
    FreeAndNil(FParams);
  {$IFDEF SIMPLEORM_FD_MONITOR}
  if Assigned(FMonFlat) then FreeAndNil(FMonFlat);
  {$ELSE}
    {$IFDEF DEBUG}
    if Assigned(FMonFlat) then FreeAndNil(FMonFlat);
    {$ENDIF}
  {$ENDIF}
  inherited;
end;

function TSimpleQueryFiredac.ExecSQL: iSimpleQuery;
begin
  Result := Self;
  if Assigned(FParams) then
    FQuery.Params.Assign(FParams);

  // Ensure SQL and Params are free of NUL characters before execution
  SanitizeInputs;
  FQuery.Prepare;
  FQuery.ExecSQL;

  if Assigned(FParams) then
    FreeAndNil(FParams);
end;

class function TSimpleQueryFiredac.New(aConnection : TFDConnection): iSimpleQuery;
begin
  Result := Self.Create(aConnection);
end;

function TSimpleQueryFiredac.Open: iSimpleQuery;
begin
  Result := Self;
  FQuery.Close;

  if Assigned(FParams) then
    FQuery.Params.Assign(FParams);

  // Ensure SQL and Params are free of NUL characters before opening
  SanitizeInputs;
  FQuery.Prepare;
  FQuery.Open;

  if Assigned(FParams) then
    FreeAndNil(FParams);
end;

function TSimpleQueryFiredac.Open(aSQL: String): iSimpleQuery;
begin
  Result := Self;
  FQuery.Close;
  // Strip NULs from incoming SQL text to avoid driver errors
  if Pos(#0, aSQL) > 0 then
    aSQL := StringReplace(aSQL, #0, '', [rfReplaceAll]);
  FQuery.Open(aSQL);
end;

function TSimpleQueryFiredac.Params: TParams;
begin
  if not Assigned(FParams) then
  begin
    FParams := TParams.Create(nil);
    FParams.Assign(FQuery.Params);
  end;
  Result := FParams;
end;

function TSimpleQueryFiredac.SQL: TStrings;
begin
  Result := FQuery.SQL;
end;

procedure TSimpleQueryFiredac.SanitizeInputs;
var
  i: Integer;
  S: string;
  P: TParam;
  FDParam: TFDParam;
begin
  // Strip NULs from SQL text (covers any literal construction that might include \x00)
  if Assigned(FQuery) and Assigned(FQuery.SQL) then
    FQuery.SQL.Text := StringReplace(FQuery.SQL.Text, #0, '', [rfReplaceAll]);

  // Sanitize temporary params, if present
  if Assigned(FParams) then
  begin
    for i := 0 to FParams.Count - 1 do
    begin
      P := FParams.Items[i];
      if P.IsNull then
        Continue;

      // Treat textual param types and any variant that is a string
      if (P.DataType in [ftString, ftWideString, ftMemo, ftWideMemo, ftFixedChar, ftFixedWideChar, ftFmtMemo])
         or VarIsStr(P.Value) then
      begin
        S := VarToStr(P.Value);
        if S <> '' then
        begin
          if Pos(#0, S) > 0 then
            S := StringReplace(S, #0, '', [rfReplaceAll]);
          if S = '' then
            P.Clear
          else
          begin
            // Ensure param is treated as textual if it wasn't
            if not (P.DataType in [ftString, ftWideString, ftMemo, ftWideMemo, ftFixedChar, ftFixedWideChar, ftFmtMemo]) then
              P.DataType := ftWideString;
            P.AsString := S;
          end;
        end
        else
          P.Clear; // normalize empty string to NULL to avoid surprises
      end;
    end;
  end;

  // Sanitize the query's actual params as well
  if Assigned(FQuery) and Assigned(FQuery.Params) then
  begin
    for i := 0 to FQuery.Params.Count - 1 do
    begin
      FDParam := FQuery.Params.Items[i];
      if FDParam.IsNull then
        Continue;

      if (FDParam.DataType in [ftString, ftWideString, ftMemo, ftWideMemo, ftFixedChar, ftFixedWideChar, ftFmtMemo])
         or VarIsStr(FDParam.Value) then
      begin
        S := VarToStr(FDParam.Value);
        if S <> '' then
        begin
          if Pos(#0, S) > 0 then
            S := StringReplace(S, #0, '', [rfReplaceAll]);
          if S = '' then
            FDParam.Clear
          else
          begin
            if not (FDParam.DataType in [ftString, ftWideString, ftMemo, ftWideMemo, ftFixedChar, ftFixedWideChar, ftFmtMemo]) then
              FDParam.DataType := ftWideString;
            FDParam.AsString := S;
          end;
        end
        else
          FDParam.Clear;
      end;
    end;
  end;
end;

end.
