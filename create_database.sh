# create sql postgers instance
SQL_INSTANCE_ID=myinstance12
gcloud sql instances create $SQL_INSTANCE_ID --project $PROJECT_ID \
  --database-version POSTGRES_13 --tier db-f1-micro --region $REGION

# create a database inside sql instance
gcloud sql databases create mydatabase --instance $SQL_INSTANCE_ID

# create a new user for instance
PASSWORD=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)
gcloud sql users create djuser --password $PASSWORD --instance $SQL_INSTANCE_ID