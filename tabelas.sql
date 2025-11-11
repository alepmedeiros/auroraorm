CREATE TABLE public.certificados (
	id varchar(255) DEFAULT gen_random_uuid() NOT NULL,
	arquivo bytea NULL,
	senha varchar(100) NULL,
	email varchar(100) NULL,
	id_empresa varchar(255) NULL
);

CREATE TABLE public.confnfe (
	id varchar(255) DEFAULT gen_random_uuid() NOT NULL,
	ativo bool NULL,
	id_empresa varchar(255) NOT NULL,
	producao int4 NULL,
	tipoemissao int4 DEFAULT 1 NULL,
	CONSTRAINT confnfe_pk PRIMARY KEY (id)
);

CREATE TABLE public.empresa (
	cpfcnpj varchar(100) NULL,
	inscricaomunicipal varchar(100) NULL,
	inscricaoestadual varchar(100) NULL,
	razaosocial varchar(100) NULL,
	nomefantasia varchar(100) NULL,
	simplesnacional bool NULL,
	regimetributario int4 NULL,
	incentivofiscal bool NULL,
	incentivadorcultural bool NULL,
	regimetributarioespecial int4 NULL,
	email varchar(100) NULL,
	cnae varchar NULL,
	inscricaoestadualst varchar NULL,
	telefone varchar(100) NULL,
	id varchar(255) DEFAULT gen_random_uuid() NULL,
	id_conf varchar NULL
);

CREATE TABLE public.endereco (
	id varchar(255) DEFAULT gen_random_uuid() NULL,
	bairro varchar(100) NULL,
	cep varchar(50) NULL,
	codigocidade varchar(30) NULL,
	estado varchar(100) NULL,
	logradouro varchar(100) NULL,
	numero varchar(100) NULL,
	tipologradouro int4 NULL,
	codigopais int4 NULL,
	complemento varchar(100) NULL,
	descricaocidade varchar(100) NULL,
	descricaopais varchar(100) NULL,
	tipobairro int4 NULL,
	id_empresa varchar(255) NULL,
	id_destinatario varchar(255) NULL
);

CREATE TABLE public.errosnfe (
	id varchar(10) NULL,
	motivo varchar(30) NULL,
	descricao varchar(255) NULL
);

CREATE TABLE public.logs (
	id varchar(255) DEFAULT gen_random_uuid() NOT NULL,
	descricao varchar(5000) NULL,
	"xml" bytea NULL,
	"json" bytea NULL,
	datahora information_schema."time_stamp" DEFAULT CURRENT_TIMESTAMP NULL,
	mensagem bytea NULL,
	CONSTRAINT logs_pk PRIMARY KEY (id)
);

CREATE TABLE public.notasfiscais (
	id varchar(255) DEFAULT gen_random_uuid() NOT NULL,
	ambiente varchar(255) NULL,
	created timestamp NULL,
	status int4 NULL,
	motivo varchar(255) NULL,
	protocolo varchar(255) NULL,
	chave varchar(255) NULL,
	linkpdf varchar(5000) NULL,
	linkxml varchar(5000) NULL,
	id_empresa varchar(255) NULL,
	recibo varchar(255) NULL,
	linkcancelamento varchar(5000) NULL,
	tipo int4 NULL,
	linkcorrecao varchar(5000) NULL,
	linkinutilizacao varchar(5000) NULL,
	linkevento varchar(5000) NULL,
	linkeventopdf varchar(5000) NULL,
	infinut varchar(255) NULL,
	seqevento int4 DEFAULT 0 NULL,
	CONSTRAINT notasfiscais_pk PRIMARY KEY (id)
);