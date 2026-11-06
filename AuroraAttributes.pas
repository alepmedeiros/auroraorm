unit AuroraAttributes;

interface

uses
  System.RTTI, System.Variants, System.Classes;

type
  Tabela = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(aName: string);
    property Name: string read FName;
  end;

  Campo = class(TCustomAttribute)
  private
    FName: string;
    FTipo: String;
  public
    Constructor Create(aName: string; aTipo: String = '');
    property Name: string read FName;
    property Tipo: String read FTipo write FTipo;
  end;

  PK = class(TCustomAttribute)
  end;

  FK = class(TCustomAttribute)
  private
    FTable: string;
    FColumn: string;
  public
    constructor Create(const aTable, aColumn: string);
    property Table: string read FTable;
    property Column: string read FColumn;
  end;

  NotNull = class(TCustomAttribute)
  end;

  Ignore = class(TCustomAttribute)
  end;

  AutoInc = class(TCustomAttribute)
  end;

  // Controle de concorrencia otimista (analogo a @Version do Hibernate/JPA).
  // Campo numerico incrementado pelo proprio Aurora a cada UPDATE bem-sucedido;
  // o WHERE do UPDATE passa a exigir o valor de versao lido, e 0 linhas afetadas
  // significa que outra transacao alterou o registro entre o Find e o Update.
  Version = class(TCustomAttribute)
  end;

  NumberOnly = class(TCustomAttribute)
  end;

  Blob = class(TCustomAttribute)
  end;

  Unique = class(TCustomAttribute)
  end;

  Index = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const aName: string = '');
    property Name: string read FName;
  end;

  // Validação: e-mail em formato válido
  Email = class(TCustomAttribute)
  end;

  // Controle específico de exposição JSON
  JsonIgnore = class(TCustomAttribute)
  end;

  JsonCampo = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const aName: string);
    property Name: string read FName;
  end;

  Bind = class(TCustomAttribute)
  private
    FField: String;
    procedure SetField(const Value: String);
  public
    constructor Create (aField : String);
    property Field : String read FField write SetField;
  end;

  Display = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const aName: string);
    property Name: string read FName write FName;
  end;

  Format = class(TCustomAttribute)
  private
    FMaxSize: integer;
    FPrecision: integer;
    FMask: string;
    FMinSize: integer;
  public
    property MaxSize: integer read FMaxSize write FMaxSize;
    property MinSize: integer read FMinSize write FMinSize;
    property Precision: integer read FPrecision write FPrecision;
    property Mask: string read FMask write FMask;
    function GetNumericMask: string;
    constructor Create(const aSize: Integer; const aPrecision: integer = 0); overload;
    constructor Create(const aMask: string); overload;
    constructor Create(const aRange: array of Integer); overload;
  end;

  // EntityName referencia o nome da classe RTTI do lado relacionado (ex.: 'TProfile').
  // LocalKey/ForeignKey sao opcionais; quando omitidos, a convencao e resolvida
  // pelo AuroraMetadata a partir do tipo dono do atributo (ver AuroraMetadata.pas).
  Relationship = class abstract(TCustomAttribute)
  private
    FEntityName: string;
    FLocalKey: string;
    FForeignKey: string;
    FJoinTable: string;
  public
    constructor Create(const aEntityName: string; const aLocalKey: string = ''; const aForeignKey: string = ''; const aJoinTable: string = '');
    property EntityName: string read FEntityName write FEntityName;
    property LocalKey: string read FLocalKey write FLocalKey;
    property ForeignKey: string read FForeignKey write FForeignKey;
    property JoinTable: string read FJoinTable write FJoinTable;
  end;

  // 1:1, lado que possui a PK referenciada (ex.: TUser tem [HasOne('TProfile')]).
  // Convencao: LocalKey = PK de TUser, ForeignKey = '<tabela_singular>_id' em TProfile.
  HasOne = class(Relationship)
  end;

  // 1:1 ou N:1, lado que possui a FK (ex.: TProfile tem [BelongsTo('TUser')]).
  // Convencao: LocalKey = '<tabela_singular_alvo>_id' nesta entidade, ForeignKey = PK do alvo.
  BelongsTo = class(Relationship)
  end;

  // 1:N, lado "um" (ex.: TUser tem [HasMany('TOrder')]). Carregamento lazy.
  // Convencao: LocalKey = PK de TUser, ForeignKey = '<tabela_singular>_id' em TOrder.
  HasMany = class(Relationship)
  end;

  // N:N via tabela de juncao. JoinTable e obrigatorio (nao ha convencao segura).
  BelongsToMany = class(Relationship)
  end;

implementation

{ Bind }

constructor Bind.Create(aField: String);
begin
  FField := aField;
end;

procedure Bind.SetField(const Value: String);
begin
  FField := Value;
end;

{ Tabela }

constructor Tabela.Create(aName: string);
begin
  FName := aName;
end;

{ Campo }

constructor Campo.Create(aName: string; aTipo: String = '');
begin
  FName := aName;
  FTipo := aTipo;
end;

{ Display }

constructor Display.Create(const aName: string);
begin
  FName := aName;
end;

{ JsonCampo }

constructor JsonCampo.Create(const aName: string);
begin
  FName := aName;
end;

{ Formato }

constructor Format.Create(const aSize, aPrecision: integer);
begin
  FMaxSize := aSize;
  FPrecision := aPrecision;
end;

constructor Format.Create(const aMask: string);
begin
  FMask := aMask;
end;

constructor Format.Create(const aRange: array of Integer);
begin
  FMinSize := aRange[0];
  FMaxSize := aRange[High(aRange)];
end;

function Format.GetNumericMask: string;
var
  sTamanho, sPrecisao: string;
begin
  sTamanho := StringOfChar('0', FMaxSize - FPrecision);
  sPrecisao := StringOfChar('0', FPrecision);

  Result := sTamanho + '.' + sPrecisao;
end;

{ Relationship }

constructor Relationship.Create(const aEntityName: string; const aLocalKey: string; const aForeignKey: string; const aJoinTable: string);
begin
  FEntityName := aEntityName;
  FLocalKey := aLocalKey;
  FForeignKey := aForeignKey;
  FJoinTable := aJoinTable;
end;

{ FK }

constructor FK.Create(const aTable, aColumn: string);
begin
  FTable := aTable;
  FColumn := aColumn;
end;

{ Index }

constructor Index.Create(const aName: string);
begin
  FName := aName;
end;

end.
