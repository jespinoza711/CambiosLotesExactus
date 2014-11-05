set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


CREATE PROCEDURE [fnica].[usp_sincroInsertaLineaTransInvTransformacionLotes]  @Fuente nvarchar(20), @CODSUCURSAL NVARCHAR(4),@Linea int,  
@noDOCUMENTO NVARCHAR(20) , @Articulo varchar(20), @Cantidad decimal (28,8),
@CostoLocal decimal (28,8), @CostoDolar decimal (28,8), @BODEGADESTINO NVARCHAR(4), @TipoTransaccion NVARCHAR(1)
AS
DECLARE @TipoTransInv NVARCHAR(10), @Tipo NVARCHAR(1), @SubTipo NVARCHAR (1), @SubSubTipo NVARCHAR(1)
DECLARE @PAQUETE NVARCHAR(4), @DOCUMENTO NVARCHAR (20)

DECLARE @AutoSuguiereLotes AS BIT


SET @AutoSuguiereLotes= CAST(( SELECT Valor
                            FROM fnica.invParametrosLOTE WHERE IDParametro='UsaLotesExactus') AS BIT)


IF UPPER (@Fuente)  = 'FORMULA'
	SET @PAQUETE = 'FORM'
IF UPPER (@Fuente)  = 'REEMPAQUE'
	SET @PAQUETE = 'REPQ'

SET @DOCUMENTO = @noDOCUMENTO

IF @TipoTransaccion = 'O' 
begin
	SET @TipoTransInv = '~OO~'
	SET @TIpo = 'O'
	SET @SubTipo = 'D'
	SET @SubSubTipo ='L'
	
	IF (@AutoSuguiereLotes=0)
	BEGIN
		INSERT FNICA.LINEA_DOC_INV ( 
			[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
		  ,[ARTICULO],[BODEGA],[TIPO],[SUBTIPO],[SUBSUBTIPO]
		  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
		  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO]
			)
		VALUES (@PAQUETE,@DOCUMENTO, @Linea, @TipoTransInv , @Articulo, @CODSUCURSAL, @TIpo,@SubTipo,@SubSubTipo, @Cantidad,
			@CostoLocal,@CostoDolar, 0, 0, @BODEGADESTINO )
	END
	ELSE
	BEGIN
		EXEC  fnica.usp_sincroInsertaLineaTransInvLoteAutoSugerido @Fuente,@CODSUCURSAL,@PAQUETE,@DOCUMENTO,@Articulo,@Cantidad,0,0,@CostoLocal,@CostoDolar,@BODEGADESTINO,@TIpo,@Lote 
	END
	
end
IF @TipoTransaccion = 'C' 
begin
	SET @TipoTransInv = '~CC~'
	SET @TIpo = 'C'
	SET @SubTipo = 'D'
	SET @SubSubTipo ='N'
	
	IF (@AutoSuguiereLotes=0)
	BEGIN
		INSERT FNICA.LINEA_DOC_INV ( 
			[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
		  ,[ARTICULO],[BODEGA],[TIPO],[SUBTIPO],[SUBSUBTIPO]
		  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
		  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,BODEGA_DESTINO, CENTRO_COSTO, CUENTA_CONTABLE
			)
		VALUES (@PAQUETE,@DOCUMENTO, @Linea, @TipoTransInv , @Articulo, @CODSUCURSAL, @TIpo,@SubTipo,@SubSubTipo, @Cantidad,
			0,0, 0, 0, @BODEGADESTINO, '00-00-00', '9-04-03-000-000' )
	END
	ELSE
	BEGIN
		EXEC  fnica.usp_sincroInsertaLineaTransInvLoteAutoSugerido @Fuente,@CODSUCURSAL,@PAQUETE,@DOCUMENTO,@Articulo,@Cantidad,0,0,@CostoLocal,@CostoDolar,@BODEGADESTINO,@TIpo,@Lote 
	END	
	
END

