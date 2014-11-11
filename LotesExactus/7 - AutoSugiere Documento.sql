
--SELECT * FROM fnica.solOrdenTraslado WHERE CodEstado='REC' ORDER BY FechaRemision desc 
--drop  PROCEDURE fnica.usp_invAtuoSugiereLotesExactusByDocumento
CREATE PROCEDURE fnica.usp_invAtuoSugiereLotesExactusByDocumento(@Documento AS NVARCHAR(20),@TipoDocumento AS NVARCHAR(20))
AS 
/*
SET @Documento='OTLE01000001732'
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
		WHERE A.NumOrdenTraslado=@Documento  

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
		
		SELECT Fecha, TipoDocumento, Documento, Bodega, BodegaDestino, a.Articulo, b.DESCRIPCION, a.Lote,l.LOTE_DEL_PROVEEDOR,l.FECHA_VENCIMIENTO
	       TipoTran, CantidadLote, Cantidad 
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

