
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

CREATE PROCEDURE [fnica].[usp_sincroInsertaLineaTransInvLotes] @Fuente nvarchar(20), @CODSUCURSAL NVARCHAR(4),  
@noDOCUMENTO NVARCHAR(20) , @Articulo varchar(20), @Cantidad decimal (28,8),
@PrecioLocal decimal (28,8), @PrecioDolar decimal (28,8),@CostoLocal decimal (28,8), @CostoDolar decimal (28,8), @BODEGADESTINO NVARCHAR(4),
@Lote NVARCHAR(15),@TipoTran AS NVARCHAR(1)
	 
AS

DECLARE @PAQUETE NVARCHAR(4), @DOCUMENTO NVARCHAR (20), @TIPOARTICULO NVARCHAR(1),@TMPCODSUCURSAL NVARCHAR (4)
DECLARE @AutoSuguiereLotes AS BIT,@Linea INT


SET @AutoSuguiereLotes= CAST(( SELECT Valor
                            FROM fnica.invParametrosLOTE WHERE IDParametro='UsaLotesExactus') AS BIT)


SET @Linea= (SELECT count(LINEA_DOC_INV)
	               FROM fnica.LINEA_DOC_INV (NOLOCK) WHERE DOCUMENTO_INV=@noDOCUMENTO)
	IF (@Linea IS NULL)
		SET @Linea=0
		
SET @Linea=@Linea+1


		

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

