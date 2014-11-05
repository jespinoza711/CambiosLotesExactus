
ALTER PROCEDURE [fnica].[usp_sincroInsertaLineaTransInvLotes] @Fuente nvarchar(20), @CODSUCURSAL NVARCHAR(4),@Linea int,  
@noDOCUMENTO NVARCHAR(20) , @Articulo varchar(20), @Cantidad decimal (28,8),
@PrecioLocal decimal (28,8), @PrecioDolar decimal (28,8),@CostoLocal decimal (28,8), @CostoDolar decimal (28,8), @BODEGADESTINO NVARCHAR(4),
@Lote NVARCHAR(15),@TipoTran AS NVARCHAR(1)
	 
AS

DECLARE @PAQUETE NVARCHAR(4), @DOCUMENTO NVARCHAR (20), @TIPOARTICULO NVARCHAR(1),@TMPCODSUCURSAL NVARCHAR (4)
DECLARE @AutoSuguiereLotes AS BIT


SET @AutoSuguiereLotes= CAST(( SELECT Valor
                            FROM fnica.invParametrosLOTE WHERE IDParametro='UsaLotesExactus') AS BIT)


-- THIS WAS BEFORE ON LINE
IF UPPER (@Fuente)  = 'SOLICITUD'
BEGIN
	
	SET @PAQUETE = 'TR'+SUBSTRING(@BODEGADESTINO,1, 2)
	SET @DOCUMENTO = @noDOCUMENTO
	SET @TipoTran='J'


	IF (@AutoSuguiereLotes=0)
	BEGIN
		INSERT FNICA.LINEA_DOC_INV ( 
				[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
			  ,[ARTICULO],[BODEGA],LOCALIZACION, LOTE,[TIPO],[SUBTIPO],[SUBSUBTIPO]
			  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
			  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO]
				)
		VALUES (@PAQUETE,@DOCUMENTO, @Linea, '~TT~' , @Articulo, @CODSUCURSAL,'ND',@Lote ,'T','D','', @Cantidad,
				0,0, @PrecioLocal, @PrecioDolar, @BODEGADESTINO )
			
	END
	ELSE
	BEGIN
		EXEC  fnica.usp_sincroInsertaLineaTransInvLoteAutoSugerido @Fuente,@CODSUCURSAL,@PAQUETE,@DOCUMENTO,@Articulo,@Cantidad,@PrecioLocal,@PrecioDolar,@CostoLocal,@CostoDolar,@BODEGADESTINO,@TipoTran,@Lote 
	END

END
-- ON LINE
IF UPPER (@Fuente)  = 'TRASLADOAGROQUIMICOS'
BEGIN
	
	SET @PAQUETE = 'MOVB'
	SET @DOCUMENTO = @noDOCUMENTO
	SET @TipoTran='J'

	IF (@AutoSuguiereLotes=0)
	BEGIN
		INSERT FNICA.LINEA_DOC_INV ( 
				[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
			  ,[ARTICULO],[BODEGA],LOCALIZACION, LOTE,[TIPO],[SUBTIPO],[SUBSUBTIPO]
			  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
			  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO]
				)
		VALUES (@PAQUETE,@DOCUMENTO, @Linea, '~TT~' , @Articulo, @CODSUCURSAL,'ND',@Lote, 'T','D','', @Cantidad,
				0,0, @PrecioLocal, @PrecioDolar, @BODEGADESTINO )
	END
	ELSE
	BEGIN
		EXEC  fnica.usp_sincroInsertaLineaTransInvLoteAutoSugerido @Fuente,@CODSUCURSAL,@PAQUETE,@DOCUMENTO,@Articulo,@Cantidad,@PrecioLocal,@PrecioDolar,@CostoLocal,@CostoDolar,@BODEGADESTINO,@TipoTran,@Lote 
	END


END

IF UPPER (@Fuente)  = 'TRASLADOFORMULAS'
BEGIN
	
	SET @PAQUETE = 'MOVC'
	SET @DOCUMENTO = @noDOCUMENTO
	SET @TipoTran='J'

	IF (@AutoSuguiereLotes=0)
	BEGIN
		INSERT FNICA.LINEA_DOC_INV ( 
				[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
			  ,[ARTICULO],[BODEGA],LOCALIZACION, LOTE,[TIPO],[SUBTIPO],[SUBSUBTIPO]
			  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
			  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO]
				)
		VALUES (@PAQUETE,@DOCUMENTO, @Linea, '~TT~' , @Articulo, @CODSUCURSAL,'ND',@Lote, 'T','D','', @Cantidad,
				0,0, @PrecioLocal, @PrecioDolar, @BODEGADESTINO )
	END
	ELSE
	BEGIN
		EXEC  fnica.usp_sincroInsertaLineaTransInvLoteAutoSugerido @Fuente,@CODSUCURSAL,@PAQUETE,@DOCUMENTO,@Articulo,@Cantidad,@PrecioLocal,@PrecioDolar,@CostoLocal,@CostoDolar,@BODEGADESTINO,@TipoTran,@Lote 
	END

END

