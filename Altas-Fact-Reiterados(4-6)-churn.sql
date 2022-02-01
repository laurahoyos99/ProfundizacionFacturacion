/*REITEREADOS x Churn (4-6m - 2m)*/
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
--AND SUBAREA="MONTO DE FACTURACION"
--AND SUBAREA="DETALLE DE MONTOS"
--AND (AREA="NOTAS DE CREDITOS" OR AREA="NOTAS DE CREDITO")
GROUP BY CONTRATO, FechaFact),

PRIMERBUCKET AS (
SELECT DISTINCT a.Contrato, f.CONTRATO as contratos1, f.FechaFact as FechaFact1, a.FechaAltas as FechaAltas1
FROM ALTAS a INNER JOIN FACTURACION f ON a.Contrato=f.CONTRATO
WHERE DATE_DIFF(f.FechaFact,a.FechaAltas,DAY)<=60 AND f.FechaFact>a.FechaAltas
GROUP BY a.Contrato,f.CONTRATO, f.FechaFact, a.FechaAltas 
),

SEGUNDOBUCKET AS (
SELECT DISTINCT a.Contrato, f.CONTRATO as contratos2, f.FechaFact as FechaFact2, a.FechaAltas as FechaAltas2
FROM ALTAS a INNER JOIN FACTURACION f ON a.Contrato=f.CONTRATO
WHERE DATE_DIFF(f.FechaFact,a.FechaAltas,DAY)<=120 AND f.FechaFact>a.FechaAltas
AND DATE_DIFF(f.FechaFact,a.FechaAltas,DAY)>60
GROUP BY a.Contrato,f.CONTRATO, f.FechaFact, a.FechaAltas
),

TERCERBUCKET AS (
SELECT DISTINCT a.Contrato, f.CONTRATO as contratos3, f.FechaFact as FechaFact3, a.FechaAltas as FechaAltas3
FROM ALTAS a INNER JOIN FACTURACION f ON a.Contrato=f.CONTRATO
WHERE DATE_DIFF(f.FechaFact,a.FechaAltas,DAY)<=180 AND f.FechaFact>a.FechaAltas
AND DATE_DIFF(f.FechaFact,a.FechaAltas,DAY)>120
GROUP BY a.Contrato,f.CONTRATO, f.FechaFact, a.FechaAltas
),

REITERADOS AS(
SELECT DISTINCT x.contratos1,y.contratos2,w.contratos3,x.FechaAltas1, y.FechaAltas2,w.FechaAltas3, x.FechaFact1, y.FechaFact2,w.FechaFact3, 
CASE WHEN (x.contratos1 IS NOT NULL AND y.contratos2 IS NOT NULL) THEN "Reiterados (<=2m)"
WHEN (x.contratos1 IS NULL AND y.contratos2 IS NOT NULL) THEN "Reiterados (2m-4m)" 
WHEN (x.contratos1 IS NULL AND y.contratos2 IS NULL) THEN "Nuevos" end as ReiterFlag
FROM TERCERBUCKET w LEFT JOIN SEGUNDOBUCKET y ON y.contratos2=w.contratos3
LEFT JOIN PRIMERBUCKET x ON x.contratos1=y.contratos2
GROUP BY x.contratos1,y.contratos2,w.contratos3,x.FechaAltas1, y.FechaAltas2,w.FechaAltas3, x.FechaFact1, y.FechaFact2,w.FechaFact3
),

CHURNERS AS(SELECT DISTINCT h.NOMBRE_CONTRATO, h.FECHA_APERTURA, h.FECHA_FINALIZACION as FechaChurn
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_ORDENES_SERVICIO_2021-01_A_2021-11_D` h 
INNER JOIN REITERADOS r on r.contratos3 = h.NOMBRE_CONTRATO
WHERE h.TIPO_ORDEN = "DESINSTALACION" AND h.ESTADO = "FINALIZADA" 
AND h.FECHA_FINALIZACION IS NOT NULL AND h.FECHA_APERTURA IS NOT NULL
AND h.FECHA_FINALIZACION > r.FechaFact3  AND DATE_DIFF ( h.FECHA_FINALIZACION, r.FechaFact3, DAY) <= 60
GROUP BY h.NOMBRE_CONTRATO, h.FECHA_APERTURA, h.FECHA_FINALIZACION),

CHURNFLAGRESULT AS(
SELECT DISTINCT r.Contratos3, r.FechaFact3,r.FechaAltas3,h.FechaChurn,r.contratos1, r.FechaFact1, r.contratos2, r.FechaFact2,ReiterFlag,
CASE WHEN h.FechaChurn IS NOT NULL THEN "Churner"
WHEN h.FechaChurn IS NULL THEN "NonChurner" end as ChurnFlag
FROM REITERADOS r LEFT JOIN CHURNERS h ON r.contratos3 = h.NOMBRE_CONTRATO
GROUP BY r.Contratos3, r.FechaFact3,r.FechaAltas3,h.FechaChurn, r.contratos1, r.FechaFact1, r.contratos2, r.FechaFact2,ReiterFlag)

SELECT
--DISTINCT t.ReiterFlag,t.Contratos3, t.FechaChurn,t.FechaFact3,t.FechaAltas3,t.contratos2, t.FechaFact2,t.contratos1, t.FechaFact1
COUNT(DISTINCT t.Contratos3) as Reg, EXTRACT (Month FROM t.FechaAltas3) as Mes
FROM CHURNFLAGRESULT t
WHERE ReiterFlag ="Nuevos"
--WHERE ReiterFlag ="Reiterados (2m-4m)"
--WHERE ReiterFlag ="Reiterados (<=2m)"
--AND ChurnFlag="Churner"
AND ChurnFlag="NonChurner"
--GROUP BY t.ReiterFlag,t.Contratos3, t.FechaChurn,t.FechaFact3,t.FechaAltas3,t.contratos2, t.FechaFact2,t.contratos1, t.FechaFact1
GROUP BY Mes ORDER BY Mes
