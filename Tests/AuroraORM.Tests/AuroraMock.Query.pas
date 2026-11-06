unit AuroraMock.Query;

interface

uses
  System.Classes,
  System.SysUtils,
  Data.DB,
  FireDAC.Comp.Client,
  AuroraInterface;

type
  // Mock de iAuroraQuery para testes sem banco
  TAuroraMockQuery = class(TInterfacedObject, iAuroraQuery)
  private
    FSQL: TStringList;
    FParams: TParams;
    FDataSet: TFDMemTable;
    FInTransaction: Boolean;
    FMockRowsAffected: Integer;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    // Helpers para preparar o dataset esperado nos testes
    procedure ResetDataSet;
    procedure DefineField(const AName: string; AType: TFieldType);
    procedure AppendRow(const AValues: array of const);
    // Numero de linhas que ExecSQL deve reportar via RowsAffected (default 1) -
    // usado para simular conflito de concorrencia otimista (0 linhas).
    property MockRowsAffected: Integer read FMockRowsAffected write FMockRowsAffected;
    // iAuroraQuery
    function SQL: TStrings;
    function Params: TParams;
    function ExecSQL: iAuroraQuery;
    function DataSet: TDataSet;
    function Open(aSQL: String): iAuroraQuery; overload;
    function Open: iAuroraQuery; overload;
    function RowsAffected: Integer;
    // Clone devolve uma instancia nova e independente (dataset proprio, vazio).
    // Sub-consultas de relacionamento (HasOne/BelongsTo eager, LoadMany lazy)
    // portanto nao encontram linhas contra o mock - isso e esperado e seguro
    // (retornam nil/lista vazia); carregamento de relacionamento de verdade e
    // verificado contra SQLite real na sample AuroraHeadless, nao aqui.
    function Clone: iAuroraQuery;
    function StartTransaction: iAuroraQuery;
    function Commit: iAuroraQuery;
    function Rollback: iAuroraQuery;
    function InTransaction: Boolean;
  end;

implementation

{ TAuroraMockQuery }

constructor TAuroraMockQuery.Create;
begin
  inherited Create;
  FSQL := TStringList.Create;
  FParams := TParams.Create;
  FDataSet := TFDMemTable.Create(nil);
  FMockRowsAffected := 1;
end;

destructor TAuroraMockQuery.Destroy;
begin
  FDataSet.Free;
  FParams.Free;
  FSQL.Free;
  inherited;
end;

procedure TAuroraMockQuery.ResetDataSet;
begin
  if FDataSet.Active then
    FDataSet.Close;
  FDataSet.FieldDefs.Clear;
  FDataSet.Indexes.Clear;
end;

procedure TAuroraMockQuery.DefineField(const AName: string; AType: TFieldType);
begin
  FDataSet.FieldDefs.Add(AName, AType, 0, False);
end;

procedure TAuroraMockQuery.AppendRow(const AValues: array of const);
var
  I: Integer;
begin
  if not FDataSet.Active then
    FDataSet.CreateDataSet;
  FDataSet.Append;
  for I := 0 to High(AValues) do
  begin
    if I < FDataSet.FieldCount then
      FDataSet.Fields[I].AssignValue(AValues[I]);
  end;
  FDataSet.Post;
end;

function TAuroraMockQuery.SQL: TStrings;
begin
  Result := FSQL;
end;

function TAuroraMockQuery.Params: TParams;
begin
  Result := FParams;
end;

function TAuroraMockQuery.ExecSQL: iAuroraQuery;
begin
  // Não faz nada (sem efeitos colaterais). Somente retorna self para encadeamento.
  Result := Self;
end;

function TAuroraMockQuery.DataSet: TDataSet;
begin
  Result := FDataSet;
end;

function TAuroraMockQuery.Open(aSQL: String): iAuroraQuery;
begin
  FSQL.Text := aSQL;
  // sem execução real; o DataSet deve ser preparado via helpers nos testes
  Result := Self;
end;

function TAuroraMockQuery.Open: iAuroraQuery;
begin
  // sem execução real; mantém o SQL já configurado
  Result := Self;
end;

function TAuroraMockQuery.RowsAffected: Integer;
begin
  Result := FMockRowsAffected;
end;

function TAuroraMockQuery.Clone: iAuroraQuery;
begin
  Result := TAuroraMockQuery.Create;
end;

function TAuroraMockQuery.StartTransaction: iAuroraQuery;
begin
  Result := Self;
  FInTransaction := True;
end;

function TAuroraMockQuery.Commit: iAuroraQuery;
begin
  Result := Self;
  FInTransaction := False;
end;

function TAuroraMockQuery.Rollback: iAuroraQuery;
begin
  Result := Self;
  FInTransaction := False;
end;

function TAuroraMockQuery.InTransaction: Boolean;
begin
  Result := FInTransaction;
end;

end.
