unit AuroraValidator;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Variants,
  System.Generics.Collections,
  System.RegularExpressions,
  AuroraAttributes;

type
  TAuroraValidationError = record
    Field: string;
    Message: string;
    class function Create(const AField, AMessage: string): TAuroraValidationError; static;
  end;

  TAuroraValidator = class
  public
    class function Validate<T: class, constructor>(const AEntity: T): TList<TAuroraValidationError>; static;
  end;

implementation

class function TAuroraValidator.Validate<T>(const AEntity: T): TList<TAuroraValidationError>;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  FieldName: string;
  ValStr: string;
  V: TValue;
  Fmt: Format;
  HasNotNull: Boolean;
  HasNumberOnly: Boolean;
  HasEmail: Boolean;
  Len: Integer;
  RegexEmail: TRegEx;
begin
  Result := TList<TAuroraValidationError>.Create;
  if not Assigned(AEntity) then Exit;

  RegexEmail := TRegEx.Create('^([^\s@]+)@([^\s@]+)\.[^\s@]+$');

  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(TypeInfo(T));
  for Prop in Typ.GetProperties do
  begin
    // Descobre nome do campo mapeado [Campo]
    FieldName := '';
    for Attr in Prop.GetAttributes do
      if Attr is Campo then
        FieldName := Campo(Attr).Name;
    if FieldName = '' then
      Continue;

    // Lê valor atual
    V := Prop.GetValue(TObject(AEntity));
    ValStr := '';
    if not V.IsEmpty then
      case Prop.PropertyType.TypeKind of
        tkString, tkUString, tkWString:
          ValStr := V.AsString;
        tkInteger:
          ValStr := V.ToString;
        tkInt64:
          ValStr := V.ToString;
        tkFloat:
          ValStr := V.ToString;
        tkEnumeration:
          ValStr := V.ToString;
      else
        ValStr := V.ToString;
      end;

    // Coleta atributos relevantes
    HasNotNull := False;
    HasNumberOnly := False;
    HasEmail := False;
    Fmt := nil;
    for Attr in Prop.GetAttributes do
    begin
      if Attr is NotNull then HasNotNull := True;
      if Attr is NumberOnly then HasNumberOnly := True;
      if Attr is Email then HasEmail := True;
      if Attr is Format then Fmt := Format(Attr);
    end;

    // Regra: NotNull
    if HasNotNull then
    begin
      case Prop.PropertyType.TypeKind of
        tkString, tkUString, tkWString:
          if Trim(ValStr) = '' then
            Result.Add(TAuroraValidationError.Create(FieldName, 'não pode ser vazio'));
        tkVariant:
          if VarIsEmpty(V.AsVariant) or VarIsNull(V.AsVariant) then
            Result.Add(TAuroraValidationError.Create(FieldName, 'não pode ser nulo'));
      else
        // Para tipos numéricos, NotNull não se aplica diretamente (não há null em tipos primitivos)
        // Se desejar tratar 0 como inválido, isso pode ser habilitado futuramente.
      end;
    end;

    // Regra: NumberOnly
    if HasNumberOnly then
    begin
      if (Prop.PropertyType.TypeKind in [tkString, tkUString, tkWString]) then
      begin
        if (ValStr <> '') and not TRegEx.IsMatch(ValStr, '^\d+$') then
          Result.Add(TAuroraValidationError.Create(FieldName, 'deve conter apenas números'));
      end
      else
      begin
        // Para tipos não string, NumberOnly é redundante
      end;
    end;

    // Regra: Email
    if HasEmail then
    begin
      if (Prop.PropertyType.TypeKind in [tkString, tkUString, tkWString]) then
      begin
        if (Trim(ValStr) <> '') and not RegexEmail.IsMatch(ValStr) then
          Result.Add(TAuroraValidationError.Create(FieldName, 'e-mail inválido'))
        else if Trim(ValStr) = '' then
          Result.Add(TAuroraValidationError.Create(FieldName, 'e-mail não pode ser vazio'));
      end
      else
      begin
        // Email só faz sentido para propriedades string
      end;
    end;

    // Regra: Format (MinSize/MaxSize)
    if Assigned(Fmt) then
    begin
      if (Prop.PropertyType.TypeKind in [tkString, tkUString, tkWString]) then
      begin
        Len := Length(ValStr);
        if (Fmt.MinSize > 0) and (Len < Fmt.MinSize) then
          Result.Add(TAuroraValidationError.Create(FieldName,
            System.SysUtils.Format('tamanho mínimo é %d (atual: %d)', [Fmt.MinSize, Len])));
        if (Fmt.MaxSize > 0) and (Len > Fmt.MaxSize) then
          Result.Add(TAuroraValidationError.Create(FieldName,
            System.SysUtils.Format('tamanho máximo é %d (atual: %d)', [Fmt.MaxSize, Len])));
      end
      else
      begin
        // Poderíamos aplicar Precision para floats no futuro
      end;
    end;
  end;
end;

class function TAuroraValidationError.Create(const AField, AMessage: string): TAuroraValidationError;
begin
  Result.Field := AField;
  Result.Message := AMessage;
end;

end.