CREATE PROCEDURE fnica.usp_invAutoSugiereLotesExactusByDocumento( @Documento AS NVARCHAR(20),@TipoDocumento AS NVARCHAR(20))
AS 
/*
SET @Documento='OTMT01000001810'
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

	IF EXISTS(SELECT * FROM fnica.tmpLotesAsignados WHERE Documento=@Documento)
		DELETE FROM fnica.tmpLotesAsignados WHERE Documento=@Documento

	IF @TipoDocumento='T' 
	BEGIN
		insert #Documento(BodegaOrigen,BodegaDestino, Articulo, Cantidad)
		SELECT  A.BodegaOrigen,B.CodSucursal,B.Articulo,B.CantidadRemitida
		  FROM fnica.solOrdenTraslado A
		INNER JOIN fnica.solOrdenTrasladoDetalle B ON B.NumOrdenTraslado = A.NumOrdenTraslado AND B.NumSolicitud = A.NumSolicitud AND B.CodSucursal = A.CodSucursal
		WHERE A.NumOrdenTraslado=@Documento  AND B.CantidadRemitida>0

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
			SELECT GETDATE(),'Traslado',@Documento, Bodega,@BodegaDestino, Articulo, Lote,1, Cantidad,@Cantidad FROM #tmpResultado
			
			DROP TABLE #tmpResultado
			set @i = @i + 1
		END
		
		SELECT Fecha, TipoDocumento, Documento, Bodega, BodegaDestino, a.Articulo, b.DESCRIPCION, a.Lote,l.LOTE_DEL_PROVEEDOR,
		l.FECHA_VENCIMIENTO, TipoTran, CantidadLote, Cantidad 
		FROM fnica.tmpLotesAsignados a
		INNER JOIN fnica.ARTICULO b ON b.Articulo = a.Articulo
		INNER JOIN fnica.LOTE L ON a.Lote=l.LOTE WHERE Documento=@Documento
		
		
		
	END
	ELSE 
		RAISERROR('No hay una configuracion establecida para el tipo de documento ingresado, verifique que sea valido',16,1)
	DROP TABLE #Documento


	
END TRY
BEGIN CATCH
	IF @@ERROR>0
	BEGIN 
		IF OBJECT_ID('tempdb..#tmpResultado') IS NOT NULL DROP TABLE #tmpResultado 
		IF OBJECT_ID('tempdb..#Documento') IS NOT NULL DROP TABLE #Documento 
		DECLARE @Error AS NVARCHAR(200)
		SET @Error=( SELECT  ERROR_MESSAGE())
		DELETE  FROM fnica.tmpLotesAsignados WHERE Documento=@Documento
		RAISERROR( @Error  ,16,1)
	END	
END CATCH


GO 




ALTER  procedure [fnica].[invGetLotesByArticulo](@Articulo AS NVARCHAR(20),@Bodega AS NVARCHAR(4),@SoloConExistencia AS INT)
AS

SELECT L.LOTE,L.LOTE_DEL_PROVEEDOR,L.ARTICULO,AR.DESCRIPCION DescrArticulo,L.FECHA_ENTRADA,L.FECHA_VENCIMIENTO,L.PROVEEDOR,P.NOMBRE NombreProveedor,isnull(EL.CANT_DISPONIBLE,0) Existencia 
  FROM fnica.LOTE L
LEFT JOIN fnica.EXISTENCIA_LOTE EL ON EL.ARTICULO = L.ARTICULO AND EL.LOTE = L.LOTE
INNER JOIN fnica.ARTICULO AR ON L.ARTICULO=AR.ARTICULO
LEFT JOIN fnica.PROVEEDOR P ON L.PROVEEDOR=P.PROVEEDOR
WHERE (EL.Bodega=@Bodega OR @Bodega='*') AND (L.ARTICULO= @Articulo OR @Articulo='*') AND (@SoloConExistencia=0 OR EL.CANT_DISPONIBLE>0)  


GO 




ALTER procedure [fnica].[invGetLotesByArticuloGlobal](@Articulo AS NVARCHAR(20))
AS 

SELECT A.LOTE,A.LOTE_DEL_PROVEEDOR,A.ARTICULO,A.FECHA_ENTRADA,A.FECHA_VENCIMIENTO,A.PROVEEDOR,B.NOMBRE NombreProveedor 
  FROM FNICA.LOTE A
LEFT JOIN fnica.PROVEEDOR B ON B.PROVEEDOR = A.Proveedor
WHERE A.Articulo=@Articulo 




GO 

drop procedure fnica.invGetLotesByArticuloCaptacionBoletas

GO 

DROP PROCEDURE [fnica].[invGetLotesByArticuloIDLote]

GO 

CREATE  procedure [fnica].[invGetLotesByArticuloLote](@Lote as NVARCHAR(15),@Articulo AS NVARCHAR(20),@Bodega AS NVARCHAR(4))
AS 

SELECT L.LOTE, L.LOTE_DEL_PROVEEDOR, L.Articulo, L.FECHA_ENTRADA, L.FECHA_VENCIMIENTO,L.Proveedor, B.NOMBRE NombreProveedor,
		ISNULL(EL.CANT_DISPONIBLE,0) Existencia
  FROM FNICA.LOTE L
LEFT JOIN fnica.PROVEEDOR B ON B.PROVEEDOR = L.Proveedor
LEFT JOIN (SELECT * FROM  fnica.EXISTENCIA_LOTE WHERE Bodega = @Bodega ) EL ON L.LOTE=EL.LOTE 
WHERE L.Articulo=@Articulo  AND (L.Lote=@Lote OR @Lote='*')

GO 

DROP PROCEDURE fnica.[invGetLotesByArticuloLoteProveedor]


GO 


DROP PROCEDURE fnica.invGetDocumentosSinLotes 

GO 

drop procedure fnica.invGetAjustesLotesByRange

GO 

drop procedure fnica.invGetConsultaAjustesLotes

GO 

DROP PROCEDURE fnica.invInsertMovLote

GO 

drop procedure fnica.uspinvActualizaFacturaIsLoteGenerado

GO 

drop procedure fnica.uspInvInsertCabeceraAjusteLotes

GO 

drop  procedure fnica.uspInvInsertDetalleAjusteLote

GO 

DROP VIEW [fnica].[vinvMasterLotes]

GO 

CREATE  VIEW [fnica].[vinvExistenciaLotes] 
AS

 SELECT L.LOTE, L.LOTE_DEL_PROVEEDOR, L.ARTICULO,A.DESCRIPCION,EL.BODEGA,L.FECHA_ENTRADA,
		L.FECHA_VENCIMIENTO,P.PROVEEDOR,P.NOMBRE NombreProveedor,EL.CANT_DISPONIBLE
 FROM fnica.LOTE L
 INNER JOIN fnica.EXISTENCIA_LOTE EL ON EL.ARTICULO = L.ARTICULO AND EL.LOTE = L.LOTE
 INNER JOIN fnica.ARTICULO A ON L.ARTICULO=A.ARTICULO AND EL.ARTICULO=A.ARTICULO
 LEFT JOIN fnica.PROVEEDOR P ON L.PROVEEDOR=P.PROVEEDOR
 

GO 

ALTER PROCEDURE [fnica].[usp_solGuardarEntradaSalidaProductos] @NumOrdenTraslado nvarchar(15),
															@CodSucursal NVARCHAR(4),
															@NumEntradaSalida AS NVARCHAR(100),
															@Usuario AS NVARCHAR(50),
															@Entrada int
AS


DECLARE @sSQL Nvarchar(4000)
DECLARE @campo NVARCHAR(50)
DECLARE @CampoBodega NVARCHAR(50)
DECLARE @DocumentoInv AS NVARCHAR(50)
DECLARE @NumSolicitud AS NVARCHAR(15)

DECLARE @SistemaUsaLotes AS INT 
SET @SistemaUsaLotes = (SELECT Valor FROM fnica.invParametrosLOTE (NOLOCK) WHERE IDParametro='UsaLotes')

DECLARE @AutoSugiereLotes AS INT 
SET @AutoSugiereLotes = (SELECT Valor
                          FROM fnica.invParametrosLOTE (NOLOCK)WHERE IDParametro='AutoSugiereLotesTraslado')
                

DECLARE @SePuedeAplicar AS INT
DECLARE @PaqueteInventario AS NVARCHAR(4)
DECLARE @Categoria AS NVARCHAR(4)

SELECT @Categoria =  CodCategoria FROM fnica.solSolicitud (NOLOCK)
					WHERE NumSolicitud=(SELECT NumSolicitud 
					FROM fnica.solOrdenTraslado   (NOLOCK)
					WHERE NumOrdenTraslado=@NumOrdenTraslado)


--Si la opcion de autoAplicarPaquetes esta Activada
SELECT @SePuedeAplicar=[AplicaPaquete],@PaqueteInventario=CASE WHEN @Categoria IN ('AGR','AVR') then 
											NombrePaqueteAgroquimico 
										when (@Categoria='FOR') then
											NombrePaqueteFormula
										else
											 NombrePaqueteEquipo 
										end 
FROM fnica.[solParametrosSolicitud] (NOLOCK)

--Salida de Productos
IF @Entrada = 0
	begin
		SET @campo = 'NumSalidaBodega'
		SET @CampoBodega='BodegaOrigen'
		
		--Actualizar el Estado de la Orden de Traslado
		UPDATE fnica.solOrdenTraslado SET CodEstado = 'SAL' WHERE NumOrdenTraslado=@NumOrdenTraslado AND BodegaOrigen = @CodSucursal
			
		--Generar Paquete de Traslado
		EXEC fnica.usp_sincroCrearDocumentoInv 'TRASLADO',@CodSucursal,@NumOrdenTraslado,@NumEntradaSalida
		
		--  Insertar Log de OrdenTraslado
		INSERT INTO fnica.solOrdenTrasladoDetalleEstado(NumOrdenTraslado, NumSolicitud,
					DocumentoInv, CodSucursal, CodEstado, Usuario, Fecha)
		SELECT NumOrdenTraslado,NumSolicitud,DocumentoInv,CodSucursal,CodEstado,@Usuario,GETDATE()
		  FROM fnica.solOrdenTraslado (NOLOCK) WHERE NumOrdenTraslado=@NumOrdenTraslado AND BodegaOrigen=@CodSucursal
		
--		IF (@SistemaUsaLotes=1)
--		BEGIN
--				IF (@AutoSugiereLotes=1)
--				BEGIN
--						/*Obtener el documento*/
--						SELECT @DocumentoInv=DocumentoInv
--						FROM fnica.solOrdenTraslado (NOLOCK) WHERE NumOrdenTraslado=@NumOrdenTraslado AND BodegaOrigen=@CodSucursal
--						/*Verificar si es aplicable*/
--						IF fnica.isPaqueteTrasladoAplicable(@PaqueteInventario, @DocumentoInv)= 1 AND @Categoria<>'AVR'
--						BEGIN
--							 EXEC [fnica].[invAutoSugiereTrasladoLotes] @NumOrdenTraslado,  @Entrada
--						END
--						
--				END
--		END
	END
