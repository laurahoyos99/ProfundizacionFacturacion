WITH 

NOTASCREDITO AS(
SELECT DISTINCT CONTRATO, FECHA_APERTURA as InicioTicket, FECHA_FINALIZACION as FinTicket
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_TIQUETES_SERVICIO_2021-01_A_2021-11_D` 
WHERE 
CLASE IS NOT NULL AND MOTIVO IS NOT NULL AND CONTRATO IS NOT NULL AND FECHA_APERTURA IS NOT NULL 
AND SUBAREA <> "0 A 30 DIAS" AND SUBAREA <> "30 A 60 DIAS" AND SUBAREA <> "60 A 90 DIAS" 
AND SUBAREA <> "90 A 120 DIAS" AND SUBAREA <> "120 A 150 DIAS" AND SUBAREA <> "150 A 180 DIAS" 
AND SUBAREA <> "MAS DE 180" AND ESTADO <> "ANULADA"
AND MOTIVO="CONSULTAS DE FACTURACION O COBRO"
AND (AREA="NOTAS DE CREDITOS" OR AREA="NOTAS DE CREDITO")
GROUP BY CONTRATO, FECHA_APERTURA, FECHA_FINALIZACION),

CHURNERS AS(SELECT DISTINCT h.NOMBRE_CONTRATO, h.FECHA_APERTURA, h.FECHA_FINALIZACION as FechaChurn
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_ORDENES_SERVICIO_2021-01_A_2021-11_D` h 
INNER JOIN NOTASCREDITO n on n.CONTRATO = h.NOMBRE_CONTRATO
WHERE h.TIPO_ORDEN = "DESINSTALACION" AND h.ESTADO = "FINALIZADA" 
AND h.FECHA_FINALIZACION IS NOT NULL AND h.FECHA_APERTURA IS NOT NULL
AND h.FECHA_FINALIZACION > n.FinTicket AND DATE_DIFF ( h.FECHA_FINALIZACION,n.FinTicket , DAY) <= 60
GROUP BY h.NOMBRE_CONTRATO, h.FECHA_APERTURA, h.FECHA_FINALIZACION),

CHURNFLAGRESULT AS(
SELECT DISTINCT n.Contrato,n.InicioTicket,n.FinTicket,h.FechaChurn,
CASE WHEN h.FechaChurn IS NOT NULL THEN "Churner"
WHEN h.FechaChurn IS NULL THEN "NonChurner" end as ChurnFlag
FROM NOTASCREDITO n LEFT JOIN CHURNERS h ON n.CONTRATO = h.NOMBRE_CONTRATO
GROUP BY n.Contrato,n.InicioTicket,n.FinTicket,h.FechaChurn)

SELECT EXTRACT(Month FROM t.InicioTicket) as Mes,
ROUND(AVG(DATE_DIFF(t.FinTicket,t.InicioTicket,DAY)),2) AS Tiempo_Solucion,
COUNT(DISTINCT t.Contrato) AS Registros
FROM CHURNFLAGRESULT t
WHERE t.FinTicket>t.InicioTicket
--AND ChurnFlag="Churner"
--AND ChurnFlag="NonChurner"
GROUP BY Mes ORDER BY Mes
