# Wagtail Deployment On Cloud Run  
In this project we will creata a simple wagtail application and deploy it on cloud run using cloud build.  
Overview: 

    1. We will create (or/and configure) project and region to use.   
    2. We will enable API's required (refer to table in Resources) for deployment.   
    3. We will create an sql instance, database and user.  
    4. We will create secrets using secret manager.
    5. We will use cloud build to run migrations and deploy to cloud run.
 ~~We will create source repo and add trigger to run build on each commit~ ~ 
    

## Prerequisite  
1. Access to GCP account with permissions to create a project with billing and to enable API's.  
2. CloudSDK set up on local machine or use cloud shell.  
3. Create a new project or use existing one. Configure shell to use this project.  

## Resources

| Resources                   	| Details 	|
|-----------------------------	|---------	|
| SQL Instance                	| SQL instance and single database will be used by wagtail website        	|
| Storage Bucket              	|         	|
| Google Container Repository 	| Image built will be pushed to gcr.io and used by cloud run for deployment         	|
| Cloud Run                   	|         	|
| Cloud Build                 	|         	|
| Cloud Build Service Account   | This account is automaticaly created while enabling cloud build api(see API's table) <br> default service account is PROJECT_NUMBER@cloudbuild.gserviceaccount.com       	|
| Cloud Run Service Account                 	| Cloud Run uses compute engine service account by default <br> default service account is PROJECT_NUMBER-compute@developer.gserviceaccount.com         	|
| application_settings                 	| Secret created using secret manager      	|
| admin_password                 	| Secret created using secret manager       	|
| wagtail-cloudrun                 	| Container Image to be created and pushed to gcr.io/PROJECT_ID/wagtail-cloudrun by cloud build |
| roles/secretmanager.secretAccessor  | on application_settings secret, assigned to cloud build and cloud run service accounts,<br> on admin_password assigned to cloud build        	|
| roles/cloudsql.client           | required by cloud build service account        	|
| roles/run.admin                 | required by cloud build service account       	|
| roles/iam.serviceAccountUser    | required by cloud build service account        	|

## Varialbes
List of Variables created and used in scritps are:
| VARIABLES                   	| Details 	|
|-----------------------------	|---------	|
| PROJECT_ID                	| Project Id in which we well create this deployment        	|
| REGION                      	| Region in which resources like bucket, sql instance will be created        	|
| SQL_INSTANCE_ID           	| Within in Project unique sql instance name, which haven't beeen used before        	|
| PASSWORD                      | SQL Instance user password        	|
| GS_BUCKET_NAME                | Google Cloud Storage Bucket Name        	|
| PROJECTNUM                 	| Porject Number of current PROJECT_ID        	|
| CLOUDBUILD                 	| Cloud Build service account        	|
| CLOUDRUN                     	| Cloud Run service account        	|

## API's  
We will need following apis to perfrom deplpoyment.  
| API Name          	| Service                      	| Details 	|
|-------------------	|------------------------------	|---------	|
| Cloud Sql         	| sql-component.googleapis.com 	|         	|
| Cloud Sql Admin   	| sqladmin.googleapis.com      	|         	|
| Cloud Run         	| run.googleapis.com           	|         	|
| Cloud Build       	| cloudbuild.googleapis.com    	|         	|
| Secret Manager    	| secretmanager.googleapis.com 	|         	|
| Cloud Compute     	| compute.googleapis.com       	|         	|
| Cloud Source Repo 	| sourcerepo.googleapis.com    	|         	|

## Deploying Wagtail on Cloud Run  
## 1. Configure Project  
If you are using cloud sdk in local machine then run:
```
gcloud init
```
to authorize the gcloud to use your account, and follow the steps to create (or/and select)  
desired project. Or login to gcp cosole and select/create desired project from drop down.
use:
```
gcloud config list
```
to se if correct project configurations are set.  
_From now on we will perfrom all steps on local machine. but you can follow same steps in cloud shell in gcp console_  


## 2. Initialize PROJECT_ID,REGION and Enable API'S  
Run the script init.sh to configure the project, set the PROJECT_ID and REGION variables accordingly.  
use command:
```
source ./init.sh
```  
*note that we are using source to run our script, so that it runs within current shell and any*   
*variables intialized by script can be used in subsequent executions*   



__or run the following commands:__  
to set PROJECT_ID and REGION and to to confirm that you are authenticated and set project id.  
"if you have used `gcloud init` use 2nd method.  
  
_1st:_
```
PROJECT_ID=wagtail-demo-mubashir
REGION=us-central1
gcloud auth list
gcloud config set project $PROJECT_ID
```
  
_2nd:_  
alternatively if you have used gcloud init to configure your project use following commands to intialize  
PROJECT_ID and REGION
```
PROJECT_ID=$(gcloud config get-value core/project)
REGION=$(gcloud config get-value compute/region)
```  
  
Now moving on to enabling apis. Run:   
```
gcloud services enable \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  compute.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com
```



## 3. Create SQL Instance, Database and User  

You can execute create_database.sh using `source ./create_database.sh`  which will 
initialize SQL_INSTANCE_ID, then create sql instance, then create database, then create 
user. And move on to next step.

Alternatively you can run following commands:  
Create sql postgres instance:
```
SQL_INSTANCE_ID=myinstance5
gcloud sql instances create $SQL_INSTANCE_ID --project $PROJECT_ID \
  --database-version POSTGRES_13 --tier db-f1-micro --region $REGION
```  
Then create a database inside that instance:  
```
gcloud sql databases create mydatabase --instance $SQL_INSTANCE_ID
```
Then create a user for the instance:  
```
PASSWORD=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)
gcloud sql users create djuser --password $PASSWORD --instance $SQL_INSTANCE_ID
```  


## 4. Create Google Storage Bucket  
create bucket with name $PROJECT_ID-media and allow cross origin resource sharing on this bucket.
create a file cors.json and save following contents in this file.  
```
[
    {
      "origin": ["*"],
      "responseHeader": ["Content-Type"],
      "method": ["GET"],
      "maxAgeSeconds": 3600
    }
]
```  
Now execute the script create_gsbucket.sh using `source ./create_bucket` and move on to next step  
Or run the following commands:  

Intialize GS_BUCKET_NAME by appending "-media" to PROJECT_ID.  
Then create the bucket in $REGION.  
```
GS_BUCKET_NAME=${PROJECT_ID}-media
gsutil mb -l ${REGION} gs://${GS_BUCKET_NAME}
```

Allow cross orgin resource sharing on this bucket to be used by cloud run.  
```
gsutil cors set cors.json gs://$GS_BUCKET_NAME
```


## 5. Create configruation File (using Secret Manager):  
Before continuing with this step make sure you have followed all previous steps and
following environment variables have been initialized:
 1. PROJECT_ID
 2. REGION
 3. SQL_INSTANCE_ID
 4. REGION
 5. PASSWORD
Now we will add configurations. 
As before you can simply run `source ./secret.sh`  
or run following commands:  
Create configurations(database url, gs bucket name, and other variables) to be used by appilcation:
```
echo DATABASE_URL=\"postgres://djuser:${PASSWORD}@//cloudsql/${PROJECT_ID}:${REGION}:${SQL_INSTANCE_ID}/mydatabase\" > .env
echo GS_BUCKET_NAME=\"${GS_BUCKET_NAME}\" >> .env
echo SECRET_KEY=\"$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)\" >> .env
echo DEBUG=\"True\" >> .env
```
Now we have stored configurations in file, use secret manager to create secret using this file.  
```
gcloud secrets create application_settings --data-file .env
gcloud secrets versions list application_settings
rm .env 
```
Make sure secret has been created.  
Now create another secret containing django user password.  
```
gcloud secrets create admin_password --replication-policy automatic
USER_PASSWORD=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)
echo -n $USER_PASSWORD | gcloud secrets versions add admin_password --data-file=-
```


## 6. Create IAM Roles Bindings  
Build is run by cloud build and then application is deployed to cloud run.  
We will assign following roles to different service account and secrets.  
Again simply run `source ./iam-binding.sh` or run the following commands.  
Intialize CLOUD_BUILD and CLOUD_RUN variables with the service account.  
```
PROJECTNUM=$(gcloud projects describe ${PROJECT_ID} --format 'value(projectNumber)')
CLOUDRUN=${PROJECTNUM}-compute@developer.gserviceaccount.com
CLOUDBUILD=${PROJECTNUM}@cloudbuild.gserviceaccount.com
```

Allow cloudbuild and cloudrun to access application_settings secret.  
```
gcloud secrets add-iam-policy-binding application_settings \
  --member serviceAccount:${CLOUDRUN} --role roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding application_settings \
  --member serviceAccount:${CLOUDBUILD} --role roles/secretmanager.secretAccessor
```
Allow cloudbuild to access admin_password secret.  
```
gcloud secrets add-iam-policy-binding admin_password \
  --member serviceAccount:${CLOUDBUILD} --role roles/secretmanager.secretAccessor
```

Allow cloud build role of cloudsql.client  
```
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${CLOUDBUILD} --role roles/cloudsql.client
```

Allow cloud build run.admin and role of cloud run service account user.  
```
gcloud iam service-accounts add-iam-policy-binding $CLOUDRUN \
  --member="serviceAccount:"${CLOUDBUILD} \
  --role="roles/iam.serviceAccountUser"
```


## 7. Run Migrations using Cloud Build  
Submit build to create and push container image and run migrations using cloudmigrate.yaml file.  
```
gcloud builds submit --config cloudmigrate.yaml --substitutions _REGOIN=$REGOIN,_SQL_INSTANCE_ID=$SQL_INSTANCE_ID
```
Now submit build to deploy to cloud run.
```
gcloud builds submit --config cloudrundeployment.yaml --substitutions _REGOIN=$REGOIN,_SQL_INSTANCE_ID=$SQL_INSTANCE_ID
```

The successfull build will return url of the service in response.

