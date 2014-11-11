
-- #1-------
CREATE PROCEDURE FNICA.usp_AutoSugiereLotesExactus @Articulo AS NVARCHAR(20),
													@Bodega AS NVARCHAR(10),
													@BodegaDestino AS NVARCHAR(10),
													@Cantidad AS DECIMAL(20,8)

AS 
/*SET @Articulo='FE00012'
SET @Bodega='AL01'
SET @BodegaDestino='JT01'
SET @Cantidad=3200*/

--Verificar Existencias
IF NOT EXISTS(SELECT sum(CANT_DISPONIBLE)  FROM fnica.EXISTENCIA_LOTE WHERE Articulo=@Articulo AND Bodega=@Bodega
				HAVING SUM(CANT_DISPONIBLE)>=@Cantidad)
BEGIN
	RAISERROR( 'No hay suficientes existencias para suplir el pedido' ,16,1)
	RETURN
END


declare @Lote NVARCHAR(15),
		@i INT,  
		@CantidadLote decimal (28,8), 
		@Completado bit, 
		@CantidadOrden DECIMAL(28,8),
		@CantidadAsignada decimal(28,8)

declare @iRwCnt int 

Create Table #Resultado (
	Bodega nvarchar(20), --COLLATE Latin1_General_CI_AS, 
	Articulo nvarchar(20),-- COLLATE Latin1_General_CI_AS, 
	Lote NVARCHAR(15), 
	Cantidad decimal(28,8) default 0 
)
		
Create Table #ProductoLote ( 
	ID int identity(1,1), 
	Bodega nvarchar(20), 
	Articulo nvarchar(20), 
	Lote NVARCHAR(15), 
	Existencia decimal(28,8) default 0  
)

create clustered index idx_tmp on #ProductoLote(ID) WITH FILLFACTOR = 100

/*Existencias*/
insert #ProductoLote (BODEGA, ARTICULO, Lote, Existencia)
SELECT A.BODEGA,A.ARTICULO,A.LOTE,A.CANT_DISPONIBLE
  FROM fnica.EXISTENCIA_LOTE A
INNER JOIN fnica.LOTE B ON B.ARTICULO = A.ARTICULO AND B.LOTE = A.LOTE 
WHERE A.ARTICULO=@Articulo AND BODEGA=@Bodega AND A.CANT_DISPONIBLE>0 
ORDER BY B.FECHA_VENCIMIENTO ASC 


SET @iRwCnt=@@ROWCOUNT
SET @CantidadOrden=@Cantidad
set @i = 1
set @Completado = 0
set @CantidadLote = 0
set @CantidadAsignada = 0
while @i <= @iRwCnt and @Completado = 0
begin
	select @Lote = Lote, @CantidadLote = Existencia from #ProductoLote where ID = @i
	if @CantidadOrden  <= @CantidadLote
	begin
		set @CantidadAsignada = @CantidadOrden
		insert #Resultado ( Bodega, Articulo, Lote, Cantidad )
		values ( @Bodega, @Articulo, @Lote, @CantidadAsignada )
		set @Completado = 1

	end
	else
	begin
		set @CantidadAsignada = @CantidadLote
	
		insert #Resultado ( Bodega, Articulo, Lote, Cantidad )
		values ( @Bodega, @Articulo, @Lote, @CantidadAsignada )
		set @CantidadOrden = @CantidadOrden - @CantidadLote

	end
		set @i = @i + 1
END

SELECT Bodega, Articulo, Lote, Cantidad FROM #Resultado


drop table #Resultado
drop table #ProductoLote


GO 


--#2

CREATE PROCEDURE fnica.usp_sincroInsertaLineaTransInvLoteAutoSugerido
	@Fuente nvarchar(20), @CODSUCURSAL NVARCHAR(4), @PAQUETE NVARCHAR(4), 
	@DOCUMENTO NVARCHAR(20) , @Articulo varchar(20), @Cantidad decimal (28,8),
	@PrecioLocal decimal (28,8), @PrecioDolar decimal (28,8),
	@CostoLocal DECIMAL(28,8),@CostoDolar DECIMAL(28,8), @BODEGADESTINO NVARCHAR(4),@TipoTransaccion NVARCHAR(1),
	@LoteCompra AS NVARCHAR(15)

AS 

/*
declare @Fuente nvarchar(20), @CODSUCURSAL NVARCHAR(4), @PAQUETE NVARCHAR(4), 
		@DOCUMENTO NVARCHAR(20) , @Articulo varchar(20), @Cantidad decimal (28,8),
		@PrecioLocal decimal (28,8), @PrecioDolar decimal (28,8),
		@CostoLocal DECIMAL(28,8),@CostoDolar DECIMAL(28,8), @BODEGADESTINO NVARCHAR(4),@TipoTransaccion NVARCHAR(1),
		@LoteCompra AS NVARCHAR(15)
		
SET @Fuente='TRASLADOAGROQUIMICOS'
SET @CODSUCURSAL='AL01'
SET @PAQUETE='MOVB'
SET @Articulo='FE00012'
SET @Cantidad=7
SET @PrecioLocal=0
SET @PrecioDolar=0
SET @BODEGADESTINO='JT01'
SET @DOCUMENTO='TP0000020058'
SET @TipoTransaccion='J'
*/

