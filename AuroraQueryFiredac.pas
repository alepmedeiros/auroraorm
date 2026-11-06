unit AuroraQueryFiredac;

interface

uses
  AuroraInterface,
  FireDAC.Comp.Client,
  System.Classes,
  Data.DB,
  FireDAC.Stan.Param,
  FireDAC.Comp.DataSet;

type
  // Implementação nativa Aurora para iAuroraQuery baseada em FireDAC (TFDQuery)
  TAuroraQueryFiredac = class(TInterfacedObject, iAuroraQuery)
  private
    FConnection: TFDConnection;
    FQuery: TFDQuery;
    FParams: TParams;
    procedure SanitizeInputs;
    procedure SyncParamsToFD;
  public
    constructor Create(aConnection: TFDConnection);
    destructor Destroy; override;
    class function New(aConnection: TFDConnection): iAuroraQuery;
    function SQL: TStrings;
    function Params: TParams;
    function ExecSQL: iAuroraQuery;
    function DataSet: TDataSet;
    function Open(aSQL: String): iAuroraQuery; overload;
    function Open: iAuroraQuery; overload;
    function RowsAffected: Integer;
    function Clone: iAuroraQuery;
    function StartTransaction: iAuroraQuery;
    function Commit: iAuroraQuery;
    function Rollback: iAuroraQuery;
    function InTransaction: Boolean;
  end;

implementation

uses
  System.SysUtils, System.Variants;

{ TAuroraQueryFiredac }

constructor TAuroraQueryFiredac.Create(aConnection: TFDConnection);
begin
  FQuery := TFDQuery.Create(nil);
  FConnection := aConnection;
  FQuery.Connection := FConnection;
  FParams := nil;
end;

destructor TAuroraQueryFiredac.Destroy;
begin
  FreeAndNil(FQuery);
  if Assigned(FParams) then
    FreeAndNil(FParams);
  inherited;
end;

class function TAuroraQueryFiredac.New(aConnection: TFDConnection): iAuroraQuery;
begin
  Result := Self.Create(aConnection);
end;

function TAuroraQueryFiredac.SQL: TStrings;
begin
  Result := FQuery.SQL;
end;

function TAuroraQueryFiredac.Params: TParams;
begin
  if not Assigned(FParams) then
    FParams := TParams.Create;
  Result := FParams;
end;

function TAuroraQueryFiredac.ExecSQL: iAuroraQuery;
begin
  Result := Self;
  SyncParamsToFD;
  SanitizeInputs;
  try
    FQuery.ExecSQL;
  except
    if InTransaction then
      Rollback;
    raise;
  end;
end;

function TAuroraQueryFiredac.DataSet: TDataSet;
begin
  Result := TDataSet(FQuery);
end;

function TAuroraQueryFiredac.Open(aSQL: String): iAuroraQuery;
begin
  Result := Self;
  FQuery.SQL.Text := aSQL;
  SyncParamsToFD;
  SanitizeInputs;
  FQuery.Open;
end;

function TAuroraQueryFiredac.Open: iAuroraQuery;
begin
  Result := Self;
  SyncParamsToFD;
  SanitizeInputs;
  FQuery.Open;
end;

procedure TAuroraQueryFiredac.SanitizeInputs;
var
  I: Integer;
  S: string;
begin
  // Remove NUL chars de SQL
  for I := 0 to FQuery.SQL.Count - 1 do
  begin
    S := FQuery.SQL[I];
    if Pos(#0, S) > 0 then
      FQuery.SQL[I] := StringReplace(S, #0, '', [rfReplaceAll]);
  end;

  // Remove NUL chars de parâmetros string
  for I := 0 to FQuery.Params.Count - 1 do
  begin
    if FQuery.Params[I].DataType in [ftString, ftWideString, ftMemo, ftWideMemo] then
    begin
      S := FQuery.Params[I].AsString;
      if Pos(#0, S) > 0 then
        FQuery.Params[I].AsString := StringReplace(S, #0, '', [rfReplaceAll]);
    end;
  end;
end;

function TAuroraQueryFiredac.RowsAffected: Integer;
begin
  Result := FQuery.RowsAffected;
end;

function TAuroraQueryFiredac.Clone: iAuroraQuery;
begin
  Result := TAuroraQueryFiredac.New(FConnection);
end;

function TAuroraQueryFiredac.StartTransaction: iAuroraQuery;
begin
  Result := Self;
  if not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

function TAuroraQueryFiredac.Commit: iAuroraQuery;
begin
  Result := Self;
  if FConnection.InTransaction then
    FConnection.Commit;
end;

function TAuroraQueryFiredac.Rollback: iAuroraQuery;
begin
  Result := Self;
  if FConnection.InTransaction then
    FConnection.Rollback;
end;

function TAuroraQueryFiredac.InTransaction: Boolean;
begin
  Result := Assigned(FConnection) and FConnection.InTransaction;
end;

procedure TAuroraQueryFiredac.SyncParamsToFD;
var
  I: Integer;
  P: TParam;
  FDPar: TFDParam;
begin
  if not Assigned(FParams) then Exit;
  // Garante que parâmetros definidos em FParams existam em FQuery.Params (FireDAC)
  for I := 0 to FParams.Count - 1 do
  begin
    P := FParams[I];
    FDPar := FQuery.Params.FindParam(P.Name);
    if FDPar = nil then
    begin
      FDPar := FQuery.Params.Add;
      FDPar.Name := P.Name;
      // Deixe FireDAC inferir tipos quando possível; ajuste básico:
      case P.DataType of
        ftUnknown: FDPar.DataType := ftUnknown;
        else FDPar.DataType := P.DataType;
      end;
      FDPar.ParamType := ptInput;
    end;
    FDPar.Value := P.Value;
  end;
end;

end.