IF UPPER (@Fuente)  = 'TRASLADOEQUIPOS'
BEGIN
	
	SET @PAQUETE = 'MOVE'
	SET @DOCUMENTO = @noDOCUMENTO
	SET @TipoTran='J'

	IF (@AutoSuguiereLotes=0)
	BEGIN
		INSERT FNICA.LINEA_DOC_INV ( 
				[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
			  ,[ARTICULO],[BODEGA],LOCALIZACION, LOTE,[TIPO],[SUBTIPO],[SUBSUBTIPO]
			  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
			  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO]
				)
		VALUES (@PAQUETE,@DOCUMENTO, @Linea, '~TT~' , @Articulo, @CODSUCURSAL,'ND',@Lote, 'T','D','', @Cantidad,
				0,0, @PrecioLocal, @PrecioDolar, @BODEGADESTINO )
	END
	ELSE
	BEGIN
		EXEC  fnica.usp_sincroInsertaLineaTransInvLoteAutoSugerido @Fuente,@CODSUCURSAL,@PAQUETE,@DOCUMENTO,@Articulo,@Cantidad,@PrecioLocal,@PrecioDolar,@CostoLocal,@CostoDolar,@BODEGADESTINO,@TipoTran,@Lote 
	END

END


IF UPPER (@Fuente)  = 'FACTURACION'
BEGIN
	SET @TIPOARTICULO = (SELECT TIPO FROM EXACTUS.FNICA.ARTICULO WHERE ARTICULO = @Articulo )
	IF 	@TIPOARTICULO = 'T'
	BEGIN
		-- Esto fue para el caso de Chinandega Central
	
		SET @TMPCODSUCURSAL = @CODSUCURSAL
		IF  @CODSUCURSAL = 'CH00'
		BEGIN
			set @CODSUCURSAL = 'CC00'
		END
				SET @PAQUETE = 'FA'+SUBSTRING(@CODSUCURSAL,1, 2)
				SET @DOCUMENTO = @noDOCUMENTO
		
		SET @TipoTran='J'
		
		IF (@AutoSuguiereLotes=0)
		BEGIN
			INSERT FNICA.LINEA_DOC_INV ( 
					[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
				  ,[ARTICULO],[BODEGA],[TIPO],[SUBTIPO],[SUBSUBTIPO]
				  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
				  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO]
					)
			VALUES (@PAQUETE,@DOCUMENTO, @Linea, '~VV~' , @Articulo, @TMPCODSUCURSAL, 'V','D','L', @Cantidad,
					0,0, @PrecioLocal, @PrecioDolar, @BODEGADESTINO )
		END
		ELSE
		BEGIN
			EXEC  fnica.usp_sincroInsertaLineaTransInvLoteAutoSugerido @Fuente,@CODSUCURSAL,@PAQUETE,@DOCUMENTO,@Articulo,@Cantidad,@PrecioLocal,@PrecioDolar,@CostoLocal,@CostoDolar,@BODEGADESTINO,@TipoTran,@Lote 
		END
	END
END




IF UPPER (@Fuente)  = 'DEVOLUCION'
BEGIN
	SET @TIPOARTICULO = (SELECT TIPO FROM EXACTUS.FNICA.ARTICULO WHERE ARTICULO = @Articulo )
	IF 	@TIPOARTICULO = 'T'
	BEGIN
		-- Esto fue para el caso de Chinandega Central
	
	SET @TMPCODSUCURSAL = @CODSUCURSAL
	IF  @CODSUCURSAL = 'CH00'
	BEGIN
		set @CODSUCURSAL = 'CC00'
	END
			SET @PAQUETE = 'DEVA'
			SET @DOCUMENTO = @noDOCUMENTO
		
		
			
		SELECT @CostoLocal= COSTOLOCAL,@CostoDolar=COSTODOLAR FROM fnica.fafFACTURADETALLE(NOLOCK)  WHERE CODSUCURSAL=@TMPCODSUCURSAL AND FACTURA=CAST(CAST(RIGHT(@DOCUMENTO,10) AS DECIMAL) AS NVARCHAR(10)) AND ARTICULO=@Articulo

		SET @TipoTran='J'
		
		IF (@AutoSuguiereLotes=0)
		BEGIN
			INSERT FNICA.LINEA_DOC_INV ( 
					[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
				  ,[ARTICULO],[BODEGA],[TIPO],[SUBTIPO],[SUBSUBTIPO]
				  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
				  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO]
					)
			VALUES (@PAQUETE,@DOCUMENTO, @Linea, '~VV~' , @Articulo, @TMPCODSUCURSAL, 'V','D','L', @Cantidad * -1,
					@CostoLocal,@CostoDolar, @PrecioLocal, @PrecioDolar, @BODEGADESTINO )
		END
		ELSE
		BEGIN
			EXEC  fnica.usp_sincroInsertaLineaTransInvLoteAutoSugerido @Fuente,@CODSUCURSAL,@PAQUETE,@DOCUMENTO,@Articulo,@Cantidad,@PrecioLocal,@PrecioDolar,@CostoLocal,@CostoDolar,@BODEGADESTINO,@TipoTran,@Lote 
		END
	END
END