DECLARE @TIPOARTICULO NVARCHAR(1),@TMPCODSUCURSAL NVARCHAR (4)

BEGIN TRY
	BEGIN  TRANSACTION	
	
	Create Table #Resultado (
		ID int IDENTITY,
		Bodega nvarchar(20), --COLLATE Latin1_General_CI_AS, 
		Articulo nvarchar(20),-- COLLATE Latin1_General_CI_AS, 
		Lote NVARCHAR(15), 
		Cantidad decimal(28,8) default 0 
	)
	
	DECLARE @iRwCnt INT,@Lote NVARCHAR(15),@i INT,@CantidadLote DECIMAL(28,8)
	DECLARE @Linea AS INT
	
	IF (@TipoTransaccion<>'O')
	BEGIN
		INSERT INTO #Resultado
		EXEC FNICA.usp_AutoSugiereLotesExactus @Articulo,@CODSUCURSAL,@BodegaDestino,@Cantidad 
		SET @iRwCnt=@@ROWCOUNT
	END
	
	SET @Linea= (SELECT MAX(LINEA_DOC_INV)
	               FROM fnica.LINEA_DOC_INV (NOLOCK) WHERE DOCUMENTO_INV=@DOCUMENTO)
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
	
	IF UPPER (@Fuente)  = 'FACTURACION' OR  UPPER (@Fuente)  = 'DEVOLUCION'
	BEGIN
		SET @TIPOARTICULO = (SELECT TIPO FROM FNICA.ARTICULO (NOLOCK) WHERE ARTICULO = @Articulo )
		IF 	@TIPOARTICULO = 'T'
		BEGIN
			-- Esto fue para el caso de Chinandega Central
		
			SET @TMPCODSUCURSAL = @CODSUCURSAL
			IF  @CODSUCURSAL = 'CH00'
			BEGIN
				set @CODSUCURSAL = 'CC00'
			END
			
			
			
			IF UPPER (@Fuente)  = 'DEVOLUCION'
			BEGIN
				SET @PAQUETE = 'DEVA'
				SELECT @CostoLocal= COSTOLOCAL,@CostoDolar=COSTODOLAR FROM fnica.fafFACTURADETALLE (NOLOCK) WHERE CODSUCURSAL=@TMPCODSUCURSAL AND FACTURA=CAST(CAST(RIGHT(@DOCUMENTO,10) AS DECIMAL) AS NVARCHAR(10)) AND ARTICULO=@Articulo
			END 
			ELSE
				SET @PAQUETE = 'FA'+SUBSTRING(@CODSUCURSAL,1, 2)
				
	
			SET @DOCUMENTO = @DOCUMENTO
			
			set @i = 1
			SET @Lote=''
			set @CantidadLote = 0
			while @i <= @iRwCnt 
			begin
				select @Lote = Lote, @CantidadLote = Cantidad from #Resultado where ID = @i
						
				SET @Linea=@Linea+1
				
				IF UPPER (@Fuente)  = 'DEVOLUCION'
					SET @CantidadLote = @CantidadLote *-1
				
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
	
	IF UPPER (@Fuente)  = 'FORMULA' OR 
		UPPER (@Fuente)  = 'REEMPAQUE'
	BEGIN
		
		DECLARE @TipoTransInv NVARCHAR(10), @Tipo NVARCHAR(1), @SubTipo NVARCHAR (1), @SubSubTipo NVARCHAR(1)
		
		
		IF UPPER (@Fuente)  = 'FORMULA'
			SET @PAQUETE = 'FORM'
		IF UPPER (@Fuente)  = 'REEMPAQUE'
			SET @PAQUETE = 'REPQ'
		
		IF @TipoTransaccion = 'O' 
		begin
			SET @TipoTransInv = '~OO~'
			SET @TIpo = 'O'
			SET @SubTipo = 'D'
			SET @SubSubTipo ='L'
			
			INSERT FNICA.LINEA_DOC_INV ( 
					[PAQUETE_INVENTARIO],[DOCUMENTO_INV],[LINEA_DOC_INV] ,[AJUSTE_CONFIG]
				  ,[ARTICULO],[BODEGA],LOCALIZACION, LOTE,[TIPO],[SUBTIPO],[SUBSUBTIPO]
				  ,[CANTIDAD] ,[COSTO_TOTAL_LOCAL] ,[COSTO_TOTAL_DOLAR]
				  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO])
			VALUES (@PAQUETE,@DOCUMENTO, @Linea, @TipoTransInv , @Articulo, @CODSUCURSAL,'ND',@LoteCompra, @TIpo,@SubTipo,@SubSubTipo, @Cantidad,
				@CostoLocal,@CostoDolar, 0, 0, @BODEGADESTINO )	
		end
		IF @TipoTransaccion = 'C' 
		begin
			SET @TipoTransInv = '~CC~'
			SET @TIpo = 'C'
			SET @SubTipo = 'D'
			SET @SubSubTipo ='N'
	
			
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
				  ,[PRECIO_TOTAL_LOCAL] ,[PRECIO_TOTAL_DOLAR] ,[BODEGA_DESTINO], CENTRO_COSTO, CUENTA_CONTABLE
					)
				
				VALUES (@PAQUETE,@DOCUMENTO, @Linea, @TipoTransInv , @Articulo, @CODSUCURSAL,'ND',@Lote,
						@Tipo,@SubTipo,@SubSubTipo, @CantidadLote,0,0, 0, 0, @BODEGADESTINO,'00-00-00', '9-04-03-000-000'  )
				
				SET @i=@i+1
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


