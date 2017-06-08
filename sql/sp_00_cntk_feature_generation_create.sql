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
@Model VARBINARY(MAX)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	-- Insert statements for procedure here
	DECLARE @predictScript NVARCHAR(MAX);
	SET @predictScript = N'
import pickle
import time
import pyodbc
from cntk import load_model
from cntk.device import try_set_default_device, gpu, cpu
from lung_cancer.lung_cancer_utils import get_patients_id, get_patient_images, manipulate_images, select_model_layer, compute_features_with_gpu, insert_features
from lung_cancer.connection_settings import get_connection_string, TABLE_SCAN_IMAGES, TABLE_LABELS, TABLE_FEATURES, TABLE_MODEL, BATCH_SIZE, CNTK_MODEL_NAME

#Debug
verbose=True
try_set_default_device(gpu(0))

# Connect to SQL Server
connection_string = get_connection_string()
conn = pyodbc.connect(connection_string)
cur = conn.cursor()

#Manage inputs
t0 = time.clock()
model = load_model(Model)
model = select_model_layer(model, "z.x")
if verbose: print("Time to load model: {}s".format(time.clock() - t0))

#Get patients id
patients = get_patients_id(TABLE_SCAN_IMAGES, cur)

for i, p in enumerate(patients):
	if verbose: print("Computing patient #{}: {}".format(i,p))
	
	t0 = time.clock()
	scans = get_patient_images(TABLE_SCAN_IMAGES, cur, p)
	scans = manipulate_images(scans)
	if verbose: print("Time to get and manipulate images: {}s".format(time.clock() - t0))
	
	t0 = time.clock()
	feats = compute_features_with_gpu(model, scans, BATCH_SIZE)
	if verbose: print("Time to compute features: {}s".format(time.clock() - t0))

	insert_features(TABLE_FEATURES, cur, conn, p, feats)

conn.close()

print("Routine finished")

	'

	EXECUTE sp_execute_external_script
	@language = N'python',
	@script = @predictScript,
	@params = N'@Model VARBINARY(MAX)',
	@Model = @Model;

END
GO
