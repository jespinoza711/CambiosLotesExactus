set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go








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

insert #solOrdenTrasladoDetalle (Articulo,Lote,CantidadRemitida)
SELECT Articulo,Lote,CantidadLote 
  FROM fnica.tmpLotesAsignados WHERE Documento=@NumOrdenTraslado
  	
/*SELECT Articulo,CantidadRemitida
FROM fnica.solOrdenTrasladoDetalle
WHERE NumOrdenTraslado= @NumOrdenTraslado AND CodSucursal=@BodegaDestino*/

set @iRowCount  = @@RowCount
Alter table #solOrdenTrasladoDetalle add ID int identity(1,1)

Create clustered index _fmlDetalleOrdenTraslado on #solOrdenTrasladoDetalle (ID) with fillfactor = 100
set @iCounter = 1

	

WHILE (@iCounter <= @iRowCount )
BEGIN -- 
	select @Articulo = Articulo,@Cantidad = CantidadLote,@Lote=Lote
	  from #solOrdenTrasladoDetalle where ID = @iCounter 
	IF (@Cantidad<>0) 
		EXEC FNICA.usp_sincroInsertaLineaTransInvLoteAutoSugerido @Fuente,@BodegaOrigen,@Paquete,@NumDocumento,@Articulo,@Cantidad,0,0,0,0,@BodegaDestino,,@Lote
		EXEC fnica.usp_sincroInsertaLineaTransInv
		@Fuente,
		@BodegaOrigen,
		@iCounter, 
		@NumDocumento,
		@Articulo ,
		@Cantidad ,
		0, 
		0, 
		@BodegaDestino 

	SET @iCounter = @iCounter + 1
END -- 

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










