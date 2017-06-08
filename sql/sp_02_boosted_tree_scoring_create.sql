
USE [lung_cancer_database]
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
@ModelName VARCHAR(50),
@PredictionResult FLOAT OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @Model VARBINARY(MAX) = (SELECT TOP(1) model from dbo.model where name = @ModelName ORDER BY date DESC);
	DECLARE @Features VARBINARY(MAX) = (SELECT array FROM dbo.features AS t1 
										INNER JOIN dbo.patients AS t2 ON t1.patient_id = t2.patient_id 
										WHERE t2.idx = @PatientIndex);
    -- Insert statements for procedure here
	DECLARE @predictScript NVARCHAR(MAX);
	SET @predictScript = N'
import sys
import pickle
from lung_cancer.lung_cancer_utils import  prediction

#Deserialize variables
loaded_model = pickle.loads(Model)
feats = pickle.loads(Features)

#Prediction
probability_cancer = prediction(loaded_model, feats)
PredictionResult = float(probability_cancer)*100
print("The probability of cancer for patient {} is {}%".format(PatientIndex, PredictionResult))

	'
	EXECUTE sp_execute_external_script
	@language = N'python',
	@script = @predictScript,
	@params = N'@PatientIndex INT, @ModelName VARCHAR(50), @Model VARBINARY(MAX), @Features VARBINARY(MAX), @PredictionResult FLOAT OUTPUT',
	@PatientIndex = @PatientIndex,
	@ModelName = @ModelName,
	@Model = @Model,
	@Features = @Features,
	@PredictionResult = @PredictionResult OUTPUT;

	PRINT 'Probability for having cancer (%):'
	SELECT @PredictionResult
END
GO



