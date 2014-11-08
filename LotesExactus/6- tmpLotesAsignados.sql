CREATE TABLE [fnica].[tmpLotesAsignados](
	[Fecha] DATETIME,
	[TipoDocumento] [NVARCHAR] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Documento] [nvarchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Bodega] [varchar](4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[BodegaDestino] [varchar](4) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Articulo] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Lote] [nvarchar] (15) NOT NULL,
	[TipoTran] [int] NOT NULL,
	[CantidadLote] [numeric](28, 8) NULL,
	[Cantidad] [numeric](28, 8) NULL,
 CONSTRAINT [PK_tmpLotesAsignados] PRIMARY KEY CLUSTERED 
(
	[Fecha] ASC,
	[TipoDocumento] ASC,
	[Documento] ASC,
	[Bodega] ASC,
	[BodegaDestino] ASC,
	[Articulo] ASC,
	[Lote] ASC
	
)WITH (IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

