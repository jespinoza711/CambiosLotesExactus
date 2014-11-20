

set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

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
     





