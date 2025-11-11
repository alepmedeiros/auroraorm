unit intensive.Resources.Conexao;

interface

uses
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.PG,
  FireDAC.Phys.PGDef,
  FireDAC.Stan.ExprFuncs,
{$IFDEF MSWINDOWS}
  FireDAC.VCLUI.Wait,
{$ELSE}
  FireDAC.ConsoleUI.Wait,
{$ENDIF}
  FireDAC.Comp.UI,
  Data.DB,
  FireDAC.Comp.Client,
  intensive.Resources.Interfaces,
  SimpleConfig,
  FireDAC.Moni.FlatFile,
  SimpleLog;

type
  TConexao = class(TInterfacedObject, iConexao)
    private
      FConn : TFDConnection;
      FMonitor: TFDMoniFlatFileLink;
      procedure DoAfterConnect(Sender: TObject);
    public
      constructor Create;
      destructor Destroy; override;
      class function New : iConexao;
      function Connect : TCustomConnection;
  end;

implementation

function TConexao.Connect: TCustomConnection;
begin
  Result := FConn;
end;

constructor TConexao.Create;
begin
  FConn := TFDConnection.Create(nil);
  // Enable FireDAC flat-file monitoring for this sample (logs SQL to fd_monitor.log)
  if TSimpleConfig.MonitorEnabled then
  begin
    FMonitor := TFDMoniFlatFileLink.Create(nil);
    FMonitor.FileName := ExtractFilePath(ParamStr(0)) + 'fd_monitor.log';
    FDManager.Tracing := True;
  end;
  FConn.Params.Clear;
  // Configure PostgreSQL connection here
  FConn.Params.Add('DriverID=PG');
  FConn.Params.Add('Server=localhost');
  FConn.Params.Add('Port=5432');
  FConn.Params.Add('Database=sample_simpleorm');
  FConn.Params.Add('User_Name=postgres');
  FConn.Params.Add('Password=postgres');
  FConn.Params.Add('CharacterSet=UTF8');
  // Apply schema via search_path after connecting, using compile-time/runtime config
  FConn.OnAfterConnect := DoAfterConnect;
  FConn.Connected := True;
end;

destructor TConexao.Destroy;
begin
  if Assigned(FMonitor) then
    FMonitor.DisposeOf;
  FConn.DisposeOf;
  inherited;
end;

class function TConexao.New : iConexao;
begin
  Result := Self.Create;
end;

procedure TConexao.DoAfterConnect(Sender: TObject);
var
  Schema: string;
  Q: TFDQuery;
begin
  Schema := TSimpleConfig.Schema; // defaults to 'public' when not set
  if SameText(FConn.Params.Values['DriverID'], 'PG') then
  begin
    // Apply active schema and some production-friendly settings
    FConn.ExecSQL(Format('SET search_path TO %s, public', [Schema]));
    FConn.ExecSQL('SET application_name = ''ActiveRecord_Builder''');
    // Statement and lock timeouts configured via SimpleConfig (compile-time seconds)
    FConn.ExecSQL(Format('SET statement_timeout = ''%ds''', [TSimpleConfig.StatementTimeoutSecs]));
    FConn.ExecSQL(Format('SET lock_timeout = ''%ds''', [TSimpleConfig.LockTimeoutSecs]));

    // Health-check: log current search_path to the monitor and debugger
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := FConn;
      // Log both search_path and resolved schemas
      Q.Open('SELECT current_setting(''search_path'')');
      Debug('SimpleORM sample: search_path=' + Q.Fields[0].AsString);
      Q.Close;
      Q.Open('SELECT current_schemas(true)::text');
      Debug('SimpleORM sample: current_schemas=' + Q.Fields[0].AsString);
    finally
      Q.DisposeOf;
    end;
  end;
end;

end.
