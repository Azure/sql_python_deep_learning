
execute sp_execute_external_script
@language = N'python',
@script = N'
import sys,os
import lung_cancer
import pyodbc
from lung_cancer.connection_settings import get_connection_string

print("*********************************************************************************************")
print("Version Lung Cancer: {}".format(lung_cancer.VERSION))
connection_string = get_connection_string()
print("Connection string: {}".format(connection_string))
conn = pyodbc.connect(connection_string)
cur = conn.cursor()
cur.execute("SELECT @@version;") 
row = cur.fetchone() 
print(row[0])
conn.close()
print("*********************************************************************************************")

'

