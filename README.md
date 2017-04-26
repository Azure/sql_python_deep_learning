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

We have to donwload the data from [kaggle dataset](https://www.kaggle.com/c/data-science-bowl-2017/data). The images are in [DICOM format](https://en.wikipedia.org/wiki/DICOM) and consist of a group of slices of the thorax of each patient as it is shown in the following figure:

<p align="center">
	<img src="https://msdnshared.blob.core.windows.net/media/2017/02/021717_1842_QuickStartG2.png" alt="lung cancer scans" width="30%"/>
	<img src="https://msdnshared.blob.core.windows.net/media/2017/02/021717_1842_QuickStartG3.png" alt="lung cancer scans" width="30%"/>
</p>

We are going to upload the images to SQL. The reason for doing this, instead of reading the images directly from disk, is because we want to simulate an scenario where all the data is already in SQL. For demo purposes we are going to use a small subset of the images, they can be found in [stage1_labels_partial.csv](data/stage1_labels_partial.csv). This subset consists of 200 patients out of 1595. The complete patient info is [stage1_labels.csv](data/stage1_labels.csv).

The first step is to create in SQL Server a database called `lung_cancer_database`. 

The next step is to create a table for the images and upload them. For that you have to execute the script [insert_scan_images_in_sql_database.py](preprocessing/insert_scan_images_in_sql_database.py). In case you want to upload the full dataset, just uncomment `STAGE1_LABELS = os.path.join(DATA_PATH, 'stage1_labels.csv')`. 



### Contributing

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
