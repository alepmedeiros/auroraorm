unit AuroraInterface;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  System.TypInfo,
  {$IFNDEF CONSOLE}
    {$IFDEF FMX}
      FMX.Forms,
    {$ELSE}
      Vcl.Forms,
    {$ENDIF}
  {$ENDIF}
  System.SysUtils;

type
  iAuroraDAOSQLAttribute<T : class> = interface;

  iAuroraDAO<T : class> = interface
    ['{61A7DCD1-2E9F-4E1D-9C83-2C2E2C7B1201}']
    {$IFNDEF CONSOLE}
    function Insert: iAuroraDAO<T>; overload;
    function Update : iAuroraDAO<T>; overload;
    function Delete : iAuroraDAO<T>; overload;
    {$ENDIF}
    function Insert(var aValue : T) : iAuroraDAO<T>; overload;
    function Update(var aValue : T) : iAuroraDAO<T>; overload;
    function Delete(aValue : T) : iAuroraDAO<T>; overload;
    function LastID : iAuroraDAO<T>;
    function LastRecord : iAuroraDAO<T>;
    function Delete(aField : String; aValue : String) : iAuroraDAO<T>; overload;
    function DataSource( aDataSource : TDataSource) : iAuroraDAO<T>;
    function Find(aBindList : Boolean = True) : iAuroraDAO<T>; overload;
    function Find(var aList : TObjectList<T>) : iAuroraDAO<T> ; overload;
    function Find(aId : Integer) : T; overload;
    function Find(aID: String): T; overload;
    function FindOneWhere(aKey : String; aValue : Variant) : T;
    function FindWhere(aKey : String; aValue : Variant) : TObjectList<T>;
    function Find(aKey : String; aValue : Variant) : iAuroraDAO<T>; overload;
    function SQL : iAuroraDAOSQLAttribute<T>;
    {$IFNDEF CONSOLE}
    function BindForm(aForm : TForm)  : iAuroraDAO<T>;
    {$ENDIF}
  end;

  iAuroraDAOSQLAttribute<T : class> = interface
    ['{C9695C1B-1B0F-4AF8-9C01-0C9E512CFB2C}']
    function Fields (aSQL : String) : iAuroraDAOSQLAttribute<T>; overload;
    function Where (aSQL : String) : iAuroraDAOSQLAttribute<T>; overload;
    function OrderBy (aSQL : String) : iAuroraDAOSQLAttribute<T>; overload;
    function GroupBy (aSQL : String) : iAuroraDAOSQLAttribute<T>; overload;
    function Join (aSQL : String) : iAuroraDAOSQLAttribute<T>; overload;
    function Join : String; overload;
    function Fields : String; overload;
    function Where : String; overload;
    function OrderBy : String; overload;
    function GroupBy : String; overload;
    function Clear : iAuroraDAOSQLAttribute<T>;
    function &End : iAuroraDAO<T>;
  end;

  iAuroraRTTI<T : class> = interface
    ['{B5C098F5-2764-4C35-84D2-7C1E9B1C5F4C}']
    function TableName(var aTableName: String): iAuroraRTTI<T>;
    function ClassName (var aClassName : String) : iAuroraRTTI<T>;
    function DictionaryFields(var aDictionary : TDictionary<string, variant>) : iAuroraRTTI<T>;
    function DictionaryTypeFields(var aDictionary: TDictionary<string, TFieldType>): iAuroraRTTI<T>;
    function ListFields (var List : TList<String>) : iAuroraRTTI<T>;
    function Update (var aUpdate : String) : iAuroraRTTI<T>;
    function Where (var aWhere : String) : iAuroraRTTI<T>;
    function Fields (var aFields : String) : iAuroraRTTI<T>;
    function FieldsInsert (var aFields : String) : iAuroraRTTI<T>;
    function Param (var aParam : String) : iAuroraRTTI<T>;
    function DataSetToEntityList (aDataSet : TDataSet; var aList : TObjectList<T>) : iAuroraRTTI<T>;
    function DataSetToEntity (aDataSet : TDataSet; var aEntity : T) : iAuroraRTTI<T>;
    function PrimaryKey(var aPK : String) : iAuroraRTTI<T>;
    function GetDataType(aCampo: String; var aType: TFieldType): iAuroraRTTI<T>;
    {$IFNDEF CONSOLE}
    function BindClassToForm (aForm : TForm;  const aEntity : T) : iAuroraRTTI<T>;
    function BindFormToClass (aForm : TForm; var aEntity : T) : iAuroraRTTI<T>;
    {$ENDIF}
  end;

  iAuroraSQL<T> = interface
    ['{EE1116E8-66A5-4BA3-A4E9-AD0596E5C55B}']
    function Insert (var aSQL : String) : iAuroraSQL<T>;
    function Update (var aSQL : String) : iAuroraSQL<T>;
    function Delete (var aSQL : String) : iAuroraSQL<T>;
    function Select (var aSQL : String) : iAuroraSQL<T>;
    function SelectId(var aSQL: String): iAuroraSQL<T>;
    function Fields (aSQL : String) : iAuroraSQL<T>;
    function Where (aSQL : String) : iAuroraSQL<T>;
    function OrderBy (aSQL : String) : iAuroraSQL<T>;
    function GroupBy (aSQL : String) : iAuroraSQL<T>;
    function Join (aSQL : String) : iAuroraSQL<T>;
    function LastID (var aSQL : String) : iAuroraSQL<T>;
    function LastRecord (var aSQL : String) : iAuroraSQL<T>;
  end;

  iAuroraQuery = interface
    ['{A6BBC286-23E1-4D9D-A6B8-4B2EEB1E7C51}']
    function SQL : TStrings;
    function Params : TParams;
    function ExecSQL : iAuroraQuery;
    function DataSet : TDataSet;
    function Open(aSQL : String) : iAuroraQuery; overload;
    function Open : iAuroraQuery; overload;
  end;

  iAuroraCommon = interface
    function MemoryStreamToOleVariant(Stream: TMemoryStream): OleVariant;
    function OleVariantToMemoryStream(Ov: OleVariant): TMemoryStream;
  end;

implementation

end.