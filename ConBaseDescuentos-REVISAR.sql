/*BASE DESCUENTOS X FACT X PROMOCIONES*/
WITH 

DESCUENTOS AS (
SELECT DISTINCT Numero_Tiquete, Fecha_Fin_Regalia, FechaTiquete
FROM 
WHERE Numero_Tiquete IS NOT NULL AND Fecha_Fin_Regalia IS NOT NULL AND FechaTiquete IS NOT NULL
AND EXTRACT(year FROM Fecha_Fin_Regalia)=2021 AND EXTRACT(year FROM FechaTiquete)=2021
--Filtros de facturación o en general?
--Personas con fecha 1900 cruzar con reversiones automtcias para saber el % y luego cuando churn
--Por subarea - y con llamadas
GROUP BY Numero_Tiquete, Fecha_Fin_Regalia, FechaTiquete),

FACTURACION AS (
SELECT DISTINCT TIQUETE_ID, FECHA_APERTURA AS FechaFact
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_TIQUETES_SERVICIO_2021-01_A_2021-11_D` 
WHERE 
CLASE IS NOT NULL AND MOTIVO IS NOT NULL AND TIQUETE_ID IS NOT NULL AND FECHA_APERTURA IS NOT NULL 
AND SUBAREA <> "0 A 30 DIAS" AND SUBAREA <> "30 A 60 DIAS" AND SUBAREA <> "60 A 90 DIAS" 
AND SUBAREA <> "90 A 120 DIAS" AND SUBAREA <> "120 A 150 DIAS" AND SUBAREA <> "150 A 180 DIAS" 
AND SUBAREA <> "MAS DE 180" AND ESTADO <> "ANULADA"
AND MOTIVO="CONSULTAS DE FACTURACION O COBRO"
GROUP BY TIQUETE_ID, FechaFact),

CRUCE AS (
SELECT DISTINCT d.Numero_Tiquete, d.Fecha_Fin_Regalia, d.FechaTiquete, f.TIQUETE_ID, f.FechaFact
FROM DESCUENTOS d JOIN FACTURACION f ON d.Numero_Tiquete=f.TIQUETE_ID
WHERE f.FechaFact > d.Fecha_Fin_Regalia AND DATE_DIFF(f.FechaFact, d.Fecha_Fin_Regalia, DAY)<=60
GROUP BY d.Numero_Tiquete, d.Fecha_Fin_Regalia, d.FechaTiquete, f.TIQUETE_ID, f.FechaFact
)

SELECT COUNT DISTINCT (c.Numero_Tiquete) as Registros, EXTRACT (Month FROM c.Fecha_Fin_Regalia) as Mes
FROM CRUCE c
GROUP BY Mes ORDER BY Mes


