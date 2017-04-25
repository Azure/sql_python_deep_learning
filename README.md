# SQL Python for deep learning
This repo has a project that use deep learning inside SQL with python code.

### Installation

#### Installation of python in SQL Server

The first step is to download the content of the folder `\\nsosnovbigbox\sqldrops\2017-03-29\1\retail\SQLFULL_ENU`. There you will find the python installer `sqlpython.cmd`. Alternatively, you can download the files from this [storage](https://migonzastorage.blob.core.windows.net/installer/SQL_Server/2017_04_04_SQLFULL_ENU.zip).

Execute `setup.exe` and follow the steps of installation. Install all the packages. In specify free edition, select developer. In the Windows DSVM (as of April 2017) you will need to update [java JRE](http://www.oracle.com/technetwork/java/javase/downloads/jre8-downloads-2133155.html) to be able to install PolyBase.

Make sure that you have the `revoscalepy` is working. To test it go to the installation folder and look for `python.exe` inside `PYTHON_SERVICES` folder.

	cd C:\Program Files\Microsoft SQL Server\YOUR-MSSQL-SERVER-INSTANCE-FOLDER\PYTHON_SERVICES
	python.exe -m "import revoscalepy"

Make sure that python runs inside SQL Server correctly. For that open SQL Server and connect to your database engine. You need to enable external scripts. For that, press `New Query` and execute: 

	Exec sp_configure 'external scripts enabled', 1
	Reconfigure with override

Then you need to restart SQL Server. Right click on the server and then restart. After restarting, you have to make sure that in external scripts enables run_value is 1.

Finally, to test that everything works correctly you have to execute the file [sqlpytest.sql](sql/sqlpytest.sql).


#### Install CNTK with SQL

We are going to install CNTK version 2.0beta12 and only the python biddings directly from the wheels. The information for the last CNTK version can be found [here](https://github.com/Microsoft/CNTK/wiki/Setup-Windows-Python).

The version we will install is CNTK with GPU 1-bit SGD in python 3.5. In a terminal, install the python wheels:

	cd C:\Program Files\Microsoft SQL Server\YOUR-MSSQL-SERVER-INSTANCE-FOLDER\PYTHON_SERVICES\Scripts
	pip.exe install https://cntk.ai/PythonWheel/GPU-1bit-SGD/cntk-2.0.beta12.0-cp35-cp35m-win_amd64.whl

Finally, make sure that SQL python loads cntk correctly:

	cd C:\Program Files\Microsoft SQL Server\YOUR-MSSQL-SERVER-INSTANCE-FOLDER\PYTHON_SERVICES
	python.exe -c "import cntk"

#### Install LightGBM

1) Clone LightGBM repo

		git clone https://github.com/microsoft/lightgbm

2) Open `./windows/LightGBM.sln` in Visual Studio

3) Set configuration to Release and x64 (set to DLL for building library)

4) Press Ctrl+Shift+B to build.

5) Install the python biddings, for that we need to execute `python setup.py install` inside the LightGBM python directory but pointing the SQL python directory.

		cd C:\lightgbm\python-package\
		"C:\Program Files\Microsoft SQL Server\YOUR-MSSQL-SERVER-INSTANCE-FOLDER\PYTHON_SERVICES\python.exe" setup.py install

6) Make sure that lightgbm is loaded correctly

		cd C:\Program Files\Microsoft SQL Server\YOUR-MSSQL-SERVER-INSTANCE-FOLDER\PYTHON_SERVICES
		python.exe -c "import lightgbm"

#### Install the rest of the libraries needed to run the the demo
The next step is to install several libraries that we need to run the demo. First you need to install OpenCV:

		cd C:\Program Files\Microsoft SQL Server\YOUR-MSSQL-SERVER-INSTANCE-FOLDER\PYTHON_SERVICES\Scripts
		conda.exe install -c https://conda.binstar.org/conda-forge opencv -y

Finally, you need to install the libraries available in the `requirements.txt`. For that you have execute SQL `pip` inside the directory where you downloaded this repo. So, in a terminal write:

	"C:\Program Files\Microsoft SQL Server\YOUR-MSSQL-SERVER-INSTANCE-FOLDER\PYTHON_SERVICES\Scripts\pip.exe" install -r requirements.txt

#### Install lung cancer detection libraries
The last step is to install the lung cancer libraries. You have to go to the folder where you donwloaded the libraries and execute from there:

	cd PATH-TO-SQL-PYTHON-DEEP-LEARNING-REPO
	"C:\Program Files\Microsoft SQL Server\YOUR-MSSQL-SERVER-INSTANCE-FOLDER\PYTHON_SERVICES\python.exe" setup.py install


#### Test that everything works correctly
Once everything was installed, we have to make sure that all libraries can be loaded from SQL. To test it, execute the file [sql_python_load_libs.sql](sql/sql_python_load_libs.sql). You should see the following:

```bash
*********************************************************************************************
3.5.2 |Anaconda 4.2.0 (64-bit)| (default, Jul  5 2016, 11:41:13) [MSC v.1900 64 bit (AMD64)]
!!!Hello World!!!
C:\PROGRA~1\MICROS~1\MSSQL1~1.MSS\MSSQL\EXTENS~1\MSSQLSERVER01\DD9AFD48-A1BB-49C4-9574-DF93B7A8AFFD
Version pandas: 0.18.1
Version OpenCV: 3.1.0
Version CNTK: 2.0.beta12.0
Version LightGBM: 0.1
Version Lung Cancer: 0.1
*********************************************************************************************
```


### Contributing

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
