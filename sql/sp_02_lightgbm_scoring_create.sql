
USE [lung_cancer]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('[dbo].[PredictLungCancer]', 'P') IS NOT NULL  
    DROP PROCEDURE [dbo].[PredictLungCancer];  
GO  

CREATE PROCEDURE [dbo].[PredictLungCancer] 
@PatientIndex INT,
@PredictionResult FLOAT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @predictScript NVARCHAR(MAX);
	SET @predictScript = N'
import sys
import pyodbc
from lung_cancer.lung_cancer_utils import get_patients_id, get_patient_id_from_index, get_features, get_ligthgbm_model, prediction
from lung_cancer.connection_settings import get_connection_string, TABLE_SCAN_IMAGES, TABLE_LABELS, TABLE_FEATURES, TABLE_MODEL

# Connect to SQL Server
connection_string = get_connection_string()
conn = pyodbc.connect(connection_string)
cur = conn.cursor()
cur.execute("SELECT @@VERSION")
row = cur.fetchone()
print(row[0])

#Main routine
print("Starting routine")
MODEL_NAME = "ligthgbm_exp09_sql_sp"

#---------------------------------------------------------------
#-------------  SCORING OF A REQUESTED PATIENT  ----------------
#---------------------------------------------------------------
patient_id_query = get_patient_id_from_index(TABLE_SCAN_IMAGES, cur, PatientIndex)

feats = get_features(TABLE_FEATURES, cur, patient_id_query)

model = get_ligthgbm_model(TABLE_MODEL, cur, MODEL_NAME)

probability_cancer = prediction(model, feats)

PredictionResult = float(probability_cancer)*100
print("The probability of cancer for patient {} is {}%".format(patient_id_query, PredictionResult))
#---------------------------------------------------------------
#-------------  SCORING OF A REQUESTED PATIENT  ----------------
#---------------------------------------------------------------
conn.close()
print("Routine finished")
	'
	EXECUTE sp_execute_external_script
	@language = N'python',
	@script = @predictScript,
	@params = N'@PatientIndex INT, @PredictionResult FLOAT OUTPUT',
	@PatientIndex = @PatientIndex,
	@PredictionResult = @PredictionResult OUTPUT;

	PRINT 'Probability for having cancer (%):'
	PRINT @PredictionResult
	SELECT @PredictionResult
END
GO



