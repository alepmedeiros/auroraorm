unit SimpleLog;

interface

procedure Debug(const Msg: string);

implementation

uses
  System.SysUtils
{$IFDEF MSWINDOWS}
  , Winapi.Windows
{$ENDIF}
  ;

procedure Debug(const Msg: string);
begin
  {$IFDEF MSWINDOWS}
  OutputDebugString(PChar(Msg));
  {$ELSE}
  // On POSIX/Linux, write to stdout (visible in console logs)
  WriteLn(Msg);
  {$ENDIF}
end;

end.