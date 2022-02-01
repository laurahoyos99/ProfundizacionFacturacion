WITH 

/*Subconsulta que extrae las ventas nuevas del 2021*/
ALTAS AS (
SELECT distinct Contrato, Formato_Fecha as FechaAltas
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-20_CR_ALTAS_V3_2021-01_A_2021-12_T` 
WHERE
Tipo_Venta="Nueva"
AND (Tipo_Cliente = "PROGRAMA HOGARES CONECTADOS" OR Tipo_Cliente="RESIDENCIAL" OR Tipo_Cliente="EMPLEADO")
AND extract(year from Formato_Fecha) = 2021 
AND Subcanal__Venta<>"OUTBOUND PYMES" AND Subcanal__Venta<>"INBOUND PYMES" AND Subcanal__Venta<>"HOTELERO" AND Subcanal__Venta<>"PYMES – NETCOM" 
AND Tipo_Movimiento= "Altas por venta" 
AND (Motivo="VENTA NUEVA" OR Motivo="VENTA")
GROUP BY contrato, FechaAltas
),

FACTURACION AS (
SELECT DISTINCT CONTRATO, FECHA_APERTURA AS FechaFact
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_TIQUETES_SERVICIO_2021-01_A_2021-11_D` 
WHERE 
CLASE IS NOT NULL AND MOTIVO IS NOT NULL AND CONTRATO IS NOT NULL AND FECHA_APERTURA IS NOT NULL 
AND SUBAREA <> "0 A 30 DIAS" AND SUBAREA <> "30 A 60 DIAS" AND SUBAREA <> "60 A 90 DIAS" 
AND SUBAREA <> "90 A 120 DIAS" AND SUBAREA <> "120 A 150 DIAS" AND SUBAREA <> "150 A 180 DIAS" 
AND SUBAREA <> "MAS DE 180" AND ESTADO <> "ANULADA"
AND MOTIVO="CONSULTAS DE FACTURACION O COBRO"
GROUP BY CONTRATO, FechaFact),

CRUCE AS (
SELECT DISTINCT a.Contrato, f.CONTRATO as contratos, f.FechaFact, a.FechaAltas 
FROM ALTAS a INNER JOIN FACTURACION f ON a.Contrato=f.CONTRATO
WHERE DATE_DIFF(f.FechaFact,a.FechaAltas,DAY)<=60
AND f.FechaFact>a.FechaAltas
GROUP BY a.Contrato,f.CONTRATO, f.FechaFact, a.FechaAltas 
),

CHURNERS AS(SELECT DISTINCT h.NOMBRE_CONTRATO, h.FECHA_APERTURA, h.FECHA_FINALIZACION as FechaChurn
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_ORDENES_SERVICIO_2021-01_A_2021-11_D` h 
INNER JOIN CRUCE c on c.Contratos = h.NOMBRE_CONTRATO
WHERE h.TIPO_ORDEN = "DESINSTALACION" AND h.ESTADO = "FINALIZADA" 
AND h.FECHA_FINALIZACION IS NOT NULL AND h.FECHA_APERTURA IS NOT NULL
AND h.FECHA_FINALIZACION > c.FechaFact  AND DATE_DIFF ( h.FECHA_FINALIZACION, c.FechaFact, DAY) <= 60
GROUP BY h.NOMBRE_CONTRATO, h.FECHA_APERTURA, h.FECHA_FINALIZACION),

/*Subconsulta que divide los churners y los no churners*/
CHURNFLAGRESULT AS(
SELECT DISTINCT c.Contratos, c.FechaFact,c.FechaAltas,h.FechaChurn ,
CASE WHEN h.FechaChurn IS NOT NULL THEN "Churner"
WHEN h.FechaChurn IS NULL THEN "NonChurner" end as ChurnFlag
FROM CRUCE c 
LEFT JOIN CHURNERS h ON c.Contratos = h.NOMBRE_CONTRATO
--WHERE h.FechaChurn > c.FechaFact  AND DATE_DIFF ( h.FechaChurn, c.FechaFact, DAY) <= 60
GROUP BY c.contratos, c.FechaFact,c.FechaAltas, ChurnFlag, h.FechaChurn)

SELECT 
--DISTINCT t.Contratos, t.FechaAltas,t.FechaFact,t.FechaChurn 
COUNT (DISTINCT t.Contratos) as Registros, EXTRACT(MONTH FROM t.FechaAltas) as Mes 
FROM CHURNFLAGRESULT t
--WHERE ChurnFlag = "Churner"
WHERE ChurnFlag = "NonChurner"
GROUP BY Mes ORDER BY Mes

