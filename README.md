## Lung Cancer Detection Algorithm in SQL Server

This document describes how to execute a transfer learning algorithm using deep learning and SQL Server in the context of lung cancer detection. We want to prove with this solution a new paradigm of computation, where the intelligence of the application is brought to the data, instead of bringing the data to the application. 

The data we used are CT scans from the 2017 [Data Science Bowl](https://www.kaggle.com/c/data-science-bowl-2017/data). The scans are horizontal slices of the thorax and the images are black and white and of size `512x512`. The scans are grouped by patient, there are 1595 patients and each of them have a variable number of scans that goes from 100 to 500 images. The dataset is labelled per patient, not per image, this means that for each patient we have a label of having cancer or not.

In the next figure there is an animation showing all the scans for one patient:

<p align="center">
<img src="https://migonzastorage.blob.core.windows.net/projects/data_science_bowl_2017/gif/0015ceb851d7251b8f399e39779d1e7d.gif" alt="animation of lung cancer scans" width="15%"/>
</p>

We use transfer learning with a pre-trained Convolutional Neural Network (CNN) on [ImageNet dataset](http://image-net.org/) as a featurizer to generate features from the Data Science Bowl dataset, this process is computed with CNTK on a GPU. Once the features are computed, a boosted tree using LightGBM is applied to classify the image. The process is explained in detail in this [blog](https://blogs.technet.microsoft.com/machinelearning/2017/02/17/quick-start-guide-to-the-data-science-bowl-lung-cancer-detection-challenge-using-deep-learning-microsoft-cognitive-toolkit-and-azure-gpu-vms/).


In the next figure we present an overview of the complete algorithm:
<p align="center">
<img src="https://migonzastorage.blob.core.windows.net/projects/data_science_bowl_2017/resnet_tree_lung2.png" alt="transfer learning overview" width="60%"/>
</p>

To create the featurizer, we remove the last layer of the pretrained CNN (in this example we used the [ResNet architecture](https://arxiv.org/abs/1512.03385)) and use the output of the penultimate layer as features. Each patient has an arbitrary number of scan images. The images are cropped to `224×244` and packed in groups of 3, to match the format of ImageNet. They are fed to the pre-trained network in k batches and then convoluted in each internal layer, until the penultimate one. This process is performed using CNTK. The output of the network are the features we feed to the boosted tree, programmed with LightGBM.

Once the boosted tree model is trained, it can be operationalized to classify cancerous scans for other patients using a web app.

In the next sections we will explain how to execute this system inside SQL. All the data, models and resulting features are stored and queried in different tables of a SQL database. There are 3 main processes: featurization, training and scoring. The are explained next together with an initial setup.


### Installation

The installation process can be found [here](INSTALL.md).

### Preprocessing

We have to download the data from [kaggle dataset](https://www.kaggle.com/c/data-science-bowl-2017/data). The images are in [DICOM format](https://en.wikipedia.org/wiki/DICOM) and consist of a group of slices of the thorax of each patient as it is shown in the following figure:

<p align="center">
	<img src="https://msdnshared.blob.core.windows.net/media/2017/02/021717_1842_QuickStartG2.png" alt="lung cancer scans" width="30%"/>
	<img src="https://msdnshared.blob.core.windows.net/media/2017/02/021717_1842_QuickStartG3.png" alt="lung cancer scans" width="30%"/>
</p>

We are going to upload the images to SQL. The reason for doing this, instead of reading the images directly from disk, is because we want to simulate an scenario where all the data is already in SQL. For demo purposes we are going to use a small subset of the images, they can be found in [stage1_labels_partial.csv](data/stage1_labels_partial.csv). This subset consists of 200 patients out of 1595. The complete patient info is [stage1_labels.csv](data/stage1_labels.csv).

The first step is to create in SQL Server a database called `lung_cancer_database`. 

The next step is to create a table for the images and upload them. First you need to put the correct paths in the file [config_preprocessing.py](preprocessing/config_preprocessing.py.template). In case you want to upload the full dataset, just uncomment `STAGE1_LABELS = os.path.join(DATA_PATH, 'stage1_labels.csv')`. To import the images to the SQL database you have to execute the script [insert_scan_images_in_sql_database.py](preprocessing/insert_scan_images_in_sql_database.py). This will take a while.

In the mean time, execute the script [insert_other_items_in_sql_database.py](preprocessing/insert_other_items_in_sql_database.py). This script creates and fill tables for the labels, the CNN model and a gif representation of the images. 

### Process 1: Featurization of Lung Scans with CNN in a GPU

The initial process generates features from the scans using a pretrained ResNet. In the SQL stored procedure [sp_00_cnn_feature_generation_create.sql](sql/sp_00_cnn_feature_generation_create.sql), the code can be found. To create the store procedure you just need to execute the SQL file in SQL Server Management Studio. This will create a new stored procedure under `lung_cancer_database/Programmability/Stored Procedures` called `dbo.GenerateFeatures`.

The main routine is super simple and consists of 9 lines of code. All the functions associated with the script can be found in [lung_cancer_utils.py](lung_cancer/lung_cancer_utils.py).

```python
try_set_default_device(gpu(0))
patients = get_patients_id(TABLE_SCAN_IMAGES, cur)
model = load_model(Model)
model = select_model_layer(model, "z.x")

for i, p in enumerate(patients):
	scans = get_patient_images(TABLE_SCAN_IMAGES, cur, p)
	scans = manipulate_images(scans)
	feats = compute_features_with_gpu(model, scans, BATCH_SIZE)
	insert_features(TABLE_FEATURES, cur, conn, p, feats)
```

Let's explain each line one by one: 
- The instruction `try_set_default_device(gpu(0))` defines the GPU the system uses. This is in fact superfluous because CNTK automatically selects the best option the current system provides, if the system has a GPU it will use it, if not, it will use the CPU. 
- The instruction `patients = get_patients_id(TABLE_SCAN_IMAGES, cur)` gets a list of the patients ids.
- The model is retrieved from SQL in this line `model = load_model(Model)`. The variable `Model` is an input to the stored procedure and it is queried from SQL externally.
- The penultimate layer of the CNN is selected to featurize the images in `model = select_model_layer(model, "z.x")`.
- The next step is to loop for each patient. The first step is to query the images of the patient using this instruction: `scans = get_patient_images(TABLE_SCAN_IMAGES, cur, p)`.
- Then there is a manipulation of the scans `scans = manipulate_images(scans)`. It consists of a size reduction, image equalization and packing of the scans in groups of 3 to match the input size of the pretrained CNN.
- The next line `feats = compute_features_with_gpu(net, scans, BATCH_SIZE)` makes the pretrained CNN `net` to compute the features. This is where the forward propagation happens and is the slowest point in the algorithm. That is why we use a GPU to speed up the process.
- Finally, the computed features are inserted in a SQL table in the last instruction `insert_features(TABLE_FEATURES, cur, conn, p, feats)`.

To execute this stored procedure you have to execute the file [sp_00_cnn_feature_generation_execute.sql](sql/sp_00_cnn_feature_generation_execute.sql). This process takes around 40min in a Windows GPU DSVM. 

To test that the GPU is actually executing the process, you can type in a terminal `nvidia-smi`.

### Process 2: Training of Scan Features with Boosted Tree 

Once the features are computed and inserted in the SQL table, we use them to train a boosted tree using LightGBM library. The code that computes this process is [sp_01_boosted_tree_training_create.sql](sql/sp_01_boosted_tree_training_create.sql) and generates a stored procedure called `dbo.TrainLungCancerModel`.

In this case the main code occupies 4 lines of code:

```python
patients_train = get_patients_id(TABLE_LABELS, cur)
trn_x, val_x, trn_y, val_y = generate_set(TABLE_FEATURES, TABLE_LABELS, patients_train, cur)
classifier = train_lightgbm(trn_x, val_x, trn_y, val_y)
insert_model(TABLE_MODEL, cur, conn, classifier, LIGHTGBM_MODEL_NAME)
```
Let's explain again each line:
- As before, we retrieve the list of patients ids `patients_train = get_patients_id(TABLE_LABELS, cur)`. However, this time instead of retrieving all the patients, we are just going to use the training subset, which is the one that has labels.
- The next line `trn_x, val_x, trn_y, val_y = generate_set(TABLE_FEATURES, TABLE_LABELS, patients_train, cur)` generates the training and validation set.
- Next, we compute the classifier in `classifier = train_lightgbm(trn_x, val_x, trn_y, val_y)`.
- Finally, we insert the trained model in a SQL table using `insert_model(TABLE_MODEL, cur, conn, classifier, LIGHTGBM_MODEL_NAME)`.

This process takes around 1 min in a DSVM.

### Process 3: Scoring with the Trained Classifier

The final process is the operationalization routine. The boosted tree can be used to compute the probability of a new patient of having cancer. The script is [sp_02_boosted_tree_scoring_create.sql](sql/sp_02_boosted_tree_scoring_create.sql) and generates a stored procedure called `PredictLungCancer`. This can be connected to a web app via an API.

The inputs of the SQL stored procedure are `@PatientIndex` and `@ModelName`. The output is the prediction result `@PredictionResult` given a patient index and a model name. Inside the stored procedure, we get the boosted tree model and the features of the patient, which are both serialized and stored as binary variables:

```sql
DECLARE @Model VARBINARY(MAX) = (SELECT TOP(1) model from dbo.model where name = @ModelName ORDER BY date DESC);
DECLARE @Features VARBINARY(MAX) = (SELECT TOP(1) array FROM dbo.features AS t1 
									INNER JOIN dbo.patients AS t2 ON t1.patient_id = t2.patient_id 
									WHERE t2.idx = @PatientIndex);
```  
- The first line retrieves the last computed model `@Model` given its name. This model is serialized with pickle and it has to be deserialized to be used in python.
- The next line obtains the features given a patient index. 

These two variables are sent to python as serialized objects. The main python code has 4 lines:

```python 
feats = pickle.loads(Features)
model = pickle.loads(Model)
probability_cancer = prediction(model, feats)
PredictionResult = float(probability_cancer)*100
``` 
In this case there is an input and output for the python routine from SQL. The input is `PatientIndex` which is the index of the patient we want to analyze. The output is `PredictionResult`, which is the probability of this patient of having cancer. Here the explanation of the code:
- The features queried from SQL are deserialized using the instruction `feats = pickle.loads(Features)`. 
- The same operation is performed for the boosted tree model in `model = pickle.loads(Model)`.
- Next, using the model and the features, the line `probability_cancer = prediction(model, feats)` computes the probability of having cancer. 
- Finally in `PredictionResult = float(probability_cancer)*100` the probability is transformed in a percentage.

To execute this stored procedure you have to makes this query, which takes 1s:

```sql
DECLARE @PredictionResultSP FLOAT;
EXECUTE lung_cancer_database.dbo.PredictLungCancer @PatientIndex = 0, @PredictionResult = @PredictionResultSP;
```
The variable `@PredictionResultSP` is the output of the stored procedure and `@PatientIndex = 0` is the input. If we use the small dataset, the maximum input is 200, in case we use the full dataset, the maximum input is 1594.

## Lung Cancer Detection Web Service

We created a demo web app to show the lung cancer detection in SQL python. To run it, you just need to execute [api_service.py](web_app/api_service.py)

The web page can be accessed at `http://localhost:5000`. 

In case you want to access it from outside you have to open the port 5000 in the Azure portal (Network Interfaces/Network security group/Inbound security rules). You need to do the same in the Firewall inside the virtual machine (Windows Firewall with Advanced Security/Inbound rules). To access the web service from outside just replace `localhost` with the DNS or IP of the VM.

You can try to search a patient called Anthony or another call Ana. You can also search for patients by ID entering a number between 0 and 200 (1594 if you use the full dataset).

### Disclaimer

The idea of the lung cancer demo is to showcase that a deep learning algorithm can be computed with GPU inside SQL in python. 

The accuracy of the actual algorithm is low. It has a very simple pipeline. This algorithm was created as a baseline for the [lung cancer kaggle competition](https://blogs.technet.microsoft.com/machinelearning/2017/02/17/quick-start-guide-to-the-data-science-bowl-lung-cancer-detection-challenge-using-deep-learning-microsoft-cognitive-toolkit-and-azure-gpu-vms/), to allow users to quickly set up a DSVM and execute a CNTK algorithm. 

An example of an algorithm with higher accuracy can be found [here](https://eliasvansteenkiste.github.io/machine learning/lung-cancer-pred/), the pipeline has a 3D CNN for nodule segmentation, one CNN for false positive reduction, another CNN for identifying if the nodule is malignant or not, then transfer learning and finally ensembling.  

It is important to understand that the focus of the demo is not the algorithm itself but the pipeline which allows to execute deep learning in a SQL database.


### Contributing

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
