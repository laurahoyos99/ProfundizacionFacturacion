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
)

SELECT COUNT(DISTINCT c.Contratos) as Registros, EXTRACT(MONTH FROM c.FechaAltas) as Mes
FROM CRUCE c
GROUP BY Mes ORDER BY Mes

