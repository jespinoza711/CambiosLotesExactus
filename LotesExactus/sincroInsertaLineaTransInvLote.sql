
--[fnica].[usp_sincroInsertaLineaTransInv]
BEGIN TRAN

declare @Fuente nvarchar(20), @CODSUCURSAL NVARCHAR(4), @PAQUETE NVARCHAR(4), 
		@DOCUMENTO NVARCHAR(20) , @Articulo varchar(20), @Cantidad decimal (28,8),
		@PrecioLocal decimal (28,8), @PrecioDolar decimal (28,8), @BODEGADESTINO NVARCHAR(4)

SET @Fuente='TRASLADOAGROQUIMICOS'
SET @CODSUCURSAL='AL01'
SET @PAQUETE='MOVB'
SET @Articulo='FE00012'
SET @Cantidad=3467
SET @PrecioLocal=0
SET @PrecioDolar=0
SET @BODEGADESTINO='JT01'
SET @DOCUMENTO='TP0000020056'

DECLARE @TIPOARTICULO NVARCHAR(1),@TMPCODSUCURSAL NVARCHAR (4)

BEGIN TRY

	Create Table #Resultado (
		ID int IDENTITY,
		Bodega nvarchar(20), --COLLATE Latin1_General_CI_AS, 
		Articulo nvarchar(20),-- COLLATE Latin1_General_CI_AS, 
		Lote NVARCHAR(15), 
		Cantidad decimal(28,8) default 0 
	)
	
	DECLARE @iRwCnt INT,@Lote NVARCHAR(15),@i INT,@CantidadLote DECIMAL(28,8)
	DECLARE @Linea AS INT
	
	INSERT INTO #Resultado
	EXEC FNICA.usp_AutoSugiereLotesExactus @Articulo,@CODSUCURSAL,@BodegaDestino,@Cantidad 
	SET @iRwCnt=@@ROWCOUNT
		
	
	SET @Linea= (SELECT MAX(LINEA_DOC_INV)
	               FROM fnica.LINEA_DOC_INV WHERE DOCUMENTO_INV=@DOCUMENTO)
	IF (@Linea IS NULL)
		SET @Linea=0
		
		
	IF UPPER (@Fuente)  = 'TRASLADOAGROQUIMICOS' OR 
		UPPER (@Fuente)  = 'TRASLADOFORMULAS' OR 
		 UPPER (@Fuente)  = 'TRASLADOEQUIPOS'
	BEGIN
		
		set @i = 1
		SET @Lote=''
		set @CantidadLote = 0
		while @i <= @iRwCnt 
		begin
			select @Lote = Lote, @CantidadLote = Cantidad from #Resultado where ID = @i
					
			SET @Linea=@Linea+1
			
			INSERT FNICA.LINEA_DOC_INV(PAQUETE_INVENTARIO, DOCUMENTO_INV,
			       LINEA_DOC_INV, AJUSTE_CONFIG, ARTICULO, BODEGA,
			       LOCALIZACION, LOTE, TIPO, SUBTIPO, SUBSUBTIPO, CANTIDAD,
			       COSTO_TOTAL_LOCAL, COSTO_TOTAL_DOLAR, PRECIO_TOTAL_LOCAL,
			       PRECIO_TOTAL_DOLAR, BODEGA_DESTINO)
			VALUES (@PAQUETE,@DOCUMENTO, @Linea, '~TT~' , @Articulo, @CODSUCURSAL,'ND',@Lote,
					'T','D','', @CantidadLote,0,0, @PrecioLocal, @PrecioDolar, @BODEGADESTINO )
			
			SET @i=@i+1
		END
		
		SELECT * FROM #ResultadO
		DROP TABLE #Resultado
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
			SET @DOCUMENTO = @DOCUMENTO

			set @i = 1
			SET @Lote=''
			set @CantidadLote = 0
			while @i <= @iRwCnt 
			begin
				select @Lote = Lote, @CantidadLote = Cantidad from #Resultado where ID = @i
						
				SET @Linea=@Linea+1
				INSERT FNICA.LINEA_DOC_INV ( 
					[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
				  ,[ARTICULO],[BODEGA],LOCALIZACION, LOTE,[TIPO],[SUBTIPO],[SUBSUBTIPO]
				  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
				  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO]
					)
				
				VALUES (@PAQUETE,@DOCUMENTO, @Linea, '~VV~' , @Articulo, @TMPCODSUCURSAL,'ND',@Lote,
						'V','D','L', @CantidadLote,0,0, @PrecioLocal, @PrecioDolar, @BODEGADESTINO )
				
				SET @i=@i+1
			END
		
			SELECT * FROM #ResultadO
			DROP TABLE #Resultado
		END
	

		
		END
	END
	
END TRY
BEGIN CATCH	
	IF OBJECT_ID('tempdb..#Resultado') IS NOT NULL DROP TABLE #Resultado
	DECLARE @ERROR AS NVARCHAR(200)
    SET @ERROR=ERROR_MESSAGE() 
	RAISERROR(@Error,16,1)
	ROLLBACK
END CATCH


SELECT * FROM FNICA.LINEA_DOC_INV WHERE DOCUMENTO_INV='TP0000020056'
		