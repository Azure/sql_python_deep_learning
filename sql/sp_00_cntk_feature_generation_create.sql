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

from lung_cancer.lung_cancer_utils import get_patients_id, get_patient_images, manipulate_images, compute_features_with_gpu, create_table_features, insert_features, get_cntk_model_sql, get_cntk_model
from lung_cancer.connection_settings import get_connection_string, TABLE_SCAN_IMAGES, TABLE_LABELS, TABLE_FEATURES, TABLE_MODEL, BATCH_SIZE, MODEL_NAME
from cntk.device import set_default_device, gpu

# Connect to SQL Server
connection_string = get_connection_string()
conn = pyodbc.connect(connection_string)
cur = conn.cursor()
cur.execute("SELECT @@VERSION")
row = cur.fetchone()
print(row[0])

create_table_features(TABLE_FEATURES, cur)

print("Starting routine")
#---------------------------------------------------------------
#--------  IMAGE FEATURIZATION WITH CNTK MODEL IN GPU  ---------
#---------------------------------------------------------------
set_default_device(gpu(0))

patients = get_patients_id(TABLE_SCAN_IMAGES, cur)
net = get_cntk_model_sql(TABLE_MODEL, cur, MODEL_NAME)

for i, p in enumerate(patients):
	print("Computing patient #{}: {}".format(i,p))

	scans = get_patient_images(TABLE_SCAN_IMAGES, cur, p)

	scans = manipulate_images(scans)

	feats = compute_features_with_gpu(net, scans, BATCH_SIZE)

	insert_features(TABLE_FEATURES, cur, conn, p, feats)

#---------------------------------------------------------------
#--------  IMAGE FEATURIZATION WITH CNTK MODEL IN GPU  ---------
#---------------------------------------------------------------
conn.close()
print("Routine finished")


	'

	EXECUTE sp_execute_external_script
	@language = N'python',
	@script = @predictScript;

END
GO
