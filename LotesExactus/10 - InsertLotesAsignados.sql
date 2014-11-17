


CREATE PROCEDURE [fnica].[usp_invInsertLotesAsignados] @Fecha DATETIME,@TipoDocumento NVARCHAR(50),
				@Documento NVARCHAR(50),@Bodega NVARCHAR(10),@BodegaDestino NVARCHAR(10),@Articulo NVARCHAR(20),
				@Lote NVARCHAR(15),@TipoTran NVARCHAR(1),@CantidadLote DECIMAL(28,8),@Cantidad DECIMAL(28,8)
AS 

INSERT INTO fnica.tmpLotesAsignados(Fecha, TipoDocumento, Documento, Bodega,
            BodegaDestino, Articulo, Lote, TipoTran, CantidadLote, Cantidad)
VALUES (@Fecha,@TipoDocumento,@Documento,@Bodega,@BodegaDestino,@Articulo,@Lote,@TipoTran,@CantidadLote,@Cantidad)