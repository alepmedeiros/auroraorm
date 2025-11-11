program AuroraORM.Tests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.XML.NUnit,
  Aurora.Test.DAO in 'Aurora.Test.DAO.pas',
  Aurora.Test.JSON in 'Aurora.Test.JSON.pas',
  AuroraMock.SimpleQuery in 'AuroraMock.SimpleQuery.pas';

var
  runner : ITestRunner;
  results : IRunResults;
  logger : ITestLogger;
  nunitLogger : ITestLogger;
begin
  try
    TDUnitX.CheckCommandLine;
    runner := TDUnitX.CreateRunner;
    runner.UseRTTI := True;
    runner.FailsOnNoAsserts := False;

    // Console
    logger := TDUnitXConsoleLogger.Create(True);
    runner.AddLogger(logger);

    // NUnit XML
    nunitLogger := TDUnitXLoggerNUnit.Create;
    runner.AddLogger(nunitLogger);

    results := runner.Execute;

    if results.AllPassed then
      ExitCode := 0
    else
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.