IF (@@TRANCOUNT>0)
	COMMIT TRANSACTION
	
GO 

--#3

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


GO 


--#4  Inserta linea Reempaque

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

GO 

--#4 Creacion de Tabla temporal para almacenar lotes
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



GO 

--

CREATE PROCEDURE fnica.usp_invAtuoSugiereLotesExactusByDocumento(@NumOrdenTraslado AS NVARCHAR(20),@TipoDocumento AS NVARCHAR(20))
AS 
/*
SET @NumOrdenTraslado='OTLE01000001732'
SET @TipoDocumento= 'T'
 */

BEGIN TRY
	Create Table #Documento (
			[ID] INT IDENTITY NOT NULL,
			BodegaOrigen nvarchar(20), --COLLATE Latin1_General_CI_AS, 
			BodegaDestino NVARCHAR(20),
			Articulo nvarchar(20),-- COLLATE Latin1_General_CI_AS, 
			Cantidad decimal(28,8) default 0 
		)

	IF @TipoDocumento='T' 
	BEGIN
		
		insert #Documento(BodegaOrigen,BodegaDestino, Articulo, Cantidad)
		SELECT  A.BodegaOrigen,B.CodSucursal,B.Articulo,B.CantidadRemitida
		  FROM fnica.solOrdenTraslado A
		INNER JOIN fnica.solOrdenTrasladoDetalle B ON B.NumOrdenTraslado = A.NumOrdenTraslado AND B.NumSolicitud = A.NumSolicitud AND B.CodSucursal = A.CodSucursal
		WHERE A.NumOrdenTraslado=@NumOrdenTraslado  

		DECLARE @iRwCnt INT,@i INT,@Cantidad DECIMAL(28,8),@Lote NVARCHAR(15),@Articulo NVARCHAR(20),@BodegaOrigen  NVARCHAR(20),@BodegaDestino NVARCHAR(20)

		SET @iRwCnt=@@ROWCOUNT
		set @i = 1

		while @i <= @iRwCnt 
		BEGIN
			select @Cantidad = Cantidad, @Articulo =Articulo,@BodegaOrigen =BodegaOrigen,@BodegaDestino=BodegaDestino
			  from #Documento where ID = @i
			
			CREATE TABLE #tmpResultado(
				Bodega NVARCHAR(4),
				Articulo NVARCHAR(20),
				Lote NVARCHAR(15),
				Cantidad DECIMAL(28,8)
			)
			
			INSERT INTO #tmpResultado	
			EXEC fnica.usp_AutoSugiereLotesExactus @Articulo,@BodegaOrigen,@BodegaDestino,@Cantidad 
			
			INSERT INTO fnica.tmpLotesAsignados(Fecha, TipoDocumento, Documento, Bodega,
						BodegaDestino, Articulo, Lote, TipoTran, CantidadLote, Cantidad)
			SELECT GETDATE(),'Traslado',@NumOrdenTraslado, Bodega,@BodegaDestino, Articulo, Lote,1, Cantidad,@Cantidad FROM #tmpResultado
			
			DROP TABLE #tmpResultado
			set @i = @i + 1
		END

	END
	ELSE 
		RAISERROR('No hay una configuracion establecida para el tipo de documento ingresado, verifique que sea valido',16,1)
	DROP TABLE #Documento


	SELECT Fecha, TipoDocumento, Documento, Bodega, BodegaDestino, Articulo, Lote,
	       TipoTran, CantidadLote, Cantidad 
	  FROM fnica.tmpLotesAsignados WHERE Documento=@NumOrdenTraslado
END TRY
BEGIN CATCH
	IF @@ERROR>0
	BEGIN 
		IF OBJECT_ID('tempdb..#tmpResultado') IS NOT NULL DROP TABLE #tmpResultado 
		IF OBJECT_ID('tempdb..#Documento') IS NOT NULL DROP TABLE #Documento 
		DECLARE @Error AS NVARCHAR(200)
		SET @Error=( SELECT  ERROR_MESSAGE())
		DELETE  FROM fnica.tmpLotesAsignados WHERE Documento=@NumOrdenTraslado
		RAISERROR( @Error  ,16,1)
	END	
END CATCH