--Ingreso de Productos
ELSE IF @Entrada=1 
	begin
		SET @campo = 'NumEntradaBodega'
		SET @CampoBodega='CodSucursal'
		
		SELECT @DocumentoInv=DocumentoInv
		  FROM fnica.solOrdenTraslado (NOLOCK) WHERE NumOrdenTraslado=@NumOrdenTraslado AND CodSucursal=@CodSucursal
		  
		/*Realizar la Actualizacion de la descripcion del paquete */
		IF (EXISTS(SELECT * FROM fnica.DOCUMENTO_INV (NOLOCK) WHERE DOCUMENTO_INV =@DocumentoInv))
		BEGIN
			UPDATE fnica.DOCUMENTO_INV SET REFERENCIA = REFERENCIA + '  Entrada a Bodega #' + @NumEntradaSalida
			WHERE DOCUMENTO_INV =@DocumentoInv
		END
		
		--Actualizar el Estado de la Orden de Traslado
		UPDATE fnica.solOrdenTraslado SET CodEstado = 'REC' WHERE NumOrdenTraslado=@NumOrdenTraslado AND CodSucursal = @CodSucursal
		
		--Proceder a Aplicar le Paquete


	
--		IF ( @SePuedeAplicar=1)
--		BEGIN
--			/*APLICAR EL PAQUETE*/
--				IF (@SistemaUsaLotes=1)
--				BEGIN
--						IF (@AutoSugiereLotes=1)
--						BEGIN
--								IF fnica.isPaqueteTrasladoAplicable(@PaqueteInventario, @DocumentoInv)= 1 AND @Categoria<>'AVR'
--								BEGIN
--										 EXEC [fnica].[invAutoSugiereTrasladoLotes] @NumOrdenTraslado,  @Entrada
--								END
--						END
--				END
--		
--		
--		--	EXEC fnica.uspinvAplicarPaqueteTraslado @PaqueteInventario,@DocumentoInv
--		END
		
		--  Insertar Log de OrdenTraslado
		INSERT INTO fnica.solOrdenTrasladoDetalleEstado(NumOrdenTraslado, NumSolicitud,
					DocumentoInv, CodSucursal, CodEstado, Usuario, Fecha)
		SELECT NumOrdenTraslado,NumSolicitud,DocumentoInv,CodSucursal,CodEstado,@Usuario,GETDATE()
		  FROM fnica.solOrdenTraslado (NOLOCK) WHERE NumOrdenTraslado=@NumOrdenTraslado AND CodSucursal=@CodSucursal

		--Verificar si la solicitud Generada Tiene todas las ordenes recibidas
		SELECT @NumSolicitud= NumSolicitud
		  FROM FNICA.solOrdenTraslado (NOLOCK) WHERE NumOrdenTraslado=@NumOrdenTraslado AND CodSucursal=@CodSucursal
		
		DECLARE @CantPendiente AS INT
		SELECT @CantPendiente = isnull(count(*),0) FROM fnica.solOrdenTraslado WHERE NumSolicitud=@NumSolicitud AND CodEstado IN ('PRO','INI','SAL')

		IF (@CantPendiente=0) 
		BEGIN
			--Cambiar el estado de la solicitud a Finalizada
			UPDATE fnica.solSolicitud SET Estado = 'FIN' WHERE NumSolicitud=@NumSolicitud
			
			--Insertar el Log de Solicitudes
			INSERT INTO fnica.solSolicitudDetalleEstado(NumSolicitud, CodSucursal,
						CodEstado, Fecha, Usuario)
			SELECT NumSolicitud,CodSucursal,Estado,GETDATE(),@Usuario
			  FROM fnica.solSolicitud (NOLOCK) WHERE NumSolicitud=@NumSolicitud
		END
		
	END
	
