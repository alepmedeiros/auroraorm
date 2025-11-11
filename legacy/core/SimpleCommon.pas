unit SimpleCommon;

interface

uses
  System.SysUtils,
  System.Variants,
  System.Classes,
  SimpleInterface;

type
  TSimpleCommon = class(TInterfacedObject, iSimpleCommon)
    private
    public
      constructor Create;
      destructor Destroy; override;
      class function New : iSimpleCommon;
      function MemoryStreamToOleVariant(Stream: TMemoryStream): OleVariant;
      function OleVariantToMemoryStream(Ov: OleVariant): TMemoryStream;
  end;

implementation

constructor TSimpleCommon.Create;
begin

end;

destructor TSimpleCommon.Destroy;
begin

  inherited;
end;

function TSimpleCommon.MemoryStreamToOleVariant(
  Stream: TMemoryStream): OleVariant;
var
  lData: PByteArray;
begin
  // Quando o stream estiver vazio, devolve Null para evitar criar um
  // array com byte 0 (0x00), que pode causar problemas em campos texto
  // e não é um conteúdo válido para blob.
  if (Stream = nil) or (Stream.Size = 0) then
  begin
    Result := Null;
    Exit;
  end;
  Result := VarArrayCreate([0, Stream.Size - 1], varByte);
  lData := VarArrayLock(Result);
  try
    Stream.Position := 0;
    Stream.ReadBuffer(lData^, Stream.Size);
  finally
    VarArrayUnlock(Result);
  end;
end;

class function TSimpleCommon.New : iSimpleCommon;
begin
  Result := Self.Create;
end;

function TSimpleCommon.OleVariantToMemoryStream(Ov: OleVariant): TMemoryStream;
var
  lData: PByteArray;
  lSize: Integer;
begin
  Result := TMemoryStream.Create;
  try
    lSize := (VarArrayHighBound(Ov, 1) - (VarArrayLowBound(Ov, 1) + 1));
    lData := VarArrayLock(Ov);
    try
      Result.Position := 0;
      Result.WriteBuffer(lData^, lSize);
    finally
      VarArrayUnlock(Ov);
    end;
  except
    FreeAndNil(Result);
  end;
end;

end.
