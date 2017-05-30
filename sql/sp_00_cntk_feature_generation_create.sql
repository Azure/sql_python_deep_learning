USE [lung_cancer_database]
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


IF OBJECT_ID('[dbo].[GenerateFeatures]', 'P') IS NOT NULL  
    DROP PROCEDURE [dbo].[GenerateFeatures];  
GO  

CREATE PROCEDURE [dbo].[GenerateFeatures] 
@PatientIndex INT,
@Model VARBINARY(MAX),
@Features VARBINARY(MAX) OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @PatientScans VARBINARY(MAX) = (SELECT array FROM dbo.scan_images AS t1 
											INNER JOIN dbo.patients AS t2 ON t1.patient_id = t2.patient_id 
											WHERE t2.idx = @PatientIndex);
	-- Insert statements for procedure here
	DECLARE @predictScript NVARCHAR(MAX);
	SET @predictScript = N'
import pickle
import time
from cntk import load_model
from lung_cancer.lung_cancer_utils import manipulate_images, compute_features_with_gpu, load_cntk_model_from_binary, select_model_layer
from lung_cancer.connection_settings import BATCH_SIZE

#Debug
verbose=True

#Manage inputs
t0 = time.clock()
model = load_model(Model)
if verbose: print("Time: {}s".format(time.clock() - t0))

t0 = time.clock()
model = select_model_layer(model, "z.x")
if verbose: print("Time: {}s".format(time.clock() - t0))

t0 = time.clock()
scans = pickle.loads(PatientScans)
if verbose: print("Time: {}s".format(time.clock() - t0))
print(scans.shape)

#Compute featurization with GPU
t0 = time.clock()
scans = manipulate_images(scans)
if verbose: print("Time: {}s".format(time.clock() - t0))

t0 = time.clock()
feats = compute_features_with_gpu(model, scans, BATCH_SIZE)
if verbose: print("Time: {}s".format(time.clock() - t0))
print(feats.shape)

t0 = time.clock()
Features = pickle.dumps(feats)
if verbose: print("Time: {}s".format(time.clock() - t0))

	'

	EXECUTE sp_execute_external_script
	@language = N'python',
	@script = @predictScript,
	@params = N'@PatientIndex INT, @Model VARBINARY(MAX), @PatientScans VARBINARY(MAX), @Features VARBINARY(MAX) OUTPUT',
	@PatientIndex = @PatientIndex,
	@Model = @Model,
	@PatientScans = @PatientScans,
	@Features = @Features OUTPUT;
	DECLARE @PatientId VARCHAR(50) = (SELECT patient_id FROM dbo.patients WHERE idx = @PatientIndex);
	INSERT INTO dbo.features_sp (patient_id, array) VALUES(@PatientId, @Features);

END
GO