--Se guarda el Num de Remision /Entrada
set @sSQL = N' UPDATE fnica.solOrdenTraslado SET ' + @campo + ' = '''+  @NumEntradaSalida  + ''' WHERE NumOrdenTraslado =''' + @NumOrdenTraslado + ''' AND ' + @CampoBodega + '=''' + @CodSucursal + ''''


EXEC sp_executesql 
     @query = @sSQL
     
     
GO      


DROP PROCEDURE	 [fnica].[invGetExistenciaBodegaLoteExcludeDocumento]

GO 


CREATE  PROCEDURE [fnica].[invGetExistenciaBodegaLote] @Articulo AS NVARCHAR(20),@Bodega AS NVARCHAR(10)
AS 

SELECT EL.LOTE, EL.LOTE_DEL_PROVEEDOR, EL.ARTICULO, EL.DESCRIPCION, EL.BODEGA,
       EL.FECHA_ENTRADA, EL.FECHA_VENCIMIENTO, EL.PROVEEDOR, EL.NombreProveedor,
       EL.CANT_DISPONIBLE
  FROM fnica.[vinvExistenciaLotes] EL
WHERE (El.BODEGA=@Bodega OR @Bodega='*') AND (EL.ARTICULO=@Articulo OR @Articulo='*')  AND EL.CANT_DISPONIBLE>0
ORDER BY EL.FECHA_VENCIMIENTO ASC 




GO 

CREATE PROCEDURE [fnica].[usp_invInsertLotesAsignados] @Fecha DATETIME,@TipoDocumento NVARCHAR(50),
				@Documento NVARCHAR(50),@Bodega NVARCHAR(10),@BodegaDestino NVARCHAR(10),@Articulo NVARCHAR(20),
				@Lote NVARCHAR(15),@TipoTran NVARCHAR(1),@CantidadLote DECIMAL(28,8),@Cantidad DECIMAL(28,8)
AS 

DELETE FROM fnica.tmpLotesAsignados WHERE Documento=@Documento

INSERT INTO fnica.tmpLotesAsignados(Fecha, TipoDocumento, Documento, Bodega,
            BodegaDestino, Articulo, Lote, TipoTran, CantidadLote, Cantidad)
VALUES (@Fecha,@TipoDocumento,@Documento,@Bodega,@BodegaDestino,@Articulo,@Lote,@TipoTran,@CantidadLote,@Cantidad)

GO 


ALTER PROCEDURE [fnica].[usp_sincroCrearDocumentoInv]
@Fuente NVARCHAR(200),
@CodSucursal NVARCHAR(4),
@NumOrdenTraslado NVARCHAR(15),
@Remision NVARCHAR(15)

AS

DECLARE @NumDocumento NVARCHAR(200)
DECLARE @BodegaDestino NVARCHAR(4)
declare @BodegaOrigen NVARCHAR(4)
DECLARE @Fecha DATETIME



Declare @iRowCount int, @iCounter int, @Articulo nvarchar(20),  @Cantidad decimal(28,8),@Lote AS NVARCHAR(15)


SELECT @Fecha = GETDATE() 
DECLARE @Categoria AS NVARCHAR(4)

/*Insertar el la cabecera*/

SELECT @NumDocumento='Traslado de ' + (SELECT Descripcion
FROM fnica.SolCategoriaSolicitud 
WHERE CodCategoria =(SELECT CodCategoria FROM fnica.solSolicitud
WHERE NumSolicitud=(SELECT NumSolicitud 
							FROM fnica.solOrdenTraslado  
							WHERE NumOrdenTraslado=@NumOrdenTraslado))) + ' de ' + BodegaOrigen + ' a ' + CodSucursal + ', Orden de Traslado #' + NumOrdenTraslado + ', Originado por la solicitud #'+ NumSolicitud + ', Remisión # ' + @Remision,
@BodegaOrigen=BodegaOrigen, @BodegaDestino=CodSucursal
FROM fnica.solOrdenTraslado 
WHERE NumOrdenTraslado=@NumOrdenTraslado 



/*Obtener la categoria */	
SELECT @Categoria =  CodCategoria FROM fnica.solSolicitud
WHERE NumSolicitud=(SELECT NumSolicitud 
							FROM fnica.solOrdenTraslado  
							WHERE NumOrdenTraslado=@NumOrdenTraslado)



IF (@Categoria IN ('AGR','AVR'))
	SET @Fuente='TRASLADOAGROQUIMICOS'
ELSE IF (@Categoria = 'FOR')
	SET @Fuente='TRASLADOFORMULAS'
ELSE
	SET @Fuente='TRASLADOEQUIPOS'				


SET @NumDocumento= (SELECT Substring(@NumDocumento,1,200))
DECLARE @Paquete AS NVARCHAR(20)

EXEC fnica.usp_sincroCrearCabeceraTransInv
	@Fuente, 
	@BodegaDestino,
	@NumDocumento OUTPUT,
	@Fecha, 
	@Paquete OUTPUT



/*Insertar el detalle del documento*/
CREATE TABLE #solOrdenTrasladoDetalle(
	[Articulo] [nvarchar](50) ,
	[Lote] NVARCHAR (15),
	[Cantidad] [decimal](18, 4) NULL DEFAULT 0
)

insert #solOrdenTrasladoDetalle (Articulo,Lote,Cantidad)
SELECT Articulo,Lote,CantidadLote 
  FROM fnica.tmpLotesAsignados WHERE Documento=@NumOrdenTraslado
  	


set @iRowCount  = @@RowCount
Alter table #solOrdenTrasladoDetalle add ID int identity(1,1)

Create clustered index _fmlDetalleOrdenTraslado on #solOrdenTrasladoDetalle (ID) with fillfactor = 100
set @iCounter = 1

	

WHILE (@iCounter <= @iRowCount )
BEGIN -- 
	select @Articulo = Articulo,@Cantidad = Cantidad,@Lote=Lote
	  from #solOrdenTrasladoDetalle where ID = @iCounter 
	IF (@Cantidad<>0) 
		EXEC FNICA.usp_sincroInsertaLineaTransInvLotes @Fuente,@BodegaOrigen,@NumDocumento,@Articulo,@Cantidad,0,0,0,0,@BodegaDestino,@Lote,'T' 
		

	SET @iCounter = @iCounter + 1
END -- 

/*Eliminar los autosugeridos*/

DELETE FROM fnica.tmpLotesAsignados WHERE Documento=@NumOrdenTraslado

/*Verificar si el paquete tiene lineas*/
DECLARE @CantidadRegistros INT 
SELECT @CantidadRegistros= COUNT(*) FROM fnica.LINEA_DOC_INV WHERE DOCUMENTO_INV=@NumDocumento
IF (@CantidadRegistros = 0)
	DELETE FROM fnica.DOCUMENTO_INV WHERE DOCUMENTO_INV= @NumDocumento

DROP TABLE  #solOrdenTrasladoDetalle

--SELECT * FROM fnica.DOCUMENTO_INV WHERE DOCUMENTO_INV=@NumDocumento
--SELECT * FROM fnica.LINEA_DOC_INV WHERE DOCUMENTO_INV=@NumDocumento

/*Actualizar el paquete de inventario en la OT*/
IF (@CantidadRegistros <> 0)
begin
	UPDATE fnica.solOrdenTraslado SET DocumentoInv=@NumDocumento WHERE NumOrdenTraslado=@NumOrdenTraslado AND CodSucursal=@BodegaDestino
	UPDATE fnica.solOrdenTrasladoDetalle SET DocumentoInv=@NumDocumento WHERE NumOrdenTraslado=@NumOrdenTraslado AND CodSucursal=@BodegaDestino
end

/*Actualizar el Consecutivo*/
IF (@CantidadRegistros>0)
	EXEC fnica.usp_sincroActualizaConsecutivoInv @Fuente,@BodegaDestino




GO 




create procedure fnica.usp_invDeleteAllLotesAsignados @Documento NVARCHAR(20)
AS 
delete FROM fnica.tmpLotesAsignados WHERE Documento=@Documento


GO 


